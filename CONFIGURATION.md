# Configuration et travail restant — V1.2.0

Mis à jour le 6 novembre 2026. Ce document distingue les réglages utilisateur, les branchements internes et les essais Roblox. Le code V1.2 est testé hors jeu ; aucune confirmation Roblox/Xeno de cette version.

## Ce que cette version apporte

| Module | Implémenté | Limite à connaître |
|---|---|---|
| Serveur courant | Population/capacité, session, ping courant/moyen/min/médian/max, graphique, roster avec avatars, recherche, tri, amis, suivi et notifications | Présence depuis l'ouverture seulement ; amitié peut rester inconnue si l'appel officiel échoue |
| Événements | Arrivées/départs datés UTC, durée de présence observée, filtres et pagination | Pas d'historique antérieur ; 80 événements en mémoire |
| Favoris et bilans | Favoris nommés, historique de ses propres sessions, export JSON local | Sauvegarde explicite ; ne garantit pas qu'un ancien serveur existe encore |
| Serveurs publics | Liste paginée, filtres places/population, sélection puis confirmation d'un changement via Roblox | API HTTP souvent indisponible depuis un client ; état affiché, aucune donnée factice ni proxy ajouté |
| Plantes | Recherche de paires réelles temps/pourcentage, liaison explicite, cartes, croissance, échéance, distance si position connue, regroupement, alertes et sauvegarde | Identité et propriété ne sont pas devinées ; liaison par parcelle requise tant que l'adaptateur BlockSpin n'est pas caractérisé |
| Suivi à distance | Échéance locale calculée à partir de la dernière lecture ; recalage quand la source change | « Estimé » après 3 s sans changement ou si source absente ; échéance atteinte seule ne prouve pas une récolte prête |
| Personnalisation | Palette HSV/souris/tactile/HEX existante, couleurs récentes, thèmes couleur, ordre/largeur/visibilité des cartes, import/export JSON et reset d'apparence | Thèmes = couleurs d'accent ; pas un remplacement intégral des couleurs du jeu |
| Mini-dashboard | Activité, durée, hausses observées, prochaine plante suivie, ouvrir/STOP, déplacement à la souris/tactile | N'exécute rien hors Roblox ; le jeu doit rester ouvert |
| Automatisation | File de pauses, trajets nommés, cycles vente/ATM/retour et attente de maturités observées | Dépend des modules existants ; arrêt sur erreur/expiration, pas de reprise ou relance automatique après échec |
| Diagnostic | État des sources dans Settings, diagnostic agricole exportable | Un adaptateur chargé ne signifie pas qu'il a été validé dans le vrai jeu |

## À régler dans l'interface maintenant

### Pêche

1. Enregistrer un spot, sélectionner ce spot et capturer la visée vers l'eau après le délai de 3 secondes.
2. Sauvegarder explicitement la bibliothèque pour conserver spots et destinations. Une capture après création actualise le spot en mémoire.
3. Régler pêche automatique, cycle automatique et action sur signal rare. Par défaut, le signal rare ne déclenche ni vente ni sortie.
4. Laisser Roblox au premier plan pour les entrées de pêche. La perte de focus suspend les entrées ; le script ne force pas le focus.
5. Les compteurs de lancers, clics, textes et signaux rares sont des observations distinctes. Ils ne constituent pas un nombre garanti de poissons capturés.

### Véhicule et itinéraires

1. Mémoriser la voiture en étant au volant.
2. Marquer pêche/vendeur/ATM aux emplacements réellement utilisés (Settings, avancé).
3. Enregistrer séparément aller et retour ; les nommer si besoin. Le tampon d'enregistrement ne remplace aucune route sans action explicite.
4. Choisir un préréglage de vitesse, puis tester chaque sens. Les valeurs sont en studs/s, pas en km/h.
5. La carte affiche uniquement les repères connus et l'aperçu d'un trajet choisi ; elle ne calcule pas un chemin depuis une position arbitraire.

### Argent

1. Afficher le vrai portefeuille dans le jeu, puis Money → rechercher/choisir le compteur si la lecture automatique ne le trouve pas.
2. Sélectionner uniquement le portefeuille. Un solde bancaire ou un prix ne doit pas servir de source de gains.
3. Vérifier que la valeur suit une modification réelle. Une source cachée ou disparue affiche N/D.
4. Régler dépôt ATM et exigence d'une preuve de dépôt selon les essais réels.
5. Les hausses, baisses, variation nette et revenus de ventes confirmés sont séparés. L'estimation horaire demande 60 secondes de lecture d'un vrai compteur.

### Plantes : branchement provisoire, en lecture seulement

