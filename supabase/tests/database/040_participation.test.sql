-- Inscriptions : rejoindre et quitter un match.
begin;
select plan(26);

select tests.create_user('orga@test.local', 'Orga') as orga \gset
select tests.create_user('a@test.local', 'Alice') as alice \gset
select tests.create_user('b@test.local', 'Bruno') as bruno \gset
select tests.create_user('c@test.local', 'Chloé') as chloe \gset
select tests.create_user('d@test.local', 'David') as david \gset
select tests.create_user('suspendu@test.local', 'Suspendu') as suspendu \gset
update public.users set account_status = 'suspended' where id = :'suspendu';

select tests.authenticate_as(:'orga');
-- Capacité 4 : l'organisateur + 3 places.
select public.create_match(tests.match_input('{"capacity": 4}')) as m \gset
select public.create_match(tests.match_input()) as annule \gset
select public.cancel_match(:'annule');
select public.create_match(tests.match_input()) as commence \gset
select public.create_match(tests.match_input()) as termine \gset
reset role;
update public.matches set starts_at = now() - interval '10 minutes' where id = :'commence';
update public.matches set status = 'completed' where id = :'termine';

-- ---------------------------------------------------------------------------
-- Accès
-- ---------------------------------------------------------------------------
select tests.authenticate_as_anon();
select throws_ok(format('select public.join_match(%L)', :'m'), '42501', null, 'anon ne peut pas rejoindre');
select throws_ok(format('select public.leave_match(%L)', :'m'), '42501', null, 'anon ne peut pas quitter');

reset role;
select tests.authenticate_as(:'suspendu');
select throws_ok(format('select public.join_match(%L)', :'m'), 'PT403', 'ACCOUNT_INACTIVE',
  'un compte suspendu ne peut pas rejoindre');

-- ---------------------------------------------------------------------------
-- Rejoindre
-- ---------------------------------------------------------------------------
reset role;
select tests.authenticate_as(:'alice');
select lives_ok(format('select public.join_match(%L)', :'m'), 'Alice rejoint le match');
select ok((select is_participant from public.match_details where id = :'m'), 'Alice se voit inscrite');
select is((select spots_left from public.match_details where id = :'m'), 2, 'une place de moins');
select throws_ok(format('select public.join_match(%L)', :'m'), 'PT409', 'ALREADY_JOINED',
  'impossible de rejoindre deux fois');

select throws_ok(format('select public.join_match(%L)', gen_random_uuid()), 'PT404', 'MATCH_NOT_FOUND',
  'match inexistant');
select throws_ok(format('select public.join_match(%L)', :'annule'), 'PT409', 'MATCH_CANCELLED',
  'un match annulé refuse les inscriptions');
select throws_ok(format('select public.join_match(%L)', :'commence'), 'PT409', 'MATCH_ALREADY_STARTED',
  'un match commencé refuse les inscriptions');
select throws_ok(format('select public.join_match(%L)', :'termine'), 'PT409', 'MATCH_COMPLETED',
  'un match terminé refuse les inscriptions');

reset role;
select tests.authenticate_as(:'bruno');
select lives_ok(format('select public.join_match(%L)', :'m'), 'Bruno rejoint le match');
reset role;
select tests.authenticate_as(:'chloe');
select lives_ok(format('select public.join_match(%L)', :'m'), 'Chloé prend la dernière place');
select is((select display_status from public.match_details where id = :'m'), 'full', 'le match est complet');

reset role;
select tests.authenticate_as(:'david');
select throws_ok(format('select public.join_match(%L)', :'m'), 'PT409', 'MATCH_FULL',
  'un match complet refuse toute inscription supplémentaire');

-- ---------------------------------------------------------------------------
-- Quitter
-- ---------------------------------------------------------------------------
select throws_ok(format('select public.leave_match(%L)', :'m'), 'PT409', 'NOT_PARTICIPANT',
  'impossible de quitter un match sans y être inscrit');

reset role;
select tests.authenticate_as(:'orga');
select throws_ok(format('select public.leave_match(%L)', :'m'), 'PT409', 'ORGANIZER_CANNOT_LEAVE',
  'l''organisateur ne peut pas quitter son match');

reset role;
select tests.authenticate_as(:'bruno');
select lives_ok(format('select public.leave_match(%L)', :'m'), 'Bruno quitte le match');
select is((select spots_left from public.match_details where id = :'m'), 1, 'la désinscription libère une place');
select is((select display_status from public.match_details where id = :'m'), 'open', 'le match redevient ouvert');
select is((select status::text from public.participations where match_id = :'m' and user_id = :'bruno'), 'cancelled',
  'Bruno voit sa désinscription dans son historique');

reset role;
select tests.authenticate_as(:'alice');
select is((select count(*)::int from public.participations where match_id = :'m' and user_id = :'bruno'), 0,
  'l''historique des désinscriptions d''autrui n''est pas visible');

reset role;
select tests.authenticate_as(:'bruno');
select lives_ok(format('select public.join_match(%L)', :'m'), 'Bruno peut se réinscrire s''il reste de la place');
select is((select count(*)::int from public.participations where match_id = :'m' and user_id = :'bruno'), 2,
  'l''historique conserve l''ancienne participation');

reset role;
select tests.authenticate_as(:'orga');
select public.cancel_match(:'m');
reset role;
select tests.authenticate_as(:'bruno');
select throws_ok(format('select public.leave_match(%L)', :'m'), 'PT409', 'MATCH_CANCELLED',
  'impossible de quitter un match annulé');
select throws_ok(format('select public.leave_match(%L)', :'commence'), 'PT409', 'MATCH_ALREADY_STARTED',
  'impossible de quitter après le coup d''envoi');

select * from finish();
rollback;
