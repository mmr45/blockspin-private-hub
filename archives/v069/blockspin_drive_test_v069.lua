-- BlockSpin v0.6.9 | TEST DE CONDUITE UNIQUEMENT
-- Ne vend rien, ne depose rien, ne modifie pas les fichiers de trajet.
local env=(getgenv and getgenv()) or _G
if env.BlockSpinDriveTest069 and env.BlockSpinDriveTest069.stop then pcall(env.BlockSpinDriveTest069.stop) end
local Players=game:GetService('Players')
local UIS=game:GetService('UserInputService')
local VIM=game:GetService('VirtualInputManager')
local RunService=game:GetService('RunService')
local player=Players.LocalPlayer
local S={running=true, driving=false, index=0, message='Pret: F11 demarrer / F12 arreter'}
env.BlockSpinDriveTest069=S
-- Coordonnees PONT -> PARKING VENDEUR transmises par l'utilisateur (19 points).
local raw={
{-350.9665222167969,254.49325561523438,844.3192138671875},
{-369.0896911621094,254.4923095703125,831.8604736328125},
{-356.9356689453125,254.54286193847657,816.4835815429688},
{-353.1336975097656,254.52691650390626,785.2936401367188},
{-354.03375244140627,254.49530029296876,761.7402954101563},
{-355.7673645019531,254.50611877441407,732.5521850585938},
{-357.8532409667969,254.48487854003907,698.636962890625},
{-358.7081604003906,254.4691162109375,665.3856201171875},
{-356.3110656738281,254.19288635253907,631.7860107421875},
{-351.2131652832031,254.3011016845703,598.9113159179688},
{-350.15362548828127,254.29486083984376,563.9579467773438},
{-351.9523620605469,254.2373809814453,530.1721801757813},
{-353.070068359375,254.17745971679688,500.9393310546875},
{-348.8035888671875,254.1873779296875,476.7269592285156},
{-339.17938232421877,254.19473266601563,460.05224609375},
{-327.79254150390627,254.25985717773438,450.3841247558594},
{-313.7236633300781,254.18594360351563,440.20709228515627},
{-300.2818908691406,254.46258544921876,435.3600769042969},
{-284.83880615234377,255.061767578125,431.8515625}}
local points={}
for _,v in ipairs(raw) do points[#points+1]=Vector3.new(v[1],v[2],v[3]) end
-- Roblox traite souvent W/A/S/D comme commandes physiques meme sur AZERTY.
-- Si ton vehicule ne reagit pas, essaye S.keys={forward=Enum.KeyCode.Z,left=Enum.KeyCode.Q,back=Enum.KeyCode.S,right=Enum.KeyCode.D}.
S.keys={forward=Enum.KeyCode.W,left=Enum.KeyCode.A,back=Enum.KeyCode.S,right=Enum.KeyCode.D}
local held={}
local function release()
 for _,k in pairs(S.keys) do
  if held[k] then pcall(function() VIM:SendKeyEvent(false,k,false,game) end) end
  held[k]=nil
 end
end
local function setKeys(forward,back,left,right)
 local wanted={[S.keys.forward]=forward,[S.keys.back]=back,[S.keys.left]=left,[S.keys.right]=right}
 for _,k in pairs(S.keys) do
  local state=not not wanted[k]
  if state~=(held[k] or false) then
   pcall(function() VIM:SendKeyEvent(state,k,false,game) end)
   held[k]=state
  end
 end
end
local gui=Instance.new('ScreenGui');gui.Name='BlockSpinDriveTest069';gui.ResetOnSpawn=false;gui.Parent=player:WaitForChild('PlayerGui')
local label=Instance.new('TextLabel');label.Size=UDim2.fromOffset(620,44);label.Position=UDim2.new(.5,-310,0,100);label.BackgroundColor3=Color3.fromRGB(20,20,20);label.TextColor3=Color3.fromRGB(120,255,180);label.Font=Enum.Font.Code;label.TextSize=15;label.Parent=gui
local function status(msg) S.message=msg;label.Text='Drive Test v0.6.9 | '..msg;print('[DriveTest] '..msg) end
status(S.message)
local function seat()
 local c=player.Character;local h=c and c:FindFirstChildOfClass('Humanoid');local p=h and h.SeatPart
 if p and p:IsA('VehicleSeat') then return p end
end
function S.cancel() S.driving=false;release();status('ARRET / F11 pour recommencer') end
function S.stop() S.running=false;S.cancel();if S.input then S.input:Disconnect() end;if gui then gui:Destroy() end;env.BlockSpinDriveTest069=nil end
function S.start()
 if not S.running or S.driving then return end
 local initialSeat=seat()
 if not initialSeat then status('ERREUR: monte au volant avant F11');return end
 local startDist=(Vector3.new(initialSeat.Position.X,0,initialSeat.Position.Z)-Vector3.new(points[1].X,0,points[1].Z)).Magnitude
 if startDist>65 then status('ERREUR: voiture trop loin du depart ('..math.floor(startDist)..' studs)');return end
 S.driving=true
 task.spawn(function()
  for i,target in ipairs(points) do
   if not S.running or not S.driving then break end
   S.index=i
   local best=math.huge;local lastProgress=os.clock();local began=os.clock()
   while S.running and S.driving do
    local current=seat()
    if current~=initialSeat then status('ERREUR: siege conducteur perdu');S.driving=false;break end
    local delta=Vector3.new(target.X-current.Position.X,0,target.Z-current.Position.Z)
    local dist=delta.Magnitude
    if dist<10 then break end
    if dist<best-1 then best=dist;lastProgress=os.clock() end
    if os.clock()-lastProgress>8 or os.clock()-began>35 then status('BLOQUE au point '..i..'/'..#points);S.driving=false;break end
    local dir=delta.Unit;local forward=current.CFrame.LookVector
    local dot=forward.X*dir.X+forward.Z*dir.Z
    local cross=forward.X*dir.Z-forward.Z*dir.X
    local steer=cross>0.12 and 1 or (cross< -0.12 and -1 or 0)
    -- Le test ne recule pas automatiquement: evite les manoeuvres dangereuses.
    if dot< -0.45 then setKeys(false,false,steer<0,steer>0)
    else setKeys(true,false,steer<0,steer>0) end
    label.Text=string.format('Drive Test v0.6.9 | Point %d/%d | %.0f studs | F12 STOP',i,#points,dist)
    task.wait(0.12)
   end
   release()
  end
  if S.driving then status('TRAJET TERMINE: parking vendeur atteint (a verifier)') end
  S.driving=false;release()
 end)
end
S.input=UIS.InputBegan:Connect(function(input,processed)
 if input.KeyCode==Enum.KeyCode.F12 then S.cancel()
 elseif input.KeyCode==Enum.KeyCode.F11 and not processed then S.start() end
end)
print('[DriveTest v0.6.9] F11 demarrer au pont, F12 arret immediat; getgenv().BlockSpinDriveTest069.stop()')
