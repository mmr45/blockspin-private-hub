-- BlockSpin Hub v0.9.0
-- Peche auto (logique v0.6.8 conservee) + cycle vente/ATM par conduite NATIVE sur route
-- (touches simulees W/A/S/D, aucun deplacement de CFrame, aucune teleportation).
-- Aucun passage sous la carte : non implemente volontairement (voir README_v080.md).
-- Arret complet : getgenv().BlockSpinCycle080.stop()
-- Arret d'urgence du cycle/conduite (le script reste charge) : F12
local VERSION = '0.9.0'
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
        elseif o.t - self.stopT >= 0.3 or not c.brake then
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
    return { Driver = Driver, DRIVE_DEFAULTS = DRIVE_DEFAULTS, validateData = validateData, DEFAULT_DATA = DEFAULT_DATA, fold = fold }
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
    S.state = state
    S.detail = detail or ''
    if stateLabel and stateLabel.Parent then stateLabel.Text = state .. (S.detail ~= '' and (' | ' .. S.detail) or '') end
end
local function update(detail) -- detail sans changer d'etat (compat v0.6.8)
    S.detail = detail
    if stateLabel and stateLabel.Parent then stateLabel.Text = S.state .. ' | ' .. tostring(detail) end
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
    local d = Driver.new(pts, S.cfg.drive)
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
    releaseAll()
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
                if not alive(tok) then hum:MoveTo(root.Position); return false, 'annule' end
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
    local pr = entry.prompt
    if type(fireproximityprompt) == 'function' then
        local ok = pcall(fireproximityprompt, pr)
        if ok then return 'fireproximityprompt' end
    end
    local code = pr.KeyboardKeyCode or Enum.KeyCode.E
    sendKey(code, true)
    sleep(math.max(0.15, (pr.HoldDuration or 0) + 0.2), tok)
    sendKey(code, false)
    return 'touche ' .. tostring(code)
end
local function pressE(tok)
    sendKey(Enum.KeyCode.E, true); sleep(0.15, tok); sendKey(Enum.KeyCode.E, false)
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
    local hum = humanoid()
    if not hum then return false, 'humanoid absent' end
    if not hum.SeatPart then return true, 'deja a pied' end
    local seat = hum.SeatPart
    local t1 = os.clock() + 3
    while os.clock() < t1 and alive(tok) and seat.AssemblyLinearVelocity.Magnitude > 2 do
        sendKey(S.cfg.keys.back, true); task.wait(0.1)
    end
    sendKey(S.cfg.keys.back, false)
    hum.Jump = true
    if sleep(0.8, tok) and not hum.SeatPart then return true, 'sortie (saut)' end
    pcall(function() hum.Sit = false end)
    if sleep(0.8, tok) and not hum.SeatPart then return true, 'sortie (Sit=false)' end
    return false, 'impossible de quitter le siege'
end
local function enterCar(tok)
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
    -- 2) marcher sur le siege (contact = assise native d'un Seat Roblox)
    hum:MoveTo(seat.Position)
    local t1 = os.clock() + 3
    while os.clock() < t1 and alive(tok) do
        if currentSeat() == seat then logLine('Entree voiture OK par contact'); return true, 'contact' end
        task.wait(0.1)
    end
    -- 3) Seat:Sit cote client (peut etre refuse par le jeu)
    pcall(function() seat:Sit(hum) end)
    if sleep(1.2, tok) and currentSeat() == seat then logLine('Entree voiture OK via Seat:Sit'); return true, 'Sit' end
    if currentSeat() and currentSeat() ~= seat then return false, 'assis dans un AUTRE siege : ' .. currentSeat():GetFullName() end
    return false, 'entree voiture echouee (prompt=' .. tostring(best ~= nil) .. ') : Settings > Diagnostic pres de la voiture'
end

