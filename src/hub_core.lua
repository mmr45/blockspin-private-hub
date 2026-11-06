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
function Core:observeCash(n)
    if not finite(n) or n < 0 then return false end
    local m = self.money
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
function Core:addSpot(name, cf, aim)
    if not nameOK(name) then return false, 'nom du spot invalide' end
    if type(cf) ~= 'table' or #cf ~= 12 then return false, 'position de 12 nombres requise' end
    for _, n in ipairs(cf) do if not finite(n) then return false, 'position invalide' end end
    if aim ~= nil and (type(aim) ~= 'table' or not finite(aim.x) or not finite(aim.y)) then return false, 'visee invalide' end
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
Core.copy = copy
return Core
