-- Services de l'observatoire. Injectes par build.py, sans code distant ni secret.
do
local O={friends={},friendKnown={},watch={},candidates={},bindings={},sessions={},favorites={},publicRows={},publicStatus='Non charge',queue={},queueHistory={},queueStatus='Prete'}
S.observatory=O
local job=type(game.JobId)=='string' and game.JobId or ''
local place=isNum(game.PlaceId) and game.PlaceId or 0
O.serverKey=tostring(place)..':'..job
O.plants=Hub.newPlants(O.serverKey)
local file='blockspin-observatory-v1.json'
local writable=true
local started=os.time()
local sessionId=tostring(started)..'-'..tostring(math.floor(os.clock()*1000))
local function message(ok,detail)
    logLine(detail or (ok and 'Operation terminee' or 'Operation impossible'))
    if S.toast then S.toast(detail or (ok and 'Termine' or 'Impossible'),ok and 'ok' or 'warn') end
    return ok,detail
end
O.message=message
local function rootPosition()
    local r=getRoot();local p=r and r.Position
    return p and {p.X,p.Y,p.Z} or nil
end
O.rootPosition=rootPosition
local function unavailable(detail)
    O.lastError=tostring(detail):sub(1,300);S.hub:error('Observatoire',O.lastError,os.clock())
