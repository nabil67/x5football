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
| 2026-10-28 | ~~Un match confirmé passe en `location_mode = fixed` ; un lieu à définir n'a jamais de position~~ (remplacé, voir « lieu toujours défini » ci-dessous) | Un seul invariant vérifié par contrainte SQL. |
| 2026-10-28 | La demande de suppression de compte annule les matchs à venir organisés et libère les places réservées | Évite des matchs fantômes ; la purge supprime ensuite les données. |
| 2026-10-28 | Nom technique : `x5football`, bundle `fr.x5football.x5football` | Provisoire, à remplacer avec le nom final. |
| 2026-10-28 | Couverture mondiale dès le lancement (pas de limitation à la France) | Validé par le porteur du projet. Écarte les services limités à un pays (ex. Base Adresse Nationale). |
| 2026-10-28 | **Le lieu d'un match est toujours défini** (nom du terrain + position) ; le mode « lieu à définir ensemble » est supprimé | Décision du porteur du projet, qui remplace sur ce point la spécification (§ 4.3 « lieu à définir », règle 11). La recherche filtre par distance au terrain. |
| 2026-10-28 | Solution gratuite, sans carte dans l'application : liste triée par distance + bouton « Ouvrir dans Maps » (lien universel Google Maps, sans clé) | Validé par le porteur du projet (« libre à l'utilisateur d'aller chercher l'adresse dans Google Maps »). |
| 2026-10-28 | Recherche d'adresses : OpenStreetMap Nominatim via l'Edge Function `geocode` (quota 30/h/personne, 1/s au total, cache 24 h) | Gratuit, mondial, sans clé. Au-delà d'un usage modéré, prévoir une instance auto-hébergée ou un fournisseur payant (interface `GeocodingRepository` remplaçable). |
| 2026-10-28 | Recherche : rayon 10 km par défaut, choix 2/5/10/25/50/100 km (serveur : 1–100), filtres date / niveau (inclut « tous niveaux ») / places disponibles, pages de 20 | Bornes côté serveur exigées par la spécification. |
| 2026-10-28 | Inscriptions : l'organisateur ne peut pas quitter son match (transfert ou annulation) ; réinscription possible après un départ s'il reste de la place ; départ possible jusqu'au coup d'envoi | Validé par le porteur du projet. |
| 2026-10-28 | Test de concurrence réel : connexions simultanées via `dblink` dans pgTAP (`050_concurrency.test.sql`) | Vérifie la dernière place avec de vraies transactions parallèles ; le test échoue si le verrou est retiré. |
| 2026-10-28 | Transfert d'organisation : proposition valable 48 h et au plus tard jusqu'au coup d'envoi ; une seule en attente par match ; l'ancien organisateur reste joueur | Validé par le porteur du projet (48 h). Durée dans `private.transfer_validity()`. |
| 2026-10-28 | Notifications : d'abord dans l'application (table `notifications`, textes rédigés par le serveur), push FCM ensuite sur la même table | Validé par le porteur du projet ; ne bloque pas l'étape 6 en attendant le projet Firebase. |
| 2026-10-28 | Rappel : une ligne par participant programmée à `starts_at - 24 h`, invisible avant échéance ; supprimée à la désinscription / annulation, replanifiée au changement d'horaire | Règles 15 à 17 de la spécification. |
| 2026-10-28 | Interface : vert provisoire (`brandSeed`, `lib/ui/theme.dart`), mode sombre selon le réglage du téléphone, zones tactiles ≥ 48 dp | Validé par le porteur du projet en attendant l'identité finale. |
| 2026-10-28 | Accessibilité vérifiée par tests automatiques (zones tactiles Android/iOS, libellés, contrastes) en clair et en sombre, et absence de débordement avec un texte agrandi à 200 % | Exigence de l'étape 7 ; tout nouvel écran doit être ajouté à `test/accessibility_test.dart`. |
| 2026-10-28 | Photo de profil facultative : bucket privé `avatars` (1 Mo, JPEG/PNG/WebP), écriture dans son seul dossier, lecture par les connectés ; `avatar_url` = chemin du fichier, jamais une URL externe ; photo réduite à 512 px sur le téléphone | Validé par le porteur du projet. Évite le pistage par image et les fichiers lourds. |
| 2026-10-28 | Données de démonstration locales dans `supabase/seed.sql` (rejouées par `supabase db reset`, jamais en production) | Confort de développement et de test sur émulateur. |
| 2026-10-28 | Blocage : la personne bloquée ne peut plus rejoindre les matchs de celle qui bloque, qui ne voit plus ses matchs ; la personne bloquée n'est pas informée (refus `JOIN_NOT_ALLOWED` neutre) | Validé par le porteur du projet. |
| 2026-10-28 | Limites anti-abus : 10 créations de match/24 h, 30 inscriptions ou désinscriptions/h, 10 signalements/24 h (fenêtres glissantes, actions réussies seulement) | Validé par le porteur du projet ; valeurs dans les RPC concernées. |
| 2026-10-28 | Signalements examinés par un administrateur dans Supabase Studio, sans écran de modération ni sanction automatique | Validé par le porteur du projet ; procédure dans `docs/BETA.md`. |
| 2026-10-28 | Photos des comptes supprimés : file d'attente alimentée à la purge, Edge Function `purge-avatars` appelée chaque heure par pg_cron (secret partagé dans Vault et dans les secrets des fonctions) | La base interdit la suppression directe des fichiers ; garantit l'effacement même si l'application n'a pas pu le faire. |
| 2026-10-28 | Intégration continue GitHub Actions sur le dépôt privé `nabil67/x5football` : application, base (migrations depuis une base vide + pgTAP), Edge Functions | Validé par le porteur du projet ; aucun secret nécessaire. |
| 2026-10-28 | Audit de sécurité automatique (`110_security_audit`) : RLS partout, aucun accès anonyme, aucune écriture directe hors nom/photo, `search_path` fixé, aucune colonne e-mail ni position exposée | S'applique à toute nouvelle table ou fonction. |
| 2026-10-28 | Signature Android de publication via `app/android/key.properties` (non versionné) ; sans ce fichier, signature de debug | Clé jamais dans le dépôt ; procédure dans `docs/BETA.md`. |
| 2026-10-28 | Position du téléphone demandée seulement sur action (« Autour de moi », « Ma position actuelle »), jamais en arrière-plan ni enregistrée | Confidentialité ; le GPS reste facultatif (recherche par ville). |

