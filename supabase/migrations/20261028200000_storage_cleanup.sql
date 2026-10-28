-- Étape 8 : suppression garantie des photos des comptes supprimés.
--
-- La base interdit d'effacer directement les fichiers (storage.protect_delete) : seule
-- l'API Storage supprime le fichier lui-même. Quand un profil est purgé, son id est mis
-- en file d'attente ; une tâche planifiée appelle l'Edge Function `purge-avatars`, qui
-- supprime les fichiers via l'API Storage puis retire l'id de la file.
--
-- Configuration par environnement (jamais versionnée), dans le coffre chiffré Vault :
--   select vault.create_secret('<URL du projet>', 'project_url');
--   select vault.create_secret('<même valeur que CLEANUP_SECRET>', 'cleanup_secret');
-- Sans ces secrets, la tâche ne fait rien (la file est conservée).

create extension if not exists pg_net;

create table private.storage_cleanup_queue (
  -- Pas de clé étrangère : le profil n'existe plus.
  user_id uuid primary key,
  queued_at timestamptz not null default now(),
  attempts integer not null default 0
);

create function private.queue_storage_cleanup()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into private.storage_cleanup_queue (user_id) values (old.id) on conflict do nothing;
  return old;
end;
$$;

create trigger users_queue_storage_cleanup
  after delete on public.users
  for each row execute function private.queue_storage_cleanup();

-- Réservées à l'Edge Function (rôle service_role, côté serveur uniquement).
create function public.claim_storage_cleanup(p_limit integer default 20)
returns setof uuid
language sql
security definer
set search_path = ''
as $$
  update private.storage_cleanup_queue q
  set attempts = q.attempts + 1
  where q.user_id in (
    select user_id from private.storage_cleanup_queue
    order by queued_at
    limit least(greatest(coalesce(p_limit, 20), 1), 100)
    for update skip locked
  )
  returning q.user_id;
$$;

create function public.complete_storage_cleanup(p_user_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from private.storage_cleanup_queue where user_id = p_user_id;
$$;

revoke execute on function public.claim_storage_cleanup(integer) from public, anon, authenticated;
revoke execute on function public.complete_storage_cleanup(uuid) from public, anon, authenticated;
grant execute on function public.claim_storage_cleanup(integer) to service_role;
grant execute on function public.complete_storage_cleanup(uuid) to service_role;

-- Appelle l'Edge Function s'il y a du travail et si l'environnement est configuré.
-- Renvoie l'identifiant de la requête HTTP, ou null si rien n'a été envoyé.
create function private.trigger_storage_cleanup()
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url text;
  v_secret text;
begin
  if not exists (select 1 from private.storage_cleanup_queue) then
    return null;
  end if;
  select decrypted_secret into v_url from vault.decrypted_secrets where name = 'project_url';
  select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'cleanup_secret';
  if v_url is null or v_secret is null then
    return null;
  end if;
  return net.http_post(
    url := rtrim(v_url, '/') || '/functions/v1/purge-avatars',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-cleanup-secret', v_secret),
    body := '{}'::jsonb
  );
end;
$$;

-- Après la purge horaire des comptes (minute 17).
select cron.schedule('cleanup-deleted-avatars', '29 * * * *', $$select private.trigger_storage_cleanup()$$);

revoke all on all tables in schema private from public, anon, authenticated;
revoke execute on all functions in schema private from public, anon, authenticated;
grant execute on function private.is_own_avatar_path(text) to authenticated;
