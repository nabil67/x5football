# Cahier des spécifications techniques — Application de rencontres sportives
**Version :** 1.2  
**Statut :** spécification de référence pour le MVP  
**Langue :** français  
**Public cible du document :** Claude Code et développeurs du projet

---

## 1. Instructions pour Claude Code

Ce document est la source de vérité fonctionnelle et technique du projet.

Avant de modifier le code :
1. Lis intégralement ce document.
2. Inspecte le dépôt existant et identifie la stack, les conventions, les tests et les fonctionnalités déjà présentes.
3. Présente brièvement un plan avant toute modification importante.
4. Ne remplace pas une architecture existante sans expliquer pourquoi et obtenir confirmation si cela entraîne une réécriture importante.
5. Implémente les fonctionnalités par petites étapes testables.
6. Ajoute ou mets à jour les tests avec chaque fonctionnalité.
7. N'invente pas les décisions laissées « à confirmer » : propose des options et demande confirmation au moment où elles deviennent nécessaires.
8. N'intègre jamais de secrets, mots de passe, clés privées ou clés de service dans le code client.
9. Respecte les règles de sécurité, les autorisations et les règles métier ci-dessous côté serveur, pas uniquement dans l'interface.
10. À la fin de chaque étape, indique les fichiers modifiés, les commandes de test exécutées, les résultats et les points restant à traiter.

### Ordre de travail recommandé
- Étape 0 : inspection du dépôt et proposition de plan.
- Étape 1 : initialisation/configuration de l'application et environnements.
- Étape 2 : authentification, profil, schéma de base de données et règles d'accès.
- Étape 3 : création, lecture, modification et annulation des matchs.
- Étape 4 : recherche géographique et gestion des lieux à confirmer.
- Étape 5 : inscriptions et désinscriptions sécurisées contre les accès concurrents.
- Étape 6 : transfert de l'organisation et notifications/rappels.
- Étape 7 : interface mobile, accessibilité et états de chargement/erreur.
- Étape 8 : tests, durcissement sécurité, documentation et préparation bêta.

Ne considère pas l'application comme prête à publier tant que les tests critiques de capacité, d'autorisation, de confidentialité et de suppression de compte ne passent pas.

---

## 2. Vision du produit

Créer une application mobile qui permet à des adultes de trouver des personnes proches d'eux pour jouer au football. Les utilisateurs peuvent créer un match, découvrir les matchs disponibles à proximité, rejoindre ou quitter un match et organiser collectivement le choix du terrain si celui-ci n'est pas encore défini.

À long terme, le produit pourra s'étendre à d'autres activités sportives ou sociales. Le MVP se limite au football afin de valider l'usage et de contribuer à réduire l'isolement social.

### Objectifs principaux
- Faciliter la création de matchs et la recherche de joueurs.
- Réduire les frictions pour rejoindre un match.
- Permettre de trouver des matchs autour de sa position ou d'une ville/adresse.
- Éviter les dépassements de capacité et les doubles inscriptions.
- Protéger les données personnelles et la localisation précise des utilisateurs.
- Garder le produit gratuit au lancement.

### Hors périmètre du MVP
- Messagerie privée ou de groupe.
- Paiement intégré et collecte d'argent.
- Notes, avis ou évaluations des joueurs.
- Autres sports que le football.
- Système complexe de ligues, classements ou tournois.
- Monétisation, abonnement ou publicité.
- Géolocalisation continue en arrière-plan.

---

## 3. Public, plateformes et décisions de produit

### Décisions retenues
- Plateformes : Android et iOS.
- Public : personnes âgées de 18 ans ou plus.
- Activité au lancement : football uniquement.
- Inscription à un match : immédiate si une place est disponible, sans validation de l'organisateur.
- La capacité d'un match inclut l'organisateur.
- Recherche : GPS si autorisé, ou recherche manuelle par ville/adresse.
- Rayon de recherche par défaut : 10 km, modifiable par l'utilisateur.
- Capacité minimale d'un match : 4 personnes au total, organisateur inclus.
- Lieu : terrain précis ou lieu/zone à définir ensemble.
- Match gratuit ou partage estimatif du coût du terrain ; aucun paiement dans l'application.
- Pas de messagerie dans le MVP.
- L'organisateur peut transférer son rôle à un participant actif ; le participant doit accepter explicitement.
- Rappel push prévu 24 heures avant le début du match.
- Pas de notes ni d'avis dans le MVP.
- Application gratuite au lancement.

