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
