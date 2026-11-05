# Vérifications réelles — à exécuter

Aucun cas ci-dessous n'a été exécuté dans Roblox ou Xeno.

1. Exécuter `src/main.lua` : menu noir, Fishing visible, trois autres onglets accessibles.
2. Réduire la fenêtre : contenu accessible par défilement ; aucun bouton essentiel coupé.
3. Attendre deux secondes : FPS plausibles ; ping API en ms ou `N/D` sans erreur.
4. Appuyer sur RightShift : masquer puis réafficher. Saisir du texte : ne pas intercepter les entrées traitées.
5. Mémoriser la position : coordonnées du personnage, mention explicite que ce n'est pas l'appât. Réessayer pendant une réapparition.
6. Cliquer chaque action non vérifiée : statut explicite et aucune action de jeu.
7. Saisir `A, B, A, [C]` : trois graines. Filtrer `[` : seulement `[C]`. Filtrer `b` : seulement `B`.
8. Sélectionner B puis supprimer B de la liste : sélection remise à aucune. Masquer B par filtre : sélection conservée.
9. Essayer `#12ABEF`, `12abef`, puis `xyz` : deux couleurs acceptées, erreur claire pour la dernière.
10. Masquer/afficher les mesures ; fermer ; relancer deux fois : un seul menu et une seule mesure active.
11. Vérifier Fish Index vide, sans poisson ou capture inventés.
12. Loader non configuré : arrêt explicite avant téléchargement. Après hébergement contrôlé : tester échec HTTP, texte non Lua, erreur d'exécution et succès.
13. Répéter sous Windows avec la version exacte de Xeno envisagée ; noter date, versions Roblox/Xeno et erreurs. Aucune compatibilité n'est acquise avant ce test.

## Version 0.2.0 — nouveaux cas, non exécutés dans Roblox/Xeno

14. Glisser le titre et redimensionner avec `<>` ; tester les limites de l'écran et réduire la fenêtre Roblox.
15. Dans Settings, activer l'overlay, masquer le menu avec le raccourci : seul l'overlay reste visible. Le déplacer, désactiver puis réactiver.
16. Changer le raccourci vers F6 ; vérifier que Maj droite ne masque plus le menu. Échap annule la capture. Saisir dans un champ ne déclenche pas le raccourci.
17. Modifier accent, mesures, overlay et géométrie. Fermer puis relancer : restauration si les API fichiers sont disponibles, sinon diagnostic explicite.
18. Avec un fichier JSON invalide : démarrage par défaut, erreur visible, fichier non écrasé. Avec écriture refusée : erreur visible et interface utilisable.
19. Tester le diagnostic : erreur volontaire visible, historique limité à cinq erreurs. Tester un ping indisponible : `N/D`.
20. Cliquer « Tout arrêter et fermer » : menu et overlay supprimés. Relancer deux fois : un seul ensemble actif.

## Version 0.3.0 — nouveaux cas, non exécutés dans Roblox/Xeno

21. Essayer les échelles 75, 100 et 150 %. Vérifier textes, boutons, déplacement et redimensionnement ; réduire la fenêtre Roblox. Refuser 74, 151 et les saisies non numériques.
22. Tester les trois modes de l'overlay et relancer : mode restauré. Menu masqué, overlay toujours indépendant.
23. Activer le graphique : deux histogrammes FPS/ping avec unités. Attendre plus de 30 mesures : seules les dernières restent visibles. Ping indisponible : colonne vide. Désactiver puis réactiver.
24. Enregistrer deux profils différents ; modifier les réglages, charger chacun puis relancer. Vérifier l'indépendance des profils, le remplacement d'un nom et la suppression. Refuser noms vides, noms trop longs et onzième profil.
25. Recentrer après déplacement : menu centré, overlay centré en haut. Réinitialiser après changement de touche : retour à Maj droite, échelle 100 %, graphiques/overlay désactivés et profils conservés.
26. Charger un ancien fichier 0.2.0 valide : conserver les préférences existantes et appliquer les valeurs par défaut des nouveaux champs.

## Version 0.4.0 — interface, non exécutée dans Roblox/Xeno

27. Vérifier Farming ouvert par défaut, les quatre actions en grille et leur message « Aucune action envoyée » au clic.
28. Changer d'onglet : un seul visible, indicateur actif et couleur correspondants. Sous 620 pixels logiques, vérifier FSH/FRM/IDX/SET et l'absence de chevauchement du titre et des mesures.
29. Parcourir Settings au clavier et par défilement. Tester échelles 75/100/150 %, fenêtres étroites, sauvegarde et restauration de profils.
30. Modifier l'accent : sections, onglet actif et marqueur actualisés. Vérifier lisibilité des textes et champs, overlay indépendant et nettoyage à la fermeture.