### Décisions à confirmer avant publication
- Versions minimales d'Android et d'iOS.
- Fournisseur de cartographie, géocodage et tuiles de carte.
- Méthode proportionnée de vérification de l'âge (ne pas collecter plus de données que nécessaire).
- Politique de confidentialité, conditions d'utilisation et durée de conservation des données.
- Nom, identité visuelle et textes finaux de l'application.

Si une décision à confirmer bloque une fonctionnalité, documente les options et demande confirmation. Utilise des interfaces abstraites/configurables lorsque cela permet d'avancer sans verrouiller un fournisseur.

---

## 4. Parcours et fonctionnalités du MVP

### 4.1 Compte et profil
- Création de compte et connexion via un fournisseur d'authentification.
- Déconnexion.
- Consultation et modification du profil.
- Nom d'affichage obligatoire ; avatar facultatif.
- L'accès au produit est réservé aux adultes selon le mécanisme d'âge qui sera choisi.
- Possibilité de demander la suppression du compte.
- Un compte suspendu ou supprimé ne peut pas effectuer d'action protégée.
- Ne jamais stocker les mots de passe en clair.

### 4.2 Découverte et recherche de matchs
- Afficher les matchs ouverts, futurs et non annulés.
- Recherche par proximité avec coordonnées GPS si l'utilisateur autorise l'accès.
- Recherche manuelle par ville ou adresse si le GPS est refusé ou indisponible.
- Rayon par défaut de 10 km, modifiable.
- Filtres de date, places disponibles et niveau si l'interface les propose.
- Trier par pertinence, puis distance et date selon les filtres actifs.
- Exclure par défaut les matchs passés, annulés et terminés.
- Ne jamais révéler publiquement l'adresse du domicile ou la position privée d'un utilisateur.

### 4.3 Création d'un match
L'organisateur peut renseigner :
- Titre.
- Description facultative.
- Date et heure de début.
- Durée en minutes.
- Capacité totale, organisateur inclus, minimum 4.
- Format : 5 contre 5, 7 contre 7 ou 11 contre 11.
- Niveau indicatif, si souhaité.
- Mode de lieu : terrain précis ou lieu à définir ensemble.
- Nom du lieu et coordonnées si le terrain est connu.
- Coût total estimé et coût estimé par personne, facultatifs.
- Devise par défaut : EUR.

Lors de la création, l'organisateur est automatiquement inscrit au match. Les places restantes correspondent à `capacity - nombre_de_participants_actifs`.

### 4.4 Lieu à définir
- Si le lieu n'est pas connu, afficher clairement « Lieu à confirmer ».
- Ne pas inventer de coordonnées ni afficher un faux marqueur précis.
- Le match peut être publié sans coordonnées exactes.
- Lorsque le lieu est confirmé, l'organisateur peut mettre à jour le nom et les coordonnées.
- Toute modification importante de lieu doit être communiquée aux participants actifs.
- Si le lieu est défini, les coordonnées doivent être valides.

### 4.5 Rejoindre et quitter un match
- Tout utilisateur authentifié et autorisé peut rejoindre directement un match ouvert s'il reste une place.
- La capacité inclut l'organisateur.
- Une personne ne peut pas avoir deux inscriptions actives au même match.
- Si le match est complet, passé, annulé ou terminé, l'inscription doit échouer.
- Une désinscription libère une place.
- Une inscription concurrente à la dernière place doit être traitée de manière atomique : une seule requête réussit.
- Les erreurs de capacité ou de doublon doivent être renvoyées avec un code explicite et un message exploitable par l'interface.

### 4.6 Modification et annulation
- Seul l'organisateur actuel peut modifier ou annuler un match.
- Les matchs annulés ne peuvent plus recevoir d'inscriptions.
- Une annulation doit déclencher des notifications aux participants actifs.
- Si la date/heure change, annuler l'ancien rappel planifié et programmer un nouveau rappel.
- Les changements significatifs (date, heure, durée, lieu, capacité) doivent être communiqués aux participants concernés.
- La modification de capacité ne doit jamais rendre le nombre de participants actifs supérieur à la capacité.

