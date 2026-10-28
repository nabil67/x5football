-- Photo de profil : dossier personnel, lecture réservée aux connectés, chemin contrôlé.
begin;
select plan(11);

select tests.create_user('a@test.local', 'Alice') as alice \gset
select tests.create_user('b@test.local', 'Bruno') as bruno \gset
select tests.create_user('s@test.local', 'Suspendu') as suspendu \gset
update public.users set account_status = 'suspended' where id = :'suspendu';

select is((select file_size_limit from storage.buckets where id = 'avatars'), 1048576::bigint,
  'taille maximale d''une photo : 1 Mo');
select ok(not (select public from storage.buckets where id = 'avatars'), 'le bucket n''est pas public');

-- Le service Storage enregistre chaque envoi dans storage.objects avec le jeton de l'utilisateur.
select tests.authenticate_as(:'alice');
select lives_ok(format($$insert into storage.objects (bucket_id, name) values ('avatars', '%s/avatar-1.jpg')$$, :'alice'),
  'envoi dans son propre dossier accepté');
select throws_ok(format($$insert into storage.objects (bucket_id, name) values ('avatars', '%s/avatar-1.jpg')$$, :'bruno'),
  '42501', null, 'envoi dans le dossier d''un autre refusé');
select throws_ok($$insert into storage.objects (bucket_id, name) values ('avatars', 'avatar-1.jpg')$$,
  '42501', null, 'envoi hors dossier personnel refusé');

select lives_ok(format($$update public.users set avatar_url = '%s/avatar-1.jpg' where id = auth.uid()$$, :'alice'),
  'le profil référence sa photo');
select throws_ok(format($$update public.users set avatar_url = '%s/avatar-1.jpg' where id = auth.uid()$$, :'bruno'),
  '23514', null, 'impossible de référencer la photo d''un autre');
select throws_ok($$update public.users set avatar_url = 'https://exemple.org/pixel.gif' where id = auth.uid()$$,
  '23514', null, 'aucune URL externe (pas de pistage par image)');

reset role;
select tests.authenticate_as(:'bruno');
select is((select count(*)::int from storage.objects where bucket_id = 'avatars' and name like :'alice' || '/%'), 1,
  'un utilisateur connecté peut voir les photos des autres');

reset role;
select tests.authenticate_as(:'suspendu');
select throws_ok(format($$insert into storage.objects (bucket_id, name) values ('avatars', '%s/avatar-1.jpg')$$, :'suspendu'),
  '42501', null, 'un compte suspendu ne peut pas envoyer de photo');

reset role;
select tests.authenticate_as_anon();
select is((select count(*)::int from storage.objects where bucket_id = 'avatars'), 0,
  'un visiteur non connecté ne voit aucune photo');

select * from finish();
rollback;
