-- Logique pure V1 : aucune API Roblox, entree/sortie de jeu ou secret.
local Core = {}
local function finite(n)
    return type(n) == 'number' and n == n and math.abs(n) < math.huge
end
local function nameOK(n)
    return type(n) == 'string' and #n > 0 and #n <= 64 and not n:find('%c')
end
local function copy(v)
    if type(v) ~= 'table' then return v end
    local out = {}; for k, x in pairs(v) do out[k] = copy(x) end; return out
end
local function bounded(list, item, limit)
    list[#list + 1] = item
    while #list > limit do table.remove(list, 1) end
end
-- Solde entier/groupe, ou decimal explicite ; jamais supprimer le point decimal.
function Core.parseMoney(text)
    if type(text) ~= 'string' then return nil end
    text = text:gsub('%s', '')
    local function integer(s)
        if s:match('^%d+$') then return tonumber(s) end
        local separator = s:find(',', 1, true) and ',' or '.'
        local first = true
        for part in (s .. separator):gmatch('(.-)' .. (separator == '.' and '%.' or separator)) do
            if not part:match('^%d+$') or (first and #part > 3) or (not first and #part ~= 3) then return nil end
            first = false
        end
        return tonumber((s:gsub('[.,]', '')))
    end
    local whole, fraction = text:match('^(.-)[.,](%d%d?)$')
    local n
    if whole then
        local base = integer(whole)
        if base then n = base + tonumber(fraction) / 10 ^ #fraction end
    else n = integer(text) end
    return finite(n) and n >= 0 and n or nil
end
function Core.new(now)
    local h = { started = now, errors = {}, history = {}, current = nil,
        library = { schema = 1, spots = {}, routes = {} }, activeSpot = nil,
        money = { earned = 0, deposited = 0, sales = 0, deposits = 0, cash = nil,
            observedIncreases = 0, observedDecreases = 0, baitUsed = 0, baitAdded = 0 },
        spotStats = {}, farm = { available = false, running = false, planted = 0, harvested = 0, cycles = 0 },
        seenTransactions = {} }
    return setmetatable(h, { __index = Core })
end
function Core:error(stage, message, now)
    bounded(self.errors, { stage = tostring(stage), message = tostring(message):sub(1, 300), at = now }, 80)
end
function Core:beginStep(name, now, timeout, token)
    assert(nameOK(name) and finite(timeout) and timeout > 0, 'etape invalide')
    self.current = { name = name, started = now, deadline = now + timeout, token = token }
end
function Core:finishStep(ok, detail, now)
    local step = self.current
    if not step then return end
    step.ok, step.detail, step.finished = ok == true, tostring(detail or ''), now
    bounded(self.history, step, 80); self.current = nil
    if not step.ok then self:error(step.name, step.detail, now) end
end
function Core:expired(now, token)
    return self.current and self.current.token == token and now >= self.current.deadline
end
function Core:snapshot(now)
    local elapsed = math.max(0, now - self.started)
    return { elapsed = elapsed, earned = self.money.earned, deposited = self.money.deposited,
        hourly = elapsed >= 60 and self.money.earned * 3600 / elapsed or nil,
        activity = self.current and self.current.name or 'repos' }
end
function Core:observeCash(n,source,now)
    if not finite(n) or n < 0 then return false end
    local m = self.money
    if source and m.cashSource and source~=m.cashSource then m.cash=nil end
    if source then m.cashSource=source end
    if finite(now) and m.observedStartedAt==nil then m.observedStartedAt=now end
    if m.cash ~= nil then
        m.observedIncreases = m.observedIncreases + math.max(0, n - m.cash)
        m.observedDecreases = m.observedDecreases + math.max(0, m.cash - n)
    end
    m.cash = n; return true
end
function Core:observeBait(n)
    if not finite(n) or n < 0 or n % 1 ~= 0 then return false end
    local m = self.money
    if m.bait ~= nil then
        m.baitUsed = m.baitUsed + math.max(0, m.bait - n)
        m.baitAdded = m.baitAdded + math.max(0, n - m.bait)
    end
    m.bait = n; return true
end
-- Une hausse passive du portefeuille n'est pas attribuee a une vente.
-- id = identifiant de tentative, preuve inventaire requise pour les ventes.
function Core:transaction(id, kind, before, after, proof)
    if not nameOK(id) or self.seenTransactions[id] or (kind ~= 'sale' and kind ~= 'deposit') then return false end
    if not finite(before) or not finite(after) or before < 0 or after < 0 or proof ~= true then return false end
    local amount = kind == 'sale' and after - before or before - after
    if amount <= 0 then return false end
    self.seenTransactions[id] = true
    local m = self.money
    if kind == 'sale' then m.earned = m.earned + amount; m.sales = m.sales + 1
    else m.deposited = m.deposited + amount; m.deposits = m.deposits + 1 end
    self:observeCash(after); return true
end
function Core.normalizeName(name)
    if type(name)~='string' then return '' end
    return (name:gsub('^%s+',''):gsub('%s+$',''))
end
function Core.validAim(aim)
    if type(aim)~='table' or not finite(aim.x) or not finite(aim.y) then return false end
    if aim.world~=nil then
        if type(aim.world)~='table' or #aim.world~=3 then return false end
        for _,n in ipairs(aim.world) do if not finite(n) then return false end end
    end
    if aim.viewport~=nil then
        if type(aim.viewport)~='table' or not finite(aim.viewport.x) or not finite(aim.viewport.y) or aim.viewport.x<=0 or aim.viewport.y<=0 then return false end
    end
    return true
end
function Core:updateSpotAim(name,aim)
    if not self.library.spots[name] then return false,'spot introuvable' end
    if not Core.validAim(aim) then return false,'visee invalide' end
    self.library.spots[name].aim=copy(aim);return true
end
function Core.cashText(raw,allowBare)
    if type(raw)~='string' or #raw>512 then return nil end
    raw=raw:gsub('<[^>]*>',''):gsub(' ',' '):gsub(' ',' '):gsub(' ',' ')
    local normalized=fold(raw)
    local labels={'equilibre des mains','argent en main','argent en poche','cash','wallet','portefeuille','solde en main','hand balance','cash in hand','money in hand'}
    for _,label in ipairs(labels) do
        local value=normalized:match('^%s*'..label..'%s*:%s*%$?%s*([%d, %.]+)%s*$')
        if value then return Core.parseMoney(value),'label' end
    end
    if allowBare then
        local value=raw:match('^%s*%$%s*([%d, %.]+)%s*$') or raw:match('^%s*([%d, %.]+)%s*%$%s*$')
            or raw:match('^%s*€%s*([%d, %.]+)%s*$') or raw:match('^%s*([%d, %.]+)%s*€%s*$')
        if value then return Core.parseMoney(value),'currency' end
    end
end
function Core:addSpot(name, cf, aim)
    if not nameOK(name) then return false, 'nom du spot invalide' end
    if type(cf) ~= 'table' or #cf ~= 12 then return false, 'position de 12 nombres requise' end
    for _, n in ipairs(cf) do if not finite(n) then return false, 'position invalide' end end
    if aim ~= nil and not Core.validAim(aim) then return false, 'visee invalide' end
    if self.library.spots[name] then return false, 'spot existant : supprimer explicitement avant de remplacer' end
    local count = 0; for _ in pairs(self.library.spots) do count = count + 1 end
    if count >= 50 then return false, 'maximum 50 spots' end
    self.library.spots[name] = { cf = copy(cf), aim = copy(aim) }
    self.activeSpot = name; return true
end
function Core:addRoute(name, points)
    if not nameOK(name) or type(points) ~= 'table' or #points < 2 or #points > 2000 then return false, 'trajet : nom et 2 a 2000 points requis' end
    if self.library.routes[name] then return false, 'trajet existant : supprimer explicitement avant de remplacer' end
    local count = 0; for _ in pairs(self.library.routes) do count = count + 1 end
    if count >= 50 then return false, 'maximum 50 trajets' end
    local length = 0
    for i, p in ipairs(points) do
        if type(p) ~= 'table' or #p ~= 3 then return false, 'point incomplet' end
        for _, n in ipairs(p) do if not finite(n) then return false, 'point invalide' end end
        if i > 1 then
            local a = points[i - 1]; length = length + (p[1] - a[1]) ^ 2 + (p[3] - a[3]) ^ 2
        end
    end
    if length < 0.01 then return false, 'trajet sans deplacement horizontal' end
    self.library.routes[name] = copy(points); return true
end
function Core:loadLibrary(d)
    if type(d) ~= 'table' or d.schema ~= 1 or type(d.spots) ~= 'table' or type(d.routes) ~= 'table' then return false, 'bibliotheque invalide' end
    local candidate = Core.new(self.started)
    for name, s in pairs(d.spots) do
        if type(s) ~= 'table' then return false, 'spot invalide' end
        local ok, err = candidate:addSpot(name, s.cf, s.aim); if not ok then return false, err end
    end
    for name, r in pairs(d.routes) do
        local ok, err = candidate:addRoute(name, r); if not ok then return false, err end
    end
    self.library = candidate.library; self.activeSpot = nil; return true
end
function Core:spotEvent(kind)
    local name = self.activeSpot
    if not name or not self.library.spots[name] then return end
    self.spotStats[name] = self.spotStats[name] or { casts = 0, texts = 0, rareSignals = 0, seconds = 0 }
    local s = self.spotStats[name]
    if kind == 'casts' or kind == 'texts' or kind == 'rareSignals' then s[kind] = s[kind] + 1 end
end
function Core:spotTime(dt)
    if not finite(dt) or dt <= 0 or not self.activeSpot then return end
    self.spotStats[self.activeSpot] = self.spotStats[self.activeSpot] or { casts = 0, texts = 0, rareSignals = 0, seconds = 0 }
    self.spotStats[self.activeSpot].seconds = self.spotStats[self.activeSpot].seconds + dt
end
-- Le jeu ne fournit encore aucun adaptateur agricole observe/verifie.
-- L'adaptateur est local, synchrone et cooperatif ; les actions ne prouvent rien
-- seules : la prochaine observation doit confirmer leur resultat.
function Core:setFarmAdapter(adapter)
    if type(adapter) ~= 'table' then return false, 'adaptateur agricole absent' end
    for _, key in ipairs({ 'observe', 'plant', 'harvest' }) do
        if type(adapter[key]) ~= 'function' then return false, 'adaptateur incomplet : ' .. key end
    end
    self.farm.adapter = adapter; self.farm.available = true; return true
end
function Core:farmAction(plot, crop, replant)
    if not self.farm.available then return nil, 'culture indisponible : interactions du jeu non observees' end
    if not nameOK(plot) or not nameOK(crop) then return nil, 'parcelle ou plante invalide' end
    local a = self.farm.adapter
    local observed = a.observe(plot)
    if type(observed) ~= 'table' then return nil, 'observation de parcelle absente' end
    if observed.state == 'growing' and observed.crop == crop then return { kind = 'wait', plot = plot, crop = crop } end
    if observed.state == 'ready' and observed.crop == crop then return { kind = 'harvest', plot = plot, crop = crop, replant = replant } end
    if observed.state == 'empty' then return { kind = 'plant', plot = plot, crop = crop } end
    return nil, 'etat ou culture inattendu : aucune action'
end
-- Couleur et observateur serveur purs ; aucune geolocalisation deduite.
function Core.hsvToHex(h,s,v)
    if not finite(h) or not finite(s) or not finite(v) then return nil end
    h=h%1;s=math.max(0,math.min(1,s));v=math.max(0,math.min(1,v))
    local c=v*s;local x=c*(1-math.abs((h*6)%2-1));local m=v-c
    local rgb={{c,x,0},{x,c,0},{0,c,x},{0,x,c},{x,0,c},{c,0,x}}
    local a=rgb[math.floor(h*6)+1]
    return string.format('%02X%02X%02X',math.floor((a[1]+m)*255+0.5),math.floor((a[2]+m)*255+0.5),math.floor((a[3]+m)*255+0.5))
end
function Core.hexToHSV(hex)
    if type(hex)~='string' or not hex:match('^%x%x%x%x%x%x$') then return nil end
    local r,g,b=tonumber(hex:sub(1,2),16)/255,tonumber(hex:sub(3,4),16)/255,tonumber(hex:sub(5,6),16)/255
    local hi,lo=math.max(r,g,b),math.min(r,g,b);local d=hi-lo;local h=0
    if d>0 then
        if hi==r then h=((g-b)/d)%6 elseif hi==g then h=(b-r)/d+2 else h=(r-g)/d+4 end
        h=h/6
    end
    return h,hi==0 and 0 or d/hi,hi
end
function Core.newServer(now,maxPlayers)
    local server={started=now,players={},events={},joined=0,left=0,count=0,revision=0,maxPlayers=maxPlayers,region=nil}
    function server:add(id,name,display,now,baseline)
        if not finite(id) or id<1 or id%1~=0 or self.players[id] then return false end
        self.players[id]={id=id,name=tostring(name or '?'):sub(1,64),display=tostring(display or name or '?'):sub(1,64),observed=now,baseline=not not baseline}
        self.count=self.count+1;self.revision=self.revision+1
        if not baseline then
            self.joined=self.joined+1
            bounded(self.events,{kind='join',player=copy(self.players[id]),at=now},80)
        end
        return true
    end
    function server:remove(id,now)
        local p=self.players[id];if not p then return false end
        bounded(self.events,{kind='leave',player=copy(p),at=now},80)
        self.players[id]=nil;self.count=self.count-1;self.left=self.left+1;self.revision=self.revision+1
        return true
    end
    function server:roster()
        local rows={};for _,p in pairs(self.players) do rows[#rows+1]=copy(p) end
        table.sort(rows,function(a,b) return a.name:lower()==b.name:lower() and a.id<b.id or a.name:lower()<b.name:lower() end)
        return rows
    end
    function server:recent(kind,limit)
        local rows={}
        for i=#self.events,1,-1 do
            if self.events[i].kind==kind then rows[#rows+1]=copy(self.events[i]);if #rows>=(limit or 6) then break end end
        end
        return rows
    end
    return server
end
-- Observatoire V1.2 : calculs locaux uniquement. Aucune hierarchie de jeu supposee.
function Core.parseDuration(value)
    if finite(value) then return value>=0 and value<=604800 and value or nil end
    if type(value)~='string' or #value>150 then return nil end
    local s=value:gsub('<[^>]*>',''):lower():match('^%s*(.-)%s*$')
    local h,m,sec=s:match('^(%d+):(%d%d):(%d%d)$')
    if h then if tonumber(m)>59 or tonumber(sec)>59 then return nil end;return Core.parseDuration(tonumber(h)*3600+tonumber(m)*60+tonumber(sec)) end
    m,sec=s:match('^(%d+):(%d%d)$')
    if m then if tonumber(sec)>59 then return nil end;return Core.parseDuration(tonumber(m)*60+tonumber(sec)) end
    local total,found=0,false
    for n,unit in s:gmatch('(%d+)%s*([hms])') do total=total+tonumber(n)*({h=3600,m=60,s=1})[unit];found=true end
    if found and s:gsub('%d+%s*[hms]',''):match('^%s*$') then return Core.parseDuration(total) end
    return nil -- pas de nombre nu dans un texte : pourrait etre un prix ou un niveau
end
function Core.parsePercent(value)
    if finite(value) then return value>=0 and value<=100 and value or nil end
    if type(value)~='string' or #value>100 then return nil end
    local n=value:gsub('<[^>]*>',''):match('^%s*(%d+[.,]?%d*)%s*%%%s*$')
    return n and Core.parsePercent(tonumber((n:gsub(',','.')))) or nil
end
function Core.duration(n)
    if not finite(n) then return 'N/D' end
    n=math.max(0,math.ceil(n))
    if n>=3600 then return string.format('%02d:%02d:%02d',math.floor(n/3600),math.floor(n/60)%60,n%60) end
    return string.format('%02d:%02d',math.floor(n/60),n%60)
end
function Core.newPlants(serverKey)
    local t={serverKey=serverKey,plots={},revision=0,events={}}
    function t:observe(sample,now)
        if type(sample)~='table' or sample.serverKey~=self.serverKey or sample.owned~=true or not nameOK(sample.id) or not nameOK(sample.crop) or not finite(now) then return false,'identite ou propriete non confirmee' end
        local seconds,percent=Core.parseDuration(sample.remaining),Core.parsePercent(sample.percent)
        if not seconds or not percent then return false,'temps et pourcentage requis' end
        local p=self.plots[sample.id]
        if not p then
            local count=0;for _ in pairs(self.plots) do count=count+1 end
            if count>=50 then return false,'50 parcelles maximum' end
        end
        local changed=not p or p.seconds~=seconds or p.percent~=percent or p.crop~=sample.crop or p.restored
        if not changed then
            if p.ready then p.observed=now;p.missing=false end
            return true,'lecture identique : echeance conservee'
        end
        local reset=p and (p.crop~=sample.crop or (percent<p.percent and seconds>p.seconds))
        local generation=p and (p.generation+(reset and 1 or 0)) or 1
        p={id=sample.id,crop=sample.crop,seconds=seconds,percent=percent,observed=now,deadline=now+seconds,
            generation=generation,ready=seconds==0 and percent==100,position=copy(sample.position),source=tostring(sample.source or ''):sub(1,512),alerts={}}
        local old=self.plots[sample.id]
        if old and not reset then p.alerts=old.alerts end
        if p.position and (type(p.position)~='table' or #p.position~=3 or not finite(p.position[1]) or not finite(p.position[2]) or not finite(p.position[3])) then return false,'position invalide' end
        self.plots[p.id]=p;self.revision=self.revision+1
        bounded(self.events,{kind=not old and 'observed' or (reset and 'restart' or (p.ready and 'ready' or 'update')),id=p.id,at=now},80)
        return true
    end
    function t:remove(id,confirmed)
        if confirmed~=true or not self.plots[id] then return false end
        self.plots[id]=nil;self.revision=self.revision+1;return true
    end
    function t:rows(now,position,group)
        local out={}
        for _,p in pairs(self.plots) do
            local r=copy(p);r.remaining=math.max(0,p.deadline-now);r.age=math.max(0,now-p.observed)
            r.estimated=p.restored==true or p.missing==true or r.age>3
            r.status=p.ready and (r.estimated and 'Derniere maturite observee' or 'Prete (observe)') or (r.remaining==0 and 'Echeance estimee' or (r.estimated and 'Estime' or 'Observe'))
            r.projectedPercent=p.percent
            if p.seconds>0 and p.percent<100 then r.projectedPercent=math.min(100,p.percent+(100-p.percent)*math.min(1,r.age/p.seconds)) end
            if position and p.position then local d=0;for i=1,3 do d=d+(position[i]-p.position[i])^2 end;r.distance=math.sqrt(d) end
            out[#out+1]=r
        end
        table.sort(out,function(a,b)
            if group and a.crop~=b.crop then return a.crop<b.crop end
            if a.remaining~=b.remaining then return a.remaining<b.remaining end
            return a.id<b.id
        end)
        return out
    end
    function t:alerts(now,threshold)
        local out={}
        for _,p in ipairs(self:rows(now)) do
            local key=p.ready and not p.estimated and 'ready' or (p.remaining>0 and p.remaining<=threshold and 'soon' or nil)
            local original=self.plots[p.id]
            if key and not original.alerts[key] then original.alerts[key]=true;out[#out+1]={id=p.id,kind=key,estimated=p.estimated} end
        end
        return out
    end
    return t
end
function Core.pingSummary(values)
    local a={};local sum=0
    for _,n in ipairs(values or {}) do if finite(n) and n>=0 then a[#a+1]=n;sum=sum+n end end
    if #a==0 then return {} end
    table.sort(a);local mid=math.floor((#a+1)/2)
    return {count=#a,min=a[1],max=a[#a],mean=sum/#a,median=#a%2==1 and a[mid] or (a[mid]+a[mid+1])/2}
end
function Core.filterRoster(server,query,order,friends)
    local rows={};query=tostring(query or ''):lower():sub(1,64)
    for _,p in ipairs(server:roster()) do
        if query=='' or p.name:lower():find(query,1,true) or p.display:lower():find(query,1,true) then rows[#rows+1]=p end
    end
    table.sort(rows,function(a,b)
        if order=='friends' and (friends[a.id]==true)~=(friends[b.id]==true) then return friends[a.id]==true end
        if order=='recent' and a.observed~=b.observed then return a.observed>b.observed end
        if a.name:lower()==b.name:lower() then return a.id<b.id end
        return a.name:lower()<b.name:lower()
    end)
    return rows
end
function Core.validateServers(payload,currentJob,minFree,maxPopulation)
    if type(payload)~='table' or type(payload.data)~='table' or #payload.data>100 then return nil,'liste publique invalide' end
    local out,seen={},{}
    for _,r in ipairs(payload.data) do
        if type(r)=='table' and type(r.id)=='string' and #r.id<=128 and r.id:match('^[%w%-]+$') and not seen[r.id]
            and finite(r.playing) and r.playing>=0 and r.playing%1==0 and finite(r.maxPlayers) and r.maxPlayers>0 and r.maxPlayers%1==0 and r.playing<=r.maxPlayers then
            seen[r.id]=true
            if r.id~=currentJob and r.maxPlayers-r.playing>=minFree and r.playing<=maxPopulation then out[#out+1]={id=r.id,playing=r.playing,maxPlayers=r.maxPlayers} end
        end
    end
    local cursor=payload.nextPageCursor
    if cursor~=nil and (type(cursor)~='string' or #cursor>512 or cursor:find('%c')) then return nil,'curseur invalide' end
    return out,cursor
end
function Core.validWorkspace(data)
    if type(data)~='table' or data.schema~=1 or type(data.favorites)~='table' or type(data.sessions)~='table' or type(data.plants)~='table' then return nil,'format observatoire invalide' end
    if #data.favorites>30 or #data.sessions>30 or #data.plants>50 then return nil,'limite observatoire depassee' end
    local function identifier(s) return type(s)=='string' and #s>0 and #s<=128 and s:match('^[%w%-]+$') end
    local out={schema=1,favorites={},sessions={},plants={},serverKey=type(data.serverKey)=='string' and data.serverKey:sub(1,160) or ''}
    local seen={}
    for _,v in ipairs(data.favorites) do
        if type(v)~='table' or not identifier(v.job) or not finite(v.place) or v.place<1 or v.place%1~=0 or not nameOK(v.name) or seen[v.place..':'..v.job] then return nil,'favori invalide' end
        seen[v.place..':'..v.job]=true;out.favorites[#out.favorites+1]={job=v.job,place=v.place,name=v.name}
    end
    for _,v in ipairs(data.sessions) do
        if type(v)~='table' or not nameOK(v.id) or not finite(v.elapsed) or v.elapsed<0 or not finite(v.at) or not finite(v.increases) or v.increases<0 or not finite(v.decreases) or v.decreases<0 or not identifier(v.job) or not finite(v.place) or v.place<1 then return nil,'session invalide' end
        out.sessions[#out.sessions+1]={id=v.id,elapsed=v.elapsed,at=v.at,increases=v.increases,decreases=v.decreases,job=v.job,place=v.place}
    end
    local t=Core.newPlants(out.serverKey)
    for _,v in ipairs(data.plants) do
        if type(v)~='table' or not finite(v.savedAt) then return nil,'plante sauvegardee invalide' end
        local sample=copy(v);sample.owned=true;sample.serverKey=out.serverKey
        if not t:observe(sample,v.savedAt) then return nil,'plante invalide' end
        out.plants[#out.plants+1]={id=v.id,crop=v.crop,remaining=v.remaining,percent=v.percent,position=copy(v.position),savedAt=v.savedAt}
    end
    return out
end
function Core.validateQueue(rows)
    if type(rows)~='table' or #rows<1 or #rows>20 then return nil,'1 a 20 etapes requises' end
    local out={}
    for _,r in ipairs(rows) do
        if type(r)~='table' or not ({route=true,cycle=true,plants=true,pause=true})[r.kind] or not finite(r.timeout) or r.timeout<1 or r.timeout>1800 then return nil,'etape ou delai invalide' end
        if r.kind=='route' and not nameOK(r.name) then return nil,'destination requise' end
        out[#out+1]={kind=r.kind,name=r.name,timeout=r.timeout}
    end
    return out
end
Core.copy = copy
Core.validName = nameOK
return Core
