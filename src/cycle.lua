-- BlockSpin Hub v1.1.0
-- Peche auto (logique v0.6.8 conservee) + cycle vente/ATM par conduite NATIVE sur route
-- (touches simulees W/A/S/D, aucun deplacement de CFrame, aucune teleportation).
-- Aucun passage sous la carte : non implemente volontairement (voir README_v080.md).
-- Arret complet : getgenv().BlockSpinCycle080.stop()
-- Arret d'urgence du cycle/conduite (le script reste charge) : F12
local VERSION = '1.1.0'
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

--@@HUB_CORE@@

--@@DEFAULT_DATA@@

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
    autoCast = true, castDelay = 2.5, retryDelay = 8, castAttempts = 0,
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
local function releaseMouse()
    if not mouseHeld then return end
    mouseHeld = false
    if type(mouse1release) == 'function' then pcall(mouse1release) end
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
    if baitCache and baitCache.Parent then
        local c = tostring(baitCache.Text):match('[xX]%s*(%d+)%s*$')
        found = tonumber(c)
    end
    if found == nil then
        if os.clock() < baitNextScan then return end
        baitNextScan = os.clock() + 10
        baitCache = nil
        for _, o in ipairs(pg:GetDescendants()) do
            if (o:IsA('TextLabel') or o:IsA('TextButton')) and fold(o.Text):find('prawntec', 1, true) and not ours(o) then
                local inline = tostring(o.Text):match('[xX]%s*(%d+)%s*$')
                if inline then found = tonumber(inline); baitCache = o end
                local parent = o.Parent
                if found == nil and parent then
                    for _, near in ipairs(parent:GetDescendants()) do
                        if near:IsA('TextLabel') or near:IsA('TextButton') then
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
local function findMoney()
    for _, obj in ipairs(pg:GetDescendants()) do
        if (obj:IsA('TextLabel') or obj:IsA('TextButton')) and not ours(obj) and shown(obj) then
            local txt = fold(obj.Text)
            local val = txt:match('equilibre des mains%s*:%s*%$?([%d, %.]+)') or txt:match('cash%s*:%s*%$?([%d, %.]+)')
            if val then
                local amount = Hub.parseMoney(val)
                if amount then return amount, obj:GetFullName() end
            end
        end
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
    S.token = S.token + 1
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
    if S.cycleRunning or S.recording then return false, 'cycle ou enregistrement deja en cours' end
    S.token = S.token + 1
    local tok = S.token
    S.cycleRunning = true
    task.spawn(function()
        local function fail(stage, msg)
            if not alive(tok) then return end
            releaseAll(); releaseMouse()
            S.cycleRunning = false
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
    local root = getRoot()
    if not root then return false, 'personnage indisponible' end
    local aim = S.baitScreenPoint
    return S.hub:addSpot(name, { root.CFrame:GetComponents() }, aim and { x = aim.X, y = aim.Y })
end
function S.selectSpot(name)
    if not idle() then return false, 'activite en cours' end
    local spot = S.hub.library.spots[name]
    if not spot then return false, 'spot introuvable' end
    local root = getRoot()
    if not root or (root.Position - v3(spot.cf)).Magnitude > 8 then return false, 'rejoindre le spot a moins de 8 studs avant de le selectionner' end
    S.data.fish = Hub.copy(spot.cf)
    S.baitScreenPoint = spot.aim and Vector2.new(spot.aim.x, spot.aim.y) or nil
    S.hub.activeSpot = name
    return true, 'Spot selectionne : ' .. name
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
function S.refreshMoney()
    local value, path = findMoney()
    if not S.hub:observeCash(value) then return false, 'solde inconnu : aucune estimation inventee' end
    return true, 'Solde observe : ' .. value .. ' (' .. tostring(path) .. ')'
end
function S.setFarmingAdapter(adapter)
    if not idle() then return false, 'activite en cours' end
    return S.hub:setFarmAdapter(adapter)
end
function S.startFarm(plan, replant)
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
    speedPreset = 'Rapide', rareAction = 'none', rarePurple = true, toasts = true, animations = true, layoutVersion = 2, density = 'normal' }
local PREF_KEYS = { 'accent', 'hotkey', 'scale', 'metrics', 'overlay', 'hideInMinigame', 'speedPreset', 'rareAction', 'rarePurple', 'toasts', 'animations',
    'position', 'size', 'overlayPosition', 'layoutVersion', 'density' }
local RARE_ACTIONS = { none = 'ne rien faire', leave = 'quitter le serveur', sell = 'aller vendre' }
local settingsRaw -- fichier lu en entier : profils et champs du hub 0.4.0 conserves
local function validKeyName(n)
    if type(n) ~= 'string' or n == 'Escape' or n == 'Unknown' or n == 'F12' then return false end
    local ok, k = pcall(function() return Enum.KeyCode[n] end)
    return ok and k ~= nil
end
local function readPrefs(d, into)
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
local profiles = (type(settingsRaw) == 'table' and type(settingsRaw.profiles) == 'table') and settingsRaw.profiles or {}
local function saveSettings()
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

