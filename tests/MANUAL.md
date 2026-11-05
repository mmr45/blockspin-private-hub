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