end
local function readWorkspace()
    if type(readfile)~='function' or type(isfile)~='function' or not isfile(file) then return true end
    local ok,value=pcall(function()
        local raw=readfile(file);assert(type(raw)=='string' and #raw<=262144,'fichier trop grand')
        local data,err=Hub.validWorkspace(HttpService:JSONDecode(raw));assert(data,err);return data
    end)
    if not ok then writable=false;unavailable('Fichier observatoire preserve : '..tostring(value));return false end
    O.favorites=value.favorites;O.sessions=value.sessions
    if value.serverKey==O.serverKey and job~='' then
        for _,v in ipairs(value.plants) do
            local elapsed=math.max(0,os.time()-v.savedAt)
            O.plants:observe({serverKey=O.serverKey,id=v.id,crop=v.crop,remaining=math.max(0,v.remaining-elapsed),percent=v.percent,owned=true,position=v.position},os.clock())
            local p=O.plants.plots[v.id];p.restored=true;p.ready=false
        end
    end
    return true
end
readWorkspace()
function S.saveObservatory()
    if not writable then return message(false,'Fichier illisible preserve : aucune sauvegarde') end
    if job=='' or place<1 then return message(false,'Identite serveur indisponible') end
    if type(writefile)~='function' then return message(false,'Sauvegarde locale indisponible') end
    local sessions=Hub.copy(O.sessions)
    local entry={id=sessionId,elapsed=math.max(0,os.clock()-S.hub.started),at=started,place=place,job=job,
        increases=S.hub.money.observedIncreases,decreases=S.hub.money.observedDecreases}
    local replaced=false
    for i,v in ipairs(sessions) do if v.id==sessionId then sessions[i]=entry;replaced=true end end
    if not replaced then sessions[#sessions+1]=entry end
    while #sessions>30 do table.remove(sessions,1) end
    local plants={}
    for _,v in ipairs(O.plants:rows(os.clock())) do
        plants[#plants+1]={id=v.id,crop=v.crop,remaining=v.remaining,percent=v.projectedPercent,position=v.position,savedAt=os.time()}
    end
    local data={schema=1,serverKey=O.serverKey,favorites=Hub.copy(O.favorites),sessions=sessions,plants=plants}
    local valid,err=Hub.validWorkspace(data);if not valid then return message(false,err) end
    local ok,why=pcall(function() local raw=HttpService:JSONEncode(valid);assert(#raw<=262144,'fichier trop grand');writefile(file,raw) end)
    if ok then O.sessions=sessions else unavailable(why) end
    return message(ok,ok and 'Favoris, bilan et timers sauvegardes localement' or tostring(why))
end
function S.favoriteServer(name,selected)
    local j,p=job,place
    if selected then j,p=selected.id,selected.place or place end
    name=Hub.normalizeName(name)
    local data={schema=1,serverKey=O.serverKey,favorites={{job=j,place=p,name=name}},sessions={},plants={}}
    local valid=Hub.validWorkspace(data)
    if not valid then return false,'Nom ou serveur invalide' end
    for _,v in ipairs(O.favorites) do if v.job==j and v.place==p then v.name=name;return true,'Favori renomme en memoire' end end
    if #O.favorites>=30 then return false,'30 favoris maximum' end
    O.favorites[#O.favorites+1]=valid.favorites[1];return true,'Favori ajoute ; sauvegarder pour conserver'
end
function S.removeServerFavorite(index,confirmed)
    if confirmed~=true or not O.favorites[index] then return false,'Confirmer le favori selectionne' end
    table.remove(O.favorites,index);return true,'Favori retire en memoire'
end
function S.exportSession()
    local now=os.clock();local snap=S.hub:snapshot(now);local privacy=ui.privacy==true
    local events={}
    for _,e in ipairs(S.server.events) do events[#events+1]={kind=e.kind,elapsed=math.max(0,e.at-S.server.started),name=not privacy and e.player.name or nil,id=not privacy and e.player.id or nil} end
    local payload={schema=1,version=VERSION,elapsed=snap.elapsed,increases=S.hub.money.observedIncreases,decreases=S.hub.money.observedDecreases,
        sales=S.hub.money.earned,deposited=S.hub.money.deposited,events=events,privacy=privacy,job=not privacy and job or nil,place=not privacy and place or nil}
    local ok,raw=pcall(function() return HttpService:JSONEncode(payload) end)
    if not ok then return message(false,'Export JSON impossible') end
    if type(setclipboard)=='function' then
        local copied=pcall(setclipboard,raw);if copied then return message(true,'Bilan copie en JSON') end
    end
    if type(writefile)=='function' then
        local wrote=pcall(writefile,'blockspin-session-export.json',raw);return message(wrote,wrote and 'Bilan dans blockspin-session-export.json' or 'Ecriture impossible')
    end
    return message(false,'Presse-papiers et fichier indisponibles')
end
-- Amitie : requete officielle, une fois par joueur, file sequentielle bornee.
O.friendQueue={};O.friendPending={}
function O.queueFriend(p)
    if not p or p.UserId==player.UserId or O.friendKnown[p.UserId] or O.friendPending[p.UserId] or #O.friendQueue>=100 then return end
    O.friendPending[p.UserId]=true;O.friendQueue[#O.friendQueue+1]=p.UserId
end
function O.presence(kind,id)
    local p=S.server.players[id]
    local selected=O.watch[id]==true or (ui.friendAlerts and O.friends[id]==true)
    if ui.presenceAlerts and selected and S.toast then S.toast(ui.privacy and ('Joueur suivi : '..kind) or ((p and p.display or O.leavingName or 'Joueur')..' : '..kind),'info') end
end
pcall(function() for _,p in ipairs(Players:GetPlayers()) do O.queueFriend(p) end end)
function S.setPublicServerProvider(fn)
    if fn~=nil and type(fn)~='function' then return false end
    if O.publicPending then return false end
    O.publicProvider=fn;O.publicCursor=nil;return true
end
function S.fetchPublicServers(nextPage)
    if O.publicPending then return false,'Recherche deja en cours' end
    if os.clock()<(O.publicRetryAt or -1) then return false,'Attendre avant une nouvelle recherche' end
    if place<1 then return false,'PlaceId indisponible' end
    if nextPage and not O.publicCursor then return false,'Aucune page suivante' end
    O.publicTicket=(O.publicTicket or 0)+1;local ticket=O.publicTicket
    O.publicPending=true;O.publicStatus='Chargement';O.publicStarted=os.clock();O.publicRetryAt=os.clock()+5
    local cursor=nextPage and O.publicCursor or nil
    task.spawn(function()
        local ok,payload=pcall(function()
            if O.publicProvider then return O.publicProvider(place,cursor) end
            local url='https://games.roblox.com/v1/games/'..string.format('%.0f',place)..'/servers/Public?sortOrder=Asc&limit=100'
            if cursor then url=url..'&cursor='..HttpService:UrlEncode(cursor) end
            local raw=HttpService:GetAsync(url)
            assert(type(raw)=='string' and #raw<=262144,'reponse trop grande')
            return HttpService:JSONDecode(raw)
        end)
        if not S.running or ticket~=O.publicTicket then return end
        O.publicPending=false
        if not ok then O.publicStatus='Acces API indisponible';O.lastPublicError=tostring(payload):sub(1,200);return end
        local rows,c=Hub.validateServers(payload,job,ui.serverMinFree or 1,ui.serverMaxPopulation or 100)
        if not rows then O.publicStatus='Reponse invalide';O.lastPublicError=c;return end
        O.publicRows=rows;O.publicCursor=c;O.publicStatus=#rows..' serveurs · instantane';O.publicObserved=os.clock();O.publicSelection=nil
    end)
    return true,'Recherche publique demandee'
end
function S.prepareServerJoin(row)
    if type(row)~='table' then return false,'Selectionner un serveur' end
    local valid=Hub.validWorkspace({schema=1,serverKey='',favorites={{job=row.id,place=row.place or place,name='Selection'}},sessions={},plants={}})
    if not valid or row.id==job then return false,'Serveur invalide ou deja rejoint' end
    O.join={id=row.id,place=row.place or place,expires=os.clock()+15};return true,'Confirmer le changement sous 15 secondes'
end
function S.confirmServerJoin()
    local target=O.join;O.join=nil
    if not target or os.clock()>target.expires then return false,'Selection expiree : choisir a nouveau' end
    if S.cycleRunning or S.recording or O.queueRunning then return false,'Terminer les activites avant de changer de serveur' end
    S.cancel()
    local ok,err=pcall(function() game:GetService('TeleportService'):TeleportToPlaceInstance(target.place,target.id,player) end)
    if not ok then return false,'Changement refuse : '..tostring(err):sub(1,160) end
    return true,'Requete envoyee a Roblox ; arrivee non confirmee'
end
-- Detection de sources : textes effectivement presents, a la demande seulement.
local function pathOf(o)
    local parts={};local q=o
    while q and q~=pg and q~=workspace do table.insert(parts,1,q.Name);q=q.Parent end
    if not q then return nil end
    return {scope=q==pg and 'gui' or 'world',parts=parts}
end
local function resolve(path)
    local q=path and (path.scope=='gui' and pg or workspace)
    for _,name in ipairs(path and path.parts or {}) do q=q and q:FindFirstChild(name) end
    return q
end
local function readText(o)
    if not o or not o.Parent or not (o:IsDescendantOf(pg) or o:IsDescendantOf(workspace)) or ours(o) then return nil end
    if o:IsA('TextLabel') or o:IsA('TextButton') then
        if o:IsDescendantOf(pg) then if not shown(o) then return nil end
        else
            local q=o;local layer=false
            while q and q~=workspace do
                if q:IsA('GuiObject') and not q.Visible then return nil end
                if q:IsA('BillboardGui') or q:IsA('SurfaceGui') then if not q.Enabled then return nil end;layer=true end
                q=q.Parent
            end
            if q~=workspace or not layer then return nil end
        end
        return o.Text
    end
end
local function plotPosition(root)
    local q=root
    for _=1,8 do
        if not q or q==pg or q==workspace then break end
        if q:IsA('BasePart') then local p=q.Position;return {p.X,p.Y,p.Z} end
        if q:IsA('BillboardGui') or q:IsA('SurfaceGui') then
            local a=q.Adornee
            if a and a:IsA('BasePart') then local p=a.Position;return {p.X,p.Y,p.Z} end
        end
        q=q.Parent
    end
end
local function plotAnchor(root)
    local q=root
    for _=1,8 do
        if not q or q==pg or q==workspace then return nil end
        if q:IsA('BasePart') then return q end
        if (q:IsA('BillboardGui') or q:IsA('SurfaceGui')) and q.Adornee then return q.Adornee end
        q=q.Parent
    end
end
function S.discoverPlantSources()
    if O.scanPending then return false,'Recherche deja en cours' end
    O.scanPending=true;O.candidates={};O.scanStatus='Recherche des temps et pourcentages visibles'
    task.spawn(function()
        local ok,err=pcall(function()
            local groups={};local processed=0
            for _,scope in ipairs({pg,workspace}) do
                local stack=scope:GetChildren()
                while #stack>0 do
                    if not S.running then return end
                    local o=table.remove(stack)
                    if o~=gui and not ours(o) then
                    processed=processed+1;if processed>15000 then break end
                    for _,child in ipairs(o:GetChildren()) do stack[#stack+1]=child end
                    local value=readText(o)
                    local sec=value and Hub.parseDuration(value);local pct=value and Hub.parsePercent(value)
                    if sec or pct then
                        local ancestor=o.Parent
                        for _=1,2 do
                            if not ancestor or ancestor==pg or ancestor==workspace then break end
                            local g=groups[ancestor] or {root=ancestor,timers={},percents={}};groups[ancestor]=g
                            if sec~=nil then g.timer=o;g.seconds=sec;g.timers[o]=true end
                            if pct~=nil then g.percent=o;g.pct=pct;g.percents[o]=true end
                            ancestor=ancestor.Parent
                        end
                    end
                    if processed%300==0 then task.wait() end
                    end
                end
                if processed>15000 then break end
            end
            local seen={}
            for root,g in pairs(groups) do
                local tc,pc=0,0;for _ in pairs(g.timers) do tc=tc+1 end;for _ in pairs(g.percents) do pc=pc+1 end
                if tc==1 and pc==1 and not seen[g.timer] and #O.candidates<30 then
                    seen[g.timer]=true
                    O.candidates[#O.candidates+1]={root=root,timer=g.timer,percent=g.percent,seconds=g.seconds,pct=g.pct,path=root:GetFullName()}
                end
            end
            table.sort(O.candidates,function(a,b) return a.path<b.path end)
            O.scanStatus=#O.candidates..' paires visibles · propriete a confirmer'..(processed>15000 and ' · limite atteinte' or '')
        end)
        O.scanPending=false
        if not ok then O.scanStatus='Recherche impossible';unavailable(err) end
    end)
    return true,'Recherche lancee ; aucune plantation declenchee'
end
local function pollBinding(b)
    if b.anchor and plotAnchor(b.timer)~=b.anchor then
        local old=O.plants.plots[b.id];if old then old.missing=true end
        return false -- un GUI reutilise pour une autre parcelle ne change pas son identite
    end
    local t=readText(b.timer);local p=readText(b.percent)
    local seconds=t and Hub.parseDuration(t);local percent=p and Hub.parsePercent(p)
    if seconds==nil or percent==nil then
        local old=O.plants.plots[b.id];if old then old.missing=true end
        return false
    end
    local ok=O.plants:observe({serverKey=O.serverKey,id=b.id,crop=b.crop,owned=true,remaining=seconds,percent=percent,
        position=plotPosition(b.timer) or b.position,source=b.source},os.clock())
    return ok
end
local function watchBinding(b)
    for _,c in ipairs(b.connections) do c:Disconnect() end;b.connections={}
    for _,o in ipairs({b.timer,b.percent}) do
        b.connections[#b.connections+1]=o:GetPropertyChangedSignal('Text'):Connect(function()
            if not S.running or b.samplePending then return end
            b.samplePending=true
            task.delay(0,function()
                b.samplePending=false
                if not S.running or O.bindings[b.id]~=b then return end
                local ok,err=pcall(pollBinding,b);if not ok then unavailable(err) end
            end)
        end)
    end
end
function S.bindPlantSource(index,id,crop,owned)
    local c=O.candidates[index]
    id=Hub.normalizeName(id);crop=Hub.normalizeName(crop)
    if owned~=true or not c or not Hub.validName(id) or not Hub.validName(crop) then return false,'Choisir une paire, nommer la parcelle et confirmer votre propriete' end
    if O.bindings[id] then return false,'Parcelle deja liee : retirer avant de remplacer' end
    local count=0;for _ in pairs(O.bindings) do count=count+1 end
    if count>=50 then return false,'50 liaisons maximum' end
    local b={id=id,crop=crop,timer=c.timer,percent=c.percent,timePath=pathOf(c.timer),percentPath=pathOf(c.percent),source=c.path,connections={},position=plotPosition(c.timer),anchor=plotAnchor(c.timer)}
    if not pollBinding(b) then return false,'Les deux valeurs ne sont plus lisibles' end
    O.bindings[id]=b
    watchBinding(b)
    return true,'Parcelle liee : lecture des valeurs reelles, estimation si elles cessent de changer'
end
function S.removePlantTracking(id,confirmed)
    if confirmed~=true then return false,'Confirmer la parcelle selectionnee' end
    local b=O.bindings[id]
    if b then for _,c in ipairs(b.connections) do c:Disconnect() end;O.bindings[id]=nil end
    return O.plants:remove(id,true),'Suivi retire ; aucune recolte declenchee'
end
-- Adaptateur de lecture seulement ; son integration BlockSpin reste a caracteriser.
function S.setPlantObserver(fn)
    if fn~=nil and type(fn)~='function' then return false end
    O.plantProvider=fn;return true
end
function S.exportPlantDiagnostic()
    local rows={}
    for _,v in ipairs(O.candidates) do
        rows[#rows+1]={root=v.path,timer=v.timer:GetFullName(),timerText=readText(v.timer),percent=v.percent:GetFullName(),percentText=readText(v.percent),position=plotPosition(v.timer)}
    end
    local raw=HttpService:JSONEncode({schema=1,version=VERSION,sources=rows,notice='Paires candidates, propriete et identite non deduites'})
    if type(setclipboard)=='function' then local ok=pcall(setclipboard,raw);return message(ok,ok and 'Diagnostic agricole copie' or 'Copie du diagnostic impossible') end
    if type(writefile)=='function' then local ok=pcall(writefile,'blockspin-plant-diagnostic.json',raw);return message(ok,ok and 'Diagnostic dans blockspin-plant-diagnostic.json' or 'Ecriture du diagnostic impossible') end
    return message(false,'Export local indisponible')
end
local function pollProvider()
    if not O.plantProvider or O.plantProviderPending then return end
    O.plantProviderPending=true;O.plantProviderAt=os.clock();O.plantProviderTicket=(O.plantProviderTicket or 0)+1
    local ticket=O.plantProviderTicket
    task.spawn(function()
        local ok,rows=pcall(O.plantProvider)
        if not S.running or ticket~=O.plantProviderTicket then return end
        O.plantProviderPending=false
        if not ok or type(rows)~='table' or #rows>50 then unavailable('Lecteur agricole : reponse invalide');return end
        for _,r in ipairs(rows) do
            if type(r)=='table' and r.state=='removed' then
                if r.serverKey==O.serverKey and r.owned==true and r.confirmed==true then O.plants:remove(r.id,true) end
            else local accepted,why=O.plants:observe(r,os.clock());if not accepted then unavailable(why) end end
        end
    end)
end
function S.addQueueStep(kind,name,timeout)
    if O.queueRunning then return false,'File en cours' end
    local rows=Hub.copy(O.queue);rows[#rows+1]={kind=kind,name=name,timeout=timeout}
    local valid,err=Hub.validateQueue(rows);if not valid then return false,err end
    if kind=='route' and not S.hub.library.routes[name] then return false,'Destination inconnue' end
    O.queue=valid;return true,'Etape ajoutee'
end
function S.startQueue()
    if O.queueRunning or S.cycleRunning or S.recording or S.hub.current then return false,'Une activite est deja en cours' end
    local steps,err=Hub.validateQueue(O.queue);if not steps then return false,err end
    O.queueTicket=(O.queueTicket or 0)+1;local ticket=O.queueTicket
    O.queueRunning=true;O.queueStatus='En cours';S.autoCycle=false;S.fishingEnabled=false;S.paused=true
    task.spawn(function()
        local completed=true
        local function valid() return S.running and O.queueTicket==ticket end
        for i,row in ipairs(steps) do
            if not valid() then return end
            O.queueIndex=i;O.queueDeadline=os.clock()+row.timeout
            local ok,why=true,nil;local tok=S.token;local beforeSales=S.hub.money.sales
            local watched={}
            if row.kind=='plants' then for id in pairs(O.plants.plots) do watched[#watched+1]=id end;if #watched==0 then ok=false;why='Aucune plante suivie' end end
            if row.kind=='cycle' or row.kind=='route' then
                O.dispatching=true
                local callOK,a,b=pcall(function() if row.kind=='cycle' then return S.runCycle() end;return S.driveNamedRoute(row.name) end)
                O.dispatching=false;ok=callOK and a==true;why=b or (not callOK and a or nil);tok=S.token
            end
            local proof=false
            while valid() and ok do
                if row.kind=='pause' then proof=os.clock()>=O.queueDeadline
                elseif row.kind=='plants' then
                    proof=true
                    for _,id in ipairs(watched) do local p=O.plants.plots[id];if not p or not p.ready or p.missing or p.restored or os.clock()-p.observed>3 then proof=false end end
                elseif not S.cycleRunning then
                    proof=row.kind=='route' and S.driver and S.driver.mode=='DONE' or (row.kind=='cycle' and S.lastCycleResult and S.lastCycleResult.token==tok and S.lastCycleResult.ok and S.hub.money.sales>beforeSales)
                    if not proof then ok=false;why=S.lastRouteError or 'Preuve de fin absente' end
                end
                if proof then break end
                if S.token~=tok then ok=false;why='Activite remplacee ou annulee';break end
                if os.clock()>=O.queueDeadline then ok=false;why='Delai maximal depasse';break end
                task.wait(0.1)
            end
            if not valid() then return end
            ok=ok and proof
            O.queueHistory[#O.queueHistory+1]={kind=row.kind,ok=ok,detail=why or 'Fin verifiee',at=os.clock()}
            while #O.queueHistory>40 do table.remove(O.queueHistory,1) end
            if not ok then
                if S.cycleRunning then cancelAll(why) end
                O.queueStatus='Interrompue : '..tostring(why);S.hub:error('File',why,os.clock());completed=false;break
            end
        end
        O.queueRunning=false;O.queueDeadline=nil
        if completed then O.queueStatus='Terminee : preuves verifiees' end
    end)
    return true,'File demarree ; aucun redemarrage automatique apres une erreur'
end
function O.tick()
    local now=os.clock()
    if O.publicPending and now-O.publicStarted>12 then O.publicTicket=O.publicTicket+1;O.publicPending=false;O.publicStatus='Delai API depasse' end
    if O.plantProviderPending and now-O.plantProviderAt>5 then O.plantProviderTicket=O.plantProviderTicket+1;O.plantProviderPending=false;unavailable('Delai du lecteur agricole depasse') end
    if now>=(O.nextPlantPoll or 0) then
        O.nextPlantPoll=now+1
        for _,b in pairs(O.bindings) do
            if not b.timer.Parent or not b.percent.Parent then
                local t,p=resolve(b.timePath),resolve(b.percentPath)
                if t and p and (t~=b.timer or p~=b.percent) then
                    b.timer=t;b.percent=p;watchBinding(b)
                end
            end
            local ok,err=pcall(pollBinding,b);if not ok then unavailable(err) end
        end
        pollProvider()
        if ui.plantAlerts then for _,a in ipairs(O.plants:alerts(now,ui.plantAlertSeconds or 60)) do
            if S.toast then S.toast(a.id..(a.kind=='ready' and ' : maturite observee' or (a.estimated and ' : bientot prete (estime)' or ' : bientot prete')),'info') end
        end end
    end
    if O.friendBusy and now-(O.friendStarted or now)>8 then O.friendTicket=(O.friendTicket or 0)+1;O.friendBusy=false end
    if not O.friendBusy and #O.friendQueue>0 and now>=(O.friendRetryAt or 0) then
        O.friendBusy=true;O.friendStarted=now;O.friendRetryAt=now+1.5;O.friendTicket=(O.friendTicket or 0)+1
        local ticket=O.friendTicket;local id=table.remove(O.friendQueue,1)
        task.spawn(function()
            local ok,result=pcall(function() return player:IsFriendsWith(id) end)
            O.friendPending[id]=nil
            if not S.running or O.friendTicket~=ticket then return end
            O.friendKnown[id]=true;if ok then O.friends[id]=result==true end
            O.friendBusy=false
        end)
    end
end
function O.cleanup()
    O.friendTicket=(O.friendTicket or 0)+1
    O.publicTicket=(O.publicTicket or 0)+1;O.plantProviderTicket=(O.plantProviderTicket or 0)+1;O.queueTicket=(O.queueTicket or 0)+1;O.queueRunning=false
    for _,b in pairs(O.bindings) do for _,c in ipairs(b.connections) do c:Disconnect() end end
    O.bindings={}
end
end
