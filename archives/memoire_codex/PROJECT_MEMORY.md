# Mémoire de projet — BlockSpin Auto Fish / Auto Seeds

Mise à jour : 2026-11-05. Contexte établi à partir des échanges avec l'utilisateur et de l'inspection des ZIP locaux. À utiliser comme contexte de travail pour Codex, pas comme preuve que les scripts fonctionnent en jeu.

## Objectif
Un seul script Lua/Luau, utilisé avec Xeno sur Windows dans Roblox BlockSpin. Priorités : **Auto Fish et Auto Seeds (plantes)**. Cycle ultérieur souhaité : pêche → inventaire 18/18 → même voiture → vendeur → vente → ATM → dépôt maximal → voiture → retour pont → reprise pêche, en boucle ; arrêt si appâts épuisés. Clavier utilisateur **ZQSD**. Ne pas substituer un farm Burger King/generator.

## Ce que l'utilisateur a confirmé
- v0.6.0 : clics répétés du mini-jeu de pêche fonctionnels.
- v0.6.1 : relancement automatique de la canne fonctionne.
- v0.6.4 : pêche et détection inventaire plein fonctionnent, MAIS un ancien bug bloquait l'état FULL après retour à 4/18.
- v0.6.7 : reprise de la pêche après vente et inventaire non plein fonctionne.
- v0.6.8 : `saveRoute()` a retourné `true saved 19 points to blockspin_route_v068.json`; `writefile` fonctionne dans cet environnement, fichier pas forcément visible dans le dossier Windows consulté.
- v0.6.9 : essai de conduite bloqué au point 1/19 (capture d'écran).
- v0.7.0 : test de conduite ZQSD et démarrage automatique préparé, résultat utilisateur pas encore communiqué.

## Interface du mini-jeu
`Players.LocalPlayer.PlayerGui.SliderMinigame` ; descendants à noms numériques dynamiques, ne pas coder en dur. Hint : `Click anywhere when the needle is over the green target`. Barre, cible verte et aiguille blanche sont des Frames ; clics successifs nécessaires (souvent 5–6).

## Inventaire, vente, appâts
- Inventaire 18 emplacements total, incluant objets non poissons ; pause à 18/18 et reprise si <18.
- Bouton observé : `PlayerGui.Items.ItemsHolder.SellAllFishButton`, possiblement invisible tant que la vente n'est pas ouverte. Maintien du clic gauche pendant plusieurs secondes selon utilisateur.
- Appât observé : `PRAWNTEC ULTIMATE x16` ; compteur GUI exact non identifié, détection x0 non validée.

## ATM
- Interaction devant distributeur : E (pression courte), puis DÉPÔT, curseur tout à droite pour montant max, puis CONFIRMER. Interface visible sur captures, mais hiérarchie GUI inconnue et automatisation non validée.
- Position personnage devant ATM : X=-225.32275390625, Y=254.68153381347657, Z=488.1391296386719 ; CFrame complet dans `route_data.json`.

## Positions et routes
- Pêche : (-334.8728332519531,254.77626037597657,836.0563354492188).
- Vendeur : (-255.43922424316407,255.9411163330078,379.14581298828127).
- ATM : (-225.32275390625,254.68153381347657,488.1391296386719).
- Route aller pêche→vendeur : 19 points, du voisinage (-351,254,844) vers (-285,255,432).
- Route retour vendeur→pêche : 20 points, de (-279,256,431) vers (-351,255,860).
- Les points voiture et les positions à pied ne coïncident pas exactement ; il faut gérer parking, entrée du bâtiment, portes, ATM, remontée en voiture. Les routes ne garantissent pas la conduite (direction, contrôle du véhicule, obstacles, siège).
- `route_data.json` joint contient les coordonnées exactes de l'aller et du retour ainsi que les CFrame de pêche, vendeur et ATM.

## Raccourcis v0.6.8
F4 point pêche ; F5 vendeur ; F6 effacer visée ; F7 enregistrer visée ; F8 début/fin enregistrement route ; F9 ATM ; F10 sauvegarder. Stop : `getgenv().BlockSpinV068.stop()`.

## Conduite
- v0.6.9 : F11 démarre, F12 stop, blocage point 1/19 observé.
- v0.7.0 : démarrage automatique en s'asseyant au volant, touches ZQSD, tentative VehicleSeat puis commandes simulées. Stop : `getgenv().BlockSpinDriveAuto070.stop()`. **Non validé dans Roblox**.
- Ne pas présumer que le contrôle du véhicule passe par un VehicleSeat Roblox standard.

## Auto Seeds
Aucune implémentation de plantation/récolte validée. Le ZIP `blockspin-private-hub.zip` est un prototype d'interface ; ses boutons graines ne pilotent pas le jeu. Chercher/implémenter un module de plantation seulement après observation de l'interface ou d'API réellement accessible. Les dépôts GitHub à loader/key ne sont pas automatiquement open source ; vérifier licence et code réel.

## Fichiers locaux inspectés
- `blockspin_auto_fish_v067(1).zip` contient `blockspin_auto_fish_v067.lua`.
- `blockspin_auto_fish_v068.zip` contient `blockspin_auto_fish_v068.lua` et README ; `S.route`, `saveRoute()`, `driveRoute()`, `S.atmCFrame` visibles dans le code.
- `blockspin_drive_auto_v070.zip` contient `blockspin_drive_auto_v070.lua` et README ; commandes ZQSD et liste des 19 points codées.
- `blockspin-private-hub.zip` contient `src/main.lua` (prototype distinct, pas la base Auto Fish).

## Prochaine action concrète
1. Tester la v0.7.0 en voiture et relever son état précis (immobile, tourne, progresse, bloquée).
2. Inspecter les scripts réels avant de fusionner. Ne pas promettre de conduite, dépôt ou seeds fonctionnels avant tests.
3. Conserver l'Auto Fish stable, introduire des modules isolés (navigation, vendeur, ATM, seeds) et un contrôleur d'états avec timeouts et arrêt d'urgence.
4. Lorsqu'un dépôt GitHub précis est fourni, ajouter ces fichiers à sa racine et maintenir la mémoire après chaque changement.
