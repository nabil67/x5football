-- Étape 2 : profils, statuts de compte, attestation d'âge et suppression de compte.
--
-- Conventions d'erreur des RPC : SQLSTATE `PTxxx` (PostgREST renvoie le statut HTTP xxx),
-- `message` = code machine stable (ex. AGE_NOT_CONFIRMED), `hint` = texte affichable.

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Utilitaires
-- ---------------------------------------------------------------------------

create function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Profils
-- ---------------------------------------------------------------------------

create type public.account_status as enum ('active', 'suspended', 'pending_deletion', 'deleted');

create table public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null
    constraint users_display_name_valid check (
      char_length(display_name) between 2 and 40
      and display_name = btrim(display_name)
      and display_name !~ '[[:cntrl:]]'
    ),
  avatar_url text
    constraint users_avatar_url_valid check (
      avatar_url ~ '^https?://' and char_length(avatar_url) <= 2048
    ),
  -- Attestation « J'ai 18 ans ou plus » : aucune date de naissance n'est conservée.
  age_confirmed_at timestamptz not null,
  account_status public.account_status not null default 'active',
  deletion_requested_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint users_deletion_requested_consistent check (
    account_status <> 'pending_deletion' or deletion_requested_at is not null
  )
);

comment on table public.users is
  'Profil applicatif. L''identité (e-mail, téléphone) reste dans auth.users.';

create trigger users_set_updated_at
  before update on public.users
  for each row execute function private.set_updated_at();

alter table public.users enable row level security;

-- Le client ne lit que son propre profil complet et ne modifie que les champs éditables.
-- Création et changements de statut passent exclusivement par les fonctions ci-dessous.
revoke all on public.users from anon, authenticated;
grant select on public.users to authenticated;
grant update (display_name, avatar_url) on public.users to authenticated;

create policy users_select_own on public.users
  for select to authenticated
  using (id = (select auth.uid()));

create policy users_update_own_when_active on public.users
  for update to authenticated
  using (id = (select auth.uid()) and account_status = 'active')
  with check (id = (select auth.uid()) and account_status = 'active');

-- Informations publiques des autres joueurs (nom, avatar), comptes actifs uniquement.
-- Vue exécutée avec les droits de son propriétaire : elle contourne volontairement la RLS
-- de public.users et n'expose que ces trois colonnes.
create view public.public_profiles
with (security_barrier)
as
select id, display_name, avatar_url
from public.users
where account_status = 'active';

revoke all on public.public_profiles from anon, authenticated;
grant select on public.public_profiles to authenticated;

-- ---------------------------------------------------------------------------
-- Contrôle d'accès commun aux opérations protégées
-- ---------------------------------------------------------------------------

-- Renvoie l'utilisateur courant s'il est authentifié, a complété son profil
-- (donc attesté sa majorité) et que son compte est actif ; lève une erreur sinon.
create function private.current_active_user_id()
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_status public.account_status;
begin
  if v_uid is null then
    raise exception using errcode = 'PT401', message = 'AUTH_REQUIRED',
      hint = 'Connectez-vous pour continuer.';
  end if;

  select account_status into v_status from public.users where id = v_uid;

  if not found then
    raise exception using errcode = 'PT403', message = 'PROFILE_REQUIRED',
      hint = 'Complétez votre profil pour continuer.';
  end if;

  if v_status <> 'active' then
    raise exception using errcode = 'PT403', message = 'ACCOUNT_INACTIVE',
      hint = 'Votre compte ne permet pas cette action.';
  end if;

  return v_uid;
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC : création du profil
-- ---------------------------------------------------------------------------

create function public.complete_profile(p_display_name text, p_is_adult boolean)
returns public.users
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_profile public.users;
begin
  if v_uid is null then
    raise exception using errcode = 'PT401', message = 'AUTH_REQUIRED',
      hint = 'Connectez-vous pour continuer.';
  end if;

  if p_is_adult is not true then
    raise exception using errcode = 'PT422', message = 'AGE_NOT_CONFIRMED',
      hint = 'L''application est réservée aux personnes de 18 ans ou plus.';
  end if;

  begin
    insert into public.users (id, display_name, age_confirmed_at)
    values (v_uid, btrim(p_display_name), now())
    on conflict (id) do nothing
    returning * into v_profile;
  exception
    when check_violation or not_null_violation then
      raise exception using errcode = 'PT400', message = 'INVALID_DISPLAY_NAME',
        hint = 'Le nom doit contenir entre 2 et 40 caractères.';
  end;

  if v_profile.id is null then
    raise exception using errcode = 'PT409', message = 'PROFILE_ALREADY_EXISTS',
      hint = 'Votre profil existe déjà.';
  end if;

  return v_profile;
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC : suppression de compte
-- ---------------------------------------------------------------------------

-- L'accès est bloqué immédiatement ; la suppression effective est faite par
-- private.purge_pending_deletions() (tâche planifiée). Un compte suspendu peut
-- aussi demander sa suppression.
create function public.request_account_deletion()
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

  -- Compte sans profil : rien à conserver, suppression immédiate de l'identité.
  if not exists (select 1 from public.users where id = v_uid) then
    delete from auth.users where id = v_uid;
  end if;
end;
$$;

-- Supprime l'identité (auth.users) des comptes en attente de suppression depuis
-- au moins p_grace ; le profil et les sessions suivent par cascade.
-- Les étapes suivantes compléteront ce traitement (matchs organisés, jetons push…).
create function private.purge_pending_deletions(p_grace interval default interval '0')
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  delete from auth.users u
  using public.users p
  where p.id = u.id
    and p.account_status = 'pending_deletion'
    and p.deletion_requested_at <= now() - p_grace;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- ---------------------------------------------------------------------------
-- Droits d'exécution (Supabase accorde EXECUTE à anon/authenticated par défaut)
-- ---------------------------------------------------------------------------

revoke execute on function public.complete_profile(text, boolean) from public, anon;
revoke execute on function public.request_account_deletion() from public, anon;
grant execute on function public.complete_profile(text, boolean) to authenticated;
grant execute on function public.request_account_deletion() to authenticated;

revoke execute on all functions in schema private from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Planification
-- ---------------------------------------------------------------------------

create extension if not exists pg_cron with schema pg_catalog;

select cron.schedule(
  'purge-pending-deletions',
  '17 * * * *',
  $$select private.purge_pending_deletions()$$
);
