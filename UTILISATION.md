# Correctif V1.2.1 — relance pêche

Le lancer **classique** revient par défaut. Place le curseur vers l’eau : aucun spot ni contrôle Mouse.Hit n’est imposé à la canne. Le clic du mini-jeu vise toujours sa barre puis tente de remettre le curseur à sa position initiale dans Roblox.

Dans **Fishing** :

- **Visée enregistrée : non** = classique, conseillé pour tester le retour au comportement précédent. Les spots et captures existants restent enregistrés.
- **Visée enregistrée : oui** = assistance avec projection et contrôles stricts, facultative ; capturer alors la visée du spot.
- **Relance après une manche** = 0,35 s par défaut ; cliquer pour choisir 0,75 / 1,5 / 2,5 s. Si le jeu exige plus de temps, augmenter ce délai.

Les 8 s de retry ne sont plus imposées à la première relance après une manche observée. Elles restent entre tentatives quand aucun mini-jeu n’apparaît. Un zéro d’appâts réellement visible suspend la pêche ; un ancien zéro dont la source n’est plus lisible devient inconnu. L’inventaire plein, STOP/F12 et la perte de focus restent prioritaires.

**511 vérifications hors Roblox, aucune confirmation du correctif en jeu.** Voir [tests/VALIDATION_V121.md](tests/VALIDATION_V121.md).

---

# Nouveautés V1.2.0 : configuration guidée

Voir [CONFIGURATION.md](CONFIGURATION.md) pour tous les réglages et le travail interne restant.

- **Farming** : rechercher les affichages temps/pourcentage près de vos plantes, choisir une paire, nommer votre parcelle et son type, puis confirmer la liaison. Le scanner refuse les paires ambiguës. Les cartes continuent ailleurs sur la map ; une lecture figée ou absente devient estimée. Il reste à relier les vrais signaux BlockSpin pour découvrir automatiquement chaque nouvelle plantation et confirmer récolte/replantation.
- **Server** : recherche/tri et avatars des joueurs, suivi local au clic, alertes optionnelles, fil UTC, statistiques de ping, favoris et bilans. Sauvegarder explicitement l'observatoire. Les listes publiques signalent l'indisponibilité de l'API si le client ne peut pas la lire. Choisir puis confirmer un serveur sous 15 s ; cela envoie une requête normale à Roblox.
- **Settings** : thèmes couleur et couleurs récentes, confidentialité, mini-dashboard, ordre/largeur/visibilité des cartes, transfert JSON des réglages et reset d'apparence.
- **Statistics** : préparer une file de trajets/cycles/attentes/pauses et son délai maximal ; erreur ou STOP interrompt la suite. Une échéance de plante calculée ne suffit pas à valider « prête ».
- Les nouvelles observations ne sont écrites que par **Sauvegarder favoris / session / timers**. Une restauration de plantes est isolée par serveur et toujours estimée. Aucun envoi automatique hors du jeu.

Version testée en simulation seulement : voir [tests/VALIDATION_V12.md](tests/VALIDATION_V12.md). Money, visée, vendeur/ATM, conduite et rendu doivent encore être validés dans Roblox pour cette version.

---

# Correctifs 1.1.1 — Money et entrées de pêche

Les captures utilisateur ont montré les limites de la 1.1.0. Cette correction est testée en simulation ; elle reste à essayer dans Roblox/Xeno.

## Money

La lecture est maintenant automatique (cache contrôlé environ toutes les 0,8 s, signaux de modification, nouvelle recherche au plus toutes les 10 s si la source manque). Les libellés explicites de portefeuille et les données numériques publiques de portefeuille réellement présentes dans Player/leaderstats/attributs peuvent être suivis. Aucun remote ni montant n’est inventé.

Si le solde reste N/D : ouvrir l’interface du jeu qui affiche le montant, puis **Rechercher / choisir le compteur** et choisir uniquement le portefeuille. Le compteur choisi est sauvegardé sur cette action explicite. **Revenir à la lecture automatique** supprime ce choix. Une source masquée/absente reste signalée ; N/D ne veut pas dire zéro.

Les cartes **Hausses observées** indiquent les variations positives du compteur. Ce ne sont pas nécessairement des revenus de vente. Les revenus de ventes et les dépôts confirmés du cycle restent séparés ; les baisses observées incluent aussi les dépôts. Une nouvelle source ne crée pas de gain artificiel. L’extrapolation horaire commence après 60 secondes de lecture d’un compteur fiable.

## Spots : procédure corrigée

