# Fiche Google Play et formulaires de la Play Console

Réponses prêtes à copier dans la Play Console pour la bêta (piste « Tests internes »).
À relire avant envoi : elles décrivent l'application telle qu'elle est aujourd'hui.

## Fichier à envoyer

`app/build/app/outputs/bundle/release/app-release.aab` (version 1.0.0, code 1), signé avec la clé
d'envoi `C:\Users\nabil\cles\x5football-upload.jks`. Accepter **Play App Signing** (Google conserve
la clé de signature finale ; notre clé ne sert qu'à l'envoi et peut être réinitialisée si perdue).

Reconstruire après une modification (incrémenter `version:` dans `app/pubspec.yaml`, ex. `1.0.1+2`) :
```sh
cd app
flutter build appbundle --release --dart-define-from-file=env/prod.json
```

## Fiche du Store (Présence sur le Store › Fiche principale)

- **Nom de l'application** (30 car. max) : `x5football`
- **Description courte** (80 car. max) :
  `Trouvez des joueurs près de chez vous et organisez vos matchs de foot.`
- **Description complète** :

  > Envie d'un five ce soir ou d'un match à 11 dimanche matin ? x5football met en relation les joueurs de football près de chez vous.
  >
  > ⚽ Trouvez un match à proximité : autour de vous ou dans n'importe quelle ville du monde, avec un rayon de 2 à 100 km, filtrés par date, niveau et places disponibles.
  >
  > 📍 Un vrai terrain pour chaque match : adresse précise, distance, et ouverture dans Google Maps pour l'itinéraire.
  >
  > 🙋 Rejoignez ou quittez un match en un geste : la dernière place ne peut pas être attribuée deux fois.
  >
  > 📝 Organisez vos matchs : 5 contre 5, 7 contre 7 ou 11 contre 11, durée, niveau, nombre de joueurs et coût indicatif du terrain à partager.
  >
  > 🔁 Un empêchement ? Transmettez l'organisation à un autre joueur inscrit.
  >
  > 🔔 Restez informé : rappel 24 h avant le match, prévenu en cas d'annulation ou de changement d'horaire.
  >
  > 🛡️ Une communauté respectueuse : signalement et blocage de joueurs, connexion sans mot de passe par code e-mail, votre position n'est jamais enregistrée.
  >
  > Gratuit, sans publicité, sans paiement dans l'application. Réservé aux adultes (18 ans et plus).
  >
  > Version bêta : vos retours sont les bienvenus à nabil.belahrach@gmail.com

- **Catégorie** : Sports. **Tags** : Football, Sports collectifs.
- **Coordonnées** : e-mail `nabil.belahrach@gmail.com` ; site `https://nabil67.github.io/x5football/`
- **Règles de confidentialité** (Contenu de l'application) : `https://nabil67.github.io/x5football/confidentialite.html`
- **Visuels** : icône 512 × 512 px (provisoire tant que l'identité visuelle n'est pas choisie),
  image de présentation 1024 × 500 px, au moins 2 captures d'écran de téléphone.

## Contenu de l'application (questionnaires)

### Accès à l'application
Toutes les fonctionnalités nécessitent une connexion par code e-mail : répondre « Tout ou partie
des fonctionnalités sont limitées ». Google demande alors comment ses testeurs peuvent se connecter.
- **Tests internes** : pas d'examen complet par Google, cette étape peut attendre.
- **Avant les tests fermés ou la production** : décision à prendre (voir `DECISIONS.md`), par
  exemple un compte de démonstration dont le code arrive dans une boîte e-mail dédiée, partagée
  avec Google le temps de l'examen.

### Annonces
L'application **ne contient pas** de publicité.

### Classification du contenu (questionnaire IARC)
Catégorie « Réseaux sociaux / communication entre utilisateurs » ou « Utilitaire » selon la
proposition de la console. Réponses :
- Violence, sexualité, langage grossier, drogues, jeux d'argent : **non**.
- Les utilisateurs peuvent-ils interagir ou échanger des contenus ? **Oui** (nom, photo de profil,
  titres et descriptions de matchs visibles par les autres).
- Partage de la position avec d'autres utilisateurs : **non** (seul le lieu du terrain choisi
  par l'organisateur est visible, jamais la position d'une personne).
- Achats numériques : **non**.

### Public cible
**18 ans et plus** uniquement. L'application n'est pas destinée aux enfants.

### Sécurité des données (Data safety)
- Collecte de données : **oui**. Partage avec des tiers : **non** (les prestataires techniques
  — hébergement, envoi d'e-mails — sont des sous-traitants, ce qui ne compte pas comme partage).
- Chiffrement en transit : **oui**. Possibilité de demander la suppression : **oui**
  (URL : `https://nabil67.github.io/x5football/suppression-compte.html`).

| Type de donnée (catégorie Play) | Collectée | Obligatoire | Finalités |
|---|---|---|---|
| Informations personnelles › Adresse e-mail | Oui | Oui | Fonctionnement de l'application, gestion du compte |
| Informations personnelles › Nom | Oui | Oui | Fonctionnement de l'application |
| Photos et vidéos › Photos | Oui | **Non** (facultatif) | Fonctionnement de l'application (photo de profil) |
| Activité dans les applications › Autre contenu généré par l'utilisateur | Oui | Oui | Fonctionnement de l'application (matchs, signalements) |
| Position (approximative et précise) | **Non collectée** : utilisée sur l'appareil et envoyée seulement comme critère de recherche, jamais enregistrée | — | — |

> Règle Google : une donnée transmise au serveur de façon éphémère (traitée en mémoire, non
> enregistrée) n'est pas considérée comme « collectée ». C'est le cas de la position de recherche.

### Suppression de compte
URL demandée par la console : `https://nabil67.github.io/x5football/suppression-compte.html`

## Tests internes

Tests et version › Tests › **Tests internes** › Créer une version › envoyer l'`.aab` › ajouter
les adresses e-mail des testeurs (comptes Google) › partager le lien d'inscription.

Rappel : pour un compte développeur personnel récent, la publication en production exige
d'abord un **test fermé avec au moins 12 testeurs pendant 14 jours**.
