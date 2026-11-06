-- Maquette de pression/relachement et disponibilite : pas les mecanismes de BlockSpin.
local function fresh(setup)
    local m=load(MOCK_SOURCE)()
    mouse1click=nil;mouse1press=nil;mouse1release=nil;isrbxactive=nil
    local Car=load(CAR_SOURCE)();m.setCar(Car.new(-350.97,844.32,20));m.setRoot(Vector3.new(-334.87,254.78,836.06))
    m.capLabel.Text='3/18';m.mouseX=320;m.mouseY=250
    if setup then setup(m) end
    load(SCRIPT_SOURCE,'=rod-client')();m.run(1)
    return m,m.genv.BlockSpinCycle080
end
local function minigame(m)
    local root=m.new('ScreenGui','SliderMinigame',m.pg)
    local panel=m.new('CanvasGroup','FishingPanel',root,{GroupTransparency=0,AbsolutePosition=Vector2.new(200,450),AbsoluteSize=Vector2.new(500,100)})
    m.new('TextLabel','Hint',panel,{Text='Keep the needle in the green target'})
    local bar=m.new('Frame','Bar',panel,{AbsolutePosition=Vector2.new(200,500),AbsoluteSize=Vector2.new(500,30)})
    m.new('Frame','Green',bar,{AbsolutePosition=Vector2.new(400,500),AbsoluteSize=Vector2.new(100,30)})
    m.new('Frame','Needle',bar,{AbsolutePosition=Vector2.new(445,500),AbsoluteSize=Vector2.new(6,30)})
    return root,panel
end
local M,S=fresh(function(m) m.requireRodRelease=true end)
M.run(2.2)
check('canne : un appui normal est relache',M.casts==1 and M.rodReleases==1 and not M.rod._active)
check('canne : signal Activated distingue de la demande',S.castDiagnostic.requests==1 and S.castDiagnostic.accepted==1)
check('canne : abonnement de preuve detache apres la pression',M.rod.Activated:count()==0 and S.rodPress==nil)
local count=M.casts
for i=1,4 do local root=minigame(M);M.run(0.2);root:Destroy();M.run(0.5) end
check('canne : quatre relances avec verrou de pression',M.casts==count+4 and M.rodReleases==M.casts and not M.rod._active)
check('canne : aucune activation ignoree par pression maintenue',(M.ignoredActivations or 0)==0)

M,S=fresh(function(m) m.requireRodRelease=true;m.rod:Activate() end)
M.run(2.2)
check('canne : ancienne pression au chargement nettoyee avant activation',M.casts==2 and M.rodReleases==2 and (M.ignoredActivations or 0)==0)

M,S=fresh(function(m) m.rod.Enabled=false end)
M.run(5)
check('canne indisponible : aucune tentative ignoree',(M.activationCalls or 0)==0 and S.castDiagnostic.accepted==0)
check('canne indisponible : cause affichee sans faux lancer',S.castDiagnostic.phase=='disabled' and S.castDiagnostic.enabled==false)
local readyAt=M.clock;M.rod.Enabled=true;M.run(0.12)
check('canne prete : activation sans attente residuelle de huit secondes',M.casts==1 and M.lastCastAt-readyAt<0.05)

M,S=fresh();M.run(2.2)
local root=minigame(M);M.run(0.2);root:Destroy();M.rod.Enabled=false;M.run(2)
check('recuperation apres poisson : pas de faux nouvel appui',M.casts==1 and S.castDiagnostic.accepted==1)
readyAt=M.clock;M.rod.Enabled=true;M.run(0.12)
check('recuperation apres poisson : relance des que Enabled revient',M.casts==2 and M.lastCastAt-readyAt<0.05)

