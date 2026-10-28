-- Transfert d'organisation : proposition, acceptation, refus, annulation, expiration.
begin;
select plan(32);

select tests.create_user('orga@test.local', 'Orga') as orga \gset
select tests.create_user('a@test.local', 'Alice') as alice \gset
select tests.create_user('b@test.local', 'Bruno') as bruno \gset
select tests.create_user('x@test.local', 'Extérieur') as dehors \gset

select tests.authenticate_as(:'orga');
select public.create_match(tests.match_input('{"title": "Match à transmettre"}')) as m \gset
reset role;
select tests.add_participant(:'m', :'alice');
select tests.add_participant(:'m', :'bruno');

select ok((select relrowsecurity from pg_class where oid = 'public.organizer_transfers'::regclass),
  'RLS activée sur organizer_transfers');

-- ---------------------------------------------------------------------------
-- Proposition
-- ---------------------------------------------------------------------------
select tests.authenticate_as(:'alice');
select throws_ok(format('select public.propose_transfer(%L, %L)', :'m', :'bruno'), 'PT403', 'NOT_ORGANIZER',
  'seul l''organisateur peut proposer un transfert');

reset role;
select tests.authenticate_as(:'orga');
select throws_ok(format('select public.propose_transfer(%L, %L)', :'m', :'dehors'), 'PT409', 'TRANSFER_TARGET_NOT_PARTICIPANT',
  'transfert vers un non-participant refusé');
select throws_ok(format('select public.propose_transfer(%L, %L)', :'m', :'orga'), 'PT400', 'INVALID_TRANSFER_TARGET',
  'transfert vers soi-même refusé');
select throws_ok(format('insert into public.organizer_transfers (match_id, from_user_id, to_user_id, expires_at) values (%L, %L, %L, now())',
  :'m', :'orga', :'alice'), '42501', null, 'insertion directe d''un transfert interdite');

select public.propose_transfer(:'m', :'alice') as t1 \gset
select is((select status::text from public.organizer_transfers where id = :'t1'), 'pending', 'proposition en attente');
select ok((select expires_at between now() + interval '47 hours 59 minutes' and now() + interval '48 hours'
           from public.organizer_transfers where id = :'t1'), 'validité de 48 h');
select is((select organizer_id from public.matches where id = :'m'), :'orga'::uuid,
  'rien ne change avant l''acceptation');
select throws_ok(format('select public.propose_transfer(%L, %L)', :'m', :'bruno'), 'PT409', 'TRANSFER_ALREADY_PENDING',
  'une seule proposition en cours par match');

reset role;
select tests.authenticate_as(:'bruno');
select is((select count(*)::int from public.organizer_transfers where id = :'t1'), 0,
  'un tiers ne voit pas la proposition');
select throws_ok(format('select public.respond_transfer(%L, true)', :'t1'), 'PT404', 'TRANSFER_NOT_FOUND',
  'un tiers ne peut pas accepter à la place du participant ciblé');

reset role;
select tests.authenticate_as(:'alice');
select is((select from_name || ' → ' || to_name from public.transfer_details where id = :'t1'), 'Orga → Alice',
  'la personne ciblée voit la proposition');
select is((select count(*)::int from public.notifications where user_id = :'alice' and type = 'transfer_proposed'), 1,
  'la personne ciblée est notifiée');

-- ---------------------------------------------------------------------------
-- Refus puis nouvelle proposition et acceptation
-- ---------------------------------------------------------------------------
select lives_ok(format('select public.respond_transfer(%L, false)', :'t1'), 'Alice refuse');
select is((select organizer_id from public.matches where id = :'m'), :'orga'::uuid, 'un refus ne change rien');
select throws_ok(format('select public.respond_transfer(%L, true)', :'t1'), 'PT409', 'TRANSFER_NOT_PENDING',
  'une proposition refusée ne peut plus être acceptée');

reset role;
select tests.authenticate_as(:'orga');
select is((select count(*)::int from public.notifications where type = 'transfer_declined'), 1,
  'l''organisateur est informé du refus');
select public.propose_transfer(:'m', :'alice') as t2 \gset

reset role;
select tests.authenticate_as(:'alice');
select lives_ok(format('select public.respond_transfer(%L, true)', :'t2'), 'Alice accepte');
select is((select organizer_id from public.matches where id = :'m'), :'alice'::uuid, 'Alice devient organisatrice');
select ok((select is_organizer from public.match_details where id = :'m'), 'Alice se voit organisatrice');
select is((select count(*)::int from public.participations where match_id = :'m' and user_id = :'orga' and status = 'active'), 1,
  'l''ancien organisateur reste inscrit comme joueur');
select lives_ok(format('select public.update_match(%L, %L)', :'m', '{"title": "Match repris"}'),
  'la nouvelle organisatrice peut modifier le match');

reset role;
select tests.authenticate_as(:'orga');
select throws_ok(format('select public.update_match(%L, %L)', :'m', '{"title": "Plus à moi"}'), 'PT403', 'NOT_ORGANIZER',
  'l''ancien organisateur ne peut plus modifier le match');
select lives_ok(format('select public.leave_match(%L)', :'m'), 'l''ancien organisateur peut désormais quitter le match');

-- ---------------------------------------------------------------------------
-- Annulations automatiques
-- ---------------------------------------------------------------------------
reset role;
select tests.authenticate_as(:'alice');
select public.propose_transfer(:'m', :'bruno') as t3 \gset
select lives_ok(format('select public.cancel_transfer(%L)', :'m'), 'l''organisatrice retire sa proposition');
select is((select status::text from public.organizer_transfers where id = :'t3'), 'cancelled', 'proposition retirée');

select public.propose_transfer(:'m', :'bruno') as t4 \gset
reset role;
select tests.authenticate_as(:'bruno');
select public.leave_match(:'m');
select is((select status::text from public.organizer_transfers where id = :'t4'), 'cancelled',
  'la proposition est annulée si la personne ciblée quitte le match');

reset role;
select tests.add_participant(:'m', :'bruno');
select tests.authenticate_as(:'alice');
select public.propose_transfer(:'m', :'bruno') as t5 \gset
select public.cancel_match(:'m');
select is((select status::text from public.organizer_transfers where id = :'t5'), 'cancelled',
  'la proposition est annulée avec le match');

-- Expiration : au plus tard au coup d'envoi, puis passage en « expirée ».
reset role;
select tests.authenticate_as(:'orga');
select public.create_match(tests.match_input(jsonb_build_object('starts_at', now() + interval '3 hours'))) as m2 \gset
reset role;
select tests.add_participant(:'m2', :'alice');
select tests.authenticate_as(:'orga');
select public.propose_transfer(:'m2', :'alice') as t6 \gset
select is((select expires_at from public.organizer_transfers where id = :'t6'),
  (select starts_at from public.matches where id = :'m2'), 'une proposition expire au plus tard au coup d''envoi');

reset role;
update public.organizer_transfers set expires_at = now() - interval '1 minute' where id = :'t6';
select tests.authenticate_as(:'alice');
select throws_ok(format('select public.respond_transfer(%L, true)', :'t6'), 'PT409', 'TRANSFER_EXPIRED',
  'une proposition expirée ne peut pas être acceptée');
reset role;
select is(private.expire_transfers(), 1, 'la tâche planifiée marque la proposition expirée');
select is((select count(*)::int from public.notifications where user_id = :'orga' and type = 'transfer_expired'), 1,
  'l''organisateur est informé de l''expiration');

select * from finish();
rollback;
