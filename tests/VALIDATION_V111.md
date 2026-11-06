# Validation V1.1.1 — 2026-11-06

Base : main `109e18cfd2c968610b5c6ab01cc4c7a1671b8514`, après PR #5.
Branche : `fix/v1.1.1-money-fishing-input`.

Retours réels en V1.1.0 : utilisateur avec captures montrant l’UI Money N/D/0 et erreurs de nom/choix de spot ; dépendance au curseur et perte de clics signalées. Ces observations ne valident pas la correction V1.1.1.

Exécuté sous Python 3.12.14, lupa 2.8, Lua 5.4 :

| Vérification | Résultat |
|---|---|
| `python -I build.py` | Script complet généré |
| `python -I build.py --check` | Concordance exacte |
| `python -I tests/check_source.py` | Réussi |
| `python -I tests/run_tests.py` dans le venv | **373 vérifications, 0 échec** |
| `git diff --check` | Réussi |
| Routes de référence, archives, README et loaders | Inchangés |

63 cas supplémentaires couvrent parsing de portefeuille, mises à jour sans bouton, cache, compteur masqué/recréé, ambiguïté, sélection de source, valeurs et attributs publics réellement présents, absence de faux revenu au changement de source, noms automatiques, capture après création, persistence de point monde, reprojection, mouvement traité avant Tool:Activate, visée refusée/obstruée, STOP pendant l’attente, clics au centre de la cible, hit-test d’inset, focus et saisie.

La maquette simule notamment une souris traitée avec retard, un Mouse.Hit différent, un curseur initial hors fenêtre et des API de clic refusées. Elle ne valide pas la réception réelle par Roblox/Xeno ni la réussite du mini-jeu. La pêche est volontairement suspendue hors focus ; aucun contournement n’est ajouté.

Sources de coordonnées/focus consultées :

- [UserInputService](https://create.roblox.com/docs/reference/engine/classes/UserInputService) : GetMouseLocation et événements de focus.
- [Camera](https://create.roblox.com/docs/reference/engine/classes/Camera) : WorldToViewportPoint et WorldToScreenPoint.
- [GuiService](https://create.roblox.com/docs/reference/engine/classes/GuiService) : inset du GUI.

À faire en jeu : relever la source réelle du portefeuille, capturer un spot sur l’eau, changer légèrement la caméra, vérifier la position du lancer, tester les clics natifs sur plusieurs mini-jeux, sortir le curseur en gardant Roblox actif puis changer réellement d’application, vérifier STOP pendant chaque phase. Ne pas présenter ces cas comme validés avant un retour utilisateur daté sur la version 1.1.1.
