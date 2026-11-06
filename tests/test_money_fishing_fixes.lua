-- Regressions issues des captures utilisateur : portefeuille, spots et clics cibles.
local Car=load(CAR_SOURCE,'=car')()
local function fresh(before)
    local M=load(MOCK_SOURCE,'=fix-mock')()
    mouse1click=nil;mouse1press=nil;mouse1release=nil;isrbxactive=nil
    M.setCar(Car.new(-350.97,844.32,20));M.setRoot(Vector3.new(-334.87,254.78,836.06))
    if before then before(M) end
    load(SCRIPT_SOURCE,'=fix-client')();M.run(0.5)
    return M,M.genv.BlockSpinCycle080
end
local M,S=fresh()
check('money auto : premier solde lu sans bouton', S.moneyReading.available and S.hub.money.cash==500 and S.design.widgets.cash.Text=='500 $')
M.cashLabel.Text='Cash: $625';M.run(1)
check('money auto : changement de portefeuille affiche automatiquement', S.hub.money.cash==625 and S.design.widgets.cash.Text=='625 $')
check('money auto : hausse observee distinguee de la vente', S.hub.money.observedIncreases==125 and S.hub.money.earned==0 and S.design.widgets.earned.Text=='125 $')
M.cashLabel.Text='Cash: $700';M.cashLabel:GetPropertyChangedSignal('Text'):Fire()
check('money auto : signal de texte actualise immediatement', S.moneyReading.value==700 and S.design.widgets.cash.Text=='700 $')
local scans=M.pgScans
M.run(20)
check('money cache : aucun nouveau parcours GUI pendant les lectures', M.pgScans==scans,M.pgScans-scans)
M.cashLabel.Visible=false;M.run(1)
check('money masque : N/D avec statut explicite', not S.moneyReading.available and S.design.widgets.cash.Text=='N/D' and S.moneyReading.status~='')
M.cashLabel.Visible=true;M.run(1)
check('money masque : reprise automatique du meme compteur', S.moneyReading.available and S.moneyReading.value==700)
M,S=fresh(function(M) M.cashLabel.Text='$1 234' end)
check('money sans libelle : aucune attribution arbitraire', not S.moneyReading.available and #S.moneyCandidates==1 and S.hub.money.cash==nil)
check('money sans libelle : choix du compteur possible', S.chooseMoneySource(S.moneyCandidates[1].path) and S.hub.money.cash==1234)
M.cashLabel.Text='$1 500';M.run(1)
check('money choisi : source suivie sans nouveau choix', S.hub.money.cash==1500 and S.hub.money.observedIncreases==266)
M,S=fresh(function(M)
    M.new('TextLabel','OtherCash',M.cashLabel.Parent,{Text='Cash: $900',AbsolutePosition=Vector2.new(10,10),AbsoluteSize=Vector2.new(100,20)})
end)
check('money ambigu : compteurs differents non fusionnes', not S.moneyReading.available and #S.moneyCandidates==2)
local source
for _,c in ipairs(S.moneyCandidates) do if c.value==500 then source=c.path end end
S.chooseMoneySource(source)
local other=M.new('TextLabel','ThirdCash',M.cashLabel.Parent,{Text='$2000',AbsolutePosition=Vector2.new(10,10),AbsoluteSize=Vector2.new(100,20)})
S.searchMoneySources()
check('money recherche : scan force meme avec cache valide', #S.moneyCandidates==3)
S.chooseMoneySource(other:GetFullName())
check('money changement de source : pas de faux gain de 1500', S.hub.money.cash==2000 and S.hub.money.observedIncreases==0)
M,S=fresh(function(M)
    M.cashLabel.Text='aucun solde'
    local stats=M.new('Folder','leaderstats',M.player)
    M.cashValue=M.new('IntValue','Cash',stats,{Value=800})
end)
check('money sans GUI : donnee numerique publique existante lue', S.moneyReading.available and S.hub.money.cash==800)
M.cashValue.Value=850;M.cashValue:GetPropertyChangedSignal('Value'):Fire()
check('money donnee numerique : Value surveille', S.moneyReading.value==850 and S.hub.money.observedIncreases==50)
M,S=fresh(function(M)
    M.cashLabel.Text='aucun solde'
    local stats=M.new('Folder','leaderstats',M.player);M.new('IntValue','Bank',stats,{Value=9000})
end)
check('money banque : jamais choisie comme portefeuille automatiquement', not S.moneyReading.available and S.hub.money.cash==nil)
M,S=fresh(function(M) M.cashLabel.Text='pas de compteur' end)
M.run(70)
check('money absent : aucun faux taux horaire', S.design.widgets.hourly.Text=='N/D')
S.stop()
check('money nettoyage : observateur de compteur coupe', M.cashLabel:GetPropertyChangedSignal('Text'):count()==0)

-- Spots : nom facultatif, capture apres enregistrement, projection et attente moteur.
M,S=fresh();M.capLabel.Text='3/18';M.run(1)
local ok,why,name=S.saveSpot('   ')
check('spot vide : nom automatique et aucune erreur invalide', ok and name=='Spot 1' and S.hub.activeSpot=='Spot 1',why)
check('spot nouveau : point de retour du cycle mis a jour', S.data.fish[1]==M.root.Position.X and S.data.fish[3]==M.root.Position.Z)
M.run(3)
check('spot sans visee : aucun appat lance au hasard', (M.casts or 0)==0 and S.fishingInputStatus:find('visee',1,true)~=nil)
M.mouseX,M.mouseY=400,300;M.mouseWorld=Vector3.new(20,2,50)
check('spot capture : visee liee au spot actif', S.captureAimNow('Spot 1') and S.hub.library.spots['Spot 1'].aim.world[3]==50)
M.projectedPoint=Vector3.new(700,360,12);M.deferMouseMove=true
M.mouseX,M.mouseY=1900,100
M.run(1)
check('spot projection : canne lancee au point projete', (M.casts or 0)>0 and M.lastCastMouse.X==700 and M.lastCastMouse.Y==360)
check('spot projection : moteur a traite le mouvement avant lancer', M.mouseProcessedAt<=M.lastCastAt and M.lastCastAt>M.lastMoveAt)
check('spot selection : nom vide choisit le spot actif', (S.selectSpot('  ')))
local beforeWrites=M.writes
M.mouseX,M.mouseY=500,330;M.mouseWorld=Vector3.new(22,2,55);S.captureAimNow('Spot 1')
check('spot recapture : donnee du spot mise a jour sans disque', S.hub.library.spots['Spot 1'].aim.world[3]==55 and M.writes==beforeWrites)
S.saveSpot('Spot 2');S.selectSpot('Spot 2')
check('spot capture changee : ancien choix refuse', not S.captureAimNow('Spot 1'))
S.stop()
M,S=fresh();M.capLabel.Text='3/18';S.baitScreenPoint=Vector2.new(420,330);M.deferMouseMove=true;M.failMouseMove=true;M.run(4)
check('visee refusee : pas de Tool Activate faux positif', (M.casts or 0)==0 and S.fishingInputStatus:find('refuse',1,true)~=nil)
M,S=fresh();M.capLabel.Text='3/18';S.baitScreenPoint=Vector2.new(420,330);M.deferMouseMove=true
local awaiting=M.run(4,0.01,function() return S.castPending end);S.cancel();M.run(0.2)
check('lancer differe : STOP annule apres le mouvement avant Activate', awaiting and (M.casts or 0)==0)
M,S=fresh();M.capLabel.Text='3/18';S.baitScreenPoint=Vector2.new(420,330);M.deferMouseMove=true
M.UIS.WindowFocusReleased:Fire();M.run(4)
check('focus perdu : aucun lancer de peche', (M.casts or 0)==0 and not S.inputFocused)
M.UIS.WindowFocused:Fire();M.run(1)
check('focus retrouve : lancer reprend au point enregistre', (M.casts or 0)>0 and M.lastCastMouse.X==420)
M,S=fresh();M.capLabel.Text='3/18';S.fishingAim={x=300,y=200,viewport={x=800,y=600}};M.run(4)
check('ancienne visee ecran : changement de resolution demande recapture', (M.casts or 0)==0 and S.fishingInputStatus:find('resolution',1,true)~=nil)
M,S=fresh();M.capLabel.Text='3/18';S.fishingAim={x=300,y=200,world={0,0,0}};M.projectedPoint=Vector3.new(200,200,-4);M.run(4)
check('visee derriere la camera : pas de lancer', (M.casts or 0)==0)

local function minigame(M)
    local root=M.new('ScreenGui','SliderMinigame',M.pg)
    local panel=M.new('Frame','FishingPanel',root,{AbsolutePosition=Vector2.new(200,450),AbsoluteSize=Vector2.new(500,100)})
    M.new('TextLabel','Hint',panel,{Text='Keep the needle in the green target',AbsolutePosition=Vector2.new(200,450),AbsoluteSize=Vector2.new(300,20)})
    local bar=M.new('Frame','Bar',panel,{AbsolutePosition=Vector2.new(200,500),AbsoluteSize=Vector2.new(500,30)})
    local target=M.new('Frame','Green',bar,{AbsolutePosition=Vector2.new(400,500),AbsoluteSize=Vector2.new(100,30)})
    M.new('Frame','Needle',bar,{AbsolutePosition=Vector2.new(445,500),AbsoluteSize=Vector2.new(6,30)})
    return target,panel
end
M,S=fresh();M.capLabel.Text='3/18';local target,panel=minigame(M)
M.mouseX,M.mouseY=-100,-100
M.tick(0.02)
check('mini-jeu : clic a la barre avec curseur hors fenetre', S.clicks==1 and M.mouseEvents[#M.mouseEvents].x==450 and M.mouseEvents[#M.mouseEvents].y==515)
check('mini-jeu : menu masque immediatement avant le clic', not S.window.Visible and S.hiddenForMinigame)
check('mini-jeu : methode native ciblee annoncee', S.method=='VirtualInputManager (barre)')
M.run(0.2)
check('mini-jeu : pas de clics multiples sur la meme cible', S.clicks==1)
M,S=fresh();M.capLabel.Text='3/18';target,panel=minigame(M)
M.UIS.WindowFocusReleased:Fire();M.run(1)
check('mini-jeu hors focus : aucun clic dans une autre application', S.clicks==0 and #(M.mouseEvents or {})==0)
M.UIS.WindowFocused:Fire();M.tick(0.02)
check('mini-jeu focus retrouve : prediction et armement reinitialises', S.clicks==1)
M,S=fresh();M.capLabel.Text='3/18';target,panel=minigame(M)
function M.pg:GetGuiObjectsAtPosition(x,y)
    if x==450 and y==551 then return {target} end
    return {}
end
M.tick(0.02)
check('mini-jeu inset : coordonnees choisies par hit-test', S.clicks==1 and M.mouseEvents[#M.mouseEvents].y==551)
M,S=fresh();M.capLabel.Text='3/18';target,panel=minigame(M);M.failMouseButtons=true
local rawClicks=0;mouse1click=function() rawClicks=rawClicks+1 end
M.mouseX,M.mouseY=-100,-100;M.UIS.WindowFocused:Fire();M.tick(0.02)
check('mini-jeu refus natif : aucun clic OS hors de la barre', rawClicks==0 and S.clicks==0)
check('correctif : aucune erreur de coroutine non capturee', (M.taskErrors or 0)==0,M.lastTaskError)

M,S=fresh(function(M) M.cashLabel.Text='inconnu';M.player:SetAttribute('Cash',450) end)
check('money attribut public : lu si reellement present', S.moneyReading.available and S.hub.money.cash==450)
M.player:SetAttribute('Cash',475)
check('money attribut public : mise a jour par signal natif', S.moneyReading.value==475 and S.hub.money.observedIncreases==25)
local signal=M.player:GetAttributeChangedSignal('Cash');S.stop()
check('money attribut public : signal nettoye', signal:count()==0)
M,S=fresh();M.capLabel.Text='3/18';target,panel=minigame(M);M.UIS.focused={}
M.run(1)
check('saisie de texte : aucun clic ni lancer parasite', S.clicks==0 and (M.casts or 0)==0)
M.UIS.focused=nil;M.tick(0.02)
check('saisie de texte : reprise apres sortie du champ', S.clicks==1)
M,S=fresh();M.mouseX,M.mouseY=-100,-100
check('capture hors fenetre : pas de point invente', not S.captureAimNow())
M.mouseX,M.mouseY=450,300;S.saveSpot('Capturé');M.mouseWorld=Vector3.new(1,2,3)
local writesBefore=M.writes
M.click('Capturer la visee dans 3 secondes');M.run(3.2)
check('capture bouton : spot existant actualise sans nouvel enregistrement', S.hub.library.spots['Capturé'].aim.world[3]==3 and M.writes==writesBefore)
S.saveLibrary();local raw=M.fs['blockspin-library-v1.json']
S.loadLibrary()
check('capture bouton : point monde restaure depuis bibliotheque', S.hub.library.spots['Capturé'].aim.world[3]==3 and raw~=nil)
M,S=fresh();M.cashLabel:Destroy()
M.cashLabel=M.new('TextLabel','Cash',M.pg:FindFirstChild('HUD'),{Text='Cash: $600',AbsolutePosition=Vector2.new(0,0),AbsoluteSize=Vector2.new(100,20)})
M.run(1)
check('money source recreee : nouveau compteur retrouve sans attendre 10 s', S.moneyReading.available and S.moneyReading.value==600)
M,S=fresh();M.capLabel.Text='3/18';S.fishingAim={x=400,y=300,world={1,2,3}};M.projectedPoint=Vector3.new(400,300,20);M.mouseWorld=Vector3.new(100,2,300)
M.run(4)
check('visee monde obstruee : aucun lancer avec Mouse.Hit different', (M.casts or 0)==0 and S.fishingInputStatus:find('monde non confirmee',1,true)~=nil)
M,S=fresh();M.capLabel.Text='3/18';S.design.pointer={}
M.run(4)
check('reglage interface : peche suspendue pendant un glisser', (M.casts or 0)==0)
S.design.pointer=nil
