# Correctif V1.1.1 — 2026-11-06

- Base : main `109e18cfd2c968610b5c6ab01cc4c7a1671b8514`, PR #5 fusionnée. Branche `fix/v1.1.1-money-fishing-input`, livraison par PR sans fusion automatique.
- Retour réel utilisateur (captures 1.1.0) : UI affichée, Money bloqué à N/D/0, noms de spots invalides/absents, appât dépendant du curseur et clics du mini-jeu perdus hors fenêtre. Ce retour ne valide pas la version corrigée.
- Money : lecture automatique avec cache et signaux Text/Value/attributs publics existants, scans manquants bornés à 10 s. Sources explicites de portefeuille ; montants nus/ambigus seulement sur choix utilisateur. N/D avec état explicite si aucun compteur fiable. Aucune donnée privée ou remote deviné.
- Hausses/baisse du compteur séparées des ventes et dépôts vérifiés du cycle. Changer de source ne crée pas de faux gain. Estimation horaire uniquement après 60 s d’observation d’un compteur.
- Spots : nom vide devient « Spot 1 », noms nettoyés, capture rattachée au spot actif même après sauvegarde en mémoire, point monde/viewport optionnels conservés dans la bibliothèque v1. Point de retour du cycle mis à jour en mémoire, jamais de déplacement direct.
- Entrées pêche : reprojection du point monde par Camera, mouvement de souris natif puis attente/contrôle, vérification de Mouse.Hit si disponible. Clic au centre de la cible GUI détectée, hit-test pour l’inset, masquage immédiat du menu automatique. Pas de clic OS à une position inconnue.
- Perte de focus : pêche suspendue, reprise avec réinitialisation ; saisie/curseur de réglage suspend les entrées. **Aucune promesse de fonctionnement en arrière-plan, aucune prise de focus forcée ni contournement.**
- 373 vérifications réussies en simulation, build et contrôles statiques réussis. Correctif à valider dans Roblox/Xeno ; voir `tests/VALIDATION_V111.md`.
- Demande suivante utilisateur : idées Server et détection de plantation avec timers à distance. **Pas encore implémenté** : il faut observer les signaux de plantation/croissance et la source de durée réelle. Un timer estimé ne doit jamais être annoncé exact. Clarification reçue : ailleurs sur la map, le jeu montre un temps et un pourcentage. Prochaine étape : identifier leurs objets/signaux réels et l’identité de chaque plante ; ne pas annoncer ce tracker comme implémenté dans le correctif Money/pêche.

# V1.1.0 — tableau visuel et serveur — 2026-11-06

