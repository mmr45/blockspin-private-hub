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
