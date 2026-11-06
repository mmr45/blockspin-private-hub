-- Regression signalee apres V1.2 : visee bloquante, curseur et relance lente.
local function fresh(prefs)
    local m=load(MOCK_SOURCE)()
    mouse1click=nil;mouse1press=nil;mouse1release=nil;isrbxactive=nil
    local Car=load(CAR_SOURCE)();m.setCar(Car.new(-350.97,844.32,20));m.setRoot(Vector3.new(-334.87,254.78,836.06))
    m.capLabel.Text='3/18';m.mouseX=320;m.mouseY=250
    if prefs then m.fs['blockspin-settings-v1.json']=py_json_encode(prefs) end
    load(SCRIPT_SOURCE,'=recast-client')();m.run(1)
    return m,m.genv.BlockSpinCycle080
end
local function minigame(m)
    local root=m.new('ScreenGui','SliderMinigame',m.pg)
    local panel=m.new('Frame','FishingPanel',root,{AbsolutePosition=Vector2.new(200,450),AbsoluteSize=Vector2.new(500,100)})
    m.new('TextLabel','Hint',panel,{Text='Keep the needle in the green target'})
    local bar=m.new('Frame','Bar',panel,{AbsolutePosition=Vector2.new(200,500),AbsoluteSize=Vector2.new(500,30)})
    m.new('Frame','Green',bar,{AbsolutePosition=Vector2.new(400,500),AbsoluteSize=Vector2.new(100,30)})
    m.new('Frame','Needle',bar,{AbsolutePosition=Vector2.new(445,500),AbsoluteSize=Vector2.new(6,30)})
    return root
