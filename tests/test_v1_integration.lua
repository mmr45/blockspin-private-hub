-- Scenarios V1 dans la maquette : aucun resultat ne prouve le jeu reel.
local Car = load(CAR_SOURCE, '=car')()
local function fresh(files)
    local M = load(MOCK_SOURCE, '=mock-v1')()
    M.placeShop(Vector3.new(-255.44,255.94,379.15), Vector3.new(-225.32,254.68,488.14))
    M.setCar(Car.new(-350.97,844.32,20))
    M.setRoot(Vector3.new(-334.87,254.78,836.06))
    for k,v in pairs(files or {}) do M.fs[k] = v end
    load(SCRIPT_SOURCE, '=hub-v1')()
    return M, M.genv.BlockSpinCycle080
end
local M, S = fresh()
local count = 0
for _,name in ipairs({'Fishing','Vehicle','Money','Farming','Statistics','Settings'}) do
    M.click(name)
    local p = M.ourGui():FindFirstChild(name,true)
    if p and p.Visible then count = count + 1 end
end
check('UI : six onglets accessibles', count == 6)
check('UI : STOP independant du menu', M.ourGui():FindFirstChild('EmergencyStop') ~= nil)
local writes = M.writes
S.baitScreenPoint = Vector2.new(100.5,200.25)
check('spot : enregistrement sans ecriture automatique', S.saveSpot('Pont') and M.writes == writes)
check('spot : selection a proximite', S.selectSpot('Pont') and S.hub.activeSpot == 'Pont')
M.setRoot(Vector3.new(100,0,0))
check('spot : selection distante refusee', not S.selectSpot('Pont'))
check('spot : aucune teleportation', M.root.Position.X == 100)
S.recordBuffer = {{1,2,3},{10,2,3}}
check('destination : enregistrement explicite', S.saveNamedRoute('Atelier'))
check('bibliotheque : sauvegarde explicite', S.saveLibrary() and M.fs['blockspin-library-v1.json'] ~= nil)
local saved = M.fs['blockspin-library-v1.json']
check('bibliotheque : fichier historique intact', M.fs['blockspin_data_v080.json'] == nil)
M, S = fresh({['blockspin-library-v1.json']=saved})
check('bibliotheque : spots et trajets restaures', S.hub.library.spots.Pont.aim.x == 100.5 and #S.hub.library.routes.Atelier == 2)
M, S = fresh({['blockspin-library-v1.json']='{casse'})
check('bibliotheque : JSON casse preserve', not S.saveLibrary() and M.fs['blockspin-library-v1.json'] == '{casse')
M.fs['blockspin-library-v1.json'] = saved
check('bibliotheque : rechargement explicite apres correction', S.loadLibrary() and S.saveLibrary())

M, S = fresh()
M.capLabel.Text='3/18'; M.run(4)
local casts = M.casts or 0
M.clickNamed('EmergencyStop'); M.run(12)
check('STOP : peche et cycle suspendus', S.paused and not S.fishingEnabled and not S.autoCycle and not S.cycleRunning)
check('STOP : aucun lancer ulterieur', (M.casts or 0) == casts)
check('STOP : reprise explicite', S.resume())
M.run(10)
check('reprise : lancers relances', (M.casts or 0) > casts)
S.ui.rareAction = 'leave'
S.onMinigameStart()
M.new('TextLabel','Rare',M.pg:FindFirstChild('HUD'),{Text='LEGENDARY Oarfish',AbsolutePosition=Vector2.new(0,0),AbsoluteSize=Vector2.new(200,30)})
S.onMinigameEnd(M.clock); S.scanCatch(M.clock)
S.cancel(); M.run(2)
check('STOP : annule aussi le depart serveur differe', M.kicked == nil)

M, S = fresh()
local tok = S.token
task.spawn(function()
    S.performStep('BLOQUE', 0.5, tok, function() task.wait(5); return true end)
end)
M.run(1)
check('superviseur : expiration interrompt une action en attente', S.state == 'ERROR' and S.hub.current == nil and S.token ~= tok)
check('superviseur : journal d\'erreur visible', #S.hub.errors > 0 and S.views.errors ~= nil)
M.run(5)
check('superviseur : action expiree sans faux succes', S.state == 'ERROR')
local ok = S.performStep('PREUVE', 2, S.token, function() return true end, function() return false end)
check('superviseur : action sans preuve refusee', not ok and S.hub.history[#S.hub.history].ok == false)
ok = S.performStep('EXCEPTION', 2, S.token, function() error('test volontaire') end)
check('superviseur : exception capturee', not ok and S.hub.current == nil)

M, S = fresh()
local oldToken = S.token
check('culture : refusee sans adaptateur', not S.startFarm({{plot='A',crop='Corn'}},true) and S.token == oldToken and not S.cycleRunning)
local plots = { A={state='ready',crop='Corn'}, B={state='empty'} }
local function adapter(noProof)
    return {observe=function(id) return plots[id] end,
        harvest=function(id) if not noProof then plots[id]={state='empty'} end; return true end,
        plant=function(id,crop) if not noProof then plots[id]={state='growing',crop=crop} end; return true end}
end
check('culture : enregistrement de l\'adaptateur', S.setFarmingAdapter(adapter()))
check('culture : plusieurs plantes et replantation demarrees', S.startFarm({{plot='A',crop='Corn'},{plot='B',crop='Pumpkin'}},true))
M.run(0.5)
check('culture : recolte + replantation observees', S.hub.farm.harvested == 1 and S.hub.farm.planted == 2 and plots.A.state=='growing' and plots.B.crop=='Pumpkin')
check('culture : exclut un cycle concurrent', not S.runCycle())
check('culture : adaptateur immuable pendant activite', not S.setFarmingAdapter(adapter()))
M.press('F12'); local planted = S.hub.farm.planted; M.run(3)
check('culture : F12 arrete la boucle', not S.hub.farm.running and not S.cycleRunning and S.hub.farm.planted==planted)

M, S = fresh()
plots = {A={state='ready',crop='Corn'}}
S.setFarmingAdapter(adapter(true)); S.startFarm({{plot='A',crop='Corn'}},false)
M.run(22)
check('culture : pas de faux succes sans observation', S.state=='ERROR' and S.hub.farm.harvested==0 and not S.cycleRunning)
check('culture : erreur journalisee', #S.hub.errors > 0)
M, S = fresh()
S.setFarmingAdapter({ observe=function() error('observation absente') end, plant=function() return true end, harvest=function() return true end })
S.startFarm({{plot='A',crop='Corn'}},false); M.run(1)
check('culture : exception adaptateur capturee', S.state=='ERROR' and not S.cycleRunning and (M.taskErrors or 0)==0)

M, S = fresh()
M.findTextBox('Accent #').Text='#12ABEF'; M.click('Appliquer mon accent')
M.click('Animations :')
local prefs = py_json_decode(M.fs['blockspin-settings-v1.json'])
check('reglages : accent libre et animations sauvegardes', prefs.accent=='12ABEF' and prefs.animations==false)
M.run(2)
check('dashboard : affiche les donnees de session', S.views.dashboard.Text:find('Session',1,true) ~= nil and S.views.money.Text:find('500',1,true) ~= nil)
check('V1 : aucune erreur de tache inattendue', (M.taskErrors or 0)==0, M.lastTaskError)

-- Argent raccorde au cycle complet, pas uniquement au module pur.
M, S = fresh()
M.saleRevenue = 1200
M.hum.SeatPart = M.seat; M.run(1.2); M.hum.SeatPart = nil
M.setRoot(Vector3.new(-334.87,254.78,836.06))
local writesBefore = M.writes
S.autoCycle = true
M.run(600,0.02,function() return S.state=='ERROR' or (S.state=='FISHING' and S.detail:find('cycle complet',1,true)) end)
check('session : vente puis depot puis retour completes', S.state=='FISHING' and S.detail:find('cycle complet',1,true)~=nil, S.detail)
check('session : gains de vente observes dans le cycle', S.hub.money.earned==1200 and S.hub.money.sales==1, S.hub.money.earned)
check('session : depot distinct du revenu', S.hub.money.deposited==1700 and S.hub.money.deposits==1 and M.cash==0)
check('session : etapes reussies historisees', #S.hub.history>=10 and S.hub.current==nil)
check('session : donnees utilisateur jamais sauvegardees automatiquement', M.writes==writesBefore)

-- Echec d'une operation requise : aucune poursuite masquee du cycle.
M, S = fresh()
S.depositRequired = true; S.autoBank = false
S.runCycle()
check('cycle : depot requis incompatible refuse avant mouvement', S.state=='ERROR' and #M.keyLog==0 and not S.cycleRunning)

-- L'absence de fichiers locaux et les erreurs d'ecriture restent explicites.
M, S = fresh()
writefile = nil
check('bibliotheque : absence de stockage geree', not S.saveLibrary() and S.running)
writefile = function() error('disque plein') end
check('bibliotheque : erreur d\'ecriture capturee', not S.saveLibrary() and #S.hub.errors>0)
check('culture : plan duplique refuse', (function()
    S.setFarmingAdapter(adapter())
    return not S.startFarm({{plot='A',crop='Corn'},{plot='A',crop='Pumpkin'}},false)
end)())
