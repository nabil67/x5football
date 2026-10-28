# Données collectées, durée de conservation et suppression

Inventaire destiné à la rédaction de la politique de confidentialité et des fiches des boutiques
(« Sécurité des données » sur Google Play, « Confidentialité » sur l'App Store).
À relire par la personne responsable du traitement avant publication.

## Données enregistrées

| Donnée | Où | Visible par | Finalité | Conservation |
|---|---|---|---|---|
| Adresse e-mail | `auth.users` | Personne d'autre (jamais exposée par l'API) | Connexion par code | Jusqu'à la suppression du compte |
| Nom affiché | `users.display_name` | Utilisateurs connectés | Identifier les joueurs | Idem |
| Photo de profil (facultative) | Bucket privé `avatars` | Utilisateurs connectés | Reconnaître les joueurs | Idem ; fichier supprimé par la tâche de nettoyage |
| Attestation « 18 ans ou plus » (date) | `users.age_confirmed_at` | Personne d'autre | Réserver le service aux adultes | Idem |
| Matchs organisés (titre, date, lieu du terrain, coûts indicatifs) | `matches` | Utilisateurs connectés | Organiser les matchs | Idem (supprimés avec le compte de l'organisateur) |
| Inscriptions aux matchs | `participations` | Inscriptions actives : utilisateurs connectés ; historique : la personne seule | Gérer les places | Idem |
| Propositions de transfert | `organizer_transfers` | Les deux personnes concernées | Transmettre l'organisation | Idem |
| Notifications | `notifications` | La personne seule | Informer (annulation, rappel…) | Idem |
| Blocages | `user_blocks` | La personne qui bloque | Sécurité communautaire | Idem |
| Signalements | `reports` | Administrateurs uniquement | Modération | Idem (supprimés avec le compte de l'auteur ou de la cible) |
| Historique anti-abus (action, date) | `private.rate_limit_events` | Personne (serveur) | Limiter les abus | 2 jours |
| Recherches d'adresse (compteur, date) | `private.geocode_requests` | Personne (serveur) | Respecter les limites du service gratuit | 1 jour |

## Données **non** enregistrées

- **Position du téléphone** : demandée seulement quand l'utilisateur appuie sur « Autour de moi »
  ou « Ma position actuelle », utilisée comme point de recherche ou comme position d'un terrain,
  **jamais stockée**, jamais en arrière-plan.
- Texte des recherches d'adresse : transmis au service OpenStreetMap (Nominatim) pour obtenir des
  coordonnées, gardé au plus 24 h dans la mémoire de la fonction serveur, non enregistré en base.
- Date de naissance, numéro de téléphone, mot de passe, données de paiement (aucun paiement).

## Services tiers

| Service | Données transmises | Rôle |
|---|---|---|
| Supabase (hébergement base, authentification, stockage) | Toutes les données ci-dessus | Sous-traitant d'hébergement |
| OpenStreetMap Nominatim | Texte de l'adresse recherchée | Conversion adresse → coordonnées |
| Google Maps (ouvert par l'utilisateur) | Coordonnées du terrain choisi | Itinéraire, hors de l'application |
| Fournisseur SMTP (à choisir) | Adresse e-mail, code de connexion | Envoi des codes |

## Suppression du compte

1. « Supprimer mon compte » dans le profil : l'application efface la photo puis le compte passe
   immédiatement en `pending_deletion` (plus aucune action possible) ; ses matchs à venir sont
   annulés et ses places libérées.
2. Purge horaire : l'identité (`auth.users`) est supprimée ; toutes les données liées suivent
   par cascade (profil, matchs, inscriptions, transferts, notifications, blocages, signalements).
3. Nettoyage horaire : les fichiers photo restants sont supprimés via l'API Storage.

Délai de grâce avant purge : 0 aujourd'hui (décision ouverte dans `docs/DECISIONS.md`).
