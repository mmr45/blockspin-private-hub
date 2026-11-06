# Validation 1.0.0 — 2026-11-06

Base GitHub : `main` 0.9.1, commit `c0da490fcbcaf60e9a9f3c3142dad508c3bd29bc`.
Branche de livraison : `feat/v1.0.0-private-hub`.

## Résultats exécutés

Environnement : Linux, Python 3.12, environnement virtuel avec `lupa==2.8`, runtime Lua 5.4.

| Vérification | Résultat |
|---|---|
| Référence 0.9.1 avant modifications | 120 vérifications, 0 échec |
| `python -I build.py` | Script complet généré |
| `python -I build.py --check` | Concordance exacte des sources et du script généré |
| `python -I tests/check_source.py` | Contrôles statiques réussis |
| `python -I tests/run_tests.py` avec le venv | 251 vérifications, 0 échec |
| `git diff --check` | Réussi |
| `data/route_data.json`, archives, README et loaders | Conservés sans changement dans la livraison |

La suite couvre les scénarios historiques, le pilote simplifié, la vitesse finale de stationnement, les six onglets, les profils, les bibliothèques et leurs limites, les fichiers invalides, l'attribution des revenus, les décimales monétaires, l'annulation et les délais, le cycle complet avec revenus/dépôt, l'agriculture multi-plantes avec replantation simulée et le refus des résultats agricoles sans observation.

La compilation du script est contrôlée, avec une marge d'au moins dix variables locales sous la limite de 200 du bloc principal.

## Contrat de présentation ajouté

46 cas supplémentaires couvrent le profil du joueur, les appels et échecs de miniature, le chargement image, la fermeture pendant un appel en attente, les cartes en colonnes/empilées, les interrupteurs, les transitions rapides, la réouverture, l’absence d’interpolation quand les animations sont coupées, le nettoyage, la migration des tailles et les changements de résolution/caméra.

Les maquettes visuelles ont été construites depuis l’arbre d’instances exporté de la maquette Lua, puis inspectées avec Chromium. Elles utilisent une représentation de remplacement pour l’avatar. Elles ne constituent pas des captures Roblox et ne valident pas les polices ni le moteur de mise en page du jeu.

## Limites et essais nécessaires

**Aucun essai 1.0.0 n'a été exécuté dans Roblox, Studio ou Xeno.** Les tests ne valident ni le rendu Roblox, ni ses entrées, ni sa physique, ni les interfaces du jeu. Le modèle de véhicule et certaines interfaces de la maquette sont simplifiés/inventés pour les tests.

- Valider la pêche historique, les visées de spots, les textes rares et la reprise après vente.
- Tester ALLER et RETOUR séparément, les préréglages, les blocages et le freinage réel.
- Observer les hiérarchies et confirmations réelles du vendeur et de l'ATM ; la baisse du portefeuille reste une preuve insuffisante d'un crédit bancaire serveur.
- Tester la Black Edition à plusieurs résolutions, le défilement, les animations, FPS/ping et STOP pendant chaque interaction.
- Farming : adaptateur BlockSpin absent. Le moteur est simulé seulement ; recueillir les observations avant de développer l'intégration.

Utiliser `tests/MANUAL.md` pour consigner date, version, scénario, résultat et preuve. La workflow GitHub ajoutée exécutera les mêmes commandes ; son résultat distant doit être consulté séparément.

## Reproduire

```sh
python -m venv .venv
.venv/bin/python -m pip install -r requirements-test.txt
.venv/bin/python -I build.py
.venv/bin/python -I build.py --check
.venv/bin/python -I tests/check_source.py
.venv/bin/python -I tests/run_tests.py
```

Sous Windows, utiliser `.venv\Scripts\python.exe`. `build.py` accepte un lancement depuis un autre répertoire ; les chemins sont résolus depuis le script.