M,S=fresh(function(m) m.ignoreNextActivations=2 end)
M.run(5)
check('activation ignoree : reprise bornee sans attendre quinze secondes',M.casts==1 and M.lastCastAt<5.1,M.lastCastAt)
check('activation ignoree : deux absences de signal comptees, un seul accepte',S.castDiagnostic.requests==3 and S.castDiagnostic.accepted==1 and S.castDiagnostic.unacknowledged==2)
check('activation ignoree : ecart des tentatives borne',#S.castDiagnostic.events<=40 and not S.castPending)

M,S=fresh(function(m) m.ignoreNextActivations=100 end)
M.run(20)
check('refus prolonges : backoff evite une boucle par frame',(M.activationCalls or 0)<10 and S.castDiagnostic.accepted==0)
check('refus prolonges : pas de fuite des signaux',M.rod.Activated:count()<=1)
S.stop();M.run(1)
check('refus prolonges : fermeture coupe le signal en attente',M.rod.Activated:count()==0 and not M.rod._active)

M,S=fresh(function(m) m.failRodActivation=true end);M.run(4)
check('exception Activate : erreurs capturees sans delai de succes',S.castDiagnostic.errors>0 and S.castDiagnostic.accepted==0 and (M.taskErrors or 0)==0)
M.failRodActivation=false;M.run(2)
check('exception corrigee : reprise avant le retry historique',M.casts==1 and S.castDiagnostic.accepted==1)

M,S=fresh(function(m) m.rodSignalDelay=0.1 end);M.run(2.4)
check('signal differe : accepte dans sa fenetre sans duplicata',M.casts==1 and S.castDiagnostic.accepted==1 and S.castDiagnostic.unacknowledged==0)

M,S=fresh();M.run(2.2)
local old=M.rod;old:Destroy()
local new=M.new('Tool','Fishing Rod v2',M.char or M.player.Character)
new.Activate=old.Activate;new.Deactivate=old.Deactivate
local replacedAt=M.clock;M.run(0.12)
check('canne remplacee : pas de retry residuel du vieux Tool',M.casts==2 and M.lastCastAt-replacedAt<0.05)

M,S=fresh(function(m)
    m.rod.Activated=nil
    function m.rod:Activate() m.casts=(m.casts or 0)+1;m.lastCastAt=m.clock end
end);M.run(2.3)
check('signal indisponible : appel non verifie distinct des signaux',S.castDiagnostic.accepted==0 and S.castDiagnostic.unverified==1)

M,S=fresh(function(m) m.requireRodRelease=true end)
M.run(2.2)
-- Declencher un nouveau cycle puis arreter pendant la pression de 50 ms.
root=minigame(M);M.run(0.2);root:Destroy()
M.run(1,0.01,function() return M.rod._active end)
local casts=M.casts;S.cancel();M.run(1)
check('STOP : relachement immediat de la canne sans nouvel appui',not M.rod._active and M.casts==casts and M.rod.Activated:count()==0)

M,S=fresh(function(m) m.requireRodRelease=true end)
M.run(3,0.01,function() return M.rod._active end)
casts=M.casts;M.UIS.WindowFocusReleased:Fire();M.run(0.3)
check('focus perdu : canne relachee meme pendant sa pression',not M.rod._active and M.casts==casts and M.rod.Activated:count()==0)

M,S=fresh(function(m) m.requireRodRelease=true end)
M.run(3,0.01,function() return M.rod._active end)
casts=M.casts;S.setFishingAimAssist(true);M.run(0.3)
check('changement de mode : pression precedente liberee',not M.rod._active and M.rodReleases>=1)

M,S=fresh();M.run(2.2);local panel
root,panel=minigame(M);M.run(0.2);casts=M.casts
panel.GroupTransparency=1;M.run(0.5)
check('mini-jeu transparent : ne bloque plus le prochain lancer',M.casts==casts+1)
check('mini-jeu transparent : fin observee en diagnostic',S.castDiagnostic.lastEnd~=nil)

M,S=fresh();M.run(2.2)
local raw;setclipboard=function(value) raw=value end
M.click('Exporter le diagnostic de relance')
local data=py_json_decode(raw)
check('diagnostic : export local des phases et horodatages',data.version=='1.2.2' and data.diagnostic.accepted==1 and #data.diagnostic.events>0 and data.diagnostic.lastAccepted~=nil)
check('diagnostic : pas d identite ni secret dans le bilan',data.userId==nil and data.job==nil and data.username==nil)
setclipboard=nil
check('diagnostic : etat et compteur affiches',S.design.widgets.rodState.Text:find('signaux',1,true)~=nil and S.design.widgets.castWait.Text~='En attente')
check('V1.2.2 : aucune erreur de coroutine',(M.taskErrors or 0)==0,M.lastTaskError)
