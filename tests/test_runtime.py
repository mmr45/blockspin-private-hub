"""Tests Lua avec API Roblox simulees. Necessite lupa (outil de test uniquement)."""
import json
from pathlib import Path
from lupa import LuaRuntime

source = (Path(__file__).resolve().parents[1] / 'src/main.lua').read_text()
MOCK = r'''
objects, warnings, files = {}, {}, {}
function warn(message) table.insert(warnings, message) end
math.clamp = function(v, lo, hi) return math.max(lo, math.min(v, hi)) end
Vector2 = {new = function(x,y) return {X=x,Y=y} end}
UDim = {new = function(s,o) return {Scale=s,Offset=o} end}
UDim2 = {new = function(xs,xo,ys,yo) return {X=UDim.new(xs or 0,xo or 0), Y=UDim.new(ys or 0,yo or 0)} end}
UDim2.fromOffset = function(x,y) return UDim2.new(0,x,0,y) end
UDim2.fromScale = function(x,y) return UDim2.new(x,0,y,0) end
Color3 = {fromRGB = function(r,g,b) return {r,g,b} end}
Enum = setmetatable({}, {__index=function(t,k)
 local entries=setmetatable({}, {__index=function(e,n)
  if n=='InvalidKey' then error('invalid key') end
  local v={Name=n}; rawset(e,n,v); return v
 end});rawset(t,k,entries);return entries
end})
function signal()
 local s={listeners={}}
 function s:Connect(fn)
  local c={active=true,fn=fn};function c:Disconnect() self.active=false end
  table.insert(self.listeners,c);return c
 end
 function s:Fire(...)
  for _,c in ipairs(self.listeners) do if c.active then c.fn(...) end end
 end
 return s
end
local methods={}
function methods:GetChildren()
 local result={};for _,v in ipairs(objects) do if v.Parent==self and not v.destroyed then table.insert(result,v) end end
 return result
end
function methods:IsA(name) return self.ClassName==name end
function methods:FindFirstChild(name)
 for _,v in ipairs(self:GetChildren()) do if v.Name==name then return v end end
end
function methods:WaitForChild(name) return self:FindFirstChild(name) end
function methods:GetPropertyChangedSignal(name)
 self.signals[name]=self.signals[name] or signal();return self.signals[name]
end
function methods:Destroy()
 self.Destroying:Fire();self.destroyed=true
 for _,v in ipairs(self:GetChildren()) do v:Destroy() end
end
Instance={new=function(class)
 local o={Visible=true,ClassName=class,signals={},Destroying=signal(),Activated=signal(),InputBegan=signal()}
 setmetatable(o,{__index=function(t,k)
  if methods[k] then return methods[k] end
  if k=='AbsoluteSize' then
   if class=='ScreenGui' or class=='PlayerGui' then return Vector2.new(1000,800) end
   local p=t.Parent and t.Parent.AbsoluteSize or Vector2.new(1000,800)
   local s=t.Size or UDim2.new();return Vector2.new(p.X*s.X.Scale+s.X.Offset,p.Y*s.Y.Scale+s.Y.Offset)
  end
 end})
 table.insert(objects,o);return o
end}
input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
function input:GetFocusedTextBox() return self.focused end
render={RenderStepped=signal()}
playerGui=Instance.new('PlayerGui');playerGui.Name='PlayerGui'
player=Instance.new('Player');playerGui.Parent=player
function player:GetNetworkPing() return 0.042 end
game={GetService=function(_,name)
 if name=='Players' then return {LocalPlayer=player} end
 if name=='RunService' then return render end
 if name=='UserInputService' then return input end
 if name=='HttpService' then return {JSONDecode=function(_,s) return decode(s) end, JSONEncode=function(_,t) return encode(t) end} end
 error(name)
end}
function find(text)
 for i=#objects,1,-1 do local o=objects[i];if not o.destroyed and o.Text and string.find(o.Text,text,1,true) then return o end end
 error('missing '..text)
end
function click(text)
 for i=#objects,1,-1 do local o=objects[i]
  if not o.destroyed and o.ClassName=='TextButton' and string.find(o.Text,text,1,true) then o.Activated:Fire();return end
 end
 error('missing button '..text)
end
function key(name,processed)
 input.InputBegan:Fire({UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode[name]},processed)
end
function pointer(kind,x,y) return {UserInputType=Enum.UserInputType[kind],Position={X=x,Y=y}} end
function connectionsActive()
 local total=0
 for _,s in ipairs({input.InputBegan,input.InputChanged,input.InputEnded,input.WindowFocusReleased,render.RenderStepped}) do
  for _,c in ipairs(s.listeners) do if c.active then total=total+1 end end
 end
 return total
end
'''

