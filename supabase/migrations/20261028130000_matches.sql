-- Étape 3 : matchs (création, lecture, modification, annulation) et participations.
--
-- Le statut `full` n'est pas stocké : il est calculé à la lecture (vue match_details)
-- à partir des participations actives. Seuls open / cancelled / completed sont stockés.
-- Toute écriture passe par des RPC qui verrouillent la ligne du match (FOR UPDATE).

create extension if not exists postgis with schema extensions;

create type public.match_format as enum ('5v5', '7v7', '11v11');
create type public.match_status as enum ('open', 'cancelled', 'completed');
create type public.location_mode as enum ('fixed', 'to_define');
create type public.location_status as enum ('confirmed', 'to_confirm');
create type public.skill_level as enum ('all', 'beginner', 'intermediate', 'advanced');
create type public.participation_status as enum ('active', 'cancelled');

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.matches (
  id uuid primary key default gen_random_uuid(),
  organizer_id uuid not null references public.users (id) on delete cascade,
  title text not null
    constraint matches_title_valid check (
      char_length(title) between 3 and 80 and title = btrim(title) and title !~ '[[:cntrl:]]'
    ),
  description text
    constraint matches_description_valid check (char_length(description) <= 1000),
  starts_at timestamptz not null,
  duration_minutes integer not null
    constraint matches_duration_valid check (duration_minutes between 15 and 600),
  -- Capacité totale, organisateur inclus.
  capacity integer not null
    constraint matches_capacity_valid check (capacity between 4 and 50),
  format public.match_format not null,
  skill_level public.skill_level not null default 'all',
  location_mode public.location_mode not null,
  location_status public.location_status not null,
  location_name text
    constraint matches_location_name_valid check (
      char_length(location_name) between 2 and 120 and location_name = btrim(location_name)
    ),
  location extensions.geography(point, 4326),
  estimated_total_cost numeric(8, 2)
    constraint matches_total_cost_valid check (estimated_total_cost >= 0),
  estimated_cost_per_player numeric(8, 2)
    constraint matches_cost_per_player_valid check (estimated_cost_per_player >= 0),
  currency char(3) not null default 'EUR'
    constraint matches_currency_valid check (currency ~ '^[A-Z]{3}$'),
  status public.match_status not null default 'open',
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- Terrain précis : nom + position confirmés. Lieu à définir : jamais de position inventée.
  constraint matches_location_consistent check (
    (location_mode = 'fixed' and location_status = 'confirmed'
      and location is not null and location_name is not null)
    or (location_mode = 'to_define' and location_status = 'to_confirm' and location is null)
  ),
  constraint matches_cancelled_consistent check ((status = 'cancelled') = (cancelled_at is not null))
);

create index matches_open_starts_at_idx on public.matches (starts_at) where status = 'open';
create index matches_location_idx on public.matches using gist (location);
create index matches_organizer_idx on public.matches (organizer_id);

create trigger matches_set_updated_at
  before update on public.matches
  for each row execute function private.set_updated_at();

create table public.participations (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  status public.participation_status not null default 'active',
  joined_at timestamptz not null default now(),
  cancelled_at timestamptz,
  constraint participations_cancelled_consistent check ((status = 'cancelled') = (cancelled_at is not null))
);

-- Une seule participation active par personne et par match.
create unique index participations_one_active_idx
  on public.participations (match_id, user_id) where status = 'active';
create index participations_user_active_idx
  on public.participations (user_id) where status = 'active';

-- ---------------------------------------------------------------------------
-- Accès en lecture (aucune écriture directe du client)
-- ---------------------------------------------------------------------------

alter table public.matches enable row level security;
alter table public.participations enable row level security;

revoke all on public.matches, public.participations from anon, authenticated;
grant select on public.matches, public.participations to authenticated;

create policy matches_select_authenticated on public.matches
  for select to authenticated
  using (true);

-- Les inscriptions actives sont publiques entre utilisateurs connectés (liste des joueurs) ;
-- l'historique des désinscriptions n'est visible que par la personne concernée.
create policy participations_select on public.participations
  for select to authenticated
  using (status = 'active' or user_id = (select auth.uid()));

