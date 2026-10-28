-- Notifications dans l'application et rappels 24 h avant le match.
begin;
select plan(17);

select tests.create_user('orga@test.local', 'Orga') as orga \gset
select tests.create_user('a@test.local', 'Alice') as alice \gset
select tests.create_user('b@test.local', 'Bruno') as bruno \gset

select tests.authenticate_as(:'orga');
select public.create_match(tests.match_input(jsonb_build_object(
  'title', 'Match du rappel', 'starts_at', date_trunc('minute', now()) + interval '3 days'))) as m \gset
reset role;
select tests.authenticate_as(:'alice');
select public.join_match(:'m');
reset role;
select tests.authenticate_as(:'bruno');
select public.join_match(:'m');
reset role;

-- ---------------------------------------------------------------------------
-- Rappels
-- ---------------------------------------------------------------------------
select is((select count(*)::int from public.notifications where match_id = :'m' and type = 'match_reminder'), 3,
  'un rappel par participant, organisateur compris');
select is((select scheduled_for from public.notifications where match_id = :'m' and user_id = :'alice' and type = 'match_reminder'),
  (select starts_at - interval '24 hours' from public.matches where id = :'m'), 'rappel programmé 24 h avant le début');

select tests.authenticate_as(:'alice');
select is((select count(*)::int from public.notifications where type = 'match_reminder'), 0,
  'un rappel futur n''est pas encore visible');
reset role;

select tests.authenticate_as(:'bruno');
select public.leave_match(:'m');
reset role;
select is((select count(*)::int from public.notifications where match_id = :'m' and user_id = :'bruno' and type = 'match_reminder'), 0,
  'la désinscription supprime le rappel');

select tests.authenticate_as(:'orga');
select public.update_match(:'m', jsonb_build_object('starts_at', date_trunc('minute', now()) + interval '5 days'));
reset role;
select is((select scheduled_for from public.notifications where match_id = :'m' and user_id = :'alice' and type = 'match_reminder'),
  date_trunc('minute', now()) + interval '4 days', 'un changement d''horaire replanifie le rappel');
select is((select count(*)::int from public.notifications where user_id = :'alice' and type = 'match_updated'), 1,
  'les participants sont prévenus du changement d''horaire');
select is((select count(*)::int from public.notifications where user_id = :'orga' and type = 'match_updated'), 0,
  'l''organisateur n''est pas notifié de sa propre modification');

select tests.authenticate_as(:'orga');
select public.update_match(:'m', '{"title": "Nouveau titre"}');
reset role;
select is((select count(*)::int from public.notifications where user_id = :'alice' and type = 'match_updated'), 1,
  'un simple changement de titre ne déclenche pas de notification');

select tests.authenticate_as(:'orga');
select public.update_match(:'m', jsonb_build_object('starts_at', now() + interval '20 hours'));
reset role;
select is((select count(*)::int from public.notifications where match_id = :'m' and type = 'match_reminder'), 0,
  'pas de rappel si le moment du rappel est déjà passé');

-- Rappel arrivé à échéance : visible et non lu.
select tests.authenticate_as(:'orga');
select public.create_match(tests.match_input(jsonb_build_object('starts_at', now() + interval '2 days'))) as m2 \gset
reset role;
update public.notifications set scheduled_for = now() - interval '1 minute' where match_id = :'m2' and type = 'match_reminder';
select tests.authenticate_as(:'orga');
select is((select count(*)::int from public.notifications where type = 'match_reminder' and read_at is null), 1,
  'un rappel arrivé à échéance est visible et non lu');

-- ---------------------------------------------------------------------------
-- Annulation et lecture
-- ---------------------------------------------------------------------------
select public.cancel_match(:'m');
reset role;
select tests.authenticate_as(:'alice');
select is((select body from public.notifications where type = 'match_cancelled'),
  '« Nouveau titre » a été annulé par l''organisateur.', 'les participants sont prévenus de l''annulation');
select is((select count(*)::int from public.notifications where user_id <> :'alice'), 0,
  'chacun ne voit que ses propres notifications');
select throws_ok($$update public.notifications set read_at = now()$$, '42501', null,
  'pas de modification directe des notifications');
-- Alice : deux changements d'horaire et l'annulation.
select is(public.mark_notifications_read(), 3, 'tout marquer comme lu');
select is((select count(*)::int from public.notifications where read_at is null), 0, 'plus aucune notification non lue');

reset role;
select tests.authenticate_as_anon();
select throws_ok($$select * from public.notifications$$, '42501', null, 'anon ne lit pas les notifications');
select throws_ok($$select public.mark_notifications_read()$$, '42501', null, 'anon ne marque rien comme lu');

select * from finish();
rollback;