### 4.7 Transfert du rôle d'organisateur
- L'organisateur peut proposer le transfert à un participant actuellement actif.
- Le destinataire doit accepter explicitement.
- Un non-participant ne peut pas recevoir le rôle.
- Le transfert doit être atomique : aucun état intermédiaire où le match n'a pas d'organisateur valide.
- L'ancien organisateur reste participant après le transfert, sauf s'il se désinscrit ensuite selon les règles applicables.
- L'organisateur actuel ne peut pas quitter son propre match tant qu'un transfert n'a pas été accepté ; il peut aussi annuler le match.
- Une demande refusée, expirée ou annulée ne change pas l'organisateur.
- Une seule demande de transfert en attente est autorisée par match.
- Une demande peut expirer après un délai configuré côté serveur ; le délai exact reste à confirmer.

### 4.8 Notifications
- Notifications push pour les événements importants : annulation, changement significatif, transfert d'organisation et rappel.
- Rappel planifié 24 heures avant le début du match.
- Si le match est créé moins de 24 heures avant son début, ne pas envoyer de rappel rétroactif.
- Aucun rappel pour un match annulé ou pour un utilisateur qui n'est plus inscrit.
- En cas de changement d'horaire, supprimer/annuler le rappel précédent et en programmer un nouveau.
- Prévoir un état d'envoi, d'échec et d'annulation des notifications.
- Les notifications ne doivent pas contenir de données privées inutiles.

### 4.9 Sécurité communautaire
- Permettre de signaler un utilisateur ou un match.
- Permettre de bloquer un utilisateur.
- Prévoir des statuts de compte actif, suspendu et supprimé.
- Ajouter une limitation de débit pour les actions sensibles.
- Ne pas promettre de modération automatisée si aucun mécanisme n'est implémenté.

---

## 5. Architecture technique proposée

### Stack de départ
- Application mobile : Flutter.
- Authentification : Supabase Auth.
- Base de données : PostgreSQL.
- Recherche géographique : PostGIS.
- Opérations métier sensibles : fonctions backend sécurisées / RPC transactionnelles.
- Cartographie et géocodage : fournisseur à confirmer.
- Push : fournisseur compatible iOS et Android à confirmer.

Cette stack est une proposition de référence. Si le dépôt contient déjà une stack cohérente, inspecte-la avant toute réécriture et propose les changements nécessaires.

### Principes d'architecture
- Le backend est la source de vérité pour toutes les règles métier.
- Ne jamais compter uniquement sur la validation de l'interface mobile.
- Activer et tester les politiques Row Level Security (RLS) sur les tables exposées.
- Les clés de service et secrets restent uniquement côté serveur.
- Utiliser des migrations versionnées pour la base de données.
- Séparer les environnements développement, test et production.
- Enregistrer les erreurs sans exposer les secrets ni les données personnelles.
- Utiliser des opérations idempotentes lorsque c'est pertinent.
- Toute opération critique multi-étapes doit être transactionnelle.

### Structure indicative du dépôt
À adapter à l'état réel du dépôt, sans imposer une réorganisation inutile :

```text
/
├── README.md
├── CLAUDE.md
├── docs/
│   ├── SPECIFICATIONS.md
│   ├── API.md
│   ├── DATA_MODEL.md
│   └── TEST_PLAN.md
├── app/                  # Application Flutter, si ce choix est confirmé
├── supabase/
│   ├── migrations/
│   ├── functions/
│   └── tests/
└── ...
```

Le présent fichier peut être enregistré sous `docs/SPECIFICATIONS.md`. Il ne remplace pas les instructions courtes propres au dépôt dans `CLAUDE.md` ; ce dernier doit demander à Claude Code de lire ce cahier des charges.

---

## 6. Modèle de données conceptuel

Les noms sont indicatifs. Les migrations doivent ajouter les types, contraintes, index, relations et règles RLS adaptés.

### 6.1 `users`
Profil public et état du compte. L'identité d'authentification reste gérée par Supabase Auth.

Champs proposés :
- `id` : UUID, clé primaire, lié à l'identifiant Auth.
- `display_name` : texte obligatoire.
- `avatar_url` : texte nullable.
- `birth_date` ou résultat d'un mécanisme de vérification d'âge : à choisir selon l'approche retenue.
- `account_status` : `active`, `suspended`, `pending_deletion`, `deleted`.
- `created_at`, `updated_at` : timestamps.