---------------------------------------------------------------------------
-- 11. INVENTAIRE / APPATS (logique v0.6.8)
---------------------------------------------------------------------------
local function readCapacity()
    local items = pg:FindFirstChild('Items')
    if not items then return nil end
    local best
    for _, obj in ipairs(items:GetDescendants()) do
        if obj:IsA('TextLabel') or obj:IsA('TextButton') then
            local a, b = tostring(obj.Text):match('^%s*(%d+)%s*/%s*(%d+)%s*$')
            a, b = tonumber(a), tonumber(b)
            if a and b and b == S.inventoryLimit and a <= b then
                local depth, p = 0, obj
                while p and p ~= items do depth = depth + 1; p = p.Parent end
                if not best or depth < best.depth then best = { count = a, limit = b, depth = depth, path = obj:GetFullName() } end
            end
        end
    end
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
        elseif wasFull and not S.inventoryFull then
            S.sellAttempts = 0; lastCast = -1e6
            logLine('INVENTAIRE ' .. S.inventoryText .. ' : peche deverrouillee')
        end
    end
    return info
end
function S.setFishCount(n)
    if type(n) ~= 'number' or n < 0 then return false end
    S.fishCount = math.floor(n); S.inventoryFull = (S.fishCount >= S.inventoryLimit)
    return true
end
local function checkBait()
    local found
    for _, o in ipairs(pg:GetDescendants()) do
        if (o:IsA('TextLabel') or o:IsA('TextButton')) and not ours(o) and fold(o.Text):find('prawntec', 1, true) then
            local inline = tostring(o.Text):match('[xX]%s*(%d+)%s*$')
            if inline then found = tonumber(inline) end
            local parent = o.Parent
            if found == nil and parent then
                for _, near in ipairs(parent:GetDescendants()) do
                    if near:IsA('TextLabel') or near:IsA('TextButton') then
                        local c = tostring(near.Text):match('^%s*[xX]%s*(%d+)%s*$')
                        if c then found = tonumber(c); break end
                    end
                end
            end
        end
        if found ~= nil then break end
    end
    if found ~= nil then
        if S.baitCount ~= found then logLine('Appats lus : x' .. found) end
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
            if val then return tonumber((val:gsub('[^%d]', ''))), obj:GetFullName() end
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
    releaseMouse()
    pcall(function() VIM:SendMouseButtonEvent(x, y, 0, false, game, 0) end)
    return ok, err
end
local function sellAll(tok)
    local before = readCapacity()
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
            local after = readCapacity()
            if after and after.count < before.count then
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
            for i = 1, 10 do VIM:SendMouseMoveEvent(x0 + (x1 - x0) * i / 10, y, game); task.wait(0.03) end
            VIM:SendMouseMoveEvent(x1 + 30, y, game); task.wait(0.05)
            VIM:SendMouseButtonEvent(x1, y, 0, false, game, 0)
        end)
        mouseHeld = false
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
    if reason then logLine('ANNULATION : ' .. reason) end
end
S.cancel = function()
    cancelAll('demande utilisateur (F12)')
    S.autoCycle = false
    if S.refreshToggles then S.refreshToggles() end
    setState('ERROR', 'annule par F12 : cycle auto desactive (S.resume() ou bouton pour reprendre)')
end

