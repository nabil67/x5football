# API

Le client parle directement à Supabase : Auth pour l'identité, PostgREST pour les lectures autorisées par la RLS, et des **RPC** (`POST /rest/v1/rpc/<nom>`) pour toutes les opérations métier sensibles.

## Convention d'erreur des RPC

Les RPC lèvent des erreurs dont le SQLSTATE est `PTxxx` ; PostgREST renvoie alors le statut HTTP `xxx`.

```json
{ "code": "PT422", "message": "AGE_NOT_CONFIRMED", "hint": "L'application est réservée aux personnes de 18 ans ou plus.", "details": null }
```

- `message` : code métier stable, à utiliser dans le code client.
- `hint` : texte en français affichable tel quel.
- Toute autre erreur (`42501`, `23xxx`, `PGRSTxxx`…) est technique : le client affiche un message générique (`AppError.from`).

| Code métier | HTTP | Signification |
|---|---|---|
| `AUTH_REQUIRED` | 401 | Pas de session. |
| `PROFILE_REQUIRED` | 403 | Profil non complété (donc majorité non attestée). |
| `ACCOUNT_INACTIVE` | 403 | Compte suspendu ou en cours de suppression. |
| `INVALID_DISPLAY_NAME` | 400 | Nom affiché hors règles (2 à 40 caractères, sans caractère de contrôle). |
| `AGE_NOT_CONFIRMED` | 422 | Attestation de majorité absente. |
| `PROFILE_ALREADY_EXISTS` | 409 | Profil déjà créé. |

## Authentification

Connexion par code à 6 chiffres envoyé par e-mail (valable 10 minutes, un envoi par minute au plus) :

1. `signInWithOtp(email)` crée le compte si besoin et envoie le code.
2. `verifyOTP(email, token, type: email)` ouvre la session.

## Profil

| Opération | Appel | Règles |
|---|---|---|
| Lire son profil | `GET /rest/v1/users` | La RLS ne renvoie que le sien. Aucune ligne → profil à compléter. |
| Créer son profil | `rpc/complete_profile(p_display_name, p_is_adult)` | `p_is_adult` doit valoir `true`. Une seule fois. |
| Modifier son profil | `PATCH /rest/v1/users?id=eq.<moi>` | Colonnes autorisées : `display_name`, `avatar_url`. Compte actif uniquement. |
| Profils publics | `GET /rest/v1/public_profiles` | `id`, `display_name`, `avatar_url` des comptes actifs ; authentifié uniquement. |
| Supprimer son compte | `rpc/request_account_deletion()` | Bloque immédiatement le compte ; purge serveur horaire. |

Le statut du compte, l'attestation d'âge et les dates ne sont jamais modifiables par le client.

## Matchs

| Opération | Appel | Règles |
|---|---|---|
| Lister / lire | `GET /rest/v1/match_details` | Lecture pour tout utilisateur connecté. Champs calculés : `participant_count`, `spots_left`, `display_status`, `is_organizer`, `is_participant`, `location_name`, `latitude`/`longitude` (toujours renseignés). |
| Rechercher | `rpc/search_matches(p_latitude, p_longitude, p_radius_km = 10, p_starts_after, p_starts_before, p_available_only = false, p_skill_level, p_limit = 20, p_offset = 0)` → lignes de `match_details` | Matchs ouverts et à venir dont le **terrain** est dans le rayon, du plus proche au plus lointain puis par date. Rayon 1–100 km, page 1–50, décalage ≤ 1000. Un filtre de niveau inclut les matchs « tous niveaux ». Le point de recherche n'est jamais enregistré. |
| Participants | `GET /rest/v1/match_participants?match_id=eq.<id>` | Inscriptions actives avec nom et avatar ; `is_organizer`. |
| Créer | `rpc/create_match(p_match jsonb)` → `uuid` | Compte actif. L'organisateur est inscrit dans la même transaction. |
| Modifier | `rpc/update_match(p_match_id, p_changes jsonb)` | Organisateur actuel, match ouvert et pas encore commencé. Seuls les champs présents changent. |
| Annuler | `rpc/cancel_match(p_match_id)` | Mêmes conditions. Les inscriptions restent visibles, aucune nouvelle n'est possible. |
| Rejoindre | `rpc/join_match(p_match_id)` | Compte actif, match ouvert, pas encore commencé, place disponible, pas déjà inscrit. Ligne du match verrouillée : deux demandes simultanées pour la dernière place ne peuvent pas réussir toutes les deux. Réinscription possible après un départ. |
| Quitter | `rpc/leave_match(p_match_id)` | Inscrit actif, jusqu'au coup d'envoi. Interdit à l'organisateur (transfert ou annulation). La désinscription reste visible de la seule personne concernée. |

