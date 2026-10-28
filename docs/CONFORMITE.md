# Conformité aux critères de la spécification

Correspondance entre les critères d'acceptation (`SPECIFICATIONS.md` § 9, § 11 et § 13) et les
tests automatiques qui les vérifient. Tous ces tests tournent en CI (GitHub Actions) à chaque envoi.

Légende des fichiers : `db/` = `supabase/tests/database/`, `app/` = `app/test/`,
`fn/` = `supabase/functions/`.

## Compte et accès

| Critère | Couvert par |
|---|---|
| Non authentifié : ni créer, ni rejoindre, ni modifier | `db/020_matches`, `db/040_participation`, `db/110_security_audit` (aucune fonction exécutable par anon) |
| Impossible de modifier le profil d'un autre | `db/010_users` |
| Compte suspendu : plus d'action protégée | `db/010_users`, `db/020_matches`, `db/040_participation`, `db/030_search`, `db/080_avatars` |
| Suppression de compte testée | `db/010_users`, `db/020_matches`, `db/100_storage_cleanup` (+ essai de bout en bout photo comprise), `app/app_test` |
| Règle d'âge (attestation 18 ans) | `db/010_users`, `app/app_test` |

## Création et capacité

| Critère | Couvert par |
|---|---|
| Capacité 3 refusée | `db/020_matches`, `app/matches_test` |
| Capacité 10 : organisateur inscrit, 9 places | `db/020_matches` |
| Coordonnées obligatoires pour le terrain | `db/020_matches`, `app/matches_test` |
| Match « à définir » sans coordonnées | **Remplacé** : le lieu est toujours défini (décision du porteur du projet, `DECISIONS.md`) ; le mode est refusé (`db/020_matches`) |
| Capacité jamais sous le nombre d'inscrits | `db/020_matches`, `app/matches_test` |

## Inscriptions

| Critère | Couvert par |
|---|---|
| Rejoindre un match ouvert | `db/040_participation`, `app/matches_test` |
| Doublon refusé | `db/040_participation`, `db/050_concurrency` (demandes simultanées) |
| Match complet refusé | `db/040_participation`, `app/matches_test` |
| La désinscription libère une place | `db/040_participation` |
| Match annulé ou terminé refusé | `db/040_participation` |
| Dernière place disputée : un seul gagnant | `db/050_concurrency` (vraies connexions parallèles ; le test échoue si le verrou est retiré) |

## Recherche et localisation

| Critère | Couvert par |
|---|---|
| Rayon par défaut 10 km, modifiable | `db/030_search`, `app/matches_test` |
| Recherche manuelle sans GPS | `app/matches_test` (GPS refusé puis recherche par ville), `fn/geocode` |
| Pas de point inventé sur une carte | Sans objet : aucune carte, et tout match a une position réelle |
| Passés et annulés exclus | `db/030_search` |
| Position privée jamais renvoyée | Jamais stockée (`DONNEES.md`) ; `db/110_security_audit` (aucune colonne de position dans le profil) |

## Transfert d'organisation

| Critère | Couvert par |
|---|---|
| Transfert vers un participant actif accepté | `db/060_transfers`, `app/transfers_notifications_test` |
| Transfert vers un non-participant refusé | `db/060_transfers` |
| Refus ou expiration : organisateur inchangé | `db/060_transfers` |
| Acceptation atomique | `db/060_transfers`, `db/050_concurrency` (acceptation et retrait simultanés) |
| Jamais deux organisateurs | Une seule proposition en attente par match (index unique) + verrous : `db/060_transfers`, `db/050_concurrency` |

## Notifications

| Critère | Couvert par |
|---|---|
| Rappel 24 h avant | `db/070_notifications` |
| Pas de rappel rétroactif (match à moins de 24 h) | `db/070_notifications` |
| Match annulé : pas de rappel | `db/070_notifications` |
| Changement d'horaire : rappel remplacé | `db/070_notifications` |
| Désinscrit : pas de rappel | `db/070_notifications` |
| Pas de doublon en cas de tentatives répétées | `db/070_notifications` |
| Notifications push (envoi, échec) | **À venir** avec Firebase Cloud Messaging (décision ouverte) |

## Sécurité (§ 9)

| Critère | Couvert par |
|---|---|
| RLS sur toutes les tables exposées | `db/110_security_audit` (vérifie automatiquement toute nouvelle table) |
| Aucune écriture directe des champs protégés | `db/020_matches`, `db/060_transfers`, `db/110_security_audit` |
| Fonctions sensibles côté serveur, `search_path` fixé | `db/110_security_audit` |
| Pas de clé secrète dans l'application | `app/config/app_config_test` (refus au démarrage), aucune clé versionnée |
| Validation serveur des dates, capacités, coûts, coordonnées, énumérations, longueurs | `db/010_users`, `db/020_matches`, `db/030_search`, `db/090_moderation` |
| Limitation de débit | `db/090_moderation` (créations, inscriptions, signalements), `db/030_search` (recherche d'adresse) ; connexion : 1 e-mail/min (`supabase/config.toml`) |
| Messages d'erreur sans fuite de données | `db/060_transfers` (proposition d'autrui : « introuvable »), `db/090_moderation` (refus sans mentionner le blocage), `app/data/app_error_test` |
| Signaler / bloquer | `db/090_moderation`, `app/moderation_test` |
| Pas de mention de modération automatique | `app/moderation_test` (« sera examiné ») |

## Périmètre produit

| Critère | État |
|---|---|
| Aucun paiement | Coûts indicatifs seulement, mention « aucun paiement dans l'application » |
| Ni avis ni notes | Absents |
| Pas de messagerie | Absente |
| Football uniquement | Formats 5v5, 7v7, 11v11 uniquement |

## Accessibilité (étape 7)

`app/accessibility_test` : zones tactiles Android/iOS, libellés, contrastes en thème clair et
sombre, texte agrandi à 200 % sans débordement, sur chaque écran principal.
