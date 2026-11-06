-- Maquette Roblox MINIMALE pour tester blockspin_cycle_v080.lua hors jeu.
-- Les interfaces (vendeur, ATM, prompts) sont INVENTEES pour le test : elles imitent les
-- observations decrites par l'utilisateur, pas la vraie hierarchie BlockSpin.
local M = { clock = 0, keys = {}, keyLog = {}, writes = 0, fs = {}, heartbeat = {}, input = {}, tasks = {} }
os.clock = function() return M.clock end

-- Vector3 ---------------------------------------------------------------
local V3 = {}
V3.__index = function(t, k)
    if k == 'Magnitude' then return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) end
    if k == 'Unit' then local m = math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z); return Vector3.new(t.X / m, t.Y / m, t.Z / m) end
    return rawget(V3, k)
end
V3.__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__mul = function(a, b)
    if type(a) == 'number' then a, b = b, a end
    if type(b) == 'number' then return Vector3.new(a.X * b, a.Y * b, a.Z * b) end
    return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b) return Vector3.new(a.X / b, a.Y / b, a.Z / b) end
V3.__tostring = function(v) return string.format('%.1f, %.1f, %.1f', v.X, v.Y, v.Z) end
Vector3 = { new = function(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3) end }
Vector3.zero = Vector3.new(0, 0, 0)
local V2 = {}
V2.__index = V2
V2.__add = function(a, b) return Vector2.new(a.X + b.X, a.Y + b.Y) end
V2.__div = function(a, b) return Vector2.new(a.X / b, a.Y / b) end
Vector2 = { new = function(x, y) return setmetatable({ X = x or 0, Y = y or 0 }, V2) end }

-- CFrame (rotation autour de Y uniquement + composantes brutes) -----------
local CFm = {}
CFm.__index = CFm
function CFm:GetComponents() return table.unpack(self.c) end
local function mkCF(c)
    local cf = setmetatable({ c = c }, CFm)
    cf.Position = Vector3.new(c[1], c[2], c[3])
    cf.X, cf.Y, cf.Z = c[1], c[2], c[3]
    cf.LookVector = Vector3.new(-c[6], -c[9], -c[12])
    cf.RightVector = Vector3.new(c[4], c[7], c[10])
    return cf
end
CFrame = {
    new = function(...)
        local a = { ... }
        if #a == 12 then return mkCF(a) end
        if #a == 1 then return mkCF({ a[1].X, a[1].Y, a[1].Z, 1, 0, 0, 0, 1, 0, 0, 0, 1 }) end
        return mkCF({ a[1], a[2], a[3], 1, 0, 0, 0, 1, 0, 0, 0, 1 })
    end,
}
function M.cfYaw(x, y, z, yaw)
    local c, s = math.cos(yaw), math.sin(yaw)
    return mkCF({ x, y, z, c, 0, s, 0, 1, 0, -s, 0, c })
end

UDim = { new = function(s, o) return { Scale = s or 0, Offset = o or 0 } end }
local function ud2(xs, xo, ys, yo) return { X = UDim.new(xs, xo), Y = UDim.new(ys, yo) } end
UDim2 = { new = ud2, fromOffset = function(x, y) return ud2(0, x, 0, y) end, fromScale = function(x, y) return ud2(x, 0, y, 0) end }
Color3 = { fromRGB = function(r, g, b) return { R = (r or 0) / 255, G = (g or 0) / 255, B = (b or 0) / 255 } end }
local function enumGroup(name)
    return setmetatable({}, { __index = function(t, k)
        local v = setmetatable({ Name = k }, { __tostring = function() return 'Enum.' .. name .. '.' .. k end })
        rawset(t, k, v); return v
    end })
end
Enum = setmetatable({}, { __index = function(t, k) local g = enumGroup(k); rawset(t, k, g); return g end })

