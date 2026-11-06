# Essais réels V1.0.0 — à exécuter dans Roblox/Xeno

Aucun cas de cette version n'a été exécuté en jeu. Consigner chaque résultat avec le modèle en fin de document.

## Interface et arrêt

1. Coller le script complet généré. Vérifier Fishing, Vehicle, Money, Farming, Statistics et Settings, puis relancer : une seule interface et une seule boucle.
2. Tester les résolutions, le défilement, le redimensionnement, l'échelle 75–150 %, l'accent libre, les profils, la sauvegarde et les animations désactivées.
3. RightShift masque/réaffiche ; les champs texte n'interceptent pas le raccourci. Vérifier FPS/ping et notifications, même après disparition d'une interface du jeu.
4. STOP pendant un mini-jeu, un maintien de vente, une conduite, une entrée/sortie et un glissement ATM : aucune nouvelle action, aucun lancer. Reprendre explicitement. Vérifier le bouton STOP lorsque le menu se masque.
5. Fermer puis relancer : aucune entrée restante, aucun fichier de données sauvegardé à l'arrêt.

## Pêche et spots

6. Canne équipée : plusieurs mini-jeux, relance et inventaire `18/18` suspendu. Vente manuelle puis reprise ; observer les appâts et `x0`.
7. Capturer une visée puis conserver deux spots avec noms distincts. Sauvegarder explicitement, relancer et retrouver les coordonnées. Essayer un doublon : refus. La sélection d'un spot éloigné doit être refusée.
8. Rejoindre un spot, le sélectionner et pêcher. Vérifier les statistiques de session ; pêcher loin de ce spot ne doit pas lui attribuer d'événement.
9. Documenter les textes/couleurs réels des prises rares et leurs faux positifs ; tester chaque action seulement après examen des observations. STOP doit annuler un départ serveur différé.

## Véhicule

10. Au volant du G-Cruzer, tester ALLER depuis les deux orientations du pont puis RETOUR depuis le vendeur. Vérifier A/D, les vitesses et les dégagements limités.
11. Enregistrer manuellement deux destinations, arrêter l'enregistrement puis les conserver sous deux noms. Rejouer chaque trajet depuis sa zone de départ, puis sauvegarder et relancer.
12. Vérifier la fin du trajet : vitesse mesurée au plus 3 studs/s avant succès. Un véhicule qui roule encore doit produire un échec de stationnement ; aucune orientation finale n'est garantie.
13. Perdre le siège, saisir du texte ou rencontrer un obstacle : erreur explicite et touches libérées. Les données aller/retour historiques restent distinctes.

## Argent et cycle

14. Avant/après une vente : relever le portefeuille et le compteur d'inventaire. Comparer le revenu du hub au montant réellement gagné, y compris les séparateurs monétaires.
15. Déposer à l'ATM : vérifier aussi le crédit bancaire réel. Un dépôt ne doit pas diminuer le revenu de session. Un solde absent reste inconnu.
16. Activer le cycle avec inventaire plein : suivre chaque étape, délais, vente, ATM et reprise de pêche. Exiger une preuve de dépôt et vérifier le refus d'une confirmation inconnue.
17. Vérifier le tableau AFK, l'estimation après 60 secondes et le journal d'erreurs. Une défaillance obligatoire ne doit pas lancer les étapes suivantes.

## Culture : intégration bloquée faute d'observations

18. Sans adaptateur, le démarrage doit être refusé sans envoyer d'action au jeu.
19. Recueillir Diagnostic écran devant les parcelles, graines, interfaces de plantation et de récolte. Ne pas déduire de RemoteEvent à partir d'un nom supposé.
20. Après développement séparé d'un adaptateur observé : tester vide → plantation → croissance → prêt → récolte → replantation pour chaque type, quantité de graines insuffisante, disparition d'une parcelle, délais et STOP.

## Fichiers

21. Bibliothèque invalide : erreur visible, contenu préservé, sauvegarde refusée. Corriger puis recharger explicitement. Tester les API fichiers absentes ou en erreur.
22. Vérifier que l'enregistrement et l'arrêt ne modifient pas automatiquement `blockspin_data_v080.json`.

## Fiche de résultat

| Date | Version / commit | Roblox / Xeno | Cas | Résultat | Preuve / erreur |
|---|---|---|---|---|---|
| À remplir | 1.0.0 / … | … | … | Non exécuté | … |

## Refonte de l’interface : essais réels supplémentaires