Ne pas exposer publiquement la date de naissance ou une position personnelle. Éviter de conserver une date de naissance si un simple attribut de vérification d'âge suffit.

### 6.2 `matches`
Champs proposés :
- `id` : UUID, clé primaire.
- `organizer_id` : UUID lié à `users.id`.
- `title` : texte obligatoire.
- `description` : texte nullable.
- `starts_at` : timestamp avec fuseau (`timestamptz`).
- `duration_minutes` : entier positif.
- `location_mode` : `fixed` ou `to_define`.
- `location_name` : texte nullable.
- `location` : point géographique nullable.
- `location_status` : `confirmed` ou `to_confirm`.
- `capacity` : entier, minimum 4.
- `format` : `5v5`, `7v7`, `11v11`.
- `skill_level` : texte/enum nullable, valeurs à définir.
- `estimated_total_cost` : numérique nullable, valeur >= 0.
- `estimated_cost_per_player` : numérique nullable, valeur >= 0.
- `currency` : code devise, par défaut `EUR`.
- `status` : `open`, `full`, `cancelled`, `completed`.
- `created_at`, `updated_at`.

Contraintes :
- `capacity >= 4`.
- `duration_minutes > 0`.
- Les coûts, s'ils sont renseignés, sont positifs ou nuls.
- Si `location_mode = fixed`, les coordonnées et le nom du lieu doivent être renseignés et valides.
- Si `location_mode = to_define`, le statut initial est `to_confirm` et les coordonnées peuvent être nulles.
- Le nombre de participants actifs ne doit jamais dépasser `capacity`.
- Le statut `full` doit rester cohérent avec les inscriptions actives. Il peut être calculé à la lecture ou maintenu transactionnellement, mais une stratégie unique doit être choisie et testée.

### 6.3 `participations`
- `id` : UUID.
- `match_id` : UUID lié à `matches.id`.
- `user_id` : UUID lié à `users.id`.
- `status` : `active` ou `cancelled`.
- `joined_at` : timestamp.
- `cancelled_at` : timestamp nullable.

Règles :
- Un utilisateur ne peut avoir qu'une participation active par match.
- Utiliser une contrainte/index unique partiel si adapté au schéma PostgreSQL retenu.
- La création de participation et la vérification de capacité doivent être atomiques.
- À la création du match, la participation de l'organisateur est créée automatiquement.

### 6.4 `organizer_transfers`
- `id` : UUID.
- `match_id` : UUID.
- `from_user_id` : UUID.
- `to_user_id` : UUID.
- `status` : `pending`, `accepted`, `rejected`, `expired`, `cancelled`.
- `created_at`, `expires_at`, `resolved_at`.

Règles :
- Une seule demande en attente par match.
- Le demandeur doit être l'organisateur actuel.
- Le destinataire doit être un participant actif.
- L'acceptation vérifie à nouveau ces conditions dans une transaction.
- Le transfert de rôle et la mise à jour du match sont atomiques.

### 6.5 `notifications`
- `id` : UUID.
- `user_id` : UUID.
- `match_id` : UUID nullable.
- `type` : code d'événement.
- `title`, `body` : texte.
- `scheduled_at`, `sent_at`, `read_at` : timestamps nullable selon l'état.
- `delivery_status` : `pending`, `sent`, `failed`, `cancelled`.
- Identifiant de tâche fournisseur éventuel, si nécessaire.

### 6.6 `reports`
- `id` : UUID.
- `reporter_id` : UUID.
- `reported_user_id` : UUID nullable.
- `match_id` : UUID nullable.
- `reason` : catégorie contrôlée.
- `details` : texte nullable, longueur limitée.
- `status` : `new`, `in_review`, `resolved`, `dismissed`.
- `created_at`, `updated_at`.

Une cible doit être fournie (utilisateur ou match) selon une règle de validation documentée.

### 6.7 `user_blocks`
- `blocker_id` : UUID.
- `blocked_id` : UUID.
- `created_at` : timestamp.
- Clé unique composée (`blocker_id`, `blocked_id`).
- Interdire le blocage de soi-même.

