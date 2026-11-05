# BlockSpin Private Hub 1.0.0 — Black Edition

Cette version est développée depuis `main` 0.9.1 (`c0da490`) sur `feat/v1.0.0-private-hub`.
**Aucun essai de la 1.0.0 dans Roblox/Xeno n'a été réalisé.** Les tests utilisent Lua 5.4, une maquette Roblox et une physique simplifiée. Consulter `CAPABILITES.md` et `tests/VALIDATION_V1.md`.

## Lancer et arrêter

Coller **tout** `src/main.lua` : c'est le script complet généré, avec les trajets et le noyau V1 intégrés. Aucun autre module n'est téléchargé. `loader.lua` continue de charger la version de `main` ; il ne charge pas cette branche avant fusion. Relancer le script arrête l'instance précédente.

- `RightShift` : masquer/réafficher le menu (raccourci existant modifiable dans Settings).
- `STOP / F12` : invalider l'activité, relâcher les entrées, arrêter l'enregistrement, la pêche, la culture et le cycle automatique. Le bouton indépendant reste accessible lorsque le menu se masque pendant le mini-jeu. La voiture peut continuer sur son élan.
- **Fishing → Reprendre la pêche après STOP** : reprise explicite si l'inventaire n'est pas plein. Pour une vente, libérer l'inventaire manuellement ou lancer explicitement le cycle dans Money.
- **Settings → Avancé → Fermer le script**, ou `getgenv().BlockSpinCycle080.stop()` : fermeture complète, connexions coupées, interface supprimée, aucune sauvegarde à l'arrêt. Le nom global historique est conservé pour la compatibilité.

## Fishing

La logique de pêche historique est conservée : canne équipée, relance, clics du mini-jeu, inventaire `n/18`, arrêt à `x0` appâts et reprise après libération de l'inventaire. STOP suspend aussi les clics.

Les actions « poisson rare » restent **ne rien faire / quitter / aller vendre**. Leur détection repose sur de nouveaux textes ou leur couleur violette pendant/après le mini-jeu ; elle peut produire des faux positifs. Les textes observés ne prouvent ni une espèce ni une capture réussie. STOP annule un départ serveur différé déjà programmé.

Pour créer un spot :

1. Se placer au point de pêche. Facultativement capturer la visée en plaçant la souris sur l'eau pendant le délai de trois secondes.
2. Saisir un nom puis **Enregistrer ce spot**. La position et l'orientation exactes du personnage sont conservées, avec la visée écran si définie ; ce n'est pas la position de l'hameçon.
3. **Sauvegarder la bibliothèque** pour écrire les spots et destinations. Rien n'est sauvegardé automatiquement dans ce fichier.
4. Pour réutiliser un spot, le rejoindre à moins de huit studs puis le sélectionner. La sélection ne déplace pas le personnage. Refaire la visée si la caméra ou la résolution change.

Les statistiques par spot sont celles de la session : tentatives de lancer, textes observés, signaux rares et durée mesurée près du point. Les événements hors de son rayon ne lui sont pas attribués. Maximum 50 spots ; un nom existant n'est jamais remplacé implicitement.

## Vehicle

Au volant, mémoriser la voiture et tester séparément ALLER puis RETOUR. Les trajets de référence restent distincts. La conduite utilise les entrées W/A/S/D et ne modifie ni CFrame ni attribut de vitesse.

Pour une destination supplémentaire : démarrer l'enregistrement, conduire manuellement, arrêter l'enregistrement, saisir un nom et conserver le trajet nommé. **Conduire vers destination** rejoue le trajet depuis une position proche de son parcours. Il ne calcule pas d'itinéraire depuis n'importe où. Sauvegarder explicitement la bibliothèque pour conserver les destinations. Maximum 50 trajets et 2 000 points par trajet.

Les préréglages existants restent Lente 12/5, Normale 20/7, Rapide 30/9 et Max moteur. Les vitesses cibles sont en **studs/s**, non calibrées sur l'affichage du jeu. Le pilote freine près de l'arrivée ; le stationnement n'est annoncé réussi qu'après une vitesse observée au plus égale à 3 studs/s. Il ne garantit pas d'orientation finale. Blocages et dégagements ont des limites ; un échec demande une intervention.

Settings → Avancé conserve l'import v0.6.8, les repères, l'affectation explicite du tampon à ALLER/RETOUR et la sauvegarde historique des trajets. Ces commandes ne sont pas exécutées automatiquement.

