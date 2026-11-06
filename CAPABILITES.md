# Capacités V1.2.0 — 2026-11-06

**482 vérifications locales, 0 échec ; aucune validation Roblox/Xeno V1.2.** Les captures réelles V1.1.0 confirment seulement l'affichage de cette ancienne UI.

| Ajout | Preuve locale | Limite réelle |
|---|---|---|
| Plantes liées | Découverte, ambiguïtés, propriété explicite, échéance, recalage, streaming, source recréée, GUI recyclé, alertes, restauration isolée par serveur | Liaison manuelle ou lecteur réel à fournir ; pas d'identité/propriété/création BlockSpin supposée |
| Cartes et mini-dashboard | Arbre Lua, sélection, compteurs, visibilité, organisation, import et reset testés ; maquette visuelle inspectée | Rendu, saisie et performances Roblox à valider |
| Serveur courant | Présence unique conservée, recherche, avatars, amis, filtres d'événements, UTC, stats ping, confidentialité et export | Historique depuis ouverture ; API amis/miniatures à confirmer en jeu |
| Publics/favoris/bilans | Validation des instantanés, filtres/pagination, erreurs/timeouts, confirmation de changement, sauvegarde atomiquement validée | HTTP client peut être indisponible ; une requête officielle de changement ne prouve pas une arrivée |
| File d'activités | Pause, maturité réelle/estimée, erreur, STOP, cycle complet puis étape suivante simulés | Repose sur vendeur/ATM/physique réels encore à valider ; aucun Auto Farm BlockSpin fourni |
| Régression | 373 vérifications antérieures conservées, 109 nouvelles ; build et statique | Simulation uniquement ; pas de promesse de pêche en arrière-plan |

Configuration et branchements à faire : [CONFIGURATION.md](CONFIGURATION.md). Rapport : [tests/VALIDATION_V12.md](tests/VALIDATION_V12.md).

---

# Correctifs V1.1.1 — 2026-11-06

Retour utilisateur confirmé par captures en V1.1.0 : l’UI s’affiche, mais le compteur Money n’est pas lu et les entrées pêche dépendent du curseur/focus. Les corrections ci-dessous sont **simulées seulement**, pas validées dans Roblox/Xeno.

| Correction | Preuve locale | Limite |
|---|---|---|
| Lecture du portefeuille | Cache, mises à jour de texte/valeur/attribut public, ambiguïté, source masquée/recréée, sélection et nettoyage | Une donnée doit réellement être visible ou répliquée ; aucun montant inventé |
| Spots/visée | Noms automatiques, capture après création, sauvegarde de point monde, reprojection et attente de traitement | Anciennes visées écran à recapturer ; eau visible et entrées natives acceptées |
| Clic mini-jeu | Curseur hors écran avec clic natif sur la barre, hit-test d’inset, focus, annulation et saisie | Acceptation de l’API simulée ne prouve pas la réussite du mini-jeu réel ; arrière-plan non garanti |

**373 vérifications locales, 0 échec.** Données/routes de référence conservées. Voir `tests/VALIDATION_V111.md`.

---

# Capacités V1.1.0 — 2026-11-06

**310 vérifications réussies en simulation ; aucun essai réel de rendu Roblox/Xeno de cette version.**

| Ajout | Preuve exécutée | Limite |
|---|---|---|
| Palette HSV | Conversion, souris/tactile, bornes, annulation, sauvegarde et aperçu sans tween par pixel | Rendu et saisie réels à valider |
| Affichage visuel | Compteurs/jauges/listes, graphiques, profil en haut et réglages testés dans la maquette | Maquette HTML inspectée, pas de capture Roblox réelle |
| Présence serveur | Initialisation, événements, dédoublonnage, pagination, historique borné et nettoyage | Historique uniquement depuis l’ouverture ; aucune donnée antérieure inventée |
| Localisation serveur | Valeur inconnue explicitement affichée | API publique client ne fournit pas la région physique ; aucune déduction par l’IP du joueur |
| Régression | Tests de pêche, conduite, argent et arrêt précédents passent | Ne prouve pas les mécanismes du jeu réel ; Auto Farm toujours indisponible sans adaptateur |

Détails dans `tests/VALIDATION_V11.md`.

---

# Capacités V1.0.0 — 2026-11-06

**Aucune fonction V1.0.0 confirmée en jeu.** Les confirmations historiques ci-dessous ne valident pas cette version. La base de travail est `main` 0.9.1 (`c0da490`).

| Fonction V1 | Résultat vérifié | Limite restante |
|---|---|---|
| Pêche et cycle existants | Scénarios historiques conservés dans la maquette | Essais Roblox/Xeno requis |
| Spots et statistiques par spot | Positions/visees exactes sauvegardées, sélection proche, attribution de session | Position du personnage ; textes/raretés heuristiques, visée liée à l'écran |
| Destinations et enregistrement | Bibliothèque et tests du pilote, aller/retour conservés | Pas de calcul de route depuis un point arbitraire ; physique réelle non validée |
| Stationnement | Succès exige vitesse mesurée ≤ 3 studs/s | Pas d'orientation finale ni calibration réelle |
| Money Manager | Attribution vente, décimales, dépôt distinct et cycle complet simulés | Instantanés de GUI ; dépôt non prouvé côté serveur |
| Culture/replantation | Moteur multi-plantes testé avec adaptateur local simulé | **Adaptateur BlockSpin absent : culture en jeu indisponible** |
| Black Edition et AFK | Six onglets, profil officiel/avatar, cartes adaptatives, transitions, métriques et réglages testés en maquette | Rendu, miniature et entrées réels Roblox non testés |
| Supervision et STOP | Expiration, exceptions, preuve absente, annulations testées | Dépend de la coopération des actions/adaptateurs ; arrêt physique non instantané |
| Build et sécurité statique | Script généré exact, aucun nouveau remote, chargement distant ou déplacement direct | Ne constitue pas une validation du jeu |

