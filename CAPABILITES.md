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