local function runCycle(manual)
    if S.cycleRunning then return false, 'cycle deja en cours' end
    S.token = S.token + 1
    local tok = S.token
    S.cycleRunning = true
    task.spawn(function()
        local function fail(stage, msg)
            releaseAll(); releaseMouse()
            S.cycleRunning = false
            if not alive(tok) then return end
            S.cycleFailures = S.cycleFailures + 1
            S.lastRouteError = stage .. ' : ' .. tostring(msg)
            setState('ERROR', S.lastRouteError)
        end
        local ok, err = pcall(function()
            -- preconditions
            local info = readCapacity()
            if not manual and (not info or info.count < info.limit) then return fail('PRECONDITION', 'inventaire pas plein / illisible') end
            if not carValid() then return fail('PRECONDITION', 'aucune voiture memorisee : monte au volant puis bouton "Memoriser voiture"') end
            local D = S.data
            local rodName = fishingTool() and fishingTool().Name
            local hum = humanoid()
            if hum then pcall(function() hum:UnequipTools() end) end

            if currentSeat() ~= S.car.seat then
                setState('TO_CAR', 'marche vers ' .. S.car.name)
                local okE, why = enterCar(tok)
                if not okE then return fail('ENTREE VOITURE', why) end
            end
            setState('NAVIGATING_TO_VENDOR', '')
            local okD, why = driveRoute(D.route_to_vendor, 'ALLER', tok)
            if not okD then return fail('CONDUITE ALLER', why) end
            logLine('Aller : ' .. tostring(why))

            setState('EXIT_CAR', '')
            local okX, whyX = exitCar(tok)
            if not okX then return fail('SORTIE VOITURE', whyX) end

            setState('WALK_TO_VENDOR', '')
            local okW, whyW = walkTo(v3(D.vendor), 5, tok, 'vendeur')
            if not okW then return fail('MARCHE VENDEUR', whyW) end
            setState('SELLING', '')
            local okS, whyS = sellAll(tok)
            S.sellStage = whyS
            if not okS then return fail('VENTE', whyS) end
            logLine(whyS)

            setState('NAVIGATING_TO_ATM', '')
            local okA, whyA = walkTo(v3(D.atm), 4, tok, 'ATM')
            if okA then
                setState('DEPOSITING', '')
                local dep, whyDep = depositAll(tok)
                S.depositStatus = tostring(whyDep)
                logLine('ATM : ' .. tostring(whyDep))
                if dep == false and S.depositRequired then return fail('DEPOT', whyDep) end
            else
                S.depositStatus = 'ATM non atteint : ' .. tostring(whyA)
                logLine(S.depositStatus)
                if S.depositRequired then return fail('MARCHE ATM', whyA) end
            end
            if not alive(tok) then return fail('DEPOT', 'annule') end

            setState('BACK_TO_CAR', S.car.name)
            local okE2, whyE2 = enterCar(tok)
            if not okE2 then return fail('RETOUR VOITURE', whyE2) end
            setState('RETURNING', '')
            local okR, whyR = driveRoute(D.route_to_fishing, 'RETOUR', tok)
            if not okR then return fail('CONDUITE RETOUR', whyR) end
            logLine('Retour : ' .. tostring(whyR))
            local okX2, whyX2 = exitCar(tok)
            if not okX2 then return fail('SORTIE VOITURE (retour)', whyX2) end

            setState('RESUMING', 'marche vers le point de peche')
            local fishCF = cfOf(D.fish)
            local pre = fishCF.Position - fishCF.LookVector * 3
            walkTo(pre, 2.5, tok, 'pre-peche')
            local okF, whyF = walkTo(fishCF.Position, 2, tok, 'point de peche')
            if not okF then return fail('RETOUR PECHE', whyF) end
            if not equipRod(rodName) then logLine('Canne non re-equipee automatiquement : equipe-la') end
            S.inventoryFull = false; S.sellAttempts = 0; lastCast = -1e6
            S.cycleRunning = false; S.cycleFailures = 0
            setState('FISHING', 'cycle complet termine')
        end)
        if not ok then fail('ERREUR INTERNE', err) end
        releaseAll(); releaseMouse()
        S.cycleRunning = false
    end)
    return true
end
S.runCycle = function() return runCycle(true) end
S.retryCycle = function() S.cycleFailures = 0; S.sellAttempts = 0; return runCycle(false) end

