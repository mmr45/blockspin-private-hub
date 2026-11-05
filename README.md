# BlockSpin Private Hub — prototype 0.1

Prototype Lua/Luau côté client, sans clé ni dépendance distante. Dépôt public : https://github.com/mmr45/blockspin-private-hub . Le fichier loader.lua contient le lanceur configuré. La compatibilité Xeno sous Windows est visée, mais **non testée et non garantie**. Aucun mécanisme de contournement ou appel réseau BlockSpin n'est fourni.

## Contenu

- `src/main.lua` : interface autonome à copier intégralement dans l'exécuteur.
- `loader.example.lua` : loader sur une ligne, volontairement bloqué tant que son URL n'est pas remplacée.
- `tests/check_source.py` : contrôles statiques locaux, sans moteur Roblox.
- `tests/MANUAL.md` : vérification en environnement réel.

## Fonctions implémentées

| Élément | Comportement réel |
| --- | --- |
| Menu | Full Black, quatre onglets, contenu défilant, dimensions adaptées à la fenêtre |
| Settings | Accent `#RRGGBB`, affichage des mesures, fermeture complète |
| Raccourci | `RightShift` masque ou affiche le menu |
| FPS | Nombre de rendus / durée écoulée, actualisé environ chaque seconde |
| Ping | `Player:GetNetworkPing()` × 1000, protégé par `pcall`, sinon `N/D` ; valeur API, sans conversion arbitraire en aller-retour |
| Repère Fishing | Position du **personnage** sur demande, conservée uniquement dans l'interface pour la session |
| Graines | Liste saisie par l'utilisateur, séparation par virgules, dédoublonnage exact, filtre textuel insensible à la casse, sélection |
| Cycle de vie | Relancer remplace l'ancien menu ; fermer déconnecte mesures et entrées |

Le repère du personnage ne donne jamais la position exacte de l'appât. La liste des graines ne lit pas l'inventaire et ne prouve pas que les noms existent dans BlockSpin. Les réglages, la sélection et le repère sont perdus à la fermeture ou à la relance.

## Intégrations non vérifiées

Les boutons Auto Fish, Auto Record, Récolte, Plantation, Engrais et Terre affichent un statut explicite, sans action dans le jeu. Le Fish Index reste vide. Détection de l'appât, contact avec l'eau, captures, espèces, raretés, catalogue, inventaire et sauvegarde persistante ne sont pas implémentés.

Avant de brancher une action, vérifier dans un environnement autorisé son API réelle, ses paramètres, les permissions, les réponses et les conditions d'échec. Ne pas remplacer ces boutons par des événements devinés. Aucun identifiant de place n'est affirmé : le prototype ne vérifie pas qu'il est lancé dans BlockSpin.

## Lancement depuis GitHub

Copier le contenu de `loader.lua` dans l’exécuteur. Il télécharge `src/main.lua` depuis ce dépôt public. Les automatisations restent non implémentées. Aucun test Roblox/Xeno n’a été effectué.

## Utilisation locale

1. Examiner `src/main.lua`.
2. Sous Windows, lancer l'environnement Roblox client souhaité et exécuter ce fichier si l'exécuteur accepte les API utilisées.
3. Vérifier les quatre onglets puis suivre `tests/MANUAL.md`.

Pour tester l'interface sans exécuteur : placer le contenu de `src/main.lua` dans un `LocalScript` de `StarterPlayerScripts` dans votre propre expérience Roblox Studio, puis lancer Play. Le loader n'est pas un LocalScript Studio : `game:HttpGet` et `loadstring` dépendent de l'environnement d'exécution.

## GitHub et loader

Ce dépôt est **public**, avec accord du propriétaire. Son contenu est visible et téléchargeable par tous. Aucune licence publique de réutilisation n'est ajoutée.

Le loader d'exemple est bien sur une ligne. Remplacer son marqueur par l'URL HTTPS réelle qui renvoie le texte de `src/main.lua`, après hébergement effectif et contrôle du contenu. Il vérifie les capacités, le téléchargement et la compilation. Les erreurs d'exécution restent visibles. Il ne vérifie ni signature ni empreinte : utiliser uniquement une source contrôlée et revue, idéalement une version immuable.

Un dépôt privé ne devient pas accessible anonymement par une URL raw. Ne jamais mettre de jeton GitHub dans le loader ou le script. Pour garder le source privé avec le moins d'infrastructure, copier le fichier localement reste l'option fournie et utilisable. Un chargement distant privé nécessite une distribution authentifiée extérieure à ce prototype. Aucun serveur ni système de clé n'est inclus.

## Confidentialité

Un script exécuté sur une machine cliente peut être lu, extrait ou modifié par cette machine. Une URL discrète, un dépôt privé ou l'obfuscation ne rendent pas le code livré secret. Sans authentification, toute personne disposant d'une URL accessible peut récupérer son contenu. Garder les secrets et toute logique réellement confidentielle côté serveur sous votre contrôle. Ce prototype ne contient aucun secret, aucune télémétrie, aucun téléchargement et aucune écriture de fichier ; seul le loader optionnel télécharge du code.

L'usage d'un exécuteur dans une expérience tierce peut enfreindre ses règles et entraîner des sanctions. Aucun contournement ni protection contre ces sanctions n'est garanti.

## Validation et références

Exécuter `python3 tests/check_source.py`. Ces contrôles inspectent uniquement le texte ; ils ne prouvent ni la syntaxe complète Luau ni le rendu ni le fonctionnement dans Roblox/Xeno. Les vérifications réelles restent dans `tests/MANUAL.md`.

API consultées : [Player](https://create.roblox.com/docs/reference/engine/classes/Player) et [conteneurs d'interface Roblox](https://github.com/Roblox/creator-docs/blob/main/content/en-us/ui/on-screen-containers.md). Ces sources ne documentent pas Xeno ou les mécaniques de BlockSpin.