### 6.8 `device_tokens`
- `id` : UUID.
- `user_id` : UUID.
- `platform` : `ios` ou `android`.
- `push_token` : texte unique ou unique par utilisateur/appareil selon le fournisseur.
- `created_at`, `updated_at`, `last_seen_at`.

Les tokens push sont des données sensibles : accès limité et suppression lors de la déconnexion/suppression du compte selon le comportement retenu.

---

## 7. Règles métier critiques

1. La capacité comprend l'organisateur.
2. La capacité minimale est de 4 personnes.
3. L'organisateur est inscrit automatiquement à la création.
4. Aucun participant ne peut être ajouté au-delà de la capacité.
5. Deux requêtes concurrentes pour la dernière place ne doivent pas toutes deux réussir.
6. Un utilisateur ne peut pas s'inscrire deux fois activement au même match.
7. Un match annulé, terminé ou passé n'accepte pas de nouvelle inscription.
8. Seul l'organisateur courant peut modifier ou annuler le match.
9. Le transfert d'organisation exige une acceptation explicite du participant actif ciblé.
10. Les opérations de transfert et d'inscription doivent être atomiques côté serveur.
11. Un match sans terrain précis affiche « Lieu à confirmer » et ne doit pas être positionné artificiellement sur une carte.
12. Le GPS est facultatif ; la recherche manuelle doit fonctionner sans lui.
13. Le rayon par défaut est de 10 km.
14. La position personnelle exacte d'un utilisateur ne doit jamais être rendue publique.
15. Le rappel est planifié à `starts_at - 24 heures`, uniquement si ce moment est encore dans le futur.
16. Les rappels des matchs annulés ou des utilisateurs désinscrits doivent être annulés/ignorés.
17. Les changements d'horaire replanifient le rappel.
18. L'application ne collecte aucun paiement dans le MVP.
19. Aucun système de notes/avis ni messagerie n'est inclus dans le MVP.
20. Les règles d'accès doivent être appliquées au backend et testées avec plusieurs rôles.

### Cohérence du format et de la capacité
Le format décrit le type de match, pas nécessairement une capacité imposée. Fournir des valeurs suggérées (par exemple 10 joueurs pour du 5 contre 5) dans l'interface, mais ne pas forcer ces valeurs sans décision produit explicite. L'organisateur peut ajuster la capacité dans les limites définies.

### Coût estimatif
Le coût affiché est indicatif uniquement. L'application ne collecte pas d'argent et ne garantit pas le montant réel facturé par le terrain. Afficher une formulation telle que « coût estimé par joueur » si le coût est renseigné.

---

## 8. API indicative

Préfixe proposé : `/api/v1`. Si Supabase RPC ou un autre style est retenu, conserver les mêmes capacités et contrôles d'accès.

### Profil
- `GET /users/me` : récupérer son profil.
- `PATCH /users/me` : modifier les champs autorisés.
- `DELETE /users/me` : demander la suppression du compte et lancer le processus sécurisé de suppression.

### Matchs
- `GET /matches` : rechercher les matchs avec filtres géographiques, dates et places disponibles.
- `POST /matches` : créer un match et inscrire automatiquement son organisateur.
- `GET /matches/{id}` : détails d'un match.
- `PATCH /matches/{id}` : modifier un match si l'utilisateur est l'organisateur.
- `POST /matches/{id}/cancel` : annuler un match si l'utilisateur est l'organisateur.
- `GET /matches/{id}/participants` : liste des participants selon la politique de visibilité retenue.

### Inscriptions
- `POST /matches/{id}/participations` : rejoindre un match.
- `DELETE /matches/{id}/participations/me` : quitter un match.
- `GET /users/me/matches` : liste des matchs de l'utilisateur.

### Transfert d'organisation
- `POST /matches/{id}/transfers` : proposer un transfert.
- `POST /matches/{id}/transfers/{transferId}/accept` : accepter.
- `POST /matches/{id}/transfers/{transferId}/reject` : refuser.

### Notifications et sécurité
- `GET /users/me/notifications` : notifications de l'utilisateur.
- `POST /reports` : signaler un utilisateur ou un match.
- `POST /users/me/blocks` : bloquer un utilisateur.
- `DELETE /users/me/blocks/{userId}` : débloquer un utilisateur.

### Recherche géographique — exemple
```http
GET /api/v1/matches?latitude=47.5861&longitude=1.3350&radius_km=10&date_from=2026-11-01T00:00:00Z&available_only=true
```

