-- Matchs : création, lecture, modification, annulation et règles d'accès.
begin;
select plan(55);

select tests.create_user('orga@test.local', 'Orga') as orga \gset
select tests.create_user('joueur@test.local', 'Joueur') as joueur \gset
select tests.create_user('suspendu@test.local', 'Suspendu') as suspendu \gset
update public.users set account_status = 'suspended' where id = :'suspendu';

select ok((select relrowsecurity from pg_class where oid = 'public.matches'::regclass), 'RLS activée sur matches');
select ok((select relrowsecurity from pg_class where oid = 'public.participations'::regclass), 'RLS activée sur participations');

-- ---------------------------------------------------------------------------
-- Accès non authentifié / compte inactif
-- ---------------------------------------------------------------------------
select tests.authenticate_as_anon();
select throws_ok($$select * from public.match_details$$, '42501', null, 'anon ne peut pas lire les matchs');
select throws_ok($$select public.create_match(tests.match_input())$$, '42501', null, 'anon ne peut pas créer de match');

reset role;
select tests.authenticate_as(:'suspendu');
select throws_ok($$select public.create_match(tests.match_input())$$, 'PT403', 'ACCOUNT_INACTIVE',
  'un compte suspendu ne peut pas créer de match');

-- ---------------------------------------------------------------------------
-- Création
-- ---------------------------------------------------------------------------
reset role;
select tests.authenticate_as(:'orga');

select public.create_match(tests.match_input()) as m1 \gset

select is((select participant_count from public.match_details where id = :'m1'), 1,
  'l''organisateur est inscrit automatiquement');
select is((select spots_left from public.match_details where id = :'m1'), 9,
  'capacité 10 : 9 places restantes');
select results_eq(
  format('select location_name, round(latitude::numeric, 4), round(longitude::numeric, 4) from public.match_details where id = %L', :'m1'),
  $$values ('Stade de la Vallée', 47.3941::numeric, 0.6848::numeric)$$,
  'le terrain (nom et position) est restitué'
);
select is((select display_status from public.match_details where id = :'m1'), 'open', 'match ouvert');
select ok((select is_organizer and is_participant from public.match_details where id = :'m1'),
  'l''organisateur se voit organisateur et participant');
select is((select currency from public.matches where id = :'m1'), 'EUR', 'devise par défaut EUR');
select is((select skill_level::text from public.matches where id = :'m1'), 'all', 'niveau par défaut : tous niveaux');

select throws_ok($$select public.create_match(tests.match_input('{"capacity": 3}'))$$,
  'PT400', 'INVALID_CAPACITY', 'capacité 3 refusée');
select throws_ok($$select public.create_match(tests.match_input('{"capacity": 51}'))$$,
  'PT400', 'INVALID_CAPACITY', 'capacité supérieure à 50 refusée');
select throws_ok($$select public.create_match(tests.match_input('{"duration_minutes": 0}'))$$,
  'PT400', 'INVALID_DURATION', 'durée nulle refusée');
select throws_ok($$select public.create_match(tests.match_input('{"title": "  "}'))$$,
  'PT400', 'INVALID_TITLE', 'titre vide refusé');
select throws_ok($$select public.create_match(tests.match_input('{"format": "6v6"}'))$$,
  'PT400', 'INVALID_FIELD_VALUE', 'format inconnu refusé');
select throws_ok($$select public.create_match(tests.match_input('{"estimated_total_cost": -5}'))$$,
  'PT400', 'INVALID_COST', 'coût négatif refusé');
select throws_ok($$select public.create_match(tests.match_input('{"organizer_id": "00000000-0000-0000-0000-000000000000"}'))$$,
  'PT400', 'UNKNOWN_FIELD', 'impossible de choisir l''organisateur');
select throws_ok($$select public.create_match(tests.match_input('{"status": "completed"}'))$$,
  'PT400', 'UNKNOWN_FIELD', 'impossible de choisir le statut');
select throws_ok(
  format('select public.create_match(tests.match_input(%L))', jsonb_build_object('starts_at', now() + interval '10 minutes')),
  'PT422', 'START_TOO_SOON', 'match commençant dans moins de 15 minutes refusé');
select throws_ok(
  format('select public.create_match(tests.match_input(%L))', jsonb_build_object('starts_at', now() - interval '1 day')),
  'PT422', 'START_TOO_SOON', 'match dans le passé refusé');

-- Lieu obligatoire
select throws_ok($$select public.create_match(tests.match_input() - 'latitude' - 'longitude')$$,
  'PT400', 'INVALID_LOCATION', 'terrain sans position refusé');
select throws_ok($$select public.create_match(tests.match_input('{"latitude": null, "longitude": null}'))$$,
  'PT400', 'INVALID_LOCATION', 'position vide refusée');
select throws_ok($$select public.create_match(tests.match_input() - 'location_name')$$,
  'PT400', 'INVALID_LOCATION_NAME', 'terrain sans nom refusé');
select throws_ok($$select public.create_match(tests.match_input('{"location_mode": "to_define"}'))$$,
  'PT400', 'UNKNOWN_FIELD', 'le mode « lieu à définir » n''existe plus');
select throws_ok($$select public.create_match(tests.match_input('{"latitude": 95}'))$$,
  'PT400', 'INVALID_COORDINATES', 'latitude hors limites refusée');
select throws_ok($$select public.create_match(tests.match_input('{"longitude": null}'))$$,
  'PT400', 'INVALID_COORDINATES', 'latitude sans longitude refusée');

select public.create_match(tests.match_input('{"capacity": 6}')) as m2 \gset

