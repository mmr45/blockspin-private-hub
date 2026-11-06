# Validation V1.2.0 — 6 novembre 2026

Base : main `da0c0efd647cc1af379169a136fc5733fffc9c21` (PR #6 fusionnée). Branche `feat/v1.2-workspace-tools`. Livraison par PR sans fusion automatique.

## Résultats locaux

- **482 vérifications, 0 échec** : 373 antérieures conservées et 109 nouvelles.
- Python 3.12, `lupa==2.8`, moteur Lua 5.4 ; pas un moteur Roblox/Luau en jeu.
- `python -I build.py` : génération du script complet depuis les six sources et les données de référence.
- `python -I build.py --check` : généré conforme.
- `python -I tests/check_source.py` : sept pages, sources injectées, pas de remote deviné ni de déplacement physique direct, raccourcis préservés.
- `python -I tests/run_tests.py` : logique pure et scénarios dans une maquette minimale.
- `git diff --check` : pas d'erreur d'espacement.
- Données `data/route_data.json`, archives, README et loaders conservés.

## Scénarios ajoutés

- Durées, pourcentages, RichText, rejets des valeurs ambiguës et invalides.
- Plantes : propriété/serveur requis, timer stable à lecture identique, recalage après nouvelle lecture, projection signalée, maturité observée distincte d'une échéance, alertes dédoublonnées, redémarrage, tri/groupement, borne de 50.
- Sources agricoles : découverte réelle dans les objets de la maquette, ambiguïtés refusées, liaison explicite, valeurs changeantes, streaming, source recréée, déconnexion des anciens signaux et changement d'Adornee refusé.
- Sauvegarde : explicite, bilans mis à jour sans doublon, restauration de plantes estimée sur le même serveur seulement, fichier corrompu préservé.
- Lecteur agricole : lecture seule, retrait confirmé, exception/délai et résultat tardif ignoré.
- Serveurs : recherche sans motifs Lua, tri amis/récence, avatars, suivi, présence unique, confidentialité des vues et exports, statistiques de ping.
- Publics : validation/filtres/doublons, curseur, cooldown, HTTP absent, délai et réponse tardive ; aucune requête publique au chargement. Changement sans effet à la sélection, expiration puis confirmation officielle simulée, arrivée non annoncée comme acquise.
- File : délai de pause, maturité réelle acceptée, échéance estimée refusée, absence de plantes/voiture, verrouillage des modifications, STOP et absence de relance. **Cycle complet vente/ATM/retour simulé puis pause suivante**, avec résultat rattaché au jeton du cycle.
- UI : thèmes, couleurs récentes, palette synchronisée, mini-dashboard, masquage/largeur/ordre, reset conservant les spots, import invalide ou hors bornes, arrêt des observateurs.

## Inspection visuelle

Une maquette HTML a été générée à partir de l'arbre d'instances Lua simulé et inspectée : page Farming, carte de croissance avec pourcentage/timer estimé et contrôles de liaison en deux colonnes. Le rendu emploie des substitutions pour la miniature et les fontes. **Cette inspection ne valide pas le rendu Roblox**, les clips/scrolls exacts, la miniature réseau ni les entrées réelles.

## Ce qui reste à valider dans Roblox

1. Vraies sources de parcelle/propriétaire/type/temps/%, nouveaux plants, récolte et streaming. Le scanner et les contrats ne constituent pas un adaptateur BlockSpin.
2. Acceptation et comportement des entrées de pêche, point monde/caméra, source Money ; correctifs précédents conservés, pas de preuve réelle supplémentaire.
3. Vendeur/ATM, orientation, braquage, freinage et stationnement réels. Les GUI/prompts de la maquette sont des exemples de test.
4. Accès HTTP public, pagination réelle et changements de serveur ; les environnements client peuvent refuser les requêtes HTTP. Aucun transport de contournement inclus.
5. Appels amis/miniatures, UI en différentes résolutions, souris/tactile, mini-dashboard et STOP.

L'emplacement physique et l'âge réel du serveur ne sont pas inventés. Les événements commencent à l'ouverture du hub. Le temps de croissance projeté et un texte de rareté restent des observations/estimations, pas des succès agricoles ou captures prouvés.

Plan de branchement détaillé : [CONFIGURATION.md](../CONFIGURATION.md). Essais utilisateur : [MANUAL.md](MANUAL.md).
