-- BlockSpin Private Hub: prototype client, aucune integration de jeu verifiee.
local VERSION = "0.3.0"
local Http = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local player = assert(Players.LocalPlayer, "Executer cote client")
local playerGui = assert(player:WaitForChild("PlayerGui", 10), "PlayerGui indisponible")
local old = playerGui:FindFirstChild("BlockSpinPrototype")
if old then old:Destroy() end

-- Points d'integration intentionnellement fermes. Aucun RemoteEvent devine.
local function unavailable(feature)
    return feature .. " : integration BlockSpin non verifiee. Aucune action envoyee."
end
local function defaults()
    return {accent = "A0A0A0", hotkey = "RightShift", metrics = true, overlay = false,
        scale = 1, overlayMode = "both", graph = false}
end
local preferences = defaults()
local profiles = {}
local configPath = "blockspin-settings-v1.json"
local storage = type(readfile) == "function" and type(writefile) == "function" and type(isfile) == "function"
local storageStatus = storage and "Disponible" or "Indisponible : reglages de session uniquement"
local errors, diagnostic, status = {}, nil, nil
local function report(message)
    message = tostring(message)
    table.insert(errors, message:sub(1, 500))
    if #errors > 5 then table.remove(errors, 1) end
    if status then status.Text = "Erreur : " .. message:sub(1, 180) end
    if diagnostic then diagnostic.Text = table.concat(errors, "\n") end
    warn("BlockSpin " .. VERSION .. ": " .. message)
end
local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end
local function validKey(name)
    if type(name) ~= "string" then return false end
    local ok, key = pcall(function() return Enum.KeyCode[name] end)
    return ok and key ~= nil and key ~= Enum.KeyCode.Unknown and key ~= Enum.KeyCode.Escape
end
local function validPoint(point)
    return type(point) == "table" and finite(point.x) and finite(point.y)
end
local function validatePreferences(data)
    assert(type(data) == "table", "Reglages invalides")
    assert(type(data.accent) == "string" and data.accent:match("^%x%x%x%x%x%x$"), "Accent invalide")
    assert(validKey(data.hotkey), "Raccourci invalide")
    assert(type(data.metrics) == "boolean" and type(data.overlay) == "boolean", "Visibilite invalide")
    local result = {accent = data.accent, hotkey = data.hotkey, metrics = data.metrics, overlay = data.overlay,
        scale = data.scale, overlayMode = data.overlayMode, graph = data.graph}
    if result.scale == nil then result.scale = 1 end
    if result.overlayMode == nil then result.overlayMode = "both" end
    if result.graph == nil then result.graph = false end
    assert(finite(result.scale) and result.scale >= 0.75 and result.scale <= 1.5, "Echelle invalide")
    assert(result.overlayMode == "both" or result.overlayMode == "fps" or result.overlayMode == "ping", "Mode overlay invalide")
    assert(type(result.graph) == "boolean", "Graphique invalide")
    for _, field in ipairs({"position", "size", "overlayPosition"}) do
        assert(data[field] == nil or validPoint(data[field]), "Geometrie invalide")
        if data[field] then result[field] = {x = data[field].x, y = data[field].y} end
    end
    return result
end
local function validProfileName(name)
    if type(name) ~= "string" then return false end
    local length = utf8.len(name)
    return length ~= nil and length > 0 and length <= 32 and not name:find("%c")
