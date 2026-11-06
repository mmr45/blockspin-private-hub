-- V1.1 : controles visuels et observateur serveur dans la maquette Roblox.
local Car=load(CAR_SOURCE,'=car')()
local function fresh()
    local M=load(MOCK_SOURCE,'=visual-mock')()
    M.setCar(Car.new(-350.97,844.32,20));M.setRoot(Vector3.new(-334.87,254.78,836.06))
    load(SCRIPT_SOURCE,'=visual-client')();M.run(0.5)
    return M,M.genv.BlockSpinCycle080
end
local function pointer(kind,x,y) return {UserInputType=Enum.UserInputType[kind],Position={X=x,Y=y}} end
local M,S=fresh()
check('V1.1 : sept onglets dont Server', #S.design.navItems==7 and M.ourGui():FindFirstChild('Server',true)~=nil)
local profile=M.ourGui():FindFirstChild('RobloxProfile',true)
check('profil : avatar place en haut a la place du logo', profile.Position.Y.Scale==0 and profile.Position.Y.Offset==20)
check('profil : aucun monogramme B dans la barre laterale', (function()
    for _,o in ipairs(S.design.sidebar:GetDescendants()) do if o:IsA('TextLabel') and o.Text=='B' then return false end end;return true
end)())
check('dashboard : vrais widgets numeriques', S.design.widgets.cash.Text=='N/D' and S.design.widgets.casts.Text=='0')
check('dashboard : jauge inventaire reliee au compteur', S.design.widgets.inventory.Text=='18/18' and S.design.widgets.inventoryFill.Size.X.Scale==1)
check('dashboard : pas de resume technique en bloc', S.views.dashboard.Text=='Session' and S.views.money.Text=='N/D')
M.click('Money')
check('tuiles : contenu adapte a la categorie', S.design.pages[M.ourGui():FindFirstChild('Money',true)].tiles[1].Text=='0 $')
M.click('Statistics');M.run(32)
check('courbes : uniquement des mesures et historique borne', #S.design.charts.fps.values==30 and #S.design.charts.ping.values==30)
function M.player:GetNetworkPing() error('indisponible') end
M.run(1.2)
check('courbe : ping absent donne N/D', S.design.charts.ping.label.Text=='N/D')

-- Plan saturation/luminosite et teinte. La position de controle est fournie par le moteur reel.
M,S=fresh();M.click('Settings')
local picker=S.design.picker
picker.sv.AbsolutePosition=Vector2.new(100,100);picker.sv.AbsoluteSize=Vector2.new(200,160)
picker.hue.AbsolutePosition=Vector2.new(330,100);picker.hue.AbsoluteSize=Vector2.new(22,160)
local savedAccent=S.ui.accent;local writes=M.writes
local down=pointer('MouseButton1',300,100)
picker.sv.InputBegan:Fire(down)
check('couleur : glisser donne saturation/luminosite', picker.s==1 and picker.v==1)
M.UIS.InputChanged:Fire(pointer('MouseMovement',200,180))
check('couleur : fractions precises', math.abs(picker.s-0.5)<0.001 and math.abs(picker.v-0.5)<0.001)
M.UIS.InputChanged:Fire(pointer('MouseMovement',1000,-100))
check('couleur : curseur borne hors du plan', picker.s==1 and picker.v==1)
M.UIS.InputEnded:Fire(down)
check('couleur : aucun fichier ecrit pendant le glisser', M.writes==writes and S.ui.accent==savedAccent)
local hueDown=pointer('MouseButton1',340,180);picker.hue.InputBegan:Fire(hueDown);M.UIS.InputEnded:Fire(hueDown)
check('couleur : teinte cyan obtenue a la souris', picker.hex=='00FFFF',picker.hex)
M.click('Appliquer la couleur')
check('couleur : application et sauvegarde explicites', S.ui.accent=='00FFFF' and py_json_decode(M.fs['blockspin-settings-v1.json']).accent=='00FFFF')
local committedWrites=M.writes
local touch=pointer('Touch',200,180);picker.sv.InputBegan:Fire(touch)
M.UIS.InputChanged:Fire(pointer('Touch',100,260))
check('couleur tactile : un autre doigt ignore', picker.s==0.5 and picker.v==0.5)
touch.Position={X=100,Y=260};M.UIS.InputChanged:Fire(touch);M.UIS.InputEnded:Fire(touch)
check('couleur tactile : noir choisi sans division invalide', picker.hex=='000000')
M.click('Annuler la couleur')
check('couleur : annulation restaure l\'accent sans ecrire', picker.hex=='00FFFF' and M.writes==committedWrites)
down=pointer('MouseButton1',200,180);picker.sv.InputBegan:Fire(down);M.UIS.WindowFocusReleased:Fire()
check('couleur : perte de focus annule la capture', S.design.pointer==nil and picker.hex==S.ui.accent)
picker.sv.InputBegan:Fire(down);M.UIS.InputEnded:Fire(down);M.click('Fishing')
check('couleur : changement de page abandonne l\'apercu', picker.hex==S.ui.accent)
M.click('Settings');picker.sv.InputBegan:Fire(down);M.clickNamed('Minimize');M.run(0.3)
check('couleur : masquer le menu annule le glisser', S.design.pointer==nil and picker.hex==S.ui.accent)
M.clickNamed('OpenHub');M.run(0.3)
M.clickNamed('CouleurB07CFF')
check('couleur : palette et selecteur synchronises', picker.hex=='B07CFF')
picker.sv.AbsoluteSize=Vector2.new(0,0)
check('couleur : surface de taille nulle geree', pcall(function() picker.sv.InputBegan:Fire(down);M.UIS.InputEnded:Fire(down) end))

local slider=S.design.scaleSlider
slider.input.AbsolutePosition=Vector2.new(100,100);slider.input.AbsoluteSize=Vector2.new(200,30)
local scaleBefore=S.ui.scale;writes=M.writes
local slide=pointer('MouseButton1',300,110);slider.input.InputBegan:Fire(slide)
check('echelle : apercu sans modification prematuree', slider.value==1.5 and S.ui.scale==scaleBefore and M.writes==writes)
M.UIS.InputEnded:Fire(slide)
check('echelle : valeur sauvegardee au relachement', S.ui.scale==1.5 and M.writes==writes+1)
slide=pointer('MouseButton1',-50,110);slider.input.InputBegan:Fire(slide);M.UIS.WindowFocusReleased:Fire()
check('echelle : focus perdu restaure sans sauvegarde', slider.value==1.5 and S.ui.scale==1.5)
M.click('Densité :');local density=S.ui.density
check('reglages : densite compacte appliquee', density=='compact' and S.design.rows[1].button.Size.Y.Offset==38)
M.findTextBox('Nom du profil').Text='Visuel';M.click('Enregistrer le profil');M.click('Densité :');M.click('Charger le profil')
check('reglages : densite restauree avec le profil', S.ui.density=='compact')
M.click('Masquer pendant la pêche :')
check('reglages : masquage de peche configurable', S.ui.hideInMinigame==false)

-- Les joueurs deja presents ne sont pas inventes comme des arrivees recentes.
M,S=fresh();M.click('Server')
check('serveur : population initiale et capacite reelles de la maquette', S.server.count==1 and S.server.maxPlayers==30)
check('serveur : aucune fausse arrivee a l\'initialisation', S.server.joined==0 and #S.server.events==0)
check('serveur : localisation inconnue explicitement', S.server.region==nil and S.design.widgets.serverRegion.Text=='Non fournie')
local bob=M.new('Player','Bob',M.Players,{UserId=902,DisplayName='Bobby'})
M.Players.PlayerAdded:Fire(bob);M.run(1)
check('serveur : arrivee observee et population mises a jour', S.server.count==2 and S.server.joined==1 and S.design.widgets.serverPlayers.Text=='2')
check('serveur : derniere arrivee correctement affichee', S.design.lists.serverJoins.pool[1].title.Text=='Bobby' and S.design.lists.serverJoins.pool[1].sub.Text=='@Bob')
M.Players.PlayerAdded:Fire(bob)
check('serveur : evenements dupliques ignores', S.server.count==2 and S.server.joined==1)
M.Players.PlayerRemoving:Fire(bob);bob.Parent=nil;M.run(1)
check('serveur : depart distinct des arrivees', S.server.count==1 and S.server.left==1 and S.server.joined==1)
check('serveur : dernier depart affiche', S.design.lists.serverLeaves.pool[1].title.Text=='Bobby')
for i=1,19 do
    local p=M.new('Player','Player'..i,M.Players,{UserId=1000+i,DisplayName='Joueur '..i});M.Players.PlayerAdded:Fire(p)
end
M.run(1);M.clickNamed('RosterNext')
check('serveur : liste paginee sans perdre les presents', S.server.count==20 and S.design.rosterPage==2 and S.design.widgets.rosterPage.Text=='2 / 3')
M.clickNamed('RosterPrevious')
check('serveur : retour a la premiere page', S.design.rosterPage==1)
local joins=S.server.joined
S.stop();M.Players.PlayerAdded:Fire(M.new('Player','Late',M.Players,{UserId=9090,DisplayName='Tardif'}))
check('serveur : observateurs coupes a la fermeture', M.Players.PlayerAdded:count()==0 and M.Players.PlayerRemoving:count()==0 and S.server.joined==joins)
check('V1.1 : aucune tache en erreur', (M.taskErrors or 0)==0,M.lastTaskError)

-- Pas de creation massive de tweens ni de sauvegarde par pixel de la palette.
M,S=fresh();M.click('Settings');picker=S.design.picker
picker.sv.AbsolutePosition=Vector2.new(100,100);picker.sv.AbsoluteSize=Vector2.new(200,160)
local tweenCount=M.tweenCount;writes=M.writes
down=pointer('MouseButton1',100,100);picker.sv.InputBegan:Fire(down)
for i=1,60 do M.UIS.InputChanged:Fire(pointer('MouseMovement',100+i*3,100+i*2)) end
M.UIS.InputEnded:Fire(down)
check('palette : apercu sans creation de tween par pixel', M.tweenCount==tweenCount,M.tweenCount-tweenCount)
check('palette : aucun enregistrement automatique pendant un mouvement long', M.writes==writes)
picker.sv.InputBegan:Fire(down);S.cancel()
check('palette : STOP libere la capture de couleur', S.design.pointer==nil and picker.hex==S.ui.accent)
M.findTextBox('Nom du profil').Text='Choix';M.click('Enregistrer le profil');M.findTextBox('Nom du profil').Text=''
S.design.lists.profiles.pool[1].root.Activated:Fire()
check('profils : liste cliquable remplit le champ', M.findTextBox('Nom du profil').Text=='Choix')
S.saveSpot('Pont');S.design.refresh()
local beforePosition,beforeMove=M.root.Position,M.moveTarget
S.design.lists.spots.pool[1].root.Activated:Fire()
check('spots : selection visuelle sans deplacement', M.findTextBox('Nom du spot').Text=='Pont' and M.root.Position==beforePosition and M.moveTarget==beforeMove)
check('spots : aucun cycle lance par le clic de liste', not S.cycleRunning)
load(SCRIPT_SOURCE,'=reload-visual')();M.run(0.5)
local newS=M.genv.BlockSpinCycle080
check('rechargement : un seul observateur serveur', M.Players.PlayerAdded:count()==1 and M.Players.PlayerRemoving:count()==1 and not S.running)
check('rechargement : palette restauree depuis les reglages', newS.ui.accent==py_json_decode(M.fs['blockspin-settings-v1.json']).accent)
