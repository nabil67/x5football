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
| 2026-10-28 | Identifiant technique : `x5football`, bundle `fr.x5football.x5football` | Provisoire, à remplacer avec le nom final. |

## Décisions ouvertes

| Sujet | Options / proposition | Nécessaire avant |
|---|---|---|
| Vérification d'âge | Proposition : attestation « J'ai 18 ans ou plus » horodatée, sans date de naissance | Étape 2 |
| Méthode de connexion | E-mail + code OTP, e-mail + mot de passe, Apple/Google | Étape 2 |
| Cartographie / géocodage | Mapbox, Google Maps Platform, OpenStreetMap (Geoapify, Nominatim auto-hébergé…) | Étape 4 |
| Fournisseur push | Proposition : Firebase Cloud Messaging (Android + iOS via APNs) | Étape 6 |
| Délai d'expiration d'un transfert | Proposition : 48 h, configurable côté serveur | Étape 6 |
| Tolérance date passée à la création | Proposition : refuser tout `starts_at` < maintenant + 15 min | Étape 3 |
| Valeurs de `skill_level` | Proposition : `all`, `beginner`, `intermediate`, `advanced` | Étape 3 |
| Versions minimales Android / iOS | Défauts Flutter actuels | Publication |
| Build iOS | Mac, ou CI macOS (Codemagic, GitHub Actions) + compte Apple Developer | Tests iOS |
| Politique de confidentialité, CGU, conservation des données | — | Publication |
| Nom, identité visuelle, textes finaux | — | Publication |