Résultats : **251 vérifications, 0 échec** sous Lua 5.4 avec `lupa==2.8`. Détails dans `tests/VALIDATION_V1.md`, essais réels dans `tests/MANUAL.md`.

---

# Matrice des capacités (mise à jour 2026-11-05)

Légende de la colonne Résultat :
- **Confirmé** : constaté par l'utilisateur en jeu.
- **Simulé** : passe les tests hors Roblox (maquette + modèle cinématique simplifié).
- **Non testé** : jamais exécuté en jeu dans cette version.
- **Échec** : échec observé.

| Fonction | Méthode | Préconditions | Version | Résultat | Preuve | Limite connue |
|---|---|---|---|---|---|---|
| Clics mini-jeu | aiguille/cible Frames, mouse1click → VIM | `PlayerGui.SliderMinigame` visible | v0.6.0 / code repris tel quel en v0.8.0 | Confirmé (v0.6.0), Non testé en v0.8.0 | message utilisateur (mémoire) | clic à la position du curseur |
| Relance canne | `Tool:Activate()` sur outil fish/rod/canne | canne équipée | v0.6.1 | Confirmé (v0.6.1) | mémoire | — |
| Inventaire plein | texte `n/18` dans `PlayerGui.Items` | label lisible | v0.6.4 / v0.6.7 | Confirmé | mémoire | 18 = emplacements totaux |
| Reprise après vidage | recalcul `count >= limit` | — | v0.6.7 | Confirmé | mémoire | — |
| Appâts x0 → arrêt | texte `prawntec` + `xN` voisin | label lisible | v0.8.0 | Simulé | test maquette (x16 lu) | x0 réel jamais observé |
| Accélération W | `VIM:SendKeyEvent(W)` | au volant | test isolé | **Confirmé** (05/11/2026) | « ok c'est bon sa marche » | — |
| Direction A/D | idem | au volant | v0.7.x | Non caractérisé | — | jamais testé seul |
| Trajet pont → vendeur lent (12/4) | v0.7.2 lente | voiture bien orientée | v0.7.2 | **Confirmé une fois** | « DEPART PONT c'est bon » | répétabilité inconnue |
| Conduite v0.7.4 | mode natif | — | v0.7.4 | **Échec** au point 2 « derrière » | capture | cause probable : voiture garée cap nord |
| Pilote v0.8.0 (projection, anticipation, freinage, demi-tour, dégagement) | W/A/S/D uniquement | au volant, moins de 45 studs du trajet | v0.8.0 | Simulé (9 scénarios) | `tests/run_tests.py` | physique G-Cruzer non modélisée, décélération supposée |
| Module `VehicleSystem.Vehicle` | `require` | — | v0.7.x | **Échec** | « Requested module experienced an error while loading » | cause inconnue, non utilisé |
| Téléportation du personnage | écriture `root.CFrame` | — | ajout séparé | **Échec** | « Téléportation détectée » | abandonné |
| Passage sous la carte | — | — | — | **Non implémenté (refusé)** | — | voir README |
| Entrée dans la même voiture | prompt de la voiture → contact du siège → `Seat:Sit` | voiture mémorisée | v0.8.0 | Non testé | — | prompt réel de BlockSpin inconnu |
| Sortie de voiture | `Humanoid.Jump`, puis `Sit=false` | — | v0.8.0 | Non testé | — | — |
| Marche vendeur/ATM | `PathfindingService` + `Humanoid:MoveTo` | — | v0.8.0 | Simulé | maquette | portes fermées non gérées |
| Vente | prompt sell/fish ou E, maintien 3,5 s sur `SellAllFishButton` | devant le vendeur | v0.8.0 | Simulé | validée seulement si l'inventaire baisse | interface d'ouverture réelle non confirmée |
| Dépôt ATM | prompt/E → DÉPÔT → glisser le curseur à droite → CONFIRMER | devant l'ATM | v0.8.0 | Simulé, interface **inventée** | validé seulement si l'argent baisse | hiérarchie GUI réelle inconnue → Diagnostic (Settings) requis |
| Cycle complet | machine à états | voiture mémorisée, inventaire plein | v0.8.0 | Simulé | maquette (cycle bouclé) | aucune étape réelle confirmée sauf W |
| Auto Seeds | — | — | — | Non implémenté | — | aucune observation de l'interface |
| writefile/readfile | API exécuteur | — | v0.6.8 | Confirmé (v0.6.8) | « saved 19 points » | dossier réel inconnu |
| Interface hub (onglets, boutons, RightShift, réglages) | hub 0.4.0 relié au cycle | — | v0.8.0 | Simulé | maquette (88 vérifications) | jamais affichée dans Roblox |
| Préréglages de vitesse (Rapide, Max moteur) | W/A/S/D, W tenu en ligne droite | au volant | v0.9.0 | Simulé | modèle (vmax 65) | 12-13 km/h signalés en v0.8.0 ; unité studs/s ↔ km/h inconnue |
| Poisson rare → quitter / vendre | nouveau texte avec mot-clé ou violet après une prise | action choisie | v0.9.0 | Simulé | maquette | textes réels de prise inconnus |
| Profils de réglages | blockspin-settings-v1.json | writefile | v0.9.0 | Simulé | maquette | — |
| Index poissons/plantes | sites de fans + textes observés | — | v0.9.0 | Données web non vérifiées | treyexgaming, blockspin-wiki | liste incomplète |
| Achat à distance | — | — | — | Refusé | — | contournerait la vérification serveur |
