# BlockSpin Hub 0.4.0

Prototype client Lua/Luau. Compatibilité Windows/Xeno non certifiée. Les contrôles automatisés utilisent une simulation ; aucun test réel Roblox/Xeno n'a été effectué.

## Lancement

Copier le contenu de `loader.lua` dans l'exécuteur, ou copier directement `src/main.lua`. Le lanceur télécharge le code du dépôt public `mmr45/blockspin-private-hub`. Aucun jeton ni clé requis. Le code est visible et utilisable par tous.

## Interface 0.4.0

Interface charbon avec accent personnalisable (vert citron par défaut pour les nouveaux réglages), titres hiérarchisés, champs et boutons bordés. Farming s'ouvre par défaut ; les quatre actions de culture sont disposées en grille. Les états « En préparation » indiquent les actions non branchées au jeu.

Navigation latérale avec indicateur actif. Sous 620 pixels de largeur logique, les onglets deviennent FSH, FRM, IDX et SET. Les positions, profils et couleurs déjà enregistrés sont conservés. La géométrie est ajustée à la nouvelle taille minimale quand l'écran le permet.

## Menu et overlay

- Glisser la barre du titre pour déplacer le menu.
- Glisser la poignée `<>` en bas à droite pour redimensionner le menu. Dimensions limitées à l'écran ; minimum 480 × 400 si l'écran le permet.
- Dans Settings, activer « Overlay FPS / ping ». Il reste visible quand le menu est masqué ; glisser l'overlay pour le déplacer.
- Les FPS et le ping API sont actualisés environ chaque seconde. Si le ping n'est pas disponible, la valeur affiche `N/D`.
- Le raccourci initial est `RightShift` (Maj droite). Dans Settings, cliquer « Raccourci », puis appuyer sur une touche clavier. Échap annule. La saisie dans un champ texte ne masque pas le menu.
- Accent : saisir une couleur `#RRGGBB`, puis appliquer.
- « Actualiser le diagnostic » affiche la version, l'état de sauvegarde et les préférences. Les cinq dernières erreurs capturées dans les callbacks du menu sont affichées ; « Tester la capture d'erreur » produit une erreur volontaire. Les erreurs de chargement initial restent dans la console de l'exécuteur.
- « Tout arrêter et fermer » supprime le menu et l'overlay, et déconnecte les entrées et mesures de ce script. Cela n'arrête ni Roblox ni d'autres scripts.

## Echelle, profils et graphiques

- Échelle du menu : saisir un pourcentage de 75 à 150 puis appliquer. Textes et boutons sont agrandis ensemble. La taille de la fenêtre est limitée à l'écran en tenant compte de l'échelle ; l'overlay garde sa taille propre.
- Mesures de l'overlay : cliquer pour passer de FPS + ping à FPS seuls, puis ping seul.
- Graphique : activer dans Settings pour afficher deux histogrammes indépendants, FPS et ping en millisecondes. Chacun conserve au maximum les 30 dernières mesures et adapte son échelle verticale. Une mesure de ping indisponible laisse une colonne vide. L'historique reste en mémoire pour la session.
- Recentrer : remet le menu au centre et l'overlay au centre en haut, sans changer les autres préférences.
- Profils : saisir un nom de 1 à 32 caractères, puis enregistrer/remplacer, charger ou supprimer. Maximum 10 profils. Un profil conserve la présentation, le raccourci et la géométrie, sans graines ni repères. La liste des noms apparaît sous le champ. Enregistrer un nom déjà présent remplace ce profil.
- Réinitialiser : restaure les réglages par défaut, dont Maj droite, échelle 100 %, overlay et graphique désactivés. Les profils enregistrés sont conservés.
- Sans API fichiers, les profils restent disponibles jusqu'à la fermeture du script.

## Sauvegarde locale

Si `readfile`, `writefile` et `isfile` sont disponibles, la couleur, le raccourci, la visibilité des mesures et de l'overlay, la taille, les positions, l’échelle, le mode overlay, la visibilité du graphique et les profils sont sauvegardés dans `blockspin-settings-v1.json`, dans l'espace fichiers de l'exécuteur. Aucun dossier Windows fixe n'est supposé. Aucun identifiant, repère du personnage ou inventaire n'est enregistré.

Sans ces fonctions, les réglages restent valables pour la session. Si le fichier est invalide ou illisible, il est préservé, les réglages par défaut sont utilisés et l'écriture est désactivée pour cette session. Pour réactiver la sauvegarde, corriger ou renommer ce fichier manuellement puis relancer. Une erreur d'écriture est signalée dans le diagnostic. Relancer remplace le précédent menu et restaure les préférences valides.

## Fonctions BlockSpin

Auto Fish, Auto Record, récolte, plantation, engrais et terre restent des boutons de démonstration. Aucune action réseau du jeu n'est envoyée. Fish Index reste vide. La liste des graines est manuelle : filtre textuel et sélection uniquement. Le repère existant note la position du personnage pendant la session, pas l'appât. Aucune gestion supplémentaire des repères n'a été ajoutée.

## Tests

- `python3 tests/check_source.py` : contrôles du texte source uniquement.
- `python3 tests/test_runtime.py` : tests avec moteur Lua et API Roblox simulées ; nécessite `lupa==2.8` dans l'environnement de test, pas dans Xeno.
- `tests/MANUAL.md` : tests réels encore à effectuer.

Le lanceur vérifie le téléchargement et la compilation ; il ne vérifie pas une signature. Le dépôt public ne protège pas le code contre la copie. L'utilisation d'un exécuteur dans une expérience tierce peut entraîner des sanctions.

Image du README : illustration de [BlockSpin par Cinnamon Go!](https://www.roblox.com/games/104715542330896/BlockSpin), récupérée depuis la page officielle Roblox. Ce dépôt n'est pas affilié au créateur du jeu.

API utilisées : [UserInputService](https://create.roblox.com/docs/reference/engine/classes/UserInputService) et [HttpService JSON](https://create.roblox.com/docs/reference/engine/classes/HttpService). [UIScale](https://create.roblox.com/docs/reference/engine/classes/UIScale) règle l’échelle du menu. Les API de fichiers dépendent de l'exécuteur et ne sont pas garanties.