1. Se placer près d'une de ses plantations avec les affichages temps et pourcentage visibles.
2. Farming → rechercher les affichages temps/pourcentage. Le scanner ne retient que les paires non ambiguës dans un parent proche ; il ne prouve pas qu'il s'agit d'une plante.
3. Sélectionner la paire correspondante, saisir un nom unique de parcelle et le type de plante, puis confirmer qu'elle vous appartient.
4. Vérifier que la carte suit une vraie modification de temps et de pourcentage. Le type de plante saisi reste une étiquette utilisateur tant qu'aucune source réelle de type n'est reliée.
5. S'éloigner : vérifier le passage à « Estimé » si le jeu ne réplique plus les valeurs. Au retour, les nouvelles valeurs doivent recaler le compteur.
6. Un changement d'Adornee d'un affichage monde suspend la liaison : une fenêtre recyclée ne doit pas être attribuée silencieusement à une autre parcelle.
7. Sauvegarder explicitement pour conserver un instantané. Sur le même serveur, la restauration est toujours estimée jusqu'à une vraie nouvelle lecture ; sur un autre serveur les plantes précédentes ne sont pas restaurées.
8. Régler les alertes de 10 à 600 secondes et le regroupement par culture. Les alertes doivent aussi être autorisées par le réglage général des notifications.

Formats actuellement reconnus : `04:32`, `01:04:32`, `2m 30s`, `1h 2m 3s`, et `35%` / `35,5 %`. Les balises RichText sont acceptées. Un chiffre seul dans un texte n'est pas interprété comme une durée. Texte composite, durée traduite ou barre sans texte : parser à adapter après observation.

**Détection universelle d'une nouvelle plantation, récolte réelle et replantation BlockSpin : encore à intégrer.** La liaison surveille automatiquement les valeurs des parcelles configurées ; elle ne découvre pas toute seule le propriétaire, un identifiant stable ou un changement d'espèce. La disparition d'un objet ne compte jamais comme une récolte.

### Serveurs

1. Rechercher et trier les joueurs ; cliquer un joueur active son suivi pendant cette session. Les notifications de présence sont désactivées par défaut.
2. Activer éventuellement les alertes pour les amis connus ; une amitié inconnue n'est pas annoncée comme vraie.
3. Nommer le serveur courant avant de l'ajouter aux favoris, puis sauvegarder l'observatoire.
4. Pour les publics, régler places libres/population puis actualiser. Pas de requête publique au chargement. Délai minimal 5 s, expiration 12 s, résultats tardifs ignorés.
5. Choisir un résultat/favori prépare le changement pendant 15 s. Le bouton de confirmation envoie une requête officielle Roblox ; il ne garantit pas l'arrivée. Terminer les activités avant de changer.
6. Le mode confidentialité masque le profil du hub, roster, événements, identifiants affichés et identités des exports de session. Il ne masque pas l'interface du jeu ou une donnée copiée explicitement par un outil technique.

### Apparence, profils et file

- Palette : aperçu, appliquer ou annuler ; aucune sauvegarde par pixel. Couleurs récentes : 8 maximum. Thèmes couleur : 12 maximum, liste paginée par 6.
- Settings → organisation : choisir une page et une carte, monter/descendre, masquer/afficher, largeur simple/complète. La carte d'organisation ne peut pas être masquée. Reset de disposition séparé du reset d'apparence.
- Import JSON : valeurs connues et bornées seulement, aucun code exécuté. La source locale de portefeuille n'est pas transférée. Profils existants : copies indépendantes des réglages, maximum 10.
- Statistics → file : préparer 1 à 20 étapes, chacune avec délai de 1 à 1800 s. Le délai d'une pause est sa durée. Une attente de plantes exige des maturités réellement observées pour les parcelles suivies au début de l'étape.
- STOP/F12 annule la file et les actions en attente. Aucun nouveau raccourci. Il faut une action utilisateur pour relancer.

## Travail interne à faire ensuite

