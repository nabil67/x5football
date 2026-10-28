-- Étape 7 : photo de profil facultative (Supabase Storage, bucket privé `avatars`).
--
-- Chaque personne n'écrit que dans son dossier `<id>/` ; les photos sont lisibles
-- par les utilisateurs connectés uniquement. Taille et formats bornés par le bucket.
-- `users.avatar_url` contient le chemin du fichier dans le bucket (jamais une URL externe).

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', false, 1048576, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Vrai si l'objet appartient au dossier de l'utilisateur connecté, dont le compte est actif.
create function private.is_own_avatar_path(p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (storage.foldername(p_name))[1] = (select auth.uid())::text
     and exists (select 1 from public.users where id = (select auth.uid()) and account_status = 'active');
$$;

grant execute on function private.is_own_avatar_path(text) to authenticated;
grant usage on schema private to authenticated;

create policy avatars_select_authenticated on storage.objects
  for select to authenticated
  using (bucket_id = 'avatars');

create policy avatars_insert_own on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars' and private.is_own_avatar_path(name));

create policy avatars_update_own on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars' and private.is_own_avatar_path(name))
  with check (bucket_id = 'avatars' and private.is_own_avatar_path(name));

create policy avatars_delete_own on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars' and private.is_own_avatar_path(name));

-- Le profil ne peut référencer qu'un fichier de son propre dossier
-- (remplace l'ancienne contrainte qui attendait une URL http).
alter table public.users
  drop constraint users_avatar_url_valid,
  add constraint users_avatar_path_valid check (
    avatar_url is null
    or avatar_url ~ ('^' || id::text || '/avatar-[0-9]{1,20}\.(jpg|png|webp)$')
  );