23. Vérifier photo Roblox, DisplayName et @username du compte connecté, noms longs et avatar de remplacement si la miniature reste indisponible.
24. Changer rapidement d’onglet, réduire puis rouvrir immédiatement, alterner RightShift : aucune page grisée ni fermeture tardive. Couper Animations et vérifier les états instantanés.
25. Tester 960 × 640, mode compact, échelle 150 %, redimensionnement de la fenêtre Roblox et changement de caméra : sections empilées, accès par défilement, avatar et STOP accessibles.
26. Fermer et relancer pendant le chargement de la photo : aucune ancienne interface ni animation restante. Vérifier le masquage automatique du mini-jeu sans bouton de réouverture superposé.

## V1.1.0 : palette et serveur (non exécutés en jeu)

27. Vérifier la photo en haut et la lisibilité des compteurs/jauges/listes. Ouvrir volontairement le journal technique : replié par défaut.
28. Dans Settings, glisser sur le plan de couleur et la teinte, sortir des bords, utiliser un écran tactile. Appliquer, annuler, changer de catégorie ou perdre le focus : aucune sauvegarde par pixel, état cohérent après relance.
29. Régler l’échelle au glisser puis la densité. Enregistrer/charger un profil et vérifier couleur, échelle, densité, métriques et masquage du mini-jeu.
30. Cliquer un spot/trajet/profil dans les listes : champ prérempli, aucun déplacement ni lancement de cycle.
31. Ouvrir Server : comparer population/capacité à Roblox. Faire rejoindre/quitter un compte de test : dernière arrivée/départ visible, aucune fausse arrivée pour les joueurs déjà présents au lancement.
32. Tester pagination avec plus de huit joueurs, départ d’un joueur affiché sur la dernière page, fermeture/relance : pas d’observateur dupliqué. La région doit rester « Non fournie », et l’historique commencer à l’ouverture.
33. Regarder les graphiques FPS/ping avec mesures manquantes : N/D, aucune mesure inventée. Tester 480 px de largeur et les transitions rapides pendant la palette.

## V1.1.1 : régressions utilisateur (à exécuter)

34. Money : relever la vraie source. Le montant change sans bouton ; si absent, N/D et état explicite. Ouvrir l’inventaire puis rechercher/choisir le portefeuille. Ne pas choisir un prix de boutique ou un solde bancaire à sa place.
35. Faire une vente manuelle : hausse du compteur observée ; une vente/depot du cycle reste séparé. Changer de source ne doit pas produire un faux gain.
36. Créer un spot sans nom puis capturer la visée sur l’eau après sa création. Sauvegarder la bibliothèque et relancer ; conserver point monde et position du personnage sans déplacement direct.
37. Éloigner le curseur puis lancer, changer légèrement la caméra, mettre la cible hors champ : lancer correctement visé ou suspension explicite, jamais succès supposé.
38. Mini-jeu : curseur ailleurs mais Roblox actif, clic sur la barre détectée. Autre application au premier plan : pause sans clic OS parasite. Retour dans Roblox : reprise. Répéter en fenêtre et plein écran pour vérifier l’inset.
39. Saisir un nom de spot, glisser un réglage, presser F12 pendant l’attente de visée : aucun lancer/clic retardé après annulation.


## V1.2.0 — observatoire et configuration (à faire dans Roblox)

