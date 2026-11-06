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
    Farming='Culture & parcelles',Statistics='Tableau de bord',Settings='Votre espace, vos réglages'}
local descriptions={Fishing='Vos spots. Votre rythme. Tout au même endroit.',Vehicle='Enregistrez vos trajets et retrouvez vos destinations.',
    Money='Un regard clair sur les montants réellement observés.',Farming='Préparez vos cultures et suivez vos parcelles.',
    Statistics='L’activité et les chiffres de votre session.',Settings='Personnalisez chaque détail du hub.'}
local defaults={Fishing='Automatisation',Vehicle='Conduite',Money='Votre argent',Farming='Vos cultures',Statistics='Vue d’ensemble',Settings='Personnalisation'}
function D.newCard(page, title)
    local meta=D.pages[page]
    local card=make('Frame',{Name='Card',BackgroundColor3=theme.surface,BorderSizePixel=0,
        Size=UDim2.new(1,0,0,80),ClipsDescendants=true},meta.columns)
    corner(card,10);stroke(card)
    make('UIPadding',{PaddingTop=UDim.new(0,16),PaddingBottom=UDim.new(0,16),PaddingLeft=UDim.new(0,16),PaddingRight=UDim.new(0,16)},card)
    make('UIListLayout',{Padding=UDim.new(0,9),SortOrder=Enum.SortOrder.LayoutOrder},card)
    local heading=text(card,title,14,theme.text); heading.Name='CardTitle';heading.Font=Enum.Font.GothamBold
    heading.Size=UDim2.new(1,0,0,24);heading.LayoutOrder=0
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
    local keys={'INVENTAIRE','APPÂTS','SESSION'}
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
    local changed=D.active~=active;D.active=active
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
    local row={button=b}
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
        if not ui.animations then window.Visible=false
        else task.delay(0.18,function()
            if S.running and token==D.visibilityToken and not D.menuVisible then window.Visible=false end
        end) end
    end
end
S.setMenuVisible=D.showMenu
function D.createChrome()
    D.sidebar=make('Frame',{Name='Sidebar',Size=UDim2.new(0,196,1,0),BackgroundColor3=color(12,13,16),BorderSizePixel=0},window)
    D.sidebarDivider=line(D.sidebar,195,0,1,640,theme.border);D.sidebarDivider.Size=UDim2.new(0,1,1,0)
    local brand=make('Frame',{Name='Brand',BackgroundTransparency=1,Position=UDim2.fromOffset(20,26),Size=UDim2.fromOffset(156,42)},D.sidebar)
    local badge=make('Frame',{BackgroundColor3=tint(theme.accent,14),Size=UDim2.fromOffset(34,34),BorderSizePixel=0},brand);corner(badge,9);D.bind(badge,'BackgroundColor3',function(c) return tint(c,14) end)
    local monogram=text(badge,'B',22,theme.accent);monogram.Font=Enum.Font.GothamBold;monogram.Size=UDim2.fromScale(1,1);monogram.TextXAlignment=Enum.TextXAlignment.Center;D.bind(monogram,'TextColor3')
    D.brandTitle=text(brand,'BLOCKSPIN',13,theme.text);D.brandTitle.Font=Enum.Font.GothamBold;D.brandTitle.Position=UDim2.fromOffset(44,-1);D.brandTitle.Size=UDim2.fromOffset(118,22)
    D.brandCaption=text(brand,'PRIVATE / BLACK EDITION',8,theme.muted);D.brandCaption.Position=UDim2.fromOffset(44,19);D.brandCaption.Size=UDim2.fromOffset(128,16)
    D.navCaption=text(D.sidebar,'WORKSPACE',9,color(96,99,112));D.navCaption.Position=UDim2.fromOffset(26,94);D.navCaption.Size=UDim2.new(1,-40,0,20)
    D.nav=make('ScrollingFrame',{Name='Navigation',BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(0,126),Size=UDim2.new(1,0,1,-252),
        CanvasSize=UDim2.fromOffset(0,336),ScrollBarThickness=0,ScrollingDirection=Enum.ScrollingDirection.Y},D.sidebar)
    D.profile=make('Frame',{Name='RobloxProfile',Position=UDim2.new(0,12,1,-84),Size=UDim2.new(1,-24,0,68),BackgroundColor3=color(20,21,26),BorderSizePixel=0},D.sidebar)
    corner(D.profile,9);stroke(D.profile)
    local avatarHolder=make('Frame',{Name='AvatarHolder',BackgroundColor3=color(35,37,44),Size=UDim2.fromOffset(38,38),Position=UDim2.fromOffset(10,15),ClipsDescendants=true,BorderSizePixel=0},D.profile);corner(avatarHolder,12)
    local fallback=text(avatarHolder,'?',18,theme.muted);fallback.Name='AvatarPlaceholder';fallback.Size=UDim2.fromScale(1,1);fallback.TextXAlignment=Enum.TextXAlignment.Center
    local avatar=make('ImageLabel',{Name='RobloxAvatar',Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Image='',Visible=false,ScaleType=Enum.ScaleType.Crop},avatarHolder);corner(avatar,12)
    local name=type(player.DisplayName)=='string' and player.DisplayName~='' and player.DisplayName or player.Name
    D.displayName=text(D.profile,tostring(name or 'Joueur Roblox'),12,theme.text);D.displayName.Name='DisplayName';D.displayName.Font=Enum.Font.GothamMedium;D.displayName.Position=UDim2.fromOffset(58,14);D.displayName.Size=UDim2.new(1,-64,0,20)
    D.username=text(D.profile,'@'..tostring(player.Name or 'Roblox'),10,theme.muted);D.username.Name='Username';D.username.Position=UDim2.fromOffset(58,35);D.username.Size=UDim2.new(1,-64,0,18)
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
    D.launcher=make('TextButton',{Name='OpenHub',Text='B',Font=Enum.Font.GothamBold,TextSize=22,TextColor3=theme.accent,Visible=false,
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
    D.profile.Position=UDim2.new(0,compact and 8 or 12,1,-84);D.profile.Size=UDim2.new(1,compact and -16 or -24,0,68)
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
    local twoColumns=w-side-40>=600
    for page,meta in pairs(D.pages) do
        local heights={0,0}
        for _,card in ipairs(meta.cards) do
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
            card.Visible=count>0
            if count>0 then
                local column=twoColumns and (heights[1]<=heights[2] and 1 or 2) or 1
                card.Size=UDim2.new(twoColumns and 0.5 or 1,twoColumns and -7 or 0,0,height)
                card.Position=UDim2.new(column==2 and 0.5 or 0,column==2 and 7 or 0,0,heights[column])
                heights[column]=heights[column]+height+14
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
    D.layout()
end
end
