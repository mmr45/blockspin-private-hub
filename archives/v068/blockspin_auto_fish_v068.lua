-- BlockSpin Auto Fish v0.6.8 | fishing + automatic vendor selling
-- Based on the proven v0.5.7 GUI detection and click method.
-- Includes optional vendor cycle. Fishing resumes when inventory capacity falls below limit.
local E = (getgenv and getgenv()) or _G
for _,key in ipairs({'BlockSpinV067','BlockSpinV066','BlockSpinV065','BlockSpinV064','BlockSpinV063','BlockSpinInventoryGuard','BlockSpinV062','BlockSpinV061','BlockSpinV060','BlockSpinV059','BlockSpinV058','BlockSpinV057','BlockSpinV056'}) do
    local old=E[key]
    if old and type(old.stop)=='function' then pcall(old.stop) end
end
local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local UIS=game:GetService('UserInputService')
local player=Players.LocalPlayer
local pg=player:WaitForChild('PlayerGui')
local S={running=true, clicks=0, rounds=0, method='-', status='starting'}
E.BlockSpinV068=S
local gui=Instance.new('ScreenGui')
gui.Name='BlockSpinFishStatus068'; gui.ResetOnSpawn=false; gui.IgnoreGuiInset=true; gui.Parent=pg
local label=Instance.new('TextLabel')
label.Size=UDim2.fromOffset(620,36); label.Position=UDim2.new(0.5,-310,0,55)
label.BackgroundColor3=Color3.fromRGB(10,10,10); label.BackgroundTransparency=0.1
label.TextColor3=Color3.fromRGB(100,255,150); label.Font=Enum.Font.Code
label.TextSize=14; label.Text='Auto Fish v0.6.7 | starting'; label.Parent=gui
local function update(s)
    S.status=s
    if label.Parent then label.Text='Auto Fish v0.6.7 | '..s end
end
local function shown(o)
    if not o or not o:IsA('GuiObject') then return false end
    local p=o
    while p and p~=pg do
        if p:IsA('GuiObject') and not p.Visible then return false end
        if p:IsA('ScreenGui') and not p.Enabled then return false end
        p=p.Parent
    end
    return p==pg
end
-- Preserve v057's identification of the green target and moving white needle.
local function find()
    local root=pg:FindFirstChild('SliderMinigame')
    if not root then return end
    for _,panel in ipairs(root:GetChildren()) do
        if panel:IsA('GuiObject') and shown(panel) then
            local hint=panel:FindFirstChild('Hint')
            local t=hint and hint:IsA('TextLabel') and hint.Text:lower() or ''
            if t:find('needle',1,true) and t:find('green',1,true) then
                for _,bar in ipairs(panel:GetChildren()) do
                    if bar:IsA('Frame') then
                        local needle,target
                        for _,child in ipairs(bar:GetChildren()) do
                            if child:IsA('Frame') and shown(child) then
                                local w,h=child.AbsoluteSize.X,child.AbsoluteSize.Y
                                if h>12 and w>=2 and w<=20 then needle=child end
                                if h>12 and w>=30 and w<bar.AbsoluteSize.X*0.9 then target=child end
                            end
                        end
                        if needle and target then return panel,target,needle end
                    end
                end
            end
        end
    end
end
local function sendClick()
    if type(mouse1click)=='function' then
        local ok=pcall(mouse1click)
        if ok then return true,'mouse1click' end
    end
    if type(mouse1press)=='function' and type(mouse1release)=='function' then
        local ok=pcall(function() mouse1press(); task.wait(0.025); mouse1release() end)
        if ok then return true,'mouse1press/release' end
    end
    local ok=pcall(function()
        local vim=game:GetService('VirtualInputManager')
        local pos=UIS:GetMouseLocation()
        vim:SendMouseButtonEvent(pos.X,pos.Y,0,true,game,0)
        vim:SendMouseButtonEvent(pos.X,pos.Y,0,false,game,0)
    end)
    if ok then return true,'VirtualInputManager' end
    return false,'no supported click method'