40. Près d’une plante à soi : rechercher temps/%, vérifier les chemins via export agricole, choisir la paire et confirmer une parcelle/type. Vérifier les valeurs contre le jeu. Une paire ambiguë ou celle d’un autre joueur ne doit pas être adoptée.
41. S’éloigner assez pour provoquer le streaming : le timer reste visible mais devient estimé. Au retour une nouvelle valeur recale l’échéance. Un affichage figé ne repousse pas indéfiniment le timer.
42. Vérifier maturité réelle (temps 0 et 100%) versus échéance calculée ; aucune récolte annoncée par disparition d’objet. Replantation : contrôler le recalage. L’espèce saisie reste une étiquette tant que sa source réelle n’est pas reliée.
43. Si le jeu recycle un BillboardGui vers une autre parcelle, vérifier que l’ancienne liaison suspend ses lectures. Exporter le diagnostic si le scanner ne reconnaît pas les formats réels.
44. Sauvegarder puis recharger sur le même serveur : estimation restaurée, sans recréer une preuve ni liaison automatique. Changer de serveur : aucune plante de l’ancien ne réapparaît. Tester un fichier invalide sans l’écraser.
45. Joueur qui rejoint/quitte : comptage unique, UTC, durée de présence depuis observation seulement ; recherche, tri, avatars et amis. Activer explicitement les notifications puis tester un joueur suivi et un ami connu.
46. Confidentialité : vérifier profil, roster, arrivées/départs, identifiants serveurs et export de bilan sans identités. Le jeu lui-même et les copies techniques explicites restent hors de ce mode.
47. Comparer les ping courant/min/médian/moyen/max à des mesures réelles ; coupure de lecture → N/D. La durée affichée est celle du hub, pas l’âge du serveur.
48. Publics : actualiser, filtrer, paginer ; échec HTTP explicite si refusé dans le client. Choisir seul ne change rien. Confirmation expirée au bout de 15 s ; confirmation valide via Roblox. Consigner l’arrivée réelle séparément.
49. Favoris et bilan : aucun fichier automatique au chargement/arrêt. Sauvegarder explicitement ; deux sauvegardes de la même session actualisent son bilan. Vérifier 30 bilans/favoris maximum.
50. Cartes : déplacer par monter/descendre, largeur, masquer/afficher et reset ; garder les réglages d’organisation accessibles. Palette souris/tactile, HEX, couleurs récentes, thèmes, profils et import/export JSON ; reset d’apparence conserve les données.
51. Mini-dashboard : déplacer, ouvrir le hub et STOP ; tester petit écran, animation désactivée et menu masqué. Vérifier qu’il n’intercepte pas une cible de pêche.
52. File : pause puis trajet, erreurs et délais, STOP avant la prochaine étape. Une échéance calculée ne valide pas une plante prête. Cycle réel puis pause suivante uniquement après validation individuelle du vendeur, ATM et trajets.
53. Après chaque série noter version, date, résultat et capture ; ne pas convertir une réussite en simulation en confirmation du jeu réel. Remplir les points P0/P1 de CONFIGURATION.md à partir de ces observations.


## V1.2.1 — retour à la relance classique (à vérifier dans Roblox)

54. Charger V1.2.1, garder « Visée enregistrée : non », mettre la canne et placer le curseur vers l’eau. Un spot sans visée ou une ancienne capture ne doit plus empêcher le lancer.
55. Faire au moins quatre manches courtes sans déplacer manuellement la souris : vérifier que le curseur revient après le clic et que la canne se relance environ 0,35 s après disparition du panneau. Consigner le délai réellement observé, sans confondre activation et appât réellement apparu.
56. Si le jeu refuse cette vitesse, régler 0,75 puis 1,5 s. Sans réponse du mini-jeu, vérifier que les tentatives restent espacées de 8 s.
57. Vérifier un vrai zéro d’appâts visible, puis fermer son affichage/restocker. Une ancienne valeur cachée ne doit pas rester bloquante. Vérifier que le jeu refuse naturellement un lancer sans appât.
58. STOP, perte de focus, inventaire plein, saisie de texte et changement de mode pendant un lancer différé : aucun lancer parasite. Le curseur ne doit jamais être déplacé par le correctif vers une autre application.
59. En option seulement, activer la visée enregistrée et vérifier les contrôles stricts. La désactiver doit rendre le lancer classique sans effacer les spots. Recharger un profil et vérifier les deux nouveaux réglages.


## V1.2.2 — canne et activations ignorées (à faire dans Roblox)

60. Tester plusieurs prises : mesurer disparition du mini-jeu → appât réellement apparu, pas seulement le compteur d’appels. Confirmer version 1.2.2 et état des nouveaux réglages. Le retour reçu après 1.2.1 est un délai d’au moins 15 s ; ne pas le considérer résolu sans ce test réel.
61. Observer Canne/activation et Relance : canne indisponible doit attendre naturellement, puis activer au retour de Enabled, sans modifier Enabled ni la protection du jeu.
62. Vérifier l’appui/relâchement complet ; STOP/F12, perte de focus, pause, changement de mode et fermeture ne doivent pas laisser une pression maintenue. Aucun nouveau clic ou prise de focus vers une autre application.
63. Si le lancer reste lent, exporter le diagnostic pendant l’attente. Vérifier version, phase, demandes/signaux/appels non vérifiés, dernier mini-jeu, canne et durée de retry. Ne pas déduire la présence d’un appât d’un signal Activated seul.
64. Vérifier qu’une animation de disparition avec CanvasGroup transparent n’est pas prise pour un mini-jeu toujours actif. Un panneau réellement visible continue de bloquer les nouveaux lancers.
65. Remplacer/rééquiper la canne, tester mode classique et assistance optionnelle. Si le comportement du vrai Tool diffère du modèle de pression, consigner les observations avant toute autre accélération ou inférence de cooldown serveur.