--@@INTERFACE@@

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
    { 'Enregistrer ce spot', function() result(S.saveSpot(spotName.Text)) end },
    { 'Selectionner le spot', function() result(S.selectSpot(spotName.Text)) end },
    { 'Supprimer ce spot', function() result(S.removeLibraryItem('spot', spotName.Text)) end },
    { 'Sauvegarder la bibliotheque', function() result(S.saveLibrary()) end },
})
button(home, 'Capturer la visee dans 3 secondes', function()
    local tok = S.token
    S.toast('Place la souris sur l\'eau : capture dans 3 s', 'info')
    task.delay(3, function()
        if not alive(tok) then return end
        local m = UIS:GetMouseLocation(); S.baitScreenPoint = Vector2.new(m.X, m.Y)
        result(true, 'Visee capturee ; enregistrer un nouveau spot pour la conserver')
    end)
end)
button(home, 'Reprendre la peche apres STOP', function()
    result(S.resume(), S.inventoryFull and 'Inventaire plein : liberer avant de reprendre' or 'Reprise demandee')
end)
S.design.rowList(home,'spots',5,'Aucun spot enregistré').onSelect=function(row) spotName.Text=row.title end
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
S.design.metricsGrid(money,{{id='cash',label='PORTEFEUILLE OBSERVÉ'},{id='earned',label='GAINS DE VENTES'},{id='deposited',label='TOTAL DÉPOSÉ'},{id='hourly',label='ESTIMATION / HEURE'}})
S.views.money = S.design.widgets.cash
S.design.caption(money,'Montants observés · estimation après 60 secondes')
section(money,'Ventes & dépôts')
S.design.metricsGrid(money,{{id='sales',label='VENTES MESURÉES'},{id='deposits',label='DÉPÔTS OBSERVÉS'},{id='baitUsed',label='APPÂTS EN MOINS'},{id='baitAdded',label='APPÂTS AJOUTÉS'}})
button(money, 'Actualiser le solde observe', function() result(S.refreshMoney()) end)
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
    menuScale.Scale = ui.scale
    applyAccent(ui.accent)
    overlay.Visible = ui.overlay
    metrics.Visible = ui.metrics
    S.setSpeedPreset(ui.speedPreset)
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
        for _, k in ipairs(PREF_KEYS) do p[k] = ui[k] end
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
            local m = UIS:GetMouseLocation()
            S.baitScreenPoint = Vector2.new(m.X, m.Y)
            logLine(string.format('Visee enregistree a %.0f, %.0f', m.X, m.Y))
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
local catchBaseline, catchWindowUntil, rareCooldownUntil = nil, 0, 0
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
    rareCooldownUntil = os.clock() + 60
    logLine('POISSON RARE detecte : "' .. text:sub(1, 50) .. '" -> ' .. RARE_ACTIONS[ui.rareAction])
    S.toast('Poisson rare : ' .. text:sub(1, 40), 'rare')
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
            if rare and ui.rareAction ~= 'none' and os.clock() > rareCooldownUntil and S.running then rareTrigger(t) end
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
local function sendClick(tok)
    if not alive(tok) or S.paused then return false, 'annule' end
    if type(mouse1click) == 'function' then
        if pcall(mouse1click) then return true, 'mouse1click' end
    end
    if type(mouse1press) == 'function' and type(mouse1release) == 'function' then
        if pcall(function() mouseHeld = true; mouse1press(); task.wait(0.025); if alive(tok) then releaseMouse() end end) then return alive(tok), 'mouse1press/release' end
    end
    if not alive(tok) then return false, 'annule' end
    local ok = pcall(function()
        local pos = UIS:GetMouseLocation()
        VIM:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 0)
        VIM:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 0)
    end)
    if ok then return true, 'VirtualInputManager' end
    return false, 'aucune methode de clic'
end
local lastMinigameEnd, minigameWasVisible = nil, false
local firstCastAt = os.clock() + 3
local function aimAtSavedPoint()
    local pt = S.baitScreenPoint
    if pt then pcall(function() VIM:SendMouseMoveEvent(pt.X, pt.Y, game) end) end
end
local function tryCast(now)
    if not S.autoCast or not S.fishingEnabled or S.paused or S.inventoryFull or S.cycleRunning or S.baitEmpty then return end
    if now < firstCastAt or now - lastCast < S.retryDelay then return end
    if lastMinigameEnd and now - lastMinigameEnd < S.castDelay then return end
    local tool = fishingTool()
    if not tool then update('equipe la canne pour le lancer auto | clics ' .. S.clicks); return end
    aimAtSavedPoint()
    lastCast = now
    S.castAttempts = S.castAttempts + 1
    S.spotEvent('casts')
    local ok, err = pcall(function() tool:Activate() end)
    if ok then update('lancer ' .. S.castAttempts .. ' (' .. tool.Name .. ')')
    else update('erreur lancer : ' .. tostring(err):sub(1, 70)) end
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
            S.checkInventory(); checkBait(); refreshInfo()
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
        local panel, target, needle = findMinigame()
        -- le menu ne doit pas recevoir les clics du mini-jeu (clic a la position du curseur)
        if panel then S.minigameSeenAt = os.clock() end
        if panel and ui.hideInMinigame and S.design.menuVisible then S.setMenuVisible(false, true); S.hiddenForMinigame = true end
        if not panel and S.hiddenForMinigame and os.clock() - (S.minigameSeenAt or 0) > 1.5 then S.setMenuVisible(true); S.hiddenForMinigame = false end
        if not panel then
            if minigameWasVisible then minigameWasVisible = false; lastMinigameEnd = os.clock(); S.onMinigameEnd(lastMinigameEnd) end
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
            task.spawn(function()
                if not alive(clickToken) or S.paused then pending = false; return end
                local success, method = sendClick(clickToken)
                pending = false
                if not alive(clickToken) or S.paused then return end
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
