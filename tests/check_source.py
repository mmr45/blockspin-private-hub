"""Controles statiques du script genere (aucune execution Roblox n'est simulee ici).
Les tests de comportement sont dans tests/run_tests.py."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = (root / "src/main.lua").read_text(encoding="utf-8")
cycle = (root / "src/cycle.lua").read_text(encoding="utf-8")

assert "--@@DEFAULT_DATA@@" not in source, "src/main.lua non regenere : lancer build.py"
assert "--@@HUB_CORE@@" not in source
assert "--@@INTERFACE@@" not in source
assert (root / "src/interface.lua").read_text(encoding="utf-8").replace("--@@VISUALS@@", (root / "src/visuals.lua").read_text(encoding="utf-8")) in source
assert "--@@VISUALS@@" not in source
assert (root / "src/hub_core.lua").read_text(encoding="utf-8") in source
assert "local DEFAULT_DATA = {" in source
assert source.replace("\r\n", "\n").count("\n") > cycle.count("\n"), "main.lua doit contenir les donnees injectees"
assert "local VERSION = '1.1.1'" in source
for name in ("Fishing", "Vehicle", "Money", "Farming", "Statistics", "Settings", "Server"):
    assert f"page('{name}')" in source, name
assert "player:Kick(" in source  # seule sortie volontaire : option poisson rare
# Aucun RemoteEvent devine, aucun code distant charge par le script lui-meme.
for forbidden in ("FireServer(", "InvokeServer(", "HttpGet(", "loadstring("):
    assert forbidden not in source, forbidden
# Aucun deplacement direct du personnage ou de la voiture (teleportation).
for forbidden in ("root.CFrame =", ".CFrame = CFrame", "PivotTo(", "AssemblyLinearVelocity ="):
    assert forbidden not in source, forbidden
# Seules F12 (urgence) et la touche d'affichage restent au clavier.
for key in ("F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11"):
    assert f"Enum.KeyCode.{key}" not in source, key
assert "Enum.KeyCode.F12" in source
assert "blockspin-settings-v1.json" in source
loader = (root / "loader.lua").read_text(encoding="utf-8")
assert "raw.githubusercontent.com/mmr45/blockspin-private-hub/main/src/main.lua" in loader
print("OK : main.lua regenere, 7 onglets, pas de remote/teleportation, F3-F11 retirees, loader vers src/main.lua.")
