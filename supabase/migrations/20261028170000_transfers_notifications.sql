-- Étape 6 : transfert d'organisation, notifications dans l'application et rappels.
--
-- Décisions du 2026-10-28 : une proposition de transfert expire après 48 h, et au plus tard
-- au coup d'envoi ; les notifications push (FCM) viendront plus tard sur cette même table.
-- Ordre des verrous, partout : ligne du match, puis ligne du transfert.

create type public.transfer_status as enum ('pending', 'accepted', 'declined', 'cancelled', 'expired');
create type public.notification_type as enum (
  'transfer_proposed', 'transfer_accepted', 'transfer_declined', 'transfer_cancelled', 'transfer_expired',
  'match_cancelled', 'match_updated', 'match_reminder'
);

-- Durée de validité d'une proposition de transfert.
create function private.transfer_validity()
returns interval
language sql
immutable
as $$ select interval '48 hours' $$;

-- Délai du rappel avant le coup d'envoi.
create function private.reminder_lead_time()
returns interval
language sql
immutable
as $$ select interval '24 hours' $$;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.organizer_transfers (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches (id) on delete cascade,
  from_user_id uuid not null references public.users (id) on delete cascade,
  to_user_id uuid not null references public.users (id) on delete cascade,
  status public.transfer_status not null default 'pending',
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  responded_at timestamptz,
  constraint organizer_transfers_distinct_users check (from_user_id <> to_user_id),
  constraint organizer_transfers_responded_consistent check ((status = 'pending') = (responded_at is null))
);

-- Une seule proposition en cours par match.
create unique index organizer_transfers_one_pending_idx
  on public.organizer_transfers (match_id) where status = 'pending';
create index organizer_transfers_to_user_idx on public.organizer_transfers (to_user_id) where status = 'pending';
create index organizer_transfers_expiry_idx on public.organizer_transfers (expires_at) where status = 'pending';

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  type public.notification_type not null,
  title text not null,
  body text not null,
  match_id uuid references public.matches (id) on delete cascade,
  transfer_id uuid references public.organizer_transfers (id) on delete set null,
  -- Visible (et envoyable en push) à partir de cette date : sert aux rappels programmés.
  scheduled_for timestamptz not null default now(),
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index notifications_user_idx on public.notifications (user_id, scheduled_for desc);
create index notifications_reminder_idx on public.notifications (match_id, user_id) where type = 'match_reminder';

-- ---------------------------------------------------------------------------
-- Accès en lecture (aucune écriture directe du client)
-- ---------------------------------------------------------------------------

alter table public.organizer_transfers enable row level security;
alter table public.notifications enable row level security;

revoke all on public.organizer_transfers, public.notifications from anon, authenticated;
grant select on public.organizer_transfers, public.notifications to authenticated;

-- Une proposition n'est visible que des deux personnes concernées.
create policy organizer_transfers_select_parties on public.organizer_transfers
  for select to authenticated
  using ((select auth.uid()) in (from_user_id, to_user_id));

-- Ses propres notifications, une fois leur date atteinte (les rappels futurs restent cachés).
create policy notifications_select_own on public.notifications
  for select to authenticated
  using (user_id = (select auth.uid()) and scheduled_for <= now());

-- Propositions avec les noms et le match, pour l'interface.
create view public.transfer_details
with (security_invoker = true)
as
select
  t.id,
  t.match_id,
  m.title as match_title,
  t.from_user_id,
  f.display_name as from_name,
  t.to_user_id,
  r.display_name as to_name,
  t.status,
  t.created_at,
  t.expires_at,
  t.responded_at
from public.organizer_transfers t
join public.matches m on m.id = t.match_id
left join public.public_profiles f on f.id = t.from_user_id
left join public.public_profiles r on r.id = t.to_user_id;

revoke all on public.transfer_details from anon, authenticated;
grant select on public.transfer_details to authenticated;

-- ---------------------------------------------------------------------------
-- Notifications : création (interne)
-- ---------------------------------------------------------------------------