1. Se placer au point de pêche et cliquer **Enregistrer ce spot**. Un nom vide devient « Spot 1 », « Spot 2 », etc.
2. Cliquer **Capturer la visée dans 3 secondes**, placer le curseur sur l’eau dans Roblox et attendre. La capture est liée directement au spot actif ; il n’est plus nécessaire de recréer le spot après capture.
3. Cliquer **Sauvegarder la bibliothèque** pour conserver ce changement sur disque.

La capture conserve un point monde lorsque `Mouse.Hit` est disponible, avec une visée écran de repli. Au lancer, le point monde est reprojeté par la caméra, le mouvement natif est envoyé, puis le script attend son traitement et vérifie le résultat. Si le point est hors champ, masqué ou si l’entrée est refusée, le lancer est suspendu avec un message. Les anciennes visées uniquement écran restent compatibles, mais doivent être recapturées après un changement de résolution/caméra. Aucun CFrame n’est écrit.

## Curseur et focus

Le clic du mini-jeu vise la cible GUI détectée. Il peut donc être envoyé à la barre quand le curseur était ailleurs, **si Roblox garde le focus et accepte l’entrée native**. Le menu se masque immédiatement pour ne pas intercepter le clic. Le compteur de clics mesure des entrées acceptées, pas des captures de poissons prouvées.

Si une autre application prend le focus, la pêche est mise en pause. Le script ne force pas le focus et ne promet pas une exécution en arrière-plan. Le repli historique mouse1click n’est utilisé que si le curseur était déjà sur la barre avec focus observé ; aucun clic OS n’est envoyé à une position inconnue. La saisie d’un texte ou un glisser de réglage suspend aussi les entrées.

---

# Interface 1.1.0 — nouveautés

Cette version ajoute la catégorie **Server** et un tableau visuel. Les anciennes explications de la 1.0 ci-dessous restent utiles pour les activités et les fichiers.

- **Couleur à la souris** : Settings → faire glisser le curseur sur le plan saturation/luminosité et la barre de teinte. L’interface donne un aperçu ; cliquer **Appliquer la couleur** pour sauvegarder ou **Annuler la couleur** pour revenir à l’accent enregistré. L’hexadécimal, les pastilles et les profils restent disponibles. Le tactile est aussi géré. Le masquage, une perte de focus, STOP ou un changement de catégorie abandonne le glisser en cours.
- **Affichage** : photo Roblox en haut, jauge d’inventaire, cartes de chiffres, listes de spots/trajets/profils cliquables, graphiques FPS/ping et journal technique replié. Cliquer une ligne de bibliothèque préremplit le champ ; les boutons d’action restent nécessaires pour sélectionner un spot ou lancer un trajet.
- **Réglages** : curseur d’échelle 75–150 % (appliqué au relâchement), densité normale/compacte, métriques de l’en-tête, overlay, annonces et masquage pendant le mini-jeu. Ces réglages restent enregistrés avec les profils.
- **Serveur** : population et capacité, ping vers le serveur, identifiant public, joueurs présents paginés par huit et dernières arrivées/départs observés. L’historique commence à l’ouverture du hub, reste en mémoire, et est borné à 80 événements. Les joueurs déjà présents ne sont pas présentés comme des arrivées récentes.
- **Localisation** : « Non fournie ». Roblox n’expose pas la région physique du serveur dans l’API client publique. Le hub n’utilise ni le pays ni l’adresse IP du joueur pour l’inventer.

Le loader de `main` ne charge cette version qu’après fusion de sa PR. Le script complet généré de la branche permet de l’essayer avant fusion. Aucun rendu réel 1.1.0 n’a été validé dans Roblox/Xeno ; voir `tests/VALIDATION_V11.md`.

---

# BlockSpin Private Hub 1.0.0 — Black Edition

Cette version est développée depuis `main` 0.9.1 (`c0da490`) sur `feat/v1.0.0-private-hub`.
**Aucun essai de la 1.0.0 dans Roblox/Xeno n'a été réalisé.** Les tests utilisent Lua 5.4, une maquette Roblox et une physique simplifiée. Consulter `CAPABILITES.md` et `tests/VALIDATION_V1.md`.

## Lancer et arrêter

Coller **tout** `src/main.lua` : c'est le script complet généré, avec les trajets et le noyau V1 intégrés. Aucun autre module n'est téléchargé. `loader.lua` continue de charger la version de `main` ; il ne charge pas cette branche avant fusion. Relancer le script arrête l'instance précédente.

