# Mise en ligne de la bêta

Procédure pour passer de l'environnement local à un projet Supabase réel et à une application
installable par des testeurs. Aucune valeur secrète ne doit être versionnée : chaque secret
est indiqué ici par son emplacement, jamais par sa valeur.

## 1. Projet Supabase

1. Créer un projet sur [supabase.com](https://supabase.com) (région proche des utilisateurs).
2. Lier le dépôt et appliquer les migrations :
   ```sh
   supabase login
   supabase link --project-ref <identifiant-du-projet>
   supabase db push            # applique supabase/migrations (le seed de démo n'est pas appliqué)
   ```
3. **Authentification** (Dashboard › Authentication) :
   - Fournisseur e-mail activé, code à usage unique (OTP) à 6 chiffres, expiration 10 min.
   - Modèle d'e-mail « Magic link » et « Confirm signup » : reprendre `supabase/templates/otp_code.html`.
   - **SMTP de production obligatoire** (le SMTP intégré est limité à quelques e-mails par heure) :
     voir la décision ouverte dans `docs/DECISIONS.md` (Resend, Postmark, Brevo…).
   - URL du site et URL de redirection : sans objet pour l'OTP, laisser les valeurs par défaut.
4. **Stockage** : le bucket privé `avatars` est créé par les migrations ; vérifier sa présence.

## 2. Edge Functions

```sh
supabase functions deploy geocode
supabase functions deploy purge-avatars --no-verify-jwt
supabase secrets set GEOCODER_USER_AGENT="x5football/1.0 (<adresse e-mail de contact>)"
supabase secrets set CLEANUP_SECRET="<valeur aléatoire d'au moins 32 caractères>"
```

Puis, dans l'éditeur SQL du Dashboard, enregistrer dans le coffre chiffré (Vault) les valeurs
qu'utilise la tâche planifiée de nettoyage des photos :

```sql
select vault.create_secret('https://<identifiant-du-projet>.supabase.co', 'project_url');
select vault.create_secret('<même valeur que CLEANUP_SECRET>', 'cleanup_secret');
```

## 3. Tâches planifiées (pg_cron)

Créées par les migrations, à vérifier dans Dashboard › Integrations › Cron :

| Tâche | Fréquence | Rôle |
|---|---|---|
| `purge-pending-deletions` | toutes les heures (min. 17) | Supprime les comptes dont la suppression a été demandée |
| `cleanup-deleted-avatars` | toutes les heures (min. 29) | Supprime les photos des comptes supprimés |
| `complete-finished-matches` | toutes les 15 min | Passe les matchs terminés en « terminé » |
| `expire-organizer-transfers` | toutes les 15 min | Expire les propositions de transfert échues |
| `purge-rate-limit-events` | chaque jour (3 h 43) | Purge l'historique des limites anti-abus |

## 4. Application Android

1. Configuration : copier `app/env/prod.example.json` en `app/env/prod.json` (ignoré par git) et
   renseigner l'URL `https://…supabase.co` et la clé **publishable** (l'application refuse de
   démarrer avec une clé secrète ou une URL non https en production).
2. Clé de signature (une seule fois, à conserver précieusement hors du dépôt) :
   ```sh
   keytool -genkey -v -keystore C:/Users/<vous>/cles/x5football-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
   puis copier `app/android/key.properties.example` en `app/android/key.properties` et le remplir.
3. Construire :
   ```sh
   cd app
   flutter build appbundle --release --dart-define-from-file=env/prod.json
   ```
   Le fichier `build/app/outputs/bundle/release/app-release.aab` s'envoie dans la Google Play
   Console, piste « Tests internes » ou « Tests fermés ».
4. Avant la première publication : figer l'identifiant `applicationId` (`fr.x5football.x5football`
   aujourd'hui) — il ne pourra plus changer — et le nom affiché.

## 5. iOS

Nécessite un Mac (ou une CI macOS) et un compte Apple Developer : voir la décision ouverte
« Build iOS ». Les autorisations (position, photos, appareil photo) sont déjà décrites en français
dans `app/ios/Runner/Info.plist`.

## 6. Liste de contrôle avant d'inviter des testeurs

- [ ] CI GitHub Actions verte sur `main`.
- [ ] `supabase db push` appliqué sans erreur ; `supabase test db` vert en local sur la même version.
- [ ] SMTP de production configuré ; un code de connexion reçu sur une vraie adresse.
- [ ] Secrets des Edge Functions et du Vault renseignés ; recherche d'adresse testée.
- [ ] Suppression de compte testée de bout en bout (compte, matchs, photo).
- [ ] Politique de confidentialité et CGU publiées (voir `docs/DONNEES.md`), liens dans la fiche Play.
- [ ] Au moins un administrateur sait traiter les signalements (section 7).

## 7. Modération des signalements (Supabase Studio)

Les signalements arrivent dans la table `public.reports` (Dashboard › Table Editor), lisible
uniquement par les administrateurs du projet. Pour chacun :

1. Lire le motif (`reason`), le commentaire et la cible (`reported_user_id` ou `match_id`).
2. Si nécessaire, suspendre le compte concerné :
   ```sql
   update public.users set account_status = 'suspended' where id = '<id>';
   ```
   (un compte suspendu ne peut plus rien créer, rejoindre ni signaler) ; ou annuler le match en
   passant `status` à `cancelled` et `cancelled_at` à `now()`.
3. Marquer le signalement traité : `status = 'reviewed'` (ou `dismissed`), `reviewed_at = now()`.

Aucune sanction n'est automatique, et l'application ne le promet pas aux utilisateurs.
