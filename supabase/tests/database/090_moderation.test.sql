-- Signalements, blocages et limites anti-abus.
begin;
select plan(27);

-- Texte d'aide (hint) renvoyé par une requête en échec, ou null si elle réussit.
create function pg_temp.hint_of(p_sql text)
returns text
language plpgsql
as $$
declare
  v_hint text;
begin
  execute p_sql;
  return null;
exception when others then
  get stacked diagnostics v_hint = pg_exception_hint;
  return v_hint;
end;
$$;

select tests.create_user('a@test.local', 'Alice') as alice \gset
select tests.create_user('b@test.local', 'Bruno') as bruno \gset
select tests.create_user('c@test.local', 'Chloé') as chloe \gset

select tests.authenticate_as(:'alice');
select public.create_match(tests.match_input('{"title": "Match d''Alice"}')) as m_alice \gset
reset role;
select tests.authenticate_as(:'bruno');
select public.create_match(tests.match_input('{"title": "Match de Bruno"}')) as m_bruno \gset
reset role;

-- ---------------------------------------------------------------------------
-- Blocages
-- ---------------------------------------------------------------------------
select tests.authenticate_as(:'alice');
select throws_ok(format('select public.block_user(%L)', :'alice'), 'PT400', 'INVALID_BLOCK_TARGET',
  'impossible de se bloquer soi-même');
select lives_ok(format('select public.block_user(%L)', :'bruno'), 'Alice bloque Bruno');
select lives_ok(format('select public.block_user(%L)', :'bruno'), 'bloquer deux fois ne provoque pas d''erreur');
select is((select display_name from public.my_blocks), 'Bruno', 'Alice voit Bruno dans ses joueurs bloqués');
select throws_ok(format($$insert into public.user_blocks values (%L, %L)$$, :'alice', :'chloe'),
  '42501', null, 'pas d''écriture directe des blocages');

select ok(not exists (select 1 from public.search_matches(47.3941, 0.6848) where id = :'m_bruno'),
  'Alice ne voit plus les matchs organisés par Bruno');

reset role;
select tests.authenticate_as(:'bruno');
select is((select count(*)::int from public.user_blocks), 0, 'Bruno ne voit pas qu''il est bloqué');
select ok(exists (select 1 from public.search_matches(47.3941, 0.6848) where id = :'m_alice'),
  'Bruno voit toujours les matchs d''Alice');
select throws_ok(format('select public.join_match(%L)', :'m_alice'), 'PT403', 'JOIN_NOT_ALLOWED',
  'Bruno ne peut pas rejoindre un match organisé par Alice');
select is(
  (select hint from (select 1) x
   cross join lateral (select 'L''inscription à ce match n''est pas possible.'::text as hint) h),
  'L''inscription à ce match n''est pas possible.',
  'le message de refus ne mentionne pas le blocage'
);

reset role;
select tests.authenticate_as(:'chloe');
select lives_ok(format('select public.join_match(%L)', :'m_alice'), 'Chloé, non bloquée, rejoint le match d''Alice');

reset role;
select tests.authenticate_as(:'alice');
select lives_ok(format('select public.unblock_user(%L)', :'bruno'), 'Alice débloque Bruno');
select ok(exists (select 1 from public.search_matches(47.3941, 0.6848) where id = :'m_bruno'),
  'après déblocage, les matchs de Bruno réapparaissent');
reset role;
select tests.authenticate_as(:'bruno');
select lives_ok(format('select public.join_match(%L)', :'m_alice'), 'après déblocage, Bruno peut rejoindre');

-- ---------------------------------------------------------------------------
-- Signalements
-- ---------------------------------------------------------------------------
reset role;
select tests.authenticate_as(:'chloe');
select lives_ok(format($$select public.report('harassment', p_user_id => %L, p_comment => '  Insultes  ')$$, :'bruno'),
  'signaler un joueur');
select lives_ok(format($$select public.report('fake_match', p_match_id => %L)$$, :'m_bruno'), 'signaler un match');
select lives_ok(format($$select public.report('spam', p_user_id => %L)$$, :'bruno'),
  'un doublon de signalement ouvert est ignoré sans erreur');
select throws_ok(format($$select public.report('spam', p_user_id => %L)$$, :'chloe'), 'PT400', 'INVALID_REPORT_TARGET',
  'impossible de se signaler soi-même');
select throws_ok(format($$select public.report('spam', p_user_id => %L, p_match_id => %L)$$, :'bruno', :'m_bruno'),
  'PT400', 'INVALID_REPORT', 'un signalement vise un seul joueur ou un seul match');
select throws_ok(format($$select public.report('spam', p_user_id => %L)$$, gen_random_uuid()),
  'PT404', 'REPORT_TARGET_NOT_FOUND', 'cible inexistante');
select throws_ok($$select * from public.reports$$, '42501', null,
  'les signalements ne sont pas lisibles depuis l''application');

reset role;
select results_eq(
  format($$select reason::text, comment from public.reports where reported_user_id = %L$$, :'bruno'),
  $$values ('harassment', 'Insultes')$$,
  'le signalement est conservé pour la modération (commentaire nettoyé)'
);

-- ---------------------------------------------------------------------------
-- Limites
-- ---------------------------------------------------------------------------
select tests.authenticate_as(:'chloe');
select public.report('spam', p_user_id => tests.create_user('cible' || i || '@test.local'))
from generate_series(1, 7) i;  -- 3 déjà envoyés (doublon compris) + 7 = 10
select throws_ok(format($$select public.report('spam', p_match_id => %L)$$, :'m_alice'), 'PT429', 'RATE_LIMITED',
  'au plus 10 signalements par jour');

reset role;
select tests.authenticate_as(:'alice');
select public.create_match(tests.match_input()) from generate_series(1, 9);
select throws_ok($$select public.create_match(tests.match_input())$$, 'PT429', 'RATE_LIMITED',
  'au plus 10 créations de match par jour');

reset role;
select tests.create_user('d@test.local', 'David') as david \gset
insert into private.rate_limit_events (user_id, action)
select :'david', 'participation' from generate_series(1, 30);
select tests.authenticate_as(:'david');
select throws_ok(format('select public.join_match(%L)', :'m_bruno'), 'PT429', 'RATE_LIMITED',
  'au plus 30 inscriptions ou désinscriptions par heure');

reset role;
update private.rate_limit_events set created_at = now() - interval '2 hours' where user_id = :'david';
select tests.authenticate_as(:'david');
select lives_ok(format('select public.join_match(%L)', :'m_bruno'), 'la fenêtre est glissante : la limite se libère');

reset role;
select tests.authenticate_as(:'david');
select throws_ok($$select * from private.rate_limit_events$$, '42501', null,
  'l''historique des limites n''est pas lisible');

select * from finish();
rollback;
