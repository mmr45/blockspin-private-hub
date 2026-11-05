-- BlockSpin Private Hub: prototype client, aucune integration de jeu verifiee.
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
local connections = {}
local function connect(signal, callback)
    local connection = signal:Connect(callback)
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
make("UISizeConstraint", {MaxSize = Vector2.new(700, 580)}, window)
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
local title = label(window, "  BLOCKSPIN | PRIVATE HUB - PROTOTYPE", 42)
local metrics = label(window, "  FPS : -- | Ping reseau : N/D", 30)
metrics.Position = UDim2.fromOffset(0, 42)
local status = label(window, "  Pret. RightShift : masquer / afficher.", 54)
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
label(settings, "Theme Full Black. Reglages conserves pour cette session.", 50)
local accent = textbox(settings, "Accent hexadecimal : #RRGGBB")
button(settings, "Appliquer la couleur d'accent", function()
    local hex = string.match(accent.Text, "^#?(%x%x%x%x%x%x)$")
    if not hex then status.Text = "Couleur invalide. Exemple : #A0A0A0"; return end
    local color = Color3.fromRGB(tonumber(hex:sub(1, 2), 16),
        tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16))
    title.TextColor3 = color
    for _, item in pairs(tabButtons) do item.TextColor3 = color end
    status.Text = "Accent applique."
end)
local showMetrics = true
local metricButton
metricButton = button(settings, "FPS / ping : affiches", function()
    showMetrics = not showMetrics
    metrics.Visible = showMetrics
    metricButton.Text = showMetrics and "FPS / ping : affiches" or "FPS / ping : masques"
end)
button(settings, "Fermer le menu et arreter les mesures", function() gui:Destroy() end)
pages.Fishing.Visible = true
connect(Input.InputBegan, function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.RightShift then
        window.Visible = not window.Visible
    end
end)
local frames, elapsed = 0, 0
connect(RunService.RenderStepped, function(dt)
    frames = frames + 1
    elapsed = elapsed + dt
    if elapsed < 1 then return end
    if showMetrics then
        local ok, ping = pcall(function() return player:GetNetworkPing() end)
        local pingText = "N/D"
        if ok and type(ping) == "number" and ping >= 0 and ping < math.huge then
            pingText = string.format("%.0f ms", ping * 1000)
        end
        metrics.Text = string.format("  FPS : %.0f | Ping API : %s", frames / elapsed, pingText)
    end
    frames, elapsed = 0, 0
end)
gui.Destroying:Connect(function()
    for _, connection in ipairs(connections) do connection:Disconnect() end
    for _, connection in ipairs(seedConnections) do connection:Disconnect() end
end)
