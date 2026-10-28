-- Recherche par distance au terrain et quota de recherche d'adresses.
begin;
select plan(22);

-- Isolation : les matchs déjà présents en base locale ne faussent pas les résultats
-- (la transaction est annulée à la fin du fichier).
delete from public.matches;

select tests.create_user('orga@test.local', 'Orga') as orga \gset
select tests.create_user('joueur@test.local', 'Joueur') as joueur \gset
select tests.create_user('suspendu@test.local', 'Suspendu') as suspendu \gset
update public.users set account_status = 'suspended' where id = :'suspendu';

-- Point de recherche : 47.3941, 0.6848. 0,01° de latitude ≈ 1,1 km.
select tests.authenticate_as(:'orga');
select public.create_match(tests.match_input('{"title": "Sur place"}'));
select public.create_match(tests.match_input('{"title": "A 3 km", "latitude": 47.4211}'));
select public.create_match(tests.match_input('{"title": "A 8 km", "latitude": 47.4661, "skill_level": "beginner"}'));
select public.create_match(tests.match_input('{"title": "A 30 km", "latitude": 47.6641, "skill_level": "advanced"}'));
select public.create_match(tests.match_input('{"title": "Paris", "latitude": 48.8566, "longitude": 2.3522}'));
select public.create_match(tests.match_input(jsonb_build_object(
  'title', 'Dans 10 jours', 'latitude', 47.4031, 'starts_at', now() + interval '10 days'))) as later \gset
select public.create_match(tests.match_input('{"title": "Annulé", "latitude": 47.3951}')) as cancelled \gset
select public.cancel_match(:'cancelled');
select public.create_match(tests.match_input('{"title": "Complet", "latitude": 47.3961, "capacity": 4}')) as full \gset
select public.create_match(tests.match_input('{"title": "Commencé", "latitude": 47.3971}')) as started \gset

reset role;
select tests.add_participant(:'full', tests.create_user('p' || i || '@test.local')) from generate_series(1, 3) i;
update public.matches set starts_at = now() - interval '10 minutes' where id = :'started';

select tests.authenticate_as(:'joueur');

-- Rayon, tri et exclusions
select results_eq(
  $$select title from public.search_matches(47.3941, 0.6848)$$,
  $$values ('Sur place'), ('Complet'), ('Dans 10 jours'), ('A 3 km'), ('A 8 km')$$,
  'rayon par défaut 10 km, du plus proche au plus lointain, sans annulés ni commencés'
);
select results_eq(
  $$select title from public.search_matches(47.3941, 0.6848, p_radius_km => 50) where title like 'A %'$$,
  $$values ('A 3 km'), ('A 8 km'), ('A 30 km')$$,
  'rayon élargi à 50 km'
);
select is((select count(*)::int from public.search_matches(47.3941, 0.6848, p_radius_km => 5)), 4,
  'rayon réduit à 5 km');
select is((select count(*)::int from public.search_matches(48.8566, 2.3522)), 1,
  'la recherche fonctionne partout dans le monde');
select is((select count(*)::int from public.search_matches(-33.8688, 151.2093)), 0,
  'aucun match loin de tout terrain');

-- Filtres
select ok(not exists (select 1 from public.search_matches(47.3941, 0.6848, p_available_only => true) where title = 'Complet'),
  'filtre « places disponibles » : match complet exclu');
select ok(exists (select 1 from public.search_matches(47.3941, 0.6848) where title = 'Complet' and display_status = 'full'),
  'sans filtre, le match complet est visible comme complet');
select results_eq(
  $$select title from public.search_matches(47.3941, 0.6848, p_radius_km => 50, p_skill_level => 'beginner') where title like 'A %'$$,
  $$values ('A 3 km'), ('A 8 km')$$,
  'filtre de niveau : niveau demandé + « tous niveaux »'
);
select ok(not exists (
    select 1 from public.search_matches(47.3941, 0.6848, p_starts_before => now() + interval '7 days')
    where title = 'Dans 10 jours'),
  'filtre de date : avant une date');
select results_eq(
  format('select title from public.search_matches(47.3941, 0.6848, p_starts_after => %L)', now() + interval '7 days'),
  $$values ('Dans 10 jours')$$,
  'filtre de date : après une date'
);
select results_eq(
  $$select title from public.search_matches(47.3941, 0.6848, p_limit => 2, p_offset => 2)$$,
  $$values ('Dans 10 jours'), ('A 3 km')$$,
  'pagination'
);

-- Paramètres bornés
select throws_ok($$select * from public.search_matches(47.39, 0.68, p_radius_km => 0)$$,
  'PT400', 'INVALID_RADIUS', 'rayon nul refusé');
select throws_ok($$select * from public.search_matches(47.39, 0.68, p_radius_km => 101)$$,
  'PT400', 'INVALID_RADIUS', 'rayon supérieur à 100 km refusé');
select throws_ok($$select * from public.search_matches(47.39, 0.68, p_limit => 51)$$,
  'PT400', 'INVALID_PAGINATION', 'page de plus de 50 résultats refusée');
select throws_ok($$select * from public.search_matches(91, 0.68)$$,
  'PT400', 'INVALID_COORDINATES', 'position de recherche invalide refusée');

reset role;
select tests.authenticate_as_anon();
select throws_ok($$select * from public.search_matches(47.39, 0.68)$$, '42501', null,
  'anon ne peut pas rechercher');

-- ---------------------------------------------------------------------------
-- Quota de recherche d'adresses
-- ---------------------------------------------------------------------------
select throws_ok($$select public.consume_geocode_quota()$$, '42501', null, 'anon n''a pas de quota');

reset role;
select tests.authenticate_as(:'suspendu');
select throws_ok($$select public.consume_geocode_quota()$$, 'PT403', 'ACCOUNT_INACTIVE',
  'un compte suspendu ne peut pas rechercher d''adresse');

reset role;
select tests.authenticate_as(:'joueur');
select lives_ok($$select public.consume_geocode_quota()$$, 'première recherche acceptée');
select throws_ok($$select public.consume_geocode_quota()$$, 'PT429', 'GEOCODE_BUSY',
  'au plus une recherche par seconde au total');

reset role;
delete from private.geocode_requests;
insert into private.geocode_requests (user_id, requested_at)
select :'joueur', clock_timestamp() - interval '2 seconds' - i * interval '1 minute' from generate_series(1, 30) i;
select tests.authenticate_as(:'joueur');
select throws_ok($$select public.consume_geocode_quota()$$, 'PT429', 'GEOCODE_RATE_LIMITED',
  'au plus 30 recherches par heure et par personne');
select throws_ok($$select * from private.geocode_requests$$, '42501', null,
  'l''historique des recherches n''est pas lisible');

select * from finish();
rollback;
