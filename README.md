# x5football

Application mobile (Android, iOS) pour trouver des personnes à proximité et organiser des matchs de football. MVP gratuit, réservé aux adultes.

- Spécifications : [docs/SPECIFICATIONS.md](docs/SPECIFICATIONS.md)
- Décisions prises et ouvertes : [docs/DECISIONS.md](docs/DECISIONS.md)
- API (RPC, codes d'erreur, limites) : [docs/API.md](docs/API.md)
- Conformité aux critères de la spécification : [docs/CONFORMITE.md](docs/CONFORMITE.md)
- Données collectées et suppression : [docs/DONNEES.md](docs/DONNEES.md)
- Mise en ligne de la bêta et modération : [docs/BETA.md](docs/BETA.md)

Intégration continue : GitHub Actions ([.github/workflows/ci.yml](.github/workflows/ci.yml)) rejoue tous les tests à chaque envoi sur `main`.

## Prérequis

| Outil | Rôle |
|---|---|
| [Flutter](https://docs.flutter.dev/get-started/install) (stable) | Application mobile |
| [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started) | Backend local, migrations, tests |
| Docker Desktop | Fait tourner Supabase en local |
| [Deno](https://deno.com) 2 | Tests des Edge Functions |
| Android Studio + un émulateur | Exécuter l'app Android |
| Mac avec Xcode (ou CI macOS) | Uniquement pour compiler/tester iOS |

## Démarrage local

```sh
# 1. Backend
supabase start          # premier lancement : télécharge les images Docker
supabase status         # affiche l'URL de l'API et la clé « publishable »
supabase functions serve # Edge Functions locales (recherche d'adresses), dans un autre terminal

# 2. Configuration de l'app
cp app/env/dev.example.json app/env/dev.json
# Renseigner SUPABASE_PUBLISHABLE_KEY (jamais la clé secrète).
# Émulateur Android : http://10.0.2.2:54321 ; simulateur iOS : http://127.0.0.1:54321.
# Appareil physique : IP locale du PC, ex. http://192.168.1.20:54321.

# 3. Application
cd app
flutter run --dart-define-from-file=env/dev.json
```

Studio Supabase (interface d'administration locale) : http://127.0.0.1:54323

## Tests

```sh
supabase test db                        # tests SQL (pgTAP)
deno test supabase/functions          # tests des Edge Functions (Deno 2)
cd app && flutter analyze && flutter test
```

`supabase db reset` recharge aussi des données de démonstration locales (`supabase/seed.sql` : un organisateur « Karim » et des matchs autour de Tours, à Paris et à Rio).

Les tests d'accessibilité (`app/test/accessibility_test.dart`) vérifient chaque écran principal en thème clair et sombre (zones tactiles, libellés, contrastes) et avec un texte agrandi à 200 %. Tout nouvel écran doit y être ajouté.

## Environnements

| Environnement | Backend | Config app |
|---|---|---|
| `dev` | Supabase local (Docker) | `app/env/dev.json` |
| `test` | Supabase local, base réinitialisée (`supabase db reset`) | `app/env/test.json` |
| `prod` | Projet Supabase hébergé (à créer) | `app/env/prod.json` (https obligatoire) |

Les secrets serveur sont décrits dans [.env.example](.env.example). Aucun secret n'est versionné, et l'application refuse de démarrer si on lui fournit une clé secrète.
