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