- Base : main `39feadb0a1fd722624b3ca11c8c21742eef35dad` (PR #4 fusionnée par l’utilisateur). Nouvelle branche `feat/v1.1-visual-dashboard`, nouvelle PR à relire sans fusion automatique.
- Demande : supprimer les pavés de texte, avatar à la place du logo B en haut, palette choisie à la souris, réglages plus clairs et rubrique serveur.
- Ajouts : sélecteur HSV souris/tactile avec aperçu, application/annulation explicites ; pas d’écriture ni de nouveau tween par pixel. Palette, hex et profils synchronisés.
- Profil Roblox déplacé en haut. Compteurs, jauges, listes cliquables, graphiques FPS/ping réels bornés à 30 mesures ; journal technique replié.
- Échelle réglable au glisser, densité compacte, métriques et masquage du mini-jeu configurables. Listes de spots/trajets/profils préremplissent les champs sans lancer d’activité.
- Page Server : population/capacité, ping, identifiant, liste paginée des présents, dernières arrivées/départs observés depuis l’ouverture. Historique borné à 80, non sauvegardé, observateurs déconnectés à l’arrêt.
- **La région physique du serveur n’est pas exposée par l’API client publique.** Elle reste « Non fournie ». Ne jamais la déduire du pays du joueur ou de son IP.
- Source de widgets : `src/visuals.lua`, injectée dans la portée privée de `src/interface.lua` par `build.py`. Le script complet actif reste `src/main.lua`, généré.
- Tests locaux : 310 vérifications, 0 échec ; maquettes HTML issues de la simulation inspectées. Aucune validation de rendu Roblox/Xeno réelle. Auto Farm toujours sans adaptateur BlockSpin.

# Refonte de présentation V1 — 2026-11-06

- Demande explicite : UI soignée inspirée des captures fournies, transitions fluides, avatar Roblox, DisplayName et @username. Ajouter à la PR #4, sans fusion.
- Présentation dans `src/interface.lua`, injectée par `build.py` avec le noyau et les trajets. `src/main.lua` reste l’unique script actif généré.
- Barre latérale, cartes en deux colonnes, vrais interrupteurs, palette avec rouge par défaut, profils et réglages existants conservés. Mode compact, résolution/caméra suivies.
- Miniature officielle `GetUserThumbnailAsync`, trois tentatives maximum, image réellement chargée avant masquage du remplacement, résultat tardif ignoré après fermeture.
- Transitions annulables et nettoyées ; mode sans animation ; réduction/réouverture et STOP indépendant. Aucun nouveau raccourci ni automatisme de jeu.
- 251 vérifications locales réussies (205 antérieures + 46 UI), build et statique réussis. Inspection de maquettes HTML issues de l’arbre Lua simulé ; **aucun rendu réel Roblox/Xeno confirmé**.

# Mise à jour V1.0.0 — 2026-11-06

- Base distante vérifiée : `main` 0.9.1, commit `c0da490fcbcaf60e9a9f3c3142dad508c3bd29bc`. Les mentions de `main` 0.4.0 plus bas sont historiques.
- Travail sur `feat/v1.0.0-private-hub`, PR vers `main`, sans fusion automatique.
- Sources : `src/cycle.lua` et noyau pur `src/hub_core.lua`. `build.py` injecte ce noyau et les données dans le seul script actif `src/main.lua` ; ne pas modifier le généré à la main.
- Black Edition six onglets ; spots/destinations nommés ; bibliothèque `blockspin-library-v1.json` avec sauvegarde explicite et rejet atomique des fichiers invalides.
- Money Manager et statistiques de session, superviseur partagé avec délais/annulation et tableau AFK. STOP suspend aussi les clics/lancers et invalide les actions différées. Vitesse finale mesurée requise pour annoncer un stationnement.
- Moteur agricole multi-plantes/replantation simulé ; **aucun adaptateur BlockSpin ni interaction agricole réelle fourni**. Ne pas annoncer Auto Farm fonctionnel en jeu.
- Tests : référence 0.9.1 = 120 vérifications ; V1 = 205 vérifications, 0 échec, Python 3.12 / lupa 2.8 / Lua 5.4. Build et contrôles statiques réussis. Aucun essai V1 Roblox/Xeno.
- README image seule, loaders vers main, archives et `data/route_data.json` conservés. Aucune donnée de l'utilisateur écrasée automatiquement.
- Prochain travail : suivre `tests/MANUAL.md`, caractériser les interfaces réelles vendeur/ATM et agricoles, recueillir une confirmation datée par version. Voir `tests/VALIDATION_V1.md`.

---

# Mémoire de projet : BlockSpin Auto Fish / cycle

Mise à jour : 2026-11-05 (reprise par Claude). La version Codex d'origine est dans `sources_originales/memoire_codex/`.
À utiliser comme contexte, pas comme preuve que les scripts fonctionnent en jeu.

## Environnement
Windows, Xeno, clavier AZERTY (ZQSD à la main ; le KeyCode simulé **W** fait avancer, confirmé le 05/11/2026).
Jeu : https://www.roblox.com/games/104715542330896/BlockSpin. L'utilisateur n'a pas accès à Studio ni au projet du jeu.
Aucun outil de l'assistant ne peut contrôler Roblox/Xeno sur le PC : tous les essais en jeu sont faits par l'utilisateur.

## Fichiers (dépôt `mmr45/blockspin-private-hub`, branche `v0.8-cycle-hub`)
- `src/main.lua` : **script unique actif** (hub + pêche + cycle), généré par `build.py` depuis `src/cycle.lua` + `data/route_data.json`. Ne pas le modifier à la main.
- `data/route_data.json` : données de référence (aller 19 points, retour 20 points distincts, CFrame pêche/vendeur/ATM). Ne pas écraser.
- `archives/` : v0.6.8, v0.6.9 et la mémoire Codex, intactes.
- `tests/` : `run_tests.py` (lupa 2.8), `check_source.py`, modèle de voiture, maquette Roblox, `MANUAL.md` (essais réels à faire).
- `UTILISATION.md` : mode d'emploi. `CAPABILITES.md` : matrice des preuves. `README.md` = image seule (choix de l'utilisateur).
- Absents : v0.6.7, v0.7.0, sources exactes de v0.7.1 à v0.7.4.

