-- BlockSpin Hub v1.2.1
-- Peche auto (logique v0.6.8 conservee) + cycle vente/ATM par conduite NATIVE sur route
-- (touches simulees W/A/S/D, aucun deplacement de CFrame, aucune teleportation).
-- Aucun passage sous la carte : non implemente volontairement (voir README_v080.md).
-- Arret complet : getgenv().BlockSpinCycle080.stop()
-- Arret d'urgence du cycle/conduite (le script reste charge) : F12
local VERSION = '1.2.1'
local E = (getgenv and getgenv()) or _G

---------------------------------------------------------------------------
-- 1. UTILITAIRES PURS (testables hors Roblox)
---------------------------------------------------------------------------
local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end
local function isNum(v) return type(v) == 'number' and v == v and v ~= math.huge and v ~= -math.huge end
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
-- Texte -> ASCII minuscule (accents francais retires). string.lower seul n'est pas fiable
-- sur l'UTF-8 ("DÉPÔT") selon l'environnement d'execution.
local FOLD = {
    ['é'] = 'e', ['É'] = 'e', ['è'] = 'e', ['È'] = 'e', ['ê'] = 'e', ['Ê'] = 'e', ['ë'] = 'e',
    ['à'] = 'a', ['À'] = 'a', ['â'] = 'a', ['Â'] = 'a', ['ô'] = 'o', ['Ô'] = 'o', ['î'] = 'i', ['Î'] = 'i',
    ['ï'] = 'i', ['û'] = 'u', ['Û'] = 'u', ['ù'] = 'u', ['ç'] = 'c', ['Ç'] = 'c',
}
local function fold(s)
    s = tostring(s or ''):gsub('\195[\128-\191]', FOLD):gsub('[\128-\255]', '')
    return (s:lower())
end

local Hub = (function()
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

end)()

-- Donnees par defaut = data/route_data.json (aller 19 points, retour 20 points DISTINCTS).
-- Un fichier blockspin_data_v080.json valide dans le dossier workspace de l'executeur les remplace.
local DEFAULT_DATA = {
    version = 1,
    route_to_vendor = {
        {-350.9665222167969, 254.49325561523438, 844.3192138671875},
        {-369.0896911621094, 254.4923095703125, 831.8604736328125},
        {-356.9356689453125, 254.54286193847656, 816.4835815429688},
        {-353.1336975097656, 254.52691650390625, 785.2936401367188},
        {-354.03375244140625, 254.49530029296875, 761.7402954101562},
        {-355.7673645019531, 254.50611877441406, 732.5521850585938},
        {-357.8532409667969, 254.48487854003906, 698.636962890625},
        {-358.7081604003906, 254.4691162109375, 665.3856201171875},
        {-356.3110656738281, 254.19288635253906, 631.7860107421875},
        {-351.2131652832031, 254.3011016845703, 598.9113159179688},
        {-350.15362548828125, 254.29486083984375, 563.9579467773438},
        {-351.9523620605469, 254.2373809814453, 530.1721801757812},
        {-353.070068359375, 254.17745971679688, 500.9393310546875},
        {-348.8035888671875, 254.1873779296875, 476.7269592285156},
        {-339.17938232421875, 254.19473266601562, 460.05224609375},
        {-327.79254150390625, 254.25985717773438, 450.3841247558594},
        {-313.7236633300781, 254.18594360351562, 440.20709228515625},
        {-300.2818908691406, 254.46258544921875, 435.3600769042969},
        {-284.83880615234375, 255.061767578125, 431.8515625}
    },
    route_to_fishing = {
        {-278.7955627441406, 255.59181213378906, 430.9920959472656},
        {-300.379150390625, 254.5145263671875, 434.5917053222656},
        {-315.169189453125, 254.5189666748047, 437.3883056640625},
        {-332.6300354003906, 254.23526000976562, 441.5803527832031},
        {-333.7713928222656, 254.2137451171875, 466.4567565917969},
        {-335.146728515625, 254.2611846923828, 482.7571105957031},
        {-336.699462890625, 254.25721740722656, 504.711181640625},
        {-338.6148986816406, 254.2566680908203, 532.5056762695312},
        {-340.81146240234375, 254.24388122558594, 565.1935424804688},
        {-345.1157531738281, 254.2581787109375, 598.58935546875},
        {-350.6275939941406, 254.3098602294922, 631.8374633789062},
        {-352.7408142089844, 254.7941131591797, 664.6741333007812},
        {-354.5787658691406, 254.6029815673828, 697.2633666992188},
        {-355.6474914550781, 254.58267211914062, 725.8491821289062},
        {-358.68707275390625, 254.49964904785156, 754.5657348632812},
        {-362.6327209472656, 254.46383666992188, 785.9971313476562},
        {-365.5960693359375, 254.54762268066406, 812.3237915039062},
        {-363.7058410644531, 254.50656127929688, 833.4988403320312},
        {-360.051025390625, 254.48480224609375, 847.9295043945312},
        {-351.1239929199219, 254.50595092773438, 859.8558349609375}
    },
    fish = {-334.8728332519531, 254.77626037597656, 836.0563354492188, -0.05788244307041168, 4.919711926731907e-08, -0.998323380947113, 9.945766521468613e-08, 1.0, 4.351321791773444e-08, 0.998323380947113, -9.677226842086384e-08, -0.05788244307041168},
    vendor = {-255.43922424316406, 255.9411163330078, 379.14581298828125, 0.014957649633288383, -6.086331438837078e-09, -0.9998881220817566, -5.01214292292218e-10, 1.0, -6.094510229814887e-09, 0.9998881220817566, 5.923178059141776e-10, 0.014957649633288383},
    atm = {-225.32275390625, 254.68153381347656, 488.1391296386719, -0.9670562744140625, -5.76344554303887e-08, -0.2545626759529114, -5.2210733514357344e-08, 1.0, -2.8062778767434793e-08, 0.2545626759529114, -1.3847382795972862e-08, -0.9670562744140625},
}

local function validPoints(list, name)
    if type(list) ~= 'table' or #list < 2 then return nil, name .. ' : au moins 2 points requis' end
    local out = {}
    for i, p in ipairs(list) do
        if type(p) ~= 'table' or #p ~= 3 or not (isNum(p[1]) and isNum(p[2]) and isNum(p[3])) then
            return nil, name .. ' : point ' .. i .. ' invalide'
        end
        out[i] = { p[1], p[2], p[3] }
    end
    return out
end
local function validCF(a, name)
    if type(a) ~= 'table' or #a ~= 12 then return nil, name .. ' : CFrame de 12 nombres requis' end
    local out = {}
    for i = 1, 12 do
        if not isNum(a[i]) then return nil, name .. ' : composante ' .. i .. ' invalide' end
        out[i] = a[i]
    end
    return out
end
-- Schema attendu : celui de route_data.json (route_to_vendor / route_to_fishing distincts).
-- Le schema v0.6.8 ("points") est refuse ici : utiliser S.importV068() explicitement.
local function validateData(d)
    if type(d) ~= 'table' then return nil, 'donnees absentes' end
    if d.points ~= nil and d.route_to_vendor == nil then
        return nil, 'schema v0.6.8 (points) : pas de route retour distincte'
    end
    local r, err = { version = 1 }, nil
    r.route_to_vendor, err = validPoints(d.route_to_vendor, 'route_to_vendor'); if not r.route_to_vendor then return nil, err end
    r.route_to_fishing, err = validPoints(d.route_to_fishing, 'route_to_fishing'); if not r.route_to_fishing then return nil, err end
    r.fish, err = validCF(d.fish, 'fish'); if not r.fish then return nil, err end
    r.vendor, err = validCF(d.vendor, 'vendor'); if not r.vendor then return nil, err end
    r.atm, err = validCF(d.atm, 'atm'); if not r.atm then return nil, err end
    return r
end

-- Parametres de conduite. Valeurs NON calibrees sur le G-Cruzer reel.
local DRIVE_DEFAULTS = {
    dt = 0.05,
    cruiseSpeed = 20, turnSpeed = 7, arriveSpeed = 3,
    decel = 10,              -- deceleration supposee au freinage (studs/s^2), non mesuree
    lookMin = 9, lookMax = 24, lookGain = 0.55, uturnLook = 18,
    arriveRadius = 8, maxStartDist = 45,
    kp = 1.4, kd = 0.45, steerTau = 0.12, pwmPeriod = 0.3, deadband = 0.05,
    angleSlow = 0.9,
    uturnEnter = 1.65, uturnExit = 0.55, uturnSpeed = 6, uturnFwdMax = 6, uturnNoGain = 2.5,
    uturnRevTime = 1.6, uturnMaxAttempts = 5,
    stuckSeconds = 6, recoverTime = 1.3, maxRecoveries = 3,
    brake = true, brakeMargin = 3, nativeStraight = false,
    stopTimeout = 3, timeoutBase = 40, timeoutSpeed = 3,
}

-- Pilote : suivi de trajet par projection sur les segments + point vise anticipe
-- (pure pursuit), vitesse limitee par la courbure a venir et la distance d'arret,
-- manoeuvre de demi-tour (avant braque / marche arriere contre-braquee),
-- degagement en cas de blocage. Ne lit/ecrit rien dans Roblox : step() recoit
-- une observation et renvoie les touches a tenir.
local Driver = {}
Driver.__index = Driver

local function segInfo(pts, i)
    local a, b = pts[i], pts[i + 1]
    local dx, dz = b[1] - a[1], b[2] - a[2]
    return a[1], a[2], dx, dz, math.sqrt(dx * dx + dz * dz)
end
local function signedAngle(fx, fz, tx, tz) -- positif = cible a DROITE de l'avant
    return atan2(fx * tz - fz * tx, fx * tx + fz * tz)
end

