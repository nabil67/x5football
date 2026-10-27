-- Vérifie que l'environnement de base de données fournit ce dont le projet a besoin.
begin;
select plan(3);

select ok(
  exists (select 1 from pg_available_extensions where name = 'postgis'),
  'PostGIS est disponible pour la recherche géographique'
);

select ok(
  exists (select 1 from pg_available_extensions where name = 'pg_cron'),
  'pg_cron est disponible pour la planification des rappels'
);

select is(
  current_setting('TimeZone'),
  'UTC',
  'La base fonctionne en UTC'
);

select * from finish();
rollback;