- `RightShift` : masquer/réafficher le menu (raccourci existant modifiable dans Settings).
- `STOP / F12` : invalider l'activité, relâcher les entrées, arrêter l'enregistrement, la pêche, la culture et le cycle automatique. Le bouton indépendant reste accessible lorsque le menu se masque pendant le mini-jeu. La voiture peut continuer sur son élan.
- **Fishing → Reprendre la pêche après STOP** : reprise explicite si l'inventaire n'est pas plein. Pour une vente, libérer l'inventaire manuellement ou lancer explicitement le cycle dans Money.
- **Settings → Avancé → Fermer le script**, ou `getgenv().BlockSpinCycle080.stop()` : fermeture complète, connexions coupées, interface supprimée, aucune sauvegarde à l'arrêt. Le nom global historique est conservé pour la compatibilité.

## Fishing

La logique de pêche historique est conservée : canne équipée, relance, clics du mini-jeu, inventaire `n/18`, arrêt à `x0` appâts et reprise après libération de l'inventaire. STOP suspend aussi les clics.

Les actions « poisson rare » restent **ne rien faire / quitter / aller vendre**. Leur détection repose sur de nouveaux textes ou leur couleur violette pendant/après le mini-jeu ; elle peut produire des faux positifs. Les textes observés ne prouvent ni une espèce ni une capture réussie. STOP annule un départ serveur différé déjà programmé.

Pour créer un spot :

1. Se placer au point de pêche. Facultativement capturer la visée en plaçant la souris sur l'eau pendant le délai de trois secondes.
2. Saisir un nom puis **Enregistrer ce spot**. La position et l'orientation exactes du personnage sont conservées, avec la visée écran si définie ; ce n'est pas la position de l'hameçon.
3. **Sauvegarder la bibliothèque** pour écrire les spots et destinations. Rien n'est sauvegardé automatiquement dans ce fichier.
4. Pour réutiliser un spot, le rejoindre à moins de huit studs puis le sélectionner. La sélection ne déplace pas le personnage. Refaire la visée si la caméra ou la résolution change.

Les statistiques par spot sont celles de la session : tentatives de lancer, textes observés, signaux rares et durée mesurée près du point. Les événements hors de son rayon ne lui sont pas attribués. Maximum 50 spots ; un nom existant n'est jamais remplacé implicitement.

## Vehicle

Au volant, mémoriser la voiture et tester séparément ALLER puis RETOUR. Les trajets de référence restent distincts. La conduite utilise les entrées W/A/S/D et ne modifie ni CFrame ni attribut de vitesse.

Pour une destination supplémentaire : démarrer l'enregistrement, conduire manuellement, arrêter l'enregistrement, saisir un nom et conserver le trajet nommé. **Conduire vers destination** rejoue le trajet depuis une position proche de son parcours. Il ne calcule pas d'itinéraire depuis n'importe où. Sauvegarder explicitement la bibliothèque pour conserver les destinations. Maximum 50 trajets et 2 000 points par trajet.

Les préréglages existants restent Lente 12/5, Normale 20/7, Rapide 30/9 et Max moteur. Les vitesses cibles sont en **studs/s**, non calibrées sur l'affichage du jeu. Le pilote freine près de l'arrivée ; le stationnement n'est annoncé réussi qu'après une vitesse observée au plus égale à 3 studs/s. Il ne garantit pas d'orientation finale. Blocages et dégagements ont des limites ; un échec demande une intervention.

Settings → Avancé conserve l'import v0.6.8, les repères, l'affectation explicite du tampon à ALLER/RETOUR et la sauvegarde historique des trajets. Ces commandes ne sont pas exécutées automatiquement.

## Money et Statistics

Money affiche le solde observé, les revenus de vente mesurés, les dépôts observés et les variations d'appâts. **Actualiser le solde** effectue une lecture explicite ; il n'y a pas de scan financier permanent de toute l'interface.

- Un revenu est ajouté seulement si une vente a fait baisser l'inventaire et si le solde augmente entre ses deux lectures. Un solde inconnu ne crée aucun montant. Une variation passive n'est pas attribuée à une vente.
- Un dépôt est suivi séparément ; il ne diminue pas le revenu gagné. La preuve héritée est une baisse de l'argent en main après confirmation ATM : elle reste une **heuristique**, pas une preuve de transaction bancaire côté serveur.
- Le taux horaire est une extrapolation du revenu observé depuis le lancement, affichée après 60 secondes. Il ne prédit pas un rendement garanti.
- Les baisses d'appâts sont observées, sans attribution certaine à chaque prise. Les ajouts sont comptés séparément.