## Dépôt GitHub
Public. Branche `main` = hub 0.4.0 (HEAD 4aec1c4). La 0.8.0 est sur la branche `v0.8-cycle-hub`, commitée en local le 05/11/2026. **Pousser ou fusionner seulement sur demande explicite.** `loader.lua` charge `main/src/main.lua` : il donne la 0.8.0 seulement après fusion.
## Historique des confirmations utilisateur
- v0.6.0 : clics du mini-jeu. v0.6.1 : relance de la canne. v0.6.4 : inventaire plein détecté. v0.6.7 : reprise après vente. v0.6.8 : writefile OK.
- v0.6.9 : bloqué au point 1. v0.7.1 : bloqué au point 2 (distance 20), zigzags.
- Test isolé : W fait avancer le G-Cruzer (`Workspace.Vehicles.G-Cruzer.DriverSeat`). `Motors.forwardMaxSpeed` = 65, unité inconnue.
- v0.7.2 lente (12/4) : pont → vendeur réussi **une fois**.
- `require(ReplicatedStorage.Modules.Game.VehicleSystem.Vehicle)` échoue (erreur de chargement).
- Téléportation du personnage : « Téléportation détectée », abandonnée.
- v0.7.4 : « Point 2 derrière », voiture restée sur le pont.

## Analyse v0.8.0 (2026-11-05)
- L'aller commence par le demi-tour manuel de l'utilisateur : caps 1→2 −124°, 2→3 +142°, puis ≈180°.
- Le retour se termine cap ≈ +37°. Une voiture garée après un retour a donc le point 2 derrière elle. C'est la cause la plus probable de l'échec v0.7.4, **non prouvée**.
- Côté vendeur, l'aller arrive cap ≈ +103° et le retour repart cap −80° : il faut aussi un demi-tour.
- Le pilote v0.8.0 gère ces cas (projection sur segments, demi-tour, freinage, dégagement). Il est simulé seulement.

## v0.8.0 : statut
- Implémenté : pêche v0.6.8 conservée, machine à états du cycle complet, vente et dépôt validés seulement par une preuve (baisse de l'inventaire / de l'argent), entrée/sortie de la même voiture, interface du hub 0.4.0 reliée au cycle (F3–F11 remplacées par des boutons ; restent RightShift et F12), diagnostic (Settings), arrêt F12 et `stop()`, données JSON validées et jamais écrasées automatiquement.
- Tests : 88 vérifications hors Roblox passent (2026-11-05). Elles ne valident ni la physique réelle ni les interfaces réelles.
- **Aucun essai en jeu de v0.8.0 à ce jour.**
- Passage sous la carte : non implémenté et refusé (contournement d'anti-triche ; physiquement impossible en conduite native). Voir README.
- Auto Seeds : non implémenté (aucune observation de l'interface de plantation).

## Prochaines étapes
1. L'utilisateur fait « Test ALLER » au volant au pont, puis envoie une capture du panneau. Vérifier aussi le sens du braquage A/D.
2. « Test RETOUR » depuis le parking vendeur.
3. Settings → Diagnostic devant l'ATM, écran DÉPÔT ouvert, puis devant le vendeur, puis près de la voiture : obtenir la vraie hiérarchie GUI et les vrais prompts. Adapter ensuite `depositAll` / `enterCar`.
4. Cycle complet avec « Cycle auto ».
5. Auto Seeds : Diagnostic au potager, puis concevoir un module isolé.

## v0.9.0 (2026-11-05, branche `v0.9-hub`)
Retours utilisateur sur la 0.8.0 (menu chargé par loader après fusion PR #1) : voiture bloquée vers 12-13 km/h, menu trop chargé, overlay FPS caché sous les boutons Roblox. Changements : menu en 3 onglets, préréglages de vitesse (défaut Rapide 30/9, Max moteur), palette, profils, poisson rare (quitter/vendre), index web. Refusés : achat à distance, passage sous la carte (redemandé). Non testé en jeu.
