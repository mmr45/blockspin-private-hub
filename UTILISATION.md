# BlockSpin Hub 0.8.0 : pêche + cycle vente/ATM

Le hub fusionne deux choses :
- l'interface préparée dans ce dépôt (0.4.0) ;
- le script Auto Fish v0.6.8 et un nouveau cycle de conduite.

Compatibilité Windows/Xeno non certifiée. **Aucune fonction de 0.8.0 n'a encore été testée dans Roblox.** Ce qui est confirmé, simulé ou non testé est détaillé dans `CAPABILITES.md`.

## Lancement

- Coller **tout** `src/main.lua` dans Xeno. C'est le script complet, données de trajet incluses.
- Ou coller `loader.lua`. Il télécharge `src/main.lua` depuis la branche `main` du dépôt public : il n'aura la 0.8.0 qu'après fusion sur `main`.
- Au lancement, le script arrête les anciennes versions : v0.6.x, tests de conduite 069→074, `BlockSpinTeleportConnection`, et une 0.8.0 précédente.

**Arrêt complet** : Settings → « Tout arrêter et fermer le script », ou `getgenv().BlockSpinCycle080.stop()`. Cela relâche les touches et la souris, déconnecte tout, détruit le menu et l'overlay, et n'écrit aucun fichier de données.

## Clavier

Les raccourcis F3–F11 sont remplacés par des boutons. Il reste seulement deux touches :

| Touche | Rôle |
|---|---|
| `RightShift` (modifiable dans Settings) | afficher / masquer le menu |
| `F12` | arrêt d'urgence : annule cycle et conduite, relâche les touches, coupe le cycle auto |

La conduite simule **W/A/S/D**, car W est le KeyCode confirmé pour avancer. Relâcher les touches n'arrête pas instantanément une voiture lancée.

## Onglets

**Cycle**
- État, inventaire, appâts, voiture mémorisée.
- Boutons : pêche ON/OFF, cycle vente/ATM ON/OFF (désactivé au démarrage), lancer un cycle maintenant, annuler, reprendre après erreur.
- Repères : point de pêche / vendeur / ATM « = ici ». La visée prend la position de la souris **3 s après** le clic, le temps de la placer sur l'eau.
- Journal des 8 derniers événements.

**Conduite**
- Mémoriser la voiture : c'est aussi automatique dès que tu es au volant.
- Test ALLER et Test RETOUR, avec départ après 3 s.
- Vitesse cible au format `20/7`, mode natif en ligne droite.
- Enregistrement de trajet dans un **tampon séparé**, puis « → ALLER » ou « → RETOUR ».
- Sauvegarder les données, importer la route v0.6.8.

**Farming** : l'interface 0.4.0 (actions en grille, liste et filtre de graines). **Elle n'est pas reliée au jeu.**

**Fish Index** : vide, aucun poisson inventé.

**Settings**
- Accent, échelle 75–150 %, FPS/ping, overlay déplaçable.
- Masquer le menu pendant le mini-jeu : activé par défaut, car les clics du mini-jeu partent à la position du curseur.
- Choix de la touche d'affichage, recentrage.
- Diagnostic : écrit `blockspin_diag_N.txt` avec les textes visibles et les ProximityPrompts à moins de 25 studs.

Le menu se déplace par l'en-tête et se redimensionne par `<>`. Il s'ouvre à gauche pour laisser le centre libre.

## Cycle

`INVENTORY_FULL → TO_CAR → NAVIGATING_TO_VENDOR → EXIT_CAR → WALK_TO_VENDOR → SELLING → NAVIGATING_TO_ATM → DEPOSITING → BACK_TO_CAR → RETURNING → RESUMING → FISHING`

- Chaque étape a un délai maximal, une annulation et un message. En cas d'échec, l'état passe à `ERROR` sans relance en boucle.
- La vente n'est validée que si le compteur `n/18` **baisse**.
- Le dépôt n'est validé que si l'argent en main **baisse**. Sinon il est marqué « NON vérifié » et le cycle continue (`S.depositRequired = true` pour bloquer).
- L'aller utilise `route_to_vendor` (19 points). Le retour utilise `route_to_fishing` (20 points distincts), jamais l'aller inversé.

## Pilote de conduite

- **Suivi** : projection sur les segments (un point dépassé n'est jamais « derrière »), cible anticipée de 9 à 24 studs selon la vitesse.
- **Vitesse** : limitée par la courbure à venir et la distance de freinage (S sert de frein ; décélération supposée).
- **Demi-tour** : avant braqué, puis marche arrière contre-braquée.
- **Blocage** : dégagement en marche arrière, puis échec explicite.

**Cause probable de l'échec v0.7.4** (non prouvée) : l'aller commence par le demi-tour manuel (caps −124°, +142°, puis ≈180°). Le retour se termine cap ≈ +37°, donc une voiture garée après un retour a le point 2 derrière elle. Côté vendeur, il faut aussi un demi-tour.

## Données et réglages

- Trajets : `blockspin_data_v080.json`, même schéma que `data/route_data.json`.
  - Validation stricte ; un fichier invalide est refusé et les données intégrées sont gardées.
  - Jamais écrit automatiquement ; l'ancien fichier est copié en `.bak` à chaque sauvegarde.
- Réglages du menu : `blockspin-settings-v1.json`, le même fichier que le hub 0.4.0. Les champs inconnus, comme les profils 0.4.0, sont conservés. Un fichier illisible est préservé et l'écriture est coupée pour la session.
- L'ancien `blockspin_route_v068.json` n'est chargé qu'avec le bouton « Importer route v0.6.8 ».

## Passage sous la carte : non réalisé, refusé

- Il n'y a pas de sol sous la carte : en conduite normale, la voiture tombe et est détruite.
- Le seul moyen serait de déplacer la voiture par script. C'est le même type de déplacement que la téléportation qui a déclenché « Téléportation détectée », dans le but de passer sous l'anti-triche. Ce n'est pas fourni.
- Rien ici n'est présenté comme indétectable. Utiliser un exécuteur dans une expérience tierce peut entraîner des sanctions.

## Développement

```
python -m venv .venv && .venv\Scripts\pip install lupa==2.8
.venv\Scripts\python -I build.py              # src/cycle.lua + data/route_data.json -> src/main.lua
.venv\Scripts\python -I tests/check_source.py
.venv\Scripts\python -I tests/run_tests.py
```

Ne pas modifier `src/main.lua` à la main : il est régénéré par `build.py`. Les tests utilisent un modèle de voiture simplifié et une maquette Roblox aux interfaces **inventées**. Ils ne valident ni la physique du G-Cruzer, ni les vrais écrans BlockSpin, ni Xeno. Les tests réels à faire sont listés dans `tests/MANUAL.md`.

Image du README : illustration de [BlockSpin par Cinnamon Go!](https://www.roblox.com/games/104715542330896/BlockSpin). Ce dépôt n'est pas affilié au créateur du jeu.