-- Signals -----------------------------------------------------------------
local function Signal()
    local s = { list = {} }
    function s:Connect(fn)
        local c = { fn = fn, connected = true }
        function c:Disconnect() c.connected = false end
        table.insert(s.list, c)
        return c
    end
    function s:Fire(...) for _, c in ipairs(s.list) do if c.connected then c.fn(...) end end end
    function s:count() local n = 0; for _, c in ipairs(s.list) do if c.connected then n = n + 1 end end; return n end
    return s
end
M.Signal = Signal

-- Instances ---------------------------------------------------------------
local ISA = {
    GuiObject = { Frame = 1, TextLabel = 1, TextButton = 1, ImageButton = 1, TextBox = 1, ScrollingFrame = 1, CanvasGroup = 1, ImageLabel = 1 },
    BasePart = { Part = 1, VehicleSeat = 1, Seat = 1 },
    GuiButton = { TextButton = 1, ImageButton = 1 },
}
local Inst = {}
local function new(class, name, parent, props)
    local o = { ClassName = class, Name = name or class, _children = {}, Visible = true, Enabled = true }
    setmetatable(o, Inst)
    for k, v in pairs(props or {}) do o[k] = v end
    if class == 'TextButton' or class == 'ImageButton' then o.MouseButton1Click = Signal(); o.Activated = Signal() end
    if class=='Tool' then o.Activated=Signal();o.Deactivated=Signal() end
    if class=='ImageLabel' then o.IsLoaded=M.thumbnailLoaded~=false end
    if ISA.GuiObject[class] then o.InputBegan = Signal(); o.MouseEnter = Signal(); o.MouseLeave = Signal() end
    o._propSignals = {}
    if parent then o:SetParent(parent) end
    return o
end
M.new = new
Inst.__index = function(t,k)
    if k=='Parent' then return rawget(t,'_parent') end
    return Inst[k]
end
function Inst:SetParent(p)
    if self.Parent then
        local list = self.Parent._children
        for i, c in ipairs(list) do if c == self then table.remove(list, i); break end end
    end
    rawset(self, '_parent', p)
    if p then table.insert(p._children, self) end
end
Inst.__newindex = function(t, k, v)
    if k == 'Parent' then Inst.SetParent(t, v) else rawset(t, k, v) end
