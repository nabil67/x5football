-- Étape 4 : lieu obligatoire et recherche par distance.
--
-- Décision du 2026-10-28 : un match a toujours un terrain précis (nom + position).
-- Le mode « lieu à définir » disparaît ; la recherche filtre par distance au terrain.

-- Aucun environnement hors local à ce jour : les matchs de développement sans position
-- ne peuvent pas recevoir de lieu inventé, ils sont supprimés.
delete from public.matches where location is null or location_name is null;

drop view public.match_details;

alter table public.matches
  drop constraint matches_location_consistent,
  drop column location_mode,
  drop column location_status,
  alter column location_name set not null,
  alter column location set not null;

drop type public.location_mode;
drop type public.location_status;

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

revoke all on public.match_details from anon, authenticated;
grant select on public.match_details to authenticated;

-- ---------------------------------------------------------------------------
-- Validation : le terrain (nom + position) est obligatoire
-- ---------------------------------------------------------------------------

create or replace function private.assert_valid_match(m public.matches)
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
  if m.location_name is null or char_length(m.location_name) not between 2 and 120 then
    raise exception using errcode = 'PT400', message = 'INVALID_LOCATION_NAME',
      hint = 'Le nom du terrain doit contenir entre 2 et 120 caractères.';
  end if;
  if m.location is null then
    raise exception using errcode = 'PT400', message = 'INVALID_LOCATION',
      hint = 'Indiquez la position du terrain.';
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

create or replace function private.apply_match_input(p_base public.matches, p_input jsonb)
returns public.matches
language plpgsql
set search_path = ''
as $$
declare
  v_allowed constant text[] := array[
    'title', 'description', 'starts_at', 'duration_minutes', 'capacity', 'format',
    'skill_level', 'location_name', 'latitude', 'longitude',
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

  perform private.assert_valid_match(v_match);
  return v_match;
end;
$$;

create or replace function public.update_match(p_match_id uuid, p_changes jsonb)
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
    location_name = v_new.location_name,
    location = v_new.location,
    estimated_total_cost = v_new.estimated_total_cost,
    estimated_cost_per_player = v_new.estimated_cost_per_player,
    currency = v_new.currency
  where id = p_match_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Recherche par distance au terrain
-- ---------------------------------------------------------------------------

-- Matchs ouverts et à venir dans un rayon autour d'un point, du plus proche au plus lointain.
-- Le point de recherche (position de l'utilisateur ou lieu saisi) n'est jamais enregistré.
-- Le filtre de niveau inclut toujours les matchs « tous niveaux ».
create function public.search_matches(
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
  order by extensions.st_distance(m.location, v_center), m.starts_at, m.id
  limit p_limit offset p_offset;
end;
$$;

revoke execute on function public.search_matches(
  double precision, double precision, double precision, timestamptz, timestamptz,
  boolean, public.skill_level, integer, integer
) from public, anon;
grant execute on function public.search_matches(
  double precision, double precision, double precision, timestamptz, timestamptz,
  boolean, public.skill_level, integer, integer
) to authenticated;

-- ---------------------------------------------------------------------------
-- Quota de recherche d'adresses (Edge Function `geocode`, service OpenStreetMap Nominatim)
-- ---------------------------------------------------------------------------

create table private.geocode_requests (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.users (id) on delete cascade,
  requested_at timestamptz not null default now()
);

create index geocode_requests_user_idx on private.geocode_requests (user_id, requested_at);
create index geocode_requests_time_idx on private.geocode_requests (requested_at);

-- Réserve une recherche d'adresse pour l'utilisateur courant.
-- Limites : 30 par heure et par personne ; 1 par seconde au total (règle d'usage de Nominatim).
create function public.consume_geocode_quota()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.current_active_user_id();
begin
  -- Sérialise les réservations pour appliquer la limite globale sans course.
  perform pg_advisory_xact_lock(hashtext('geocode_quota'));

  if (select count(*) from private.geocode_requests
      where user_id = v_uid and requested_at > clock_timestamp() - interval '1 hour') >= 30 then
    raise exception using errcode = 'PT429', message = 'GEOCODE_RATE_LIMITED',
      hint = 'Trop de recherches d''adresse. Réessayez dans un moment.';
  end if;

  if exists (select 1 from private.geocode_requests
             where requested_at > clock_timestamp() - interval '1 second') then
    raise exception using errcode = 'PT429', message = 'GEOCODE_BUSY',
      hint = 'Le service de recherche est occupé. Réessayez dans un instant.';
  end if;

  delete from private.geocode_requests where requested_at < clock_timestamp() - interval '1 day';
  insert into private.geocode_requests (user_id, requested_at) values (v_uid, clock_timestamp());
end;
$$;

revoke execute on function public.consume_geocode_quota() from public, anon;
grant execute on function public.consume_geocode_quota() to authenticated;

revoke all on all tables in schema private from public, anon, authenticated;
revoke execute on all functions in schema private from public, anon, authenticated;
