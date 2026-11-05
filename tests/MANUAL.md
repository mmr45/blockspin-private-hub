# Vérifications réelles 0.8.0 : à exécuter dans Roblox/Xeno

Aucun cas ci-dessous n'a encore été exécuté. Pour chaque essai, noter la date, le résultat et une capture.

## Interface
1. Coller `src/main.lua` : le menu s'ouvre à gauche sur l'onglet Cycle et le pied affiche l'état. Une seule instance tourne après deux lancements.
2. RightShift masque puis réaffiche le menu. F3 à F11 n'ont plus d'effet. Saisir du texte ne déclenche pas le raccourci.
3. Déplacer, redimensionner, régler l'échelle à 75/150 %, changer l'accent, relancer : les réglages sont restaurés.
4. Pendant le mini-jeu, le menu se masque puis revient à la fin.

## Pêche (non-régression v0.6.8)
5. Canne équipée : le mini-jeu est réussi sur plusieurs clics et la canne est relancée.
6. Inventaire 18/18 : plus de lancer. Après vente manuelle : reprise.
7. Le compteur d'appâts est lu (`x16`…). Noter ce qui s'affiche à `x0`.

## Conduite (au volant du G-Cruzer)
8. **Test ALLER** au pont, capot vers le nord : le demi-tour se fait, puis arrivée au parking vendeur. Noter le sens du braquage A/D.
9. Test ALLER capot déjà vers le sud.
10. **Test RETOUR** depuis le parking vendeur.
11. F12 pendant un test : touches relâchées, aucune reprise.
12. Vitesse `15/6` puis `25/8` : comportement en virage.

## Interfaces réelles (Settings → Diagnostic)
13. Près de la voiture : prompt pour monter.
14. Devant le vendeur, interface ouverte : nom et parents du bouton de vente.
15. Devant l'ATM, écran DÉPÔT ouvert : bouton, curseur, CONFIRMER, texte d'argent en main.

## Cycle complet
16. Cycle ON, inventaire plein : chaque état s'enchaîne. Vente confirmée par la baisse de l'inventaire, dépôt confirmé par la baisse de l'argent, puis retour et reprise de la pêche.