| Priorité | Intégration | Donnée réelle nécessaire | Critère de fin |
|---|---|---|---|
| P0 | Plantation automatique détectée | Objet de parcelle stable, propriétaire, type de plante, événement/attribut public de création | Une plantation à soi ajoute exactement une carte ; celle d'un autre n'en ajoute aucune |
| P0 | Source temps/croissance | Chemins et formats réels, sens des unités, réplication à distance, pause et boosts | Compteur recalé après changement ; aucune exactitude annoncée sur une source figée |
| P0 | Récolte/replantation | Signal d'état vide/récolté et nouvelle génération, distinct du streaming | Retrait/réinitialisation au bon événement ; aucun faux succès quand on s'éloigne |
| P0 | Vendeur et ATM | Diagnostic des vrais prompts/boutons ; preuves inventaire/argent | Vente et dépôt réels, puis retour, sans interface supposée |
| P0 | Auto Drive | Sens A/D, vitesse/freinage réels, orientation aux deux parkings | Aller et retour répétés, arrêt final mesuré ; pas de téléportation ni modification physique |
| P1 | Portefeuille | Vraie source GUI/Value/attribut publique et comportement caché/recréé | Lecture concordante avant/après une variation réelle |
| P1 | Captures et rareté | Signal de capture réel et identité du poisson, pas seulement un texte violet | Tentative, texte, capture et rareté distingués ; notifications sans faux comptage |
| P1 | Liste publique | Vérifier si le transport HTTP officiel fonctionne dans l'environnement utilisateur ; sinon lecteur autorisé fourni explicitement | Réponse publique valide, pagination, échec clair ; aucun secret/proxy de contournement côté client |
| P1 | Présence/amis/miniature | Essai des appels Roblox et de leurs limites | Échec/temps d'attente gérés sans bloquer le reste du hub |
| P1 | Rendu et saisie | Essais Roblox en plusieurs résolutions, souris, tactile, animations coupées | Cartes lisibles, contrôles accessibles, STOP utilisable même menu masqué |
| P2 | Éditions confort | Réorganisation au glisser, recherche de cartes, profils d'alertes, icônes spécifiques des cultures après identification | Accessibilité conservée ; aucune activité déclenchée par une simple sélection |

L'accès mobile/hors Roblox n'est pas demandé. La localisation physique du datacenter, l'âge réel du serveur et les joueurs partis avant observation restent inconnus sans source officielle fiable. Aucun réglage local ne peut créer ces données.

## Contrats internes disponibles

Dans la portée locale du script : `S.setPlantObserver(fn)` reçoit un lecteur en lecture seule. Il est interrogé au plus une fois par seconde, avec expiration logique à 5 s. Il retourne jusqu'à 50 observations, chacune :

```lua
{
    serverKey = S.observatory.serverKey,
    id = "identifiant stable observe", crop = "type observe", owned = true,
    remaining = 272, percent = 35, position = { x, y, z },
    source = "origine publique effectivement observee",
}
```

`owned=true` doit découler d'une vraie preuve de propriété, jamais d'une supposition. Pour retirer une plante : `{serverKey=..., id=..., owned=true, state="removed", confirmed=true}` après preuve réelle. Un `nil`, une erreur, un délai ou une disparition de réplication ne retire rien.

`S.setFarmingAdapter({observe=..., plant=..., harvest=...})` est le contrat distinct des **actions** agricoles déjà présent. Il manque toujours son implémentation BlockSpin. Un lecteur de timers n'active pas cet adaptateur.

`S.setPublicServerProvider(fn)` accepte un lecteur explicite `(placeId, cursor) -> {data=..., nextPageCursor=...}`. Le contrat conserve uniquement identifiant public, population et capacité. Aucun ping d'un autre serveur ni région n'est inventé.

## Fichiers locaux et persistance

| Fichier | Contenu | Écriture |
|---|---|---|
| `blockspin-settings-v1.json` | Apparence, profils, source Money, réglages d'alertes et de disposition | Après une modification explicite d'un réglage ; fichier illisible préservé |
| `blockspin-library-v1.json` | Spots, visées et destinations | Bouton sauvegarder la bibliothèque |
| `blockspin_data_v080.json` | Aller/retour, pêche/vendeur/ATM | Bouton sauvegarder les trajets ; jamais lors d'un enregistrement seul |
| `blockspin-observatory-v1.json` | Favoris, 30 bilans maximum, instantané de 50 plantes maximum | Bouton sauvegarder favoris/session/timers ; fichier invalide préservé |
| `blockspin-session-export.json` | Export du bilan et événements de la session | Export explicite si presse-papiers indisponible |
| `blockspin-plant-diagnostic.json` | Chemins/textes des paires candidates réellement trouvées | Export agricole explicite ; jamais transmis automatiquement |
| `blockspin_fishlog.json` | Textes de capture potentiels observés, mécanisme historique | Mise à jour après nouvelle observation de texte ; ce ne sont pas des captures confirmées |

Les liaisons GUI agricoles et joueurs suivis restent propres à la session. Une restauration de timer ne recrée pas une liaison ni une preuve de propriété automatique. Aucune sauvegarde à la fermeture.

## Développement et validation

Sources : `cycle.lua`, `hub_core.lua`, `interface.lua`, `visuals.lua`, `observatory.lua`, `workspace_ui.lua`. `build.py` les assemble en **un seul** `src/main.lua`. Ne pas modifier le généré à la main.

```sh
python -I build.py
python -I build.py --check
python -I tests/check_source.py
python -I tests/run_tests.py
git diff --check
```

Installer `requirements-test.txt` dans un venv pour les tests (`lupa==2.8`). Voir `tests/VALIDATION_V12.md` et `tests/MANUAL.md`. Livrer par PR vers main ; ne pas fusionner automatiquement.
