# Instructions Codex — BlockSpin

Lire `PROJECT_MEMORY.md` avant toute modification. Ce fichier est le contexte durable du projet.

## Règles de travail
- Ne jamais affirmer qu'une fonctionnalité a été testée dans Roblox sans preuve de test utilisateur.
- Ne pas casser les fonctions de pêche déjà confirmées ; changements minimaux, réversibles, avec arrêt/cleanup.
- Ne pas confondre les prototypes `blockspin-private-hub` et les versions Auto Fish v0.6.x.
- Préserver les données de trajet ; un enregistrement F8 peut écraser l'ancien tableau.
- Ne pas inventer les RemoteEvents, noms de GUI, API de véhicule ou interfaces de graines.
- Séparer clairement : implémenté, confirmé par utilisateur, non testé, manquant.
- Conserver les coordonnées du trajet dans des fichiers de données, pas seulement en mémoire.
- Tester la syntaxe et prévoir un mode diagnostic avant de modifier le cycle complet.
- Priorité actuelle : conduite automatique fonctionnelle, puis vente/ATM, puis Auto Seeds.
- Ne jamais publier automatiquement sur GitHub sans dépôt/branche explicites.
