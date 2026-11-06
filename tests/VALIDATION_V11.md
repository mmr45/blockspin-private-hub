# Validation 1.1.0 — 2026-11-06

Base : `main`, `39feadb0a1fd722624b3ca11c8c21742eef35dad`, après fusion de la PR #4.
Branche : `feat/v1.1-visual-dashboard`.

Exécuté localement : Python 3.12.14, lupa 2.8, Lua 5.4.

| Vérification | Résultat |
|---|---|
| `python -I build.py` | Script complet généré |
| `python -I build.py --check` | Concordance exacte |
| `python -I tests/check_source.py` | Réussi |
| `python -I tests/run_tests.py` dans le venv | **310 vérifications, 0 échec** |
| `git diff --check` | Réussi |
| Trajets de référence, archives, README et loaders | Inchangés |

Les 251 vérifications précédentes sont conservées (contrats de présentation adaptés aux sept onglets). 59 cas supplémentaires vérifient HSV, palette souris/tactile, annulation et sauvegarde explicite, absence d’écriture/tween par pixel, widgets reliés aux valeurs observées, graphiques bornés, réglages/profils, listes cliquables, événements serveur, pagination, dédoublonnage et nettoyage/rechargement.

Les vues Fishing, Settings et Server ont été inspectées dans des maquettes HTML générées depuis l’arbre d’instances Lua simulé. L’avatar y est un substitut. **Ce ne sont pas des captures Roblox.**

Limites : aucune validation réelle 1.1.0 dans Roblox/Xeno ; région serveur inconnue ; historique de présence limité à la période d’observation ; cultures du jeu sans adaptateur réel. Les API simulées de la maquette ne prouvent ni le rendu, ni la physique, ni les interactions réelles.

Reproduire avec le venv `lupa==2.8` et les commandes ci-dessus. Les sources `src/cycle.lua`, `src/hub_core.lua`, `src/interface.lua` et `src/visuals.lua` sont assemblées par `build.py` ; ne jamais éditer `src/main.lua` à la main.
