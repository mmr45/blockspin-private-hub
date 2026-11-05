"""Contrôles statiques : aucune exécution Roblox n'est simulée."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = (root / 'src/main.lua').read_text()
for name in ('Fishing', 'Farming', 'Fish Index', 'Settings'):
    assert f'page("{name}")' in source, name
for forbidden in ('FireServer(', 'InvokeServer(', 'HttpGet(', 'loadstring('):
    assert forbidden not in source, forbidden
assert 'string.find(string.lower(name), query, 1, true)' in source
assert 'player:GetNetworkPing()' in source and 'pcall(function()' in source
assert 'connection:Disconnect()' in source and 'gui.Destroying:Connect' in source
loader = (root / 'loader.example.lua').read_text().splitlines()
assert len(loader) == 1
assert 'REMPLACER_PAR_URL_HTTPS_REELLE_DU_MAIN_LUA' in loader[0]
assert 'url:match("^https://")' in loader[0]
assert 'local configPath = "blockspin-settings-v1.json"' in source
assert 'pcall(callback, ...)' in source
assert 'Input:GetFocusedTextBox()' in source
assert 'if showMetrics or preferences.overlay or preferences.graph then' in source
assert 'local VERSION = "0.3.0"' in source
print('OK : 4 onglets, integrations fermees, filtre litteral, mesures protegees, nettoyage, loader bloque.')
