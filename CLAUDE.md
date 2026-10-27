# CLAUDE.md

Application mobile de rencontres pour jouer au football (MVP, adultes, Android/iOS).

**Lis `docs/SPECIFICATIONS.md` avant toute modification importante** : c'est la source de vérité fonctionnelle et technique. Les décisions prises et ouvertes sont suivies dans `docs/DECISIONS.md`.

## Structure
- `app/` — application Flutter (Android, iOS).
- `supabase/` — config locale, migrations SQL versionnées, Edge Functions, tests pgTAP.
- `docs/` — spécifications, décisions, modèle de données, API, plan de test.

## Commandes
```sh
supabase start                     # stack locale (Docker requis)
supabase db reset                  # rejoue toutes les migrations + seed
supabase test db                   # tests pgTAP (supabase/tests/database)
cd app && flutter analyze && flutter test
cd app && flutter run --dart-define-from-file=env/dev.json
```

## Règles
- Toutes les règles métier sont appliquées côté serveur (contraintes SQL, RPC transactionnelles, RLS). Flutter ne fait que de la validation de confort.
- Aucune écriture directe du client sur `matches`, `participations`, `organizer_transfers` : passer par des RPC `security definer` qui vérifient `auth.uid()`.
- Jamais de clé secrète/service_role dans `app/` (l'app refuse de démarrer avec une telle clé).
- Une migration par changement de schéma ; ne jamais modifier une migration déjà appliquée ailleurs qu'en local.
- Chaque fonctionnalité arrive avec ses tests (pgTAP pour le SQL, `flutter test` pour l'app).
- Ne pas trancher seul une décision marquée « à confirmer » : proposer des options.
- Langue de l'interface et de la documentation : français.