end
if storage then
    local ok, result = pcall(function()
        if not isfile(configPath) then return nil end
        local raw = readfile(configPath)
        assert(type(raw) == "string" and #raw <= 32768, "Fichier de reglages trop grand")
        local data = Http:JSONDecode(raw)
        assert(type(data) == "table" and data.schema == 1, "Format de reglages invalide")
        local current = validatePreferences(data)
        local savedProfiles = data.profiles
        if savedProfiles == nil then savedProfiles = {} end
        assert(type(savedProfiles) == "table", "Profils invalides")
        local count, validated = 0, {}
        for name, profile in pairs(savedProfiles) do
            count = count + 1
            assert(count <= 10 and validProfileName(name), "Nom ou nombre de profils invalide")
            validated[name] = validatePreferences(profile)
        end
        return {current = current, profiles = validated}
    end)
    if ok and result then preferences, profiles = result.current, result.profiles
    elseif not ok then
        storage = false
        storageStatus = "Lecture impossible : fichier preserve, sauvegarde desactivee"
        report(result)
    end
end
local function saveSettings()
    if not storage then return end
    local ok, err = pcall(function()
        local data = validatePreferences(preferences)
        data.schema, data.profiles = 1, profiles
        writefile(configPath, Http:JSONEncode(data))
    end)
    storageStatus = ok and "Sauvegarde OK" or "Ecriture impossible"
    if not ok then report(err) end
end
local connections = {}
local function connect(signal, callback)
    local connection = signal:Connect(function(...)
        local ok, err = pcall(callback, ...)
        if not ok then report(err) end
    end)
    table.insert(connections, connection)
    return connection
end
local function make(class, properties, parent)
    local object = Instance.new(class)
    for key, value in pairs(properties) do object[key] = value end
    object.Parent = parent
    return object
end
local gui = make("ScreenGui", {Name = "BlockSpinPrototype", ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, playerGui)
local window = make("Frame", {Size = UDim2.new(0.9, 0, 0.85, 0),
    Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = Color3.fromRGB(5, 5, 5), BorderSizePixel = 0}, gui)
local viewport = make("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
    Active = false, Visible = false}, gui)
-- Attendre le premier calcul de disposition avant de restaurer la geometrie.
local layoutStart = os.clock()
while viewport.AbsoluteSize.X <= 0 or viewport.AbsoluteSize.Y <= 0 do
    assert(os.clock() - layoutStart < 10, "Dimensions de fenetre indisponibles")
    RunService.RenderStepped:Wait()
end
local menuScale = make("UIScale", {Scale = preferences.scale}, window)
local function fitWindow()
    local v = viewport.AbsoluteSize
    local w = math.clamp(window.Size.X.Offset, math.min(360, v.X / preferences.scale), math.max(1, v.X / preferences.scale))
    local h = math.clamp(window.Size.Y.Offset, math.min(340, v.Y / preferences.scale), math.max(1, v.Y / preferences.scale))
    window.Size = UDim2.fromOffset(w, h)
    window.Position = UDim2.fromOffset(math.clamp(window.Position.X.Offset, 0, math.max(0, v.X - w * preferences.scale)),
        math.clamp(window.Position.Y.Offset, 0, math.max(0, v.Y - h * preferences.scale)))
end
local initialSize = preferences.size or {x = math.min(700, viewport.AbsoluteSize.X * 0.9),
    y = math.min(580, viewport.AbsoluteSize.Y * 0.85)}
local initialPosition = preferences.position or {x = (viewport.AbsoluteSize.X - initialSize.x * preferences.scale) / 2,
    y = (viewport.AbsoluteSize.Y - initialSize.y * preferences.scale) / 2}
window.AnchorPoint = Vector2.new(0, 0)
window.Size = UDim2.fromOffset(initialSize.x, initialSize.y)
window.Position = UDim2.fromOffset(initialPosition.x, initialPosition.y)
fitWindow()
make("UICorner", {CornerRadius = UDim.new(0, 10)}, window)
local function label(parent, text, height)
    return make("TextLabel", {Size = UDim2.new(1, 0, 0, height or 36),
        BackgroundTransparency = 1, Text = text, TextWrapped = true,
        TextColor3 = Color3.fromRGB(235, 235, 235), TextSize = 15,
        Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left}, parent)
end
local function button(parent, text, callback)
    local item = make("TextButton", {Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = Color3.fromRGB(25, 25, 25), BorderSizePixel = 0,
        Text = text, TextColor3 = Color3.fromRGB(245, 245, 245), TextSize = 14,
        Font = Enum.Font.Gotham, TextWrapped = true}, parent)
    make("UICorner", {CornerRadius = UDim.new(0, 6)}, item)
    connect(item.Activated, callback)
    return item
end
local function textbox(parent, placeholder)
    return make("TextBox", {Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = Color3.fromRGB(20, 20, 20), BorderSizePixel = 0,
        Text = "", PlaceholderText = placeholder, ClearTextOnFocus = false,
        TextColor3 = Color3.fromRGB(245, 245, 245), TextSize = 14,
        Font = Enum.Font.Gotham}, parent)
end
local title = label(window, "  BLOCKSPIN | v" .. VERSION .. " | glisser ici", 42)
title.Active = true
local metrics = label(window, "  FPS : -- | Ping reseau : N/D", 30)
metrics.Position = UDim2.fromOffset(0, 42)
status = label(window, "  Pret. " .. preferences.hotkey .. " : masquer / afficher.", 54)
status.Position = UDim2.new(0, 0, 1, -54)
local tabs = make("Frame", {BackgroundTransparency = 1,
    Position = UDim2.fromOffset(12, 82), Size = UDim2.new(0, 130, 1, -148)}, window)
make("UIListLayout", {Padding = UDim.new(0, 8)}, tabs)
local pages = {}
local tabButtons = {}
local function page(name)
    local body = make("ScrollingFrame", {Name = name, BackgroundTransparency = 1,
        BorderSizePixel = 0, Position = UDim2.fromOffset(154, 82),
        Size = UDim2.new(1, -168, 1, -148), CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 5,
        Visible = false}, window)
    make("UIListLayout", {Padding = UDim.new(0, 8)}, body)
    make("UIPadding", {PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8)}, body)
    pages[name] = body
    tabButtons[name] = button(tabs, name, function()
        for key, item in pairs(pages) do item.Visible = key == name end
    end)
    return body
