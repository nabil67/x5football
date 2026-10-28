# Journal des décisions

## Décisions prises

| Date | Décision | Raison |
|---|---|---|
| 2026-10-28 | Stack : Flutter + Supabase (Auth, PostgreSQL 17, PostGIS) | Stack de référence de la spécification ; dépôt vierge. |
| 2026-10-28 | Développement local avec `supabase start` (Docker) | Environnement reproductible, sans coût, isolé de la production. |
| 2026-10-28 | Statut `full` **calculé à la lecture** (participants actifs ≥ capacité) ; seuls `open`, `cancelled`, `completed` sont stockés | Une seule source de vérité, aucune incohérence possible entre statut et inscriptions. |
| 2026-10-28 | Écritures sensibles uniquement via RPC transactionnelles verrouillant la ligne du match (`FOR UPDATE`) + index unique partiel sur les participations actives | Atomicité de la dernière place et du transfert. |
| 2026-10-28 | Position de recherche de l'utilisateur jamais stockée (paramètre de requête uniquement) | Confidentialité de la localisation. |
| 2026-10-28 | Rappels : une ligne `notifications` par participant, envoyée par une tâche `pg_cron` + Edge Function | Annulation fine à la désinscription, idempotence, planification serveur. |
| 2026-10-28 | Configuration client via `--dart-define-from-file=env/<env>.json` (non versionné) | Pas de secret versionné ; l'app refuse une clé secrète. |
| 2026-10-28 | Âge : attestation « J'ai 18 ans ou plus » horodatée (`users.age_confirmed_at`), sans date de naissance | Collecte minimale ; validée par le porteur du projet. |
| 2026-10-28 | Connexion par code à usage unique : e-mail d'abord, WhatsApp ensuite | Pas de mot de passe à gérer. WhatsApp exige un fournisseur (Twilio…) et un expéditeur validé par Meta. |
| 2026-10-28 | Suppression de compte : blocage immédiat (`pending_deletion`), purge horaire par `pg_cron` qui supprime l'identité `auth.users` (le profil suit par cascade) | Droit à l'effacement, exigence des boutiques. Délai de grâce paramétrable (0 par défaut). |
| 2026-10-28 | Erreurs métier des RPC : SQLSTATE `PTxxx` (statut HTTP xxx), `message` = code stable, `hint` = texte affichable | Codes explicites exploitables par l'interface (cf. docs/API.md). |
| 2026-10-28 | Matchs : début au moins 15 min après la création ou la replanification, au plus 1 an ; durée 15 min – 10 h ; capacité 4 – 50 | Validé par le porteur du projet (15 min) ; bornes hautes pour éviter les valeurs aberrantes. |
| 2026-10-28 | Niveaux : tous niveaux, débutant, intermédiaire, confirmé (`all`, `beginner`, `intermediate`, `advanced`) | Validé par le porteur du projet. |
| 2026-10-28 | La liste des participants actifs (nom, avatar) est visible de tout utilisateur connecté | Permet de décider de rejoindre un match ; aucune donnée privée exposée. |
| 2026-10-28 | Un match confirmé passe en `location_mode = fixed` ; un lieu à définir n'a jamais de position | Un seul invariant vérifié par contrainte SQL. |
| 2026-10-28 | La demande de suppression de compte annule les matchs à venir organisés et libère les places réservées | Évite des matchs fantômes ; la purge supprime ensuite les données. |
$1 : `x5football`, bundle `fr.x5football.x5football` | Provisoire, à remplacer avec le nom final. |

## Décisions ouvertes

| Sujet | Options / proposition | Nécessaire avant |
|---|---|---|
| Connexion WhatsApp | Fournisseur (Twilio Verify, MessageBird…), compte Meta Business, coût par message | Avant l'ajout de WhatsApp |
| Délai de grâce avant purge d'un compte supprimé | 0 (immédiat) aujourd'hui ; à aligner sur la politique de conservation | Publication |
| Expéditeur e-mail de production (SMTP) | Resend, Postmark, Brevo, SendGrid… (le SMTP intégré de Supabase est limité à quelques e-mails/heure) | Bêta |
| Cartographie / géocodage | Mapbox, Google Maps Platform, OpenStreetMap (Geoapify, Nominatim auto-hébergé…) | Étape 4 — d'ici là, la position d'un terrain précis se saisit en coordonnées GPS (provisoire) |
| Fournisseur push | Proposition : Firebase Cloud Messaging (Android + iOS via APNs) | Étape 6 |
| Délai d'expiration d'un transfert | Proposition : 48 h, configurable côté serveur | Étape 6 |
| Versions minimales Android / iOS | Défauts Flutter actuels | Publication |
| Build iOS | Mac, ou CI macOS (Codemagic, GitHub Actions) + compte Apple Developer | Tests iOS |
| Politique de confidentialité, CGU, conservation des données | — | Publication |
| Nom, identité visuelle, textes finaux | — | Publication |