-- Écriture directe interdite
select throws_ok($$insert into public.matches (organizer_id, title, starts_at, duration_minutes, capacity, format, location_name, location)
  values (auth.uid(), 'Direct', now() + interval '1 day', 90, 10, '5v5', 'Stade', 'POINT(0.69 47.39)')$$,
  '42501', null, 'insertion directe dans matches interdite');
select throws_ok(format('update public.matches set capacity = 4 where id = %L', :'m1'),
  '42501', null, 'modification directe d''un match interdite');
select throws_ok(format('insert into public.participations (match_id, user_id) values (%L, auth.uid())', :'m1'),
  '42501', null, 'insertion directe d''une participation interdite');

-- ---------------------------------------------------------------------------
-- Modification
-- ---------------------------------------------------------------------------
reset role;
select tests.authenticate_as(:'joueur');
select throws_ok(format('select public.update_match(%L, %L)', :'m1', '{"title": "Piraté"}'),
  'PT403', 'NOT_ORGANIZER', 'un non-organisateur ne peut pas modifier le match');
select throws_ok(format('select public.cancel_match(%L)', :'m1'),
  'PT403', 'NOT_ORGANIZER', 'un non-organisateur ne peut pas annuler le match');
select is((select is_organizer from public.match_details where id = :'m1'), false,
  'un autre joueur ne se voit pas organisateur');

reset role;
select tests.authenticate_as(:'orga');
select throws_ok(format('select public.update_match(%L, %L)', gen_random_uuid(), '{"title": "X"}'),
  'PT404', 'MATCH_NOT_FOUND', 'match inexistant');

select lives_ok(format('select public.update_match(%L, %L)', :'m1', '{"title": "Foot du samedi"}'),
  'l''organisateur modifie le titre');
select is((select title from public.matches where id = :'m1'), 'Foot du samedi', 'titre modifié');
select is((select format::text from public.matches where id = :'m1'), '5v5', 'les champs absents ne changent pas');

select lives_ok(format('select public.update_match(%L, %L)', :'m1',
  '{"location_name": "City stade", "latitude": 48.8566, "longitude": 2.3522}'),
  'le terrain peut être changé');
select is((select round(latitude::numeric, 4) from public.match_details where id = :'m1'), 48.8566::numeric,
  'nouvelle position enregistrée');
select throws_ok(format('select public.update_match(%L, %L)', :'m1', '{"latitude": null, "longitude": null}'),
  'PT400', 'INVALID_LOCATION', 'la position ne peut pas être retirée');

select throws_ok(format('select public.update_match(%L, %L)', :'m1',
  jsonb_build_object('starts_at', now() + interval '5 minutes')),
  'PT422', 'START_TOO_SOON', 'replanification trop proche refusée');

-- Capacité et participants : m2 (capacité 6) reçoit 4 joueurs de plus → 5 actifs.
reset role;
select tests.add_participant(:'m2', tests.create_user('p' || i || '@test.local')) from generate_series(1, 4) i;
select tests.authenticate_as(:'orga');

select throws_ok(format('select public.update_match(%L, %L)', :'m2', '{"capacity": 4}'),
  'PT409', 'CAPACITY_BELOW_PARTICIPANTS', 'capacité inférieure au nombre d''inscrits refusée');
select lives_ok(format('select public.update_match(%L, %L)', :'m2', '{"capacity": 5}'),
  'capacité égale au nombre d''inscrits acceptée');
select is((select display_status from public.match_details where id = :'m2'), 'full', 'match complet calculé à la lecture');

select is((select count(*)::int from public.match_participants where match_id = :'m2'), 5,
  'la liste des participants est visible');
select is((select display_name from public.match_participants where match_id = :'m2' and is_organizer), 'Orga',
  'l''organisateur est identifié dans la liste');

reset role;
select throws_ok(format('select tests.add_participant(%L, %L)', :'m1', :'orga'), '23505', null,
  'deux participations actives au même match sont impossibles');
select tests.authenticate_as(:'orga');

-- ---------------------------------------------------------------------------
-- Annulation
-- ---------------------------------------------------------------------------
select lives_ok(format('select public.cancel_match(%L)', :'m1'), 'l''organisateur annule le match');
select is((select display_status from public.match_details where id = :'m1'), 'cancelled', 'match annulé');
select throws_ok(format('select public.update_match(%L, %L)', :'m1', '{"title": "Encore"}'),
  'PT409', 'MATCH_NOT_EDITABLE', 'un match annulé ne peut plus être modifié');

-- ---------------------------------------------------------------------------
-- Matchs terminés
-- ---------------------------------------------------------------------------
reset role;
update public.matches set starts_at = now() - interval '3 hours' where id = :'m2';
select private.complete_finished_matches();
select is((select status::text from public.matches where id = :'m2'), 'completed', 'un match passé est marqué terminé');

-- ---------------------------------------------------------------------------
-- Suppression de compte
-- ---------------------------------------------------------------------------
select tests.authenticate_as(:'orga');
select public.create_match(tests.match_input()) as m3 \gset
reset role;
select tests.authenticate_as(:'joueur');
select public.create_match(tests.match_input()) as m4 \gset
reset role;
select tests.add_participant(:'m4', :'orga');

select tests.authenticate_as(:'orga');
select public.request_account_deletion();
reset role;
select is((select status::text from public.matches where id = :'m3'), 'cancelled',
  'la suppression de compte annule les matchs à venir organisés');
select is((select count(*)::int from public.participations where match_id = :'m4' and user_id = :'orga' and status = 'active'), 0,
  'la suppression de compte libère les places réservées');

select private.purge_pending_deletions();
select is((select count(*)::int from public.matches where organizer_id = :'orga'), 0,
  'la purge supprime les matchs de la personne');

select * from finish();
rollback;
