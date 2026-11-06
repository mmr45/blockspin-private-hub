-- Cartes et controles V1.2, injectes dans la portee du client.
do
local D,O=S.design,S.observatory
local function report(ok,detail) O.message(ok,detail);S.refreshDashboard() end
local function parent(p) return D.parent(p) end
local function box(p,name,height)
    p=parent(p)
    return make('Frame',{Name=name,BackgroundTransparency=1,Size=UDim2.new(1,0,0,height),LayoutOrder=D.order(p)},p)
end
local function txt(p,value,size,color)
    return make('TextLabel',{BackgroundTransparency=1,Text=value,TextSize=size or 12,Font=Enum.Font.GothamMedium,
        TextColor3=color or theme.text,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,Size=UDim2.new(1,0,0,24)},p)
end
local function timer(n) return Hub.duration(n) end
local function money(n) return isNum(n) and string.format('%.0f $',n) or 'N/D' end
local function stamp(t) return os.date('!%H:%M:%S',math.floor(os.time()-math.max(0,os.clock()-t))) end
local function limited(list,start,count)
    local rows={};for i=start,math.min(#list,start+count-1) do rows[#rows+1]=list[i] end;return rows
end
local function pagination(p,name,step)
    return grid(p,{{'‹ '..name,function() step(-1) end},{name..' ›',function() step(1) end}},34)
end
local function setting(p,label,key)
    toggle(p,function() return label..' : '..(ui[key] and 'oui' or 'non') end,function() ui[key]=not ui[key];saveSettings();D.refresh() end)
end
local function badgeList(id,p,limit,empty) return D.rowList(p,id,limit,empty) end
-- Serveur : enrichit le moniteur de presence existant, sans second comptage.
do
local p=pages.Server
section(p,'Connexion & session')
D.metricsGrid(p,{{id='serverElapsed',label='VOTRE SESSION'},{id='serverFree',label='PLACES LIBRES'},{id='pingMean',label='PING MOYEN'},{id='pingPeak',label='PIC DE PING'}})
D.detail(p,'pingRange','Minimum / médiane','N/D')
D.caption(p,'Durée depuis l’ouverture du hub · historique du ping sur 30 mesures')
D.chart(p,'serverPingChart','Votre connexion')
section(p,'Recherche & joueurs suivis')
local search=textbox(p,'Rechercher un pseudo / username')
connect(search:GetPropertyChangedSignal('Text'),function() O.rosterSearch=search.Text:sub(1,64);D.rosterPage=1 end)
O.rosterOrder='name'
toggle(p,function() return 'Tri des joueurs : '..O.rosterOrder end,function() local nextOrder={name='recent',recent='friends',friends='name'};O.rosterOrder=nextOrder[O.rosterOrder];D.rosterPage=1 end)
setting(p,'Alertes de présence','presenceAlerts');setting(p,'Inclure les amis connus','friendAlerts')
D.caption(p,'Clique un joueur dans la liste pour activer ou retirer son suivi de session.')
D.lists.serverRoster.onSelect=function(row)
    if row.id and row.id~=player.UserId then O.watch[row.id]=not O.watch[row.id];report(true,O.watch[row.id] and 'Joueur suivi pour cette session' or 'Suivi retire') end
end
section(p,'Fil des événements')
O.eventKind='all';O.eventPage=1
toggle(p,function() return 'Événements : '..O.eventKind end,function() local n={all='join',join='leave',leave='all'};O.eventKind=n[O.eventKind];O.eventPage=1 end)
badgeList('serverTimeline',p,8,'Aucun événement depuis l’ouverture')
pagination(p,'Événements',function(n) O.eventPage=math.max(1,(O.eventPage or 1)+n);D.refresh() end)
D.detail(p,'timelinePage','Page','1 / 1')
section(p,'Favoris & bilan local')
local favoriteName=textbox(p,'Nom du serveur favori')
button(p,'Ajouter ce serveur aux favoris',function() report(S.favoriteServer(favoriteName.Text)) end)
badgeList('serverFavorites',p,6,'Aucun favori enregistré').onSelect=function(row)
    O.favoriteSelection=row.index;local v=O.favorites[row.index];if v then favoriteName.Text=v.name;report(S.prepareServerJoin({id=v.job,place=v.place})) end
end
O.favoritePage=1
pagination(p,'Favoris',function(n) O.favoritePage=math.max(1,O.favoritePage+n);D.refresh() end)
button(p,'Retirer le favori sélectionné (confirmer)',function() report(S.removeServerFavorite(O.favoriteSelection,true));O.favoriteSelection=nil end)
button(p,'Sauvegarder favoris / session / timers',function() S.saveObservatory() end)
button(p,'Exporter le bilan de session',function() S.exportSession() end)
badgeList('serverSessions',p,6,'Aucun bilan sauvegardé')
O.sessionPage=1
pagination(p,'Bilans',function(n) O.sessionPage=math.max(1,O.sessionPage+n);D.refresh() end)
D.caption(p,'Sauvegarde locale explicite · 30 bilans maximum · aucun envoi à un tiers')
section(p,'Serveurs publics')
D.badge(p,'publicStatus','Disponibilité','Non chargé')
D.caption(p,'Instantanés publics ; disponibilité à revérifier par Roblox au moment de rejoindre.')
local freeBox=textbox(p,'Places libres minimum (0–100)');freeBox.Text=tostring(ui.serverMinFree)
local populationBox=textbox(p,'Population maximum (1–200)');populationBox.Text=tostring(ui.serverMaxPopulation)
button(p,'Appliquer les filtres serveurs',function()
    local free,max=tonumber(freeBox.Text),tonumber(populationBox.Text)
    if not isNum(free) or free%1~=0 or free<0 or free>100 or not isNum(max) or max%1~=0 or max<1 or max>200 then report(false,'Filtres invalides');return end
    ui.serverMinFree=free;ui.serverMaxPopulation=max;saveSettings();O.publicRows={};O.publicCursor=nil;O.publicStatus='Filtres appliques : actualiser';O.publicPage=1
end)
grid(p,{{'Actualiser les serveurs publics',function() O.publicPage=1;report(S.fetchPublicServers(false)) end},{'Page API suivante',function() O.publicPage=1;report(S.fetchPublicServers(true)) end}})
badgeList('publicServers',p,6,'Aucun serveur public chargé').onSelect=function(row) O.publicSelection=row.server;report(S.prepareServerJoin(row.server)) end
O.publicPage=1
pagination(p,'Liste publique',function(n) O.publicPage=math.max(1,O.publicPage+n);D.refresh() end)
button(p,'Ajouter le serveur public sélectionné aux favoris',function() if not O.publicSelection then report(false,'Choisir un serveur public');return end;report(S.favoriteServer(favoriteName.Text,O.publicSelection)) end)
D.badge(p,'joinTarget','Changement de serveur','Aucune sélection')
button(p,'Confirmer rejoindre le serveur sélectionné',function() report(S.confirmServerJoin()) end)
-- Le rendu normal conserve les listes historiques ; recherche et confidentialite s'y appliquent ensuite.
local original=D.refreshServer
function D.refreshServer()
    original()
    local now=os.clock();local rows={};local roster=Hub.filterRoster(S.server,O.rosterSearch,O.rosterOrder,O.friends)
    local total=math.max(1,math.ceil(#roster/8));D.rosterPage=clamp(D.rosterPage,1,total)
    for i=(D.rosterPage-1)*8+1,math.min(#roster,D.rosterPage*8) do
        local v=roster[i]
        rows[#rows+1]={id=v.id,title=ui.privacy and 'Joueur '..i or v.display,sub=ui.privacy and 'Identité masquée' or '@'..v.name,
            avatarId=not ui.privacy and v.id or nil,badge=v.id==player.UserId and 'VOUS' or (O.watch[v.id] and 'SUIVI' or (O.friends[v.id] and 'AMI' or 'PRÉSENT'))}
    end
    D.lists.serverRoster:set(rows);D.value('rosterPage',D.rosterPage..' / '..total)
    if ui.privacy then
        for _,key in ipairs({'serverJoins','serverLeaves'}) do
            rows={};for i,v in ipairs(S.server:recent(key=='serverJoins' and 'join' or 'leave',6)) do rows[#rows+1]={title='Joueur',sub='Identité masquée',badge=timer(now-v.at)} end;D.lists[key]:set(rows)
        end
    end
    rows={}
    for i=#S.server.events,1,-1 do
        local e=S.server.events[i]
        if O.eventKind=='all' or e.kind==O.eventKind then
            rows[#rows+1]={title=(ui.privacy and 'Joueur' or e.player.display)..(e.kind=='join' and ' · arrivée' or ' · départ'),
                sub=stamp(e.at)..' UTC'..(e.kind=='leave' and (' · présence observée '..timer(e.at-e.player.observed)) or ''),badge=timer(now-e.at)}
        end
    end
    local count=math.max(1,math.ceil(#rows/8));O.eventPage=clamp(O.eventPage,1,count)
    D.lists.serverTimeline:set(limited(rows,(O.eventPage-1)*8+1,8));D.value('timelinePage',O.eventPage..' / '..count)
    local stats=Hub.pingSummary(D.charts.ping.values)
    D.value('pingMean',stats.mean and string.format('%.0f ms',stats.mean) or 'N/D');D.value('pingPeak',stats.max and string.format('%.0f ms',stats.max) or 'N/D')
    D.value('pingRange',stats.min and string.format('%.0f / %.0f ms',stats.min,stats.median) or 'N/D')
    D.value('serverElapsed',timer(now-S.server.started));D.value('serverFree',S.server.maxPlayers and math.max(0,S.server.maxPlayers-S.server.count) or 'N/D')
    D.value('serverJob',ui.privacy and 'Masqué' or game.JobId)
    rows={};for i,v in ipairs(O.favorites) do rows[#rows+1]={index=i,title=ui.privacy and 'Serveur favori '..i or v.name,sub=ui.privacy and 'Identifiant masqué' or v.job,badge='CHOISIR'} end
    O.favoritePage=clamp(O.favoritePage,1,math.max(1,math.ceil(#rows/6)));D.lists.serverFavorites:set(limited(rows,(O.favoritePage-1)*6+1,6))
    rows={};for i=#O.sessions,1,-1 do local v=O.sessions[i];rows[#rows+1]={title=os.date('!%d/%m %H:%M',v.at)..' UTC',sub=timer(v.elapsed)..' · hausses '..money(v.increases),badge='LOCAL'} end
    O.sessionPage=clamp(O.sessionPage,1,math.max(1,math.ceil(#rows/6)));D.lists.serverSessions:set(limited(rows,(O.sessionPage-1)*6+1,6))
    rows={};for i,v in ipairs(O.publicRows) do rows[#rows+1]={server=v,title=ui.privacy and 'Serveur public '..i or v.id,sub=v.playing..' / '..v.maxPlayers..' joueurs',badge=(v.maxPlayers-v.playing)..' libres'} end
    O.publicPage=clamp(O.publicPage,1,math.max(1,math.ceil(#rows/6)));D.lists.publicServers:set(limited(rows,(O.publicPage-1)*6+1,6))
    D.value('publicStatus',O.publicStatus);D.value('joinTarget',O.join and now<=O.join.expires and (ui.privacy and 'Sélection masquée · confirmer' or O.join.id) or 'Aucune sélection')
end
end
-- Cartes de plantation : pool borne, pourcentage et echeance toujours distingues.
do
local p=pages.Farming
section(p,'Mes plantations suivies')
D.metricsGrid(p,{{id='trackedPlants',label='PARCELLES SUIVIES'},{id='readyPlants',label='MATURITÉS OBSERVÉES'}})
D.badge(p,'plantObserver','Lecture agricole','À relier')
D.caption(p,'Suivi à distance sur la map · un timer projeté reste marqué estimé')
local root=box(p,'PlantCards',48)
local empty=txt(root,'Aucune parcelle liée pour le moment',12,theme.muted)
local pool={}
for i=1,6 do
    local c=make('TextButton',{Name='PlantCard'..i,Text='',BackgroundColor3=theme.control,BorderSizePixel=0,Size=UDim2.new(1,0,0,116),Position=UDim2.fromOffset(0,(i-1)*124),Visible=false},root);round(c,10);outline(c)
    local icon=make('Frame',{BackgroundTransparency=1,Size=UDim2.fromOffset(28,30),Position=UDim2.fromOffset(12,12)},c)
    local stem=make('Frame',{BackgroundColor3=Color3.fromRGB(125,210,154),BorderSizePixel=0,Size=UDim2.fromOffset(3,23),Position=UDim2.fromOffset(12,6)},icon);round(stem,2)
    for _,r in ipairs({-35,35}) do local leaf=make('Frame',{BackgroundColor3=Color3.fromRGB(125,210,154),BorderSizePixel=0,Rotation=r,Size=UDim2.fromOffset(15,6),Position=UDim2.fromOffset(r<0 and 1 or 12,8)},icon);round(leaf,4) end
    local title=txt(c,'',13);title.Position=UDim2.fromOffset(52,10);title.Size=UDim2.new(1,-64,0,22)
    local time=txt(c,'',24);time.Position=UDim2.fromOffset(14,40);time.Size=UDim2.new(0.55,-14,0,30)
    local pct=txt(c,'',13,theme.muted);pct.Position=UDim2.new(0.55,0,0,43);pct.Size=UDim2.new(0.45,-14,0,24);pct.TextXAlignment=Enum.TextXAlignment.Right
    local track=make('Frame',{BackgroundColor3=theme.border,BorderSizePixel=0,Size=UDim2.new(1,-28,0,4),Position=UDim2.fromOffset(14,79)},c);round(track,2)
    local fill=make('Frame',{BackgroundColor3=theme.accent,BorderSizePixel=0,Size=UDim2.fromScale(0,1)},track);round(fill,2);D.bind(fill,'BackgroundColor3')
    local status=txt(c,'',9,theme.muted);status.Position=UDim2.fromOffset(14,88);status.Size=UDim2.new(1,-28,0,20)
    pool[i]={root=c,title=title,time=time,pct=pct,fill=fill,status=status}
    connect(c.Activated,function() if O.visiblePlants and O.visiblePlants[i] then O.plantSelection=O.visiblePlants[i].id end end)
end
O.plantPage=1
pagination(p,'Plantations',function(n) O.plantPage=math.max(1,O.plantPage+n);D.refresh() end)
setting(p,'Grouper par type de plante','plantGrouping');setting(p,'Alertes de récolte','plantAlerts')
local threshold=textbox(p,'Alerte avant maturité en secondes (10–600)');threshold.Text=tostring(ui.plantAlertSeconds)
button(p,'Appliquer le délai des alertes',function() local n=tonumber(threshold.Text);if not isNum(n) or n<10 or n>600 then report(false,'Choisir 10 à 600 secondes');return end;ui.plantAlertSeconds=math.floor(n);saveSettings() end)
button(p,'Retirer le suivi sélectionné (confirmer)',function() report(S.removePlantTracking(O.plantSelection,true));O.plantSelection=nil end)
section(p,'Relier mes affichages de croissance')
D.caption(p,'Près de vos plantes, rechercher leurs temps et pourcentages réellement affichés.')
button(p,'Rechercher les affichages temps / pourcentage',function() report(S.discoverPlantSources()) end)
button(p,'Exporter le diagnostic agricole',function() S.exportPlantDiagnostic() end)
D.detail(p,'plantScanStatus','Sources visibles','Non recherché')
badgeList('plantSources',p,6,'Aucune paire temps / pourcentage trouvée').onSelect=function(row) O.plantSourceSelection=row.index end
O.sourcePage=1
pagination(p,'Sources agricoles',function(n) O.sourcePage=math.max(1,O.sourcePage+n);D.refresh() end)
local id=textbox(p,'Nom unique de ma parcelle');local crop=textbox(p,'Type de ma plante')
button(p,'Lier la source choisie à ma parcelle (je confirme)',function() report(S.bindPlantSource(O.plantSourceSelection,id.Text,crop.Text,true)) end)
D.caption(p,'Cette confirmation identifie votre parcelle ; elle ne plante et ne récolte rien.')
function O.refreshPlants()
    local now=os.clock();local rows=O.plants:rows(now,O.rootPosition(),ui.plantGrouping);local ready=0
    for _,v in ipairs(rows) do if v.ready and not v.estimated then ready=ready+1 end end
    D.value('trackedPlants',#rows);D.value('readyPlants',ready);D.value('plantObserver',O.plantProvider and 'Lecteur configuré' or (next(O.bindings) and 'Affichages liés' or 'À relier'))
    O.plantPage=clamp(O.plantPage,1,math.max(1,math.ceil(#rows/6)));O.visiblePlants=limited(rows,(O.plantPage-1)*6+1,6)
    empty.Visible=#rows==0;root.Size=UDim2.new(1,0,0,#rows==0 and 48 or #O.visiblePlants*124-8)
    for i,c in ipairs(pool) do
        local v=O.visiblePlants[i];c.root.Visible=v~=nil
        if v then
            c.title.Text=v.crop..' · '..v.id;c.time.Text=v.ready and not v.estimated and 'Prête' or (v.remaining==0 and 'À vérifier' or timer(v.remaining))
            c.pct.Text=string.format('%s%.0f %%',v.estimated and '~ ' or '',v.estimated and v.projectedPercent or v.percent)
            D.animate(c.fill,0.3,{Size=UDim2.fromScale((v.estimated and v.projectedPercent or v.percent)/100,1)})
            c.status.Text=v.status..' · lecture il y a '..timer(v.age)..(v.distance and string.format(' · %.0f studs',v.distance) or '')
            c.root.BackgroundColor3=O.plantSelection==v.id and theme.surface or theme.control
        end
    end
    rows={};for i,v in ipairs(O.candidates) do rows[#rows+1]={index=i,title=timer(v.seconds)..' · '..v.pct..' %',sub=v.path,badge=O.plantSourceSelection==i and 'CHOISI' or 'CHOISIR'} end
    O.sourcePage=clamp(O.sourcePage,1,math.max(1,math.ceil(#rows/6)));D.lists.plantSources:set(limited(rows,(O.sourcePage-1)*6+1,6));D.value('plantScanStatus',O.scanStatus or 'Non recherché')
end
end
-- Apercu top-down des seules donnees enregistrees par l'utilisateur.
do
local p=pages.Vehicle
section(p,'Carte de mes repères')
D.caption(p,'Vue X/Z de vos spots, parcelles liées et trajet sélectionné · aucune téléportation')
local root=box(p,'RecordedMap',250);root.BackgroundColor3=theme.background;round(root,9);outline(root)
local status=txt(root,'Choisir un trajet ou un repère',10,theme.muted);status.Position=UDim2.fromOffset(12,220);status.Size=UDim2.new(1,-24,0,26)
local plot=make('Frame',{Name='MapPlot',BackgroundTransparency=1,ClipsDescendants=true,Position=UDim2.fromOffset(12,12),Size=UDim2.new(1,-24,1,-50)},root)
for i=1,4 do make('Frame',{BackgroundColor3=theme.border,BackgroundTransparency=0.5,BorderSizePixel=0,Size=UDim2.new(1,0,0,1),Position=UDim2.fromScale(0,i/5)},plot) end
local marks={};for i=1,101 do
    local b=make('TextButton',{Name='MapMarker',Text='•',TextSize=24,Font=Enum.Font.GothamBold,TextColor3=theme.accent,BackgroundTransparency=1,Size=UDim2.fromOffset(24,24),AnchorPoint=Vector2.new(0.5,0.5),Visible=false},plot)
    marks[i]=b
    connect(b.Activated,function()
        local r=O.mapRows and O.mapRows[i];if not r then return end
        status.Text=r.title
        if r.kind=='spot' then report(S.selectSpot(r.title)) elseif r.kind=='plant' then O.plantSelection=r.title end
    end)
end
local dots={};for i=1,160 do dots[i]=make('Frame',{Name='RoutePoint',BorderSizePixel=0,BackgroundColor3=theme.accent,Size=UDim2.fromOffset(3,3),Visible=false},plot);round(dots[i],2);D.bind(dots[i],'BackgroundColor3') end
local routeBox=textbox(p,'Destination à prévisualiser')
button(p,'Afficher ce trajet sur la carte',function() local n=Hub.normalizeName(routeBox.Text);if not S.hub.library.routes[n] then report(false,'Destination inconnue');return end;O.mapRoute=n;status.Text=n;D.refresh() end)
function O.refreshMap()
    local rows,route={},S.hub.library.routes[O.mapRoute] or {}
    for n,v in pairs(S.hub.library.spots) do rows[#rows+1]={kind='spot',title=n,x=v.cf[1],z=v.cf[3]} end
    for n,v in pairs(O.plants.plots) do if v.position then rows[#rows+1]={kind='plant',title=n,x=v.position[1],z=v.position[3]} end end
    table.sort(rows,function(a,b) return a.kind==b.kind and a.title<b.title or a.kind<b.kind end)
    local pos=O.rootPosition();if pos then rows[#rows+1]={kind='self',title='Vous',x=pos[1],z=pos[3]} end
    local minx,maxx,minz,maxz=math.huge,-math.huge,math.huge,-math.huge
    local function bound(x,z) minx=math.min(minx,x);maxx=math.max(maxx,x);minz=math.min(minz,z);maxz=math.max(maxz,z) end
    for _,v in ipairs(rows) do bound(v.x,v.z) end;for _,v in ipairs(route) do bound(v[1],v[3]) end
    local span=math.max(20,maxx-minx,maxz-minz);local function point(x,z) return UDim2.fromScale(0.08+(x-minx)/span*0.84,0.08+(z-minz)/span*0.84) end
    O.mapRows=rows
    for i,b in ipairs(marks) do local r=rows[i];b.Visible=r~=nil;if r then b.Position=point(r.x,r.z);b.Text=r.kind=='self' and '◇' or (r.kind=='plant' and '♧' or '•');b.TextColor3=r.kind=='self' and theme.text or theme.accent end end
    local count=math.min(160,#route)
    for i,d in ipairs(dots) do d.Visible=i<=count;if i<=count then local index=count==1 and 1 or math.floor((i-1)*(#route-1)/(count-1))+1;d.Position=point(route[index][1],route[index][3]) end end
end
end
-- File d'activites : etapes verifiees, aucun auto-retry non borne.
do
local p=pages.Statistics
section(p,'File d’activités')
D.badge(p,'queueStatus','État de la file','Prête');D.gauge(p,'queueRemaining','Délai de l’étape')
local destination=textbox(p,'Destination pour une étape de conduite')
local timeout=textbox(p,'Délai maximal en secondes (1–1800)');timeout.Text='600'
local function append(kind) report(S.addQueueStep(kind,destination.Text,tonumber(timeout.Text))) end
grid(p,{{'Ajouter un trajet',function() append('route') end},{'Ajouter vente / ATM / retour',function() append('cycle') end},{'Attendre mes plantes prêtes',function() append('plants') end},{'Ajouter une pause',function() append('pause') end}})
badgeList('automationQueue',p,6,'Aucune étape préparée')
O.queuePage=1
pagination(p,'Étapes',function(n) O.queuePage=math.max(1,O.queuePage+n);D.refresh() end)
grid(p,{{'Démarrer la file',function() report(S.startQueue()) end},{'Arrêter la file',S.cancel},{'Retirer la dernière étape',function() if O.queueRunning then report(false,'Arrêter la file avant de modifier');return end;table.remove(O.queue) end}})
section(p,'Étapes & preuves')
D.detail(p,'stepName','Étape active','Aucune');D.detail(p,'stepRemaining','Délai restant','—')
badgeList('stepHistory',p,6,'Aucune étape exécutée')
badgeList('queueHistory',p,6,'Aucune étape de file terminée')
D.metricsGrid(p,{{id='observedNet',label='VARIATION NETTE OBSERVÉE'},{id='observedGross',label='HAUSSES DU COMPTEUR'}})
D.caption(p,'Variation nette = hausses − baisses observées ; ce n’est pas un bénéfice commercial.')
end
-- Reglages : themes nommes, import/export JSON et organisation des cartes.
do
local p=pages.Settings
section(p,'Mes couleurs & thèmes')
local themeName=textbox(p,'Nom du thème couleur')
local themeList=badgeList('savedThemes',p,6,'Aucun thème couleur sauvegardé')
O.themePage=1
pagination(p,'Thèmes couleur',function(n) O.themePage=math.max(1,O.themePage+n);D.refresh() end)
themeList.onSelect=function(row) themeName.Text=row.title;ui.accent=row.hex;S.applyAccent(row.hex);D.picker.sync(row.hex);saveSettings() end
grid(p,{{'Enregistrer mon thème couleur',function()
    local n=Hub.normalizeName(themeName.Text);if not Hub.validName(n) then report(false,'Nom de thème invalide');return end
    local count=0;for _ in pairs(ui.savedThemes) do count=count+1 end;if not ui.savedThemes[n] and count>=12 then report(false,'12 thèmes maximum');return end
    ui.savedThemes[n]=ui.accent;saveSettings();D.refresh()
end},{'Retirer ce thème couleur (confirmer)',function() local n=Hub.normalizeName(themeName.Text);if n then ui.savedThemes[n]=nil;saveSettings() end end}})
badgeList('recentColors',p,8,'Aucune couleur récente').onSelect=function(row) ui.accent=row.hex;S.applyAccent(row.hex);D.picker.sync(row.hex);saveSettings() end
section(p,'Confidentialité & mini-dashboard')
setting(p,'Masquer les identités affichées','privacy');setting(p,'Mini-dashboard flottant','miniDashboard')
D.caption(p,'Le mode confidentialité masque aussi les identités dans les exports de session.')
section(p,'Organisation des cartes')
D.protectedCards=D.protectedCards or {};D.protectedCards[D.pages[p].current]=true
O.layoutPage='Statistics';O.layoutListPage=1
toggle(p,function() return 'Page à personnaliser : '..O.layoutPage end,function()
    local names={'Statistics','Server','Farming','Fishing','Vehicle','Money','Settings'};for i,n in ipairs(names) do if n==O.layoutPage then O.layoutPage=names[i%#names+1];break end end;O.layoutListPage=1
end)
badgeList('layoutCards',p,6,'Aucune carte').onSelect=function(row) O.cardSelection=row.key;D.value('selectedCard',row.title) end
pagination(p,'Cartes',function(n) O.layoutListPage=math.max(1,O.layoutListPage+n);D.refresh() end)
D.detail(p,'selectedCard','Carte sélectionnée','Aucune')
function S.configureCard(key,change)
    local selected,index,meta
    for _,m in pairs(D.pages) do for i,c in ipairs(m.cards) do if D.cardKeys[c]==key then selected=c;index=i;meta=m end end end
    if not selected or type(change)~='table' then return false,'Carte inconnue' end
    local value=Hub.copy(ui.cardLayouts[key] or {rank=index,hidden=false,wide=false})
    if change.hidden~=nil then if D.protectedCards[selected] then return false,'Cette carte garde les reglages accessibles' end;value.hidden=change.hidden==true end
    if change.wide~=nil then value.wide=change.wide==true end
    if change.direction then
        local ordered={};for i,c in ipairs(meta.cards) do ordered[#ordered+1]={key=D.cardKeys[c],index=i} end
        table.sort(ordered,function(a,b) local x,y=ui.cardLayouts[a.key],ui.cardLayouts[b.key];local ar,br=x and x.rank or a.index,y and y.rank or b.index;return ar==br and a.index<b.index or ar<br end)
        local position;for i,v in ipairs(ordered) do if v.key==key then position=i end end
        local target=clamp(position+(change.direction<0 and -1 or 1),1,#ordered);ordered[position],ordered[target]=ordered[target],ordered[position]
        for i,v in ipairs(ordered) do local old=ui.cardLayouts[v.key] or {hidden=false,wide=false};old.rank=i;ui.cardLayouts[v.key]=old;if v.key==key then value.rank=i end end
    end
    ui.cardLayouts[key]=value;saveSettings();D.layout();return true,'Organisation enregistree'
end
grid(p,{{'Monter la carte',function() report(S.configureCard(O.cardSelection,{direction=-1})) end},{'Descendre la carte',function() report(S.configureCard(O.cardSelection,{direction=1})) end},{'Masquer / afficher la carte',function() local v=ui.cardLayouts[O.cardSelection] or {};report(S.configureCard(O.cardSelection,{hidden=not v.hidden})) end},{'Largeur simple / complète',function() local v=ui.cardLayouts[O.cardSelection] or {};report(S.configureCard(O.cardSelection,{wide=not v.wide})) end}})
button(p,'Réinitialiser uniquement la disposition des cartes',function() ui.cardLayouts={};saveSettings();D.layout() end)
section(p,'Transférer mes réglages')
local importBox=textbox(p,'Coller ici un export JSON de réglages')
button(p,'Exporter mes réglages en JSON',function()
    local prefs={};for _,k in ipairs(PREF_KEYS) do prefs[k]=Hub.copy(ui[k]) end
    -- Source GUI locale omise : un autre joueur peut avoir une hierarchie differente.
    prefs.moneySourcePath=nil
    local raw=HttpService:JSONEncode({schema=1,prefs=prefs})
    if type(setclipboard)=='function' then report(pcall(setclipboard,raw),'Export des reglages vers le presse-papiers') else importBox.Text=raw;report(true,'Export affiche dans le champ JSON') end
end)
button(p,'Importer les réglages JSON (appliquer)',function()
    local raw=importBox.Text
    if #raw>32768 then report(false,'Export trop grand');return end
    local ok,data=pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok or type(data)~='table' or data.schema~=1 or type(data.prefs)~='table' then report(false,'JSON de reglages invalide');return end
    local allowed={};for _,k in ipairs(PREF_KEYS) do if k~='moneySourcePath' then allowed[k]=data.prefs[k] end end
    readPrefs(allowed,ui);applyPrefs();saveSettings();report(true,'Reglages reconnus appliques ; aucune activite lancee')
end)
button(p,'Restaurer l’apparence par défaut',function()
    ui.accent='FF475C';ui.scale=1;ui.density='normal';ui.animations=true;ui.cardLayouts={};ui.size={x=960,y=640};ui.position=nil
    applyPrefs();saveSettings();report(true,'Apparence restauree ; bibliotheque et observations conservees')
end)
section(p,'Sources & connexions')
for _,v in ipairs({{'diagMoney','Portefeuille'},{'diagAim','Visée de pêche'},{'diagPlant','Suivi des plantes'},{'diagFarm','Actions agricoles'},{'diagPublic','Liste de serveurs'},{'diagFiles','Sauvegarde locale'}}) do D.badge(p,v[1],v[2],'À vérifier') end
D.caption(p,'Les branchements et validations restant à faire sont détaillés dans CONFIGURATION.md du dépôt.')
end
-- Les cartes de suivi passent avant les actions agricoles non configurees.
do
    local meta=D.pages[pages.Farming]
    if #meta.cards==3 then meta.cards={meta.cards[2],meta.cards[3],meta.cards[1]} end
end
-- Mini-dashboard : deplacable, STOP propre, aucune nouvelle touche clavier.
do
local mini=make('Frame',{Name='MiniDashboard',BackgroundColor3=theme.background,BorderSizePixel=0,Size=UDim2.fromOffset(248,160),Position=UDim2.new(1,-270,0,120),Visible=ui.miniDashboard,Active=true,ZIndex=18},gui);round(mini,12);outline(mini)
local heading=txt(mini,'SESSION EN DIRECT',10,theme.muted);heading.Position=UDim2.fromOffset(14,8);heading.Size=UDim2.new(1,-28,0,22)
local activity=txt(mini,'Prêt',16);activity.Position=UDim2.fromOffset(14,34);activity.Size=UDim2.new(1,-28,0,24)
local gains=txt(mini,'',11,theme.muted);gains.Position=UDim2.fromOffset(14,64);gains.Size=UDim2.new(1,-28,0,20)
local plant=txt(mini,'',11,theme.muted);plant.Position=UDim2.fromOffset(14,87);plant.Size=UDim2.new(1,-28,0,20)
local stop=button(mini,'STOP',S.cancel,30);stop.Position=UDim2.fromOffset(14,118);stop.Size=UDim2.fromOffset(100,30);stop.BackgroundColor3=theme.danger
local open=button(mini,'Ouvrir le hub',function() S.setMenuVisible(true) end,30);open.Position=UDim2.fromOffset(122,118);open.Size=UDim2.fromOffset(112,30)
local drag
connect(mini.InputBegan,function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then drag={input=input,start=input.Position,pos=mini.AbsolutePosition or Vector2.new(0,0)} end end)
connect(UIS.InputChanged,function(input)
    if not drag then return end
    if drag.input.UserInputType==Enum.UserInputType.Touch and input~=drag.input then return end
    if drag.input.UserInputType~=Enum.UserInputType.Touch and input.UserInputType~=Enum.UserInputType.MouseMovement then return end
    local v=viewportSize();mini.Position=UDim2.fromOffset(clamp(drag.pos.X+input.Position.X-drag.start.X,0,math.max(0,v.X-248)),clamp(drag.pos.Y+input.Position.Y-drag.start.Y,0,math.max(0,v.Y-160)))
end)
connect(UIS.InputEnded,function(input) if drag and (input==drag.input or input.UserInputType==Enum.UserInputType.MouseButton1) then drag=nil end end)
connect(UIS.WindowFocusReleased,function() drag=nil end)
function O.refreshMini()
    mini.Visible=ui.miniDashboard;activity.Text=D.stateText(S.state,'')
    local m=S.hub.money;gains.Text=timer(os.clock()-S.hub.started)..' · hausses '..money(m.observedIncreases)
    local rows=O.plants:rows(os.clock());local first=rows[1]
    plant.Text=first and (first.id..' · '..timer(first.remaining)..(first.estimated and ' estimé' or ' observé')) or 'Aucune plantation suivie'
end
end
function D.refreshInsights()
    O.refreshPlants();O.refreshMap();O.refreshMini()
    local now=os.clock();local rows={}
    for i,v in ipairs(O.queue) do rows[#rows+1]={title=i..' · '..v.kind,sub=v.name or 'Étape vérifiée',badge=O.queueRunning and O.queueIndex==i and 'EN COURS' or timer(v.timeout)} end
    O.queuePage=clamp(O.queuePage,1,math.max(1,math.ceil(#rows/6)));D.lists.automationQueue:set(limited(rows,(O.queuePage-1)*6+1,6))
    D.value('queueStatus',O.queueStatus)
    local current=O.queueRunning and O.queue[O.queueIndex]
    local remaining=O.queueDeadline and math.max(0,O.queueDeadline-now) or 0
    D.setGauge('queueRemaining',current and timer(remaining) or 'Aucune étape active',current and remaining/current.timeout or 0)
    local step=S.hub.current;D.value('stepName',step and step.name or 'Aucune');D.value('stepRemaining',step and timer(step.deadline-now) or '—')
    rows={};for i=#S.hub.history,math.max(1,#S.hub.history-5),-1 do local v=S.hub.history[i];rows[#rows+1]={title=v.name,sub=v.detail,badge=v.ok and 'VÉRIFIÉ' or 'ÉCHEC'} end;D.lists.stepHistory:set(rows)
    rows={};for i=#O.queueHistory,math.max(1,#O.queueHistory-5),-1 do local v=O.queueHistory[i];rows[#rows+1]={title=v.kind,sub=v.detail,badge=v.ok and 'VÉRIFIÉ' or 'ÉCHEC'} end;D.lists.queueHistory:set(rows)
    D.value('observedNet',money(S.hub.money.observedIncreases-S.hub.money.observedDecreases));D.value('observedGross',money(S.hub.money.observedIncreases))
    rows={};for n,h in pairs(ui.savedThemes) do rows[#rows+1]={title=n,sub='#'..h,hex=h,badge='APPLIQUER'} end;table.sort(rows,function(a,b) return a.title<b.title end)
    O.themePage=clamp(O.themePage,1,math.max(1,math.ceil(#rows/6)));D.lists.savedThemes:set(limited(rows,(O.themePage-1)*6+1,6))
    rows={};for _,h in ipairs(ui.recentColors) do rows[#rows+1]={title='#'..h,hex=h,badge='APPLIQUER'} end;D.lists.recentColors:set(rows)
    rows={};for _,m in pairs(D.pages) do if m.name==O.layoutPage then for _,c in ipairs(m.cards) do local key=D.cardKeys[c];local v=ui.cardLayouts[key] or {};rows[#rows+1]={key=key,title=c:FindFirstChild('CardTitle').Text,sub=v.wide and 'Largeur complète' or 'Largeur simple',badge=v.hidden and 'MASQUÉE' or 'VISIBLE'} end end end
    O.layoutListPage=clamp(O.layoutListPage,1,math.max(1,math.ceil(#rows/6)));D.lists.layoutCards:set(limited(rows,(O.layoutListPage-1)*6+1,6))
    D.value('diagMoney',S.moneyReading and S.moneyReading.available and 'Lecture active' or 'À relier / afficher')
    D.value('diagAim',S.baitScreenPoint and 'Capturée · à valider' or 'À capturer')
    D.value('diagPlant',O.plantProvider and 'Lecteur configuré' or (next(O.bindings) and 'Affichages liés' or 'À relier'))
    D.value('diagFarm',S.hub.farm.available and 'Adaptateur fourni' or 'Adaptateur manquant')
    D.value('diagPublic',O.publicStatus);D.value('diagFiles',type(writefile)=='function' and 'API présente · écriture explicite' or 'Indisponible')
    D.displayName.Text=ui.privacy and 'Profil masqué' or tostring(player.DisplayName or player.Name)
    D.username.Text=ui.privacy and 'Confidentialité' or '@'..tostring(player.Name)
    D.profile:FindFirstChild('AvatarHolder').Visible=not ui.privacy
end
end
