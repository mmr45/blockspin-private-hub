# Validation V1.2.1 — 6 novembre 2026

Base : main `abc178d8ed7e6e828bf28358170976a09b0d8e1f`, après fusion de la PR #7. Branche `fix/v1.2.1-fishing-recast`, PR vers main sans fusion automatique.

## Problème et correction

L’utilisateur signale une pêche moins fluide depuis la mise à jour de visée, avec nécessité apparente de déplacer le curseur pour relancer. Le code impose alors des contrôles de visée/Mouse.Hit, déplace le curseur pour cliquer la barre, et applique encore le délai de retry de 8 s après une manche observée. Un zéro d’appâts caché peut aussi rester bloquant.

Le correctif remet le lancer classique par défaut, sans visée obligatoire, conserve l’assistance en option, restaure le curseur initial après un clic natif dans le viewport et réarme la première relance 0,35 s après disparition du mini-jeu. Le retry 8 s demeure sans réponse. Les sources d’appâts illisibles redeviennent inconnues plutôt que conserver un zéro bloquant.

## Vérifications locales

- **511 vérifications, 0 échec** : 482 antérieures conservées et 29 nouvelles.
- Python 3.12 / lupa 2.8 / Lua 5.4 ; maquette Roblox, pas moteur Roblox réel.
- Build, concordance du généré, contrôles statiques et `git diff --check` réussis.
- Données/routes de référence, archives, README et loaders conservés.

Cas ajoutés : mode classique malgré spot sans visée ou Mouse.Hit indisponible, aucun mouvement de souris nécessaire au lancer, clic toujours ciblé puis curseur restauré, quatre manches courtes sans mouvement manuel, borne du délai après fermeture et absence de spam, retour bref du panneau, levée du délai initial après une manche déjà observée, STOP/focus/inventaire, ancien zéro caché/détaché, migration/profils et invalidation d’une activation différée au changement de mode.

Les scénarios stricts de la correction 1.1.1 restent exécutés en activant explicitement la visée enregistrée. Le test UI recherche désormais le sélecteur par son libellé, sans supposer sa position parmi les nouveaux contrôles.

## Limites

**Aucun essai Roblox/Xeno V1.2.1 confirmé.** Les causes sont étayées par le code et des régressions reproduites en maquette, pas par une observation instrumentée du PC utilisateur. L’ordre réel des événements souris et le délai minimal accepté par le jeu restent à vérifier. Un `Tool:Activate()` accepté ne prouve ni appât apparu, ni poisson capturé.

Garder Roblox au premier plan ; aucun focus forcé, aucune entrée OS hors cible connue, aucun contournement des règles serveur. Voir les essais 54–59 de [MANUAL.md](MANUAL.md).
