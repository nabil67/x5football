-- Concurrence : plusieurs personnes tentent de prendre la dernière place au même instant.
--
-- Chaque tentative passe par une connexion distincte (dblink) et sa propre transaction,
-- comme deux téléphones appelant l'API en même temps. Les données de départ doivent donc
-- être validées (commit) : elles sont créées puis supprimées par une connexion annexe.
begin;
select plan(6);

create extension if not exists dblink with schema extensions;

-- Connexion à la base courante par l'adresse réseau du serveur (authentification par mot de passe,
-- exigée par dblink ; mot de passe de la stack locale Supabase uniquement).
create function pg_temp.conn_string()
returns text
language sql
as $$
  select format('dbname=%s user=postgres password=postgres host=%s port=%s',
    current_database(), host(inet_server_addr()), inet_server_port())
$$;

-- Attend la fin de la requête asynchrone et renvoie le premier message d'erreur, ou 'OK'.
create function pg_temp.wait_for(p_conn text)
returns text
language plpgsql
as $$
declare
  v_rows integer;
  v_error text := 'OK';
begin
  loop
    select count(*) into v_rows from extensions.dblink_get_result(p_conn, false) as t(r text);
    if v_error = 'OK' then
      v_error := extensions.dblink_error_message(p_conn);
    end if;
    exit when v_rows = 0 and not extensions.dblink_is_busy(p_conn)::boolean;
  end loop;
  return v_error;
end;
$$;

select extensions.dblink_connect('setup', pg_temp.conn_string());
select extensions.dblink_exec('setup', $$delete from auth.users where email like 'race-%@test.local'$$);

-- Match de 4 places : l'organisateur + 2 inscrits, il reste 1 place pour 3 candidats.
select extensions.dblink_exec('setup', $$
  do $setup$
  declare
    v_orga uuid := tests.create_user('race-orga@test.local', 'Orga');
    v_match uuid;
  begin
    insert into public.matches (organizer_id, title, starts_at, duration_minutes, capacity, format, location_name, location)
    values (v_orga, 'Course à la dernière place', now() + interval '1 day', 90, 4, '5v5', 'Stade',
            extensions.st_setsrid(extensions.st_makepoint(0.6848, 47.3941), 4326)::extensions.geography)
    returning id into v_match;
    perform tests.add_participant(v_match, v_orga);
    perform tests.add_participant(v_match, tests.create_user('race-p1@test.local'));
    perform tests.add_participant(v_match, tests.create_user('race-p2@test.local'));
    perform tests.create_user('race-a@test.local');
    perform tests.create_user('race-b@test.local');
    perform tests.create_user('race-c@test.local');
  end
  $setup$
$$);

select id as race_match from public.matches where title = 'Course à la dernière place' \gset

-- Chaque candidat : inscription puis pause de 0,5 s avant validation, transaction ouverte.
-- La première inscription garde le verrou pendant la pause : les autres attendent,
-- puis constatent que le match est complet.
select extensions.dblink_connect(c, pg_temp.conn_string()) from unnest(array['race_a', 'race_b', 'race_c']) c;
select extensions.dblink_send_query(
  'race_' || who,
  format(
    'begin; select tests.authenticate_as(%L); select public.join_match(%L); select pg_sleep(0.5); commit;',
    (select id from auth.users where email = 'race-' || who || '@test.local'),
    :'race_match'
  )
)
from unnest(array['a', 'b', 'c']) who;

create temporary table race_results as
select c as conn, pg_temp.wait_for(c) as error
from unnest(array['race_a', 'race_b', 'race_c']) c;

select is((select count(*)::int from race_results where error = 'OK'), 1,
  'une seule des trois tentatives simultanées réussit');
select is((select count(*)::int from race_results where error like '%MATCH_FULL%'), 2,
  'les deux autres reçoivent « match complet »');

select is(
  (select count(*)::int from extensions.dblink('setup',
    format($$select 1 from public.participations where match_id = %L and status = 'active'$$, :'race_match')
  ) as t(x int)),
  4,
  'le match compte exactement 4 participants actifs : la capacité n''est jamais dépassée'
);

-- Même personne, deux demandes simultanées : une seule inscription active.
-- Les connexions refusées sont restées dans une transaction en échec : on l'annule.
select extensions.dblink_exec(c, 'rollback') from unnest(array['race_a', 'race_b', 'race_c']) c;
select extensions.dblink_exec('setup', format(
  $$update public.participations set status = 'cancelled', cancelled_at = now()
    where match_id = %L and user_id in (select id from auth.users where email like 'race-_@test.local')$$,
  :'race_match'));
select extensions.dblink_send_query(
  c,
  format(
    'begin; select tests.authenticate_as(%L); select public.join_match(%L); select pg_sleep(0.3); commit;',
    (select id from auth.users where email = 'race-a@test.local'),
    :'race_match'
  )
)
from unnest(array['race_a', 'race_b']) c;
select is(
  (select count(*)::int from unnest(array['race_a', 'race_b']) c where pg_temp.wait_for(c) like '%ALREADY_JOINED%'),
  1,
  'deux demandes simultanées de la même personne : une seule inscription'
);

-- Transfert : la personne ciblée accepte pendant que l'organisateur retire la proposition.
select extensions.dblink_exec(c, 'rollback') from unnest(array['race_a', 'race_b']) c;
select extensions.dblink_exec('setup', format(
  $$begin; select tests.authenticate_as(%L); select public.propose_transfer(%L, %L); commit;$$,
  (select id from auth.users where email = 'race-orga@test.local'),
  :'race_match',
  (select id from auth.users where email = 'race-a@test.local')));
select id as race_transfer from extensions.dblink('setup',
  format($$select id from public.organizer_transfers where match_id = %L and status = 'pending'$$, :'race_match')
) as t(id uuid) \gset

select extensions.dblink_send_query('race_a', format(
  'begin; select tests.authenticate_as(%L); select public.respond_transfer(%L, true); select pg_sleep(0.3); commit;',
  (select id from auth.users where email = 'race-a@test.local'), :'race_transfer'));
select extensions.dblink_send_query('race_b', format(
  'begin; select tests.authenticate_as(%L); select public.cancel_transfer(%L); select pg_sleep(0.3); commit;',
  (select id from auth.users where email = 'race-orga@test.local'), :'race_match'));

create temporary table transfer_race as
select c as conn, pg_temp.wait_for(c) as error from unnest(array['race_a', 'race_b']) c;

select is((select count(*)::int from transfer_race where error = 'OK'), 1,
  'acceptation et retrait simultanés : une seule des deux actions aboutit');

select ok(
  (select (t.status = 'accepted' and m.organizer = t.to_user)
       or (t.status = 'cancelled' and m.organizer = t.from_user)
   from extensions.dblink('setup', format(
     $$select t.status::text, t.from_user_id, t.to_user_id, m.organizer_id
       from public.organizer_transfers t join public.matches m on m.id = t.match_id where t.id = %L$$,
     :'race_transfer')) as t(status text, from_user uuid, to_user uuid, organizer uuid)
   cross join lateral (select t.organizer) m),
  'l''état final est cohérent : organisateur et proposition concordent'
);

select extensions.dblink_disconnect(c) from unnest(array['race_a', 'race_b', 'race_c']) c;
select extensions.dblink_exec('setup', $$delete from auth.users where email like 'race-%@test.local'$$);
select extensions.dblink_disconnect('setup');

select * from finish();
rollback;