def runtime(saved=None, storage=True, fail_write=False):
    lua = LuaRuntime(unpack_returned_tuples=True)
    def from_py(value):
        if isinstance(value, dict):
            return lua.table_from({k: from_py(v) for k, v in value.items()})
        return value
    def encode(table):
        def convert(v):
            if hasattr(v, 'items'):
                return {k: convert(x) for k, x in v.items()}
            return v
        return json.dumps(convert(table))
    lua.globals().decode = lambda s: from_py(json.loads(s))
    lua.globals().encode = encode
    lua.execute(MOCK)
    if storage:
        lua.execute('''
function isfile(path) return files[path] ~= nil end
function readfile(path) return files[path] end
function writefile(path, data) files[path]=data end
''')
    if saved is not None:
        lua.globals().files['blockspin-settings-v1.json'] = saved
    if fail_write:
        lua.execute("function writefile() error('disk full') end")
    lua.execute(source)
    return lua

lua = runtime()
lua.execute('''
assert(find('BLOCKSPIN').Text:find('0.2.0',1,true))
click('Overlay FPS / ping : inactif')
local overlay=find('FPS : -- | Ping : N/D')
assert(overlay.Visible)
render.RenderStepped:Fire(1/60)
for i=1,60 do render.RenderStepped:Fire(1/60) end
assert(overlay.Text:find('42 ms',1,true))
local window=find('BLOCKSPIN').Parent
key('RightShift',false);assert(not window.Visible and overlay.Visible)
key('RightShift',false);assert(window.Visible)
click('Raccourci :');key('F6',true)
key('RightShift',false);assert(window.Visible)
key('F6',false);assert(not window.Visible)
input.focused={};key('F6',false);assert(not window.Visible);input.focused=nil
key('F6',false)
click('Raccourci :');key('Escape',true);key('F6',false);assert(not window.Visible);key('F6',false)
local title=find('BLOCKSPIN')
local start=pointer('MouseButton1',100,100)
title.InputBegan:Fire(start)
input.InputChanged:Fire(pointer('MouseMovement',-5000,-5000))
input.InputEnded:Fire(start)
assert(window.Position.X.Offset==0 and window.Position.Y.Offset==0)
local handle=find('<>');start=pointer('MouseButton1',100,100);handle.InputBegan:Fire(start)
input.InputChanged:Fire(pointer('MouseMovement',-5000,-5000));input.InputEnded:Fire(start)
assert(window.AbsoluteSize.X>=360 and window.AbsoluteSize.Y>=340)
start=pointer('Touch',0,0);overlay.InputBegan:Fire(start)
start.Position={X=9999,Y=9999};input.InputChanged:Fire(start);input.InputEnded:Fire(start)
assert(overlay.Position.X.Offset<=730 and overlay.Position.Y.Offset<=764)
click('Tester la capture');assert(find('Test volontaire du diagnostic'))
click('Tout arreter');assert(connectionsActive()==0 and overlay.destroyed)
''')
saved = lua.globals().files['blockspin-settings-v1.json']
data = json.loads(saved)
assert data['hotkey'] == 'F6' and data['overlay'] is True and 'position' in data
lua = runtime(saved)
lua.execute("assert(find('Raccourci : F6')); assert(find('Overlay FPS / ping : actif'))")
# Reloading must disconnect old handlers and replace the previous GUI.
lua.execute(source)
lua.execute("assert(connectionsActive()==5); click('Tout arreter'); assert(connectionsActive()==0)")
for invalid in ('{', json.dumps({'schema': 9}), json.dumps({**data, 'hotkey': 'InvalidKey'}), json.dumps({**data,'size':{'x':'bad','y':100}})):
    lua = runtime(invalid)
    lua.execute("click('FPS / ping : affiches');click('Tout arreter')")
    assert lua.globals().files['blockspin-settings-v1.json'] == invalid
lua = runtime(storage=False)
lua.execute("click('Overlay FPS / ping : inactif');click('Actualiser');assert(find('Indisponible'));click('Tout arreter');assert(connectionsActive()==0)")
lua = runtime(fail_write=True)
lua.execute("click('FPS / ping : affiches');assert(find('disk full'));click('Tout arreter');assert(connectionsActive()==0)")
lua = runtime(json.dumps({**data, 'position': {'x': -99999, 'y': 99999}, 'size': {'x': -10, 'y': 99999}}))
lua.execute("local w=find('BLOCKSPIN').Parent;assert(w.Position.X.Offset>=0 and w.Position.Y.Offset>=0 and w.AbsoluteSize.X>=360 and w.AbsoluteSize.Y<=800)")
lua.execute("function player:GetNetworkPing() error('unavailable') end;for i=1,61 do render.RenderStepped:Fire(1/60) end;assert(find('Ping API : N/D'))")
print('OK : overlay, mesures, raccourci, focus, annulation, geometrie, sauvegarde, fichiers invalides, erreurs, fermeture et relance')
