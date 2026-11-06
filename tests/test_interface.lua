-- Contrat UI dans la maquette : pas une validation du rendu Roblox.
local Car=load(CAR_SOURCE,'=car')()
local function fresh(options)
    options=options or {}
    local M=load(MOCK_SOURCE,'=ui-mock')()
    M.setCar(Car.new(-350.97,844.32,20));M.setRoot(Vector3.new(-334.87,254.78,836.06))
    M.thumbnailLoaded=options.thumbnailLoaded;M.thumbnailFail=options.thumbnailFail;M.thumbnailReady=options.thumbnailReady;M.thumbnailWait=options.thumbnailWait
    if options.settings then M.fs['blockspin-settings-v1.json']=py_json_encode(options.settings) end
    if options.name then M.player.Name=options.name end
    if options.displayName then M.player.DisplayName=options.displayName end
    load(SCRIPT_SOURCE,'=ui-client')()
    M.run(0.4)
    return M,M.genv.BlockSpinCycle080
end
local M,S=fresh({name='Test_User',displayName='Le Joueur'})
local profile=M.ourGui():FindFirstChild('RobloxProfile',true)
local avatar=profile:FindFirstChild('RobloxAvatar',true)
check('UI profil : display name reel', profile:FindFirstChild('DisplayName').Text=='Le Joueur')
check('UI profil : username reel', profile:FindFirstChild('Username').Text=='@Test_User')
check('UI profil : API officielle et bon UserId', M.thumbnailUserId==M.player.UserId and M.thumbnailCalls==1)
check('UI profil : miniature prete affichee', avatar.Visible and avatar.Image:find(tostring(M.player.UserId),1,true)~=nil)
check('UI profil : placeholder masque apres succes', not profile:FindFirstChild('AvatarPlaceholder',true).Visible)
check('UI profil : noms longs tronques sans champ editable', profile:FindFirstChild('DisplayName').TextTruncate==Enum.TextTruncate.AtEnd)
check('UI : barre laterale et contenu separes', S.design.sidebar.Parent==S.window and S.design.content.Parent==S.window)
check('UI : icones des sept onglets', #S.design.navItems==7 and S.design.navItems[1].icon~=nil)
check('UI : accent rouge par defaut', S.ui.accent=='FF475C')
local cards=S.design.pages[M.ourGui():FindFirstChild('Fishing',true)].cards
local visible={};for _,card in ipairs(cards) do if card.Visible then visible[#visible+1]=card end end
check('UI : cartes en deux colonnes', #visible>=2 and visible[1].Position.X.Scale==0 and visible[2].Position.X.Scale==0.5)
check('UI : journal correctement deplace dans Statistics', M.ourGui():FindFirstChild('Fishing',true):FindFirstChild('CardTitle',true).Text=='Automatisation')
local row=S.design.rows[1]
check('UI : interrupteur visuel actif', row.track.Visible and row.knob.Position.X.Offset==19)
M.click('[ON]  Peche automatique')
check('UI : interrupteur visuel desactive', row.knob.Position.X.Offset==3 and not S.fishingEnabled)
M.click('Poisson rare')
local enumRow
for _,entry in ipairs(S.design.rows) do if entry.button.Text:find('^Poisson rare :') then enumRow=entry end end
check('UI : selecteur distinct d\'un interrupteur', enumRow and not enumRow.track.Visible and enumRow.value.Text=='quitter le serveur')
for i=1,4 do M.click('Statistics');M.click('Settings');M.click('Fishing') end
check('UI transitions : contenu visible apres changements repetes', S.design.content.GroupTransparency==0)
local selected=0
for _,item in ipairs(S.design.navItems) do if item.mark.Visible then selected=selected+1 end end
check('UI navigation : un seul onglet actif', selected==1 and S.design.active=='Fishing')
local pending=0;for _ in pairs(S.design.tweens) do pending=pending+1 end
check('UI transitions : tweens termines retires du registre', pending==0,pending)

-- Un ancien callback de fermeture ne doit jamais masquer une reouverture recente.
M.deferTweens=true
M.clickNamed('Minimize');M.run(0.06)
M.clickNamed('OpenHub');M.run(0.4)
check('UI transitions : reouverture rapide conservee', S.window.Visible and S.design.menuVisible and S.window.GroupTransparency==0)
M.press('RightShift');M.press('RightShift');M.run(0.4)
check('UI transitions : touches rapides sans masquage tardif', S.window.Visible and S.design.menuVisible)
M.clickNamed('Minimize');M.run(0.3)
check('UI reduction : menu masque et lanceur visible', not S.window.Visible and S.design.launcher.Visible)
check('UI reduction : STOP reste accessible', M.ourGui():FindFirstChild('EmergencyStop').Visible)
M.clickNamed('OpenHub');M.run(0.3)
check('UI reduction : bouton de reouverture fonctionnel', S.window.Visible and not S.design.launcher.Visible)
M.click('Animations :');M.run(0.3)
local tweenCount=M.tweenCount
M.click('Money');M.click('Fishing');M.clickNamed('Minimize')
check('UI sans animation : fermeture immediate', not S.window.Visible and not S.ui.animations)
M.clickNamed('OpenHub')
check('UI sans animation : aucune nouvelle interpolation', M.tweenCount==tweenCount)

-- La meme disposition est recalculee a chaque echelle/taille, sans recréer le profil.
S.window.Size=UDim2.fromOffset(560,520);S.design.refresh()
check('UI compacte : barre laterale reduite', S.design.sidebarWidth==72 and not S.design.username.Visible)
check('UI compacte : avatar toujours visible', profile.Visible and avatar.Visible)
check('UI compacte : cartes empilees', visible[2].Position.X.Scale==0 and visible[2].Position.Y.Offset>=visible[1].Size.Y.Offset)
check('UI compacte : contenu dans la fenetre', S.design.content.Position.X.Offset+S.design.content.Size.X.Offset+S.window.Size.X.Offset<=S.window.Size.X.Offset)
S.window.Size=UDim2.fromOffset(960,640);S.design.refresh()
check('UI agrandie : identite et colonnes restaurees', S.design.username.Visible and visible[2].Position.X.Scale==0.5)
M.clickNamed('Couleur5EC8FF')
check('UI accent : avatar/lanceur/navigation recolores', S.design.launcher.TextColor3.B==1 and S.design.navItems[1].mark.BackgroundColor3.B==1)

M,S=fresh({thumbnailFail=true});M.run(4)
profile=M.ourGui():FindFirstChild('RobloxProfile',true)
check('UI avatar : echec reseau avec placeholder', profile:FindFirstChild('AvatarPlaceholder',true).Visible and not profile:FindFirstChild('RobloxAvatar',true).Visible)
check('UI avatar : essais bornes, pas de tache en erreur', M.thumbnailCalls==3 and (M.taskErrors or 0)==0)
M,S=fresh({thumbnailReady=false});M.run(4)
check('UI avatar : miniature non prete non affichee', not M.ourGui():FindFirstChild('RobloxAvatar',true).Visible and M.thumbnailCalls==3)
M,S=fresh({thumbnailWait=2});S.stop();M.run(3)
check('UI avatar : resultat tardif apres fermeture ignore', M.ourGui()==nil and not S.running and (M.taskErrors or 0)==0)
M,S=fresh({settings={schema=1,accent='00AAFF',size={x=430,y=500},hotkey='RightShift'}})
check('UI migration : ancien format par defaut agrandi', S.window.Size.X.Offset==960 and S.ui.accent=='00AAFF')
M,S=fresh({settings={schema=1,accent='00AAFF',size={x=700,y=540},hotkey='RightShift'}})
check('UI migration : geometrie personnalisee conservee', S.window.Size.X.Offset==700 and S.window.Size.Y.Offset==540)
M.deferTweens=true;M.click('Money');S.stop();M.run(1)
local entries=0;for _ in pairs(S.design.tweens) do entries=entries+1 end
check('UI fermeture : animations annulees et registre vide', entries==0 and S.design.closed and M.ourGui()==nil)
check('UI fermeture : aucune erreur de tache', (M.taskErrors or 0)==0,M.lastTaskError)

M,S=fresh()
workspace.CurrentCamera.ViewportSize=Vector2.new(480,420)
workspace.CurrentCamera:GetPropertyChangedSignal('ViewportSize'):Fire()
check('UI viewport : fenetre bornee apres changement de resolution', S.window.Size.X.Offset<=480 and S.window.Size.Y.Offset<=420)
check('UI viewport : mode compact recalcule automatiquement', S.design.sidebarWidth==72)
local oldCamera=workspace.CurrentCamera
local newCamera=M.new('Camera','OtherCamera',workspace,{ViewportSize=Vector2.new(800,600)})
workspace.CurrentCamera=newCamera;workspace:GetPropertyChangedSignal('CurrentCamera'):Fire()
check('UI viewport : ancienne camera deconnectee', oldCamera:GetPropertyChangedSignal('ViewportSize'):count()==0)
check('UI viewport : nouvelle camera observee', newCamera:GetPropertyChangedSignal('ViewportSize'):count()==1)
S.stop()
check('UI viewport : observateurs coupes a la fermeture', newCamera:GetPropertyChangedSignal('ViewportSize'):count()==0)
M,S=fresh({settings={schema=1,accent='00AAFF',size={x=430,y=500},layoutVersion=2,hotkey='RightShift'}})
check('UI migration : taille compacte choisie dans le nouveau design conservee', S.window.Size.X.Offset==430)

M,S=fresh({thumbnailLoaded=false})
check('UI avatar : placeholder conserve pendant le chargement image', M.ourGui():FindFirstChild('AvatarPlaceholder',true).Visible)
M.run(6)
check('UI avatar : image non chargee abandonnee apres delai', not M.ourGui():FindFirstChild('RobloxAvatar',true).Visible and M.ourGui():FindFirstChild('AvatarPlaceholder',true).Visible)