Statistics contient le tableau AFK, l'activité supervisée, le temps de session, le bilan estimé, les statistiques par spot et les huit dernières erreurs parmi un journal borné à 80. L'index web et les textes de pêche historiques y restent accessibles. Les compteurs de session repartent à zéro au lancement.

## Smart Automation

La vente automatique est désactivée par défaut. Une fois activée, l'inventaire plein déclenche le cycle existant : voiture → vendeur → vente → ATM → voiture → retour → pêche.

Les opérations passent par un superviseur commun : état, délai maximal, vérification du résultat, historique et annulation. Limites : conduite 600 s, marche/entrée 80 s, sortie 10 s, vente 45 s, ATM 25 s. Les fonctions existantes conservent aussi leurs limites internes. Une étape obligatoire échouée arrête le cycle ; le dépôt optionnel peut être abandonné avec son résultat journalisé. « Exiger une preuve de dépôt » refuse aussi un résultat inconnu. Un délai maximal expiré suspend les automatismes.

Les boutons de conduite et le moteur agricole utilisent le même superviseur et le même verrou d'activité. Il n'y a pas de nouvelle interaction serveur devinée.

## Farming

**La culture automatique dans BlockSpin reste indisponible.** Les interfaces et interactions réelles de plantation/récolte n'ont pas été observées. Le bouton refuse le démarrage sans adaptateur ; Diagnostic écran permet de recueillir ces observations.

Le moteur est implémenté et testé avec un adaptateur local : plusieurs parcelles et plantes, états vide/croissance/prête, récolte, replantation, délai de confirmation de 20 s, croissance limitée à 600 s, statistiques et arrêt F12. Exemple de plan : `A:Corn, B:Pumpkin`. Ces noms ne prouvent ni la disponibilité des graines ni leur prise en charge par le jeu.

Pour développer l'intégration après observation, `S.setFarmingAdapter(adapter)` attend trois fonctions locales coopératives : `observe(plot)` → `{state='empty'|'growing'|'ready', crop=...}`, `plant(plot,crop)` et `harvest(plot,crop)` → booléen. Les actions doivent céder régulièrement et respecter l'annulation avant tout effet. Le moteur exige une nouvelle observation conforme après chaque action. Aucun adaptateur du jeu n'est fourni dans cette version.

## Settings, fichiers et génération

L’interface utilise une barre latérale avec icônes locales, des cartes en deux colonnes, des interrupteurs animés et une disposition compacte qui empile les sections. La taille initiale est de 960 × 640, centrée et limitée à la résolution disponible. L’ancienne taille par défaut 430 × 500 migre vers ce format ; les tailles personnalisées sont conservées.

Le profil affiche le `DisplayName`, le `@Name` et la photo du compte actuellement connecté. La miniature est demandée à l’API officielle `Players:GetUserThumbnailAsync`, jamais à un service tiers ; le chargement de l’image est aussi vérifié. En cas d’échec ou d’absence de chargement, un avatar de remplacement reste affiché. En mode compact, seul l’avatar reste visible dans la barre latérale.

Les changements d’onglet, les interrupteurs, les survols et l’ouverture/réduction utilisent TweenService. Les interpolations précédentes sont annulées si nécessaire, puis nettoyées à leur fin ou à la fermeture. Le bouton de réduction fait apparaître un petit bouton « B » pour rouvrir le hub ; STOP reste indépendant. La réduction automatique du mini-jeu n’affiche pas ce bouton. L’option Animations désactive les transitions et applique directement leur état final.

Thème noir, palette et accent libre `#RRGGBB`, animations désactivables, notifications, FPS/ping, échelle, menu redimensionnable/déplaçable et profils existants sont conservés.

| Fichier local de l'exécuteur | Usage |
|---|---|
| `blockspin-settings-v1.json` | Réglages et profils, format historique conservé |
| `blockspin-library-v1.json` | Spots et destinations, sauvegarde explicite seulement |
| `blockspin_data_v080.json` | Trajets historiques ; bouton explicite de sauvegarde uniquement |
| `blockspin_fishlog.json` | Textes de pêche observés, comportement historique conservé |

Une bibliothèque invalide reste intacte et bloque sa sauvegarde pendant la session. Corriger le fichier puis le recharger explicitement. Sans API fichiers, la session reste utilisable en mémoire. Aucune clé ni secret n'est requis dans le client.

Développement : modifier `src/cycle.lua` , le noyau pur `src/hub_core.lua` et la présentation `src/interface.lua`, puis générer `src/main.lua` avec `python -I build.py`. Ne pas modifier le fichier généré à la main. Voir `tests/VALIDATION_V1.md` pour les commandes de vérification.
