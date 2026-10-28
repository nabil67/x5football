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
