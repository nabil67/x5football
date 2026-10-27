# x5football

Application mobile (Android, iOS) pour trouver des personnes à proximité et organiser des matchs de football. MVP gratuit, réservé aux adultes.

- Spécifications : [docs/SPECIFICATIONS.md](docs/SPECIFICATIONS.md)
- Décisions prises et ouvertes : [docs/DECISIONS.md](docs/DECISIONS.md)

## Prérequis

| Outil | Rôle |
|---|---|
| [Flutter](https://docs.flutter.dev/get-started/install) (stable) | Application mobile |
| [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started) | Backend local, migrations, tests |
| Docker Desktop | Fait tourner Supabase en local |
| Android Studio + un émulateur | Exécuter l'app Android |
| Mac avec Xcode (ou CI macOS) | Uniquement pour compiler/tester iOS |

## Démarrage local

```sh
# 1. Backend
supabase start          # premier lancement : télécharge les images Docker
supabase status         # affiche l'URL de l'API et la clé « publishable »

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
cd app && flutter analyze && flutter test
```

## Environnements

| Environnement | Backend | Config app |
|---|---|---|
| `dev` | Supabase local (Docker) | `app/env/dev.json` |
| `test` | Supabase local, base réinitialisée (`supabase db reset`) | `app/env/test.json` |
| `prod` | Projet Supabase hébergé (à créer) | `app/env/prod.json` (https obligatoire) |

Les secrets serveur sont décrits dans [.env.example](.env.example). Aucun secret n'est versionné, et l'application refuse de démarrer si on lui fournit une clé secrète.
