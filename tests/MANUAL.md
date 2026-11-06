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
