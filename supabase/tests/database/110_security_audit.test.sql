-- Audit de sécurité systématique : s'applique automatiquement à toute nouvelle table,
-- vue ou fonction. Un échec ici signale un objet ajouté sans protection.
begin;
select plan(12);

-- Fonctions créées par le projet (hors extensions installées).
create temporary view audit_functions as
select p.oid, n.nspname as schema, p.proname as name, p.prosecdef as security_definer, p.proconfig
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname in ('public', 'private')
  and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e');

create temporary view audit_relations as
select c.oid, c.relname as name, c.relkind
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind in ('r', 'v', 'm')
  and not exists (select 1 from pg_depend d where d.objid = c.oid and d.deptype = 'e');

-- ---------------------------------------------------------------------------
-- Tables et vues
-- ---------------------------------------------------------------------------
select is(
  (select array_agg(name order by name) from audit_relations r join pg_class c on c.oid = r.oid
   where r.relkind = 'r' and not c.relrowsecurity),
  null,
  'toutes les tables publiques ont la RLS activée'
);

select is(
  (select array_agg(name order by name) from audit_relations
   where has_table_privilege('anon', oid, 'SELECT') or has_table_privilege('anon', oid, 'INSERT')
      or has_table_privilege('anon', oid, 'UPDATE') or has_table_privilege('anon', oid, 'DELETE')),
  null,
  'un visiteur non connecté n''a accès à aucune table ni vue'
);

select is(
  (select array_agg(name order by name) from audit_relations
   where has_table_privilege('authenticated', oid, 'INSERT')
      or has_table_privilege('authenticated', oid, 'DELETE')
      or has_table_privilege('authenticated', oid, 'TRUNCATE')),
  null,
  'aucune insertion ni suppression directe : tout passe par les RPC'
);

select is(
  (select array_agg(table_name || '.' || column_name order by table_name, column_name)
   from information_schema.column_privileges
   where table_schema = 'public' and grantee = 'authenticated' and privilege_type = 'UPDATE'),
  array['users.avatar_url', 'users.display_name'],
  'seules modifications directes : son nom et sa photo'
);

select is(
  (select array_agg(table_name || '.' || column_name order by table_name)
   from information_schema.columns
   where table_schema = 'public' and column_name in ('email', 'phone', 'password', 'encrypted_password')),
  null,
  'aucune vue ni table publique n''expose e-mail, téléphone ou mot de passe'
);

select is(
  (select array_agg(column_name::text order by ordinal_position)
   from information_schema.columns where table_schema = 'public' and table_name = 'public_profiles'),
  array['id', 'display_name', 'avatar_url'],
  'le profil public se limite au nom et à la photo'
);

select is(
  (select array_agg(column_name::text order by column_name)
   from information_schema.columns
   where table_schema = 'public' and table_name = 'users'
     and (column_name ~ '(lat|lng|lon|location|position|address)' )),
  null,
  'aucune position ni adresse personnelle n''est stockée dans le profil'
);

-- ---------------------------------------------------------------------------
-- Fonctions
-- ---------------------------------------------------------------------------
select is(
  (select array_agg(schema || '.' || name order by schema, name) from audit_functions
   where security_definer and not exists (
     select 1 from unnest(proconfig) c where c like 'search_path=%')),
  null,
  'toute fonction security definer fixe son search_path (pas de détournement)'
);

select is(
  (select array_agg(schema || '.' || name order by schema, name) from audit_functions
   where has_function_privilege('anon', oid, 'EXECUTE')),
  null,
  'un visiteur non connecté ne peut exécuter aucune fonction du projet'
);

select is(
  (select array_agg(name order by name) from audit_functions
   where schema = 'private' and has_function_privilege('authenticated', oid, 'EXECUTE')),
  array['is_own_avatar_path']::name[],
  'fonctions internes inaccessibles, sauf le contrôle de dossier photo des politiques Storage'
);

select is(
  (select array_agg(name order by name) from audit_functions
   where schema = 'public' and not has_function_privilege('authenticated', oid, 'EXECUTE')
     and has_function_privilege('service_role', oid, 'EXECUTE')
     and (select count(*) from pg_trigger t where t.tgfoid = oid) = 0),
  array['claim_storage_cleanup', 'complete_storage_cleanup']::name[],
  'les fonctions de maintenance sont réservées au serveur (service_role)'
);

select is(
  (select array_agg(name order by name) from audit_functions
   where schema = 'public' and has_function_privilege('authenticated', oid, 'EXECUTE')
     and not security_definer and name not in ('search_matches')),
  null,
  'les RPC accessibles aux utilisateurs sont security definer (contrôles serveur), sauf la recherche (lecture sous RLS)'
);

select * from finish();
rollback;