create view public.match_details
with (security_invoker = true)
as
select
  m.id,
  m.organizer_id,
  o.display_name as organizer_name,
  m.title,
  m.description,
  m.starts_at,
  m.starts_at + make_interval(mins => m.duration_minutes) as ends_at,
  m.duration_minutes,
  m.capacity,
  pc.participant_count,
  greatest(m.capacity - pc.participant_count, 0) as spots_left,
  m.format,
  m.skill_level,
  m.location_mode,
  m.location_status,
  m.location_name,
  extensions.st_y(m.location::extensions.geometry) as latitude,
  extensions.st_x(m.location::extensions.geometry) as longitude,
  m.estimated_total_cost,
  m.estimated_cost_per_player,
  m.currency,
  m.status,
  case
    when m.status = 'cancelled' then 'cancelled'
    when m.status = 'completed'
      or m.starts_at + make_interval(mins => m.duration_minutes) <= now() then 'completed'
    when m.starts_at <= now() then 'in_progress'
    when pc.participant_count >= m.capacity then 'full'
    else 'open'
  end as display_status,
  m.organizer_id = (select auth.uid()) as is_organizer,
  exists (
    select 1 from public.participations p
    where p.match_id = m.id and p.user_id = (select auth.uid()) and p.status = 'active'
  ) as is_participant,
  m.created_at,
  m.updated_at
from public.matches m
left join public.public_profiles o on o.id = m.organizer_id
cross join lateral (
  select count(*)::integer as participant_count
  from public.participations p
  where p.match_id = m.id and p.status = 'active'
) pc;

create view public.match_participants
with (security_invoker = true)
as
select
  p.match_id,
  p.user_id,
  pp.display_name,
  pp.avatar_url,
  p.joined_at,
  p.user_id = m.organizer_id as is_organizer
from public.participations p
join public.matches m on m.id = p.match_id
join public.public_profiles pp on pp.id = p.user_id
where p.status = 'active';

revoke all on public.match_details, public.match_participants from anon, authenticated;
grant select on public.match_details, public.match_participants to authenticated;

-- ---------------------------------------------------------------------------
-- Validation partagée par la création et la modification
-- ---------------------------------------------------------------------------

-- Délai minimal entre maintenant et le début d'un match créé ou replanifié.
create function private.min_start_delay()
returns interval
language sql
immutable
as $$ select interval '15 minutes' $$;

create function private.assert_valid_match(m public.matches)
returns void
language plpgsql
set search_path = ''
as $$
begin
  if m.title is null or char_length(m.title) not between 3 and 80 then
    raise exception using errcode = 'PT400', message = 'INVALID_TITLE',
      hint = 'Le titre doit contenir entre 3 et 80 caractères.';
  end if;
  if char_length(m.description) > 1000 then
    raise exception using errcode = 'PT400', message = 'INVALID_DESCRIPTION',
      hint = 'La description est limitée à 1000 caractères.';
  end if;
  if m.starts_at is null then
    raise exception using errcode = 'PT400', message = 'INVALID_START_TIME',
      hint = 'La date et l''heure de début sont obligatoires.';
  end if;
  if m.duration_minutes is null or m.duration_minutes not between 15 and 600 then
    raise exception using errcode = 'PT400', message = 'INVALID_DURATION',
      hint = 'La durée doit être comprise entre 15 minutes et 10 heures.';
  end if;
  if m.capacity is null or m.capacity not between 4 and 50 then
    raise exception using errcode = 'PT400', message = 'INVALID_CAPACITY',
      hint = 'La capacité doit être comprise entre 4 et 50 personnes, organisateur inclus.';
  end if;
  if m.format is null then
    raise exception using errcode = 'PT400', message = 'INVALID_FORMAT',
      hint = 'Choisissez un format de match.';
  end if;
  if m.location_mode is null then
    raise exception using errcode = 'PT400', message = 'INVALID_LOCATION',
      hint = 'Indiquez un terrain précis ou un lieu à définir.';
  end if;
  if m.location_name is not null and char_length(m.location_name) not between 2 and 120 then
    raise exception using errcode = 'PT400', message = 'INVALID_LOCATION_NAME',
      hint = 'Le nom du lieu doit contenir entre 2 et 120 caractères.';
  end if;
  if m.location_mode = 'fixed' and (m.location is null or m.location_name is null) then
    raise exception using errcode = 'PT400', message = 'INVALID_LOCATION',
      hint = 'Un terrain précis nécessite un nom et une position.';
  end if;
  if m.estimated_total_cost < 0 or m.estimated_cost_per_player < 0 then
    raise exception using errcode = 'PT400', message = 'INVALID_COST',
      hint = 'Les coûts estimés ne peuvent pas être négatifs.';
  end if;
  if m.currency is null or m.currency !~ '^[A-Z]{3}$' then
    raise exception using errcode = 'PT400', message = 'INVALID_CURRENCY',
      hint = 'Devise invalide.';
  end if;