## Décisions ouvertes

| Sujet | Options / proposition | Nécessaire avant |
|---|---|---|
| Connexion WhatsApp | Fournisseur (Twilio Verify, MessageBird…), compte Meta Business, coût par message | Avant l'ajout de WhatsApp |
| Délai de grâce avant purge d'un compte supprimé | 0 (immédiat) aujourd'hui ; à aligner sur la politique de conservation | Publication |
| Expéditeur e-mail de production (SMTP) | Resend, Postmark, Brevo, SendGrid… (le SMTP intégré de Supabase est limité à quelques e-mails/heure) | Bêta |
| Langue(s) de l'interface | Français seul aujourd'hui ; ajout de l'anglais (structure de traduction à prévoir) | Publication |
| Devise des coûts estimés | EUR par défaut aujourd'hui ; devise choisie par l'organisateur (liste ISO 4217) | Étape 4 ou 7 |
| Unité de distance | km partout (actuel), ou km/miles selon la région du téléphone | Publication |
| Contact pour Nominatim | Adresse e-mail de contact à mettre dans `GEOCODER_USER_AGENT` (exigée par les règles d'usage) | Mise en production |
| Notifications push | Firebase Cloud Messaging retenu ; nécessite un projet Firebase créé par le porteur du projet (gratuit) | Quand le projet Firebase est prêt |
| Versions minimales Android / iOS | Défauts Flutter actuels | Publication |
| Build iOS | Mac, ou CI macOS (Codemagic, GitHub Actions) + compte Apple Developer | Tests iOS |
| Politique de confidentialité, CGU, conservation des données | — | Publication |
| Nom, identité visuelle, textes finaux | Vert provisoire en place ; couleur de marque modifiable en un seul endroit (`brandSeed`) | Publication |