local function testDrive(which)
    if S.cycleRunning then return false, 'cycle en cours' end
    if not currentSeat() then setState('ERROR', 'test conduite : monte au volant d\'abord'); return false end
    if not carValid() then rememberCar() end
    S.token = S.token + 1
    local tok = S.token
    S.cycleRunning = true
    local pts = which == 'retour' and S.data.route_to_fishing or S.data.route_to_vendor
    setState(which == 'retour' and 'TEST_RETOUR' or 'TEST_ALLER', 'depart dans 3 s (F12 annule)')
    task.spawn(function()
        if sleep(3, tok) then
            local ok, why = driveRoute(pts, 'TEST ' .. which:upper(), tok)
            if alive(tok) then
                local d = S.driver
                local extra = d and string.format(' | ecart max %.1f studs, demi-tours %d, degagements %d', d.maxCross or 0, d.uturns or 0, d.recoveries or 0) or ''
                setState(ok and 'IDLE' or 'ERROR', 'test ' .. which .. ' : ' .. tostring(why) .. extra)
            end
        end
        releaseAll()
        if alive(tok) then S.cycleRunning = false end
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
-- 17. INTERFACE SIMPLIFIEE (theme du hub 0.4.0)
-- 3 onglets : Accueil (l'essentiel), Index (poissons/plantes), Reglages.
-- Les outils techniques sont dans Reglages > Avance (replie par defaut).
-- Clavier : touche d'affichage (RightShift par defaut) et F12 (urgence) seulement.
---------------------------------------------------------------------------
local SETTINGS_FILE = 'blockspin-settings-v1.json'
local ui = { accent = 'C5F277', hotkey = 'RightShift', scale = 1, metrics = true, overlay = false, hideInMinigame = true,
    speedPreset = 'Rapide', rareAction = 'none', rarePurple = true }
local PREF_KEYS = { 'accent', 'hotkey', 'scale', 'metrics', 'overlay', 'hideInMinigame', 'speedPreset', 'rareAction', 'rarePurple',
    'position', 'size', 'overlayPosition' }
local RARE_ACTIONS = { none = 'ne rien faire', leave = 'quitter le serveur', sell = 'aller vendre' }
local settingsRaw -- fichier lu en entier : profils et champs du hub 0.4.0 conserves
local function validKeyName(n)
    if type(n) ~= 'string' or n == 'Escape' or n == 'Unknown' or n == 'F12' then return false end
    local ok, k = pcall(function() return Enum.KeyCode[n] end)
    return ok and k ~= nil
end
local function readPrefs(d, into)
    if type(d.accent) == 'string' and d.accent:match('^%x%x%x%x%x%x$') then into.accent = d.accent end
    if validKeyName(d.hotkey) then into.hotkey = d.hotkey end
    if isNum(d.scale) and d.scale >= 0.75 and d.scale <= 1.5 then into.scale = d.scale end
    for _, k in ipairs({ 'metrics', 'overlay', 'hideInMinigame', 'rarePurple' }) do if type(d[k]) == 'boolean' then into[k] = d[k] end end
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
    background = Color3.fromRGB(14, 16, 18), surface = Color3.fromRGB(23, 26, 29),
    control = Color3.fromRGB(31, 35, 39), border = Color3.fromRGB(47, 53, 59),
    text = Color3.fromRGB(241, 244, 239), muted = Color3.fromRGB(166, 175, 181),
    danger = Color3.fromRGB(150, 40, 40),
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
        if not ok then logLine('Erreur interface : ' .. tostring(err)) end
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
local window = make('Frame', { Name = 'Window', BackgroundColor3 = theme.background, BorderSizePixel = 0,
    ClipsDescendants = true, Active = true }, gui)
local menuScale = make('UIScale', { Scale = ui.scale }, window)
round(window, 12); outline(window)
local function fitWindow()
    local v, sc = viewportSize(), ui.scale
    local maxW, maxH = math.max(1, v.X / sc), math.max(1, v.Y / sc)
    local w = clamp(window.Size.X.Offset, math.min(380, maxW), maxW)
    local h = clamp(window.Size.Y.Offset, math.min(360, maxH), maxH)
    window.Size = UDim2.fromOffset(w, h)
    window.Position = UDim2.fromOffset(clamp(window.Position.X.Offset, 0, math.max(0, v.X - w * sc)),
        clamp(window.Position.Y.Offset, 0, math.max(0, v.Y - h * sc)))
end
local size0 = ui.size or { x = 430, y = 500 }
local pos0 = ui.position or { x = 16, y = 90 }
window.Size = UDim2.fromOffset(size0.x, size0.y)
window.Position = UDim2.fromOffset(pos0.x, pos0.y)

local accentItems = {}
local function label(parent, text, height)
    return make('TextLabel', { Size = UDim2.new(1, 0, 0, height or 32), BackgroundTransparency = 1, Text = text,
        TextWrapped = true, TextColor3 = theme.muted, TextSize = 13, Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center }, parent)
end
local function button(parent, text, fn, height)
    local b = make('TextButton', { Size = UDim2.new(1, 0, 0, height or 40), BackgroundColor3 = theme.control, BorderSizePixel = 0,
        Text = text, TextColor3 = theme.text, TextSize = 14, Font = Enum.Font.GothamMedium, TextWrapped = true,
        AutoButtonColor = true, TextXAlignment = Enum.TextXAlignment.Left }, parent)
    round(b, 8); outline(b); inset(b, 14)
    connect(b.Activated, function() fn(b) end)
    return b
end
local function textbox(parent, placeholder)
    local t = make('TextBox', { Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = theme.background, BorderSizePixel = 0,
        Text = '', PlaceholderText = placeholder, ClearTextOnFocus = false, PlaceholderColor3 = theme.muted,
        TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = theme.text, TextSize = 13, Font = Enum.Font.Gotham }, parent)
    round(t, 7); outline(t); inset(t, 14)
    return t
end
local function section(parent, text)
    local h = label(parent, text, 24)
    h.TextSize, h.TextColor3, h.Font = 11, theme.accent, Enum.Font.GothamBold
    table.insert(accentItems, h)
    return h
end
local function notice(parent, text, height)
    local n = label(parent, text, height or 52)
    n.BackgroundTransparency, n.BackgroundColor3, n.TextColor3 = 0, theme.surface, theme.muted
    n.TextYAlignment = Enum.TextYAlignment.Top
    round(n, 8); outline(n); inset(n, 12)
    return n
end
local toggles = {}
local function toggle(parent, textFn, fn, height)
    local b = button(parent, textFn(), function(b) fn(); b.Text = textFn() end, height)
    table.insert(toggles, function() b.Text = textFn() end)
    return b
end
function S.refreshToggles() for _, f in ipairs(toggles) do pcall(f) end end
local function grid(parent, items, h)
    h = h or 38
    local holder = make('Frame', { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, math.ceil(#items / 2) * (h + 6)) }, parent)
    for i, it in ipairs(items) do
        local b = button(holder, it[1], it[2], h)
        b.Size = UDim2.new(0.5, -4, 0, h)
        b.Position = UDim2.new(((i - 1) % 2) * 0.5, ((i - 1) % 2) * 4, 0, math.floor((i - 1) / 2) * (h + 6))
    end
    return holder
end

-- en-tete : titre (sert a deplacer) + FPS
local top = make('Frame', { Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = theme.surface, BorderSizePixel = 0, Active = true }, window)
local title = label(top, 'BLOCKSPIN', 26)
title.Position = UDim2.fromOffset(16, 4); title.Size = UDim2.new(1, -170, 0, 26)
title.TextSize, title.Font, title.TextColor3 = 18, Enum.Font.GothamBold, theme.text
local sub = label(top, 'v' .. VERSION .. '  /  ' .. ui.hotkey .. ' : masquer', 14)
sub.Position = UDim2.fromOffset(16, 30); sub.Size = UDim2.new(1, -170, 0, 14); sub.TextSize = 10
local metrics = label(top, 'FPS --', 24)
metrics.Size = UDim2.fromOffset(140, 24); metrics.Position = UDim2.new(1, -152, 0, 13)
metrics.TextSize, metrics.TextColor3, metrics.TextXAlignment = 11, theme.muted, Enum.TextXAlignment.Right
metrics.Visible = ui.metrics
-- onglets en haut (3 seulement)
local tabBar = make('Frame', { Position = UDim2.fromOffset(10, 56), Size = UDim2.new(1, -20, 0, 34), BackgroundTransparency = 1 }, window)
-- pied : etat du script
local footer = make('Frame', { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 1, -40),
    BackgroundColor3 = theme.surface, BorderSizePixel = 0 }, window)
stateLabel = label(footer, 'demarrage', 38)
stateLabel.Position = UDim2.fromOffset(14, 1); stateLabel.Size = UDim2.new(1, -50, 0, 38)
stateLabel.TextSize, stateLabel.TextColor3, stateLabel.Font = 12, theme.accent, Enum.Font.Code
table.insert(accentItems, stateLabel)
local resize = make('TextButton', { Text = '<>', TextSize = 13, TextColor3 = theme.text, BackgroundColor3 = theme.control,
    Size = UDim2.fromOffset(24, 24), Position = UDim2.new(1, -30, 1, -32), ZIndex = 5 }, window)

local pages, tabButtons, pageOrder = {}, {}, {}
local activePage = 'Accueil'
local function updateTabs()
    for name, b in pairs(tabButtons) do
        local sel = name == activePage
        b.BackgroundColor3 = sel and theme.accent or theme.control
        b.TextColor3 = sel and theme.background or theme.text
        pages[name].Visible = sel
    end
end
local TAB_NAMES = { 'Accueil', 'Index', 'Reglages' }
local function page(name)
    local body = make('ScrollingFrame', { Name = name, BackgroundTransparency = 1, BorderSizePixel = 0,
        Position = UDim2.fromOffset(12, 98), Size = UDim2.new(1, -24, 1, -146), CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = theme.border, Visible = false }, window)
    make('UIListLayout', { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, body)
    make('UIPadding', { PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 12) }, body)
    pages[name] = body
    pageOrder[#pageOrder + 1] = name
    local i = #pageOrder
    local tb = make('TextButton', { Size = UDim2.new(1 / #TAB_NAMES, -4, 1, 0), Position = UDim2.new((i - 1) / #TAB_NAMES, 2, 0, 0),
        BackgroundColor3 = theme.control, BorderSizePixel = 0, Text = name, TextColor3 = theme.text, TextSize = 13,
        Font = Enum.Font.GothamBold }, tabBar)
    round(tb, 8)
    connect(tb.Activated, function() activePage = name; updateTabs() end)
    tabButtons[name] = tb
    return body
end

---------------------------------------------------------------------------
-- ACCUEIL
---------------------------------------------------------------------------
local home = page('Accueil')
infoLabel = notice(home, '', 58)
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
local stopBtn = button(home, 'STOP  (tout annuler, F12)', function() S.cancel() end, 44)
stopBtn.BackgroundColor3 = theme.danger
stopBtn.TextXAlignment = Enum.TextXAlignment.Center
section(home, 'JOURNAL')
logLabel = notice(home, '', 128)
logLabel.TextSize = 11; logLabel.Font = Enum.Font.Code

---------------------------------------------------------------------------
-- INDEX : poissons et plantes
---------------------------------------------------------------------------
-- Sources web consultees le 2026-11-05 (sites de fans, NON verifiees en jeu) :
-- treyexgaming.com/blockspin-fishing-update-2-guide, blockspin-wiki.wiki, TikTok.
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
S.fishLog = {}
local FISHLOG_FILE = 'blockspin_fishlog.json'
pcall(function()
    if type(readfile) == 'function' and type(isfile) == 'function' and isfile(FISHLOG_FILE) then
        local d = HttpService:JSONDecode(readfile(FISHLOG_FILE))
        if type(d) == 'table' then for k, v in pairs(d) do if type(k) == 'string' and isNum(v) then S.fishLog[k] = v end end end
    end
end)
local index = page('Index')
section(index, 'POISSONS (liste web, non verifiee en jeu)')
local lines = {}
for _, f in ipairs(FISH_WEB) do lines[#lines + 1] = string.format('%s  |  %s  |  %s', f[1], f[2], f[3]) end
notice(index, table.concat(lines, '\n'), #FISH_WEB * 16 + 14)
section(index, 'VUS PENDANT TES PECHES (textes apparus apres une prise)')
local seenLabel = notice(index, '', 60)
local function refreshFishLog()
    local names = {}
    for k, v in pairs(S.fishLog) do names[#names + 1] = { k, v } end
    table.sort(names, function(a, b) return a[2] > b[2] end)
    local t = {}
    for i = 1, math.min(15, #names) do t[#t + 1] = names[i][1] .. '  x' .. names[i][2] end
    seenLabel.Text = #t == 0 and 'Rien encore : la liste se remplit pendant que tu peches.' or table.concat(t, '\n')
    seenLabel.Size = UDim2.new(1, 0, 0, math.max(40, #t * 16 + 14))
end
refreshFishLog()
section(index, 'PLANTES (liste web, non verifiee ; culture auto non disponible)')
lines = {}
for _, p in ipairs(PLANTS_WEB) do lines[#lines + 1] = p[1] .. '  |  ' .. p[2] end
notice(index, table.concat(lines, '\n'), #PLANTS_WEB * 16 + 14)

---------------------------------------------------------------------------
-- REGLAGES
---------------------------------------------------------------------------
local settingsPage = page('Reglages')
section(settingsPage, 'COULEUR')
local PALETTE = { 'C5F277', '5EC8FF', 'B07CFF', 'FF6FA8', 'FF9F43', 'FFD84D', '4DE0A0', 'F1F4EF' }
local function applyAccent(hex)
    theme.accent = hexColor(hex)
    for _, it in ipairs(accentItems) do it.TextColor3 = theme.accent end
    updateTabs()
end
local swatches = make('Frame', { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34) }, settingsPage)
for i, hex in ipairs(PALETTE) do
    local h = hex
    local sw = make('TextButton', { Name = 'Couleur' .. h, Text = '', BackgroundColor3 = hexColor(h), BorderSizePixel = 0,
        Size = UDim2.new(1 / #PALETTE, -6, 1, 0), Position = UDim2.new((i - 1) / #PALETTE, 3, 0, 0) }, swatches)
    round(sw, 8)
    connect(sw.Activated, function() ui.accent = h; applyAccent(h); saveSettings() end)
end
toggle(settingsPage, function() return 'Taille du menu : ' .. math.floor(ui.scale * 100 + 0.5) .. ' %' end,
    function()
        local nextScale = { [75] = 1, [100] = 1.25, [125] = 1.5, [150] = 0.75 }
        ui.scale = nextScale[math.floor(ui.scale * 100 + 0.5)] or 1
        menuScale.Scale = ui.scale; fitWindow(); saveSettings()
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
toggle(settingsPage, function() return 'Detecter aussi les textes violets : ' .. (ui.rarePurple and 'oui' or 'non') end,
    function() ui.rarePurple = not ui.rarePurple; saveSettings() end)
local capturing = false
local function keyText() return 'Touche pour masquer le menu : ' .. ui.hotkey end
local hotkeyButton = button(settingsPage, keyText(), function(b) capturing = true; b.Text = 'Appuie sur une touche... (Echap : annuler)' end)

section(settingsPage, 'PROFILS (tes reglages enregistres)')
local profileBox = textbox(settingsPage, 'Nom du profil')
local profileList = label(settingsPage, '', 22)
local function refreshProfiles()
    local names = {}
    for n in pairs(profiles) do names[#names + 1] = n end
    table.sort(names)
    profileList.Text = #names == 0 and 'Aucun profil.' or ('Profils : ' .. table.concat(names, ', '))
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
    if ui.size then window.Size = UDim2.fromOffset(ui.size.x, ui.size.y) end
    if ui.position then window.Position = UDim2.fromOffset(ui.position.x, ui.position.y) end
    if ui.overlayPosition then overlay.Position = UDim2.fromOffset(ui.overlayPosition.x, ui.overlayPosition.y) end
    sub.Text = 'v' .. VERSION .. '  /  ' .. ui.hotkey .. ' : masquer'
    hotkeyButton.Text = keyText()
    fitWindow(); S.refreshToggles()
end
grid(settingsPage, {
    { 'Enregistrer', function()
        local n = profileName(); if not n then return end
        local count = 0
        for _ in pairs(profiles) do count = count + 1 end
        if not profiles[n] and count >= 10 then logLine('Maximum 10 profils'); return end
        local p = {}
        for _, k in ipairs(PREF_KEYS) do p[k] = ui[k] end
        profiles[n] = p
        refreshProfiles(); saveSettings(); logLine('Profil enregistre : ' .. n)
    end },
    { 'Charger', function()
        local n = profileName(); if not n then return end
        if type(profiles[n]) ~= 'table' then logLine('Profil introuvable : ' .. n); return end
        readPrefs(profiles[n], ui)
        applyPrefs(); saveSettings(); logLine('Profil charge : ' .. n)
    end },
    { 'Supprimer', function()
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
        logLine('Place la souris sur l\'eau : capture dans 3 s')
        task.delay(3, function()
            if not S.running then return end
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
S.window = window
fitWindow()
updateTabs()

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
    if ui.rareAction == 'leave' then
        task.delay(1, function()
            if S.running then pcall(function() player:Kick('BlockSpin hub : poisson rare detecte (' .. text:sub(1, 40) .. ')') end) end
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
                S.fishLog[t] = (S.fishLog[t] or 0) + 1; changed = true
            end
            local rare = false
            for _, w in ipairs(RARE_WORDS) do if f:find(w, 1, true) then rare = true end end
            if not rare and ui.rarePurple and isPurple(o.TextColor3) then rare = true end
            if rare and ui.rareAction ~= 'none' and os.clock() > rareCooldownUntil and S.running then rareTrigger(t) end
        end
    end
    if changed then
        refreshFishLog()
        if type(writefile) == 'function' then pcall(function() writefile(FISHLOG_FILE, HttpService:JSONEncode(S.fishLog)) end) end
    end
end

-- FPS (1 mesure par seconde) + infos voiture
local frames, elapsed = 0, 0
connect(RunService.RenderStepped, function(dt)
    frames = frames + 1; elapsed = elapsed + dt
    if elapsed < 1 then return end
    if ui.metrics or ui.overlay then
        local ok, ping = pcall(function() return player:GetNetworkPing() end)
        local pingText = (ok and isNum(ping) and ping >= 0) and string.format('%.0f ms', ping * 1000) or 'N/D'
        local txt = string.format('FPS %.0f | %s', frames / elapsed, pingText)
        metrics.Text = txt; overlay.Text = txt
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
local function sendClick()
    if type(mouse1click) == 'function' then
        if pcall(mouse1click) then return true, 'mouse1click' end
    end
    if type(mouse1press) == 'function' and type(mouse1release) == 'function' then
        if pcall(function() mouse1press(); task.wait(0.025); mouse1release() end) then return true, 'mouse1press/release' end
    end
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
local function refreshInfo()
    if not (infoLabel and infoLabel.Parent) then return end
    local d = S.cfg.drive
    infoLabel.Text = string.format('Inventaire %s | Appats %s | Clics %d | Lancers %d\nVoiture : %s | Donnees : %s\nVitesse cible %.0f/%.0f | Erreurs touches %d | Cycle auto %s',
        S.inventoryText, S.baitUnknown and 'inconnus' or ('x' .. tostring(S.baitCount)), S.clicks, S.castAttempts,
        S.car and S.car.name or 'non memorisee', S.dataSource == DATA_FILE and 'fichier' or 'defauts',
        d.cruiseSpeed, d.turnSpeed, S.keyErrors, S.autoCycle and 'ON' or 'OFF')
end

table.insert(conns, RunService.Heartbeat:Connect(function()
    if not S.running then return end
    local ok, err = pcall(function()
        local now = os.clock()
        if now >= nextCheck then
            nextCheck = now + 0.8
            S.checkInventory(); checkBait(); refreshInfo(); S.scanCatch(now)
            if S.recording then
                local seat = currentSeat()
                if seat then
                    local p = seat.Position
                    local last = S.recordBuffer[#S.recordBuffer]
                    if not last or (Vector3.new(last[1], last[2], last[3]) - p).Magnitude > 14 then
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
        if not S.fishingEnabled or S.cycleRunning then return end
        local panel, target, needle = findMinigame()
        -- le menu ne doit pas recevoir les clics du mini-jeu (clic a la position du curseur)
        if panel and ui.hideInMinigame and window.Visible then window.Visible = false; S.hiddenForMinigame = true end
        if not panel and S.hiddenForMinigame then window.Visible = true; S.hiddenForMinigame = false end
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
            task.spawn(function()
                local success, method = sendClick()
                pending = false
                if not S.running then return end
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
    if not ok then update('ERREUR : ' .. tostring(err):sub(1, 95)) end
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
        window.Visible = not window.Visible
        S.hiddenForMinigame = false
        gesture = nil
    end
end)
function S.useRecording(which)
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
    S.paused = false; S.cycleFailures = 0
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
    S.recording = false
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