Champs acceptés dans `p_match` / `p_changes` (tout autre champ → `UNKNOWN_FIELD`) : `title`, `description`, `starts_at`, `duration_minutes`, `capacity`, `format` (`5v5`, `7v7`, `11v11`), `skill_level` (`all`, `beginner`, `intermediate`, `advanced`), `location_name` (obligatoire), `latitude`, `longitude` (obligatoires), `estimated_total_cost`, `estimated_cost_per_player`, `currency`.

`display_status` : `open`, `full` (participants actifs ≥ capacité), `in_progress`, `completed`, `cancelled`. Une tâche planifiée passe les matchs terminés en `completed` toutes les 15 minutes ; la vue les affiche comme terminés dès leur fin.

| Code métier | HTTP | Signification |
|---|---|---|
| `INVALID_INPUT`, `UNKNOWN_FIELD`, `INVALID_FIELD_VALUE` | 400 | Saisie mal formée, champ non autorisé, valeur illisible (ex. format inconnu). |
| `INVALID_TITLE`, `INVALID_DESCRIPTION`, `INVALID_START_TIME`, `INVALID_DURATION`, `INVALID_CAPACITY`, `INVALID_FORMAT` | 400 | Titre 3–80 caractères, description ≤ 1000, durée 15–600 min, capacité 4–50. |
| `INVALID_LOCATION`, `INVALID_LOCATION_NAME`, `INVALID_COORDINATES` | 400 | Terrain sans position ou sans nom (2–120 caractères), coordonnées hors limites. |
| `INVALID_COST`, `INVALID_CURRENCY` | 400 | Coût négatif, devise non ISO. |
| `START_TOO_SOON`, `START_TOO_FAR` | 422 | Début dans moins de 15 minutes, ou dans plus d'un an. |
| `NOT_ORGANIZER` | 403 | Action réservée à l'organisateur actuel. |
| `MATCH_NOT_FOUND` | 404 | Match inexistant. |
| `MATCH_NOT_EDITABLE`, `MATCH_ALREADY_STARTED` | 409 | Match annulé / terminé, ou déjà commencé. |
| `CAPACITY_BELOW_PARTICIPANTS` | 409 | Capacité inférieure au nombre d'inscrits actifs. |
| `INVALID_RADIUS`, `INVALID_PAGINATION` | 400 | Rayon ou pagination de recherche hors limites. |
| `MATCH_FULL` | 409 | Plus aucune place. |
| `ALREADY_JOINED`, `NOT_PARTICIPANT` | 409 | Déjà inscrit ; ou pas inscrit (quitter). |
| `MATCH_CANCELLED`, `MATCH_COMPLETED` | 409 | Match annulé ou terminé (rejoindre / quitter). |
| `ORGANIZER_CANNOT_LEAVE` | 409 | L'organisateur doit transmettre l'organisation ou annuler. |

## Recherche d'adresses

Edge Function `geocode` (données OpenStreetMap via Nominatim, gratuit, monde entier, sans clé) :

```http
POST /functions/v1/geocode
Authorization: Bearer <jeton utilisateur>
{ "query": "Stade Jean-Bouin, Paris" }
→ 200 { "places": [{ "name": "Stade Jean-Bouin", "label": "Stade Jean-Bouin, …, France", "latitude": 48.84, "longitude": 2.25 }] }
```

- Réservée aux comptes actifs ; au plus 5 résultats, doublons d'adresse retirés.
- Chaque appel au fournisseur consomme `rpc/consume_geocode_quota()` : 30 recherches par heure et par personne, 1 par seconde au total (règle d'usage de Nominatim ; la fonction patiente une fois avant d'abandonner). Les réponses identiques sont mises en cache 24 h.
- Règles d'usage de Nominatim respectées par l'application : recherche sur validation (pas à chaque frappe), mention « Données © les contributeurs OpenStreetMap ». En production, définir `GEOCODER_USER_AGENT` avec un contact (voir `.env.example`).

| Code | HTTP | Signification |
|---|---|---|
| `INVALID_QUERY` | 400 | Saisie de moins de 3 ou plus de 200 caractères. |
| `GEOCODE_RATE_LIMITED`, `GEOCODE_BUSY` | 429 | Quota personnel atteint, ou service saturé. |
| `GEOCODER_UNAVAILABLE` | 503 | Fournisseur injoignable. |

L'application ouvre un terrain dans Google Maps (application ou navigateur) via le lien universel `https://www.google.com/maps/search/?api=1&query=<lat>,<lng>`, sans clé ni compte.

## Transfert d'organisation