La recherche par ville/adresse doit d'abord convertir le lieu en coordonnées via le fournisseur de géocodage. Le serveur applique le rayon, les filtres et la pagination. Ne jamais accepter aveuglément des valeurs de rayon ou de pagination non bornées.

### Exemple de création d'un match dont le lieu reste à définir
```json
{
  "title": "Football entre joueurs du coin",
  "description": "Match amical ouvert à tous les niveaux",
  "starts_at": "2026-11-01T14:00:00Z",
  "duration_minutes": 90,
  "location_mode": "to_define",
  "location_name": "Secteur centre-ville",
  "capacity": 10,
  "format": "5v5",
  "skill_level": "all",
  "estimated_total_cost": null,
  "estimated_cost_per_player": null,
  "currency": "EUR"
}
```

Résultat attendu :
- Match créé avec `location_status = to_confirm`.
- Participation active créée pour l'organisateur.
- Neuf places restantes si aucun autre participant n'est inscrit.
- Aucun point géographique exact inventé.

Les dates ci-dessus sont des exemples, pas des dates de production.

### Codes d'erreur recommandés
- `400` : données invalides.
- `401` : authentification requise.
- `403` : action interdite.
- `404` : ressource introuvable ou non visible.
- `409` : conflit, match complet, doublon ou état incompatible.
- `422` : règle métier non satisfaite.
- `429` : limite de débit dépassée.
- `500` : erreur interne générique, sans détails sensibles.

---

## 9. Sécurité, confidentialité et fiabilité

- Appliquer le principe du moindre privilège.
- Activer RLS sur les tables exposées et ajouter des tests pour chaque politique.
- Un utilisateur ne peut modifier que son profil et ses données autorisées.
- Un participant ne peut pas changer `organizer_id`, `capacity`, `status` ou d'autres champs protégés directement.
- Les changements sensibles passent par des fonctions backend vérifiant le contexte d'authentification.
- Ne jamais exposer la clé de service Supabase dans l'application mobile.
- Valider côté serveur les dates, capacités, coûts, coordonnées, durées et énumérations.
- Refuser les dates de match incohérentes ou passées lors de la création, selon une tolérance à définir.
- Limiter les longueurs des champs textuels et nettoyer les entrées.
- Ajouter une limitation de débit pour les inscriptions, créations, signalements et authentifications si applicable.
- Éviter les journaux contenant des tokens, adresses privées, dates de naissance ou contenus sensibles.
- Prévoir un flux de suppression de compte conforme aux exigences applicables et aux règles des boutiques.
- Documenter la conservation et la suppression des données.
- Utiliser des secrets d'environnement côté serveur et des fichiers d'exemple sans secrets.
- Les messages d'erreur ne doivent pas révéler l'existence de données privées.

---

## 10. Notifications : logique serveur

Pour chaque match à venir :
1. À la création, calculer `reminder_at = starts_at - interval '24 hours'`.
2. Si `reminder_at` est dans le futur, planifier le rappel.
3. Sinon, ne pas créer de rappel rétroactif.
4. Lors d'un changement d'heure, annuler l'ancien rappel et en créer un nouveau si pertinent.
5. Lors de l'annulation du match, annuler les rappels en attente.
6. Lorsqu'un participant se désinscrit, empêcher l'envoi du rappel à cette personne.
7. Avant l'envoi, revalider l'état du match et de la participation.
8. Enregistrer les échecs et prévoir une stratégie de reprise sans envoi en double.

La planification doit être exécutée côté serveur. Ne pas dépendre d'un minuteur local sur le téléphone.

---

## 11. Plan de tests et critères d'acceptation

### Compte et accès
- Un utilisateur non authentifié ne peut pas créer/rejoindre/modifier un match.
- Un utilisateur ne peut pas modifier le profil d'un autre utilisateur.
- Un compte suspendu ne peut plus réaliser d'actions protégées.
- La procédure de suppression de compte est testée.
- La règle d'âge est appliquée selon le mécanisme qui sera retenu.

### Création et capacité
- Une capacité de 3 est rejetée.
- Un match de capacité 10 inscrit l'organisateur et dispose de 9 places restantes.
- Les coordonnées sont obligatoires pour un lieu fixe.
- Un match `to_define` peut être créé sans coordonnées et affiche « Lieu à confirmer ».
- Une capacité ne peut pas être réduite sous le nombre de participants actifs.