end;
$$;

-- Applique une saisie JSON (liste blanche de champs) sur un match et la valide.
-- La position se transmet via `latitude` / `longitude`.
create function private.apply_match_input(p_base public.matches, p_input jsonb)
returns public.matches
language plpgsql
set search_path = ''
as $$
declare
  v_allowed constant text[] := array[
    'title', 'description', 'starts_at', 'duration_minutes', 'capacity', 'format',
    'skill_level', 'location_mode', 'location_name', 'latitude', 'longitude',
    'estimated_total_cost', 'estimated_cost_per_player', 'currency'
  ];
  v_unknown text;
  v_match public.matches := p_base;
  v_has_coords boolean := p_input ? 'latitude' or p_input ? 'longitude';
  v_lat double precision;
  v_lng double precision;
begin
  if p_input is null or jsonb_typeof(p_input) <> 'object' then
    raise exception using errcode = 'PT400', message = 'INVALID_INPUT',
      hint = 'Données invalides.';
  end if;

  select k into v_unknown from jsonb_object_keys(p_input) k where k <> all (v_allowed) limit 1;
  if v_unknown is not null then
    raise exception using errcode = 'PT400', message = 'UNKNOWN_FIELD',
      hint = format('Champ non modifiable : %s.', v_unknown);
  end if;

  begin
    v_match := jsonb_populate_record(v_match, p_input - 'latitude' - 'longitude');
    v_lat := (p_input ->> 'latitude')::double precision;
    v_lng := (p_input ->> 'longitude')::double precision;
  exception
    when data_exception then
      raise exception using errcode = 'PT400', message = 'INVALID_FIELD_VALUE',
        hint = 'Une valeur saisie est invalide.';
  end;

  v_match.title := btrim(v_match.title);
  v_match.description := nullif(btrim(v_match.description), '');
  v_match.location_name := nullif(btrim(v_match.location_name), '');
  v_match.currency := upper(v_match.currency);

  if v_has_coords then
    if (v_lat is null) <> (v_lng is null) then
      raise exception using errcode = 'PT400', message = 'INVALID_COORDINATES',
        hint = 'Latitude et longitude doivent être fournies ensemble.';
    end if;
    if v_lat is null then
      v_match.location := null;
    elsif v_lat not between -90 and 90 or v_lng not between -180 and 180 then
      raise exception using errcode = 'PT400', message = 'INVALID_COORDINATES',
        hint = 'Coordonnées invalides.';
    else
      v_match.location := extensions.st_setsrid(extensions.st_makepoint(v_lng, v_lat), 4326)::extensions.geography;
    end if;
  end if;

  if v_match.location_mode = 'to_define' then
    if v_has_coords and v_lat is not null then
      raise exception using errcode = 'PT400', message = 'INVALID_LOCATION',
        hint = 'Un lieu à définir ne peut pas avoir de position précise.';
    end if;
    v_match.location := null;
    v_match.location_status := 'to_confirm';
  elsif v_match.location_mode = 'fixed' then
    v_match.location_status := 'confirmed';
  end if;

  perform private.assert_valid_match(v_match);
  return v_match;
end;
$$;

create function private.assert_start_time_allowed(p_starts_at timestamptz)
returns void
language plpgsql
set search_path = ''
as $$
begin
  if p_starts_at < now() + private.min_start_delay() then
    raise exception using errcode = 'PT422', message = 'START_TOO_SOON',
      hint = 'Le match doit commencer dans au moins 15 minutes.';
  end if;
  if p_starts_at > now() + interval '1 year' then
    raise exception using errcode = 'PT422', message = 'START_TOO_FAR',
      hint = 'Le match doit avoir lieu dans moins d''un an.';
  end if;
end;
$$;

-- Verrouille un match pour une action de l'organisateur et renvoie sa ligne.
create function private.lock_match_for_organizer(p_match_id uuid, p_user_id uuid)
returns public.matches
language plpgsql
set search_path = ''
as $$
declare
  v_match public.matches;