end
local M,S=fresh()
check('relance : classique par defaut et delai court explicite',S.ui.aimAssist==false and S.castDelay==0.35)
S.saveSpot('Sans visée')
local mouseReads=0
function M.player:GetMouse() mouseReads=mouseReads+1;error('Mouse.Hit ne suit pas la souris simulee') end
S.fishingAim={x=400,y=300,world={999,999,999}};M.projectedVisible=false;M.failMouseMove=true
M.run(2.2)
check('classique : spot et Mouse.Hit perime ne bloquent plus la canne',(M.casts or 0)==1 and mouseReads==0)
check('classique : aucun deplacement de souris requis pour lancer',M.lastMoveAt==nil and M.lastCastMouse.X==320 and M.lastCastMouse.Y==250)
M.failMouseMove=false
local count=M.casts
local root=minigame(M);M.run(0.1)
check('curseur : clic natif cible accepte puis retour au point initial',S.clicks==1 and M.mouseX==320 and M.mouseY==250)
check('curseur : evenements de clic restent sur la barre',M.mouseEvents[#M.mouseEvents].x==450 and M.mouseEvents[#M.mouseEvents].y==515)
root.Enabled=false;M.tick(0.02);local ended=M.clock
M.run(0.2)
check('relance : attendre le court delai plutot que cliquer chaque frame',M.casts==count)
M.run(0.2)
check('relance : manche courte ne subit plus le retry de huit secondes',M.casts==count+1 and M.lastCastAt-ended>=0.35 and M.lastCastAt-ended<0.5,M.lastCastAt-ended)
check('relance : canne activee vers le curseur restaure sans mouvement manuel',M.lastCastMouse.X==320 and M.lastCastMouse.Y==250)
count=M.casts;M.run(7)
check('retry : sans nouveau mini-jeu, pas de spam apres relance',M.casts==count)
M.run(1.1)
check('retry : attente de huit secondes conservee en absence de reponse',M.casts==count+1)

-- Des cycles GUI courts et repetes doivent tous relancer sans aide manuelle.
M,S=fresh();M.run(2.2)
local before=M.casts;local exact=true
for i=1,4 do
    local gui=minigame(M);M.run(0.5);gui:Destroy();M.run(0.5)
    exact=exact and M.casts==before+i and M.lastCastMouse.X==320 and M.lastCastMouse.Y==250
end
check('relance : quatre manches courtes sans toucher le curseur',exact)
check('relance : une activation par fin de manche',M.casts==before+4)

M,S=fresh();root=minigame(M);M.run(0.1);root.Enabled=false;M.tick(0.02)
M.run(0.4)
check('relance : manche deja observee leve aussi le delai initial',(M.casts or 0)==1 and M.lastCastAt<3)
M,S=fresh();M.run(2.2);root=minigame(M);M.run(0.1);root.Enabled=false;M.tick(0.02)
count=M.casts;M.UIS.WindowFocusReleased:Fire();M.run(1)
check('relance : focus perdu suspend toutes les activations',M.casts==count)
M.UIS.WindowFocused:Fire();M.run(0.1)
check('relance : reprise apres retour au jeu sans deplacer la souris',M.casts==count+1)
M,S=fresh();M.run(2.2);root=minigame(M);M.run(0.1);root.Enabled=false;M.tick(0.02)
count=M.casts;S.cancel();M.run(1)
check('relance : STOP avant echeance empeche la canne',M.casts==count and S.paused)
M,S=fresh();M.run(2.2);root=minigame(M);M.run(0.1);root.Enabled=false;M.tick(0.02)
count=M.casts;M.capLabel.Text='18/18';S.checkInventory();M.run(1)
check('relance : inventaire plein reste prioritaire',M.casts==count and S.inventoryFull)

M,S=fresh();M.run(2.2);root=minigame(M);M.run(0.1)
count=M.casts;root.Enabled=false;M.run(0.1);root.Enabled=true;M.run(0.5)
check('relance : disparition GUI trop courte ne provoque pas de lancer',M.casts==count)

M,S=fresh();M.baitLabel.Text='x0';M.run(1)
check('appats : zero visible bloque toujours les lancers',S.baitEmpty and not S.baitUnknown)
M.baitLabel.Visible=false;M.run(2)
check('appats : ancien zero masque ne bloque plus la canne',S.baitUnknown and not S.baitEmpty and (M.casts or 0)>0)
M.baitLabel.Visible=true;M.baitLabel.Text='x16';M.run(1)
check('appats : lecture reprend quand le compteur redevient visible',not S.baitUnknown and S.baitCount==16)
M.baitLabel.Text='x0';M.run(1);M.baitLabel.Parent=nil;M.run(1)
check('appats : zero detache ou disparu devient inconnu',S.baitUnknown and not S.baitEmpty)

M,S=fresh({schema=1,accent='B07CFF',moneySourcePath='Existing',profiles={Old={accent='FF475C'}}})
check('migration : anciens reglages ne reactivate pas la visee stricte',not S.ui.aimAssist and S.ui.accent=='B07CFF')
M.click('Visée enregistrée :');M.click('Relance après une manche :')
local prefs=py_json_decode(M.fs['blockspin-settings-v1.json'])
check('reglages : assistance optionnelle et delai sauvegardes',prefs.aimAssist==true and prefs.recastDelay==0.75 and S.castDelay==0.75 and prefs.profiles.Old~=nil)
S.saveSpot('Sans visee');M.run(3)
check('assistance : validation stricte conservee si demandee',(M.casts or 0)==0 and S.fishingInputStatus:find('visee',1,true)~=nil)
M.click('Visée enregistrée :');M.run(0.1)
check('classique : desactiver l assistance debloque sans recapture',(M.casts or 0)==1)
M,S=fresh({schema=1,recastDelay=0/0,aimAssist='true'})
check('reglages : delai et mode invalides ignorent les valeurs',S.castDelay==0.35 and S.ui.aimAssist==false)

M,S=fresh();S.setFishingAimAssist(true);S.baitScreenPoint=Vector2.new(420,330);M.deferMouseMove=true
local pending=M.run(3,0.01,function() return S.castPending end)
S.setFishingAimAssist(false);M.run(0.2)
check('mode : changement invalide le lancer strict differe',pending and (M.casts or 0)==1)
check('mode : aucune erreur de tache',(M.taskErrors or 0)==0,M.lastTaskError)
