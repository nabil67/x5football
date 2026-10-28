-- Étape 8 : signalements, blocages et limites anti-abus.
--
-- Décisions du 2026-10-28 :
--   - signalements examinés par une personne (Supabase Studio), aucune sanction automatique ;
--   - si A bloque B : B ne peut plus rejoindre les matchs organisés par A, A ne voit plus
--     les matchs organisés par B dans ses recherches, B n'est pas prévenu ;
--   - limites : 10 créations de match par jour, 30 inscriptions/désinscriptions par heure,
--     10 signalements par jour.

-- ---------------------------------------------------------------------------
-- Limites anti-abus
-- ---------------------------------------------------------------------------

create table private.rate_limit_events (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.users (id) on delete cascade,
  action text not null,
  created_at timestamptz not null default clock_timestamp()
);

create index rate_limit_events_lookup_idx on private.rate_limit_events (user_id, action, created_at);

-- Enregistre une action, ou la refuse si la limite de la fenêtre glissante est atteinte.
create function private.enforce_rate_limit(
  p_user_id uuid,
  p_action text,
  p_max integer,
  p_window interval,
  p_hint text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Sérialise les demandes simultanées d'une même personne pour une même action.
  perform pg_advisory_xact_lock(hashtext(p_user_id::text || ':' || p_action));

  if (select count(*) from private.rate_limit_events
      where user_id = p_user_id and action = p_action
        and created_at > clock_timestamp() - p_window) >= p_max then
    raise exception using errcode = 'PT429', message = 'RATE_LIMITED', hint = p_hint;
  end if;

  insert into private.rate_limit_events (user_id, action) values (p_user_id, p_action);
end;
$$;

-- Purge quotidienne de l'historique des limites (fenêtres d'au plus 24 h).
create function private.purge_rate_limit_events()
returns integer
language sql
security definer
set search_path = ''
as $$
  with deleted as (
    delete from private.rate_limit_events where created_at < now() - interval '2 days' returning 1
  )
  select count(*)::integer from deleted;
$$;

select cron.schedule('purge-rate-limit-events', '43 3 * * *', $$select private.purge_rate_limit_events()$$);

-- ---------------------------------------------------------------------------
-- Blocages
-- ---------------------------------------------------------------------------

create table public.user_blocks (
  blocker_id uuid not null references public.users (id) on delete cascade,
  blocked_id uuid not null references public.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint user_blocks_not_self check (blocker_id <> blocked_id)
);

create index user_blocks_blocked_idx on public.user_blocks (blocked_id);

alter table public.user_blocks enable row level security;
revoke all on public.user_blocks from anon, authenticated;
grant select on public.user_blocks to authenticated;

-- Seule la personne qui bloque voit ses blocages : la personne bloquée n'en sait rien.
create policy user_blocks_select_own on public.user_blocks
  for select to authenticated
  using (blocker_id = (select auth.uid()));

create view public.my_blocks
with (security_invoker = true)
as
select b.blocked_id as user_id, p.display_name, p.avatar_url, b.created_at
from public.user_blocks b
left join public.public_profiles p on p.id = b.blocked_id;

revoke all on public.my_blocks from anon, authenticated;
grant select on public.my_blocks to authenticated;

