# Validation V1.2.2 — 6 novembre 2026

Base : main `06371e9ecbab48169fb1dddabfd3979e68a4b79b` après PR #8. Branche `fix/v1.2.2-rod-activation`, PR sans fusion automatique.

## Retour utilisateur

Après la livraison 1.2.1, l’utilisateur signale toujours une relance lente, avec « lancer en cours » et un retard d’au moins 15 secondes. Le résultat réel du correctif précédent n’est donc pas validé.

Le modèle précédent comptait chaque appel Tool:Activate comme une activation, sans vérifier la disponibilité, le signal d’entrée ou le relâchement. Le nouveau code lit Tool.Enabled sans jamais l’écrire, effectue Deactivate/Activate/Deactivate, observe Activated et distingue appel ignoré, signal reçu et signal inaccessible/non vérifié.

## Expérience comparative locale

Même maquette, mêmes paramètres : fin du mini-jeu observée, puis deux appels d’activation ignorés par l’outil. L’appel suivant est accepté. Exécution de l’ancien script généré depuis main et du nouveau script généré avec le même mock.

| Source | Fin du mini-jeu → activation acceptée | Demandes | Ignorées |
|---|---:|---:|---:|
| 1.2.1 | 16,40 s | 3 | 2 |
| 1.2.2 | 2,18 s | 3 | 2 |

Cela reproduit **un chemin plausible** du retard signalé. Ce n’est ni une mesure sur le PC utilisateur, ni une confirmation que le jeu ignore exactement deux appels. Une réception Tool.Activated prouve seulement un événement local, pas un appât réellement apparu.

## Vérifications exécutées

**542 vérifications locales, 0 échec** (511 conservées + 31 nouvelles), Python 3.12 / lupa 2.8 / Lua 5.4. Build, concordance du généré, statique et `git diff --check` réussis. Routes, archives, README et loaders conservés.

Cas supplémentaires :

- Pression complète et quatre relances avec outil qui ignore un nouvel appui tant que le précédent n’est pas relâché ; ancienne pression au chargement nettoyée.
- Enabled=false sans fausse tentative ; activation au retour à true, y compris après une prise ; nouvel outil sans retry de l’ancien.
- Deux activations ignorées avec reprise bornée ; refus prolongés avec backoff, exceptions, signal différé et signal inaccessible distinct du compteur de signaux reçus.
- Nettoyage des abonnements et de la pression sur STOP, perte de focus, changement de mode et fermeture.
- CanvasGroup totalement transparent reconnu comme non visible ; aucun relancement tant qu’un mini-jeu visible demeure.
- Diagnostic local des 40 dernières phases, horaires, disponibilité et demandes/signaux ; UI reliée et export sans identité serveur/joueur.

Les contrôles de focus, inventaire, appâts, mode classique, assistance, conduite et autres modules restent testés. Aucune écriture de Tool.Enabled, de CFrame ou de vitesse ; aucun remote deviné.

## Limites à vérifier dans Roblox

**Aucun essai réel V1.2.2 confirmé.** Le comportement exact du Tool et de ses handlers, les temps de disponibilité et l’apparition réelle de l’appât sont à mesurer. Le script ne raccourcit aucun cooldown serveur. Si le retard persiste, utiliser l’export de diagnostic pendant l’attente pour décider du prochain changement, plutôt qu’une nouvelle baisse arbitraire du délai.

Voir les essais 60–65 de [MANUAL.md](MANUAL.md) et [CONFIGURATION.md](../CONFIGURATION.md).
