-- BlockSpin Private Hub: prototype client, aucune integration de jeu verifiee.
local VERSION = "0.2.0"
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
local preferences = {accent = "A0A0A0", hotkey = "RightShift", metrics = true, overlay = false}
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
if storage then
    local ok, result = pcall(function()
        if not isfile(configPath) then return nil end
        local raw = readfile(configPath)
        assert(type(raw) == "string" and #raw <= 8192, "Fichier de reglages trop grand")
        local data = Http:JSONDecode(raw)
        assert(type(data) == "table" and data.schema == 1, "Format de reglages invalide")
        assert(type(data.accent) == "string" and data.accent:match("^%x%x%x%x%x%x$"), "Accent invalide")
        assert(validKey(data.hotkey), "Raccourci invalide")
        assert(type(data.metrics) == "boolean" and type(data.overlay) == "boolean", "Visibilite invalide")
        for _, field in ipairs({"position", "size", "overlayPosition"}) do
            assert(data[field] == nil or validPoint(data[field]), "Geometrie invalide")
        end
        return data
    end)
    if ok and result then preferences = result
    elseif not ok then
        storage = false
        storageStatus = "Lecture impossible : fichier preserve, sauvegarde desactivee"
        report(result)
    end
end
local function saveSettings()
    if not storage then return end
    local ok, err = pcall(function()
        preferences.schema = 1
        writefile(configPath, Http:JSONEncode(preferences))
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
local function fitWindow()
    local v = viewport.AbsoluteSize
    local w = math.clamp(window.Size.X.Offset, math.min(360, v.X), math.max(1, v.X))
    local h = math.clamp(window.Size.Y.Offset, math.min(340, v.Y), math.max(1, v.Y))
    window.Size = UDim2.fromOffset(w, h)
    window.Position = UDim2.fromOffset(math.clamp(window.Position.X.Offset, 0, math.max(0, v.X - w)),
        math.clamp(window.Position.Y.Offset, 0, math.max(0, v.Y - h)))
end
local initialSize = preferences.size or {x = math.min(700, viewport.AbsoluteSize.X * 0.9),
    y = math.min(580, viewport.AbsoluteSize.Y * 0.85)}
local initialPosition = preferences.position or {x = (viewport.AbsoluteSize.X - initialSize.x) / 2,
    y = (viewport.AbsoluteSize.Y - initialSize.y) / 2}
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
        window.Size = UDim2.fromOffset(gesture.size.X + dx, gesture.size.Y + dy)
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
    if showMetrics or preferences.overlay then
        local ok, ping = pcall(function() return player:GetNetworkPing() end)
        local pingText = "N/D"
        if ok and type(ping) == "number" and ping >= 0 and ping < math.huge then
            pingText = string.format("%.0f ms", ping * 1000)
        end
        metrics.Text = string.format("  FPS : %.0f | Ping API : %s", frames / elapsed, pingText)
        overlay.Text = metrics.Text
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
