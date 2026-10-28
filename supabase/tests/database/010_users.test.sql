-- Profils, attestation d'âge, statuts de compte, RLS et suppression de compte.
begin;
select plan(27);

-- Préparation (en tant que postgres)
select tests.create_auth_user('nouveau@test.local') as new_id \gset
select tests.create_user('alice@test.local', 'Alice') as alice \gset
select tests.create_user('bob@test.local', 'Bob') as bob \gset

select ok(
  (select relrowsecurity from pg_class where oid = 'public.users'::regclass),
  'RLS activée sur public.users'
);

-- ---------------------------------------------------------------------------
-- Utilisateur non authentifié
-- ---------------------------------------------------------------------------
select tests.authenticate_as_anon();

select throws_ok($$select * from public.users$$, '42501', null,
  'anon ne peut pas lire les profils');
select throws_ok($$select * from public.public_profiles$$, '42501', null,
  'anon ne peut pas lire les profils publics');
select throws_ok($$select public.complete_profile('Anon', true)$$, '42501', null,
  'anon ne peut pas créer de profil');
select throws_ok($$select public.request_account_deletion()$$, '42501', null,
  'anon ne peut pas demander une suppression');

-- ---------------------------------------------------------------------------
-- Création du profil
-- ---------------------------------------------------------------------------
reset role;
select tests.authenticate_as(:'new_id');

select throws_ok($$select public.complete_profile('Nouveau', false)$$, 'PT422', 'AGE_NOT_CONFIRMED',
  'profil refusé sans attestation de majorité');
select throws_ok($$select public.complete_profile('Nouveau', null)$$, 'PT422', 'AGE_NOT_CONFIRMED',
  'profil refusé si l''attestation est absente');
select throws_ok($$select public.complete_profile('   ', true)$$, 'PT400', 'INVALID_DISPLAY_NAME',
  'nom vide refusé');
select throws_ok($$select public.complete_profile(repeat('x', 41), true)$$, 'PT400', 'INVALID_DISPLAY_NAME',
  'nom trop long refusé');
select throws_ok($$insert into public.users (id, display_name, age_confirmed_at) values (auth.uid(), 'Direct', now())$$,
  '42501', null, 'insertion directe dans public.users interdite');

select is(
  (select display_name from public.complete_profile('  Nouveau  ', true)),
  'Nouveau',
  'profil créé avec un nom nettoyé'
);
select is(
  (select account_status::text from public.users where id = auth.uid()),
  'active',
  'nouveau profil actif'
);
select isnt((select age_confirmed_at from public.users where id = auth.uid()), null,
  'attestation de majorité horodatée');
select throws_ok($$select public.complete_profile('Encore', true)$$, 'PT409', 'PROFILE_ALREADY_EXISTS',
  'second profil refusé');

-- ---------------------------------------------------------------------------
-- Isolation des profils
-- ---------------------------------------------------------------------------
reset role;
select tests.authenticate_as(:'alice');

select results_eq($$select id from public.users$$, array[:'alice'::uuid],
  'un utilisateur ne lit que son propre profil complet');
select results_eq($$select display_name from public.public_profiles where id = '$$ || :'bob' || $$'$$,
  array['Bob'], 'le nom public d''un autre joueur est visible');

with u as (update public.users set display_name = 'Pirate' where id = :'bob' returning 1)
select is(count(*)::int, 0, 'impossible de modifier le profil d''un autre utilisateur') from u;

with u as (update public.users set display_name = 'Alice B.' where id = :'alice' returning display_name)
select is((select display_name from u), 'Alice B.', 'modification de son propre nom');

select throws_ok($$update public.users set account_status = 'active' where id = auth.uid()$$, '42501', null,
  'impossible de modifier son statut de compte');
select throws_ok($$update public.users set age_confirmed_at = now() where id = auth.uid()$$, '42501', null,
  'impossible de modifier son attestation');

-- ---------------------------------------------------------------------------
-- Compte suspendu
-- ---------------------------------------------------------------------------
reset role;
update public.users set account_status = 'suspended' where id = :'bob';
select tests.authenticate_as(:'bob');

with u as (update public.users set display_name = 'Bob 2' where id = :'bob' returning 1)
select is(count(*)::int, 0, 'un compte suspendu ne peut pas modifier son profil') from u;

reset role;  -- la fonction privée n'est appelable que par le serveur ; auth.uid() reste Bob
select throws_ok($$select private.current_active_user_id()$$, 'PT403', 'ACCOUNT_INACTIVE',
  'un compte suspendu ne peut réaliser aucune action protégée');

select tests.authenticate_as(:'alice');
select is((select count(*)::int from public.public_profiles where id = :'bob'), 0,
  'un compte suspendu n''apparaît pas dans les profils publics');

-- ---------------------------------------------------------------------------
-- Suppression de compte
-- ---------------------------------------------------------------------------
select public.request_account_deletion();

reset role;
select is((select account_status::text from public.users where id = :'alice'), 'pending_deletion',
  'la demande de suppression bloque le compte');
select throws_ok($$select private.current_active_user_id()$$, 'PT403', 'ACCOUNT_INACTIVE',
  'un compte en cours de suppression ne peut réaliser aucune action protégée');

select private.purge_pending_deletions();
select is((select count(*)::int from auth.users where id = :'alice'), 0,
  'la purge supprime l''identité et le profil du compte');

-- La session d'Alice reste techniquement valide jusqu'à son expiration.
select tests.authenticate_as(:'alice');
select throws_ok($$select public.complete_profile('Alice', true)$$, 'PT401', 'AUTH_REQUIRED',
  'une session dont l''identité a été supprimée doit se reconnecter');
reset role;

select * from finish();
rollback;