end
local fishing = page("Fishing")
label(fishing, "Appat, captures et Auto Fish : non verifies.", 50)
button(fishing, "Auto Fish / Auto Record : non verifies", function()
    status.Text = unavailable("Peche automatique et enregistrement")
end)
local spot = label(fishing, "Aucun repere joueur enregistre.", 60)
button(fishing, "Memoriser ma position joueur (session)", function()
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not root then status.Text = "Personnage indisponible."; return end
    local p = root.Position
    spot.Text = string.format("JOUEUR : X %.2f | Y %.2f | Z %.2f", p.X, p.Y, p.Z)
    status.Text = "Repere joueur uniquement. Ce n'est PAS la position de l'appat."
end)
local farming = page("Farming")
label(farming, "Actions non branchees. Graines saisies manuellement.", 50)
local selected = nil
local selection = label(farming, "Graine selectionnee : aucune", 36)
for _, action in ipairs({"Recolte", "Plantation", "Engrais", "Terre"}) do
    local actionName = action
    button(farming, actionName .. " : non verifie", function()
        status.Text = unavailable(actionName)
    end)
end
local names = textbox(farming, "Graines : nom1, nom2 (liste manuelle)")
local filter = textbox(farming, "Filtrer les noms (texte)")
local seedList = make("Frame", {BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y}, farming)
make("UIListLayout", {Padding = UDim.new(0, 6)}, seedList)
local seedConnections = {}
local function refreshSeeds()
    for _, connection in ipairs(seedConnections) do connection:Disconnect() end
    seedConnections = {}
    for _, item in ipairs(seedList:GetChildren()) do
        if item:IsA("TextButton") then item:Destroy() end
    end
    local seen, validSelection = {}, false
    local query = string.lower(filter.Text)
    for raw in string.gmatch(names.Text, "[^,]+") do
        local name = string.match(raw, "^%s*(.-)%s*$")
        if name ~= "" and not seen[name] then
            seen[name] = true
            if selected == name then validSelection = true end
            if string.find(string.lower(name), query, 1, true) then
                local seed = name
                -- Connexions gerees a part : la liste est reconstruite pendant la saisie.
                local item = make("TextButton", {Size = UDim2.new(1, 0, 0, 32),
                    BackgroundColor3 = Color3.fromRGB(25, 25, 25), Text = seed,
                    TextColor3 = Color3.fromRGB(245, 245, 245), TextSize = 14,
                    Font = Enum.Font.Gotham}, seedList)
                table.insert(seedConnections, item.Activated:Connect(function()
                    selected = seed
                    selection.Text = "Graine selectionnee : " .. seed
                end))
            end
        end
    end
    if not validSelection then
        selected = nil
        selection.Text = "Graine selectionnee : aucune"
    end