| Opération | Appel | Règles |
|---|---|---|
| Proposer | `rpc/propose_transfer(p_match_id, p_to_user_id)` → `uuid` | Organisateur actuel, match ouvert et pas commencé, cible = participant actif (compte actif), une seule proposition en attente par match. Validité : 48 h, et au plus tard le coup d'envoi. |
| Retirer | `rpc/cancel_transfer(p_match_id)` | Organisateur actuel. |
| Répondre | `rpc/respond_transfer(p_transfer_id, p_accept boolean)` | Uniquement le participant ciblé. À l'acceptation, il devient organisateur ; l'ancien organisateur reste inscrit comme joueur. |
| Consulter | `GET /rest/v1/transfer_details?match_id=eq.<id>&status=eq.pending` | Visible des deux personnes concernées uniquement. |

Annulation automatique d'une proposition en attente : la personne ciblée quitte le match, le match est annulé. Une tâche planifiée (toutes les 15 min) passe les propositions échues en `expired` et prévient l'organisateur. Les RPC verrouillent la ligne du match puis celle de la proposition : une acceptation et un retrait simultanés ne peuvent pas aboutir tous les deux.

| Code métier | HTTP | Signification |
|---|---|---|
| `INVALID_TRANSFER_TARGET` | 400 | Cible absente ou soi-même. |
| `TRANSFER_TARGET_NOT_PARTICIPANT` | 409 | La cible n'est pas inscrite (ou son compte est inactif). |
| `TRANSFER_ALREADY_PENDING` | 409 | Une proposition est déjà en attente. |
| `TRANSFER_NOT_FOUND` | 404 | Proposition inexistante ou adressée à quelqu'un d'autre. |
| `TRANSFER_NOT_PENDING` | 409 | Déjà acceptée, refusée, retirée, ou situation changée. |
| `TRANSFER_EXPIRED` | 409 | Proposition échue ou match commencé / plus ouvert. |

## Notifications

`GET /rest/v1/notifications` : notifications de l'utilisateur dont la date (`scheduled_for`) est atteinte, avec `type`, `title`, `body` (rédigés en français par le serveur), `match_id`, `read_at`. `rpc/mark_notifications_read()` marque tout comme lu. Aucune écriture directe.

| Type | Destinataire | Déclencheur |
|---|---|---|
| `transfer_proposed` | Participant ciblé | Proposition de transfert. |
| `transfer_accepted`, `transfer_declined`, `transfer_expired` | Organisateur qui a proposé | Réponse ou expiration. |
| `transfer_cancelled` | L'autre partie | Retrait par l'organisateur, ou départ de la personne ciblée. |
| `match_cancelled` | Participants (hors organisateur) | Annulation du match. |
| `match_updated` | Participants (hors organisateur) | Changement d'horaire, de durée ou de lieu (pas du titre). |
| `match_reminder` | Chaque participant | 24 h avant le début, seulement si ce moment est encore à venir ; supprimé à la désinscription ou à l'annulation, replanifié si l'horaire change. |

Notifications push (Firebase Cloud Messaging) : à venir, à partir de cette même table.

## Signalements et blocages

| Opération | Appel | Règles |
|---|---|---|
| Signaler | `rpc/report(p_reason, p_user_id?, p_match_id?, p_comment?)` | Un joueur **ou** un match. Motifs : `inappropriate_behavior`, `harassment`, `spam`, `fake_match`, `dangerous`, `other`. Commentaire ≤ 1000 caractères. Un doublon encore ouvert est ignoré sans erreur. Impossible de se signaler soi-même ou son propre match. 10 par jour. |
| Bloquer / débloquer | `rpc/block_user(p_user_id)`, `rpc/unblock_user(p_user_id)` | La personne bloquée ne peut plus rejoindre vos matchs (`JOIN_NOT_ALLOWED`, sans mention du blocage) ; ses matchs disparaissent de vos recherches. Elle n'est pas informée. |
| Mes blocages | `GET /rest/v1/my_blocks` | Visible de la seule personne qui bloque. |

Les signalements (`public.reports`) ne sont lisibles par aucun utilisateur : ils sont traités par
un administrateur dans Supabase Studio (`docs/BETA.md`, section 7).

## Limites anti-abus

| Action | Limite | Code |
|---|---|---|
| Créer un match | 10 par 24 h glissantes | `RATE_LIMITED` (429) |
| Rejoindre ou quitter un match | 30 par heure (cumulés) | `RATE_LIMITED` (429) |
| Signaler | 10 par 24 h | `RATE_LIMITED` (429) |
| Rechercher une adresse | 30 par heure, 1/s au total | `GEOCODE_RATE_LIMITED`, `GEOCODE_BUSY` (429) |
| Recevoir un code de connexion | 1 e-mail par minute | Limite Supabase Auth |

Seules les actions réussies comptent (une action refusée est annulée avec sa transaction).

## Maintenance (serveur uniquement)

`rpc/claim_storage_cleanup` et `rpc/complete_storage_cleanup` : réservées au rôle `service_role`,
utilisées par l'Edge Function `purge-avatars` (appelée par pg_cron, authentifiée par l'en-tête
`x-cleanup-secret`) pour supprimer les photos des comptes purgés.