create function public.block_user(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.current_active_user_id();
begin
  if p_user_id is null or p_user_id = v_uid then
    raise exception using errcode = 'PT400', message = 'INVALID_BLOCK_TARGET',
      hint = 'Vous ne pouvez pas vous bloquer vous-même.';
  end if;
  if not exists (select 1 from public.users where id = p_user_id) then
    raise exception using errcode = 'PT404', message = 'USER_NOT_FOUND',
      hint = 'Ce joueur est introuvable.';
  end if;
  insert into public.user_blocks (blocker_id, blocked_id) values (v_uid, p_user_id)
  on conflict do nothing;
end;
$$;

create function public.unblock_user(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.current_active_user_id();
begin
  delete from public.user_blocks where blocker_id = v_uid and blocked_id = p_user_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Signalements
-- ---------------------------------------------------------------------------

create type public.report_reason as enum (
  'inappropriate_behavior', 'harassment', 'spam', 'fake_match', 'dangerous', 'other'
);
create type public.report_status as enum ('open', 'reviewed', 'dismissed');

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.users (id) on delete cascade,
  reported_user_id uuid references public.users (id) on delete cascade,
  match_id uuid references public.matches (id) on delete cascade,
  reason public.report_reason not null,
  comment text
    constraint reports_comment_valid check (char_length(comment) <= 1000),
  status public.report_status not null default 'open',
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  -- Un signalement vise soit un joueur, soit un match.
  constraint reports_one_target check ((reported_user_id is null) <> (match_id is null)),
  constraint reports_not_self check (reported_user_id is distinct from reporter_id)
);

-- Un seul signalement ouvert par personne et par cible : pas de doublons.
create unique index reports_one_open_user_idx
  on public.reports (reporter_id, reported_user_id) where status = 'open' and reported_user_id is not null;
create unique index reports_one_open_match_idx
  on public.reports (reporter_id, match_id) where status = 'open' and match_id is not null;
create index reports_open_idx on public.reports (created_at) where status = 'open';

-- Aucune lecture côté application : la modération se fait dans Supabase Studio.
alter table public.reports enable row level security;
revoke all on public.reports from anon, authenticated;

create function public.report(
  p_reason public.report_reason,
  p_user_id uuid default null,
  p_match_id uuid default null,
  p_comment text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.current_active_user_id();
  v_comment text := nullif(btrim(p_comment), '');
begin
  if p_reason is null or (p_user_id is null) = (p_match_id is null) then
    raise exception using errcode = 'PT400', message = 'INVALID_REPORT',
      hint = 'Choisissez un motif et ce que vous signalez.';
  end if;
  if char_length(v_comment) > 1000 then
    raise exception using errcode = 'PT400', message = 'INVALID_REPORT',
      hint = 'Le commentaire est limité à 1000 caractères.';
  end if;
  if p_user_id = v_uid
     or (p_match_id is not null and exists (
       select 1 from public.matches where id = p_match_id and organizer_id = v_uid)) then
    raise exception using errcode = 'PT400', message = 'INVALID_REPORT_TARGET',
      hint = 'Vous ne pouvez pas vous signaler vous-même.';
  end if;
  if (p_user_id is not null and not exists (select 1 from public.users where id = p_user_id))
     or (p_match_id is not null and not exists (select 1 from public.matches where id = p_match_id)) then
    raise exception using errcode = 'PT404', message = 'REPORT_TARGET_NOT_FOUND',
      hint = 'Ce que vous signalez est introuvable.';
  end if;

  perform private.enforce_rate_limit(v_uid, 'report', 10, interval '1 day',
    'Vous avez atteint la limite de 10 signalements par jour. Réessayez demain.');

  -- Déjà signalé et pas encore traité : rien à ajouter, sans erreur.
  insert into public.reports (reporter_id, reported_user_id, match_id, reason, comment)
  values (v_uid, p_user_id, p_match_id, p_reason, v_comment)
  on conflict do nothing;
end;
$$;

-- ---------------------------------------------------------------------------
-- Application des blocages et des limites aux RPC existantes
-- ---------------------------------------------------------------------------

create or replace function public.create_match(p_match jsonb)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.current_active_user_id();
  v_match public.matches;
begin
  v_match.id := gen_random_uuid();
  v_match.organizer_id := v_uid;
  v_match.skill_level := 'all';
  v_match.currency := 'EUR';
  v_match.status := 'open';
  v_match := private.apply_match_input(v_match, p_match);
  perform private.assert_start_time_allowed(v_match.starts_at);
  perform private.enforce_rate_limit(v_uid, 'create_match', 10, interval '1 day',
    'Vous avez atteint la limite de 10 matchs créés par jour. Réessayez demain.');

  v_match.created_at := now();
  v_match.updated_at := now();
  insert into public.matches select (v_match).*;
  insert into public.participations (match_id, user_id) values (v_match.id, v_uid);

  return v_match.id;
end;
$$;

create or replace function public.join_match(p_match_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.current_active_user_id();
  v_match public.matches := private.lock_open_match(p_match_id);
  v_active integer;
begin
  if exists (
    select 1 from public.participations
    where match_id = p_match_id and user_id = v_uid and status = 'active'
  ) then
    raise exception using errcode = 'PT409', message = 'ALREADY_JOINED',
      hint = 'Vous êtes déjà inscrit à ce match.';
  end if;

  -- Organisateur ayant bloqué la personne : refus sans révéler le blocage.
  if exists (
    select 1 from public.user_blocks where blocker_id = v_match.organizer_id and blocked_id = v_uid
  ) then
    raise exception using errcode = 'PT403', message = 'JOIN_NOT_ALLOWED',
      hint = 'L''inscription à ce match n''est pas possible.';
  end if;

  perform private.enforce_rate_limit(v_uid, 'participation', 30, interval '1 hour',
    'Trop d''inscriptions ou de désinscriptions en peu de temps. Réessayez dans un moment.');

  -- Lecture après obtention du verrou : voit les inscriptions validées entre-temps.
  select count(*) into v_active
  from public.participations
  where match_id = p_match_id and status = 'active';

  if v_active >= v_match.capacity then
    raise exception using errcode = 'PT409', message = 'MATCH_FULL',
      hint = 'Ce match est complet.';
  end if;

  insert into public.participations (match_id, user_id) values (p_match_id, v_uid);
exception
  -- Filet de sécurité : l'index unique partiel refuse toute double inscription active.
  when unique_violation then
    raise exception using errcode = 'PT409', message = 'ALREADY_JOINED',
      hint = 'Vous êtes déjà inscrit à ce match.';
end;
$$;

create or replace function public.leave_match(p_match_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.current_active_user_id();
  v_match public.matches := private.lock_open_match(p_match_id);
begin
  if v_match.organizer_id = v_uid then
    raise exception using errcode = 'PT409', message = 'ORGANIZER_CANNOT_LEAVE',
      hint = 'Vous organisez ce match : transmettez l''organisation à un autre joueur ou annulez le match.';
  end if;

  perform private.enforce_rate_limit(v_uid, 'participation', 30, interval '1 hour',
    'Trop d''inscriptions ou de désinscriptions en peu de temps. Réessayez dans un moment.');

  update public.participations
  set status = 'cancelled', cancelled_at = now()
  where match_id = p_match_id and user_id = v_uid and status = 'active';

  if not found then
    raise exception using errcode = 'PT409', message = 'NOT_PARTICIPANT',
      hint = 'Vous n''êtes pas inscrit à ce match.';
  end if;
end;
$$;

-- Recherche : les matchs organisés par une personne bloquée n'apparaissent plus.
create or replace function public.search_matches(
  p_latitude double precision,
  p_longitude double precision,
  p_radius_km double precision default 10,
  p_starts_after timestamptz default null,
  p_starts_before timestamptz default null,
  p_available_only boolean default false,
  p_skill_level public.skill_level default null,
  p_limit integer default 20,
  p_offset integer default 0
)
returns setof public.match_details
language plpgsql
stable
set search_path = ''
as $$
declare
  v_center extensions.geography;
begin
  if p_latitude is null or p_longitude is null
    or p_latitude not between -90 and 90 or p_longitude not between -180 and 180 then
    raise exception using errcode = 'PT400', message = 'INVALID_COORDINATES',
      hint = 'Position de recherche invalide.';
  end if;
  if p_radius_km is null or p_radius_km not between 1 and 100 then
    raise exception using errcode = 'PT400', message = 'INVALID_RADIUS',
      hint = 'Le rayon doit être compris entre 1 et 100 km.';
  end if;
  if p_limit is null or p_limit not between 1 and 50
    or p_offset is null or p_offset not between 0 and 1000 then
    raise exception using errcode = 'PT400', message = 'INVALID_PAGINATION',
      hint = 'Pagination invalide.';
  end if;

  v_center := extensions.st_setsrid(extensions.st_makepoint(p_longitude, p_latitude), 4326)::extensions.geography;

  return query
  select d.*
  from public.matches m
  join public.match_details d on d.id = m.id
  where m.status = 'open'
    and m.starts_at > greatest(now(), coalesce(p_starts_after, now()))
    and (p_starts_before is null or m.starts_at < p_starts_before)
    and extensions.st_dwithin(m.location, v_center, p_radius_km * 1000)
    and (not coalesce(p_available_only, false) or d.spots_left > 0)
    and (p_skill_level is null or p_skill_level = 'all' or m.skill_level in (p_skill_level, 'all'))
    and not exists (
      select 1 from public.user_blocks b
      where b.blocker_id = (select auth.uid()) and b.blocked_id = m.organizer_id
    )
  order by extensions.st_distance(m.location, v_center), m.starts_at, m.id
  limit p_limit offset p_offset;
end;
$$;

revoke execute on function public.block_user(uuid) from public, anon;
revoke execute on function public.unblock_user(uuid) from public, anon;
revoke execute on function public.report(public.report_reason, uuid, uuid, text) from public, anon;
grant execute on function public.block_user(uuid) to authenticated;
grant execute on function public.unblock_user(uuid) to authenticated;
grant execute on function public.report(public.report_reason, uuid, uuid, text) to authenticated;

revoke all on all tables in schema private from public, anon, authenticated;
revoke execute on all functions in schema private from public, anon, authenticated;
-- La politique de stockage des photos s'appuie sur cette fonction (étape 7).
grant execute on function private.is_own_avatar_path(text) to authenticated;
