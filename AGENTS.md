# Instructions pour les assistants : BlockSpin

Lire `PROJECT_MEMORY.md` et `CAPABILITES.md` avant toute modification.

- Modifier `src/cycle.lua`, `src/hub_core.lua` et `src/interface.lua` (jamais `src/main.lua`, généré), puis `python -I build.py`, `python -I tests/check_source.py` et `python -I tests/run_tests.py` (venv avec `lupa==2.8`).
- Pas de raccourcis clavier nouveaux : les actions passent par l'interface (seules RightShift et F12 restent).
- Ne jamais affirmer qu'une fonction marche en jeu sans confirmation de l'utilisateur, datée et rattachée à une version.
- Ne pas casser la pêche v0.6.8. Ne pas inventer de RemoteEvent, de GUI ou d'API de véhicule.
- Garder l'aller et le retour distincts. Ne jamais écraser `data/route_data.json` ni le fichier de l'utilisateur automatiquement.
- Pas de téléportation, pas de modification de CFrame ou de vitesse du véhicule, pas de contournement d'anti-triche.
- Ne rien pousser ni publier (GitHub, environnement) sans demande explicite.
- Livrer un script complet copiable. Une seule version active.