function Driver.new(points, cfg)
    local d = setmetatable({}, Driver)
    d.cfg = cfg
    d.pts = {}
    for _, p in ipairs(points) do
        local last = d.pts[#d.pts]
        if not last or (p[1] - last[1]) ^ 2 + (p[2] - last[2]) ^ 2 > 0.01 then d.pts[#d.pts + 1] = { p[1], p[2] } end
    end
    if #d.pts < 2 then d.mode = 'FAIL'; d.err = 'trajet de moins de 2 points distincts'; return d end
    d.cum = { 0 }
    for i = 2, #d.pts do
        local dx, dz = d.pts[i][1] - d.pts[i - 1][1], d.pts[i][2] - d.pts[i - 1][2]
        d.cum[i] = d.cum[i - 1] + math.sqrt(dx * dx + dz * dz)
    end
    d.total = d.cum[#d.pts]
    d.mode = 'INIT'; d.s = 0; d.seg = 1; d.filtered = 0
    d.recoveries = 0; d.uturns = 0; d.status = 'init'; d.maxCross = 0
    return d
end
function Driver:segForS(s)
    local i = 1
    while i < #self.pts - 1 and self.cum[i + 1] < s do i = i + 1 end
    return i
end
function Driver:projectRange(x, z, i1, i2)
    local bestD, bestS, bestI = math.huge, 0, i1
    for i = math.max(1, i1), math.min(#self.pts - 1, i2) do
        local ax, az, dx, dz, len = segInfo(self.pts, i)
        local t = clamp(((x - ax) * dx + (z - az) * dz) / (len * len), 0, 1)
        local px, pz = ax + dx * t, az + dz * t
        local dd = math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)
        if dd < bestD then bestD = dd; bestS = self.cum[i] + len * t; bestI = i end
    end
    return bestS, bestD, bestI
end
function Driver:pointAt(s)
    s = clamp(s, 0, self.total)
    local i = self:segForS(s)
    local ax, az, dx, dz, len = segInfo(self.pts, i)
    local t = (s - self.cum[i]) / len
    return ax + dx * t, az + dz * t, dx / len, dz / len
end
function Driver:speedLimit()
    local c = self.cfg
    local limit = c.cruiseSpeed
    -- virage LOCAL (sur 14 studs) a chaque distance devant : une longue courbe douce
    -- ne bride plus la vitesse comme dans la v0.8.0
    for _, ahead in ipairs({ 0, 6, 12, 18, 24, 32, 40, 50, 60, 75 }) do
        if self.s + ahead + 4 > self.total then break end
        local _, _, ax, az = self:pointAt(self.s + ahead)
        local _, _, bx, bz = self:pointAt(math.min(self.total, self.s + ahead + 14))
        local turn = math.abs(signedAngle(ax, az, bx, bz))
        local vAt = c.cruiseSpeed - (c.cruiseSpeed - c.turnSpeed) * clamp(turn / 0.8, 0, 1)
        local allowed = math.sqrt(vAt * vAt + 2 * c.decel * ahead)
        if allowed < limit then limit = allowed end
    end
    local remaining = self.total - self.s
    local stopAllowed = math.sqrt(c.arriveSpeed ^ 2 + 2 * c.decel * math.max(0, remaining - c.arriveRadius))
    return math.min(limit, stopAllowed)
end
function Driver:fail(msg)
    self.mode = 'FAIL'; self.err = msg; self.status = 'ECHEC : ' .. msg
    return { fwd = false, back = false, left = false, right = false }
end
-- o = { t, x, z, lx, lz (LookVector), vx, vz (vitesse), yaw (AssemblyAngularVelocity.Y, >0 = vers la gauche) }
function Driver:step(o)
    local c = self.cfg
    local cmd = { fwd = false, back = false, left = false, right = false }
    if self.mode == 'FAIL' or self.mode == 'DONE' then return cmd end
    local ll = math.sqrt(o.lx * o.lx + o.lz * o.lz)
    if ll < 1e-6 then return self:fail('orientation du siege invalide') end
    local fx, fz = o.lx / ll, o.lz / ll
    local fwdSpeed = o.vx * fx + o.vz * fz
    local speed = math.sqrt(o.vx * o.vx + o.vz * o.vz)
    if self.mode == 'INIT' then
        local s, dist, i = self:projectRange(o.x, o.z, 1, #self.pts - 1)
        if dist > c.maxStartDist then
            return self:fail(string.format('voiture a %.0f studs du trajet (max %d)', dist, c.maxStartDist))
        end
        self.s = s; self.seg = i; self.bestS = s; self.lastProg = o.t; self.t0 = o.t; self.lastT = o.t; self.pulse0 = o.t
        self.startS = s
        self.mode = 'RUN'
    end
    local dt = clamp(o.t - self.lastT, 0, 0.5); self.lastT = o.t
    if o.t - self.t0 > c.timeoutBase + self.total / c.timeoutSpeed then return self:fail('delai global du trajet depasse') end

    if self.mode ~= 'STOPPING' then
        local s, dist = self:projectRange(o.x, o.z, self.seg - 1, self.seg + 3)
        if s > self.s then self.s = s end
        self.seg = self:segForS(self.s)
        self.cross = dist
        if dist > self.maxCross then self.maxCross = dist end
    end
    local remaining = self.total - self.s
    local ex, ez = self.pts[#self.pts][1], self.pts[#self.pts][2]
    local endDist = math.sqrt((ex - o.x) ^ 2 + (ez - o.z) ^ 2)
    if self.mode ~= 'STOPPING' and (endDist < c.arriveRadius or (remaining < c.arriveRadius and endDist < c.arriveRadius * 2)) then
        self.mode = 'STOPPING'; self.stopT = o.t
    end
    if self.mode == 'STOPPING' then
        if c.brake and fwdSpeed > 1 and o.t - self.stopT < c.stopTimeout then
            cmd.back = true
        elseif speed > 3 and o.t - self.stopT >= c.stopTimeout then
            return self:fail('stationnement non confirme : voiture encore en mouvement')
        elseif speed <= 3 and o.t - self.stopT >= 0.3 then
            self.mode = 'DONE'
            self.status = string.format('ARRIVE (%.1f studs du dernier point, %.1f studs/s)', endDist, speed)
        end
        self.endDist = endDist
        return cmd
    end

    local uturning = (self.mode == 'UTURN_FWD' or self.mode == 'UTURN_REV')
    local look = uturning and c.uturnLook or clamp(c.lookMin + c.lookGain * speed, c.lookMin, c.lookMax)
    local tx, tz = self:pointAt(self.s + look)
    if remaining < look then tx, tz = ex, ez end
    local dx, dz = tx - o.x, tz - o.z
    local angle = (dx * dx + dz * dz > 0.01) and signedAngle(fx, fz, dx, dz) or 0
    self.angle = angle

    if self.mode == 'RUN' then
        if math.abs(angle) > c.uturnEnter then
            if self.uturns >= c.uturnMaxAttempts then return self:fail('demi-tour impossible apres ' .. self.uturns .. ' essais') end
            self.mode = 'UTURN_FWD'; self.uDir = angle > 0 and 1 or -1
            self.phaseT = o.t; self.uturns = self.uturns + 1
            self.bestAngle = math.abs(angle); self.uImproveT = o.t
        elseif o.t - self.lastProg > c.stuckSeconds then
            if self.recoveries >= c.maxRecoveries then
                return self:fail(string.format('bloque au segment %d/%d apres %d degagements', self.seg, #self.pts - 1, self.recoveries))
            end
            self.recoveries = self.recoveries + 1
            self.mode = 'RECOVER'; self.phaseT = o.t; self.recDir = angle > 0 and -1 or 1
        end
    end

    if self.mode == 'UTURN_FWD' then
        if math.abs(angle) < c.uturnExit then
            self.mode = 'RUN'; self.lastProg = o.t; self.bestS = self.s; self.filtered = 0
        else
            if math.abs(angle) < self.bestAngle - 0.05 then self.bestAngle = math.abs(angle); self.uImproveT = o.t end
            cmd.right = self.uDir > 0; cmd.left = self.uDir < 0
            if fwdSpeed < c.uturnSpeed then cmd.fwd = true
            elseif c.brake and fwdSpeed > c.uturnSpeed + 3 then cmd.back = true end
            if o.t - self.uImproveT > c.uturnNoGain or o.t - self.phaseT > c.uturnFwdMax then
                self.mode = 'UTURN_REV'; self.phaseT = o.t
            end
        end
    elseif self.mode == 'UTURN_REV' then
        if math.abs(angle) < c.uturnExit then
            self.mode = 'RUN'; self.lastProg = o.t; self.bestS = self.s; self.filtered = 0
        elseif o.t - self.phaseT > c.uturnRevTime then
            if self.uturns >= c.uturnMaxAttempts then return self:fail('demi-tour impossible apres ' .. self.uturns .. ' essais') end
            self.uturns = self.uturns + 1
            self.mode = 'UTURN_FWD'; self.phaseT = o.t; self.bestAngle = math.abs(angle); self.uImproveT = o.t
        else
            cmd.back = true
            -- en marche arriere, braquer a l'oppose fait pivoter l'avant vers la cible
            cmd.left = self.uDir > 0; cmd.right = self.uDir < 0
        end
    elseif self.mode == 'RECOVER' then
        if o.t - self.phaseT > c.recoverTime then
            self.mode = 'RUN'; self.lastProg = o.t; self.bestS = self.s
        else
            cmd.back = true
            cmd.right = self.recDir > 0; cmd.left = self.recDir < 0
        end
    end

    if self.mode == 'RUN' then
        if self.s > self.bestS + 1.5 then self.bestS = self.s; self.lastProg = o.t end
        local demand = clamp(c.kp * angle + c.kd * (o.yaw or 0), -1, 1)
        self.filtered = self.filtered + (demand - self.filtered) * clamp(dt / c.steerTau, 0, 1)
        local duty = math.abs(self.filtered)
        local phase = ((o.t - self.pulse0) % c.pwmPeriod) / c.pwmPeriod
        local turning = duty > c.deadband and (duty >= 0.98 or phase < duty)
        cmd.right = turning and self.filtered > 0
        cmd.left = turning and self.filtered < 0
        local limit = math.min(self:speedLimit(),
            c.cruiseSpeed - (c.cruiseSpeed - c.turnSpeed) * clamp(math.abs(angle) / c.angleSlow, 0, 1))
        if c.nativeStraight and limit >= c.cruiseSpeed - 0.01 and math.abs(angle) < 0.15 then limit = math.huge end
        self.limit = limit
        if fwdSpeed < limit - 0.5 then cmd.fwd = true
        elseif c.brake and fwdSpeed > limit + c.brakeMargin and fwdSpeed > 2 then cmd.back = true end
    end
    self.status = string.format('%s seg %d/%d | reste %.0f | %.1f studs/s | cap %+.0f deg',
        self.mode, self.seg, #self.pts - 1, remaining, fwdSpeed, math.deg(angle))
    return cmd
end

if E.__BLOCKSPIN_PURE_TEST then
    return { Hub = Hub, Driver = Driver, DRIVE_DEFAULTS = DRIVE_DEFAULTS, validateData = validateData, DEFAULT_DATA = DEFAULT_DATA, fold = fold }
end

---------------------------------------------------------------------------
-- 2. ARRET DES ANCIENNES VERSIONS (y compris une instance precedente de celle-ci)
---------------------------------------------------------------------------
for _, key in ipairs({ 'BlockSpinCycle080', 'BlockSpinV068', 'BlockSpinV067', 'BlockSpinV066', 'BlockSpinV065',
    'BlockSpinV064', 'BlockSpinV063', 'BlockSpinInventoryGuard', 'BlockSpinV062', 'BlockSpinV061', 'BlockSpinV060',
    'BlockSpinDriveTest069', 'BlockSpinDriveAuto070', 'BlockSpinDriveTest071', 'BlockSpinDriveTest072',
    'BlockSpinDriveTest073', 'BlockSpinDriveTest074' }) do
    local old = E[key]
    if type(old) == 'table' and type(old.stop) == 'function' then pcall(old.stop) end
    E[key] = nil
end
if E.BlockSpinTeleportConnection then
    pcall(function() E.BlockSpinTeleportConnection:Disconnect() end)
    E.BlockSpinTeleportConnection = nil
end

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UIS = game:GetService('UserInputService')
local VIM = game:GetService('VirtualInputManager')
local HttpService = game:GetService('HttpService')
local PathfindingService = game:GetService('PathfindingService')
local player = Players.LocalPlayer
local pg = player:WaitForChild('PlayerGui')

local S = {
    running = true, version = VERSION, state = 'IDLE', detail = '',
    clicks = 0, rounds = 0, method = '-',
    fishingEnabled = true, autoCycle = false, cycleRunning = false, cycleFailures = 0,
    autoCast = true, castDelay = 0.35, retryDelay = 8, castAttempts = 0,
    inventoryLimit = 18, fishCount = nil, inventoryFull = false, paused = false,
    inventoryText = 'inconnu', inventorySource = 'none',
    baitCount = nil, baitEmpty = false, baitUnknown = true,
    sellHoldSeconds = 3.5, sellAttempts = 0, lastSellError = nil, lastRouteError = nil,
    sellStage = 'idle', driveStatus = 'idle', depositStatus = 'idle',
    autoSell = true, autoBank = true, depositRequired = false,
    recording = false, recordBuffer = {}, baitScreenPoint = nil,
    car = nil, keyErrors = 0, lastKeyError = nil,
    cfg = { drive = {} }, log = {}, token = 0,
}
for k, v in pairs(DRIVE_DEFAULTS) do S.cfg.drive[k] = v end
S.hub = Hub.new(os.clock())
S.cfg.keys = { forward = Enum.KeyCode.W, back = Enum.KeyCode.S, left = Enum.KeyCode.A, right = Enum.KeyCode.D }
E.BlockSpinCycle080 = S

local conns = {}
local gui, stateLabel, infoLabel, logLabel

local function logLine(msg)
    local line = string.format('[%s] %s', os.date and os.date('%H:%M:%S') or tostring(os.clock()), tostring(msg))
    table.insert(S.log, line)
    while #S.log > 80 do table.remove(S.log, 1) end
    print('[BlockSpin ' .. VERSION .. '] ' .. tostring(msg))
    if logLabel and logLabel.Parent then
        local t = {}
        for i = math.max(1, #S.log - 7), #S.log do t[#t + 1] = S.log[i] end
        logLabel.Text = table.concat(t, '\n')
    end
end
local function setState(state, detail)
    if state ~= S.state then logLine('ETAT ' .. S.state .. ' -> ' .. state .. (detail and (' : ' .. detail) or '')) end
    if state == 'ERROR' then S.hub:error(state, detail, os.clock()) end
    S.state = state
    S.detail = detail or ''
    if S.toast and state ~= S.lastToastState then
        if state == 'ERROR' then S.toast(S.detail ~= '' and S.detail or 'Erreur', 'error')
        elseif state == 'NO_BAIT' then S.toast('Plus d\'appats : lancers arretes', 'error') end
    end
    S.lastToastState = state
    local txt = S.design and S.design.stateText(state,S.detail) or (state .. (S.detail ~= '' and (' | ' .. S.detail) or ''))
    if stateLabel and stateLabel.Parent and stateLabel.Text ~= txt then stateLabel.Text = txt end
end
local function update(detail) -- detail sans changer d'etat (compat v0.6.8)
    S.detail = detail
    local txt = S.design and S.design.stateText(S.state,detail) or (S.state .. ' | ' .. tostring(detail))
    if stateLabel and stateLabel.Parent and stateLabel.Text ~= txt then stateLabel.Text = txt end
end

---------------------------------------------------------------------------
-- 3. TOUCHES : suivi par KeyCode reellement presse (pas par mapping)
---------------------------------------------------------------------------
local held = {}
local function sendKey(code, down)
    if (held[code] == true) == down then return true end
    local ok, err = pcall(function() VIM:SendKeyEvent(down, code, false, game) end)
    if ok then
        held[code] = down or nil
    else
        S.keyErrors = S.keyErrors + 1
        S.lastKeyError = tostring(err)
        if not down then held[code] = nil end
        logLine('ERREUR touche ' .. tostring(code) .. ' ' .. (down and 'appui' or 'relache') .. ' : ' .. tostring(err))
    end
    return ok
end
local function releaseAll()
    for code in pairs(held) do sendKey(code, false) end
end
local function applyCmd(cmd)
    local k = S.cfg.keys
    local want = { [k.forward] = cmd.fwd, [k.back] = cmd.back, [k.left] = cmd.left, [k.right] = cmd.right }
    for code in pairs(held) do if not want[code] then sendKey(code, false) end end
    for code, down in pairs(want) do if down then sendKey(code, true) end end
end
local mouseHeld = false
local mouseHeldVia
local function releaseMouse()
    if not mouseHeld then return end
    mouseHeld = false
    if mouseHeldVia~='native' and type(mouse1release) == 'function' then pcall(mouse1release) end
    mouseHeldVia=nil
    pcall(function()
        local m = UIS:GetMouseLocation()
        VIM:SendMouseButtonEvent(m.X, m.Y, 0, false, game, 0)
    end)
end

---------------------------------------------------------------------------
-- 4. ANNULATION : jeton de generation
---------------------------------------------------------------------------
local function alive(tok) return S.running and tok == S.token end
local function sleep(sec, tok)
    local t1 = os.clock() + sec
    while os.clock() < t1 do
        if not alive(tok) then return false end
        task.wait(math.min(0.1, t1 - os.clock() + 0.01))
    end
    return alive(tok)
end

---------------------------------------------------------------------------
-- 5. DONNEES (fichier JSON, jamais ecrase automatiquement)
---------------------------------------------------------------------------
local DATA_FILE = 'blockspin_data_v080.json'
S.dataSource = 'defauts integres (route_data.json)'
S.data = validateData(DEFAULT_DATA)
local function loadData()
    if type(readfile) ~= 'function' or type(isfile) == 'function' and not isfile(DATA_FILE) then
        return false, 'pas de fichier ' .. DATA_FILE .. ' : defauts integres utilises'
    end
    local ok, decoded = pcall(function() return HttpService:JSONDecode(readfile(DATA_FILE)) end)
    if not ok then return false, 'lecture/JSON invalide : ' .. tostring(decoded) end
    local d, err = validateData(decoded)
    if not d then return false, DATA_FILE .. ' rejete : ' .. err end
    S.data = d; S.dataSource = DATA_FILE
    return true, 'donnees chargees depuis ' .. DATA_FILE
end
local function saveData()
    if type(writefile) ~= 'function' then return false, 'writefile indisponible' end
    local d, err = validateData(S.data)
    if not d then return false, 'donnees invalides, rien ecrit : ' .. err end
    if type(isfile) == 'function' and type(readfile) == 'function' and isfile(DATA_FILE) then
        pcall(function() writefile(DATA_FILE .. '.bak', readfile(DATA_FILE)) end)
    end
    local ok, e2 = pcall(function() writefile(DATA_FILE, HttpService:JSONEncode(d)) end)
    return ok, ok and ('sauvegarde dans ' .. DATA_FILE .. ' (ancienne copie .bak)') or tostring(e2)
end
S.loadData = loadData; S.saveData = saveData
function S.importV068()
    if type(readfile) ~= 'function' then return false, 'readfile indisponible' end
    local ok, d = pcall(function() return HttpService:JSONDecode(readfile('blockspin_route_v068.json')) end)
    if not ok or type(d) ~= 'table' then return false, 'blockspin_route_v068.json illisible' end
    local cand = {
        route_to_vendor = d.points, route_to_fishing = S.data.route_to_fishing,
        fish = d.fish or S.data.fish, vendor = d.vendor or S.data.vendor, atm = d.atm or S.data.atm }
    local v, err = validateData(cand)
    if not v then return false, err end
    S.data = v
    return true, 'v0.6.8 importe (aller seulement ; retour conserve). bouton Sauvegarder les donnees.'
end
local function v3(p) return Vector3.new(p[1], p[2], p[3]) end
local function cfOf(a) return CFrame.new(table.unpack(a)) end

---------------------------------------------------------------------------
-- 6. PERSONNAGE / VEHICULE
---------------------------------------------------------------------------
local function character() return player.Character end
local function humanoid() local c = character(); return c and c:FindFirstChildOfClass('Humanoid') end
local function getRoot() local c = character(); return c and c:FindFirstChild('HumanoidRootPart') end
local function currentSeat()
    local h = humanoid(); local p = h and h.SeatPart
    if p and p:IsA('VehicleSeat') then return p end
end
local function rememberCar(seat)
    seat = seat or currentSeat()
    if not seat then return false, 'monte au volant pour memoriser la voiture' end
    local model = seat.Parent
    S.car = { seat = seat, model = model, name = model and model.Name or '?', path = seat:GetFullName() }
    local motors = model and model:FindFirstChild('Motors')
    S.car.maxSpeedAttr = motors and motors:GetAttribute('forwardMaxSpeed')
    logLine('Voiture memorisee : ' .. S.car.path .. ' (forwardMaxSpeed=' .. tostring(S.car.maxSpeedAttr) .. ', unite inconnue)')
    return true
end
S.rememberCar = rememberCar
local function carValid()
    return S.car and S.car.seat and S.car.seat.Parent and S.car.seat:IsDescendantOf(workspace)
end

---------------------------------------------------------------------------
-- 7. CONDUITE (boucle Roblox autour du Driver pur)
---------------------------------------------------------------------------
local function driveRoute(points3, label, tok)
    local seat = currentSeat()
    if not seat then return false, 'pas au volant' end
    local pts = {}
    for i, p in ipairs(points3) do pts[i] = { p[1], p[3] } end
    local d = Driver.new(pts, Hub.copy(S.cfg.drive))
    S.driver = d
    local ok, res, msg = pcall(function()
        while true do
            if not alive(tok) then return false, 'annule' end
            if currentSeat() ~= seat then return false, 'siege conducteur perdu' end
            if UIS:GetFocusedTextBox() then return false, 'saisie texte active : conduite interrompue' end
            local pos, look = seat.Position, seat.CFrame.LookVector
            local vel, ang = seat.AssemblyLinearVelocity, seat.AssemblyAngularVelocity
            local cmd = d:step({ t = os.clock(), x = pos.X, z = pos.Z, lx = look.X, lz = look.Z, vx = vel.X, vz = vel.Z, yaw = ang.Y })
            applyCmd(cmd)
            S.driveStatus = label .. ' | ' .. tostring(d.status)
            update(S.driveStatus .. (S.keyErrors > 0 and (' | erreurs touches ' .. S.keyErrors) or ''))
            if d.mode == 'DONE' then return true, d.status end
            if d.mode == 'FAIL' then return false, d.err end
            task.wait(S.cfg.drive.dt)
        end
    end)
    if alive(tok) then releaseAll() end
    if not ok then return false, 'erreur interne conduite : ' .. tostring(res) end
    if res and seat.AssemblyLinearVelocity.Magnitude > 3 then
        logLine('Attention : touches relachees mais la voiture roule encore (' .. math.floor(seat.AssemblyLinearVelocity.Magnitude) .. ' studs/s)')
    end
    return res, msg
end

---------------------------------------------------------------------------
-- 8. MARCHE (Humanoid:MoveTo + PathfindingService, deplacement natif)
---------------------------------------------------------------------------
local function walkTo(goal, radius, tok, what)
    if not alive(tok) then return false, 'annule' end
    radius = radius or 5
    local hum, root = humanoid(), getRoot()
    if not hum or not root then return false, 'personnage absent' end
    if hum.SeatPart then return false, 'encore assis' end
    local function flatDist() local p = root.Position; return Vector3.new(p.X - goal.X, 0, p.Z - goal.Z).Magnitude end
    if flatDist() <= radius then return true end
    local waypoints
    local okPath, path = pcall(function()
        local p = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
        p:ComputeAsync(root.Position, goal)
        return p
    end)
    if okPath and path and path.Status == Enum.PathStatus.Success then
        waypoints = path:GetWaypoints()
    else
        logLine('Pathfinding indisponible vers ' .. what .. ' : marche directe')
        waypoints = { { Position = goal, Action = Enum.PathWaypointAction.Walk } }
    end
    local began = os.clock()
    for i, wp in ipairs(waypoints) do
        if i > 1 or #waypoints == 1 then
            local wpBegan, lastIssue = os.clock(), -1
            local p0 = root.Position
            local wpLimit = math.max(6, Vector3.new(p0.X - wp.Position.X, 0, p0.Z - wp.Position.Z).Magnitude / 8 + 2)
            while true do
                if not alive(tok) then return false, 'annule' end
                if hum.SeatPart then return false, 'assis pendant la marche' end
                if hum.Health <= 0 then return false, 'personnage mort' end
                if flatDist() <= radius then hum:MoveTo(root.Position); return true end
                local p = root.Position
                if Vector3.new(p.X - wp.Position.X, 0, p.Z - wp.Position.Z).Magnitude < 3 then break end
                if os.clock() - lastIssue > 2 then
                    hum:MoveTo(wp.Position); lastIssue = os.clock()
                    if wp.Action == Enum.PathWaypointAction.Jump then hum.Jump = true end
                end
                if os.clock() - wpBegan > wpLimit then return false, 'marche bloquee vers ' .. what .. ' (porte/obstacle ?)' end
                if os.clock() - began > 60 then return false, 'marche trop longue vers ' .. what end
                task.wait(0.1)
            end
        end
    end
    local t1 = os.clock() + 4
    while os.clock() < t1 do
        if not alive(tok) then return false, 'annule' end
        if flatDist() <= radius then hum:MoveTo(root.Position); return true end
        hum:MoveTo(goal); task.wait(0.2)
    end
    return false, string.format('arrivee non atteinte vers %s (%.0f studs)', what, flatDist())
end

---------------------------------------------------------------------------
-- 9. GUI DU JEU : visibilite, clics, scans
---------------------------------------------------------------------------
local function shown(o)
    if not o or not o:IsA('GuiObject') then return false end
    local p = o
    while p and p ~= pg do
        if p:IsA('GuiObject') and not p.Visible then return false end
        if p:IsA('ScreenGui') and not p.Enabled then return false end
        p = p.Parent
    end
    return p == pg
end
local function ours(o) return gui and o:IsDescendantOf(gui) end
local function clickAt(x, y)
    if type(mousemoveabs) == 'function' then pcall(mousemoveabs, x, y) end
    return pcall(function()
        VIM:SendMouseMoveEvent(x, y, game)
        VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.1)
        VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
end
local function clickGui(button)
    if not button or not shown(button) then return false end
    local pos = button.AbsolutePosition + button.AbsoluteSize / 2
    return clickAt(math.floor(pos.X), math.floor(pos.Y))
end
local function visibleButtons()
    local out = {}
    for _, o in ipairs(pg:GetDescendants()) do
        if (o:IsA('TextButton') or o:IsA('ImageButton')) and not ours(o) and shown(o) and o.AbsoluteSize.X > 35 then out[#out + 1] = o end
    end
    return out
end
local function buttonByText(patterns)
    for _, o in ipairs(visibleButtons()) do
        local txt = fold(o:IsA('TextButton') and o.Text or '')
        if txt == '' then
            local l = o:FindFirstChildWhichIsA('TextLabel', true)
            txt = l and fold(l.Text) or ''
        end
        for _, p in ipairs(patterns) do if txt:find(p, 1, true) then return o end end
    end
end
local function nearbyPrompts(radius, within)
    local root = getRoot(); local out = {}
    if not root then return out end
    for _, obj in ipairs((within or workspace):GetDescendants()) do
        if obj:IsA('ProximityPrompt') and obj.Enabled then
            local part = obj.Parent
            local base = part and (part:IsA('BasePart') and part or part:FindFirstAncestorWhichIsA('BasePart'))
            if not base and part and part:IsA('Attachment') then base = part.Parent end
            if base and base:IsA('BasePart') then
                local dist = (base.Position - root.Position).Magnitude
                if dist < radius then out[#out + 1] = { prompt = obj, dist = dist, tag = fold(obj.Name .. ' ' .. obj.ActionText .. ' ' .. obj.ObjectText .. ' ' .. base.Name) } end
            end
        end
    end
    table.sort(out, function(a, b) return a.dist < b.dist end)
    return out
end
local function triggerPrompt(entry, tok)
    if not alive(tok) then return 'annule' end
    local pr = entry.prompt
    if type(fireproximityprompt) == 'function' then
        local ok = pcall(fireproximityprompt, pr)
        if ok then return 'fireproximityprompt' end
    end
    local code = pr.KeyboardKeyCode or Enum.KeyCode.E
    sendKey(code, true)
    sleep(math.max(0.15, (pr.HoldDuration or 0) + 0.2), tok)
    if alive(tok) then sendKey(code, false) end
    return 'touche ' .. tostring(code)
end
local function pressE(tok)
    if not alive(tok) then return end
    sendKey(Enum.KeyCode.E, true); sleep(0.15, tok)
    if alive(tok) then sendKey(Enum.KeyCode.E, false) end
end
local function promptByWords(radius, words)
    for _, e in ipairs(nearbyPrompts(radius)) do
        for _, w in ipairs(words) do if e.tag:find(w, 1, true) then return e end end
    end
end

---------------------------------------------------------------------------
-- 10. ENTREE / SORTIE DE LA MEME VOITURE
---------------------------------------------------------------------------
local function exitCar(tok)
    if not alive(tok) then return false, 'annule' end
    local hum = humanoid()
    if not hum then return false, 'humanoid absent' end
    if not hum.SeatPart then return true, 'deja a pied' end
    local seat = hum.SeatPart
    local t1 = os.clock() + 3
    while os.clock() < t1 and alive(tok) and seat.AssemblyLinearVelocity.Magnitude > 2 do
        sendKey(S.cfg.keys.back, true); task.wait(0.1)
    end
    if not alive(tok) then return false, 'annule' end
    sendKey(S.cfg.keys.back, false)
    hum.Jump = true
    if sleep(0.8, tok) and not hum.SeatPart then return true, 'sortie (saut)' end
    if not alive(tok) then return false, 'annule' end
    pcall(function() hum.Sit = false end)
    if sleep(0.8, tok) and not hum.SeatPart then return true, 'sortie (Sit=false)' end
    return false, 'impossible de quitter le siege'
end
local function enterCar(tok)
    if not alive(tok) then return false, 'annule' end
    if not carValid() then return false, 'voiture memorisee introuvable (disparue ?)' end
    local seat = S.car.seat
    if currentSeat() == seat then return true, 'deja au volant' end
    local hum, root = humanoid(), getRoot()
    if not hum or not root then return false, 'personnage absent' end
    -- point d'approche a ~5 studs du siege, du cote du joueur
    local side = seat.CFrame.RightVector
    local a, b = seat.Position - side * 5, seat.Position + side * 5
    local approach = ((a - root.Position).Magnitude < (b - root.Position).Magnitude) and a or b
    local ok, err = walkTo(approach, 3.5, tok, 'voiture')
    if not ok and (root.Position - seat.Position).Magnitude > 9 then return false, 'approche voiture : ' .. tostring(err) end
    if not alive(tok) then return false, 'annule' end
    -- 1) ProximityPrompt de la voiture le plus proche du siege
    local best
    for _, e in ipairs(nearbyPrompts(15, S.car.model)) do
        local w = e.tag
        local score = e.dist - ((w:find('driv', 1, true) or w:find('condu', 1, true) or w:find('seat', 1, true) or w:find('enter', 1, true) or w:find('monter', 1, true)) and 10 or 0)
        if not best or score < best.score then best = { entry = e, score = score } end
    end
    if best then
        local how = triggerPrompt(best.entry, tok)
        if sleep(1.5, tok) and currentSeat() == seat then logLine('Entree voiture OK via prompt (' .. how .. ')'); return true, 'prompt' end
    end
    if not alive(tok) then return false, 'annule' end
    -- 2) marcher sur le siege (contact = assise native d'un Seat Roblox)
    hum:MoveTo(seat.Position)
    local t1 = os.clock() + 3
    while os.clock() < t1 and alive(tok) do
        if currentSeat() == seat then logLine('Entree voiture OK par contact'); return true, 'contact' end
        task.wait(0.1)
    end
    if not alive(tok) then return false, 'annule' end
    -- 3) Seat:Sit cote client (peut etre refuse par le jeu)
    pcall(function() seat:Sit(hum) end)
    if sleep(1.2, tok) and currentSeat() == seat then logLine('Entree voiture OK via Seat:Sit'); return true, 'Sit' end
    if currentSeat() and currentSeat() ~= seat then return false, 'assis dans un AUTRE siege : ' .. currentSeat():GetFullName() end
    return false, 'entree voiture echouee (prompt=' .. tostring(best ~= nil) .. ') : Settings > Diagnostic pres de la voiture'
end

---------------------------------------------------------------------------
-- 11. INVENTAIRE / APPATS (logique v0.6.8)
---------------------------------------------------------------------------
local capCache, capNextScan = nil, 0
local function parseCap(obj)
    local a, b = tostring(obj.Text):match('^%s*(%d+)%s*/%s*(%d+)%s*$')
    a, b = tonumber(a), tonumber(b)
    if a and b and b == S.inventoryLimit and a <= b then return a, b end
end
local function readCapacity(force)
    local items = pg:FindFirstChild('Items')
    if not items then return nil end
    if capCache and capCache.obj.Parent and capCache.obj:IsDescendantOf(items) then
        local a, b = parseCap(capCache.obj)
        if a then return { count = a, limit = b, depth = capCache.depth, path = capCache.path } end
    end
    -- etiquette perdue : recherche complete, mais pas plus d'une fois toutes les 3 s
    if not force and os.clock() < capNextScan then return nil end
    capNextScan = os.clock() + 3
    local best
    for _, obj in ipairs(items:GetDescendants()) do
        if obj:IsA('TextLabel') or obj:IsA('TextButton') then
            local a, b = tostring(obj.Text):match('^%s*(%d+)%s*/%s*(%d+)%s*$')
            a, b = tonumber(a), tonumber(b)
            if a and b and b == S.inventoryLimit and a <= b then
                local depth, p = 0, obj
                while p and p ~= items do depth = depth + 1; p = p.Parent end
                if not best or depth < best.depth then best = { count = a, limit = b, depth = depth, path = obj:GetFullName(), obj = obj } end
            end
        end
    end
    if best then capCache = { obj = best.obj, depth = best.depth, path = best.path }; capNextScan = 0 end
    return best
end
S.readCapacity = readCapacity
local lastCast = -1e6
function S.checkInventory()
    local info = readCapacity()
    if info then
        local wasFull = S.inventoryFull
        S.inventoryText = info.count .. '/' .. info.limit
        S.inventorySource = info.path
        S.fishCount = info.count -- = emplacements occupes, pas seulement des poissons
        S.inventoryFull = (info.count >= info.limit)
        if S.inventoryFull and not wasFull then
            logLine('INVENTAIRE ' .. S.inventoryText .. ' : lancers suspendus')
            if S.toast then S.toast('Inventaire plein (' .. S.inventoryText .. ')' .. (S.autoCycle and ' : vente auto' or ' : peche en pause'), 'warn') end
        elseif wasFull and not S.inventoryFull then
            S.sellAttempts = 0; lastCast = -1e6
            logLine('INVENTAIRE ' .. S.inventoryText .. ' : peche deverrouillee')
            if S.toast then S.toast('Inventaire libere (' .. S.inventoryText .. ') : la peche reprend', 'ok') end
        end
    end
    return info
end
function S.setFishCount(n)
    if type(n) ~= 'number' or n < 0 then return false end
    S.fishCount = math.floor(n); S.inventoryFull = (S.fishCount >= S.inventoryLimit)
    return true
end
local baitCache, baitNextScan = nil, 0
local function checkBait()
    local found
    if baitCache and baitCache.Parent and baitCache:IsDescendantOf(pg) and shown(baitCache) then
        local c = tostring(baitCache.Text):match('[xX]%s*(%d+)%s*$')
        found = tonumber(c)
    end
    if found == nil then
        S.baitUnknown=true;S.baitEmpty=false
        if os.clock() < baitNextScan then return end
        baitNextScan = os.clock() + 10
        baitCache = nil
        for _, o in ipairs(pg:GetDescendants()) do
            if (o:IsA('TextLabel') or o:IsA('TextButton')) and fold(o.Text):find('prawntec', 1, true) and not ours(o) and shown(o) then
                local inline = tostring(o.Text):match('[xX]%s*(%d+)%s*$')
                if inline then found = tonumber(inline); baitCache = o end
                local parent = o.Parent
                if found == nil and parent then
                    for _, near in ipairs(parent:GetDescendants()) do
                        if (near:IsA('TextLabel') or near:IsA('TextButton')) and shown(near) and not ours(near) then
                            local c = tostring(near.Text):match('^%s*[xX]%s*(%d+)%s*$')
                            if c then found = tonumber(c); baitCache = near; break end
                        end
                    end
                end
            end
            if found ~= nil then break end
        end
    end
    if found ~= nil then
        if S.baitCount ~= found then
            logLine('Appats lus : x' .. found)
            if found == 0 and S.toast then S.toast('Plus d\'appats (x0) : lancers arretes', 'error') end
        end
        S.hub:observeBait(found)
        S.baitCount = found; S.baitEmpty = (found == 0); S.baitUnknown = false
    end
end
function S.setBaitCount(n)
    if type(n) ~= 'number' or n < 0 then return false end
    S.baitCount = math.floor(n); S.baitEmpty = (S.baitCount == 0); S.baitUnknown = false
    return true
end
-- Lecture du portefeuille : cache surveille, scans bornes et choix explicite en cas d'ambiguite.
local findMoney
do
local cached,nextScan,connection=nil,0,nil
S.moneyReading={available=false,value=nil,status='Recherche du compteur',updatedAt=nil}
S.moneyCandidates={}
local function disconnect()
    if connection then connection:Disconnect();connection=nil end
end
S.detachMoneySource=disconnect
local function amount(obj,explicit,attribute)
    if attribute then
        if obj~=player then return nil end
        local n=player:GetAttribute(attribute)
        return isNum(n) and n>=0 and n or nil
    end
    if obj and (obj:IsA('IntValue') or obj:IsA('NumberValue')) then
        local tag=fold(obj.Name)
        if not obj.Parent or not obj:IsDescendantOf(player) or (not explicit and tag~='cash' and tag~='wallet' and tag~='money' and tag~='argent') then return nil end
        return isNum(obj.Value) and obj.Value>=0 and obj.Value or nil
    end
    if not obj or not obj.Parent or not obj:IsDescendantOf(pg) or ours(obj) or not shown(obj) then return nil end
    return Hub.cashText(tostring(obj.Text),explicit)
end
local function use(obj,explicit,attribute)
    if cached and cached.obj==obj and cached.explicit==explicit and cached.attribute==attribute then return end
    disconnect();cached={obj=obj,explicit=explicit,attribute=attribute}
    local signal=attribute and obj:GetAttributeChangedSignal(attribute) or obj:GetPropertyChangedSignal((obj:IsA('IntValue') or obj:IsA('NumberValue')) and 'Value' or 'Text')
    connection=signal:Connect(function()
        if not S.running then return end
        local ok,err=pcall(function() S.pollMoney(false);if S.refreshDashboard then S.refreshDashboard() end end)
        if not ok then S.hub:error('Portefeuille',err,os.clock()) end
    end)
end
findMoney=function(force)
    if cached and not force then
        local n=amount(cached.obj,cached.explicit,cached.attribute)
        if n~=nil then return n,cached.obj:GetFullName()..(cached.attribute and ('[@'..cached.attribute..']') or '') end
        S.moneyReading.status='Compteur masque ou indisponible'
        if not cached.obj.Parent or not cached.obj:IsDescendantOf(pg) then disconnect();cached=nil;nextScan=0 end
    end
    if not force and os.clock()<nextScan then return nil end
    nextScan=os.clock()+10
    local candidates,strong={},{}
    for _,obj in ipairs(pg:GetDescendants()) do
        if (obj:IsA('TextLabel') or obj:IsA('TextButton')) and not ours(obj) and shown(obj) then
            local n,kind=Hub.cashText(tostring(obj.Text),true)
            if n~=nil then
                local entry={obj=obj,value=n,path=obj:GetFullName(),text=tostring(obj.Text),trusted=kind=='label'}
                candidates[#candidates+1]=entry
                if entry.trusted then strong[#strong+1]=entry end
            end
        end
    end
    -- Donnees numeriques publiques si le jeu les replique : aucune API distante supposee.
    local numeric={}
    for _,obj in ipairs(player:GetChildren()) do numeric[#numeric+1]=obj end
    local stats=player:FindFirstChild('leaderstats')
    if stats then for _,obj in ipairs(stats:GetDescendants()) do numeric[#numeric+1]=obj end end
    for _,obj in ipairs(numeric) do
        if obj:IsA('IntValue') or obj:IsA('NumberValue') then
            local tag=fold(obj.Name)
            if tag=='cash' or tag=='money' or tag=='wallet' or tag=='argent' or tag=='bank' or tag=='balance' then
                local n=amount(obj,true)
                if n~=nil then
                    local entry={obj=obj,value=n,path=obj:GetFullName(),text=obj.Name..' : '..tostring(n),trusted=tag=='cash' or tag=='money' or tag=='wallet' or tag=='argent'}
                    candidates[#candidates+1]=entry;if entry.trusted then strong[#strong+1]=entry end
                end
            end
        end
    end
    for key,n in pairs(player:GetAttributes()) do
        local tag=fold(key)
        if isNum(n) and n>=0 and (tag=='cash' or tag=='money' or tag=='wallet' or tag=='argent' or tag=='bank' or tag=='balance') then
            local entry={obj=player,attribute=key,value=n,path=player:GetFullName()..'[@'..key..']',text=key..' : '..tostring(n),trusted=tag=='cash' or tag=='money' or tag=='wallet' or tag=='argent'}
            candidates[#candidates+1]=entry;if entry.trusted then strong[#strong+1]=entry end
        end
    end
    table.sort(candidates,function(a,b) return a.path<b.path end)
    S.moneyCandidates=candidates
    if S.moneySourcePath then
        for _,c in ipairs(candidates) do if c.path==S.moneySourcePath then use(c.obj,true,c.attribute);return c.value,c.path end end
        S.moneyReading.status='Compteur choisi non visible';return nil
    end
    local chosen=strong[1]
    if chosen then
        for _,entry in ipairs(strong) do if entry.value~=chosen.value then chosen=nil;break end end
    end
    if chosen then use(chosen.obj,false,chosen.attribute);return chosen.value,chosen.path end
    S.moneyReading.status=#candidates>0 and 'Choisir le compteur du portefeuille' or 'Aucun compteur visible trouve'
    return nil
end
function S.pollMoney(force)
    local value,path=findMoney(force)
    local reading=S.moneyReading
    reading.available=value~=nil;reading.value=value
    if value~=nil then
        S.hub:observeCash(value,path,os.clock())
        reading.source=path;reading.updatedAt=os.clock();reading.status='Actualisation automatique active'
        return true,'Portefeuille observe : '..tostring(value)
    end
    return false,reading.status
end
function S.chooseMoneySource(path)
    for _,c in ipairs(S.moneyCandidates) do
        if c.path==path and amount(c.obj,true,c.attribute)~=nil then
            S.moneySourcePath=path;use(c.obj,true,c.attribute);return S.pollMoney(false)
        end
    end
    return false,'Ce compteur a disparu : relancer la recherche'
end
function S.searchMoneySources() return S.pollMoney(true) end
function S.configureMoneySource(path)
    disconnect();cached=nil;S.moneySourcePath=path;nextScan=0
    S.moneyReading.available=false;S.moneyReading.value=nil;S.moneyReading.status='Recherche du compteur'
end
function S.resetMoneySource()
    S.configureMoneySource(nil)
    return S.pollMoney(true)
end
end

---------------------------------------------------------------------------
-- 12. VENTE (preuve = baisse du compteur d'inventaire)
---------------------------------------------------------------------------
local function sellButton()
    local items = pg:FindFirstChild('Items')
    local holder = items and items:FindFirstChild('ItemsHolder')
    local b = holder and holder:FindFirstChild('SellAllFishButton')
    if b and b:IsA('GuiObject') and shown(b) and b.AbsoluteSize.X > 25 then return b end
end
local function holdButton(button, seconds, tok)
    local pos = button.AbsolutePosition + button.AbsoluteSize / 2
    local x, y = math.floor(pos.X), math.floor(pos.Y)
    local ok, err = pcall(function()
        if type(mousemoveabs) == 'function' then pcall(mousemoveabs, x, y) end
        VIM:SendMouseMoveEvent(x, y, game)
        mouseHeld = true
        local pressed = false
        if type(mouse1press) == 'function' then pressed = pcall(mouse1press) end
        if not pressed then VIM:SendMouseButtonEvent(x, y, 0, true, game, 0) end
        sleep(seconds, tok)
    end)
    if alive(tok) then
        releaseMouse()
        pcall(function() VIM:SendMouseButtonEvent(x, y, 0, false, game, 0) end)
    end
    return ok, err
end
local function sellAll(tok)
    local cashBefore = findMoney()
    S.hub:observeCash(cashBefore)
    local before = readCapacity(true)
    if not before then return false, 'compteur inventaire illisible avant vente' end
    for attempt = 1, 2 do
        local button, deadline = sellButton(), os.clock() + 10
        while alive(tok) and not button and os.clock() < deadline do
            local e = promptByWords(14, { 'sell', 'fish', 'poisson', 'vend' })
            if e then triggerPrompt(e, tok) else pressE(tok) end
            sleep(0.8, tok); button = sellButton()
        end
        if not alive(tok) then return false, 'annule' end
        if not button then return false, 'bouton SellAllFishButton non affiche (vendeur non ouvert)' end
        update('VENTE : maintien du bouton ' .. S.sellHoldSeconds .. ' s (essai ' .. attempt .. ')')
        local held2, why = holdButton(button, S.sellHoldSeconds, tok)
        if not held2 then return false, 'maintien du clic : ' .. tostring(why) end
        local t1 = os.clock() + 4
        while os.clock() < t1 and alive(tok) do
            local after = readCapacity(true)
            if after and after.count < before.count then
                local cashAfter = findMoney()
                S.hub:transaction('sale-' .. tok .. '-' .. attempt, 'sale', cashBefore, cashAfter, true)
                return true, string.format('vente CONFIRMEE : %d/%d -> %d/%d', before.count, before.limit, after.count, after.limit)
            end
            task.wait(0.3)
        end
    end
    return false, 'aucune baisse d\'inventaire apres 2 essais : vente NON confirmee'
end

---------------------------------------------------------------------------
-- 13. ATM (heuristique non validee ; preuve = baisse de l'argent en main)
---------------------------------------------------------------------------
local function depositAll(tok)
    if not S.autoBank then return true, 'depot desactive' end
    local cashBefore, cashPath = findMoney()
    S.hub:observeCash(cashBefore)
    local opened
    for _ = 1, 3 do
        local e = promptByWords(12, { 'atm', 'guichet', 'argent', 'bank', 'banque', 'distrib' })
        if e then triggerPrompt(e, tok) else pressE(tok) end
        if not sleep(0.8, tok) then return false, 'annule' end
        opened = buttonByText({ 'depot', 'deposit' })
        if opened then break end
    end
    if not opened then return false, 'menu ATM non detecte (bouton DEPOT introuvable) : Settings > Diagnostic devant l\'ATM' end
    if cashBefore == 0 then return true, 'argent en main = 0, rien a deposer' end
    clickGui(opened)
    if not sleep(0.7, tok) then return false, 'annule' end
    -- curseur du montant : glisser jusqu'a l'extremite droite
    local slider
    for _, o in ipairs(pg:GetDescendants()) do
        if o:IsA('GuiObject') and not ours(o) and shown(o) and o.AbsoluteSize.X > 150 and o.AbsoluteSize.Y < 60 then
            local n = o.Name:lower()
            if n:find('slider', 1, true) or n:find('track', 1, true) or n:find('bar', 1, true) then slider = o; break end
        end
    end
    local box
    for _, o in ipairs(pg:GetDescendants()) do
        if o:IsA('TextBox') and not ours(o) and shown(o) then box = o; break end
    end
    if slider then
        local y = math.floor(slider.AbsolutePosition.Y + slider.AbsoluteSize.Y / 2)
        local x0 = math.floor(slider.AbsolutePosition.X + 4)
        local x1 = math.floor(slider.AbsolutePosition.X + slider.AbsoluteSize.X - 2)
        pcall(function()
            VIM:SendMouseMoveEvent(x0, y, game)
            mouseHeld = true
            VIM:SendMouseButtonEvent(x0, y, 0, true, game, 0)
            for i = 1, 10 do
                if not alive(tok) then return end
                VIM:SendMouseMoveEvent(x0 + (x1 - x0) * i / 10, y, game); task.wait(0.03) end
            if not alive(tok) then return end
            VIM:SendMouseMoveEvent(x1 + 30, y, game); task.wait(0.05)
            if not alive(tok) then return end
            VIM:SendMouseButtonEvent(x1, y, 0, false, game, 0)
        end)
        if not alive(tok) then return false, 'annule' end
        releaseMouse()
    elseif box and cashBefore and cashBefore > 0 then
        pcall(function() box.Text = tostring(cashBefore) end)
    else
        return false, 'curseur/champ du montant non identifie : Settings > Diagnostic sur l\'ecran DEPOT'
    end
    if not sleep(0.4, tok) then return false, 'annule' end
    local confirm = buttonByText({ 'confirmer', 'confirm' })
    if not confirm then return false, 'bouton CONFIRMER introuvable' end
    clickGui(confirm)
    if not sleep(1.5, tok) then return false, 'annule' end
    local cashAfter = findMoney()
    if cashBefore and cashAfter and cashAfter < cashBefore then
        S.hub:transaction('deposit-' .. tok, 'deposit', cashBefore, cashAfter, true)
        return true, string.format('depot CONFIRME : argent en main %d -> %d', cashBefore, cashAfter)
    end
    pcall(function() local close = buttonByText({ 'fermer', 'close', 'quitter' }); if close then clickGui(close) end end)
    if not cashBefore then return nil, 'confirmer clique mais solde illisible (' .. tostring(cashPath) .. ') : depot NON verifie' end
    return nil, string.format('solde inchange (%s -> %s) : depot NON confirme', tostring(cashBefore), tostring(cashAfter))
end

---------------------------------------------------------------------------
-- 14. CANNE A PECHE (Tool:Activate uniquement sur un outil de peche)
---------------------------------------------------------------------------
local function isRod(o)
    if not o:IsA('Tool') then return false end
    local n = o.Name:lower()
    return n:find('fish', 1, true) or n:find('rod', 1, true) or n:find('canne', 1, true)
end
local function fishingTool()
    local c = character(); if not c then return nil end
    for _, o in ipairs(c:GetChildren()) do if isRod(o) then return o end end
end
local function equipRod(name)
    local hum = humanoid(); local bp = player:FindFirstChildOfClass('Backpack')
    if fishingTool() then return true end
    if not hum or not bp then return false end
    local tool = name and bp:FindFirstChild(name)
    if not tool then for _, o in ipairs(bp:GetChildren()) do if isRod(o) then tool = o; break end end end
    if not tool then return false end
    pcall(function() hum:EquipTool(tool) end)
    task.wait(0.5)
    return fishingTool() ~= nil
end

---------------------------------------------------------------------------
-- 15. CYCLE : chaque etape = precondition, action, preuve, delai, erreur, annulation
---------------------------------------------------------------------------
local function cancelAll(reason)
    if S.observatory then
        local o=S.observatory;o.queueTicket=(o.queueTicket or 0)+1;o.queueRunning=false;o.queueDeadline=nil;o.queueStatus='Arretee : '..tostring(reason or 'annule')
    end
    S.token = S.token + 1
    S.castTicket=nil;S.castPending=false
    releaseAll(); releaseMouse()
    local h = humanoid(); local r = getRoot()
    if h and r and not h.SeatPart then pcall(function() h:MoveTo(r.Position) end) end
    S.cycleRunning = false
    S.recording = false
    S.hub.farm.running = false
    S.hub:finishStep(false, reason or 'annule', os.clock())
    if reason then logLine('ANNULATION : ' .. reason) end
end
S.cancel = function()
    if S.design and S.design.cancelPointer then S.design.cancelPointer() end
    cancelAll('demande utilisateur (F12)')
    S.autoCycle = false
    S.paused = true
    S.fishingEnabled = false
    if S.refreshToggles then S.refreshToggles() end
    setState('ERROR', 'annule par F12 : cycle auto desactive (S.resume() ou bouton pour reprendre)')
end

function S.performStep(name, timeout, tok, action, verify)
    if not alive(tok) then return false, 'annule' end
    if S.hub.current then return false, 'une etape est deja active' end
    S.hub:beginStep(name, os.clock(), timeout, tok)
    setState(name, '')
    local callOK, ok, detail = pcall(action)
    if not alive(tok) then return false, 'annule' end
    if os.clock() >= S.hub.current.deadline then ok, detail = false, 'delai maximal depasse' end
    if not callOK then detail, ok = ok, false end
    if ok == true and verify then
        local proofOK, proof = pcall(verify)
        if not proofOK or proof ~= true then ok, detail = false, 'preuve de fin absente : ' .. tostring(proof) end
    end
    S.hub:finishStep(ok == true, detail, os.clock())
    return ok == true, detail
end

local function runCycle(manual)
    if S.observatory and S.observatory.queueRunning and not S.observatory.dispatching then return false,'file centrale en cours' end
    if S.cycleRunning or S.recording then return false, 'cycle ou enregistrement deja en cours' end
    S.token = S.token + 1
    local tok = S.token
    S.cycleRunning = true
    task.spawn(function()
        local function fail(stage, msg)
            if not alive(tok) then return end
            releaseAll(); releaseMouse()
            S.cycleRunning = false
            S.lastCycleResult={token=tok,ok=false,detail=tostring(msg)}
            S.cycleFailures = S.cycleFailures + 1
            S.lastRouteError = stage .. ' : ' .. tostring(msg)
            setState('ERROR', S.lastRouteError)
        end
        local ok, err = pcall(function()
            -- preconditions
            if S.depositRequired and not S.autoBank then return fail('PRECONDITION', 'depot exige mais ATM desactive') end
            local info = readCapacity(true)
            if not manual and (not info or info.count < info.limit) then return fail('PRECONDITION', 'inventaire pas plein / illisible') end
            if not carValid() then return fail('PRECONDITION', 'aucune voiture memorisee : monte au volant puis bouton "Memoriser voiture"') end
            local D = Hub.copy(S.data)
            local rodName = fishingTool() and fishingTool().Name
            local hum = humanoid()
            if hum then pcall(function() hum:UnequipTools() end) end

            if currentSeat() ~= S.car.seat then
                setState('TO_CAR', 'marche vers ' .. S.car.name)
                local okE, why = S.performStep('TO_CAR', 80, tok, function() return enterCar(tok) end, function() return currentSeat() == S.car.seat end)
                if not okE then return fail('ENTREE VOITURE', why) end
            end
            setState('NAVIGATING_TO_VENDOR', '')
            local okD, why = S.performStep('NAVIGATING_TO_VENDOR', 600, tok, function() return driveRoute(D.route_to_vendor, 'ALLER', tok) end)
            if not okD then return fail('CONDUITE ALLER', why) end
            logLine('Aller : ' .. tostring(why))

            setState('EXIT_CAR', '')
            local okX, whyX = S.performStep('EXIT_CAR', 10, tok, function() return exitCar(tok) end, function() return currentSeat() == nil end)
            if not okX then return fail('SORTIE VOITURE', whyX) end

            setState('WALK_TO_VENDOR', '')
            local okW, whyW = S.performStep('WALK_TO_VENDOR', 80, tok, function() return walkTo(v3(D.vendor), 5, tok, 'vendeur') end)
            if not okW then return fail('MARCHE VENDEUR', whyW) end
            setState('SELLING', '')
            local okS, whyS = S.performStep('SELLING', 45, tok, function() return sellAll(tok) end)
            S.sellStage = whyS
            if not okS then return fail('VENTE', whyS) end
            logLine(whyS)
            if S.toast then S.toast('Vente reussie : ' .. tostring(whyS):gsub('vente CONFIRMEE : ', ''), 'ok') end

            setState('NAVIGATING_TO_ATM', '')
            local okA, whyA = S.performStep('NAVIGATING_TO_ATM', 80, tok, function() return walkTo(v3(D.atm), 4, tok, 'ATM') end)
            if okA then
                setState('DEPOSITING', '')
                local dep, whyDep = S.performStep('DEPOSITING', 25, tok, function() return depositAll(tok) end)
                S.depositStatus = tostring(whyDep)
                logLine('ATM : ' .. tostring(whyDep))
                if dep ~= true and S.depositRequired then return fail('DEPOT', whyDep) end
            else
                S.depositStatus = 'ATM non atteint : ' .. tostring(whyA)
                logLine(S.depositStatus)
                if S.depositRequired then return fail('MARCHE ATM', whyA) end
            end
            if not alive(tok) then return fail('DEPOT', 'annule') end

            setState('BACK_TO_CAR', S.car.name)
            local okE2, whyE2 = S.performStep('TO_CAR', 80, tok, function() return enterCar(tok) end, function() return currentSeat() == S.car.seat end)
            if not okE2 then return fail('RETOUR VOITURE', whyE2) end
            setState('RETURNING', '')
            local okR, whyR = S.performStep('RETURNING', 600, tok, function() return driveRoute(D.route_to_fishing, 'RETOUR', tok) end)
            if not okR then return fail('CONDUITE RETOUR', whyR) end
            logLine('Retour : ' .. tostring(whyR))
            local okX2, whyX2 = S.performStep('EXIT_CAR', 10, tok, function() return exitCar(tok) end, function() return currentSeat() == nil end)
            if not okX2 then return fail('SORTIE VOITURE (retour)', whyX2) end

            setState('RESUMING', 'marche vers le point de peche')
            local fishCF = cfOf(D.fish)
            local pre = fishCF.Position - fishCF.LookVector * 3
            local okP, whyP = S.performStep('PRE_FISHING', 80, tok, function() return walkTo(pre, 2.5, tok, 'pre-peche') end)
            if not okP then return fail('APPROCHE PECHE', whyP) end
            local okF, whyF = S.performStep('RESUMING', 80, tok, function() return walkTo(fishCF.Position, 2, tok, 'point de peche') end)
            if not okF then return fail('RETOUR PECHE', whyF) end
            if not equipRod(rodName) then logLine('Canne non re-equipee automatiquement : equipe-la') end
            S.checkInventory(); S.sellAttempts = 0; lastCast = -1e6
            S.cycleRunning = false; S.cycleFailures = 0
            S.lastCycleResult={token=tok,ok=true}
            setState('FISHING', 'cycle complet termine')
            if S.toast then S.toast('Cycle termine : retour a la peche', 'ok') end
        end)
        if not ok then fail('ERREUR INTERNE', err) end
        if alive(tok) then releaseAll(); releaseMouse(); S.cycleRunning = false end
    end)
    return true
end
S.runCycle = function() return runCycle(true) end
S.retryCycle = function() S.cycleFailures = 0; S.sellAttempts = 0; return runCycle(false) end

local function testDrive(which, namedRoute)
    if S.observatory and S.observatory.queueRunning and not S.observatory.dispatching then return false,'file centrale en cours' end
    if S.recording then return false, 'enregistrement en cours' end
    if S.cycleRunning then return false, 'cycle en cours' end
    if not currentSeat() then setState('ERROR', 'test conduite : monte au volant d\'abord'); return false end
    if not carValid() then rememberCar() end
    S.token = S.token + 1
    local tok = S.token
    S.cycleRunning = true
    local pts = namedRoute or (which == 'retour' and S.data.route_to_fishing or S.data.route_to_vendor)
    setState(which == 'retour' and 'TEST_RETOUR' or 'TEST_ALLER', 'depart dans 3 s (F12 annule)')
    task.spawn(function()
        if sleep(3, tok) then
            local ok, why = S.performStep(which == 'retour' and 'TEST_RETOUR' or 'TEST_ALLER', 600, tok, function() return driveRoute(pts, 'TEST ' .. which:upper(), tok) end)
            if alive(tok) then
                local d = S.driver
                local extra = d and string.format(' | ecart max %.1f studs, demi-tours %d, degagements %d', d.maxCross or 0, d.uturns or 0, d.recoveries or 0) or ''
                setState(ok and 'IDLE' or 'ERROR', 'test ' .. which .. ' : ' .. tostring(why) .. extra)
            end
        end
        if alive(tok) then releaseAll(); S.cycleRunning = false end
    end)
    return true
end
S.testDrive = testDrive
function S.setSpeed(straight, curve)
    if not isNum(straight) or not isNum(curve) then return false end
    S.cfg.drive.cruiseSpeed = clamp(straight, 5, 60)
    S.cfg.drive.turnSpeed = clamp(curve, 3, S.cfg.drive.cruiseSpeed)
    S.cfg.drive.nativeStraight = false
    logLine(('Vitesse cible : %.0f ligne droite / %.0f virage (studs/s, non calibre)'):format(S.cfg.drive.cruiseSpeed, S.cfg.drive.turnSpeed))
    return true
end
function S.setNative(on) S.cfg.drive.nativeStraight = not not on; logLine('Mode natif ligne droite : ' .. tostring(S.cfg.drive.nativeStraight)) end
-- Prereglages : "max moteur" garde W enfonce en ligne droite (limite = celle du jeu).
-- Aucun attribut du vehicule n'est modifie. Plus c'est rapide, moins c'est teste.
local SPEED_PRESETS = {
    { name = 'Lente', cruise = 12, turn = 5, native = false },
    { name = 'Normale', cruise = 20, turn = 7, native = false },
    { name = 'Rapide', cruise = 30, turn = 9, native = false },
    { name = 'Max moteur', cruise = 45, turn = 10, native = true },
}
S.speedPresets = SPEED_PRESETS
S.speedPreset = 'Rapide'
function S.setSpeedPreset(name)
    for _, p in ipairs(SPEED_PRESETS) do
        if p.name == name then
            S.cfg.drive.cruiseSpeed = p.cruise; S.cfg.drive.turnSpeed = p.turn; S.cfg.drive.nativeStraight = p.native
            S.speedPreset = p.name
            logLine('Vitesse voiture : ' .. p.name .. (p.native and ' (W enfonce en ligne droite)' or string.format(' (%d/%d studs/s)', p.cruise, p.turn)))
            return true
        end
    end
    return false
end
function S.nextSpeedPreset()
    for i, p in ipairs(SPEED_PRESETS) do
        if p.name == S.speedPreset then return S.setSpeedPreset(SPEED_PRESETS[i % #SPEED_PRESETS + 1].name) end
    end
    return S.setSpeedPreset('Rapide')
end

---------------------------------------------------------------------------
S.views = {}
-- Services V1 : bibliotheque explicite, session, destinations et agriculture.
do
local libraryFile = 'blockspin-library-v1.json'
local libraryWritable = true
local function idle()
    return S.running and not S.cycleRunning and not S.hub.current and not S.recording
        and not (S.observatory and S.observatory.queueRunning and not S.observatory.dispatching)
end
function S.saveLibrary()
    if not libraryWritable then return false, 'fichier illisible preserve : corriger puis recharger explicitement' end
    if type(writefile) ~= 'function' then return false, 'writefile indisponible' end
    local ok, err = pcall(function()
        local checker = Hub.new(0)
        assert(checker:loadLibrary(S.hub.library))
        local raw = HttpService:JSONEncode(S.hub.library)
        assert(#raw <= 2097152, 'bibliotheque trop grande')
        writefile(libraryFile, raw)
    end)
    if not ok then S.hub:error('Bibliotheque', err, os.clock()) end
    return ok, ok and 'Bibliotheque sauvegardee' or tostring(err)
end
function S.loadLibrary()
    if not idle() then return false, 'arreter les activites avant de recharger' end
    if type(readfile) ~= 'function' or type(isfile) ~= 'function' or not isfile(libraryFile) then return false, 'bibliotheque absente' end
    local ok, err = pcall(function()
        local raw = readfile(libraryFile)
        assert(type(raw) == 'string' and #raw <= 2097152, 'bibliotheque trop grande')
        local valid, why = S.hub:loadLibrary(HttpService:JSONDecode(raw)); assert(valid, why)
    end)
    libraryWritable = ok
    if not ok then S.hub:error('Bibliotheque', err, os.clock()) end
    return ok, ok and 'Bibliotheque chargee' or tostring(err)
end
function S.spotEvent(kind)
    local spot = S.hub.activeSpot and S.hub.library.spots[S.hub.activeSpot]
    local root = getRoot()
    if spot and root and (root.Position - v3(spot.cf)).Magnitude <= 8 then S.hub:spotEvent(kind) end
end
function S.saveSpot(name)
    if not idle() then return false, 'activite en cours' end
    local root=getRoot();if not root then return false,'personnage indisponible' end
    name=Hub.normalizeName(name)
    if name=='' then
        local i=1;repeat name='Spot '..i;i=i+1 until not S.hub.library.spots[name]
    end
    local aim=S.fishingAim
    if not aim and S.baitScreenPoint then aim={x=S.baitScreenPoint.X,y=S.baitScreenPoint.Y} end
    local ok,why=S.hub:addSpot(name,{root.CFrame:GetComponents()},aim)
    if not ok then return false,why end
    S.data.fish=Hub.copy(S.hub.library.spots[name].cf)
    return true,'Spot '..name..' enregistre'..(aim and '' or ' : capturer la visee sur l’eau'),name
end
function S.selectSpot(name)
    if not idle() then return false,'activite en cours' end
    name=Hub.normalizeName(name)
    if name=='' then
        name=S.hub.activeSpot
        if not name then
            for key in pairs(S.hub.library.spots) do if name then return false,'Choisis un spot dans la liste' end;name=key end
        end
    end
    local spot=name and S.hub.library.spots[name]
    if not spot then return false,'Enregistre un spot ou choisis son nom dans la liste' end
    local root=getRoot()
    if not root or (root.Position-v3(spot.cf)).Magnitude>8 then return false,'Rejoins ce spot a moins de 8 studs' end
    S.data.fish=Hub.copy(spot.cf);S.fishingAim=Hub.copy(spot.aim)
    S.baitScreenPoint=spot.aim and Vector2.new(spot.aim.x,spot.aim.y) or nil
    S.hub.activeSpot=name
    return true,'Spot '..name..' selectionne'..(spot.aim and '' or ' : capturer la visee'),name
end
function S.captureAimNow(expectedSpot)
    if S.isFishingInputActive and not S.isFishingInputActive() then return false,'Reviens dans Roblox pour capturer la visee' end
    local camera=workspace.CurrentCamera;local size=camera and camera.ViewportSize
    local point=UIS:GetMouseLocation()
    if not size or not point or not isNum(point.X) or not isNum(point.Y) or point.X<0 or point.Y<0 or point.X>=size.X or point.Y>=size.Y then return false,'Place le curseur sur l’eau dans Roblox' end
    local aim={x=point.X,y=point.Y,viewport={x=size.X,y=size.Y}}
    local ok,world=pcall(function() return player:GetMouse().Hit.Position end)
    if ok and world and isNum(world.X) and isNum(world.Y) and isNum(world.Z) then aim.world={world.X,world.Y,world.Z} end
    if expectedSpot and S.hub.activeSpot~=expectedSpot then return false,'Le spot a change : relancer la capture' end
    S.fishingAim=aim;S.baitScreenPoint=Vector2.new(point.X,point.Y);S.aimRetryAt=0
    if S.hub.activeSpot and S.hub.library.spots[S.hub.activeSpot] then S.hub:updateSpotAim(S.hub.activeSpot,aim) end
    return true,aim.world and 'Visee dans le monde capturee pour le spot actif' or 'Visee ecran capturee (camera a conserver)'
end
function S.saveNamedRoute(name)
    if not idle() then return false, 'terminer l\'enregistrement et les activites avant de conserver le trajet' end
    return S.hub:addRoute(name, S.recordBuffer)
end
function S.driveNamedRoute(name)
    if not idle() then return false, 'activite en cours' end
    local route = S.hub.library.routes[name]
    if not route then return false, 'destination introuvable' end
    return testDrive('destination ' .. name, Hub.copy(route))
end
function S.removeLibraryItem(kind, name)
    if not idle() then return false, 'activite en cours' end
    local list = (kind == 'spot' and S.hub.library.spots) or (kind == 'route' and S.hub.library.routes)
    if not list or not list[name] then return false, 'element introuvable' end
    list[name] = nil
    if kind == 'spot' then
        S.hub.spotStats[name] = nil
        if S.hub.activeSpot == name then S.hub.activeSpot = nil end
    end
    return true, 'Suppression en memoire ; sauvegarder explicitement pour conserver'
end
function S.refreshMoney() return S.pollMoney(true) end
function S.setFarmingAdapter(adapter)
    if not idle() then return false, 'activite en cours' end
    return S.hub:setFarmAdapter(adapter)
end
function S.startFarm(plan, replant)
    if S.observatory and S.observatory.queueRunning then return false,'file centrale en cours' end
    if not idle() then return false, 'activite en cours' end
    if not S.hub.farm.available then return false, 'Culture indisponible : interactions du jeu non observees. Utiliser Diagnostic ecran.' end
    if type(plan) ~= 'table' or #plan < 1 or #plan > 20 then return false, '1 a 20 parcelles requises' end
    local unique = {}
    for _, row in ipairs(plan) do
        if type(row) ~= 'table' or type(row.plot) ~= 'string' or type(row.crop) ~= 'string'
            or #row.plot == 0 or #row.plot > 64 or #row.crop == 0 or #row.crop > 64
            or row.plot:find('%c') or row.crop:find('%c') or unique[row.plot] then return false, 'parcelle/culture invalide ou dupliquee' end
        unique[row.plot] = true
    end
    plan = Hub.copy(plan)
    S.token = S.token + 1; local tok = S.token
    S.hub.farm.running = true; S.cycleRunning = true; S.fishingEnabled = false; S.paused = false
    task.spawn(function()
        local farm = S.hub.farm
        local function step(row, kind)
            local a = farm.adapter
            return S.performStep('FARM_' .. kind:upper(), 20, tok, function()
                if a[kind](row.plot, row.crop) ~= true then return false, 'action agricole refusee' end
                local deadline = os.clock() + 18
                while alive(tok) and os.clock() < deadline do
                    local seen = a.observe(row.plot)
                    if type(seen) == 'table' and ((kind == 'plant' and seen.state == 'growing' and seen.crop == row.crop)
                        or (kind == 'harvest' and seen.state == 'empty')) then return true, 'observation confirmee' end
                    if not sleep(0.25, tok) then break end
                end
                return false, 'resultat agricole non confirme'
            end)
        end
        local ok, why = pcall(function()
            repeat
                for _, row in ipairs(plan) do
                    if not alive(tok) then return end
                    local action, err = S.hub:farmAction(row.plot, row.crop, replant)
                    if not action then error(err) end
                    if action.kind == 'wait' then
                        local ready, detail = S.performStep('FARM_GROWING', 600, tok, function()
                            local untilAt = os.clock() + 598
                            while alive(tok) and os.clock() < untilAt do
                                local seen = farm.adapter.observe(row.plot)
                                if type(seen) ~= 'table' or seen.crop ~= row.crop then return false, 'observation de culture perdue' end
                                if seen.state == 'ready' then return true end
                                if seen.state ~= 'growing' then return false, 'etat agricole inattendu' end
                                if not sleep(1, tok) then break end
                            end
                            return false, 'delai de croissance depasse'
                        end)
                        if not ready then error(detail) end
                        action = { kind = 'harvest' }
                    end
                    local done, detail = step(row, action.kind)
                    if not done then error(detail) end
                    if not alive(tok) then return end
                    if action.kind == 'plant' then farm.planted = farm.planted + 1
                    else
                        farm.harvested = farm.harvested + 1
                        if replant then
                            local planted, msg = step(row, 'plant'); if not planted then error(msg) end
                            farm.planted = farm.planted + 1
                        end
                    end
                end
                farm.cycles = farm.cycles + 1
                if replant and not sleep(1, tok) then return end
            until not replant or not alive(tok)
        end)
        if alive(tok) then
            farm.running = false; S.cycleRunning = false
            if not ok then S.hub:finishStep(false, why, os.clock()); setState('ERROR', tostring(why))
            else setState('IDLE', 'Passage agricole termine (observations de l\'adaptateur)') end
        end
    end)
    return true, 'Culture demarree avec adaptateur local'
end
S.loadLibrary()
end

-- 16. DIAGNOSTIC GUI / PROMPTS / VEHICULE (bouton Settings > Diagnostic)
---------------------------------------------------------------------------
local dumpCount = 0
function S.dumpGui()
    dumpCount = dumpCount + 1
    local lines = { 'BlockSpin ' .. VERSION .. ' diagnostic #' .. dumpCount .. ' etat=' .. S.state }
    local root = getRoot()
    if root then lines[#lines + 1] = string.format('Position : %.1f, %.1f, %.1f', root.Position.X, root.Position.Y, root.Position.Z) end
    local seat = currentSeat()
    lines[#lines + 1] = 'Siege : ' .. (seat and seat:GetFullName() or 'aucun')
    lines[#lines + 1] = 'Voiture memorisee : ' .. (S.car and S.car.path or 'aucune')
    lines[#lines + 1] = '--- GUI visibles (texte) ---'
    for _, o in ipairs(pg:GetDescendants()) do
        if (o:IsA('TextLabel') or o:IsA('TextButton') or o:IsA('TextBox')) and not ours(o) and shown(o) and tostring(o.Text) ~= '' then
            lines[#lines + 1] = string.format('%s [%s] "%s" @%.0f,%.0f %.0fx%.0f', o:GetFullName(), o.ClassName,
                tostring(o.Text):gsub('\n', ' '):sub(1, 60), o.AbsolutePosition.X, o.AbsolutePosition.Y, o.AbsoluteSize.X, o.AbsoluteSize.Y)
        elseif o:IsA('ImageButton') and not ours(o) and shown(o) then
            lines[#lines + 1] = string.format('%s [ImageButton] @%.0f,%.0f %.0fx%.0f', o:GetFullName(), o.AbsolutePosition.X, o.AbsolutePosition.Y, o.AbsoluteSize.X, o.AbsoluteSize.Y)
        end
    end
    lines[#lines + 1] = '--- ProximityPrompts a moins de 25 studs ---'
    for _, e in ipairs(nearbyPrompts(25)) do
        local p = e.prompt
        lines[#lines + 1] = string.format('%.1f studs | %s | action="%s" objet="%s" touche=%s maintien=%.2f portee=%.0f',
            e.dist, p:GetFullName(), p.ActionText, p.ObjectText, tostring(p.KeyboardKeyCode), p.HoldDuration or 0, p.MaxActivationDistance or 0)
    end
    local text = table.concat(lines, '\n')
    local file = 'blockspin_diag_' .. dumpCount .. '.txt'
    local wrote = type(writefile) == 'function' and pcall(writefile, file, text)
    print(text)
    logLine('Diagnostic : ' .. (#lines) .. ' lignes' .. (wrote and (' -> ' .. file) or ' (console Roblox)'))
    return text
end

---------------------------------------------------------------------------
-- 17. BLACK EDITION UI
-- Six onglets : Fishing, Vehicle, Money, Farming, Statistics, Settings.
-- Les outils techniques sont dans Reglages > Avance (replie par defaut).
-- Clavier : touche d'affichage (RightShift par defaut) et F12 (urgence) seulement.
---------------------------------------------------------------------------
local SETTINGS_FILE = 'blockspin-settings-v1.json'
local ui = { accent = 'FF475C', hotkey = 'RightShift', scale = 1, metrics = true, overlay = false, hideInMinigame = true,
    speedPreset = 'Rapide', rareAction = 'none', rarePurple = true, toasts = true, animations = true, layoutVersion = 2, density = 'normal',
    privacy=false,miniDashboard=false,plantAlerts=true,plantAlertSeconds=60,plantGrouping=false,presenceAlerts=false,friendAlerts=false,rareNotifications=true,
    serverMinFree=1,serverMaxPopulation=100,cardLayouts={},recentColors={},savedThemes={},aimAssist=false,recastDelay=0.35 }
local PREF_KEYS = { 'accent', 'hotkey', 'scale', 'metrics', 'overlay', 'hideInMinigame', 'speedPreset', 'rareAction', 'rarePurple', 'toasts', 'animations',
    'position', 'size', 'overlayPosition', 'layoutVersion', 'density', 'moneySourcePath',
    'privacy','miniDashboard','plantAlerts','plantAlertSeconds','plantGrouping','presenceAlerts','friendAlerts','rareNotifications',
    'serverMinFree','serverMaxPopulation','cardLayouts','recentColors','savedThemes','aimAssist','recastDelay' }
local RARE_ACTIONS = { none = 'ne rien faire', leave = 'quitter le serveur', sell = 'aller vendre' }
local settingsRaw -- fichier lu en entier : profils et champs du hub 0.4.0 conserves
local function validKeyName(n)
    if type(n) ~= 'string' or n == 'Escape' or n == 'Unknown' or n == 'F12' then return false end
    local ok, k = pcall(function() return Enum.KeyCode[n] end)
    return ok and k ~= nil
end
local function readPrefs(d, into)
    if type(d)~='table' then return end
    if type(d.aimAssist)=='boolean' then into.aimAssist=d.aimAssist end
    if isNum(d.recastDelay) and d.recastDelay>=0.2 and d.recastDelay<=3 then into.recastDelay=d.recastDelay end
    for _,k in ipairs({'privacy','miniDashboard','plantAlerts','plantGrouping','presenceAlerts','friendAlerts','rareNotifications'}) do if type(d[k])=='boolean' then into[k]=d[k] end end
    for k,range in pairs({plantAlertSeconds={10,600},serverMinFree={0,100},serverMaxPopulation={1,200}}) do if isNum(d[k]) and d[k]>=range[1] and d[k]<=range[2] then into[k]=math.floor(d[k]) end end
    if type(d.cardLayouts)=='table' then
        local rows={};local count=0
        for key,v in pairs(d.cardLayouts) do
            if count<150 and type(key)=='string' and #key<=80 and type(v)=='table' and isNum(v.rank) and v.rank>=1 and v.rank<=150 and type(v.hidden)=='boolean' and type(v.wide)=='boolean' then
                rows[key]={rank=math.floor(v.rank),hidden=v.hidden,wide=v.wide};count=count+1
            end
        end
        into.cardLayouts=rows
    end
    if type(d.recentColors)=='table' then local rows={};for _,v in ipairs(d.recentColors) do if #rows<8 and type(v)=='string' and v:match('^%x%x%x%x%x%x$') then rows[#rows+1]=v:upper() end end;into.recentColors=rows end
    if type(d.savedThemes)=='table' then
        local rows={};local count=0
        for k,v in pairs(d.savedThemes) do if count<12 and Hub.validName(k) and type(v)=='string' and v:match('^%x%x%x%x%x%x$') then rows[k]=v:upper();count=count+1 end end
        into.savedThemes=rows
    end
    if type(d.moneySourcePath)=='string' and #d.moneySourcePath<=512 and not d.moneySourcePath:find('%c') then into.moneySourcePath=d.moneySourcePath end
    if d.density=='normal' or d.density=='compact' then into.density=d.density end
    if type(d.accent) == 'string' and d.accent:match('^%x%x%x%x%x%x$') then into.accent = d.accent end
    if validKeyName(d.hotkey) then into.hotkey = d.hotkey end
    if isNum(d.scale) and d.scale >= 0.75 and d.scale <= 1.5 then into.scale = d.scale end
    for _, k in ipairs({ 'metrics', 'overlay', 'hideInMinigame', 'rarePurple', 'toasts', 'animations' }) do if type(d[k]) == 'boolean' then into[k] = d[k] end end
    for _, p in ipairs(SPEED_PRESETS) do if d.speedPreset == p.name then into.speedPreset = p.name end end
    if RARE_ACTIONS[d.rareAction] then into.rareAction = d.rareAction end
    for _, f in ipairs({ 'position', 'size', 'overlayPosition' }) do
        local p = d[f]
        if type(p) == 'table' and isNum(p.x) and isNum(p.y) then into[f] = { x = p.x, y = p.y } end
    end
end
local settingsWritable = true
local okSettings, settingsErr = pcall(function()
    if type(readfile) == 'function' and type(isfile) == 'function' and isfile(SETTINGS_FILE) then
        local raw = readfile(SETTINGS_FILE)
        assert(type(raw) == 'string' and #raw <= 65536, 'fichier de reglages trop grand')
        local d = HttpService:JSONDecode(raw)
        assert(type(d) == 'table', 'format de reglages invalide')
        settingsRaw = d
        readPrefs(d, ui)
    end
end)
if not okSettings then
    settingsWritable = false
    logLine(SETTINGS_FILE .. ' illisible (' .. tostring(settingsErr) .. ') : fichier preserve, reglages non sauvegardes cette session')
end
-- l'ancien overlay (12,12) etait cache sous les boutons Roblox en haut a gauche
if ui.overlayPosition and ui.overlayPosition.y < 64 and ui.overlayPosition.x < 330 then ui.overlayPosition = nil end
S.ui = ui
S.castDelay=ui.recastDelay
function S.setFishingAimAssist(enabled)
    if type(enabled)~='boolean' then return false end
    ui.aimAssist=enabled;S.aimRetryAt=0;S.castTicket=nil;S.castPending=false
    S.fishingInputStatus=enabled and 'Visee enregistree activee' or 'Classique : lancer direct'
    return true
end
S.moneySourcePath=ui.moneySourcePath
local profiles = (type(settingsRaw) == 'table' and type(settingsRaw.profiles) == 'table') and settingsRaw.profiles or {}
local function saveSettings()
    if ui.recentColors and ui.recentColors[1]~=ui.accent then
        local rows={ui.accent};for _,h in ipairs(ui.recentColors) do if h~=ui.accent and #rows<8 then rows[#rows+1]=h end end;ui.recentColors=rows
    end
    if type(writefile) ~= 'function' or not settingsWritable then return false end
    local out = {}
    if type(settingsRaw) == 'table' then for k, v in pairs(settingsRaw) do out[k] = v end end
    out.schema = 1
    for _, k in ipairs(PREF_KEYS) do out[k] = ui[k] end
    out.profiles = profiles
    local ok, err = pcall(function() writefile(SETTINGS_FILE, HttpService:JSONEncode(out)) end)
    if not ok then logLine('Reglages non sauvegardes : ' .. tostring(err)) end
    return ok
end
S.setSpeedPreset(ui.speedPreset)

local theme = {
    background = Color3.fromRGB(9, 10, 13), surface = Color3.fromRGB(15, 16, 20),
    control = Color3.fromRGB(22, 23, 29), border = Color3.fromRGB(34, 36, 44),
    text = Color3.fromRGB(238, 239, 245), muted = Color3.fromRGB(130, 135, 152),
    danger = Color3.fromRGB(175, 42, 61),
}
local function hexColor(h) return Color3.fromRGB(tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16)) end
theme.accent = hexColor(ui.accent)
local function make(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    o.Parent = parent
    return o
end
local function connect(signal, fn)
    local c = signal:Connect(function(...)
        local ok, err = pcall(fn, ...)
        if not ok then logLine('Erreur interface : ' .. tostring(err)); S.hub:error('Interface', err, os.clock()) end
    end)
    table.insert(conns, c)
    return c
end
local function round(o, r) make('UICorner', { CornerRadius = UDim.new(0, r or 8) }, o) end
local function outline(o) make('UIStroke', { Color = theme.border, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o) end
local function inset(o, a) make('UIPadding', { PaddingLeft = UDim.new(0, a), PaddingRight = UDim.new(0, a) }, o) end
local function viewportSize()
    local cam = workspace.CurrentCamera
    local v = cam and cam.ViewportSize
    if v and v.X > 0 and v.Y > 0 then return v end
    return Vector2.new(1280, 720)
end

gui = make('ScreenGui', { Name = 'BlockSpinCycle080', ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, pg)
local window = make('CanvasGroup', { Name = 'Window', BackgroundColor3 = theme.background, BorderSizePixel = 0,
    ClipsDescendants = true, Active = true, GroupTransparency = 0 }, gui)
local menuScale = make('UIScale', { Scale = ui.scale }, window)
round(window, 14); outline(window)

-- Presentation Black Edition. Injectee par build.py dans la portee du client.
-- Aucune logique de jeu : les controles appellent les callbacks existants.
do
local D = { pages = {}, cards = {}, rows = {}, navItems = {}, orders = {}, tweens = {},
    accentBindings = {}, visibilityToken = 0, menuVisible = true, sidebarWidth = 196 }
S.design = D
local TweenService = game:GetService('TweenService')
local function color(r,g,b) return Color3.fromRGB(r,g,b) end
local function tint(c, amount)
    return color(14 + c.R * amount, 15 + c.G * amount, 18 + c.B * amount)
end
local function corner(o, radius)
    make('UICorner', {CornerRadius=UDim.new(0,radius or 8)}, o)
end
local function stroke(o, c)
    return make('UIStroke', {Color=c or theme.border, Thickness=1, ApplyStrokeMode=Enum.ApplyStrokeMode.Border}, o)
end
local function text(parent, value, size, c)
    return make('TextLabel', {BackgroundTransparency=1, BorderSizePixel=0, Text=value, TextSize=size or 13,
        TextColor3=c or theme.text, Font=Enum.Font.Gotham, TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Center, TextWrapped=false, TextTruncate=Enum.TextTruncate.AtEnd,
        Size=UDim2.new(1,0,0,24)}, parent)
end
local function line(parent,x,y,w,h,c,rotation)
    local o=make('Frame',{BorderSizePixel=0, BackgroundColor3=c, Position=UDim2.fromOffset(x,y),
        Size=UDim2.fromOffset(w,h), Rotation=rotation or 0},parent)
    corner(o,math.min(w,h)/2); return o
end
-- Petites icones vectorielles locales : aucun asset externe a telecharger.
function D.icon(parent, name, c)
    local host=make('Frame',{Name='Icon',BackgroundTransparency=1,Size=UDim2.fromOffset(22,22),Position=UDim2.fromOffset(14,13)},parent)
    local pieces={}
    local function l(x,y,w,h,r) pieces[#pieces+1]=line(host,x,y,w,h,c,r) end
    if name=='Fishing' then l(3,4,2,9);l(4,13,8,2);l(11,4,2,9);l(3,3,10,2);l(14,2,2,5,35);l(13,15,6,2,-35)
    elseif name=='Vehicle' then l(3,9,16,8);l(6,5,10,2);l(5,5,2,7,25);l(15,5,2,7,-25);l(4,16,3,4);l(15,16,3,4)
    elseif name=='Money' then l(2,5,18,14);l(12,9,8,6);l(14,11,2,2);l(5,2,10,2,-12)
    elseif name=='Farming' then l(10,9,2,12);l(3,6,9,3,35);l(11,4,9,3,-35);l(6,16,10,2)
    elseif name=='Server' then l(3,3,16,2);l(3,8,16,2);l(3,13,16,2);l(3,18,16,2);l(3,3,2,7);l(17,3,2,7);l(3,13,2,7);l(17,13,2,7)
    elseif name=='Statistics' then l(3,13,3,7);l(9,8,3,12);l(15,3,3,17)
    else l(3,5,16,2);l(3,11,16,2);l(3,17,16,2);l(7,2,3,7);l(13,8,3,7);l(6,14,3,7) end
    return host,pieces
end
function D.bind(o, property, fn)
    D.accentBindings[#D.accentBindings+1]={object=o,property=property,transform=fn}
    o[property]=fn and fn(theme.accent) or theme.accent
end
function D.animate(o, seconds, props)
    if not o or not o.Parent or D.closed then return end
    local previous=D.tweens[o]
    if D.fastPreview then
        if previous then
            if previous.connection then previous.connection:Disconnect() end
            pcall(function() previous.tween:Cancel() end);D.tweens[o]=nil
        end
        for key,value in pairs(props) do o[key]=value end
        return
    end
    local unchanged=true
    for k,v in pairs(props) do if o[k]~=v then unchanged=false end end
    if previous then
        local same=true; for k,v in pairs(props) do if previous.props[k]~=v then same=false end end
        if same and ui.animations then return end
        if previous.connection then previous.connection:Disconnect() end
        pcall(function() previous.tween:Cancel() end); D.tweens[o]=nil
    end
    if unchanged then return end
    if not ui.animations then for k,v in pairs(props) do o[k]=v end; return end
    local ok,tween=pcall(function()
        return TweenService:Create(o,TweenInfo.new(seconds,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),props)
    end)
    if ok then
        local entry={tween=tween,props=props};D.tweens[o]=entry
        if tween.Completed then entry.connection=tween.Completed:Connect(function()
            if D.tweens[o]==entry then D.tweens[o]=nil end
            if entry.connection then entry.connection:Disconnect();entry.connection=nil end
        end) end
        tween:Play()
    else for k,v in pairs(props) do pcall(function() o[k]=v end) end end
end
S.animate=D.animate
function D.finishAnimations()
    local pending=D.tweens;D.tweens={}
    for o,entry in pairs(pending) do
        if entry.connection then entry.connection:Disconnect() end
        pcall(function() entry.tween:Cancel() end)
        if o.Parent then for k,v in pairs(entry.props) do pcall(function() o[k]=v end) end end
    end
    D.tweens={}
end
function D.cleanup()
    if D.cancelPointer then D.cancelPointer() end
    D.visibilityToken=D.visibilityToken+1
    D.finishAnimations(); D.closed=true
end
function D.order(parent)
    D.orders[parent]=(D.orders[parent] or 0)+1; return D.orders[parent]
end
function D.hover(button, border)
    button.AutoButtonColor=false; button.Selectable=true
    if button.MouseEnter then connect(button.MouseEnter,function()
        D.animate(button,0.16,{BackgroundColor3=color(28,29,35)})
        if border then D.animate(border,0.16,{Color=color(68,70,80)}) end
    end) end
    if button.MouseLeave then connect(button.MouseLeave,function()
        D.animate(button,0.2,{BackgroundColor3=theme.control})
        if border then D.animate(border,0.2,{Color=theme.border}) end
    end) end
end
local pageTitles={Fishing='Pêche & automatisation',Vehicle='Votre garage',Money='Bilan de session',
    Farming='Culture & parcelles',Statistics='Tableau de bord',Settings='Votre espace, vos réglages',Server='Votre serveur'}
local descriptions={Fishing='Vos spots. Votre rythme. Tout au même endroit.',Vehicle='Enregistrez vos trajets et retrouvez vos destinations.',
    Money='Un regard clair sur les montants réellement observés.',Farming='Préparez vos cultures et suivez vos parcelles.',
    Statistics='L’activité et les chiffres de votre session.',Settings='Des couleurs et des réglages qui vous ressemblent.',Server='Les joueurs et les mouvements de cette session.'}
local defaults={Fishing='Automatisation',Vehicle='Conduite',Money='Votre argent',Farming='Vos cultures',Statistics='Vue d’ensemble',Settings='Personnalisation',Server='Vue du serveur'}
function D.newCard(page, title)
    local meta=D.pages[page]
    local card=make('Frame',{Name='Card',BackgroundColor3=theme.surface,BorderSizePixel=0,
        Size=UDim2.new(1,0,0,80),ClipsDescendants=true},meta.columns)
    corner(card,10);stroke(card)
    make('UIPadding',{PaddingTop=UDim.new(0,16),PaddingBottom=UDim.new(0,16),PaddingLeft=UDim.new(0,16),PaddingRight=UDim.new(0,16)},card)
    make('UIListLayout',{Padding=UDim.new(0,9),SortOrder=Enum.SortOrder.LayoutOrder},card)
    local heading=text(card,title,14,theme.text); heading.Name='CardTitle';heading.Font=Enum.Font.GothamBold
    heading.Size=UDim2.new(1,0,0,24);heading.LayoutOrder=0
    card.Name='Card'
    local key=meta.name..':'..tostring(#meta.cards+1)
    D.cardKeys=D.cardKeys or {};D.cardKeys[card]=key
    meta.cards[#meta.cards+1]=card; D.cards[#D.cards+1]=card;meta.current=card
    return card,heading
end
function D.parent(parent)
    local meta=D.pages[parent]
    if not meta then return parent end
    if not meta.current then D.newCard(parent,defaults[meta.name] or meta.name) end
    return meta.current
end
function D.section(parent,title)
    if not D.pages[parent] then return nil end
    local _,heading=D.newCard(parent,title);return heading
end
function D.addPage(page,name)
    local hero=make('Frame',{Name='SessionTiles',Size=UDim2.new(1,0,0,66),BackgroundTransparency=1,LayoutOrder=0},page)
    local tileNames={Fishing={'INVENTAIRE','APPÂTS','LANCERS'},Vehicle={'VÉHICULE','DESTINATIONS','POINTS'},Money={'GAINS','PORTEFEUILLE','ESTIMATION'},
        Farming={'PARCELLES SUIVIES','PRÊTES OBSERVÉES','PROCHAINE ÉCHÉANCE'},Statistics={'SESSION','LANCERS','ERREURS'},Settings={'ACCENT','ÉCHELLE','ANIMATIONS'},Server={'JOUEURS','CAPACITÉ','PING'}}
    local keys=tileNames[name] or {'INVENTAIRE','APPÂTS','SESSION'}
    local values={}
    for i,key in ipairs(keys) do
        local tile=make('Frame',{BackgroundColor3=theme.surface,BorderSizePixel=0,Size=UDim2.new(1/3,-9,1,0),
            Position=UDim2.new((i-1)/3,(i-1)*4,0,0)},hero)
        corner(tile,8);stroke(tile)
        local caption=text(tile,key,9,theme.muted);caption.Position=UDim2.fromOffset(12,7);caption.Size=UDim2.new(1,-24,0,16)
        local value=text(tile,'—',19,theme.text);value.Font=Enum.Font.GothamMedium;value.Position=UDim2.fromOffset(12,26);value.Size=UDim2.new(1,-24,0,28)
        values[i]=value
    end
    local columns=make('Frame',{Name='Cards',BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),LayoutOrder=1},page)
    D.pages[page]={name=name,columns=columns,cards={},tiles=values}
end
function D.navButton(name,callback)
    local i=#D.navItems+1
    local b=make('TextButton',{Name='Nav'..name,Text=name,TextTransparency=1,AutoButtonColor=false,Selectable=true,
        Size=UDim2.new(1,-24,0,48),Position=UDim2.fromOffset(12,(i-1)*56),BackgroundTransparency=1,
        BackgroundColor3=theme.control,BorderSizePixel=0,TextSize=13},D.nav)
    corner(b,8)
    local mark=make('Frame',{Name='ActiveIndicator',Size=UDim2.fromOffset(3,20),Position=UDim2.new(0,0,0.5,-10),
        BackgroundColor3=theme.accent,BorderSizePixel=0,Visible=false},b);corner(mark,2)
    local icon,pieces=D.icon(b,name,theme.muted)
    local nameLabel=text(b,name,13,theme.muted);nameLabel.Name='NavTitle';nameLabel.Font=Enum.Font.GothamMedium
    nameLabel.Position=UDim2.fromOffset(48,0);nameLabel.Size=UDim2.new(1,-58,1,0)
    local data={button=b,icon=icon,pieces=pieces,title=nameLabel,mark=mark,name=name}
    D.navItems[#D.navItems+1]=data
    connect(b.Activated,callback)
    if b.MouseEnter then connect(b.MouseEnter,function() D.animate(b,0.16,{BackgroundTransparency=data.selected and 0 or 0.45}) end) end
    if b.MouseLeave then connect(b.MouseLeave,function() D.animate(b,0.2,{BackgroundTransparency=data.selected and 0 or 1}) end) end
    return b
end
function D.navigation(pages,active)
    local previous=D.active;local changed=previous~=active;D.active=active
    if changed then
        D.cancelPointer()
        if previous=='Settings' and D.picker then D.picker.cancel() end
    end
    for _,item in ipairs(D.navItems) do
        local selected=item.name==active;item.selected=selected;item.mark.Visible=selected
        item.mark.BackgroundColor3=theme.accent
        D.animate(item.button,0.2,{BackgroundTransparency=selected and 0 or 1,BackgroundColor3=selected and tint(theme.accent,16) or theme.control})
        D.animate(item.title,0.2,{TextColor3=selected and theme.text or theme.muted})
        for _,piece in ipairs(item.pieces) do D.animate(piece,0.2,{BackgroundColor3=selected and theme.accent or theme.muted}) end
        pages[item.name].Visible=selected
    end
    D.heading.Text=pageTitles[active] or active;D.description.Text=descriptions[active] or ''
    if changed and ui.animations then
        D.content.GroupTransparency=0.8
        D.animate(D.content,0.22,{GroupTransparency=0})
        for page,meta in pairs(D.pages) do if meta.name==active then
            page.Position=UDim2.fromOffset(0,7);D.animate(page,0.24,{Position=UDim2.fromOffset(0,0)})
        end end
    end
end
function D.decorateRow(b,raw)
    local row={button=b,baseHeight=b.Size.Y.Offset}
    b.TextTransparency=1
    local padding=b:FindFirstChildOfClass('UIPadding')
    if padding then padding.PaddingLeft=UDim.new(0,0);padding.PaddingRight=UDim.new(0,0) end
    row.title=text(b,'',13,theme.text);row.title.Name='ControlTitle'
    row.title.Position=UDim2.fromOffset(14,0);row.title.Size=UDim2.new(1,-88,1,0)
    row.title.TextWrapped=true
    row.value=text(b,'',11,theme.muted);row.value.Name='ControlValue'
    row.value.Position=UDim2.new(0.5,0,0,0);row.value.Size=UDim2.new(0.5,-14,1,0);row.value.TextXAlignment=Enum.TextXAlignment.Right
    row.track=make('Frame',{Name='Switch',Size=UDim2.fromOffset(38,22),Position=UDim2.new(1,-52,0.5,-11),
        BackgroundColor3=color(48,50,58),BorderSizePixel=0},b);corner(row.track,11)
    row.knob=make('Frame',{Name='Knob',Size=UDim2.fromOffset(16,16),Position=UDim2.fromOffset(3,3),
        BackgroundColor3=color(226,228,234),BorderSizePixel=0},row.track);corner(row.knob,8)
    function row.paint(value)
        b.Text=value
        local state
        if value:find('^%[ON%]') then state=true elseif value:find('^%[OFF%]') then state=false
        elseif value:find('^Enregistrement :') then state=true elseif value:find('^Enregistrer un nouveau trajet') then state=false
        else
            local suffix=value:match(':%s*(.-)%s*$')
            if suffix=='oui' or suffix=='actif' then state=true elseif suffix=='non' or suffix=='inactif' then state=false end
        end
        local cleaned=value:gsub('^%[ON%]%s*',''):gsub('^%[OFF%]%s*',''):gsub('^> ',''):gsub('^v ','')
        row.track.Visible=state~=nil;row.value.Visible=state==nil
        if state~=nil then
            row.title.Text=cleaned:gsub(':%s*oui$',''):gsub(':%s*non$',''):gsub(':%s*actif$',''):gsub(':%s*inactif$','')
            row.title.Size=UDim2.new(1,-80,1,0)
            D.animate(row.track,0.18,{BackgroundColor3=state and theme.accent or color(48,50,58)})
            D.animate(row.knob,0.18,{Position=UDim2.fromOffset(state and 19 or 3,3),BackgroundColor3=state and color(255,255,255) or color(168,171,183)})
        else
            local title,valueText=cleaned:match('^(.-)%s*:%s*(.+)$')
            row.title.Text=title or cleaned;row.value.Text=valueText or (value:find('^v ') and '⌄' or '›')
            row.title.Size=UDim2.new(valueText and 0.52 or 1,valueText and -14 or -40,1,0)
        end
    end
    row.paint(raw);D.rows[#D.rows+1]=row
    return row
end
function D.applyAccent()
    for _,entry in ipairs(D.accentBindings) do
        if entry.object.Parent then entry.object[entry.property]=entry.transform and entry.transform(theme.accent) or theme.accent end
    end
    for _,row in ipairs(D.rows) do if row.button.Parent then row.paint(row.button.Text) end end
end
function D.showMenu(visible,automatic)
    if D.closed then return end
    if not visible and D.cancelPointer then D.cancelPointer();if D.picker then D.picker.cancel() end end
    D.visibilityToken=D.visibilityToken+1;local token=D.visibilityToken
    D.menuVisible=visible
    D.launcher.Visible=not visible and not automatic
    if visible then
        window.Visible=true
        D.animate(window,0.22,{GroupTransparency=0})
        D.animate(menuScale,0.24,{Scale=ui.scale})
    else
        D.animate(window,0.16,{GroupTransparency=1})
        D.animate(menuScale,0.18,{Scale=ui.scale*0.98})
        if automatic or not ui.animations then window.Visible=false
        else task.delay(0.18,function()
            if S.running and token==D.visibilityToken and not D.menuVisible then window.Visible=false end
        end) end
    end
end
S.setMenuVisible=D.showMenu
function D.createChrome()
    D.sidebar=make('Frame',{Name='Sidebar',Size=UDim2.new(0,196,1,0),BackgroundColor3=color(12,13,16),BorderSizePixel=0},window)
    D.sidebarDivider=line(D.sidebar,195,0,1,640,theme.border);D.sidebarDivider.Size=UDim2.new(0,1,1,0)
    D.navCaption=text(D.sidebar,'WORKSPACE',9,color(96,99,112));D.navCaption.Position=UDim2.fromOffset(26,94);D.navCaption.Size=UDim2.new(1,-40,0,20)
    D.nav=make('ScrollingFrame',{Name='Navigation',BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(0,126),Size=UDim2.new(1,0,1,-208),
        CanvasSize=UDim2.fromOffset(0,392),ScrollBarThickness=0,ScrollingDirection=Enum.ScrollingDirection.Y},D.sidebar)
    D.profile=make('Frame',{Name='RobloxProfile',Position=UDim2.fromOffset(12,20),Size=UDim2.new(1,-24,0,68),BackgroundColor3=color(20,21,26),BorderSizePixel=0},D.sidebar)
    corner(D.profile,9);stroke(D.profile)
    local avatarHolder=make('Frame',{Name='AvatarHolder',BackgroundColor3=color(35,37,44),Size=UDim2.fromOffset(38,38),Position=UDim2.fromOffset(10,15),ClipsDescendants=true,BorderSizePixel=0},D.profile);corner(avatarHolder,12)
    local fallback=text(avatarHolder,'?',18,theme.muted);fallback.Name='AvatarPlaceholder';fallback.Size=UDim2.fromScale(1,1);fallback.TextXAlignment=Enum.TextXAlignment.Center
    local avatar=make('ImageLabel',{Name='RobloxAvatar',Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Image='',Visible=false,ScaleType=Enum.ScaleType.Crop},avatarHolder);corner(avatar,12)
    local name=type(player.DisplayName)=='string' and player.DisplayName~='' and player.DisplayName or player.Name
    D.displayName=text(D.profile,tostring(name or 'Joueur Roblox'),12,theme.text);D.displayName.Name='DisplayName';D.displayName.Font=Enum.Font.GothamMedium;D.displayName.Position=UDim2.fromOffset(58,14);D.displayName.Size=UDim2.new(1,-64,0,20)
    D.username=text(D.profile,'@'..tostring(player.Name or 'Roblox'),10,theme.muted);D.username.Name='Username';D.username.Position=UDim2.fromOffset(58,35);D.username.Size=UDim2.new(1,-64,0,18)
    D.brandTitle=D.displayName;D.brandCaption=D.username
    task.spawn(function()
        for attempt=1,3 do
            if not S.running or not avatar.Parent then return end
            local ok,url,ready=pcall(function() return Players:GetUserThumbnailAsync(player.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size150x150) end)
            if not S.running or not avatar.Parent then return end
            if ok and ready and type(url)=='string' and url~='' then
                avatar.Image=url;avatar.Visible=true
                local deadline=os.clock()+5
                while S.running and avatar.Parent and not avatar.IsLoaded and os.clock()<deadline do task.wait(0.1) end
                if not S.running or not avatar.Parent then return end
                if avatar.IsLoaded then fallback.Visible=false else avatar.Visible=false end
                return
            end
            if attempt<3 then task.wait(attempt) end
        end
    end)
    D.header=make('Frame',{Name='Header',BackgroundTransparency=1,Size=UDim2.new(1,-196,0,100),Position=UDim2.fromOffset(196,0),Active=true},window)
    D.dragHandle=D.header
    D.heading=text(D.header,'Pêche & automatisation',22,theme.text);D.heading.Font=Enum.Font.GothamBold;D.heading.Position=UDim2.fromOffset(24,22);D.heading.Size=UDim2.new(1,-260,0,32)
    D.description=text(D.header,descriptions.Fishing,11,theme.muted);D.description.Position=UDim2.fromOffset(24,60);D.description.Size=UDim2.new(1,-48,0,20)
    D.metrics=text(D.header,'FPS -- | Ping --',10,theme.muted);D.metrics.Position=UDim2.new(1,-210,0,26);D.metrics.Size=UDim2.fromOffset(152,30);D.metrics.TextXAlignment=Enum.TextXAlignment.Center
    D.metrics.BackgroundTransparency=0;D.metrics.BackgroundColor3=theme.control;corner(D.metrics,7);stroke(D.metrics);D.metrics.Visible=ui.metrics
    local minimize=make('TextButton',{Name='Minimize',Text='−',TextColor3=theme.muted,TextSize=22,Font=Enum.Font.Gotham,
        Size=UDim2.fromOffset(30,30),Position=UDim2.new(1,-46,0,26),BackgroundColor3=theme.control,BorderSizePixel=0},D.header);corner(minimize,7);D.hover(minimize,stroke(minimize))
    connect(minimize.Activated,function() D.showMenu(false) end)
    D.content=make('CanvasGroup',{Name='PageTransition',BackgroundTransparency=1,GroupTransparency=0,BorderSizePixel=0,
        Position=UDim2.fromOffset(220,104),Size=UDim2.new(1,-244,1,-158),ClipsDescendants=true},window)
    D.footer=make('Frame',{Name='StatusBar',BackgroundTransparency=1,Size=UDim2.new(1,-196,0,40),Position=UDim2.new(0,196,1,-42)},window)
    local dot=line(D.footer,24,17,5,5,theme.accent);D.bind(dot,'BackgroundColor3')
    D.stateLabel=text(D.footer,'Session prête',10,theme.muted);D.stateLabel.Position=UDim2.fromOffset(38,0);D.stateLabel.Size=UDim2.new(1,-210,1,0)
    D.versionLabel=text(D.footer,'v'..VERSION..'  /  '..ui.hotkey..' : masquer',9,color(100,104,118));D.versionLabel.Position=UDim2.new(1,-198,0,0);D.versionLabel.Size=UDim2.fromOffset(164,40);D.versionLabel.TextXAlignment=Enum.TextXAlignment.Right
    D.resize=make('TextButton',{Name='Resize',Text='◢',TextSize=16,Font=Enum.Font.Gotham,TextColor3=color(100,104,118),BackgroundTransparency=1,
        Size=UDim2.fromOffset(24,24),Position=UDim2.new(1,-27,1,-27)},window)
    D.launcher=make('TextButton',{Name='OpenHub',Text='☰',Font=Enum.Font.GothamBold,TextSize=22,TextColor3=theme.accent,Visible=false,
        BackgroundColor3=theme.surface,BorderSizePixel=0,Position=UDim2.new(0,16,1,-68),Size=UDim2.fromOffset(44,44),ZIndex=25},gui);corner(D.launcher,12);stroke(D.launcher);D.bind(D.launcher,'TextColor3')
    connect(D.launcher.Activated,function() D.showMenu(true) end)
end
function D.layout()
    if not D.header then return end
    local w,h=window.Size.X.Offset,window.Size.Y.Offset
    local compact=w<860;local side=compact and 72 or 196
    D.sidebarWidth=side
    D.sidebar.Size=UDim2.new(0,side,1,0);D.sidebarDivider.Position=UDim2.fromOffset(side-1,0)
    D.brandTitle.Visible=not compact;D.brandCaption.Visible=not compact;D.navCaption.Visible=not compact
    D.profile.Position=UDim2.fromOffset(compact and 8 or 12,20);D.profile.Size=UDim2.new(1,compact and -16 or -24,0,68)
    D.displayName.Visible=not compact;D.username.Visible=not compact
    local holder=D.profile:FindFirstChild('AvatarHolder');holder.Position=UDim2.fromOffset(compact and 8 or 10,15)
    D.header.Position=UDim2.fromOffset(side,0);D.header.Size=UDim2.new(1,-side,0,100)
    D.heading.Size=UDim2.new(1,w<600 and -80 or -260,0,32);D.heading.TextSize=w<600 and 18 or 22
    D.metrics.Visible=ui.metrics and w>=600
    D.content.Position=UDim2.fromOffset(side+20,100);D.content.Size=UDim2.new(1,-side-40,1,-148)
    D.footer.Position=UDim2.new(0,side,1,-42);D.footer.Size=UDim2.new(1,-side,0,40)
    D.versionLabel.Visible=w>=600
    D.stateLabel.Size=UDim2.new(1,w>=600 and -210 or -56,1,0)
    for _,item in ipairs(D.navItems) do
        item.title.Visible=not compact;item.icon.Position=UDim2.fromOffset(compact and 13 or 14,13)
    end
    for _,row in ipairs(D.rows) do row.button.Size=UDim2.new(1,0,0,ui.density=='compact' and math.max(38,row.baseHeight-8) or row.baseHeight) end
    if D.picker and D.picker.layout then D.picker.layout() end
    local twoColumns=w-side-40>=600
    for page,meta in pairs(D.pages) do
        local heights={0,0}
        local cards={};for i,card in ipairs(meta.cards) do cards[#cards+1]={card=card,index=i,layout=ui.cardLayouts and ui.cardLayouts[D.cardKeys[card]] or {}} end
        table.sort(cards,function(a,b) local x,y=a.layout.rank or a.index,b.layout.rank or b.index;if x==y then return a.index<b.index end;return x<y end)
        for _,entry in ipairs(cards) do
            local card=entry.card
            local children={}
            for _,child in ipairs(card:GetChildren()) do
                if child:IsA('GuiObject') and child.Visible and child.Name~='CardTitle' then children[#children+1]=child end
            end
            local count=#children
            local height=32
            local heading=card:FindFirstChild('CardTitle')
            if heading and heading.Visible then height=height+24+(count>0 and 9 or 0) end
            for _,child in ipairs(children) do height=height+child.Size.Y.Offset end
            height=height+math.max(0,count-1)*9
            local hidden=entry.layout.hidden and not (D.protectedCards and D.protectedCards[card])
            card.Visible=count>0 and not hidden
            if count>0 and not hidden then
                local wide=entry.layout.wide==true
                if wide then local start=math.max(heights[1],heights[2]);heights={start,start} end
                local split=twoColumns and not wide
                local column=split and (heights[1]<=heights[2] and 1 or 2) or 1
                card.Size=UDim2.new(split and 0.5 or 1,split and -7 or 0,0,height)
                card.Position=UDim2.new(column==2 and 0.5 or 0,column==2 and 7 or 0,0,heights[column])
                heights[column]=heights[column]+height+14
                if wide then heights[2]=heights[1] end
            end
        end
        meta.columns.Size=UDim2.new(1,0,0,math.max(0,math.max(heights[1],heights[2])-14))
    end
end
function D.stateText(state,detail)
    local names={IDLE='Prêt',FISHING='Pêche en cours',PAUSED='En pause',ERROR='Intervention requise',
        INVENTORY_FULL='Inventaire plein',NO_BAIT='Plus d’appâts',TO_CAR='Retour au véhicule',EXIT_CAR='Sortie du véhicule',
        NAVIGATING_TO_VENDOR='Trajet vers le vendeur',WALK_TO_VENDOR='Approche du vendeur',SELLING='Vente en cours',
        NAVIGATING_TO_ATM='Trajet vers l’ATM',DEPOSITING='Dépôt en cours',BACK_TO_CAR='Retour au véhicule',
        RETURNING='Trajet de retour',PRE_FISHING='Approche du spot',RESUMING='Reprise de la pêche',
        TEST_ALLER='Conduite / aller',TEST_RETOUR='Conduite / retour',FARM_PLANT='Plantation',FARM_GROWING='Croissance',FARM_HARVEST='Récolte'}
    return (names[state] or state)..(detail and detail~='' and ('  ·  '..detail) or '')
end
function D.refresh()
    for target,entry in pairs(D.tweens) do
        if not target.Parent then
            if entry.connection then entry.connection:Disconnect() end
            pcall(function() entry.tween:Cancel() end);D.tweens[target]=nil
        end
    end
    local elapsed=math.max(0,os.clock()-S.hub.started)
    for _,meta in pairs(D.pages) do
        meta.tiles[1].Text=S.inventoryText or '—'
        meta.tiles[2].Text=S.baitUnknown and '—' or ('x'..tostring(S.baitCount))
        meta.tiles[3].Text=string.format('%02d:%02d',math.floor(elapsed/60),math.floor(elapsed%60))
    end
    D.stateLabel.TextColor3=S.state=='ERROR' and color(255,116,135) or theme.muted
    if D.refreshVisuals then D.refreshVisuals() end
    D.layout()
end
-- Widgets de presentation : nombres, jauges, listes et controles a la souris.
D.widgets={};D.lists={};D.charts={}
local function parentOf(parent) return D.parent(parent) end
local function countKeys(t) local n=0;for _ in pairs(t or {}) do n=n+1 end;return n end
local function shortMoney(n) return isNum(n) and string.format('%.0f $',n) or 'N/D' end
local function frame(parent,name,height)
    parent=parentOf(parent)
    return make('Frame',{Name=name,BackgroundTransparency=1,Size=UDim2.new(1,0,0,height),LayoutOrder=D.order(parent)},parent)
end
function D.metricsGrid(parent,items,columns)
    columns=columns or 2
    local root=frame(parent,'MetricGrid',math.ceil(#items/columns)*88-8)
    for i,item in ipairs(items) do
        local box=make('Frame',{Name='Metric_'..item.id,BackgroundColor3=theme.control,BorderSizePixel=0,
            Size=UDim2.new(1/columns,-5,0,80),Position=UDim2.new((i-1)%columns/columns,((i-1)%columns)*5,0,math.floor((i-1)/columns)*88)},root)
        corner(box,8)
        local cap=text(box,item.label,10,theme.muted);cap.Position=UDim2.fromOffset(12,8);cap.Size=UDim2.new(1,-24,0,18)
        local value=text(box,'—',22,theme.text);value.Name='Value';value.Font=Enum.Font.GothamMedium;value.Position=UDim2.fromOffset(12,31);value.Size=UDim2.new(1,-24,0,30)
        local dash=line(box,12,68,22,2,theme.accent);D.bind(dash,'BackgroundColor3')
        D.widgets[item.id]=value
    end
    return root
end
function D.value(id,value)
    local widget=D.widgets[id];if widget and widget.Parent then widget.Text=tostring(value or '—') end
end
function D.detail(parent,id,labelText,initial)
    local root=frame(parent,'Detail_'..id,38)
    local cap=text(root,labelText,11,theme.muted);cap.Size=UDim2.new(0.45,0,1,0)
    local value=text(root,initial or '—',12,theme.text);value.Position=UDim2.fromScale(0.45,0);value.Size=UDim2.new(0.55,0,1,0);value.TextXAlignment=Enum.TextXAlignment.Right
    D.widgets[id]=value;return value
end
function D.gauge(parent,id,labelText)
    local root=frame(parent,'Gauge_'..id,48)
    local cap=text(root,labelText,11,theme.muted);cap.Size=UDim2.new(0.65,0,0,20)
    local value=text(root,'—',11,theme.text);value.Position=UDim2.fromScale(0.65,0);value.Size=UDim2.new(0.35,0,0,20);value.TextXAlignment=Enum.TextXAlignment.Right
    local track=make('Frame',{Name='Track',Position=UDim2.fromOffset(0,33),Size=UDim2.new(1,0,0,5),BackgroundColor3=color(36,38,46),BorderSizePixel=0,ClipsDescendants=true},root);corner(track,3)
    local fill=make('Frame',{Name='Fill',Size=UDim2.fromScale(0,1),BackgroundColor3=theme.accent,BorderSizePixel=0},track);corner(fill,3);D.bind(fill,'BackgroundColor3')
    D.widgets[id]=value;D.widgets[id..'Fill']=fill
end
function D.setGauge(id,value,ratio)
    D.value(id,value);local fill=D.widgets[id..'Fill']
    if fill then D.animate(fill,0.24,{Size=UDim2.fromScale(clamp(isNum(ratio) and ratio or 0,0,1),1)}) end
end
function D.caption(parent,value)
    local cap=text(parentOf(parent),value,10,theme.muted);cap.TextWrapped=true;cap.Size=UDim2.new(1,0,0,28);cap.LayoutOrder=D.order(cap.Parent);return cap
end
function D.badge(parent,id,labelText,value)
    local root=frame(parent,'Badge_'..id,44)
    local cap=text(root,labelText,12,theme.text);cap.Size=UDim2.new(0.55,0,1,0)
    local pill=text(root,value,10,theme.muted);pill.Position=UDim2.fromScale(0.55,0);pill.Size=UDim2.new(0.45,0,1,0);pill.TextXAlignment=Enum.TextXAlignment.Right
    D.widgets[id]=pill;return pill
end
function D.rowList(parent,id,limit,emptyLabel)
    local root=frame(parent,'List_'..id,42)
    local list={root=root,pool={},limit=limit or 6}
    list.empty=text(root,emptyLabel or 'Aucun élément',12,theme.muted);list.empty.Size=UDim2.new(1,0,0,42)
    for i=1,list.limit do
        local row=make('TextButton',{Name='ListRow',Text='',AutoButtonColor=false,BackgroundColor3=theme.control,BorderSizePixel=0,Size=UDim2.new(1,0,0,44),Position=UDim2.fromOffset(0,(i-1)*50),Visible=false},root);corner(row,7)
        local dot=line(row,12,18,6,6,theme.accent);D.bind(dot,'BackgroundColor3')
        local title=text(row,'',12,theme.text);title.Position=UDim2.fromOffset(28,4);title.Size=UDim2.new(0.7,-28,0,22)
        local sub=text(row,'',9,theme.muted);sub.Position=UDim2.fromOffset(28,25);sub.Size=UDim2.new(0.75,-28,0,14)
        local badge=text(row,'',10,theme.muted);badge.Position=UDim2.fromScale(0.7,0);badge.Size=UDim2.new(0.3,-12,1,0);badge.TextXAlignment=Enum.TextXAlignment.Right
        local avatar=make('ImageLabel',{Name='PlayerAvatar',Visible=false,BackgroundTransparency=1,Size=UDim2.fromOffset(30,30),Position=UDim2.fromOffset(8,7),Image=''},row);corner(avatar,8)
        list.pool[i]={root=row,title=title,sub=sub,badge=badge,avatar=avatar,dot=dot}
        connect(row.Activated,function() if list.onSelect and list.rows and list.rows[i] then list.onSelect(list.rows[i]) end end)
    end
    function list:set(rows)
        self.rows=rows
        local n=math.min(#rows,self.limit);self.empty.Visible=n==0
        for i,entry in ipairs(self.pool) do
            entry.root.Visible=i<=n
            if rows[i] then
                local r=rows[i];entry.title.Text=tostring(r.title or '');entry.sub.Text=tostring(r.sub or '');entry.badge.Text=tostring(r.badge or '')
                entry.avatar.Visible=isNum(r.avatarId) and r.avatarId>0
                if entry.avatar.Visible then entry.avatar.Image='rbxthumb://type=AvatarHeadShot&id='..string.format('%.0f',r.avatarId)..'&w=150&h=150' end
                entry.dot.Visible=not entry.avatar.Visible
                entry.title.Position=UDim2.fromOffset(entry.avatar.Visible and 46 or 28,4);entry.title.Size=UDim2.new(0.7,entry.avatar.Visible and -46 or -28,0,22)
                entry.sub.Position=UDim2.fromOffset(entry.avatar.Visible and 46 or 28,25)
            end
        end
        self.root.Size=UDim2.new(1,0,0,n==0 and 42 or n*50-6)
    end
    D.lists[id]=list;return list
end
function D.chart(parent,id,labelText)
    local root=frame(parent,'Chart_'..id,108)
    local cap=text(root,labelText,11,theme.muted);cap.Size=UDim2.new(0.7,0,0,22)
    local value=text(root,'—',12,theme.text);value.Position=UDim2.fromScale(0.7,0);value.Size=UDim2.new(0.3,0,0,22);value.TextXAlignment=Enum.TextXAlignment.Right
    local plot=make('Frame',{BackgroundTransparency=1,Position=UDim2.fromOffset(0,30),Size=UDim2.new(1,0,0,64)},root)
    local chart={values={},bars={},label=value}
    for i=1,30 do
        local bar=make('Frame',{Name='Sample'..i,BackgroundColor3=theme.accent,BorderSizePixel=0,AnchorPoint=Vector2.new(0,1),
            Position=UDim2.new((i-1)/30,1,1,0),Size=UDim2.new(1/30,-3,0,0)},plot);corner(bar,2);D.bind(bar,'BackgroundColor3');chart.bars[i]=bar
    end
    D.charts[id]=chart
end
function D.recordMetrics(fps,ping)
    D.lastFPS=fps;D.lastPing=ping
    for id,chart in pairs(D.charts) do
        local value=id=='fps' and fps or (isNum(ping) and ping*1000 or nil)
        chart.values[#chart.values+1]=isNum(value) and value or false
        while #chart.values>30 do table.remove(chart.values,1) end
        local maximum=1;for _,n in ipairs(chart.values) do if isNum(n) then maximum=math.max(maximum,n) end end
        chart.label.Text=isNum(value) and string.format('%.0f%s',value,id=='fps' and ' FPS' or ' ms') or 'N/D'
        for i,bar in ipairs(chart.bars) do local n=chart.values[i];bar.Size=UDim2.new(1/30,-3,isNum(n) and n/maximum or 0,0) end
    end
end
-- Capture souris/tactile unique ; aucun enregistrement de reglages pendant un glisser.
D.pointer=nil
local function startPointer(input,move,finish,cancel)
    if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
    if D.pointer and D.pointer.cancel then D.pointer.cancel() end
    D.pointer={input=input,move=move,finish=finish,cancel=cancel};move(input.Position)
end
function D.cancelPointer()
    local p=D.pointer;D.pointer=nil;if p and p.cancel then p.cancel() end
end
connect(UIS.InputChanged,function(input)
    local p=D.pointer;if not p then return end
    if p.input.UserInputType==Enum.UserInputType.Touch and input~=p.input then return end
    if p.input.UserInputType~=Enum.UserInputType.Touch and input.UserInputType~=Enum.UserInputType.MouseMovement then return end
    p.move(input.Position)
end)
connect(UIS.InputEnded,function(input)
    local p=D.pointer
    if p and (input==p.input or (p.input.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseButton1)) then
        D.pointer=nil;if p.finish then p.finish() end
    end
end)
connect(UIS.WindowFocusReleased,D.cancelPointer)
local function fraction(control,point)
    local size,pos=control.AbsoluteSize,control.AbsolutePosition
    if not size or not pos or size.X<=0 or size.Y<=0 then return nil end
    return clamp((point.X-pos.X)/size.X,0,1),clamp((point.Y-pos.Y)/size.Y,0,1)
end
function D.colorPicker(parent,onPreview,onCommit)
    local root=frame(parent,'ColorPicker',230)
    local p={root=root,h=0,s=0,v=1,hex=ui.accent};D.picker=p
    local base=make('Frame',{Name='SVPlane',BackgroundColor3=color(255,0,0),BorderSizePixel=0,Size=UDim2.new(1,-34,0,160),ClipsDescendants=true},root);corner(base,8)
    local white=make('Frame',{BackgroundColor3=color(255,255,255),BorderSizePixel=0,Size=UDim2.fromScale(1,1)},base)
    make('UIGradient',{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)})},white)
    local black=make('Frame',{BackgroundColor3=color(0,0,0),BorderSizePixel=0,Size=UDim2.fromScale(1,1)},base)
    make('UIGradient',{Rotation=90,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)})},black)
    local hit=make('TextButton',{Name='SVInput',Text='',AutoButtonColor=false,BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=4},base)
    local marker=make('Frame',{Name='ColorCursor',BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromOffset(12,12),AnchorPoint=Vector2.new(0.5,0.5),ZIndex=5},base);corner(marker,6);stroke(marker,color(255,255,255))
    local hue=make('TextButton',{Name='HueInput',Text='',AutoButtonColor=false,BackgroundColor3=color(255,255,255),BorderSizePixel=0,
        Position=UDim2.new(1,-22,0,0),Size=UDim2.fromOffset(22,160)},root);corner(hue,6)
    local points={};for i=0,6 do points[#points+1]=ColorSequenceKeypoint.new(i/6,hexColor(Hub.hsvToHex(i/6,1,1))) end
    make('UIGradient',{Rotation=90,Color=ColorSequence.new(points)},hue)
    local hueCursor=make('Frame',{Name='HueCursor',Size=UDim2.new(1,6,0,5),Position=UDim2.fromOffset(-3,0),BackgroundColor3=color(255,255,255),BorderSizePixel=0},hue);corner(hueCursor,2)
    local swatch=make('Frame',{Name='ColorPreview',BackgroundColor3=theme.accent,BorderSizePixel=0,Position=UDim2.fromOffset(0,176),Size=UDim2.fromOffset(40,36)},root);corner(swatch,8)
    local hexLabel=text(root,'#'..ui.accent,16,theme.text);hexLabel.Position=UDim2.fromOffset(54,175);hexLabel.Size=UDim2.new(1,-54,0,24)
    local help=text(root,'Aperçu · appliquer pour sauvegarder',9,theme.muted);help.Position=UDim2.fromOffset(54,200);help.Size=UDim2.new(1,-54,0,18)
    function p.paint(preview)
        p.hex=Hub.hsvToHex(p.h,p.s,p.v);base.BackgroundColor3=hexColor(Hub.hsvToHex(p.h,1,1));swatch.BackgroundColor3=hexColor(p.hex)
        hexLabel.Text='#'..p.hex;marker.Position=UDim2.fromScale(p.s,1-p.v);hueCursor.Position=UDim2.new(0,-3,p.h,-2)
        if preview then
            D.fastPreview=true;local ok,err=pcall(onPreview,p.hex);D.fastPreview=false
            if not ok then error(err) end
        end
    end
    function p.sync(hex)
        local h,s,v=Hub.hexToHSV(hex);if not h then return false end
        p.h,p.s,p.v=h,s,v;p.paint(false);return true
    end
    function p.cancel() p.sync(ui.accent);onPreview(ui.accent) end
    function p.commit() ui.accent=p.hex;onCommit(p.hex) end
    function p.layout() end
    local function svStart(input)
        startPointer(input,function(point) local x,y=fraction(hit,point);if x then p.s=x;p.v=1-y;p.paint(true) end end,nil,p.cancel)
    end
    connect(hit.InputBegan,svStart);connect(marker.InputBegan,svStart)
    local function hueStart(input)
        startPointer(input,function(point) local _,y=fraction(hue,point);if y then p.h=math.min(y,0.999999);p.paint(true) end end,nil,p.cancel)
    end
    connect(hue.InputBegan,hueStart);connect(hueCursor.InputBegan,hueStart)
    p.sv=hit;p.hue=hue;p.sync(ui.accent);return p
end
function D.slider(parent,name,labelText,lo,hi,initial,onCommit)
    local root=frame(parent,name,62)
    local cap=text(root,labelText,12,theme.text);cap.Size=UDim2.new(0.7,0,0,22)
    local val=text(root,string.format('%.0f %%',initial*100),11,theme.muted);val.Position=UDim2.fromScale(0.7,0);val.Size=UDim2.new(0.3,0,0,22);val.TextXAlignment=Enum.TextXAlignment.Right
    local hit=make('TextButton',{Name='SliderInput',Text='',AutoButtonColor=false,BackgroundTransparency=1,Position=UDim2.fromOffset(0,28),Size=UDim2.new(1,0,0,30)},root)
    local track=make('Frame',{BackgroundColor3=color(40,42,52),BorderSizePixel=0,Position=UDim2.fromOffset(0,11),Size=UDim2.new(1,0,0,5)},hit);corner(track,3)
    local fill=make('Frame',{BackgroundColor3=theme.accent,BorderSizePixel=0,Size=UDim2.fromScale((initial-lo)/(hi-lo),1)},track);corner(fill,3);D.bind(fill,'BackgroundColor3')
    local knob=make('Frame',{BackgroundColor3=theme.text,BorderSizePixel=0,Size=UDim2.fromOffset(12,12),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale((initial-lo)/(hi-lo),0.5)},track);corner(knob,6)
    local slider={value=initial,root=root,input=hit}
    function slider.sync(value) slider.value=value;val.Text=string.format('%.0f %%',value*100);fill.Size=UDim2.fromScale((value-lo)/(hi-lo),1);knob.Position=UDim2.fromScale((value-lo)/(hi-lo),0.5) end
    local function start(input)
        local before=slider.value
        startPointer(input,function(point) local x=fraction(hit,point);if x then slider.sync(math.floor((lo+x*(hi-lo))*100+0.5)/100) end end,
            function() onCommit(slider.value) end,function() slider.sync(before) end)
    end
    connect(hit.InputBegan,start);connect(knob.InputBegan,start)
    return slider
end
function D.buildServer(serverPage,action)
    local maxPlayers=Players.MaxPlayers
    S.server=Hub.newServer(os.clock(),isNum(maxPlayers) and maxPlayers>0 and maxPlayers or nil)
    local monitor=S.server
    local function added(p,baseline)
        if not S.running then return end
        local changed=monitor:add(p.UserId,p.Name,p.DisplayName,os.clock(),baseline)
        if changed and S.observatory then S.observatory.queueFriend(p);if not baseline then S.observatory.presence('arrivee',p.UserId) end end
    end
    connect(Players.PlayerAdded,function(p) added(p,false) end)
    connect(Players.PlayerRemoving,function(p) if S.running then
        if S.observatory then S.observatory.presence('depart',p.UserId) end
        monitor:remove(p.UserId,os.clock())
    end end)
    local ok,players=pcall(function() return Players:GetPlayers() end)
    if ok then for _,p in ipairs(players) do added(p,true) end end
    D.section(serverPage,'Serveur en direct')
    D.metricsGrid(serverPage,{{id='serverPlayers',label='JOUEURS PRÉSENTS'},{id='serverCapacity',label='CAPACITÉ'},{id='serverJoined',label='ARRIVÉES OBSERVÉES'},{id='serverLeft',label='DÉPARTS OBSERVÉS'}})
    D.gauge(serverPage,'serverOccupancy','Remplissage du serveur')
    D.badge(serverPage,'serverRegion','Localisation','Non fournie')
    D.caption(serverPage,'Roblox ne communique pas la région physique au client.')
    D.detail(serverPage,'serverPing','Ping vers le serveur','N/D')
    D.detail(serverPage,'serverJob','Identifiant',type(game.JobId)=='string' and game.JobId~='' and game.JobId or 'N/D')
    action(serverPage,'Copier l’identifiant du serveur',function()
        if type(setclipboard)=='function' and type(game.JobId)=='string' and game.JobId~='' then
            local copied=pcall(setclipboard,game.JobId);S.toast(copied and 'Identifiant copié' or 'Copie impossible','info')
        else S.toast('Presse-papiers ou identifiant indisponible','warn') end
    end)
    D.section(serverPage,'Joueurs présents')
    D.rowList(serverPage,'serverRoster',8,'Aucun joueur observé')
    D.rosterPage=1
    local controls=frame(serverPage,'RosterPagination',34)
    local prev=make('TextButton',{Name='RosterPrevious',Text='‹',TextColor3=theme.text,TextSize=18,Font=Enum.Font.Gotham,
        BackgroundColor3=theme.control,BorderSizePixel=0,Size=UDim2.fromOffset(36,32)},controls);corner(prev,6)
    local nextButton=make('TextButton',{Name='RosterNext',Text='›',TextColor3=theme.text,TextSize=18,Font=Enum.Font.Gotham,
        BackgroundColor3=theme.control,BorderSizePixel=0,Position=UDim2.new(1,-36,0,0),Size=UDim2.fromOffset(36,32)},controls);corner(nextButton,6)
    local pageNumber=text(controls,'1 / 1',11,theme.muted);pageNumber.Position=UDim2.fromOffset(44,0);pageNumber.Size=UDim2.new(1,-88,1,0);pageNumber.TextXAlignment=Enum.TextXAlignment.Center;D.widgets.rosterPage=pageNumber
    connect(prev.Activated,function() D.rosterPage=math.max(1,D.rosterPage-1);D.refreshServer() end)
    connect(nextButton.Activated,function() D.rosterPage=math.min(math.max(1,math.ceil(monitor.count/8)),D.rosterPage+1);D.refreshServer() end)
    D.section(serverPage,'Dernières arrivées')
    D.caption(serverPage,'Historique depuis l’ouverture du hub')
    D.rowList(serverPage,'serverJoins',6,'Aucune arrivée depuis l’ouverture')
    D.section(serverPage,'Derniers départs')
    D.rowList(serverPage,'serverLeaves',6,'Aucun départ depuis l’ouverture')
end
function D.refreshServer()
    local m=S.server;if not m then return end
    D.value('serverPlayers',m.count);D.value('serverCapacity',m.maxPlayers or 'N/D');D.value('serverJoined',m.joined);D.value('serverLeft',m.left)
    D.setGauge('serverOccupancy',m.count..' / '..tostring(m.maxPlayers or '?'),m.maxPlayers and m.count/m.maxPlayers or 0)
    D.value('serverPing',isNum(D.lastPing) and string.format('%.0f ms',D.lastPing*1000) or 'N/D')
    local roster=m:roster();local pages=math.max(1,math.ceil(#roster/8));D.rosterPage=clamp(D.rosterPage or 1,1,pages)
    local rows={}
    for i=(D.rosterPage-1)*8+1,math.min(#roster,D.rosterPage*8) do
        local p=roster[i];rows[#rows+1]={title=p.display,sub='@'..p.name,badge=p.id==player.UserId and 'VOUS' or 'PRÉSENT'}
    end
    D.lists.serverRoster:set(rows);D.value('rosterPage',D.rosterPage..' / '..pages)
    for kind,key in pairs({join='serverJoins',leave='serverLeaves'}) do
        rows={}
        for _,e in ipairs(m:recent(kind,6)) do rows[#rows+1]={title=e.player.display,sub='@'..e.player.name,badge=string.format('%.0f s',math.max(0,os.clock()-e.at))} end
        D.lists[key]:set(rows)
    end
end
function D.refreshVisuals()
    local h,m=S.hub,S.hub.money
    local snap=h:snapshot(os.clock());local observedFor=m.observedStartedAt and math.max(0,os.clock()-m.observedStartedAt) or 0
    local rate=observedFor>=60 and string.format('%.0f $/h',m.observedIncreases*3600/observedFor) or 'N/D'
    D.value('cash',shortMoney(S.moneyReading and S.moneyReading.available and S.moneyReading.value or nil));D.value('earned',shortMoney(m.observedIncreases));D.value('deposited',shortMoney(m.deposited));D.value('hourly',rate)
    D.value('sales',m.sales);D.value('deposits',m.deposits);D.value('baitUsed',m.baitUsed);D.value('baitAdded',m.baitAdded)
    D.value('saleEarnings',shortMoney(m.earned));D.value('observedDown',shortMoney(m.observedDecreases))
    D.value('fishingInput',S.fishingInputStatus or (S.baitScreenPoint and 'Écran enregistré' or 'Visée à capturer'))
    local state=S.moneyReading
    local masked=state and (state.status:find('masque',1,true) or state.status:find('non visible',1,true))
    D.value('moneyStatus',state and (state.available and 'Actif' or (masked and 'Masqué' or (#S.moneyCandidates>0 and 'À choisir' or 'Non trouvé'))) or 'Recherche')
    if D.lists.moneySources then
        local rows={};for _,entry in ipairs(S.moneyCandidates or {}) do rows[#rows+1]={title=entry.text,sub=entry.path,badge='CHOISIR',key=entry.path} end
        D.lists.moneySources:set(rows);D.lists.moneySources.root.Visible=S.showMoneySources==true
    end
    D.value('casts',S.castAttempts);D.value('clicks',S.clicks);D.value('activity',D.stateText(S.state,''));D.value('carName',S.car and S.car.name or 'Aucun véhicule')
    D.value('activeSpot',h.activeSpot or 'Aucun spot');D.value('spotsCount',countKeys(h.library.spots));D.value('routesCount',countKeys(h.library.routes));D.value('recordedPoints',#S.recordBuffer)
    D.value('farmPlanted',h.farm.planted);D.value('farmHarvested',h.farm.harvested);D.value('farmCycles',h.farm.cycles);D.value('farmStatus',h.farm.available and 'Adaptateur chargé' or 'Indisponible')
    D.value('errorsCount',#h.errors);D.value('session',string.format('%02d:%02d',math.floor(snap.elapsed/60),math.floor(snap.elapsed%60)))
    D.setGauge('inventory',S.inventoryText,(S.fishCount or 0)/S.inventoryLimit)
    local driveRatio=S.driver and S.driver.total and (S.driver.s or 0)/S.driver.total or 0
    D.setGauge('drive',string.format('%.0f %%',driveRatio*100),driveRatio)
    local seat=currentSeat and currentSeat() -- fourni par la portee du script, lecture seulement
    D.value('vehicleSpeed',seat and string.format('%.0f studs/s',seat.AssemblyLinearVelocity.Magnitude) or '—')
    local function libraryList(key,source)
        local rows={};for name,value in pairs(source) do rows[#rows+1]={title=name,sub=key=='spots' and 'Spot enregistré' or 'Trajet enregistré',badge=key=='spots' and (h.activeSpot==name and 'ACTIF' or '') or (#value..' pts')} end
        table.sort(rows,function(a,b) return a.title<b.title end);if D.lists[key] then D.lists[key]:set(rows) end
    end
    libraryList('spots',h.library.spots);libraryList('routes',h.library.routes)
    if D.lists.spotStats then
        local rows={};for name,stat in pairs(h.spotStats) do rows[#rows+1]={title=name,sub=stat.texts..' textes · '..stat.rareSignals..' signaux rares',badge=stat.casts..' lancers'} end
        table.sort(rows,function(a,b) return a.title<b.title end);D.lists.spotStats:set(rows)
    end
    if D.lists.errors then
        local rows={};for i=#h.errors,math.max(1,#h.errors-5),-1 do local e=h.errors[i];rows[#rows+1]={title=e.stage,sub=e.message,badge='ERREUR'} end
        D.lists.errors:set(rows)
    end
    for _,meta in pairs(D.pages) do
        local vals
        if meta.name=='Money' then vals={shortMoney(m.observedIncreases),shortMoney(S.moneyReading and S.moneyReading.available and S.moneyReading.value or nil),rate}
        elseif meta.name=='Vehicle' then vals={S.car and S.car.name or '—',tostring(countKeys(h.library.routes)),tostring(#S.recordBuffer)}
        elseif meta.name=='Server' then vals={S.server and tostring(S.server.count) or '—',S.server and tostring(S.server.maxPlayers or '?') or '—',isNum(D.lastPing) and string.format('%.0f ms',D.lastPing*1000) or 'N/D'}
        elseif meta.name=='Farming' then
            local rows=S.observatory and S.observatory.plants:rows(os.clock()) or {};local ready=0
            for _,r in ipairs(rows) do if r.ready and not r.estimated then ready=ready+1 end end
            vals={tostring(#rows),tostring(ready),rows[1] and ((rows[1].estimated and '~ ' or '')..Hub.duration(rows[1].remaining)) or '—'}
        elseif meta.name=='Settings' then vals={'#'..ui.accent,string.format('%.0f %%',ui.scale*100),ui.animations and 'Activées' or 'Coupées'}
        elseif meta.name=='Statistics' then vals={string.format('%02d:%02d',math.floor(snap.elapsed/60),math.floor(snap.elapsed%60)),tostring(S.castAttempts),tostring(#h.errors)}
        else vals={S.inventoryText or '—',S.baitUnknown and '—' or 'x'..tostring(S.baitCount),tostring(S.castAttempts)} end
        for i,v in ipairs(vals) do meta.tiles[i].Text=v end
    end
    D.refreshServer()
    if D.refreshInsights then D.refreshInsights() end
end


end


-- ANNONCES : bulles "verre" en haut au centre (au plus 3, disparaissent apres 4 s)
do -- annonces (portee fermee : limite de 200 locales)
local toastHolder = make('Frame', { Name = 'Toasts', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(400, 200), ZIndex = 20 }, gui)
make('UIListLayout', { Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder }, toastHolder)
local TOAST_COLORS = { ok = Color3.fromRGB(110, 230, 150), warn = Color3.fromRGB(255, 196, 90),
    error = Color3.fromRGB(255, 110, 110), rare = Color3.fromRGB(190, 120, 255), info = Color3.fromRGB(120, 200, 255) }
local toastSeq, lastToastText, lastToastAt = 0, nil, -100
local tween = S.animate
function S.toast(text, kind)
    if not ui.toasts or not toastHolder.Parent then return end
    text = tostring(text)
    if text == lastToastText and os.clock() - lastToastAt < 3 then return end -- pas de doublon en rafale
    lastToastText, lastToastAt = text, os.clock()
    toastSeq = toastSeq + 1
    local cards = {}
    for _, c in ipairs(toastHolder:GetChildren()) do if c.Name == 'Toast' then cards[#cards + 1] = c end end
    table.sort(cards, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
    while #cards >= 3 do table.remove(cards, 1):Destroy() end
    local card = make('Frame', { Name = 'Toast', LayoutOrder = toastSeq, Size = UDim2.fromOffset(380, 44),
        BackgroundColor3 = Color3.fromRGB(10, 10, 10), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 20 }, toastHolder)
    round(card, 22)
    make('UIGradient', { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 180, 200)) }, card)
    local stroke = make('UIStroke', { Color = Color3.fromRGB(255, 255, 255), Thickness = 1, Transparency = 1 }, card)
    local dot = make('Frame', { Size = UDim2.fromOffset(10, 10), Position = UDim2.new(0, 16, 0.5, -5),
        BackgroundColor3 = TOAST_COLORS[kind] or TOAST_COLORS.info, BorderSizePixel = 0, BackgroundTransparency = 1, ZIndex = 21 }, card)
    round(dot, 5)
    local txt = make('TextLabel', { BackgroundTransparency = 1, Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -50, 1, 0),
        Text = text, TextColor3 = Color3.fromRGB(245, 247, 250), TextTransparency = 1, TextSize = 14, Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 21 }, card)
    tween(card, 0.25, { BackgroundTransparency = 0.35 })
    tween(stroke, 0.25, { Transparency = 0.65 })
    tween(dot, 0.25, { BackgroundTransparency = 0 })
    tween(txt, 0.25, { TextTransparency = 0 })
    task.delay(4, function()
        if not card.Parent then return end
        tween(card, 0.35, { BackgroundTransparency = 1 })
        tween(stroke, 0.35, { Transparency = 1 })
        tween(dot, 0.35, { BackgroundTransparency = 1 })
        tween(txt, 0.35, { TextTransparency = 1 })
        task.delay(0.4, function() if card.Parent then card:Destroy() end end)
    end)
end
end

local function fitWindow()
    local v, sc = viewportSize(), ui.scale
    local maxW, maxH = math.max(1, v.X / sc), math.max(1, v.Y / sc)
    local w = clamp(window.Size.X.Offset, math.min(420, maxW), maxW)
    local h = clamp(window.Size.Y.Offset, math.min(400, maxH), maxH)
    window.Size = UDim2.fromOffset(w, h)
    window.Position = UDim2.fromOffset(clamp(window.Position.X.Offset, 0, math.max(0, v.X - w * sc)),
        clamp(window.Position.Y.Offset, 0, math.max(0, v.Y - h * sc)))
    S.design.layout()
end
-- L'ancienne taille par defaut est migree ; les tailles personnalisees restent intactes.
if ui.size and ui.size.x == 430 and ui.size.y == 500 and not (settingsRaw and settingsRaw.layoutVersion == 2) then ui.size = nil; ui.position = nil end
local size0 = ui.size or { x = 960, y = 640 }
local pos0 = ui.position or { x = math.max(0,(viewportSize().X-size0.x*ui.scale)/2), y = math.max(0,(viewportSize().Y-size0.y*ui.scale)/2) }
window.Size = UDim2.fromOffset(size0.x, size0.y)
window.Position = UDim2.fromOffset(pos0.x, pos0.y)

local accentItems = {}
local function label(parent, text, height)
    parent = S.design.parent(parent)
    return make('TextLabel', { Size = UDim2.new(1, 0, 0, height or 32), BackgroundTransparency = 1, Text = text, LayoutOrder = S.design.order(parent),
        TextWrapped = true, TextColor3 = theme.muted, TextSize = 13, Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center }, parent)
end
local function button(parent, text, fn, height)
    parent = S.design.parent(parent)
    local b = make('TextButton', { Size = UDim2.new(1, 0, 0, height or 44), LayoutOrder = S.design.order(parent), BackgroundColor3 = theme.control, BorderSizePixel = 0,
        Text = text, TextColor3 = theme.text, TextSize = 12, Font = Enum.Font.GothamMedium, TextWrapped = true,
        AutoButtonColor = true, TextXAlignment = Enum.TextXAlignment.Left }, parent)
    round(b, 7); outline(b); inset(b, 12)
    S.design.hover(b, b:FindFirstChildOfClass('UIStroke'))
    connect(b.Activated, function() fn(b) end)
    return b
end
local function textbox(parent, placeholder)
    parent = S.design.parent(parent)
    local t = make('TextBox', { Size = UDim2.new(1, 0, 0, 40), LayoutOrder = S.design.order(parent), BackgroundColor3 = theme.background, BorderSizePixel = 0,
        Text = '', PlaceholderText = placeholder, ClearTextOnFocus = false, PlaceholderColor3 = theme.muted,
        TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = theme.text, TextSize = 13, Font = Enum.Font.Gotham }, parent)
    round(t, 7); outline(t); inset(t, 14)
    return t
end
local function section(parent, text)
    local heading = S.design.section(parent, text)
    if heading then return heading end
    local h = label(parent, text, 24)
    h.TextSize, h.TextColor3, h.Font = 11, theme.accent, Enum.Font.GothamBold
    table.insert(accentItems, h)
    return h
end
local function notice(parent, text, height)
    local n = label(parent, text, height or 52)
    n.BackgroundTransparency, n.BackgroundColor3, n.TextColor3 = 0, theme.surface, theme.muted
    n.TextYAlignment = Enum.TextYAlignment.Center
    n.BackgroundColor3 = theme.control
    round(n, 7); inset(n, 12)
    return n
end
local toggles = {}
local function toggle(parent, textFn, fn, height)
    local row
    local b = button(parent, textFn(), function(b) fn(); row.paint(textFn()); S.design.layout() end, height or 50)
    row = S.design.decorateRow(b, textFn())
    table.insert(toggles, function() local t = textFn(); if b.Text ~= t then row.paint(t) end end)
    return b
end
function S.refreshToggles() for _, f in ipairs(toggles) do pcall(f) end end
local function grid(parent, items, h)
    parent = S.design.parent(parent)
    h = h or 44
    local holder = make('Frame', { BackgroundTransparency = 1, LayoutOrder = S.design.order(parent), Size = UDim2.new(1, 0, 0, math.ceil(#items / 2) * (h + 6)) }, parent)
    for i, it in ipairs(items) do
        local b = button(holder, it[1], it[2], h)
        b.Size = UDim2.new(0.5, -4, 0, h)
        b.Position = UDim2.new(((i - 1) % 2) * 0.5, ((i - 1) % 2) * 4, 0, math.floor((i - 1) / 2) * (h + 6))
    end
    return holder
end

-- Barre laterale, profil Roblox et en-tete editorial.
S.design.createChrome()
local top = S.design.dragHandle
local title = S.design.brandTitle
local sub = S.design.versionLabel
local metrics = S.design.metrics
local tabBar = S.design.nav
local footer = S.design.footer
stateLabel = S.design.stateLabel
local resize = S.design.resize

local pages, tabButtons, pageOrder = {}, {}, {}
local activePage = 'Fishing'
local function updateTabs()
    S.design.navigation(pages, activePage)
end
local function page(name)
    local body = make('ScrollingFrame', { Name = name, BackgroundTransparency = 1, BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 0), Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = theme.border, Visible = false }, S.design.content)
    make('UIListLayout', { Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder }, body)
    make('UIPadding', { PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 16) }, body)
    pages[name] = body
    pageOrder[#pageOrder + 1] = name
    S.design.addPage(body, name)
    tabButtons[name] = S.design.navButton(name, function() activePage = name; updateTabs() end)
    return body
end

---------------------------------------------------------------------------
-- ACCUEIL
---------------------------------------------------------------------------
local home = page('Fishing')
section(home,'Automatisation')
toggle(home, function() return (S.fishingEnabled and '[ON]  ' or '[OFF] ') .. 'Peche automatique' end,
    function() S.fishingEnabled = not S.fishingEnabled end, 44)
toggle(home,function() return 'Visée enregistrée : '..(ui.aimAssist and 'oui' or 'non') end,
    function() S.setFishingAimAssist(not ui.aimAssist);saveSettings() end)
S.design.caption(home,'Mode classique par défaut : place le curseur vers l’eau. La visée enregistrée est facultative.')
toggle(home,function() return string.format('Relance après une manche : %.2f s',ui.recastDelay) end,function()
    local nextDelay=0.35
    for _,n in ipairs({0.35,0.75,1.5,2.5}) do if n>ui.recastDelay+0.001 then nextDelay=n;break end end
    ui.recastDelay=nextDelay;S.castDelay=nextDelay;saveSettings()
end)
toggle(home, function() return (S.autoCycle and '[ON]  ' or '[OFF] ') .. 'Vente auto quand l\'inventaire est plein' end,
    function() S.autoCycle = not S.autoCycle; S.cycleFailures = 0; logLine('Vente auto ' .. (S.autoCycle and 'activee' or 'desactivee')) end, 44)
toggle(home, function() return 'Poisson rare : ' .. RARE_ACTIONS[ui.rareAction] end,
    function()
        local order = { none = 'leave', leave = 'sell', sell = 'none' }
        ui.rareAction = order[ui.rareAction]; saveSettings()
        logLine('Poisson rare (violet / legendaire) : ' .. RARE_ACTIONS[ui.rareAction])
    end, 44)
toggle(home, function() return 'Vitesse voiture : ' .. S.speedPreset end,
    function() S.nextSpeedPreset(); ui.speedPreset = S.speedPreset; saveSettings() end, 44)
section(home,'Session de pêche')
S.design.gauge(home,'inventory','Inventaire')
S.design.metricsGrid(home,{{id='casts',label='LANCERS'},{id='clicks',label='CLICS MINI-JEU'}})
S.design.detail(home,'activeSpot','Spot actif','Aucun spot')
S.design.detail(home,'fishingInput','Visée / clics','En attente')
logLabel = notice(home, '', 128)
logLabel.Visible = false
logLabel.TextSize = 11; logLabel.Font = Enum.Font.Code

---------------------------------------------------------------------------
-- BLACK EDITION : gestion des spots, vehicules, argent et culture.
do
local function result(ok, message)
    local text = message or (ok and 'Operation terminee en memoire' or 'Operation refusee')
    logLine(text); if S.toast then S.toast(text, ok and 'ok' or 'warn') end
end
section(home, 'SPOTS DE PECHE')
S.design.caption(home,'Enregistre cet endroit avec sa visée, puis retrouve-le ici.')
local spotName = textbox(home, 'Nom du spot')
grid(home, {
    { 'Enregistrer ce spot', function() local ok,msg,name=S.saveSpot(spotName.Text);if ok then spotName.Text=name end;result(ok,msg) end },
    { 'Selectionner le spot', function() local ok,msg,name=S.selectSpot(spotName.Text);if ok then spotName.Text=name end;result(ok,msg) end },
    { 'Supprimer ce spot', function() result(S.removeLibraryItem('spot', spotName.Text)) end },
    { 'Sauvegarder la bibliotheque', function() result(S.saveLibrary()) end },
})
button(home, 'Capturer la visee dans 3 secondes', function()
    local tok = S.token
    local expectedSpot = S.hub.activeSpot
    S.toast('Place la souris sur l\'eau : capture dans 3 s', 'info')
    task.delay(3, function()
        if not alive(tok) then return end
        result(S.captureAimNow(expectedSpot))
    end)
end)
button(home, 'Reprendre la peche apres STOP', function()
    result(S.resume(), S.inventoryFull and 'Inventaire plein : liberer avant de reprendre' or 'Reprise demandee')
end)
S.design.rowList(home,'spots',5,'Aucun spot enregistré').onSelect=function(row) spotName.Text=row.title;result(S.selectSpot(row.title)) end
S.design.detail(home,'spotsCount','Spots enregistrés','0')

local vehicle = page('Vehicle')
section(vehicle, 'AUTO DRIVE V2')
S.design.detail(vehicle,'carName','Véhicule','Aucun véhicule')
S.design.metricsGrid(vehicle,{{id='vehicleSpeed',label='VITESSE MESURÉE'},{id='recordedPoints',label='POINTS ENREGISTRÉS'}})
S.design.gauge(vehicle,'drive','Progression du trajet')
grid(vehicle, {
    { 'Memoriser voiture actuelle', function() result(rememberCar()) end },
    { 'Tester ALLER', function() result(testDrive('aller')) end },
    { 'Tester RETOUR', function() result(testDrive('retour')) end },
    { 'Recharger la bibliotheque', function() result(S.loadLibrary()) end },
})
toggle(vehicle, function() return 'Vitesse voiture : ' .. S.speedPreset end,
    function() S.nextSpeedPreset(); ui.speedPreset = S.speedPreset; saveSettings() end)
toggle(vehicle, function() return S.recording and ('Enregistrement : ' .. #S.recordBuffer .. ' points (arreter)') or 'Enregistrer un nouveau trajet' end,
    function()
        if S.cycleRunning then result(false, 'Activite en cours'); return end
        S.recording = not S.recording
        if S.recording then S.recordBuffer = {} end
    end)
section(vehicle,'Destinations')
S.design.rowList(vehicle,'routes',6,'Aucune destination enregistrée')
local routeName = textbox(vehicle, 'Nom de destination')
S.design.lists.routes.onSelect=function(row) routeName.Text=row.title end
grid(vehicle, {
    { 'Conserver le trajet nomme', function() result(S.saveNamedRoute(routeName.Text)) end },
    { 'Conduire vers destination', function() result(S.driveNamedRoute(routeName.Text)) end },
    { 'Supprimer destination', function() result(S.removeLibraryItem('route', routeName.Text)) end },
    { 'Sauvegarder la bibliotheque', function() result(S.saveLibrary()) end },
})

local money = page('Money')
section(money, 'MONEY MANAGER / SESSION')
S.design.metricsGrid(money,{{id='cash',label='PORTEFEUILLE OBSERVÉ'},{id='earned',label='HAUSSES OBSERVÉES'},{id='deposited',label='TOTAL DÉPOSÉ'},{id='hourly',label='ESTIMATION / HEURE'}})
S.views.money = S.design.widgets.cash
S.design.caption(money,'Hausses du compteur observé · attribution aux ventes séparée')
S.design.badge(money,'moneyStatus','Lecture du portefeuille','Recherche')
section(money,'Ventes & dépôts')
S.design.metricsGrid(money,{{id='sales',label='VENTES MESURÉES'},{id='deposits',label='DÉPÔTS OBSERVÉS'},{id='baitUsed',label='APPÂTS EN MOINS'},{id='baitAdded',label='APPÂTS AJOUTÉS'},{id='saleEarnings',label='REVENUS DE VENTES'},{id='observedDown',label='BAISSES OBSERVÉES'}})
button(money, 'Actualiser le solde observe', function() result(S.refreshMoney());S.refreshDashboard() end)
button(money,'Rechercher / choisir le compteur',function()
    S.showMoneySources=true;result(S.searchMoneySources());S.refreshDashboard()
end)
S.design.caption(money,'Si la lecture échoue, choisis uniquement le compteur du portefeuille.')
local moneySources=S.design.rowList(money,'moneySources',10,'Aucun compteur monétaire visible')
moneySources.root.Visible=false
moneySources.onSelect=function(row)
    local ok,msg=S.chooseMoneySource(row.key)
    if ok then ui.moneySourcePath=S.moneySourcePath;saveSettings();S.showMoneySources=false end
    result(ok,msg);S.refreshDashboard()
end
button(money,'Revenir à la lecture automatique',function()
    ui.moneySourcePath=nil;result(S.resetMoneySource());saveSettings();S.refreshDashboard()
end)
button(money, 'Lancer le cycle vente / ATM / retour', function() result(S.runCycle()) end)
toggle(money, function() return 'Depot ATM : ' .. (S.autoBank and 'actif' or 'inactif') end,
    function() if not S.cycleRunning then S.autoBank = not S.autoBank end end)
toggle(money, function() return 'Exiger une preuve de depot : ' .. (S.depositRequired and 'oui' or 'non') end,
    function() if not S.cycleRunning then S.depositRequired = not S.depositRequired end end)

local farming = page('Farming')
section(farming, 'AUTO FARM / ADAPTATEUR REQUIS')
S.design.badge(farming,'farmStatus','Culture automatique','Indisponible')
S.design.caption(farming,'Interactions de plantation et récolte à identifier dans le jeu.')
S.design.metricsGrid(farming,{{id='farmPlanted',label='PLANTATIONS'},{id='farmHarvested',label='RÉCOLTES'}})
local planBox = textbox(farming, 'Parcelles : A:Corn, B:Pumpkin')
local replant = true
toggle(farming, function() return 'Replantation : ' .. (replant and 'oui' or 'non') end, function() replant = not replant end)
button(farming, 'Demarrer la culture (adaptateur requis)', function()
    local plan = {}
    for entry in planBox.Text:gmatch('[^,]+') do
        local plot, crop = entry:match('^%s*([^:]+):%s*(.-)%s*$')
        if not plot or crop == '' then result(false, 'Format : parcelle:plante, parcelle:plante'); return end
        plan[#plan + 1] = { plot = plot:match('^%s*(.-)%s*$'), crop = crop }
    end
    result(S.startFarm(plan, replant))
end)
button(farming, 'Diagnostic ecran pour la culture', function() S.dumpGui() end)
end

-- INDEX : poissons et plantes
---------------------------------------------------------------------------
-- Sources web consultees le 2026-11-05 (sites de fans, NON verifiees en jeu) :
-- treyexgaming.com/blockspin-fishing-update-2-guide, blockspin-wiki.wiki, TikTok.
S.fishLog = {}
local FISHLOG_FILE = 'blockspin_fishlog.json'
local refreshFishLog
pcall(function()
    if type(readfile) == 'function' and type(isfile) == 'function' and isfile(FISHLOG_FILE) then
        local d = HttpService:JSONDecode(readfile(FISHLOG_FILE))
        if type(d) == 'table' then for k, v in pairs(d) do if type(k) == 'string' and isNum(v) then S.fishLog[k] = v end end end
    end
end)
do -- index (portee fermee : limite de 200 locales)
local FISH_WEB = {
    { 'Salmon (saumon)', 'normal', '~138-162 $' },
    { 'Pufferfish', '?', '~8 000 $' },
    { 'Oarfish', 'Legendaire', '~68 000 $' },
    { 'Shark (requin)', '?', '~222 750-275 000 $' },
    { 'Anglerfish', 'rare', '~334 000 $' },
    { 'Megalodon', '?', '?' },
    { 'Omega Shark', 'Omega (plus rare)', '?' },
}
local PLANTS_WEB = {
    { 'Mais (Corn)', 'graine ~250 selon une video, non verifie' },
    { 'Citrouille (Pumpkin)', 'gains annonces par des joueurs, non verifies' },
}
local index = page('Statistics')
S.views.dashboard = section(index, 'Session')
S.design.metricsGrid(index,{{id='session',label='DURÉE'},{id='errorsCount',label='ERREURS'}})
S.design.detail(index,'activity','Activité','Prêt')
section(index,'Performances')
S.design.chart(index,'fps','Images par seconde')
S.design.chart(index,'ping','Ping vers le serveur')
section(index, 'STATISTIQUES PAR SPOT (SESSION)')
S.design.rowList(index,'spotStats',8,'Aucune mesure par spot')
section(index, 'JOURNAL DES ERREURS (80 MAXIMUM)')
S.design.rowList(index,'errors',6,'Aucune erreur observée')
S.views.errors = S.design.lists.errors.root
section(index,'Diagnostic')
button(index,'Afficher / masquer le journal technique',function() logLabel.Visible=not logLabel.Visible;S.design.layout() end)
logLabel.Parent = S.design.parent(index)
logLabel.LayoutOrder = S.design.order(logLabel.Parent)
section(index, 'Catalogue indicatif')
S.design.caption(index,'Sources web · informations à confirmer en jeu')
local lines = {}
for _, f in ipairs(FISH_WEB) do lines[#lines + 1] = string.format('%s  |  %s  |  %s', f[1], f[2], f[3]) end
do
local rows={};for _,f in ipairs(FISH_WEB) do rows[#rows+1]={title=f[1],sub=f[2],badge=f[3]} end
S.design.rowList(index,'catalogFish',8,'Aucun poisson référencé'):set(rows)
end
section(index, 'VUS PENDANT TES PECHES (textes apparus apres une prise)')
local seenList = S.design.rowList(index,'seenFish',10,'Aucun texte de prise observé')
refreshFishLog = function()
    local names = {}
    for k, v in pairs(S.fishLog) do names[#names + 1] = { k, v } end
    table.sort(names, function(a, b) return a[2] > b[2] end)
    local t = {}
    for i = 1, math.min(15, #names) do t[#t + 1] = names[i][1] .. '  x' .. names[i][2] end
    local rows={};for i=1,math.min(10,#names) do rows[#rows+1]={title=names[i][1],sub='Texte observé',badge='x'..names[i][2]} end
    seenList:set(rows)
end
refreshFishLog()
section(index, 'Plantes référencées')
lines = {}
for _, p in ipairs(PLANTS_WEB) do lines[#lines + 1] = p[1] .. '  |  ' .. p[2] end
do
local rows={};for _,plant in ipairs(PLANTS_WEB) do rows[#rows+1]={title=plant[1],sub='Référence web non validée',badge='À VALIDER'} end
S.design.rowList(index,'catalogPlants',3,'Aucune plante référencée'):set(rows)
end
end

---------------------------------------------------------------------------
-- REGLAGES
---------------------------------------------------------------------------
do
local serverPage = page('Server')
S.design.buildServer(serverPage,button)
end

local settingsPage = page('Settings')
section(settingsPage, 'BLACK EDITION / COULEUR')
local PALETTE = { 'FF475C', 'C5F277', '5EC8FF', 'B07CFF', 'FF6FA8', 'FF9F43', 'FFD84D', '4DE0A0', 'F1F4EF' }
local function applyAccent(hex)
    theme.accent = hexColor(hex)
    for _, it in ipairs(accentItems) do it.TextColor3 = theme.accent end
    S.design.applyAccent()
    updateTabs()
end
S.applyAccent = function(hex)
    if type(hex)~='string' or not hex:match('^%x%x%x%x%x%x$') then return false end
    applyAccent(hex);return true
end
do
local picker = S.design.colorPicker(settingsPage,applyAccent,function(hex) ui.accent=hex;applyAccent(hex);saveSettings() end)
grid(settingsPage,{{'Appliquer la couleur',picker.commit},{'Annuler la couleur',picker.cancel}})
local customAccent = textbox(settingsPage, 'Accent #RRGGBB')
button(settingsPage, 'Appliquer mon accent', function()
    local h = customAccent.Text:gsub('^#', ''):upper()
    if not h:match('^%x%x%x%x%x%x$') then logLine('Accent invalide : #RRGGBB requis'); return end
    ui.accent = h; applyAccent(h); if S.design.picker then S.design.picker.sync(h) end; saveSettings()
end)
toggle(settingsPage, function() return 'Animations : ' .. (ui.animations and 'oui' or 'non') end,
    function() ui.animations = not ui.animations; if not ui.animations then S.design.finishAnimations() end; saveSettings() end)
end
local swatches = make('Frame', { BackgroundTransparency = 1, LayoutOrder = S.design.order(S.design.parent(settingsPage)), Size = UDim2.new(1, 0, 0, 34) }, S.design.parent(settingsPage))
for i, hex in ipairs(PALETTE) do
    local h = hex
    local sw = make('TextButton', { Name = 'Couleur' .. h, Text = '', BackgroundColor3 = hexColor(h), BorderSizePixel = 0,
        Size = UDim2.new(1 / #PALETTE, -6, 1, 0), Position = UDim2.new((i - 1) / #PALETTE, 3, 0, 0) }, swatches)
    round(sw, 8)
    connect(sw.Activated, function() ui.accent = h; applyAccent(h); if S.design.picker then S.design.picker.sync(h) end; saveSettings() end)
end
section(settingsPage,'Affichage & confort')
S.design.scaleSlider=S.design.slider(settingsPage,'MenuScaleSlider','Échelle du menu',0.75,1.5,ui.scale,function(value)
    ui.scale=value;menuScale.Scale=value;fitWindow();saveSettings()
end)
toggle(settingsPage,function() return 'Densité : '..ui.density end,function()
    ui.density=ui.density=='normal' and 'compact' or 'normal';S.design.layout();saveSettings()
end)
toggle(settingsPage,function() return 'Mesures dans l’en-tête : '..(ui.metrics and 'oui' or 'non') end,function()
    ui.metrics=not ui.metrics;metrics.Visible=ui.metrics;S.design.layout();saveSettings()
end)
toggle(settingsPage,function() return 'Masquer pendant la pêche : '..(ui.hideInMinigame and 'oui' or 'non') end,function()
    ui.hideInMinigame=not ui.hideInMinigame;saveSettings()
end)
local overlay = label(gui, 'FPS --', 26)
overlay.Name = 'PerformanceOverlay'
overlay.Size = UDim2.fromOffset(200, 26)
overlay.BackgroundTransparency, overlay.BackgroundColor3, overlay.TextColor3 = 0.15, theme.background, theme.text
overlay.TextSize, overlay.Font, overlay.Active, overlay.ZIndex = 12, Enum.Font.GothamMedium, true, 10
overlay.TextXAlignment = Enum.TextXAlignment.Center
round(overlay, 8); outline(overlay)
overlay.Visible = ui.overlay
-- sous les boutons Roblox du coin haut-gauche (sinon il etait cache)
local op = ui.overlayPosition or { x = 12, y = 70 }
overlay.Position = UDim2.fromOffset(op.x, op.y)
toggle(settingsPage, function() return 'Compteur FPS a l\'ecran : ' .. (ui.overlay and 'oui' or 'non') end,
    function() ui.overlay = not ui.overlay; overlay.Visible = ui.overlay; saveSettings() end)
toggle(settingsPage, function() return 'Annonces en haut de l\'ecran : ' .. (ui.toasts and 'oui' or 'non') end,
    function() ui.toasts = not ui.toasts; saveSettings(); if ui.toasts then S.toast('Annonces activees', 'info') end end)
toggle(settingsPage, function() return 'Detecter aussi les textes violets : ' .. (ui.rarePurple and 'oui' or 'non') end,
    function() ui.rarePurple = not ui.rarePurple; saveSettings() end)
toggle(settingsPage,function() return 'Notifier les signaux rares : '..(ui.rareNotifications and 'oui' or 'non') end,
    function() ui.rareNotifications=not ui.rareNotifications;saveSettings() end)
local capturing = false
local function keyText() return 'Touche pour masquer le menu : ' .. ui.hotkey end
local hotkeyButton = button(settingsPage, keyText(), function(b) capturing = true; b.Text = 'Appuie sur une touche... (Echap : annuler)' end)

section(settingsPage, 'PROFILS (tes reglages enregistres)')
local profileBox = textbox(settingsPage, 'Nom du profil')
local profileList = S.design.rowList(settingsPage,'profiles',10,'Aucun profil enregistré')
profileList.onSelect=function(row) profileBox.Text=row.title end
local function refreshProfiles()
    local names = {}
    for n in pairs(profiles) do names[#names + 1] = n end
    table.sort(names)
    local rows={};for _,name in ipairs(names) do rows[#rows+1]={title=name,sub='Profil enregistré',badge='CHOISIR'} end
    profileList:set(rows)
end
local function profileName()
    local n = profileBox.Text:match('^%s*(.-)%s*$')
    if n == '' or #n > 32 or n:find('%c') then logLine('Nom de profil : 1 a 32 caracteres'); return nil end
    return n
end
local function applyPrefs()
    S.castDelay=ui.recastDelay;S.setFishingAimAssist(ui.aimAssist)
    menuScale.Scale = ui.scale
    applyAccent(ui.accent)
    overlay.Visible = ui.overlay
    metrics.Visible = ui.metrics
    S.setSpeedPreset(ui.speedPreset)
    S.configureMoneySource(ui.moneySourcePath)
    if S.design.picker then S.design.picker.sync(ui.accent) end
    if S.design.scaleSlider then S.design.scaleSlider.sync(ui.scale) end
    if ui.size then window.Size = UDim2.fromOffset(ui.size.x, ui.size.y) end
    if ui.position then window.Position = UDim2.fromOffset(ui.position.x, ui.position.y) end
    if ui.overlayPosition then overlay.Position = UDim2.fromOffset(ui.overlayPosition.x, ui.overlayPosition.y) end
    sub.Text = 'v' .. VERSION .. '  /  ' .. ui.hotkey .. ' : masquer'
    hotkeyButton.Text = keyText()
    fitWindow(); S.refreshToggles()
end
grid(settingsPage, {
    { 'Enregistrer le profil', function()
        local n = profileName(); if not n then return end
        local count = 0
        for _ in pairs(profiles) do count = count + 1 end
        if not profiles[n] and count >= 10 then logLine('Maximum 10 profils'); return end
        local p = {}
        for _, k in ipairs(PREF_KEYS) do p[k] = Hub.copy(ui[k]) end
        profiles[n] = p
        refreshProfiles(); saveSettings(); logLine('Profil enregistre : ' .. n)
    end },
    { 'Charger le profil', function()
        local n = profileName(); if not n then return end
        if type(profiles[n]) ~= 'table' then logLine('Profil introuvable : ' .. n); return end
        readPrefs(profiles[n], ui)
        applyPrefs(); saveSettings(); logLine('Profil charge : ' .. n)
    end },
    { 'Supprimer le profil', function()
        local n = profileName(); if not n then return end
        if profiles[n] == nil then logLine('Profil introuvable : ' .. n); return end
        profiles[n] = nil
        refreshProfiles(); saveSettings(); logLine('Profil supprime : ' .. n)
    end },
})
refreshProfiles()

-- AVANCE : outils de configuration et de test, replies par defaut
local advanced = {}
local advOpen = false
toggle(settingsPage, function() return (advOpen and 'v ' or '> ') .. 'Avance (voiture, trajets, reperes, diagnostic)' end,
    function()
        advOpen = not advOpen
        for _, o in ipairs(advanced) do o.Visible = advOpen end
    end)
local function adv(o) o.Visible = false; table.insert(advanced, o); return o end
local carInfo = adv(notice(settingsPage, '', 46))
adv(grid(settingsPage, {
    { 'Memoriser la voiture', function() local ok, e = rememberCar(); if not ok then logLine(e) end end },
    { 'Lancer une vente maintenant', function() S.cycleFailures = 0; runCycle(true) end },
    { 'Test trajet ALLER', function() testDrive('aller') end },
    { 'Test trajet RETOUR', function() testDrive('retour') end },
}))
adv(section(settingsPage, 'REPERES (ou tu te trouves)'))
local function pack(cf) return { cf:GetComponents() } end
local function mark(key, what)
    local root = getRoot()
    if not root then logLine('Personnage indisponible'); return end
    S.data[key] = pack(root.CFrame)
    logLine(what .. ' = ici. Pense a "Sauvegarder les trajets".')
end
S.markFishing = function() mark('fish', 'Point de peche') end
S.markVendor = function() mark('vendor', 'Vendeur') end
S.markAtm = function() mark('atm', 'ATM') end
adv(grid(settingsPage, {
    { 'Peche = ici', S.markFishing },
    { 'Vendeur = ici', S.markVendor },
    { 'ATM = ici', S.markAtm },
    { 'Visee souris (3 s)', function()
        local aimToken = S.token
        logLine('Place la souris sur l\'eau : capture dans 3 s')
        task.delay(3, function()
            if not alive(aimToken) then return end
            local ok,msg=S.captureAimNow();logLine(msg)
            if S.toast then S.toast(msg,ok and 'ok' or 'warn') end
        end)
    end },
}))
adv(section(settingsPage, 'TRAJETS'))
adv(toggle(settingsPage, function() return S.recording and ('Enregistrement : ' .. #S.recordBuffer .. ' points (cliquer pour arreter)') or 'Enregistrer un nouveau trajet' end,
    function()
        if not S.recording then
            S.recordBuffer = {}; S.recording = true
            logLine('Enregistrement : conduis le trajet (les trajets actuels ne sont pas touches)')
        else
            S.recording = false
            logLine('Enregistrement : ' .. #S.recordBuffer .. ' points. Choisis aller ou retour.')
        end
    end))
adv(grid(settingsPage, {
    { 'Trajet enregistre = ALLER', function() local ok, e = S.useRecording('aller'); if not ok then logLine(e) end end },
    { 'Trajet enregistre = RETOUR', function() local ok, e = S.useRecording('retour'); if not ok then logLine(e) end end },
    { 'Sauvegarder les trajets', function() local ok, msg = saveData(); logLine('Sauvegarde : ' .. tostring(msg) .. (ok and '' or ' (ECHEC)')) end },
    { 'Importer route v0.6.8', function() local ok, msg = S.importV068(); logLine(tostring(msg)) end },
}))
adv(section(settingsPage, 'DIAGNOSTIC'))
adv(grid(settingsPage, {
    { 'Diagnostic ecran', function() S.dumpGui() end },
    { 'Fermer le script', function() S.stop() end },
}))
-- Tableau AFK et journal bornes, rafraichis par la boucle existante.
do
local function names(list)
    local out = {}; for n in pairs(list) do out[#out + 1] = n end; table.sort(out)
    return #out == 0 and 'aucun' or table.concat(out, ', ')
end
function S.refreshDashboard()
    S.design.refresh()
end
local emergency = button(gui, 'STOP / F12', S.cancel, 38)
emergency.Name = 'EmergencyStop'; emergency.Size = UDim2.fromOffset(112, 38)
emergency.Position = UDim2.new(1, -124, 1, -50); emergency.ZIndex = 30
emergency.BackgroundColor3 = theme.danger
-- Un bouton visible meme si le menu est masque pendant la peche.
S.refreshDashboard()
end

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


S.window = window
fitWindow()
updateTabs()
S.design.refresh()
window.GroupTransparency = ui.animations and 1 or 0
menuScale.Scale = ui.animations and ui.scale * 0.98 or ui.scale
S.setMenuVisible(true)

-- Recalcul lors d'un changement de camera ou de resolution Roblox.
do
local cameraConnection
local function attachViewport()
    if cameraConnection then cameraConnection:Disconnect() end
    local camera=workspace.CurrentCamera
    if camera and camera.GetPropertyChangedSignal then
        cameraConnection=connect(camera:GetPropertyChangedSignal('ViewportSize'),function() fitWindow();S.design.refresh() end)
    end
    fitWindow()
end
connect(workspace:GetPropertyChangedSignal('CurrentCamera'),attachViewport)
attachViewport()
end

-- deplacement (en-tete), redimensionnement (<>), overlay deplacable
local gesture
local function beginGesture(mode, input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
    gesture = { mode = mode, input = input, start = input.Position,
        position = (mode == 'overlay' and overlay or window).Position, size = Vector2.new(window.Size.X.Offset, window.Size.Y.Offset) }
end
connect(top.InputBegan, function(input) beginGesture('move', input) end)
connect(resize.InputBegan, function(input) beginGesture('resize', input) end)
connect(overlay.InputBegan, function(input) beginGesture('overlay', input) end)
connect(UIS.InputChanged, function(input)
    if not gesture then return end
    if gesture.input.UserInputType == Enum.UserInputType.Touch then
        if input ~= gesture.input then return end
    elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
    local dx, dy = input.Position.X - gesture.start.X, input.Position.Y - gesture.start.Y
    if gesture.mode == 'resize' then
        window.Size = UDim2.fromOffset(gesture.size.X + dx / ui.scale, gesture.size.Y + dy / ui.scale); fitWindow()
    elseif gesture.mode == 'overlay' then
        overlay.Position = UDim2.fromOffset(gesture.position.X.Offset + dx, gesture.position.Y.Offset + dy)
    else
        window.Position = UDim2.fromOffset(gesture.position.X.Offset + dx, gesture.position.Y.Offset + dy); fitWindow()
    end
end)
connect(UIS.InputEnded, function(input)
    if gesture and (input == gesture.input or input.UserInputType == Enum.UserInputType.MouseButton1) then
        gesture = nil
        ui.position = { x = window.Position.X.Offset, y = window.Position.Y.Offset }
        ui.size = { x = window.Size.X.Offset, y = window.Size.Y.Offset }
        ui.overlayPosition = { x = overlay.Position.X.Offset, y = overlay.Position.Y.Offset }
        saveSettings()
    end
end)

---------------------------------------------------------------------------
-- POISSON RARE : texte nouveau apparu pendant/apres le mini-jeu contenant un mot
-- de rarete, ou (option) ecrit en violet. Heuristique NON verifiee en jeu.
---------------------------------------------------------------------------
do -- poisson rare (portee fermee : limite de 200 locales)
local RARE_WORDS = { 'legendary', 'legendaire', 'mythic', 'mythique', 'omega', 'epic', 'epique' }
local catchBaseline, catchWindowUntil, rareCooldownUntil, rareNoticeUntil = nil, 0, 0, 0
local function isPurple(c)
    local ok, r, g, b = pcall(function() return c.R, c.G, c.B end)
    if not ok or not isNum(r) or not isNum(g) or not isNum(b) then return false end
    local mx, mn = math.max(r, g, b), math.min(r, g, b)
    if mx < 0.35 or mx - mn < 0.25 then return false end
    local d = mx - mn
    local h
    if mx == r then h = ((g - b) / d) % 6 elseif mx == g then h = (b - r) / d + 2 else h = (r - g) / d + 4 end
    h = h * 60
    return h >= 255 and h <= 310
end
local function visibleTexts()
    local out = {}
    for _, o in ipairs(pg:GetDescendants()) do
        if (o:IsA('TextLabel') or o:IsA('TextButton')) and not ours(o) and shown(o) then
            local t = tostring(o.Text)
            if t ~= '' then out[o] = t end
        end
    end
    return out
end
function S.onMinigameStart()
    catchBaseline = visibleTexts()
    catchWindowUntil = math.huge
end
function S.onMinigameEnd(now) catchWindowUntil = now + 8 end
local function rareTrigger(text)
    rareNoticeUntil=os.clock()+60
    if ui.rareAction~='none' then rareCooldownUntil = os.clock() + 60 end
    logLine('POISSON RARE detecte : "' .. text:sub(1, 50) .. '" -> ' .. RARE_ACTIONS[ui.rareAction])
    S.toast('Signal de rareté (à vérifier) : ' .. text:sub(1, 40), 'rare')
    if ui.rareAction == 'leave' then
        local rareToken = S.token
        task.delay(1, function()
            if alive(rareToken) and not S.paused then pcall(function() player:Kick('BlockSpin hub : poisson rare detecte (' .. text:sub(1, 40) .. ')') end) end
        end)
    elseif ui.rareAction == 'sell' then
        if not carValid() then logLine('Aller vendre impossible : aucune voiture memorisee'); return end
        S.cycleFailures = 0
        runCycle(true)
    end
end
function S.scanCatch(now)
    if not catchBaseline or now > catchWindowUntil then return end
    local changed = false
    for o, t in pairs(visibleTexts()) do
        if catchBaseline[o] ~= t then
            catchBaseline[o] = t
            local f = fold(t)
            -- index : textes courts avec des lettres (probablement le nom du poisson)
            if #t >= 3 and #t <= 40 and f:find('%a%a') and not f:find('^[%s%d%p]*$') then
                S.fishLog[t] = (S.fishLog[t] or 0) + 1; changed = true; S.spotEvent('texts')
            end
            local rare = false
            for _, w in ipairs(RARE_WORDS) do if f:find(w, 1, true) then rare = true end end
            if not rare and ui.rarePurple and isPurple(o.TextColor3) then rare = true end
            if rare then S.spotEvent('rareSignals') end
            if rare and S.running and ((ui.rareAction~='none' and os.clock()>rareCooldownUntil)
                or (ui.rareAction=='none' and ui.rareNotifications and os.clock()>rareNoticeUntil)) then rareTrigger(t) end
        end
    end
    if changed then
        refreshFishLog()
        if type(writefile) == 'function' then pcall(function() writefile(FISHLOG_FILE, HttpService:JSONEncode(S.fishLog)) end) end
    end
end
end

-- FPS (1 mesure par seconde) + infos voiture
local frames, elapsed = 0, 0
connect(RunService.RenderStepped, function(dt)
    frames = frames + 1; elapsed = elapsed + dt
    if elapsed < 1 then return end
    do
        local ok, ping = pcall(function() return player:GetNetworkPing() end)
        local pingText = (ok and isNum(ping) and ping >= 0) and string.format('%.0f ms', ping * 1000) or 'N/D'
        local txt = string.format('FPS %.0f | Ping %s', frames / elapsed, pingText)
        metrics.Text = txt; overlay.Text = txt
        S.design.recordMetrics(frames / elapsed,ok and isNum(ping) and ping>=0 and ping or nil)
    end
    if carInfo.Parent then
        local seat = currentSeat()
        carInfo.Text = 'Voiture : ' .. (S.car and S.car.name or 'non memorisee (monte au volant)')
            .. (seat and string.format(' | vitesse %.0f studs/s', seat.AssemblyLinearVelocity.Magnitude) or '')
            .. '\n' .. tostring(S.driveStatus)
    end
    S.refreshToggles()
    frames, elapsed = 0, 0
end)

---------------------------------------------------------------------------
-- 18. MINI-JEU DE PECHE (identique v0.6.8 sauf etats)
---------------------------------------------------------------------------
local function findMinigame()
    local root = pg:FindFirstChild('SliderMinigame')
    if not root then return end
    for _, panel in ipairs(root:GetChildren()) do
        if panel:IsA('GuiObject') and shown(panel) then
            local hint = panel:FindFirstChild('Hint')
            local t = hint and hint:IsA('TextLabel') and hint.Text:lower() or ''
            if t:find('needle', 1, true) and t:find('green', 1, true) then
                for _, bar in ipairs(panel:GetChildren()) do
                    if bar:IsA('Frame') then
                        local needle, target
                        for _, child in ipairs(bar:GetChildren()) do
                            if child:IsA('Frame') and shown(child) then
                                local w, h = child.AbsoluteSize.X, child.AbsoluteSize.Y
                                if h > 12 and w >= 2 and w <= 20 then needle = child end
                                if h > 12 and w >= 30 and w < bar.AbsoluteSize.X * 0.9 then target = child end
                            end
                        end
                        if needle and target then return panel, target, needle end
                    end
                end
            end
        end
    end
end
-- Entrees de peche ciblees sur Roblox ; aucun clic OS lorsque la fenetre perd le focus.
S.inputFocused=true;S.focusKnown=false;S.inputEpoch=0;S.castPending=false;S.aimRetryAt=0
function S.isFishingInputActive()
    if type(isrbxactive)=='function' then
        local ok,active=pcall(isrbxactive)
        if ok and type(active)=='boolean' then S.inputFocused=active;S.focusKnown=true end
    end
    return S.inputFocused~=false
end
connect(UIS.WindowFocusReleased,function()
    S.inputFocused=false;S.focusKnown=true;S.inputEpoch=S.inputEpoch+1;releaseMouse()
    S.fishingInputStatus='Peche en pause : Roblox hors focus'
end)
connect(UIS.WindowFocused,function()
    S.inputFocused=true;S.focusKnown=true;S.inputEpoch=S.inputEpoch+1
    S.fishingInputStatus='Roblox au premier plan'
end)
local function pointerInside(point)
    local camera=workspace.CurrentCamera;local v=camera and camera.ViewportSize
    return point and v and isNum(point.X) and isNum(point.Y) and point.X>=0 and point.Y>=0 and point.X<v.X and point.Y<v.Y
end
local function moveFishingPointer(point,tok,epoch)
    if not alive(tok) or S.inputEpoch~=epoch or not S.isFishingInputActive() or not pointerInside(point) then return false,'Visee hors ecran ou Roblox sans focus' end
    local ok,err=pcall(function() VIM:SendMouseMoveEvent(point.X,point.Y,game) end)
    if not ok then return false,'Deplacement de visee refuse : '..tostring(err) end
    if not sleep(0.04,tok) then return false,'annule' end -- laisser le moteur actualiser Mouse.Hit
    if S.inputEpoch~=epoch or not S.isFishingInputActive() then return false,'Roblox a perdu le focus' end
    local current=UIS:GetMouseLocation()
    if not pointerInside(current) or math.abs(current.X-point.X)>4 or math.abs(current.Y-point.Y)>4 then return false,'Visee non confirmee par le moteur' end
    return true
end
local function minigamePoint(target,panel)
    if not target or not target.Parent or not shown(target) then return nil end
    local pos=target.AbsolutePosition+target.AbsoluteSize/2
    if not pointerInside(pos) then return nil end
    -- Coordonnees observees du GUI ; les variantes d'inset sont choisies par hit-test.
    if pg.GetGuiObjectsAtPosition then
        local options={pos}
        local ok,inset=pcall(function() return game:GetService('GuiService'):GetGuiInset() end)
        if ok and inset then options[#options+1]=Vector2.new(pos.X+inset.X,pos.Y+inset.Y) end
        for _,candidate in ipairs(options) do
            local good,objects=pcall(function() return pg:GetGuiObjectsAtPosition(candidate.X,candidate.Y) end)
            if good then
                for _,object in ipairs(objects) do
                    if ours(object) and (object:IsA('GuiButton') or object.Active) then break end
                    if object==target or object:IsDescendantOf(target) then return candidate end
                end
            end
        end
        return nil
    end
    return pos
end
local function sendClick(tok,target,panel,epoch)
    if not alive(tok) or S.paused or S.inputEpoch~=epoch or not S.isFishingInputActive() then return false,'annule ou hors focus' end
    local point=minigamePoint(target,panel)
    if not point then return false,'Barre du mini-jeu non accessible a l’ecran' end
    local original=UIS:GetMouseLocation()
    local pressed=false
    local ok=pcall(function()
        VIM:SendMouseMoveEvent(point.X,point.Y,game)
        mouseHeld=true;mouseHeldVia='native'
        VIM:SendMouseButtonEvent(point.X,point.Y,0,true,game,0);pressed=true
        VIM:SendMouseButtonEvent(point.X,point.Y,0,false,game,0)
        mouseHeld=false;mouseHeldVia=nil
    end)
    if ok then
        -- Le clic vise la barre ; il ne doit pas laisser la prochaine canne viser cette barre.
        -- Aucun deplacement vers une autre fenetre, aucune nouvelle tentative de clic si ce retour echoue.
        if alive(tok) and S.inputEpoch==epoch and S.isFishingInputActive() and pointerInside(original) then
            pcall(function() VIM:SendMouseMoveEvent(original.X,original.Y,game) end)
        end
        return true,'VirtualInputManager (barre)'
    end
    releaseMouse()
    if pressed then return false,'Relachement natif refuse : clic non repete' end
    -- Compatibilite historique seulement si le vrai curseur etait deja dans la barre
    -- et si le focus a ete observe, jamais de mouse1click a une position inconnue.
    if not alive(tok) or S.inputEpoch~=epoch or not S.focusKnown or not S.isFishingInputActive() then return false,'Clic natif refuse' end
    local a,b=target.AbsolutePosition,target.AbsoluteSize
    local inside=pointerInside(original) and original.X>=a.X and original.X<=a.X+b.X and original.Y>=a.Y and original.Y<=a.Y+b.Y
    if inside and type(mouse1click)=='function' and pcall(mouse1click) then return true,'mouse1click (barre sous curseur)' end
    return false,'Clic natif refuse ; reviens sur la barre dans Roblox'
end
local lastMinigameEnd,minigameWasVisible=nil,false
local firstCastAt=os.clock()+3
local function aimAtSavedPoint(tok,epoch)
    if not ui.aimAssist then return true end -- comportement classique, sans dependance a Mouse.Hit ni spot obligatoire
    local aim=S.fishingAim
    if not aim and S.baitScreenPoint then aim={x=S.baitScreenPoint.X,y=S.baitScreenPoint.Y} end
    if not aim then
        if S.hub.activeSpot then return false,'Capture d’abord la visee de ce spot sur l’eau' end
        return pointerInside(UIS:GetMouseLocation()),'Curseur a placer dans Roblox'
    end
    local point=Vector2.new(aim.x,aim.y);local camera=workspace.CurrentCamera
    if aim.world then
        local ok,screen,onScreen=pcall(function() return camera:WorldToViewportPoint(v3(aim.world)) end)
        if not ok or not onScreen or not screen or screen.Z<=0 then return false,'Le point du spot est hors champ : oriente la camera vers l’eau' end
        point=Vector2.new(screen.X,screen.Y)
    elseif aim.viewport and (aim.viewport.x~=camera.ViewportSize.X or aim.viewport.y~=camera.ViewportSize.Y) then
        return false,'La resolution a change : recapturer la visee ecran'
    end
    local moved,why=moveFishingPointer(point,tok,epoch)
    if not moved then return false,why end
    if aim.world then
        local deadline=os.clock()+0.25
        repeat
            if not alive(tok) or S.inputEpoch~=epoch or not S.isFishingInputActive() then return false,'annule ou hors focus' end
            local ok,hit=pcall(function() return player:GetMouse().Hit.Position end)
            if ok and hit and (hit-v3(aim.world)).Magnitude<=6 then return true end
            if not sleep(0.05,tok) then return false,'annule' end
        until os.clock()>=deadline
        return false,'Visee monde non confirmee : eau masquee ou mise a jour refusee'
    end
    return true
end
local function tryCast(now)
    if S.castPending or not S.autoCast or not S.fishingEnabled or S.paused or S.inventoryFull or S.cycleRunning or S.baitEmpty then return end
    if not S.isFishingInputActive() then S.fishingInputStatus='Peche en pause : Roblox hors focus';return end
    if now<firstCastAt or now<S.aimRetryAt or now-lastCast<S.retryDelay then return end
    if lastMinigameEnd and now-lastMinigameEnd<S.castDelay then return end
    local tool=fishingTool()
    if not tool then update('Equipe la canne pour le lancer auto');return end
    local tok,epoch=S.token,S.inputEpoch;S.castPending=true
    local ticket={};S.castTicket=ticket
    task.spawn(function()
        local worked,err=pcall(function()
            local aimed,why=aimAtSavedPoint(tok,epoch)
            if not aimed then if alive(tok) and S.inputEpoch==epoch then S.aimRetryAt=os.clock()+2;S.fishingInputStatus=why;update(why) end;return end
            if S.castTicket~=ticket or not alive(tok) or S.inputEpoch~=epoch or not S.isFishingInputActive() or S.paused or S.inventoryFull or S.cycleRunning or not S.fishingEnabled then return end
            lastCast=os.clock();S.castAttempts=S.castAttempts+1;S.spotEvent('casts')
            local activated,why2=pcall(function() tool:Activate() end)
            S.fishingInputStatus=activated and (ui.aimAssist and 'Canne activee · visee enregistree' or 'Canne activee · classique') or tostring(why2)
            update(activated and ('lancer '..S.castAttempts..' ('..tool.Name..')') or ('Erreur lancer : '..tostring(why2)))
        end)
        if S.castTicket==ticket then S.castPending=false end
        if not worked and alive(tok) then S.hub:error('Lancer',err,os.clock());S.fishingInputStatus=tostring(err) end
    end)
end
local currentPanel, lastX, lastT, lastClick, lastTarget, lastTries = nil, nil, nil, -100, nil, nil
local armed, exitedAfterClick, clickX, pending, roundsInPanel = true, false, nil, false, 0
local function resetPanel(panel)
    currentPanel = panel; lastX = nil; lastT = nil; lastTarget = nil; lastTries = nil
    armed = true; exitedAfterClick = false; clickX = nil; pending = false; roundsInPanel = 0
end

local nextCheck, fullSince = 0, nil
local function refreshInfo() end -- donnees presentes dans les widgets de presentation

table.insert(conns, RunService.Heartbeat:Connect(function()
    if not S.running then return end
    local ok, err = pcall(function()
        local now = os.clock()
        if S.hub:expired(now, S.token) then
            local name = S.hub.current.name
            cancelAll('delai maximal depasse : ' .. name)
            S.autoCycle = false; S.paused = true
            setState('ERROR', name .. ' : delai maximal depasse')
            return
        end
        if now >= nextCheck then
            nextCheck = now + 0.8
            if S.observatory then S.observatory.tick() end
            S.checkInventory(); checkBait(); S.pollMoney(false); refreshInfo()
            if not S.paused then S.scanCatch(now) end
            if S.refreshDashboard then S.refreshDashboard() end
            local spot = S.hub.activeSpot and S.hub.library.spots[S.hub.activeSpot]
            local root = getRoot()
            if spot and root and S.fishingEnabled and not S.paused and not S.cycleRunning
                and (root.Position - v3(spot.cf)).Magnitude <= 8 then
                S.hub:spotTime(math.min(2, now - (S.spotTick or now)))
            end
            S.spotTick = now
            if S.recording then
                local seat = currentSeat()
                if seat then
                    local p = seat.Position
                    local last = S.recordBuffer[#S.recordBuffer]
                    if #S.recordBuffer >= 2000 then S.recording = false; logLine('Maximum 2000 points atteint') end
                    if S.recording and (not last or (Vector3.new(last[1], last[2], last[3]) - p).Magnitude > 14) then
                        S.recordBuffer[#S.recordBuffer + 1] = { p.X, p.Y, p.Z }
                    end
                    update('ENREGISTREMENT : ' .. #S.recordBuffer .. ' points (bouton Conduite pour finir)')
                end
            end
            -- "meme voiture" = la derniere dans laquelle tu t'es assis au volant hors cycle
            local seatNow = currentSeat()
            if seatNow and not S.cycleRunning and (not S.car or S.car.seat ~= seatNow) then rememberCar(seatNow) end
            -- etats de repos
            if not S.cycleRunning and S.state ~= 'ERROR' then
                if S.baitEmpty then setState('NO_BAIT', 'x0 lu : lancers arretes')
                elseif S.inventoryFull then setState('INVENTORY_FULL', S.inventoryText)
                elseif S.paused then setState('PAUSED', '')
                elseif S.fishingEnabled then if S.state ~= 'FISHING' then setState('FISHING', '') end
                elseif S.state ~= 'IDLE' then setState('IDLE', '') end
            end
            -- declenchement du cycle : inventaire plein confirme 2 s, pas de mini-jeu
            if S.inventoryFull then fullSince = fullSince or now else fullSince = nil end
            if S.autoCycle and S.autoSell and not S.cycleRunning and S.cycleFailures == 0 and S.sellAttempts < 1
                and fullSince and now - fullSince > 2 and not minigameWasVisible and not S.paused then
                S.sellAttempts = 1
                runCycle(false)
            end
        end
        if not S.fishingEnabled or S.paused or S.cycleRunning then return end
        if not S.isFishingInputActive() then S.fishingInputStatus='Peche en pause : Roblox hors focus';return end
        if UIS:GetFocusedTextBox() or S.design.pointer then S.fishingInputStatus='Saisie ou reglage en cours : peche en pause';return end
        if S.lastFishingEpoch~=S.inputEpoch then resetPanel(nil);S.lastFishingEpoch=S.inputEpoch end
        local panel, target, needle = findMinigame()
        -- le menu ne doit pas recevoir les clics du mini-jeu (clic a la position du curseur)
        if panel then S.minigameSeenAt = os.clock() end
        if panel and ui.hideInMinigame and S.design.menuVisible then S.setMenuVisible(false, true); S.hiddenForMinigame = true end
        if not panel and S.hiddenForMinigame and os.clock() - (S.minigameSeenAt or 0) > 1.5 then S.setMenuVisible(true); S.hiddenForMinigame = false end
        if not panel then
            if minigameWasVisible then
                minigameWasVisible=false;lastMinigameEnd=os.clock()
                -- Une manche observee est terminee : le delai de retry sans reponse ne s'applique plus.
                lastCast=-1e6;firstCastAt=math.min(firstCastAt,lastMinigameEnd)
                S.onMinigameEnd(lastMinigameEnd)
            end
            if currentPanel then resetPanel(nil) end
            tryCast(os.clock())
            return
        end
        if not minigameWasVisible then S.onMinigameStart() end
        minigameWasVisible = true
        if panel ~= currentPanel then resetPanel(panel) end
        local x = needle.AbsolutePosition.X + needle.AbsoluteSize.X * 0.5
        local left = target.AbsolutePosition.X
        local right = left + target.AbsoluteSize.X
        local width = right - left
        if width <= 0 then return end
        local triesObj = panel:FindFirstChild('Tries')
        local tries = (triesObj and triesObj:IsA('TextLabel')) and triesObj.Text or ''
        local signature = math.floor(left + 0.5) .. ':' .. math.floor(right + 0.5)
        local margin = math.min(10, math.max(3, width * 0.04))
        local inside = (x >= left + margin and x <= right - margin)
        local outside = (x < left - margin or x > right + margin)
        if not armed and now - lastClick >= 0.15 then
            if lastTarget and signature ~= lastTarget then armed = true; exitedAfterClick = false
            elseif lastTries and tries ~= lastTries then armed = true; exitedAfterClick = false
            elseif outside then exitedAfterClick = true
            elseif exitedAfterClick and not pending and inside then armed = true end
        end
        lastTarget = signature; lastTries = tries
        local predicted = x
        if lastX and lastT and now > lastT then
            local speed = (x - lastX) / (now - lastT)
            if math.abs(speed) < 7000 then predicted = x + speed * 0.008 end
        end
        lastX, lastT = x, now
        if not armed or pending then return end
        if now - lastClick >= 0.45 and predicted >= left + margin and predicted <= right - margin then
            armed = false; pending = true; exitedAfterClick = false; lastClick = now; clickX = x
            roundsInPanel = roundsInPanel + 1; S.rounds = S.rounds + 1
            local clickToken = S.token
            local clickEpoch = S.inputEpoch
            task.spawn(function()
                if not alive(clickToken) or S.paused then pending = false; return end
                local success, method = sendClick(clickToken,target,panel,clickEpoch)
                pending = false
                if not alive(clickToken) or S.paused or clickEpoch~=S.inputEpoch or not S.isFishingInputActive() then return end
                S.method = method
                if success then
                    S.clicks = S.clicks + 1
                    update('clic ' .. roundsInPanel .. ' (' .. method .. ') | total ' .. S.clicks)
                else
                    armed = true
                    update('ERREUR CLIC : ' .. method)
                end
            end)
        end
    end)
    if not ok then S.hub:error('Heartbeat', err, os.clock()); update('ERREUR : ' .. tostring(err):sub(1, 95)) end
end))

---------------------------------------------------------------------------
-- 19. CLAVIER : seulement F12 (urgence) et le raccourci d'affichage du menu.
-- Toutes les autres actions sont des boutons de l'interface.
---------------------------------------------------------------------------
connect(UIS.InputBegan, function(input, processed)
    if not S.running then return end
    S.inputFocused=true;S.focusKnown=true
    if input.KeyCode == Enum.KeyCode.F12 then S.cancel(); return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if capturing then
        if input.KeyCode == Enum.KeyCode.Escape then
            capturing = false
        elseif validKeyName(input.KeyCode.Name) then
            ui.hotkey = input.KeyCode.Name; capturing = false; saveSettings()
            sub.Text = 'v' .. VERSION .. '  /  ' .. ui.hotkey .. ' : masquer'
        end
        hotkeyButton.Text = capturing and 'Choisir une touche clavier' or keyText()
        return
    end
    if processed or UIS:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode[ui.hotkey] then
        S.setMenuVisible(not S.design.menuVisible)
        S.hiddenForMinigame = false
        gesture = nil
    end
end)
function S.useRecording(which)
    if S.cycleRunning or S.recording then return false, 'activite ou enregistrement en cours' end
    if #S.recordBuffer < 2 then return false, 'tampon vide' end
    local key = (which == 'retour') and 'route_to_fishing' or (which == 'aller' and 'route_to_vendor') or nil
    if not key then return false, 'preciser "aller" ou "retour"' end
    local copy = {}
    for i, p in ipairs(S.recordBuffer) do copy[i] = { p[1], p[2], p[3] } end
    S.data[key] = copy
    logLine(key .. ' remplace par ' .. #copy .. ' points enregistres (bouton Sauvegarder les donnees pour ecrire le fichier)')
    return true
end
function S.pause() S.paused = true end
function S.resume()
    if S.observatory and S.observatory.queueRunning then return false end
    local info = readCapacity()
    if info and info.count >= info.limit then S.inventoryFull = true; return false end
    S.paused = false; S.fishingEnabled = true; S.cycleFailures = 0
    if S.state == 'ERROR' then setState('IDLE', '') end
    return true
end
S.retrySell = S.retryCycle

---------------------------------------------------------------------------
-- 20. ARRET COMPLET
---------------------------------------------------------------------------
function S.stop()
    if not S.running then return end
    S.token = S.token + 1
    S.running = false
    if S.observatory then S.observatory.cleanup() end
    if S.detachMoneySource then S.detachMoneySource() end
    if S.design then S.design.cleanup() end
    S.recording = false
    S.hub.farm.running = false
    S.hub:finishStep(false, 'arret complet', os.clock())
    releaseAll(); releaseMouse()
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    conns = {}
    if gui then pcall(function() gui:Destroy() end) end
    S.state = 'STOPPED'
    print('[BlockSpin ' .. VERSION .. '] arrete. Aucune donnee ecrite a l\'arret. Touches liberees ; une voiture en mouvement peut encore rouler sur son elan.')
    if E.BlockSpinCycle080 == S then E.BlockSpinCycle080 = nil end
end

local okLoad, loadMsg = loadData()
logLine(loadMsg)
if currentSeat() then rememberCar() end
setState(S.fishingEnabled and 'FISHING' or 'IDLE', 'pret')
logLine('Charge. Stop : getgenv().BlockSpinCycle080.stop()')
refreshInfo()