## Money et Statistics

Money affiche le solde observé, les revenus de vente mesurés, les dépôts observés et les variations d'appâts. **Actualiser le solde** effectue une lecture explicite ; il n'y a pas de scan financier permanent de toute l'interface.

- Un revenu est ajouté seulement si une vente a fait baisser l'inventaire et si le solde augmente entre ses deux lectures. Un solde inconnu ne crée aucun montant. Une variation passive n'est pas attribuée à une vente.
- Un dépôt est suivi séparément ; il ne diminue pas le revenu gagné. La preuve héritée est une baisse de l'argent en main après confirmation ATM : elle reste une **heuristique**, pas une preuve de transaction bancaire côté serveur.
- Le taux horaire est une extrapolation du revenu observé depuis le lancement, affichée après 60 secondes. Il ne prédit pas un rendement garanti.
- Les baisses d'appâts sont observées, sans attribution certaine à chaque prise. Les ajouts sont comptés séparément.

Statistics contient le tableau AFK, l'activité supervisée, le temps de session, le bilan estimé, les statistiques par spot et les huit dernières erreurs parmi un journal borné à 80. L'index web et les textes de pêche historiques y restent accessibles. Les compteurs de session repartent à zéro au lancement.

## Smart Automation

La vente automatique est désactivée par défaut. Une fois activée, l'inventaire plein déclenche le cycle existant : voiture → vendeur → vente → ATM → voiture → retour → pêche.

Les opérations passent par un superviseur commun : état, délai maximal, vérification du résultat, historique et annulation. Limites : conduite 600 s, marche/entrée 80 s, sortie 10 s, vente 45 s, ATM 25 s. Les fonctions existantes conservent aussi leurs limites internes. Une étape obligatoire échouée arrête le cycle ; le dépôt optionnel peut être abandonné avec son résultat journalisé. « Exiger une preuve de dépôt » refuse aussi un résultat inconnu. Un délai maximal expiré suspend les automatismes.

Les boutons de conduite et le moteur agricole utilisent le même superviseur et le même verrou d'activité. Il n'y a pas de nouvelle interaction serveur devinée.

## Farming

**La culture automatique dans BlockSpin reste indisponible.** Les interfaces et interactions réelles de plantation/récolte n'ont pas été observées. Le bouton refuse le démarrage sans adaptateur ; Diagnostic écran permet de recueillir ces observations.

Le moteur est implémenté et testé avec un adaptateur local : plusieurs parcelles et plantes, états vide/croissance/prête, récolte, replantation, délai de confirmation de 20 s, croissance limitée à 600 s, statistiques et arrêt F12. Exemple de plan : `A:Corn, B:Pumpkin`. Ces noms ne prouvent ni la disponibilité des graines ni leur prise en charge par le jeu.

Pour développer l'intégration après observation, `S.setFarmingAdapter(adapter)` attend trois fonctions locales coopératives : `observe(plot)` → `{state='empty'|'growing'|'ready', crop=...}`, `plant(plot,crop)` et `harvest(plot,crop)` → booléen. Les actions doivent céder régulièrement et respecter l'annulation avant tout effet. Le moteur exige une nouvelle observation conforme après chaque action. Aucun adaptateur du jeu n'est fourni dans cette version.

## Settings, fichiers et génération

Thème noir, palette et accent libre `#RRGGBB`, animations désactivables, notifications, FPS/ping, échelle, menu redimensionnable/déplaçable et profils existants sont conservés.

| Fichier local de l'exécuteur | Usage |
|---|---|
| `blockspin-settings-v1.json` | Réglages et profils, format historique conservé |
| `blockspin-library-v1.json` | Spots et destinations, sauvegarde explicite seulement |
| `blockspin_data_v080.json` | Trajets historiques ; bouton explicite de sauvegarde uniquement |
| `blockspin_fishlog.json` | Textes de pêche observés, comportement historique conservé |

Une bibliothèque invalide reste intacte et bloque sa sauvegarde pendant la session. Corriger le fichier puis le recharger explicitement. Sans API fichiers, la session reste utilisable en mémoire. Aucune clé ni secret n'est requis dans le client.

Développement : modifier `src/cycle.lua` et le noyau pur `src/hub_core.lua`, puis générer `src/main.lua` avec `python -I build.py`. Ne pas modifier le fichier généré à la main. Voir `tests/VALIDATION_V1.md` pour les commandes de vérification.