end
function Inst:IsA(c) return self.ClassName == c or c == 'Instance' or (ISA[c] and ISA[c][self.ClassName] ~= nil) or false end
function Inst:GetChildren() local o = {}; for i, c in ipairs(self._children) do o[i] = c end; return o end
function Inst:GetDescendants()
    if self == M.pg then M.pgScans = (M.pgScans or 0) + 1 end
    local o = {}
    local function rec(x) for _, c in ipairs(x._children) do o[#o + 1] = c; rec(c) end end
    rec(self); return o
end
function Inst:FindFirstChild(n, rec)
    for _, c in ipairs(self._children) do if c.Name == n then return c end end
    if rec then for _, c in ipairs(self._children) do local r = c:FindFirstChild(n, true); if r then return r end end end
end
function Inst:WaitForChild(n) return self:FindFirstChild(n) end
function Inst:FindFirstChildOfClass(c) for _, x in ipairs(self._children) do if x.ClassName == c then return x end end end
function Inst:FindFirstChildWhichIsA(c, rec)
    for _, x in ipairs(rec and self:GetDescendants() or self._children) do if x:IsA(c) then return x end end
end
function Inst:FindFirstAncestorWhichIsA(c) local p = self.Parent; while p do if p:IsA(c) then return p end; p = p.Parent end end
function Inst:FindFirstAncestorOfClass(c) local p = self.Parent; while p do if p.ClassName == c then return p end; p = p.Parent end end
function Inst:IsDescendantOf(a) local p = self.Parent; while p do if p == a then return true end; p = p.Parent end; return false end
function Inst:GetFullName() local n = self.Name; local p = self.Parent; while p and p.ClassName ~= 'DataModel' do n = p.Name .. '.' .. n; p = p.Parent end; return n end
function Inst:Destroy()
    for _,child in ipairs(self:GetChildren()) do child:Destroy() end
    self:SetParent(nil); self.destroyed = true
end
function Inst:GetAttribute(k) return self.attrs and self.attrs[k] end
function Inst:GetAttributes() local out={};for k,v in pairs(self.attrs or {}) do out[k]=v end;return out end
function Inst:GetAttributeChangedSignal(k) return self:GetPropertyChangedSignal('Attribute:'..k) end
function Inst:SetAttribute(k,v) self.attrs=self.attrs or {};self.attrs[k]=v;self:GetAttributeChangedSignal(k):Fire() end
function Inst:ClearAllChildren() self._children = {} end
function Inst:GetPropertyChangedSignal(p) self._propSignals[p] = self._propSignals[p] or Signal(); return self._propSignals[p] end

-- Monde -------------------------------------------------------------------
local DataModel = new('DataModel', 'game')
workspace = new('Workspace', 'Workspace', DataModel)
M.workspace = workspace
local Players = new('Players', 'Players', DataModel)
local player = new('Player', 'Player1', Players)
Players.LocalPlayer = player
Players.MaxPlayers=30;Players.PlayerAdded=Signal();Players.PlayerRemoving=Signal()
function Players:GetPlayers() return self:GetChildren() end
M.Players=Players
player.Name='mmr45'; player.DisplayName='Osman'; player.UserId=143872552
function Players:GetUserThumbnailAsync(id,kind,size)
    M.thumbnailCalls=(M.thumbnailCalls or 0)+1
    M.thumbnailUserId=id
    if M.thumbnailFail then error('thumbnail unavailable') end
    if M.thumbnailWait then task.wait(M.thumbnailWait) end
    return 'rbxthumb://type=AvatarHeadShot&id='..id..'&w=150&h=150', M.thumbnailReady~=false
end
local pg = new('PlayerGui', 'PlayerGui', player)
local backpack = new('Backpack', 'Backpack', player)
M.pg, M.player, M.backpack = pg, player, backpack

local char = new('Model', 'Player1', workspace)
player.Character = char
local root = new('Part', 'HumanoidRootPart', char)
local hum = new('Humanoid', 'Humanoid', char, { Health = 100, Jump = false, Sit = false })
M.root, M.hum, M.char = root, hum, char
root.Position = Vector3.new(0, 0, 0)
root.CFrame = CFrame.new(0, 0, 0)
function hum:MoveTo(p) M.moveTarget = p end
function hum:EquipTool(t) t.Parent = char end
function hum:UnequipTools() for _, c in ipairs(char:GetChildren()) do if c.ClassName == 'Tool' then c.Parent = backpack end end end
local rod = new('Tool', 'Fishing Rod', char)
M.rod=rod
function rod:Activate()
    M.activationCalls=(M.activationCalls or 0)+1
    if not self.Enabled or (M.requireRodRelease and self._active) then M.ignoredActivations=(M.ignoredActivations or 0)+1;return end
    if M.ignoreNextActivations and M.ignoreNextActivations>0 then M.ignoreNextActivations=M.ignoreNextActivations-1;M.ignoredActivations=(M.ignoredActivations or 0)+1;return end
    if M.failRodActivation then error('activation refusee (test)') end
    self._active=true;M.casts=(M.casts or 0)+1;M.lastCastMouse={X=M.mouseX,Y=M.mouseY};M.lastCastAt=M.clock
    M.rodLog=M.rodLog or {};M.rodLog[#M.rodLog+1]={kind='press',at=M.clock}
    local function ack() if not M.suppressRodSignal then self.Activated:Fire() end end
    if M.rodSignalDelay then task.delay(M.rodSignalDelay,ack) else ack() end
    if M.onRodActivate then M.onRodActivate(self) end
end
function rod:Deactivate()
    if not self._active then return end
    self._active=false;M.rodReleases=(M.rodReleases or 0)+1
    M.rodLog=M.rodLog or {};M.rodLog[#M.rodLog+1]={kind='release',at=M.clock}
    self.Deactivated:Fire()
    if M.onRodDeactivate then M.onRodDeactivate(self) end
end

-- GUI du jeu (imitation)
local items = new('ScreenGui', 'Items', pg)
local holder = new('Frame', 'ItemsHolder', items, { AbsolutePosition = Vector2.new(0, 0), AbsoluteSize = Vector2.new(800, 600) })
M.capLabel = new('TextLabel', 'Capacity', holder, { Text = '18/18', AbsolutePosition = Vector2.new(10, 10), AbsoluteSize = Vector2.new(50, 20) })
M.sellBtn = new('TextButton', 'SellAllFishButton', holder, { Text = 'SELL ALL', Visible = false, AbsolutePosition = Vector2.new(300, 500), AbsoluteSize = Vector2.new(200, 50) })
local baitRow = new('Frame', 'BaitRow', holder, { AbsolutePosition = Vector2.new(0, 0), AbsoluteSize = Vector2.new(100, 20) })
new('TextLabel', 'Name', baitRow, { Text = 'PRAWNTEC ULTIMATE', AbsolutePosition = Vector2.new(0, 0), AbsoluteSize = Vector2.new(100, 20) })
M.baitLabel = new('TextLabel', 'Count', baitRow, { Text = 'x16', AbsolutePosition = Vector2.new(0, 0), AbsoluteSize = Vector2.new(30, 20) })
local hud = new('ScreenGui', 'HUD', pg)
M.cashLabel = new('TextLabel', 'Cash', hud, { Text = 'Cash: $500', AbsolutePosition = Vector2.new(0, 0), AbsoluteSize = Vector2.new(100, 20) })
local atmGui = new('ScreenGui', 'ATM', pg, { Enabled = false })
local atmFrame = new('Frame', 'Main', atmGui, { AbsolutePosition = Vector2.new(0, 0), AbsoluteSize = Vector2.new(600, 400) })
M.depBtn = new('TextButton', 'Deposit', atmFrame, { Text = 'DÉPÔT', AbsolutePosition = Vector2.new(100, 100), AbsoluteSize = Vector2.new(120, 40) })
M.slider = new('Frame', 'SliderTrack', atmFrame, { Visible = false, AbsolutePosition = Vector2.new(100, 200), AbsoluteSize = Vector2.new(300, 20) })
M.confirmBtn = new('TextButton', 'Confirm', atmFrame, { Text = 'CONFIRMER', Visible = false, AbsolutePosition = Vector2.new(100, 300), AbsoluteSize = Vector2.new(140, 40) })

-- Voiture
local vehicles = new('Folder', 'Vehicles', workspace)
local carModel = new('Model', 'G-Cruzer', vehicles)
local motors = new('Folder', 'Motors', carModel, { attrs = { forwardMaxSpeed = 65 } })
local seat = new('VehicleSeat', 'DriverSeat', carModel)
seat.AssemblyLinearVelocity = Vector3.zero
seat.AssemblyAngularVelocity = Vector3.zero
M.seat, M.carModel = seat, carModel
M.drivePrompt = new('ProximityPrompt', 'DrivePrompt', seat, { ActionText = 'Drive', ObjectText = 'G-Cruzer', HoldDuration = 0, MaxActivationDistance = 10 })

local function promptPart(name, pos, action)
    local p = new('Part', name, workspace, { Position = pos })
    return new('ProximityPrompt', 'Prompt', p, { ActionText = action, ObjectText = name, HoldDuration = 0 })
end
function M.placeShop(vendorPos, atmPos)
    M.vendorPrompt = promptPart('FishSeller', vendorPos + Vector3.new(0, 0, -3), 'Sell Fish')
    M.atmPrompt = promptPart('ATM', atmPos + Vector3.new(0, 0, -3), 'Use ATM')
end

-- Physique simplifiee ------------------------------------------------------
function M.setCar(car) M.car = car; M.syncSeat() end
function M.syncSeat()
    local c = M.car
    seat.Position = Vector3.new(c.x, 254.5, c.z)
    seat.CFrame = M.cfYaw(c.x, 254.5, c.z, c.yaw)
    local lx, lz = c:look()
    seat.AssemblyLinearVelocity = Vector3.new(lx * c.v, 0, lz * c.v)
    seat.AssemblyAngularVelocity = Vector3.new(0, c.yawRate, 0)
end
local function sitIn(s)
    hum.SeatPart = s; hum.Sit = true; M.moveTarget = nil
end
Instance = { new = function(c) return new(c) end }
function M.setRoot(pos) root.Position = pos; root.CFrame = CFrame.new(pos.X, pos.Y, pos.Z) end

-- Services ------------------------------------------------------------------
local RunService = { Heartbeat = Signal(), RenderStepped = Signal() }
local UIS = { InputBegan = Signal(), InputChanged = Signal(), InputEnded = Signal(), WindowFocusReleased = Signal(), WindowFocused=Signal(), focused = nil }
workspace.CurrentCamera = new('Camera','CurrentCamera',workspace,{ ViewportSize = Vector2.new(1920,1080) })
function player:GetNetworkPing() return 0.05 end
function player:IsFriendsWith(id) return M.friendIds and M.friendIds[id]==true end
function player:GetMouse() return {Hit={Position=M.mouseWorld}} end
function workspace.CurrentCamera:WorldToViewportPoint(point)
    if M.projectedPoint then return M.projectedPoint,M.projectedVisible~=false end
    error('projection non configuree dans la maquette')
end
function player:Kick(msg) M.kicked = msg end
function UIS:GetFocusedTextBox() return self.focused end
function UIS:GetMouseLocation() return Vector2.new(M.mouseX or 0, M.mouseY or 0) end
local function inside(btn, x, y)
    return btn.Visible and btn.AbsolutePosition.X <= x and x <= btn.AbsolutePosition.X + btn.AbsoluteSize.X
        and btn.AbsolutePosition.Y <= y and y <= btn.AbsolutePosition.Y + btn.AbsoluteSize.Y
end
local VIM = {}
function VIM:SendKeyEvent(down, code, rep, g)
    if M.failKeys then error('SendKeyEvent refuse (test)') end
    M.keys[code.Name] = down or nil
    table.insert(M.keyLog, (down and '+' or '-') .. code.Name)
    if down and code.Name == 'E' then M.onE() end
end
function VIM:SendMouseMoveEvent(x,y)
    if M.failMouseMove then error('mouvement refuse') end
    M.lastMoveAt=M.clock
    if M.deferMouseMove then M.pendingMouse={x,y} else M.mouseX,M.mouseY=x,y end
end
function VIM:SendMouseButtonEvent(x, y, b, down)
    if M.failMouseButtons then error('clic natif refuse') end
    M.mouseEvents=M.mouseEvents or {};M.mouseEvents[#M.mouseEvents+1]={x=x,y=y,down=down,at=M.clock}
    M.mouseX, M.mouseY = x, y
    if down then
        M.mouseDownAt = M.clock
        if atmGui.Enabled and inside(M.depBtn, x, y) then M.slider.Visible = true; M.confirmBtn.Visible = true end
        if atmGui.Enabled and inside(M.slider, x, y) then M.sliderGrab = true end
        if atmGui.Enabled and inside(M.confirmBtn, x, y) and M.sliderMax then
            M.bank = (M.bank or 0) + M.cash; M.cash = 0; M.cashLabel.Text = 'Cash: $0'; atmGui.Enabled = false
        end
        if M.sellBtn.Visible and inside(M.sellBtn, x, y) then M.sellHoldStart = M.clock end
    else
        if M.sliderGrab and x >= M.slider.AbsolutePosition.X + M.slider.AbsoluteSize.X - 3 then M.sliderMax = true end
        M.sliderGrab = false
        if M.sellHoldStart and M.clock - M.sellHoldStart >= 3 then
            M.capLabel.Text = '3/18'; M.sellBtn.Visible = false
            if M.saleRevenue then
                M.cash = M.cash + M.saleRevenue; M.cashLabel.Text = 'Cash: $' .. M.cash
            end
        end
        M.sellHoldStart = nil
    end
end
local function nearPrompt(pr, d)
    local p = pr.Parent.Position
    return (p - root.Position).Magnitude < (d or 10)
end
function M.onE()
    if M.vendorPrompt and nearPrompt(M.vendorPrompt) then M.sellBtn.Visible = true end
    if M.atmPrompt and nearPrompt(M.atmPrompt) then atmGui.Enabled = true end
end
fireproximityprompt = function(pr)
    if not nearPrompt(pr, 12) then return end
    if pr == M.drivePrompt then sitIn(seat) return end
    if pr == M.vendorPrompt then M.sellBtn.Visible = true end
    if pr == M.atmPrompt then atmGui.Enabled = true end
end
M.cash = 500
local Http = {}
function Http:JSONEncode(t) return py_json_encode(t) end
function Http:JSONDecode(s) return py_json_decode(s) end
function Http:GetAsync(url)
    M.httpCalls=(M.httpCalls or 0)+1;M.lastHttpUrl=url
    if M.httpDelay then task.wait(M.httpDelay) end
    if M.httpResponse then return M.httpResponse end
    error('HTTP indisponible dans la maquette par defaut')
end
function Http:UrlEncode(s) return (s:gsub('[^%w%-_%.~]',function(c) return string.format('%%%02X',string.byte(c)) end)) end
M.Http=Http
local Path = {}
function Path:CreatePath()
    local p = { Status = Enum.PathStatus.Success }
    function p:ComputeAsync(a, b) p.a, p.b = a, b end
    function p:GetWaypoints() return { { Position = p.a, Action = Enum.PathWaypointAction.Walk }, { Position = p.b, Action = Enum.PathWaypointAction.Walk } } end
    return p
end
TweenInfo = { new = function(...) return { ... } end }
ColorSequence = { new = function(...) return { ... } end }
ColorSequenceKeypoint={new=function(t,c) return {Time=t,Value=c} end}
NumberSequence={new=function(...) return {...} end}
NumberSequenceKeypoint={new=function(t,v) return {Time=t,Value=v} end}
local TweenService = {}
function TweenService:Create(o, info, props) M.tweenCount=(M.tweenCount or 0)+1
    local tween={Completed=Signal(),PlaybackState=Enum.PlaybackState.Begin,cancelled=false}
    function tween:Play()
        self.PlaybackState=Enum.PlaybackState.Playing
        local function finish()
            if self.cancelled then return end
            for k,v in pairs(props) do o[k]=v end
            self.PlaybackState=Enum.PlaybackState.Completed;self.Completed:Fire(self.PlaybackState)
        end
        if M.deferTweens then task.delay(info[1] or 0.2,finish) else finish() end
    end
    function tween:Cancel()
        M.tweenCancels=(M.tweenCancels or 0)+1;self.cancelled=true
        self.PlaybackState=Enum.PlaybackState.Cancelled;self.Completed:Fire(self.PlaybackState)
    end
    return tween end
local GuiService={GetGuiInset=function() return Vector2.new(0,36),Vector2.new(0,0) end}
local services = { GuiService=GuiService, TweenService = TweenService, Players = Players, RunService = RunService, UserInputService = UIS, VirtualInputManager = VIM, HttpService = Http, PathfindingService = Path }
services.TeleportService={TeleportToPlaceInstance=function(_,place,job,p) M.teleport={place=place,job=job,player=p};if M.teleportError then error(M.teleportError) end end}
game = DataModel
game.JobId='mock-job-123';game.PlaceId=104715542330896
function DataModel:GetService(n) return services[n] or error('service inconnu ' .. n) end
M.RunService, M.UIS = RunService, UIS

writefile = function(n, s) M.fs[n] = s; M.writes = M.writes + 1 end
readfile = function(n) return M.fs[n] or error('fichier absent ' .. n) end
isfile = function(n) return M.fs[n] ~= nil end
local G = {}
getgenv = function() return G end
M.genv = G

-- Ordonnanceur task.* ------------------------------------------------------
local function resume(co, ...)
    local ok, err = coroutine.resume(co, ...)
    if not ok then M.taskErrors = (M.taskErrors or 0) + 1; M.lastTaskError = tostring(err); print('ERREUR TACHE : ' .. tostring(err)) end
end
task = {
    spawn = function(fn, ...) local co = coroutine.create(fn); resume(co, ...); return co end,
    wait = function(t)
        local co, main = coroutine.running()
        if main then error('task.wait hors coroutine (bloquerait le thread principal)') end
        table.insert(M.tasks, { co = co, wake = M.clock + (t or 0.03) })
        coroutine.yield()
        return t
    end,
    delay = function(t, fn) task.spawn(function() task.wait(t); fn() end) end,
}

function M.tick(dt)
    M.clock = M.clock + dt
    if M.pendingMouse then M.mouseX,M.mouseY=M.pendingMouse[1],M.pendingMouse[2];M.pendingMouse=nil;M.mouseProcessedAt=M.clock end
    -- physique
    if hum.SeatPart == seat and M.car then
        M.car:step(dt, { fwd = M.keys.W, back = M.keys.S, left = M.keys.A, right = M.keys.D })
        M.syncSeat()
        M.setRoot(seat.Position + Vector3.new(0, 1, 0))
        if hum.Jump then hum.SeatPart = nil; hum.Sit = false; hum.Jump = false; M.setRoot(seat.Position + seat.CFrame.RightVector * -4) end
    elseif M.car then
        M.car:step(dt, {}); M.syncSeat()
        hum.Jump = false
        if M.moveTarget then
            local d = M.moveTarget - root.Position
            local flatd = Vector3.new(d.X, 0, d.Z)
            local step = 16 * dt
            if flatd.Magnitude <= step then M.setRoot(Vector3.new(M.moveTarget.X, root.Position.Y, M.moveTarget.Z))
            else M.setRoot(root.Position + flatd.Unit * step) end
        end
    end
    RunService.Heartbeat:Fire(dt)
    RunService.RenderStepped:Fire(dt)
    local due, keep = {}, {}
    for _, t in ipairs(M.tasks) do if t.wake <= M.clock then due[#due + 1] = t else keep[#keep + 1] = t end end
    M.tasks = keep
    for _, t in ipairs(due) do resume(t.co) end
end
function M.run(seconds, dt, untilFn)
    dt = dt or 0.02
    local t1 = M.clock + seconds
    while M.clock < t1 do
        M.tick(dt)
        if untilFn and untilFn() then return true end
    end
    return false
end
function M.press(code) UIS.InputBegan:Fire({ KeyCode = Enum.KeyCode[code], UserInputType = Enum.UserInputType.Keyboard }, false) end
function M.ourGui() return pg:FindFirstChild('BlockSpinCycle080') end
function M.findButton(prefix)
    local g = M.ourGui(); if not g then return nil end
    for _, o in ipairs(g:GetDescendants()) do
        if o.ClassName == 'TextButton' and type(o.Text) == 'string' and o.Text:sub(1, #prefix) == prefix then return o end
    end
end
function M.click(prefix)
    local b = M.findButton(prefix)
    if not b then error('bouton introuvable : ' .. prefix) end
    b.Activated:Fire()
    return b
end
function M.clickNamed(name)
    local b = M.ourGui():FindFirstChild(name, true)
    if not b then error('introuvable : ' .. name) end
    b.Activated:Fire()
end
function M.findTextBox(placeholderPrefix)
    for _, o in ipairs(M.ourGui():GetDescendants()) do
        if o.ClassName == 'TextBox' and tostring(o.PlaceholderText):sub(1, #placeholderPrefix) == placeholderPrefix then return o end
    end
end
function M.heldKeys() local o = {}; for k in pairs(M.keys) do o[#o + 1] = k end; table.sort(o); return table.concat(o, ',') end
return M