end
connect(names:GetPropertyChangedSignal("Text"), refreshSeeds)
connect(filter:GetPropertyChangedSignal("Text"), refreshSeeds)
local index = page("Fish Index")
label(index, "Catalogue vide : aucune espece BlockSpin verifiee.", 60)
label(index, "Aucune capture detectee. Aucun poisson fictif ajoute.", 60)
local settings = page("Settings")
label(settings, "Reglages locaux. Aucun repere sauvegarde.", 50)
local accent = textbox(settings, "Accent hexadecimal : #RRGGBB")
accent.Text = preferences.accent
local function applyAccent(hex)
    local color = Color3.fromRGB(tonumber(hex:sub(1, 2), 16),
        tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16))
    title.TextColor3 = color
    for _, item in pairs(tabButtons) do item.TextColor3 = color end
end
applyAccent(preferences.accent)
button(settings, "Appliquer la couleur d'accent", function()
    local hex = string.match(accent.Text, "^#?(%x%x%x%x%x%x)$")
    if not hex then status.Text = "Couleur invalide. Exemple : #A0A0A0"; return end
    preferences.accent = hex
    applyAccent(hex)
    status.Text = "Accent applique."
    saveSettings()
end)
local showMetrics = preferences.metrics
metrics.Visible = showMetrics
local metricButton
metricButton = button(settings, showMetrics and "FPS / ping : affiches" or "FPS / ping : masques", function()
    showMetrics = not showMetrics
    preferences.metrics = showMetrics
    metrics.Visible = showMetrics
    metricButton.Text = showMetrics and "FPS / ping : affiches" or "FPS / ping : masques"
    saveSettings()
end)
local overlay = label(gui, "  FPS : -- | Ping : N/D", 36)
overlay.Name = "PerformanceOverlay"
overlay.Size = UDim2.fromOffset(270, 36)
overlay.BackgroundTransparency = 0.15
overlay.BackgroundColor3 = Color3.fromRGB(5, 5, 5)
overlay.Active = true
overlay.ZIndex = 10
overlay.Visible = preferences.overlay
local op = preferences.overlayPosition or {x = 12, y = 12}
overlay.Position = UDim2.fromOffset(op.x, op.y)
local function fitOverlay()
    local v = viewport.AbsoluteSize
    overlay.Size = UDim2.fromOffset(math.min(270, v.X), math.min(36, v.Y))
    overlay.Position = UDim2.fromOffset(math.clamp(overlay.Position.X.Offset, 0, math.max(0, v.X - overlay.Size.X.Offset)),
        math.clamp(overlay.Position.Y.Offset, 0, math.max(0, v.Y - overlay.Size.Y.Offset)))
end
fitOverlay()
local overlayButton
local function overlayText() return preferences.overlay and "Overlay FPS / ping : actif" or "Overlay FPS / ping : inactif" end
overlayButton = button(settings, overlayText(), function()
    preferences.overlay = not preferences.overlay
    overlay.Visible = preferences.overlay
    overlayButton.Text = overlayText()
    saveSettings()
end)
local capturing = false
local hotkeyButton
local function keyText() return "Raccourci : " .. preferences.hotkey .. " (modifier)" end
hotkeyButton = button(settings, keyText(), function()
    capturing = true
    hotkeyButton.Text = "Appuyer sur une touche (Echap : annuler)"
end)
local resize = make("TextButton", {Text = "<>" , TextSize = 16,
    TextColor3 = Color3.fromRGB(255, 255, 255), BackgroundColor3 = Color3.fromRGB(35, 35, 35),
    Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -28, 1, -28), ZIndex = 5}, window)
