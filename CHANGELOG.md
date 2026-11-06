# Historique

## Refonte UI 1.0.0 — 2026-11-06 (même PR)

- Direction visuelle inspirée des références utilisateur : barre latérale à icônes locales, fond noir, accent rouge par défaut, cartes en colonnes, typographie et espaces revus.
- Photo de profil Roblox via l’API officielle, DisplayName et @username du joueur connecté ; chargement et échec de miniature gérés avec un remplacement.
- Transitions d’onglets, interrupteurs, survols, ouverture/réduction ; option sans animation, annulation des anciennes interpolations et nettoyage.
- Réouverture par bouton « B », STOP indépendant, disposition compacte, adaptation aux changements de caméra/résolution et migration de l’ancienne taille par défaut.
- Présentation isolée dans `src/interface.lua`, intégrée au script unique par `build.py`.
- 251 vérifications locales réussies, dont 46 cas de contrat UI supplémentaires. Maquettes visuelles issues de l’arbre Lua inspectées ; aucun rendu Roblox réel validé.

## 1.0.0 — 2026-11-06 (validation Roblox requise)

- Black Edition : six onglets, accent libre, animations désactivables et bouton STOP indépendant.
- Spots précis et destinations nommées, bibliothèque validée et sauvegardée explicitement ; routes historiques inchangées.
- Money Manager de session : revenus observés pendant les ventes, dépôts séparés, taux après 60 s et suivi des variations d'appâts.
- Superviseur partagé des étapes : délais, résultats vérifiés, annulation, historique et journal borné ; tableau AFK.
- STOP suspend aussi la pêche et les actions différées ; stationnement refusé tant que la vitesse finale reste trop élevée.
- Moteur agricole multi-plantes et replantation testé avec adaptateur simulé. **Intégration réelle BlockSpin absente et démarrage bloqué sans adaptateur.**
- Génération conservée, noyau pur `src/hub_core.lua` injecté par `build.py`, mode `--check` et workflow CI.
- Tests locaux : 205 vérifications, 0 échec. Aucun test 1.0.0 dans Roblox/Xeno ; voir `tests/VALIDATION_V1.md`.

## 0.8.0 — 2026-11-05 (branche `v0.8-cycle-hub`, non testée en jeu)

- Le hub devient le script principal. `src/main.lua` est généré par `build.py` à partir de `src/cycle.lua` et `data/route_data.json`.
- Pêche Auto Fish v0.6.8 reprise sans changement (mini-jeu, relance, inventaire n/18, appâts).
- Cycle complet par états : voiture → vendeur → ATM → retour → pêche. Vente et dépôt validés uniquement par une baisse mesurée.
- Nouveau pilote W/A/S/D : projection sur segments, anticipation, freinage, demi-tour, dégagement. Aucune téléportation.
- Raccourcis F3–F11 remplacés par des boutons. Il ne reste que la touche d'affichage (RightShift) et F12 (urgence).
- Nouveaux onglets Cycle (ouvert par défaut) et Conduite. Farming et Fish Index sont conservés tels quels (non reliés au jeu).
- Le menu se masque pendant le mini-jeu et s'ouvre à gauche par défaut.
- Réglages `blockspin-settings-v1.json` repris. Les champs 0.4.0 (profils, mode overlay…) sont conservés dans le fichier mais ne sont plus gérés par l'interface.
- Retirés de l'interface : profils, histogrammes FPS/ping, modes d'overlay, bouton de réinitialisation, test d'erreur volontaire.
- Tests : `tests/run_tests.py` (88 vérifications, maquette + modèle de voiture simplifié) remplace `tests/test_runtime.py`. `check_source.py` est réécrit.
- Sources historiques (v0.6.8, v0.6.9, mémoire Codex) archivées dans `archives/`.

## 0.4.0 — 2026-11-05

- Refonte de l'interface : fond charbon, accent personnalisable, barre de navigation et indicateur actif.
- Farming ouvert par défaut, actions en grille et champs de graines alignés.
- Titres de page et sections distinctes, contrôles bordés, overlay assorti.
- Navigation compacte sur les petites fenêtres ; taille minimale 480 × 400 si l'écran le permet.
- Réglages et profils précédents conservés ; aucune nouvelle automatisation de jeu.

## 0.3.0 — 2026-11-05

- Échelle du menu réglable de 75 à 150 %.
- Jusqu'à 10 profils nommés : enregistrer, remplacer, charger et supprimer.
- Choix FPS seuls, ping seul ou les deux dans l'overlay.
- Histogrammes FPS/ping des 30 dernières mesures, activables dans Settings.
- Recentrage du menu et de l'overlay ; réinitialisation des réglages sans supprimer les profils.
- Lecture des anciens réglages 0.2.0 avec valeurs par défaut pour les nouveaux champs.
- Aucun bouton de réouverture ajouté. README conservé avec uniquement l'image.

## 0.2.0 — 2026-11-05

- Sauvegarde locale des préférences quand les API fichiers existent.
- Menu déplaçable et redimensionnable, raccourci personnalisable.
- Overlay FPS/ping déplaçable, indépendant de la visibilité du menu.
- Diagnostic de version, état de sauvegarde et erreurs des callbacks.
- Bouton « Tout arrêter et fermer » avec nettoyage de l'overlay et des entrées.
- README réduit à l'image BlockSpin ; notice déplacée dans UTILISATION.md.
- Tests Lua avec API simulées. Compatibilité réelle Xeno toujours à vérifier.