### Inscriptions
- Un utilisateur peut rejoindre un match ouvert avec une place disponible.
- Un doublon d'inscription active est refusé.
- Un match complet refuse toute inscription supplémentaire.
- Une désinscription libère une place.
- Un match annulé ou terminé refuse les inscriptions.
- Test de concurrence : si deux utilisateurs tentent de prendre la dernière place, un seul réussit.

### Recherche et localisation
- Le rayon par défaut est de 10 km.
- L'utilisateur peut modifier le rayon.
- La recherche manuelle fonctionne sans autorisation GPS.
- Les matchs sans coordonnées exactes ne sont pas présentés comme des points précis sur la carte.
- Les matchs passés et annulés sont exclus par défaut.
- Les coordonnées privées de l'utilisateur ne sont jamais retournées dans les réponses publiques.

### Transfert d'organisation
- Un transfert vers un participant actif peut être accepté.
- Un transfert vers un non-participant est refusé.
- Un refus ou une expiration ne change pas l'organisateur.
- L'acceptation met à jour le rôle de façon atomique.
- Deux transferts concurrents ne peuvent pas produire deux organisateurs.

### Notifications
- Un rappel est planifié 24 heures avant un match créé suffisamment tôt.
- Aucun rappel rétroactif n'est planifié si le match est créé moins de 24 heures avant.
- Un match annulé n'envoie pas de rappel.
- Un changement d'horaire remplace l'ancien rappel.
- Un participant désinscrit ne reçoit pas de rappel.
- Les tentatives répétées ne provoquent pas de notifications en double.

### Périmètre produit
- Aucun paiement n'est proposé.
- Aucun avis ou système de notes n'est présent.
- Aucune messagerie n'est incluse dans le MVP.
- Seul le football est disponible dans le MVP.

---

## 12. Livrables attendus

- Application Flutter Android/iOS.
- Migrations SQL versionnées.
- Contraintes et index PostgreSQL/PostGIS.
- Politiques RLS documentées et testées.
- Fonctions transactionnelles pour création, inscription, désinscription et transfert.
- Contrat API documenté (OpenAPI ou documentation équivalente).
- Tests unitaires, d'intégration et de sécurité.
- Documentation de configuration locale.
- Fichier `.env.example` sans secrets.
- Guide de déploiement.
- Plan de test bêta et liste des décisions encore ouvertes.

---

## 13. Definition of Done

Une fonctionnalité est terminée lorsque :
- Le comportement correspond aux règles métier.
- Les contrôles sont réalisés côté serveur.
- Les cas d'erreur sont traités dans l'interface.
- Les tests correspondants passent.
- Les politiques RLS ont été vérifiées si des données sont exposées.
- Les migrations sont versionnées et reproductibles.
- Aucune clé secrète n'est intégrée au client.
- La documentation nécessaire est mise à jour.
- Les limitations et décisions en attente sont signalées.

---

## 14. Première consigne pratique pour Claude Code

Au démarrage du projet, demande à Claude Code :

> Lis `docs/SPECIFICATIONS.md` en entier. Inspecte le dépôt actuel sans modifier de fichier. Résume l'architecture et l'état du projet, relève les décisions encore ouvertes, identifie les risques techniques majeurs, puis propose un plan d'implémentation par étapes avec les tests à prévoir. N'écris pas encore de code avant de m'avoir présenté ce diagnostic.

Une fois le diagnostic validé, demander une étape à la fois. Ne pas demander la génération de toute l'application en une seule opération.

---

## 15. Notes de mise en œuvre

- Les exemples de noms de tables, endpoints et valeurs d'énumération sont une base de travail ; les migrations finales doivent être cohérentes entre elles.
- Les règles critiques doivent être garanties par des contraintes SQL et/ou des fonctions transactionnelles, pas seulement par du code Flutter.
- La méthode de vérification d'âge, le fournisseur de cartographie et les versions minimales des systèmes restent des décisions ouvertes.
- Les coûts sont indicatifs ; aucune transaction financière n'est gérée dans le MVP.
- La capacité minimale de 4 représente une limite de configuration, pas une garantie que quatre personnes seront présentes le jour du match.
