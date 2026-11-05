-- Tests d'integration dans la maquette Roblox (voir mock_roblox.lua : interfaces inventees).
local CarLib = load(CAR_SOURCE, '=car_model')()

local function fresh(opts)
    opts = opts or {}
    local M = load(MOCK_SOURCE, '=mock')()
    M.placeShop(Vector3.new(-255.44, 255.94, 379.15), Vector3.new(-225.32, 254.68, 488.14))
    M.setCar(CarLib.new(-350.97, 844.32, opts.carHeading or 20))
    M.setRoot(Vector3.new(-334.87, 254.78, 836.06))
    if opts.files then for k, v in pairs(opts.files) do M.fs[k] = v end end
    if opts.before then opts.before(M) end
    local okLoad, errLoad = pcall(load(SCRIPT_SOURCE, '=blockspin_cycle_v080'))
    if not okLoad then error('chargement script : ' .. tostring(errLoad)) end
    local S = M.genv.BlockSpinCycle080
    if opts.drove ~= false then
        -- usage reel : arrivee en voiture au pont, descente, peche
        M.hum.SeatPart = M.seat
        M.run(1.2)
        M.hum.SeatPart = nil
        M.setRoot(Vector3.new(-334.87, 254.78, 836.06))
    end
    return M, S
end
local function logHas(S, word)
    for _, l in ipairs(S.log) do if l:find(word, 1, true) then return true end end
    return false
end
local function dist2(M, x, z) local p = M.root.Position; return math.sqrt((p.X - x) ^ 2 + (p.Z - z) ^ 2) end