end
-- Automatic recast: uses the equipped Roblox Tool's standard Activate method.
-- Only fishing tools are accepted, to avoid firing weapons or using other items.
S.autoCast=true
S.castDelay=2.5          -- seconds after the timing GUI disappears
S.retryDelay=8           -- minimum seconds between cast attempts
S.castAttempts=0
S.castMethod='Tool:Activate'
local lastCast=-1e6
local lastMinigameEnd=nil
local minigameWasVisible=false
local lastSeenPanelAt=nil
local firstCastAt=os.clock()+3
local function fishingTool()
    local character=player.Character
    if not character then return nil end
    for _,obj in ipairs(character:GetChildren()) do
        if obj:IsA('Tool') then
            local name=obj.Name:lower()
            if name:find('fish',1,true) or name:find('rod',1,true) or name:find('canne',1,true) then
                return obj
            end
        end
    end
    return nil
end
-- Integrated inventory guard: reads the actual Items GUI capacity label (occupied slots / max slots).
-- 18/18 means TOTAL occupied slots, not 18 fish. Does not sell or discard items.
S.inventoryLimit=18
S.fishCount=nil
S.inventoryFull=false
S.paused=false
S.inventoryText='unknown'
S.inventorySource='none'
-- Sell cycle. Save two positions once per session: F4 at fishing spot, F5 on blue vendor marker.
-- This is a client-side reposition attempt; some games may reject it.
S.fishingCFrame=nil
S.vendorCFrame=nil
S.autoSell=true
S.selling=false
S.sellStage='idle'
S.sellHoldSeconds=3.5
S.sellAttempts=0
S.lastSellError=nil
local function getRoot()
    local c=player.Character
    return c and c:FindFirstChild('HumanoidRootPart')
end
local function moveTo(cf)
    local root=getRoot()
    if not root or not cf then return false end
    return pcall(function() root.CFrame=cf end)
end
local function sellButton()
    local items=pg:FindFirstChild('Items')
    local holder=items and items:FindFirstChild('ItemsHolder')
    local button=holder and holder:FindFirstChild('SellAllFishButton')
    if button and button:IsA('GuiObject') and shown(button) and button.AbsoluteSize.X>25 then return button end
    return nil
end
local function holdSell(button,seconds)
    local pos=button.AbsolutePosition+button.AbsoluteSize/2
    local x,y=math.floor(pos.X),math.floor(pos.Y)
    local released=false
    local function release()
        if released then return end
        released=true
        if type(mouse1release)=='function' then pcall(mouse1release) end
        pcall(function() game:GetService('VirtualInputManager'):SendMouseButtonEvent(x,y,0,false,game,0) end)
    end
    local ok,err=pcall(function()
        if type(mousemoveabs)=='function' then pcall(mousemoveabs,x,y) end
        pcall(function() game:GetService('VirtualInputManager'):SendMouseMoveEvent(x,y,game) end)
        local pressed=false
        if type(mouse1press)=='function' then pressed=pcall(mouse1press) end
        if not pressed then
            local vim=game:GetService('VirtualInputManager')
            vim:SendMouseButtonEvent(x,y,0,true,game,0)
        end
        local deadline=os.clock()+seconds
        while S.running and S.selling and os.clock()<deadline do task.wait(0.08) end
    end)
    release()
    return ok,err
end
local function tryOpenSeller()
    if sellButton() then return true end
    local root=getRoot()
    if not root then return false end
    -- Prefer a nearby prompt; do not trigger unrelated distant prompts.
    for _,obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA('ProximityPrompt') and obj.Enabled then
            local part=obj.Parent
            local base=part and (part:IsA('BasePart') and part or part:FindFirstAncestorWhichIsA('BasePart'))
            if base and (base.Position-root.Position).Magnitude<12 then
                local tag=(obj.Name..' '..obj.ActionText..' '..obj.ObjectText..' '..base.Name):lower()
                if tag:find('sell',1,true) or tag:find('fish',1,true) or tag:find('poisson',1,true) or tag:find('vend',1,true) then
                    if type(fireproximityprompt)=='function' then pcall(fireproximityprompt,obj) end
                    break
                end
            end
        end
    end
    return sellButton()~=nil
