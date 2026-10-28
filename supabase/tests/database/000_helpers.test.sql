-- Utilitaires partagés par les tests pgTAP (base locale uniquement).
-- Ce fichier est validé (commit) pour que les fichiers suivants puissent s'en servir ;
-- `supabase db reset` les supprime.
begin;
select plan(1);

create schema if not exists tests;
grant usage on schema tests to anon, authenticated;

-- Crée une identité Supabase Auth et renvoie son id.
create or replace function tests.create_auth_user(p_email text)
returns uuid
language sql
security definer
set search_path = ''
as $$
  insert into auth.users (id, instance_id, aud, role, email, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
          p_email, '{}', '{}', now(), now())
  returning id;
$$;

-- Crée une identité avec un profil actif complet.
create or replace function tests.create_user(p_email text, p_display_name text default 'Joueur test')
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid := tests.create_auth_user(p_email);
begin
  insert into public.users (id, display_name, age_confirmed_at) values (v_id, p_display_name, now());
  return v_id;
end;
$$;

-- Inscrit directement un utilisateur à un match (préparation des données de test).
create or replace function tests.add_participant(p_match_id uuid, p_user_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.participations (match_id, user_id) values (p_match_id, p_user_id);
$$;

-- Saisie de match valide, à compléter ou surcharger avec `||`.
create or replace function tests.match_input(p_overrides jsonb default '{}')
returns jsonb
language sql
as $$
  select jsonb_build_object(
    'title', 'Foot du dimanche',
    'starts_at', now() + interval '2 days',
    'duration_minutes', 90,
    'capacity', 10,
    'format', '5v5',
    'location_name', 'Stade de la Vallée',
    'latitude', 47.3941,
    'longitude', 0.6848
  ) || p_overrides;
$$;

-- À appeler en tant que postgres : simule une requête API de cet utilisateur
-- jusqu'à la fin de la transaction ou au prochain `reset role`.
create or replace function tests.authenticate_as(p_user_id uuid)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

-- Simule une requête non authentifiée.
create or replace function tests.authenticate_as_anon()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
  perform set_config('role', 'anon', true);
end;
$$;

select pass('Utilitaires de test installés');
select * from finish();
commit;