-- 0. Sans voiture memorisee : refus explicite, rien ne bouge
local M, S = fresh({ drove = false })
S.autoCycle = true
M.run(10, 0.02, function() return S.state == 'ERROR' end)
check('sans voiture : erreur de precondition explicite', S.state == 'ERROR' and tostring(S.lastRouteError):find('voiture', 1, true) ~= nil, S.lastRouteError)
check('sans voiture : aucune touche envoyee', #M.keyLog == 0)

-- 1. Chargement
M, S = fresh()
check('chargement : instance globale', S ~= nil and S.running)
check('chargement : 1 Heartbeat + 1 InputBegan', M.RunService.Heartbeat:count() == 1 and M.UIS.InputBegan:count() == 1)
check('chargement : donnees par defaut (aucun fichier)', S.dataSource ~= 'blockspin_data_v080.json')
M.run(2)
check('appats lus x16', S.baitCount == 16 and not S.baitUnknown, S.baitCount)
check('inventaire 18/18 detecte', S.inventoryFull and S.inventoryText == '18/18')
check('pas de lancer avec inventaire plein', (M.casts or 0) == 0, M.casts)
check('cycle auto OFF par defaut : pas de depart', not S.cycleRunning)
S.setSpeed(22.5, 7.5)
M.capLabel.AbsolutePosition = Vector2.new(10.37, 20.5)
local okDump, dump = pcall(S.dumpGui)
check('diagnostic F3 : positions decimales acceptees', okDump and tostring(dump):find('Capacity', 1, true) ~= nil, dump)
check('diagnostic F3 : prompts listes', okDump and tostring(dump):find('DrivePrompt', 1, true) ~= nil)
M.run(2)
check('vitesse decimale : affichage sans erreur', not tostring(S.detail):find('ERREUR', 1, true), S.detail)
S.setSpeed(20, 7)

-- 2. Cycle complet (voiture garee cap nord comme apres un retour)
S.autoCycle = true
local writesBefore = M.writes
local done = M.run(600, 0.02, function() return (S.state == 'FISHING' and S.detail:find('cycle complet', 1, true)) or S.state == 'ERROR' end)
check('cycle complet : termine sans erreur', done and S.state == 'FISHING', S.state .. ' | ' .. tostring(S.detail) .. ' | ' .. tostring(S.lastRouteError))
check('cycle : vente confirmee par inventaire', logHas(S, 'vente CONFIRMEE') and M.capLabel.Text == '3/18')
check('cycle : depot confirme par solde', logHas(S, 'depot CONFIRME') and M.cash == 0 and M.bank == 500)
check('cycle : retour pres du point de peche', dist2(M, -334.87, 836.06) < 3.5, dist2(M, -334.87, 836.06))
check('cycle : voiture garee pres de la fin du retour', math.sqrt((M.car.x + 351.12) ^ 2 + (M.car.z - 859.86) ^ 2) < 12)
check('cycle : canne re-equipee', M.char:FindFirstChild('Fishing Rod') ~= nil)
check('cycle : aucune touche tenue', M.heldKeys() == '', M.heldKeys())
check('cycle : aucune ecriture fichier', M.writes == writesBefore)
check('cycle : aucune erreur de tache', (M.taskErrors or 0) == 0, M.lastTaskError)
M.run(15)
check('apres cycle : lancers repris', (M.casts or 0) > 0, M.casts)

-- 3. F12 pendant la conduite
M, S = fresh()
S.autoCycle = true
M.run(120, 0.02, function() return S.state == 'NAVIGATING_TO_VENDOR' and M.car.v > 5 end)
check('F12 : la conduite avait commence', S.state == 'NAVIGATING_TO_VENDOR')
M.press('F12')
M.run(0.5)
local logLen = #M.keyLog
check('F12 : touches relachees', M.heldKeys() == '', M.heldKeys())
check('F12 : etat ERROR + cycle auto coupe', S.state == 'ERROR' and not S.autoCycle and not S.cycleRunning)
M.run(10)
local pressedAfter = false
for i = logLen + 1, #M.keyLog do if M.keyLog[i]:sub(1, 1) == '+' then pressedAfter = true end end
check('F12 : aucune touche re-pressee ensuite (ancienne coroutine invalidee)', not pressedAfter)
check('F12 : pas de nouveau cycle automatique', not S.cycleRunning)

-- 4. Touches refusees : erreur visible, echec et pas "arrive"
M, S = fresh({ carHeading = 180 })
M.hum.SeatPart = M.seat
M.run(1)
M.failKeys = true
S.testDrive('aller')
M.run(200, 0.02, function() return S.state == 'ERROR' end)
check('touches refusees : erreurs comptees', S.keyErrors > 0, S.keyErrors)
check('touches refusees : echec explicite', S.state == 'ERROR' and S.detail:find('test aller', 1, true) ~= nil, S.detail)

-- 5. Test aller seul depuis le pont (bouton Test ALLER)
M, S = fresh({ carHeading = 20 })
M.hum.SeatPart = M.seat
M.run(1)
check('memorisation auto de la voiture au volant', S.car and S.car.name == 'G-Cruzer' and S.car.maxSpeedAttr == 65)
M.click('Test ALLER')
M.run(200, 0.02, function() return S.state ~= 'TEST_ALLER' end)
check('test aller : arrive', S.state == 'IDLE' and S.detail:find('ARRIVE', 1, true) ~= nil, S.detail)
check('test aller : touches relachees', M.heldKeys() == '')

-- 6. Vente impossible : le cycle s'arrete a VENTE, ne continue pas
M, S = fresh()
M.vendorPrompt.Parent.Position = Vector3.new(0, 0, 0) -- vendeur hors de portee
M.onE = function() end
S.autoCycle = true
M.run(600, 0.02, function() return S.state == 'ERROR' end)
check('vente impossible : ERROR a l\'etape VENTE', S.state == 'ERROR' and tostring(S.lastRouteError):find('VENTE', 1, true) ~= nil, S.lastRouteError)
check('vente impossible : pas de depot tente', M.cash == 500)
check('vente impossible : touches relachees', M.heldKeys() == '')
M.run(30)
check('vente impossible : pas de relance en boucle', not S.cycleRunning)

-- 7. Arret complet
M, S = fresh()
M.run(2)
local w = M.writes
M.click('Tout arreter')
check('stop : connexions coupees', M.RunService.Heartbeat:count() == 0 and M.UIS.InputBegan:count() == 0)
check('stop : interface detruite', M.pg:FindFirstChild('BlockSpinCycle080') == nil)
check('stop : aucune ecriture a l\'arret', M.writes == w)
check('stop : global nettoye', M.genv.BlockSpinCycle080 == nil)
check('stop : aucune touche tenue', M.heldKeys() == '')

-- 8. Fichier de donnees
M, S = fresh({ files = { ['blockspin_data_v080.json'] = '{pas du json' } })
check('fichier invalide : defauts conserves', S.dataSource ~= 'blockspin_data_v080.json' and logHas(S, 'invalide'))
local base = S.data
local modified = py_json_encode({ version = 1, route_to_vendor = { { -350, 254.5, 844 }, { -360, 254.5, 800 } },
    route_to_fishing = base.route_to_fishing, fish = base.fish, vendor = base.vendor, atm = base.atm })
M, S = fresh({ files = { ['blockspin_data_v080.json'] = modified } })
check('fichier valide : charge', S.dataSource == 'blockspin_data_v080.json' and #S.data.route_to_vendor == 2)
M.click('Sauvegarder les donnees')
check('bouton Sauvegarder : sauvegarde + copie .bak', M.fs['blockspin_data_v080.json.bak'] == modified and M.fs['blockspin_data_v080.json'] ~= nil)
M.hum.SeatPart = M.seat
M.click('Enregistrer un trajet'); M.run(3); M.click('Enregistrement EN COURS')
check('bouton Enregistrer : routes actuelles intactes apres enregistrement', #S.data.route_to_vendor == 2 and #S.recordBuffer >= 1)

-- 9. Rechargement : l'instance precedente est arretee
M, S = fresh()
local first = S
load(SCRIPT_SOURCE, '=blockspin_cycle_v080')()
check('rechargement : ancienne instance arretee', first.running == false and M.genv.BlockSpinCycle080 ~= first)
check('rechargement : une seule boucle Heartbeat', M.RunService.Heartbeat:count() == 1)
check('rechargement : une seule interface', (function()
    local n = 0
    for _, c in ipairs(M.pg:GetChildren()) do if c.Name == 'BlockSpinCycle080' then n = n + 1 end end
    return n == 1
end)())

-- 10. Interface du hub : touches remplacees par des boutons
M, S = fresh()
M.run(2)
local w0, rec0 = M.writes, S.recording
local root0 = { table.unpack(S.data.fish) }
for _, k in ipairs({ 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'F9', 'F10', 'F11' }) do M.press(k) end
M.run(4)
check('anciennes touches F3-F11 : sans effet', M.writes == w0 and S.recording == rec0 and not S.cycleRunning
    and S.data.fish[1] == root0[1] and #M.keyLog == 0)
local win = S.window
check('menu : visible au demarrage, onglet Cycle', win.Visible and M.ourGui():FindFirstChild('Cycle', true).Visible)
M.press('RightShift')
check('RightShift : masque le menu', win.Visible == false)
M.press('RightShift')
check('RightShift : reaffiche le menu', win.Visible == true)
M.click('Conduite')
check('onglet Conduite : affiche', M.ourGui():FindFirstChild('Conduite', true).Visible and not M.ourGui():FindFirstChild('Cycle', true).Visible)
M.click('Afficher / masquer le menu')
M.press('K')
check('raccourci modifiable : K', S.ui.hotkey == 'K' and M.fs['blockspin-settings-v1.json'] ~= nil)
M.press('K')
check('nouveau raccourci K actif', win.Visible == false)
M.press('K')
M.setRoot(Vector3.new(-300, 254.7, 600))
M.click('Point de peche = ici')
check('bouton Point de peche = ici', math.abs(S.data.fish[1] + 300) < 0.01 and math.abs(S.data.fish[3] - 600) < 0.01)
local box = M.findTextBox('ligne droite')
box.Text = '15/6'
M.click('Appliquer la vitesse')
check('vitesse via la zone de texte', S.cfg.drive.cruiseSpeed == 15 and S.cfg.drive.turnSpeed == 6)
M.click('Cycle vente/ATM')
check('bouton cycle auto : ACTIF', S.autoCycle and M.findButton('Cycle vente/ATM a 18/18 : ACTIF') ~= nil)
M.run(4, 0.02, function() return S.cycleRunning end)
M.press('F12')
M.run(0.5)
check('F12 garde : cycle annule et bouton remis a inactif', not S.autoCycle and M.findButton('Cycle vente/ATM a 18/18 : inactif') ~= nil and M.heldKeys() == '')

-- 11. Reglages du hub 0.4.0 conserves (profils compris)
local hubSettings = py_json_encode({ schema = 1, accent = 'FF8800', hotkey = 'RightShift', metrics = true, overlay = false,
    scale = 1, overlayMode = 'both', graph = false, profiles = { Perso = { accent = '00FF00', hotkey = 'RightShift', metrics = true, overlay = false } } })
M, S = fresh({ files = { ['blockspin-settings-v1.json'] = hubSettings } })
check('reglages hub : accent lu', S.ui.accent == 'FF8800')
local acc = M.findTextBox('Accent')
acc.Text = '#112233'
M.click('Appliquer la couleur')
local saved = py_json_decode(M.fs['blockspin-settings-v1.json'])
M2, S2 = fresh({ files = { ['blockspin-settings-v1.json'] = '{casse' } })
M2.findTextBox('Accent').Text = '#445566'
M2.click('Appliquer la couleur')
check('reglages illisibles : fichier preserve (pas ecrase)', M2.fs['blockspin-settings-v1.json'] == '{casse')
check('reglages illisibles : interface utilisable', S2.running and M2.ourGui() ~= nil)
check('reglages hub : accent sauve, profils et champs 0.4.0 conserves', saved.accent == '112233' and saved.profiles ~= nil
    and saved.profiles.Perso ~= nil and saved.overlayMode == 'both')