local gesture = nil
local function beginGesture(mode, input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
    gesture = {mode = mode, input = input, start = input.Position,
        position = (mode == "overlay" and overlay or window).Position, size = Vector2.new(window.Size.X.Offset, window.Size.Y.Offset)}
end
connect(title.InputBegan, function(input) beginGesture("move", input) end)
connect(resize.InputBegan, function(input) beginGesture("resize", input) end)
connect(overlay.InputBegan, function(input) beginGesture("overlay", input) end)
local function rememberGeometry()
    preferences.position = {x = window.Position.X.Offset, y = window.Position.Y.Offset}
    preferences.size = {x = window.Size.X.Offset, y = window.Size.Y.Offset}
    preferences.overlayPosition = {x = overlay.Position.X.Offset, y = overlay.Position.Y.Offset}
end
connect(Input.InputChanged, function(input)
    if not gesture then return end
    if gesture.input.UserInputType == Enum.UserInputType.Touch then
        if input ~= gesture.input then return end
    elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
    local dx, dy = input.Position.X - gesture.start.X, input.Position.Y - gesture.start.Y
    if gesture.mode == "resize" then
        window.Size = UDim2.fromOffset(gesture.size.X + dx / preferences.scale, gesture.size.Y + dy / preferences.scale)
        fitWindow()
    else
        local target = gesture.mode == "overlay" and overlay or window
        target.Position = UDim2.fromOffset(gesture.position.X.Offset + dx, gesture.position.Y.Offset + dy)
        if target == window then fitWindow() else fitOverlay() end
    end
end)
connect(Input.InputEnded, function(input)
    if gesture and (input == gesture.input or
        (gesture.input.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1)) then
        gesture = nil
        rememberGeometry()
        saveSettings()
    end
end)
connect(Input.WindowFocusReleased, function() gesture = nil end)
connect(viewport:GetPropertyChangedSignal("AbsoluteSize"), function()
    fitWindow()
    fitOverlay()
end)
local scaleInput = textbox(settings, "Echelle du menu : 75 a 150 (%)")
scaleInput.Text = tostring(math.floor(preferences.scale * 100 + 0.5))
button(settings, "Appliquer l'echelle du menu", function()
    local percent = tonumber(scaleInput.Text)
    if not finite(percent) or percent < 75 or percent > 150 then
        status.Text = "Echelle invalide : choisir 75 a 150 %."; return
    end
    preferences.scale = percent / 100
    menuScale.Scale = preferences.scale
    fitWindow()
    rememberGeometry()
    saveSettings()
end)
local modeNames = {both = "FPS + ping", fps = "FPS seuls", ping = "Ping seul"}
local modeButton
local function modeText() return "Mesures overlay : " .. modeNames[preferences.overlayMode] end
modeButton = button(settings, modeText(), function()
    local modes = {both = "fps", fps = "ping", ping = "both"}
    preferences.overlayMode = modes[preferences.overlayMode]
    modeButton.Text = modeText()
    overlay.Text = "  Actualisation..."
    saveSettings()
end)
local graphButton
local function graphText() return preferences.graph and "Graphique : actif" or "Graphique : inactif" end
local charts = {}
local history = {}
local function chart(name, color)
    local caption = label(settings, name .. " : en attente", 36)
    local plot = make("Frame", {Size = UDim2.new(1, 0, 0, 60), BorderSizePixel = 0,
        BackgroundColor3 = Color3.fromRGB(20, 20, 20)}, settings)
    local bars = {}
    for i = 1, 30 do
        bars[i] = make("Frame", {Name = name .. "Sample" .. i, BorderSizePixel = 0,
            BackgroundColor3 = color, AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new((i - 1) / 30, 0, 1, 0), Size = UDim2.new(1 / 30, -1, 0, 0)}, plot)
    end
    return {caption = caption, plot = plot, bars = bars, name = name}
end
local function graphVisibility()
    for _, item in ipairs(charts) do
        item.caption.Visible, item.plot.Visible = preferences.graph, preferences.graph
    end
end
graphButton = button(settings, graphText(), function()
    preferences.graph = not preferences.graph
    graphButton.Text = graphText()
    graphVisibility()
    saveSettings()
end)
charts[1] = chart("FPS", Color3.fromRGB(70, 200, 255))
charts[2] = chart("Ping", Color3.fromRGB(255, 190, 70))
graphVisibility()
local function updateCharts(fps, ping)
    table.insert(history, {fps = fps, ping = ping})
    if #history > 30 then table.remove(history, 1) end
    if not preferences.graph then return end
    for index, item in ipairs(charts) do
        local field = index == 1 and "fps" or "ping"
        local maximum = 1
        for _, sample in ipairs(history) do maximum = math.max(maximum, sample[field] or 0) end
        item.caption.Text = string.format("%s : 30 dernieres mesures | haut : %.0f%s", item.name,
            maximum, index == 1 and " FPS" or " ms")
        for i, bar in ipairs(item.bars) do
            local sample = history[i - (30 - #history)]
            local value = sample and sample[field]
            bar.Size = UDim2.new(1 / 30, -1, value and value / maximum or 0, 0)
        end
    end
end
local function applyPreferences()
    gesture, capturing = nil, false
    menuScale.Scale = preferences.scale
    accent.Text = preferences.accent
    applyAccent(preferences.accent)
    showMetrics, metrics.Visible = preferences.metrics, preferences.metrics
    metricButton.Text = showMetrics and "FPS / ping : affiches" or "FPS / ping : masques"
    overlay.Visible, overlayButton.Text = preferences.overlay, overlayText()
    overlay.Text = "  Actualisation..."
    hotkeyButton.Text, modeButton.Text, graphButton.Text = keyText(), modeText(), graphText()
    scaleInput.Text = tostring(math.floor(preferences.scale * 100 + 0.5))
    graphVisibility()
    local size = preferences.size or {x = 700, y = 580}
    window.Size = UDim2.fromOffset(size.x, size.y)
    local position = preferences.position or {x = (viewport.AbsoluteSize.X - size.x * preferences.scale) / 2,
        y = (viewport.AbsoluteSize.Y - size.y * preferences.scale) / 2}
    window.Position = UDim2.fromOffset(position.x, position.y)
    local point = preferences.overlayPosition or {x = 12, y = 12}
    overlay.Position = UDim2.fromOffset(point.x, point.y)
    fitWindow()
    fitOverlay()
end
button(settings, "Recentrer le menu et l'overlay", function()
    gesture = nil
    fitWindow()
    local v = viewport.AbsoluteSize
    window.Position = UDim2.fromOffset((v.X - window.Size.X.Offset * preferences.scale) / 2,
        (v.Y - window.Size.Y.Offset * preferences.scale) / 2)
    overlay.Position = UDim2.fromOffset((v.X - overlay.Size.X.Offset) / 2, 12)
    fitOverlay()
    rememberGeometry()
    saveSettings()
end)
local profileInput = textbox(settings, "Nom du profil (32 caracteres maximum)")
local profileList = label(settings, "", 0)
profileList.AutomaticSize = Enum.AutomaticSize.Y
local function refreshProfiles()
    local names = {}
    for name in pairs(profiles) do table.insert(names, name) end
    table.sort(names)
    profileList.Text = #names == 0 and "Aucun profil enregistre." or "Profils : " .. table.concat(names, ", ")
end
local function profileName()
    local name = profileInput.Text:match("^%s*(.-)%s*$")
    if not validProfileName(name) then status.Text = "Nom invalide : 1 a 32 caracteres, sans controle."; return nil end
    return name
end
button(settings, "Enregistrer / remplacer le profil", function()
    local name = profileName()
    if not name then return end
    local count = 0
    for _ in pairs(profiles) do count = count + 1 end
    if not profiles[name] and count >= 10 then status.Text = "Limite : 10 profils."; return end
    rememberGeometry()
    profiles[name] = validatePreferences(preferences)
    refreshProfiles()
    status.Text = "Profil enregistre : " .. name
    saveSettings()
end)
button(settings, "Charger le profil", function()
    local name = profileName()
    if not name then return end
    if not profiles[name] then status.Text = "Profil introuvable."; return end
    preferences = validatePreferences(profiles[name])
    applyPreferences()
    status.Text = "Profil charge : " .. name
    saveSettings()
end)
button(settings, "Supprimer le profil", function()
    local name = profileName()
    if not name then return end
    if not profiles[name] then status.Text = "Profil introuvable."; return end
    profiles[name] = nil
    refreshProfiles()
    status.Text = "Profil supprime : " .. name
    saveSettings()
end)
refreshProfiles()
button(settings, "Reinitialiser les reglages (garder les profils)", function()
    preferences = defaults()
    applyPreferences()
    status.Text = "Reglages reinitialises. Raccourci : RightShift. Profils conserves."
    rememberGeometry()
    saveSettings()
end)
local diagnosticInfo = label(settings, "", 100)
diagnostic = label(settings, #errors > 0 and table.concat(errors, "\n") or "Aucune erreur capturee.", 130)
local function refreshDiagnostic()
    diagnosticInfo.Text = "BlockSpin v" .. VERSION .. " | Roblox client\nFichiers : " .. storageStatus ..
        "\nRaccourci : " .. preferences.hotkey .. " | Overlay : " .. tostring(preferences.overlay) ..
        "\nCompatibilite Xeno : non certifiee"
end
button(settings, "Actualiser le diagnostic", refreshDiagnostic)
button(settings, "Tester la capture d'erreur", function() error("Test volontaire du diagnostic") end)
refreshDiagnostic()
button(settings, "Tout arreter et fermer", function() gui:Destroy() end)
pages.Fishing.Visible = true
connect(Input.InputBegan, function(input, processed)
    if input.UserInputType ~= Enum.UserInputType.Keyboard or Input:GetFocusedTextBox() then return end
    if capturing then
        if input.KeyCode == Enum.KeyCode.Escape then
            capturing = false
        elseif validKey(input.KeyCode.Name) then
            preferences.hotkey = input.KeyCode.Name
            capturing = false
            saveSettings()
        end
        hotkeyButton.Text = capturing and "Choisir une touche clavier" or keyText()
        status.Text = "Raccourci : " .. preferences.hotkey
        return
    end
    if not processed and input.KeyCode == Enum.KeyCode[preferences.hotkey] then
        window.Visible = not window.Visible
        gesture = nil
    end
end)
local frames, elapsed = 0, 0
connect(RunService.RenderStepped, function(dt)
    frames = frames + 1
    elapsed = elapsed + dt
    if elapsed < 1 then return end
    if showMetrics or preferences.overlay or preferences.graph then
        local ok, ping = pcall(function() return player:GetNetworkPing() end)
        local pingText = "N/D"
        if ok and type(ping) == "number" and ping >= 0 and ping < math.huge then
            pingText = string.format("%.0f ms", ping * 1000)
        end
        metrics.Text = string.format("  FPS : %.0f | Ping API : %s", frames / elapsed, pingText)
        local fps = frames / elapsed
        if preferences.overlayMode == "fps" then overlay.Text = string.format("  FPS : %.0f", fps)
        elseif preferences.overlayMode == "ping" then overlay.Text = "  Ping API : " .. pingText
        else overlay.Text = metrics.Text end
        local validPing = ok and finite(ping) and ping >= 0 and ping * 1000 or nil
        updateCharts(fps, validPing)
    end
    frames, elapsed = 0, 0
end)
gui.Destroying:Connect(function()
    gesture = nil
    rememberGeometry()
    saveSettings()
    for _, connection in ipairs(connections) do connection:Disconnect() end
    for _, connection in ipairs(seedConnections) do connection:Disconnect() end
end)