end
local readCapacity
-- Auto route: F8 records a real drive from fishing area to the seller area.
-- F4 fishing position, F5 seller marker, F9 ATM. The vehicle must be occupied.
S.route={}; S.recording=false; S.autoSell=true; S.autoBank=true
S.atmCFrame=nil; S.baitCount=nil; S.baitEmpty=false; S.baitUnknown=true
S.depositStatus='idle'; S.driveStatus='idle'; S.lastRouteError=nil
-- Persistent, inspectable route file. Only use local executor file APIs when available.
local HttpService=game:GetService('HttpService')
local ROUTE_FILE='blockspin_route_v068.json'
local function packCF(cf)
    if not cf then return nil end
    return {cf:GetComponents()}
end
local function unpackCF(a)
    if type(a)~='table' or #a~=12 then return nil end
    for _,n in ipairs(a) do if type(n)~='number' then return nil end end
    return CFrame.new(table.unpack(a))
end
local function saveRoute()
    if type(writefile)~='function' then
        return false,'writefile unavailable: data only kept in memory'
    end
    local pts={}
    for _,v in ipairs(S.route) do pts[#pts+1]={v.X,v.Y,v.Z} end
    local payload={version=1,points=pts,fish=packCF(S.fishingCFrame),vendor=packCF(S.vendorCFrame),atm=packCF(S.atmCFrame)}
    local ok,err=pcall(function() writefile(ROUTE_FILE,HttpService:JSONEncode(payload)) end)
    return ok,ok and ('saved '..#pts..' points to '..ROUTE_FILE) or tostring(err)
end
local function loadRoute()
    if type(readfile)~='function' then return false,'readfile unavailable' end
    local ok,data=pcall(function() return HttpService:JSONDecode(readfile(ROUTE_FILE)) end)
    if not ok or type(data)~='table' or type(data.points)~='table' then return false,'no valid saved route' end
    local points={}
    for _,v in ipairs(data.points) do
        if type(v)=='table' and #v==3 and type(v[1])=='number' and type(v[2])=='number' and type(v[3])=='number' then
            points[#points+1]=Vector3.new(v[1],v[2],v[3])
        end
    end
    S.route=points
    S.fishingCFrame=unpackCF(data.fish)
    S.vendorCFrame=unpackCF(data.vendor)
    S.atmCFrame=unpackCF(data.atm)
    return true,'loaded '..#points..' route points'
end
S.saveRoute=saveRoute
S.loadRoute=loadRoute
local restored,restoreMsg=loadRoute()
if restored then update('ROUTE: '..restoreMsg) end

local function getSeat()
    local c=player.Character
    local hum=c and c:FindFirstChildOfClass('Humanoid')
    local seat=hum and hum.SeatPart
    if seat and seat:IsA('VehicleSeat') then return seat end
end
local function key(code,down)
    local ok=pcall(function() game:GetService('VirtualInputManager'):SendKeyEvent(down,code,false,game) end)
    return ok
end
local function driveKeys(throttle,steer)
    key(Enum.KeyCode.W,throttle>0); key(Enum.KeyCode.S,throttle<0)
    key(Enum.KeyCode.A,steer<0); key(Enum.KeyCode.D,steer>0)
end
local function driveRoute(points)
    if #points<2 then return false,'route missing: record F8 from fishing to vendor' end
    local seat=getSeat()
    if not seat then return false,'sit in driver seat before automatic driving' end
    local vehicle=seat:FindFirstAncestorOfClass('Model')
    for i,point in ipairs(points) do
        local began=os.clock(); local lastDistance=math.huge; local lastProgress=began
        while S.running and S.selling do
            local current=getSeat()
            if current~=seat then driveKeys(0,0); return false,'driver left vehicle' end
            local delta=point-seat.Position
            local flat=Vector3.new(delta.X,0,delta.Z)
            local dist=flat.Magnitude
            if dist<9 then break end
            if dist<lastDistance-1.5 then lastDistance=dist; lastProgress=os.clock() end
            if os.clock()-lastProgress>9 or os.clock()-began>35 then
                driveKeys(0,0); return false,'vehicle stuck or route obstructed at waypoint '..i
            end
            local dir=flat.Unit
            local forward=seat.CFrame.LookVector
            local cross=forward.X*dir.Z-forward.Z*dir.X
            local dot=forward.X*dir.X+forward.Z*dir.Z
            local steer=(cross>0.15 and 1 or (cross< -0.15 and -1 or 0))
            local throttle=(dot< -0.3 and -1 or 1)
            driveKeys(throttle,steer)
            S.driveStatus='waypoint '..i..'/'..#points..' ('..math.floor(dist)..' studs)'
            update('DRIVE '..S.driveStatus)
            task.wait(0.12)
        end
    end
    driveKeys(0,0)
    return true
end
local function walkTo(cf)
    if not cf then return false,'position not saved' end
    local root=getRoot(); local c=player.Character
    local hum=c and c:FindFirstChildOfClass('Humanoid')
    if not root or not hum then return false,'character missing' end
    hum:MoveTo(cf.Position)
    local began=os.clock()
    while S.running and S.selling and os.clock()-began<18 do
        if (root.Position-cf.Position).Magnitude<7 then return true end
        task.wait(0.2)
    end
    return false,'walk timed out (doors/obstacles may block)' 
end
local function clickGui(button)
    if not button or not shown(button) then return false end
    local pos=button.AbsolutePosition+button.AbsoluteSize/2
    local x,y=math.floor(pos.X),math.floor(pos.Y)
    if type(mousemoveabs)=='function' then pcall(mousemoveabs,x,y) end
    local ok=pcall(function()
        local vim=game:GetService('VirtualInputManager')
        vim:SendMouseMoveEvent(x,y,game)
        vim:SendMouseButtonEvent(x,y,0,true,game,0)
        task.wait(0.1)
        vim:SendMouseButtonEvent(x,y,0,false,game,0)
    end)
    return ok
end
local function visibleButtons()
    local buttons={}
    for _,o in ipairs(pg:GetDescendants()) do
        if (o:IsA('TextButton') or o:IsA('ImageButton')) and shown(o) and o.AbsoluteSize.X>35 then
            table.insert(buttons,o)
        end
    end
    return buttons
end
local function byText(pattern)
    for _,o in ipairs(visibleButtons()) do
        local txt=(o:IsA('TextButton') and o.Text or ''):lower()
        if txt:find(pattern,1,true) then return o end
    end
end
local function atmPrompt()
    local root=getRoot(); if not root then return false end
    for _,obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA('ProximityPrompt') and obj.Enabled then
            local part=obj.Parent
            local base=part and (part:IsA('BasePart') and part or part:FindFirstAncestorWhichIsA('BasePart'))
            local tag=(obj.Name..' '..obj.ActionText..' '..obj.ObjectText):lower()
            if base and (base.Position-root.Position).Magnitude<12 and (tag:find('atm',1,true) or tag:find('guichet',1,true) or tag:find('argent',1,true) or tag:find('bank',1,true)) then
                if type(fireproximityprompt)=='function' then return pcall(fireproximityprompt,obj) end
                -- The E key is a fallback, not a guarantee that the prompt is in range.
                key(Enum.KeyCode.E,true); task.wait(0.15); key(Enum.KeyCode.E,false)
                return true
            end
        end
    end
    return false
end
local function findMoneyText()
    for _,obj in ipairs(pg:GetDescendants()) do
        if (obj:IsA('TextLabel') or obj:IsA('TextButton')) and shown(obj) then
            local txt=tostring(obj.Text)
            local val=txt:match('[Éé]quilibre des mains%s*:%s*%$?([%d, ]+)') or txt:match('[Cc]ash%s*:%s*%$?([%d, ]+)')
            if val then return tonumber(val:gsub('[^%d]','')) end
        end
    end
end
local function depositAtAtm()
    if not S.autoBank then return true,'bank disabled' end
    if not S.atmCFrame then return false,'save ATM with F9' end
    S.depositStatus='walking to ATM'
    local ok,err=walkTo(S.atmCFrame)
    if not ok then return false,err end
    atmPrompt()
    local deadline=os.clock()+9
    local depositButton
    repeat
        depositButton=byText('dépôt') or byText('depot')
        if depositButton then break end
        atmPrompt(); task.wait(0.5)
    until os.clock()>deadline or not S.running
    if not depositButton then return false,'ATM service menu not detected' end
    local cash=findMoneyText()
    if cash==0 then return true,'no cash to deposit' end
    clickGui(depositButton); task.wait(0.7)
    -- Slider is not a standard Roblox API. Prefer the actual editable amount field
    -- if the game exposes one; otherwise stop safely instead of guessing a remote.
    local input
    for _,o in ipairs(pg:GetDescendants()) do
        if o:IsA('TextBox') and shown(o) then input=o; break end
    end
    if input and cash and cash>0 then
        pcall(function() input:CaptureFocus() end)
        if type(keypress)=='function' then -- game-specific input still may reject this
            pcall(function() input.Text=tostring(cash) end)
        else
            pcall(function() input.Text=tostring(cash) end)
        end
    else
        -- The screenshot's amount slider is at the rightmost end for max.
        local slider
        for _,o in ipairs(pg:GetDescendants()) do
            if o:IsA('GuiObject') and shown(o) and o.AbsoluteSize.X>220 and o.AbsoluteSize.Y<55 then
                local n=o.Name:lower()
                if n:find('slider',1,true) or n:find('track',1,true) or n:find('bar',1,true) then slider=o; break end
            end
        end
        if not slider then return false,'ATM amount slider not identified; cannot safely deposit' end
        local x=math.floor(slider.AbsolutePosition.X+slider.AbsoluteSize.X-6)
        local y=math.floor(slider.AbsolutePosition.Y+slider.AbsoluteSize.Y/2)
        pcall(function()
            local vim=game:GetService('VirtualInputManager')
            vim:SendMouseMoveEvent(x,y,game)
            vim:SendMouseButtonEvent(x,y,0,true,game,0)
            task.wait(0.12)
            vim:SendMouseButtonEvent(x,y,0,false,game,0)
        end)
    end
    task.wait(0.4)
    local confirm=byText('confirmer')
    if not confirm then return false,'ATM confirm button not found' end
    local amount=0
    for _,o in ipairs(pg:GetDescendants()) do
        if o:IsA('TextLabel') and shown(o) then
            local n=tostring(o.Text):match('[Mm]ontant%s*:%s*%$?([%d, ]+)')
            if n then amount=tonumber(n:gsub('[^%d]','')) or 0 end
        end
    end
    if amount<=0 then return false,'ATM amount remains 0; deposit not sent' end
    clickGui(confirm)
    task.wait(1.2)
    S.depositStatus='deposit clicked for '..amount
    return true,S.depositStatus
end
local function sellCycle()
    if S.selling or not S.running then return end
    S.selling=true
    task.spawn(function()
        local function finish(message)
            driveKeys(0,0); S.sellStage=message; S.selling=false; update(message)
        end
        if not S.inventoryFull then finish('inventory no longer full'); return end
        if not S.fishingCFrame or not S.vendorCFrame or not S.atmCFrame or #S.route<2 then
            S.sellAttempts=1
            finish('SETUP: F4 fish / F5 vendor / F9 ATM / F8 record driving route')
            return
        end
        S.sellAttempts=1
        local ok,err=driveRoute(S.route)
        if not ok then S.lastRouteError=err; finish('DRIVE: '..err); return end
        -- Leave the car manually if the game does not expose a usable exit action.
        local seat=getSeat()
        if seat then
            local hum=player.Character and player.Character:FindFirstChildOfClass('Humanoid')
            if hum then pcall(function() hum.Sit=false end) end
            task.wait(0.7)
        end
        ok,err=walkTo(S.vendorCFrame)
        if not ok then finish('VENDOR: '..err); return end
        local button=sellButton(); local deadline=os.clock()+12
        while S.running and not button and os.clock()<deadline do
            tryOpenSeller(); task.wait(0.5); button=sellButton()
        end
        if not button then finish('VENDOR: sell button not opened'); return end
        update('SELL: holding button')
        local held,why=holdSell(button,S.sellHoldSeconds)
        if not held then finish('SELL: '..tostring(why)); return end
        task.wait(1)
        local info=readCapacity()
        if not info or info.count>=info.limit then finish('SELL: inventory still full / count unknown'); return end
        update('BANK: going to ATM')
        local deposited,why=depositAtAtm()
        if not deposited then finish('BANK: '..tostring(why)); return end
        -- Return to the vehicle's parked point; user must occupy the driver seat.
        local parked=S.route[#S.route]
        local returned,whyWalk=walkTo(CFrame.new(parked))
        if not returned then finish('RETURN: '..tostring(whyWalk)); return end
        local waiting=os.clock()+15
        while S.running and not getSeat() and os.clock()<waiting do
            update('RETURN: enter driver seat (15s)'); task.wait(0.5)
        end
        if not getSeat() then finish('RETURN: vehicle seat not occupied'); return end
        local reversed={}
        for i=#S.route,1,-1 do table.insert(reversed,S.route[i]) end
        local driven,whyDrive=driveRoute(reversed)
        if not driven then finish('RETURN: '..tostring(whyDrive)); return end
        S.inventoryFull=false; S.sellAttempts=0; lastCast=-1e6
        finish('CYCLE COMPLETE: fishing unlocked')
    end)
end

local nextInventoryCheck=0
readCapacity=function()
    local items=pg:FindFirstChild('Items')
    if not items then return nil end
    local best=nil
    for _,obj in ipairs(items:GetDescendants()) do
        if obj:IsA('TextLabel') or obj:IsA('TextButton') then
            local a,b=tostring(obj.Text):match('^%s*(%d+)%s*/%s*(%d+)%s*$')
            a,b=tonumber(a),tonumber(b)
            if a and b and b==S.inventoryLimit and a<=b then
                -- A cached GUI label may be readable even with inventory closed.
                -- Prefer the label nearest the Items container, not slot text.
                local depth=0
                local p=obj
                while p and p~=items do depth=depth+1; p=p.Parent end
                if not best or depth<best.depth then
                    best={count=a,limit=b,depth=depth,path=obj:GetFullName()}
                end
            end
        end
    end
    return best
end
function S.setFishCount(n)
    -- Manual fallback for a UI that does not expose the capacity label.
    if type(n)~='number' or n<0 then return false end
    S.fishCount=math.floor(n)
    S.inventoryFull=(S.fishCount>=S.inventoryLimit)
    if S.inventoryFull then update('INVENTORY FULL - paused') end
    return true
end
function S.resume()
    -- Only resumes if the inventory is no longer full.
    local info=readCapacity()
    if info and info.count>=info.limit then
        S.inventoryFull=true
        update('18/18 - empty inventory before resuming')
        return false
    end
    S.paused=false; S.inventoryFull=false; S.fishCount=nil; S.sellAttempts=0
    return true
end
function S.pause() S.paused=true end
function S.checkInventory()
    local info=readCapacity()
    if info then
        local wasFull=S.inventoryFull
        S.inventoryText=info.count..'/'..info.limit
        S.inventorySource=info.path
        S.fishCount=info.count
        -- The capacity is the source of truth, not a latched FULL flag.
        S.inventoryFull=(info.count>=info.limit)
        if S.inventoryFull then
            if not wasFull then update('INVENTORY '..S.inventoryText..' - AUTO FISH PAUSED') end
        elseif wasFull then
            -- Selling can happen manually or via the vendor routine.
            -- Do not unpause a deliberate user pause.
            S.sellAttempts=0
            lastCast=-1e6
            update('INVENTORY '..S.inventoryText..' - fishing unlocked')
        end
    end
    return info
end
function S.retrySell() S.sellAttempts=0; if S.inventoryFull then sellCycle() end end
local function checkBait()
    local found
    for _,o in ipairs(pg:GetDescendants()) do
        if (o:IsA('TextLabel') or o:IsA('TextButton')) then
            local t=tostring(o.Text)
            if t:lower():find('prawntec',1,true) then
                local parent=o.Parent
                if parent then
                    for _,near in ipairs(parent:GetDescendants()) do
                        if near:IsA('TextLabel') or near:IsA('TextButton') then
                            local count=tostring(near.Text):match('^[xX]%s*(%d+)$')
                            if count then found=tonumber(count); break end
                        end
                    end
                end
            end
        end
        if found~=nil then break end
    end
    if found~=nil then S.baitCount=found; S.baitEmpty=(found==0); S.baitUnknown=false end
end
function S.setBaitCount(n)
    if type(n)~='number' or n<0 then return false end
    S.baitCount=math.floor(n); S.baitEmpty=(S.baitCount==0); S.baitUnknown=false
    return true
end
local function checkInventory(now)
    if now<nextInventoryCheck then return end
    nextInventoryCheck=now+0.8
    S.checkInventory()
    checkBait()
end
-- Optional bait landing calibration: aim at a fixed screen point before casting.
-- F7 saves the current mouse location, F6 clears it. This only moves the cursor;
-- it cannot guarantee where the game's physics will land the bait.
S.baitScreenPoint=nil
local function aimAtSavedPoint()
    local pt=S.baitScreenPoint
    if not pt then return end
    pcall(function()
        local vim=game:GetService('VirtualInputManager')
        vim:SendMouseMoveEvent(pt.X,pt.Y,game)
    end)
end
task.spawn(function()
    while S.running do
        if S.recording then
            local seat=getSeat()
            if seat then
                local pos=seat.Position
                local last=S.route[#S.route]
                if not last or (pos-last).Magnitude>14 then table.insert(S.route,pos) end
                update('RECORDING DRIVE: '..#S.route..' waypoints (F8 to stop)')
            end
        end
        task.wait(0.35)
    end
end)
local inputConn=UIS.InputBegan:Connect(function(input,processed)
    if processed then return end
    if input.KeyCode==Enum.KeyCode.F7 then
        local m=UIS:GetMouseLocation()
        S.baitScreenPoint=Vector2.new(m.X,m.Y)
        update(string.format('aim saved at %.0f, %.0f',m.X,m.Y))
    elseif input.KeyCode==Enum.KeyCode.F4 then
        local root=getRoot()
        if root then S.fishingCFrame=root.CFrame; saveRoute(); update('Fishing position saved (F4)') end
    elseif input.KeyCode==Enum.KeyCode.F5 then
        local root=getRoot()
        if root then S.vendorCFrame=root.CFrame; saveRoute(); update('Vendor position saved (F5)') end
    elseif input.KeyCode==Enum.KeyCode.F9 then
        local root=getRoot()
        if root then S.atmCFrame=root.CFrame; saveRoute(); update('ATM saved (F9)') end
    elseif input.KeyCode==Enum.KeyCode.F8 then
        if not S.recording then S.route={} end
        S.recording=not S.recording
        if not S.recording then
            local ok,msg=saveRoute()
            update('Drive route '..#S.route..' points | '..msg)
        else update('Drive route recording START') end
    elseif input.KeyCode==Enum.KeyCode.F10 then
        local ok,msg=saveRoute()
        update('EXPORT: '..msg)
    elseif input.KeyCode==Enum.KeyCode.F6 then
        S.baitScreenPoint=nil
        update('aim cleared')
    end
end)
local function tryCast(now)
    checkInventory(now)
    if not S.autoCast or S.paused or S.inventoryFull or S.selling or S.baitEmpty then
        if S.inventoryFull then update('INVENTORY FULL - no recast') end
        return
    end
    if now<firstCastAt or now-lastCast<S.retryDelay then return end
    if lastMinigameEnd and now-lastMinigameEnd<S.castDelay then return end
    local tool=fishingTool()
    if not tool then
        update('equip fishing rod to enable auto cast | clicks '..S.clicks)
        return
    end
    aimAtSavedPoint()
    lastCast=now
    S.castAttempts=S.castAttempts+1
    local ok,err=pcall(function() tool:Activate() end)
    if ok then
        update('auto cast attempt '..S.castAttempts..' ('..tool.Name..')')
        print('[BlockSpin v0.6.8] Tool:Activate attempt',S.castAttempts,tool.Name)
    else
        update('auto cast error: '..tostring(err):sub(1,70))
    end
end
local connection
local currentPanel=nil
local lastX,lastT=nil,nil
local lastClick=-100
local lastTarget=nil
local lastTries=nil
local armed=true
local exitedAfterClick=false
local clickX=nil
local pending=false
-- No per-panel click ceiling: each pass is gated by re-arm and cooldown.
local roundsInPanel=0
local function resetPanel(panel)
    currentPanel=panel; lastX=nil; lastT=nil; lastTarget=nil; lastTries=nil
    armed=true; exitedAfterClick=false; clickX=nil; pending=false; roundsInPanel=0
end
function S.stop()
    if not S.running then return end
    if not S.recording then saveRoute() end
    S.running=false
    driveKeys(0,0)
    if connection then connection:Disconnect(); connection=nil end
    if inputConn then inputConn:Disconnect(); inputConn=nil end
    if gui then gui:Destroy() end
    print('[BlockSpin v0.6.8] stopped, clicks='..S.clicks)
end
connection=RunService.Heartbeat:Connect(function()
    if not S.running then return end
    local ok,err=pcall(function()
        checkInventory(os.clock())
        if S.paused or S.inventoryFull or S.selling or S.baitEmpty then
            if S.inventoryFull and S.autoSell and not S.selling and S.sellAttempts<1 then sellCycle() end
            if S.selling then return end
            if S.baitEmpty then update('NO BAIT - casts stopped'); return end
            if S.inventoryFull then update('INVENTORY FULL ('..S.inventoryText..') - no more casts') else update('PAUSED') end
            return
        end
        local panel,target,needle=find()
        if not panel then
            if minigameWasVisible then
                minigameWasVisible=false
                lastMinigameEnd=os.clock()
            end
            if currentPanel then resetPanel(nil) end
            tryCast(os.clock())
            return
        end
        minigameWasVisible=true
        lastSeenPanelAt=os.clock()
        if panel~=currentPanel then resetPanel(panel) end
        local now=os.clock()
        local x=needle.AbsolutePosition.X+needle.AbsoluteSize.X*0.5
        local left=target.AbsolutePosition.X
        local right=left+target.AbsoluteSize.X
        local width=right-left
        if width<=0 then return end
        local triesObj=panel:FindFirstChild('Tries')
        local tries=(triesObj and triesObj:IsA('TextLabel')) and triesObj.Text or ''
        local signature=math.floor(left+0.5)..':'..math.floor(right+0.5)
        local margin=math.min(10,math.max(3,width*0.04))
        local inside=(x>=left+margin and x<=right-margin)
        local outside=(x<left-margin or x>right+margin)
        -- A new phase may keep the same panel. Re-arm on an updated target,
        -- changed attempts label, or the needle completing a fresh exit.
        if not armed and now-lastClick>=0.15 then
            if lastTarget and signature~=lastTarget then
                armed=true; exitedAfterClick=false
            elseif lastTries and tries~=lastTries then
                armed=true; exitedAfterClick=false
            elseif outside then
                exitedAfterClick=true
            elseif exitedAfterClick and not pending and inside then
                armed=true
            end
        end
        lastTarget=signature; lastTries=tries
        local predicted=x
        if lastX and lastT and now>lastT then
            local speed=(x-lastX)/(now-lastT)
            if math.abs(speed)<7000 then predicted=x+speed*0.008 end
        end
        lastX,lastT=x,now
        if not armed or pending then
            update(string.format('round %d | waiting for next pass | total %d',roundsInPanel,S.clicks))
            return
        end
        update(string.format('needle %.0f | green %.0f..%.0f | total %d',x,left,right,S.clicks))
        if now-lastClick>=0.45 and predicted>=left+margin and predicted<=right-margin then
            armed=false; pending=true; exitedAfterClick=false; lastClick=now; clickX=x
            roundsInPanel=roundsInPanel+1
            S.rounds=S.rounds+1
            local thisPanel=panel
            task.spawn(function()
                local success,method=sendClick()
                pending=false
                if not S.running then return end
                S.method=method
                if success then
                    S.clicks=S.clicks+1
                    update('click '..roundsInPanel..' sent ('..method..') | total '..S.clicks)
                    print('[BlockSpin v0.6.8] click',S.clicks,'x',math.floor(clickX or 0),'method',method)
                else
                    -- Retry on a future entry rather than silently becoming stuck.
                    armed=true
                    update('CLICK ERROR: '..method)
                    warn('[BlockSpin v0.6.8] click failed: '..method)
                end
            end)
        end
    end)
    if not ok then update('ERROR: '..tostring(err):sub(1,95)) end
end)
print('[BlockSpin v0.6.8] F4 fish / F5 vendor / F9 ATM / F8 record driving route / F7 aim. F10 save route. Stop: getgenv().BlockSpinV068.stop()')