begin
  select * into v_match from public.matches where id = p_match_id for update;
  if not found then
    raise exception using errcode = 'PT404', message = 'MATCH_NOT_FOUND',
      hint = 'Ce match est introuvable.';
  end if;
  if v_match.organizer_id <> p_user_id then
    raise exception using errcode = 'PT403', message = 'NOT_ORGANIZER',
      hint = 'Seul l''organisateur peut effectuer cette action.';
  end if;
  if v_match.status <> 'open' then
    raise exception using errcode = 'PT409', message = 'MATCH_NOT_EDITABLE',
      hint = 'Ce match est annulé ou terminé.';
  end if;
  if v_match.starts_at <= now() then
    raise exception using errcode = 'PT409', message = 'MATCH_ALREADY_STARTED',
      hint = 'Ce match a déjà commencé.';
  end if;
  return v_match;
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC
-- ---------------------------------------------------------------------------

-- Crée un match et y inscrit son organisateur ; renvoie l'id du match.
create function public.create_match(p_match jsonb)
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

  v_match.created_at := now();
  v_match.updated_at := now();
  insert into public.matches select (v_match).*;
  insert into public.participations (match_id, user_id) values (v_match.id, v_uid);

  return v_match.id;
end;
$$;

-- Modifie un match à venir. Seuls les champs présents dans p_changes sont modifiés.
create function public.update_match(p_match_id uuid, p_changes jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.current_active_user_id();
  v_old public.matches := private.lock_match_for_organizer(p_match_id, v_uid);
  v_new public.matches := private.apply_match_input(v_old, p_changes);
  v_active integer;
begin
  if v_new.starts_at is distinct from v_old.starts_at then
    perform private.assert_start_time_allowed(v_new.starts_at);
  end if;

  if v_new.capacity < v_old.capacity then
    select count(*) into v_active
    from public.participations
    where match_id = p_match_id and status = 'active';

    if v_new.capacity < v_active then
      raise exception using errcode = 'PT409', message = 'CAPACITY_BELOW_PARTICIPANTS',
        hint = format('%s personnes sont déjà inscrites : la capacité ne peut pas être inférieure.', v_active);
    end if;
  end if;

  update public.matches set
    title = v_new.title,
    description = v_new.description,
    starts_at = v_new.starts_at,
    duration_minutes = v_new.duration_minutes,
    capacity = v_new.capacity,
    format = v_new.format,
    skill_level = v_new.skill_level,
    location_mode = v_new.location_mode,
    location_status = v_new.location_status,
    location_name = v_new.location_name,
    location = v_new.location,
    estimated_total_cost = v_new.estimated_total_cost,
    estimated_cost_per_player = v_new.estimated_cost_per_player,
    currency = v_new.currency
  where id = p_match_id;
end;
$$;

create function public.cancel_match(p_match_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.current_active_user_id();
begin
  perform private.lock_match_for_organizer(p_match_id, v_uid);

  update public.matches
  set status = 'cancelled', cancelled_at = now()
  where id = p_match_id;
end;
$$;

revoke execute on function public.create_match(jsonb) from public, anon;
revoke execute on function public.update_match(uuid, jsonb) from public, anon;
revoke execute on function public.cancel_match(uuid) from public, anon;
grant execute on function public.create_match(jsonb) to authenticated;
grant execute on function public.update_match(uuid, jsonb) to authenticated;
grant execute on function public.cancel_match(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Tâches serveur
-- ---------------------------------------------------------------------------

-- Passe en `completed` les matchs terminés.
create function private.complete_finished_matches()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  update public.matches
  set status = 'completed'
  where status = 'open'
    and starts_at + make_interval(mins => duration_minutes) <= now();

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

select cron.schedule(
  'complete-finished-matches',
  '*/15 * * * *',
  $$select private.complete_finished_matches()$$
);

-- La demande de suppression de compte annule désormais aussi les matchs à venir
-- organisés par la personne et ses inscriptions aux matchs à venir.
create or replace function public.request_account_deletion()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception using errcode = 'PT401', message = 'AUTH_REQUIRED',
      hint = 'Connectez-vous pour continuer.';
  end if;

  update public.users
  set account_status = 'pending_deletion', deletion_requested_at = now()
  where id = v_uid and account_status in ('active', 'suspended');

  if found then
    update public.matches
    set status = 'cancelled', cancelled_at = now()
    where organizer_id = v_uid and status = 'open' and starts_at > now();

    update public.participations p
    set status = 'cancelled', cancelled_at = now()
    from public.matches m
    where p.match_id = m.id and p.user_id = v_uid and p.status = 'active' and m.starts_at > now();
  end if;

  -- Compte sans profil : rien à conserver, suppression immédiate de l'identité.
  if not exists (select 1 from public.users where id = v_uid) then
    delete from auth.users where id = v_uid;
  end if;
end;
$$;

revoke execute on all functions in schema private from public, anon, authenticated;