create function private.notify(
  p_user_id uuid,
  p_type public.notification_type,
  p_title text,
  p_body text,
  p_match_id uuid default null,
  p_transfer_id uuid default null
)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.notifications (user_id, type, title, body, match_id, transfer_id)
  values (p_user_id, p_type, p_title, p_body, p_match_id, p_transfer_id);
$$;

create function private.display_name(p_user_id uuid)
returns text
language sql
stable
set search_path = ''
as $$ select coalesce((select display_name from public.users where id = p_user_id), 'Un joueur') $$;

create function private.reminder_body(m public.matches)
returns text
language sql
immutable
as $$ select format('« %s » commence dans 24 h — %s.', m.title, m.location_name) $$;

-- Programme le rappel d'un participant, si son heure n'est pas déjà passée.
create function private.schedule_reminder(p_match public.matches, p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_match.starts_at - private.reminder_lead_time() <= now() then
    return;
  end if;
  if exists (
    select 1 from public.notifications
    where match_id = p_match.id and user_id = p_user_id and type = 'match_reminder'
  ) then
    return;
  end if;
  insert into public.notifications (user_id, type, title, body, match_id, scheduled_for)
  values (p_user_id, 'match_reminder', 'Rappel : votre match approche', private.reminder_body(p_match),
          p_match.id, p_match.starts_at - private.reminder_lead_time());
end;
$$;

-- Annule une proposition en cours (sans notification) et renvoie la ligne, ou null.
create function private.cancel_pending_transfer(p_match_id uuid, p_status public.transfer_status default 'cancelled')
returns public.organizer_transfers
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_transfer public.organizer_transfers;
begin
  update public.organizer_transfers
  set status = p_status, responded_at = now()
  where match_id = p_match_id and status = 'pending'
  returning * into v_transfer;
  return v_transfer;
end;
$$;

-- ---------------------------------------------------------------------------
-- Déclencheurs : rappels et notifications liés aux inscriptions et aux matchs
-- ---------------------------------------------------------------------------

create function private.on_participation_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_match public.matches;
  v_transfer public.organizer_transfers;
begin
  select * into v_match from public.matches where id = new.match_id;

  if new.status = 'active' and (tg_op = 'INSERT' or old.status <> 'active') then
    perform private.schedule_reminder(v_match, new.user_id);
  elsif new.status = 'cancelled' and tg_op = 'UPDATE' and old.status = 'active' then
    -- Plus de rappel à venir pour qui n'est plus inscrit.
    delete from public.notifications
    where match_id = new.match_id and user_id = new.user_id
      and type = 'match_reminder' and scheduled_for > now();

    -- La personne qui part ne peut plus recevoir l'organisation.
    update public.organizer_transfers
    set status = 'cancelled', responded_at = now()
    where match_id = new.match_id and to_user_id = new.user_id and status = 'pending'
    returning * into v_transfer;

    if v_transfer.id is not null then
      perform private.notify(v_transfer.from_user_id, 'transfer_cancelled', 'Proposition annulée',
        format('%s a quitté « %s » : la proposition d''organisation est annulée.',
               private.display_name(new.user_id), v_match.title),
        v_match.id, v_transfer.id);
    end if;
  end if;
  return null;
end;
$$;

create trigger participations_after_change
  after insert or update of status on public.participations
  for each row execute function private.on_participation_change();

create function private.on_match_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_participant uuid;
begin
  if new.status = 'cancelled' and old.status <> 'cancelled' then
    perform private.cancel_pending_transfer(new.id);
    delete from public.notifications
    where match_id = new.id and type = 'match_reminder' and scheduled_for > now();

    for v_participant in
      select user_id from public.participations
      where match_id = new.id and status = 'active' and user_id <> new.organizer_id
    loop
      perform private.notify(v_participant, 'match_cancelled', 'Match annulé',
        format('« %s » a été annulé par l''organisateur.', new.title), new.id);
    end loop;
    return null;
  end if;

  if new.status = 'open' and (
    new.starts_at is distinct from old.starts_at
    or new.duration_minutes is distinct from old.duration_minutes
    or new.location_name is distinct from old.location_name
    or not extensions.st_equals(new.location::extensions.geometry, old.location::extensions.geometry)
  ) then
    for v_participant in
      select user_id from public.participations
      where match_id = new.id and status = 'active' and user_id <> new.organizer_id
    loop
      perform private.notify(v_participant, 'match_updated', 'Match modifié',
        format('L''horaire ou le lieu de « %s » a changé : vérifiez les détails.', new.title), new.id);
    end loop;

    -- Rappels non encore affichés : nouvelle heure et nouveau texte, ou suppression si trop tard.
    if new.starts_at - private.reminder_lead_time() <= now() then
      delete from public.notifications
      where match_id = new.id and type = 'match_reminder' and scheduled_for > now();
    else
      update public.notifications
      set scheduled_for = new.starts_at - private.reminder_lead_time(),
          body = private.reminder_body(new)
      where match_id = new.id and type = 'match_reminder' and scheduled_for > now();

      -- Participants dont le rappel était impossible avec l'ancien horaire.
      perform private.schedule_reminder(new, p.user_id)
      from public.participations p
      where p.match_id = new.id and p.status = 'active';
    end if;
  end if;
  return null;
end;
$$;

create trigger matches_after_change
  after update on public.matches
  for each row execute function private.on_match_change();

-- ---------------------------------------------------------------------------
-- RPC : transfert d'organisation
-- ---------------------------------------------------------------------------

-- L'organisateur propose à un participant actif de reprendre le match ; renvoie l'id de la proposition.
create function public.propose_transfer(p_match_id uuid, p_to_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.current_active_user_id();
  v_match public.matches := private.lock_match_for_organizer(p_match_id, v_uid);
  v_id uuid;
begin
  if p_to_user_id is null or p_to_user_id = v_uid then
    raise exception using errcode = 'PT400', message = 'INVALID_TRANSFER_TARGET',
      hint = 'Choisissez un autre participant.';
  end if;
  if not exists (
    select 1 from public.participations p
    join public.users u on u.id = p.user_id
    where p.match_id = p_match_id and p.user_id = p_to_user_id
      and p.status = 'active' and u.account_status = 'active'
  ) then
    raise exception using errcode = 'PT409', message = 'TRANSFER_TARGET_NOT_PARTICIPANT',
      hint = 'L''organisation ne peut être transmise qu''à un participant inscrit.';
  end if;
  if exists (select 1 from public.organizer_transfers where match_id = p_match_id and status = 'pending') then
    raise exception using errcode = 'PT409', message = 'TRANSFER_ALREADY_PENDING',
      hint = 'Une proposition est déjà en attente pour ce match. Annulez-la d''abord.';
  end if;

  insert into public.organizer_transfers (match_id, from_user_id, to_user_id, expires_at)
  values (p_match_id, v_uid, p_to_user_id, least(now() + private.transfer_validity(), v_match.starts_at))
  returning id into v_id;

  perform private.notify(p_to_user_id, 'transfer_proposed', 'Proposition d''organisation',
    format('%s vous propose d''organiser « %s ».', private.display_name(v_uid), v_match.title),
    p_match_id, v_id);
  return v_id;
end;
$$;

-- L'organisateur retire sa proposition en cours.
create function public.cancel_transfer(p_match_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.current_active_user_id();
  v_match public.matches := private.lock_match_for_organizer(p_match_id, v_uid);
  v_transfer public.organizer_transfers := private.cancel_pending_transfer(p_match_id);
begin
  if v_transfer.id is null then
    raise exception using errcode = 'PT409', message = 'TRANSFER_NOT_PENDING',
      hint = 'Aucune proposition en attente pour ce match.';
  end if;
  perform private.notify(v_transfer.to_user_id, 'transfer_cancelled', 'Proposition annulée',
    format('La proposition d''organiser « %s » a été retirée.', v_match.title),
    p_match_id, v_transfer.id);
end;
$$;

-- Le participant ciblé accepte ou refuse. À l'acceptation, il devient organisateur ;
-- l'ancien organisateur reste inscrit comme joueur.
create function public.respond_transfer(p_transfer_id uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.current_active_user_id();
  v_match_id uuid;
  v_match public.matches;
  v_transfer public.organizer_transfers;
begin
  if p_accept is null then
    raise exception using errcode = 'PT400', message = 'INVALID_INPUT', hint = 'Réponse invalide.';
  end if;

  select match_id into v_match_id from public.organizer_transfers where id = p_transfer_id and to_user_id = v_uid;
  if v_match_id is null then
    raise exception using errcode = 'PT404', message = 'TRANSFER_NOT_FOUND',
      hint = 'Cette proposition est introuvable.';
  end if;

  select * into v_match from public.matches where id = v_match_id for update;
  select * into v_transfer from public.organizer_transfers where id = p_transfer_id for update;

  if v_transfer.status <> 'pending' then
    raise exception using errcode = 'PT409', message = 'TRANSFER_NOT_PENDING',
      hint = 'Cette proposition n''est plus valable.';
  end if;
  if v_transfer.expires_at <= now() or v_match.status <> 'open' or v_match.starts_at <= now() then
    raise exception using errcode = 'PT409', message = 'TRANSFER_EXPIRED',
      hint = 'Cette proposition a expiré.';
  end if;
  -- Garde-fous : l'organisateur n'a pas changé et le participant est toujours inscrit.
  if v_match.organizer_id <> v_transfer.from_user_id or not exists (
    select 1 from public.participations
    where match_id = v_match.id and user_id = v_uid and status = 'active'
  ) then
    raise exception using errcode = 'PT409', message = 'TRANSFER_NOT_PENDING',
      hint = 'Cette proposition n''est plus valable.';
  end if;

  update public.organizer_transfers
  set status = case when p_accept then 'accepted'::public.transfer_status else 'declined' end,
      responded_at = now()
  where id = p_transfer_id;

  if p_accept then
    update public.matches set organizer_id = v_uid where id = v_match.id;
    perform private.notify(v_transfer.from_user_id, 'transfer_accepted', 'Organisation transmise',
      format('%s organise désormais « %s ». Vous restez inscrit comme joueur.',
             private.display_name(v_uid), v_match.title),
      v_match.id, p_transfer_id);
  else
    perform private.notify(v_transfer.from_user_id, 'transfer_declined', 'Proposition refusée',
      format('%s a refusé d''organiser « %s ».', private.display_name(v_uid), v_match.title),
      v_match.id, p_transfer_id);
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC : notifications
-- ---------------------------------------------------------------------------

-- Marque comme lues toutes les notifications visibles de l'utilisateur ; renvoie leur nombre.
create function public.mark_notifications_read()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.current_active_user_id();
  v_count integer;
begin
  update public.notifications
  set read_at = now()
  where user_id = v_uid and read_at is null and scheduled_for <= now();
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke execute on function public.propose_transfer(uuid, uuid) from public, anon;
revoke execute on function public.cancel_transfer(uuid) from public, anon;
revoke execute on function public.respond_transfer(uuid, boolean) from public, anon;
revoke execute on function public.mark_notifications_read() from public, anon;
grant execute on function public.propose_transfer(uuid, uuid) to authenticated;
grant execute on function public.cancel_transfer(uuid) to authenticated;
grant execute on function public.respond_transfer(uuid, boolean) to authenticated;
grant execute on function public.mark_notifications_read() to authenticated;

-- ---------------------------------------------------------------------------
-- Tâche serveur : expiration des propositions
-- ---------------------------------------------------------------------------

create function private.expire_transfers()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_transfer public.organizer_transfers;
  v_count integer := 0;
begin
  for v_transfer in
    update public.organizer_transfers
    set status = 'expired', responded_at = now()
    where status = 'pending' and expires_at <= now()
    returning *
  loop
    perform private.notify(v_transfer.from_user_id, 'transfer_expired', 'Proposition expirée',
      format('%s n''a pas répondu à temps pour « %s ».',
             private.display_name(v_transfer.to_user_id),
             (select title from public.matches where id = v_transfer.match_id)),
      v_transfer.match_id, v_transfer.id);
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

select cron.schedule('expire-organizer-transfers', '*/15 * * * *', $$select private.expire_transfers()$$);

revoke all on all tables in schema private from public, anon, authenticated;
revoke execute on all functions in schema private from public, anon, authenticated;
