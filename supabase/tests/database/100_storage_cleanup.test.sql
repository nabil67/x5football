-- Nettoyage des photos : file d'attente alimentée à la purge, réservée au serveur.
begin;
select plan(8);

select tests.create_user('parti@test.local', 'Parti') as parti \gset
select tests.create_user('reste@test.local', 'Reste') as reste \gset

delete from auth.users where id = :'parti';
select is((select count(*)::int from private.storage_cleanup_queue where user_id = :'parti'), 1,
  'la purge d''un compte met ses photos en file de suppression');
select is((select count(*)::int from private.storage_cleanup_queue where user_id = :'reste'), 0,
  'les autres comptes ne sont pas concernés');

select tests.authenticate_as(:'reste');
select throws_ok($$select * from public.claim_storage_cleanup()$$, '42501', null,
  'un utilisateur ne peut pas lire la file');
select throws_ok(format('select public.complete_storage_cleanup(%L)', :'parti'), '42501', null,
  'un utilisateur ne peut pas vider la file');
reset role;
select tests.authenticate_as_anon();
select throws_ok($$select * from public.claim_storage_cleanup()$$, '42501', null, 'anon non plus');
reset role;

-- Isolation : d'éventuels comptes déjà en attente (autres tests) ne faussent pas le résultat.
delete from private.storage_cleanup_queue where user_id <> :'parti';
set local role service_role;
select ok(:'parti'::uuid in (select * from public.claim_storage_cleanup()),
  'le serveur (service_role) récupère les comptes à nettoyer');
select lives_ok(format('select public.complete_storage_cleanup(%L)', :'parti'), 'puis les retire de la file');
reset role;

-- Sans URL ni secret dans le coffre (Vault), la tâche planifiée n'envoie rien.
-- (Secrets éventuellement configurés en local retirés le temps du test : annulé par le rollback.)
delete from vault.secrets where name in ('project_url', 'cleanup_secret');
select is(private.trigger_storage_cleanup(), null::bigint, 'environnement non configuré : aucun appel');

select * from finish();
rollback;
