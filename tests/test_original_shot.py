import ast,pathlib
from lua_runtime import run
folder=pathlib.Path(__file__).resolve().parent
tree=ast.parse((folder/'test_ultimate_offense.py').read_text(encoding='utf-8'))
raw=next(ast.literal_eval(n.value.func.value) for n in tree.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='lua' for t in n.targets))
setup=raw.split('local s={AutoGuard=true')[0]
lua=setup+r'''
setmetatable(env,{__index=_G});env.game.Players=players;own.Character.Head=part(v(65,5,0));own.Character.HumanoidRootPart=root
root.Position=v(65,3,0);env.GetDeArc=function()return 10 end;env.warn=function()end
local camera={CFrame={},ViewportSize={X=800,Y=600}};world.CurrentCamera=camera
env.CFrame={lookAt=function()return{}end,new=function()return{}end}
env.Vector2={new=function(x,y)return{X=x,Y=y}end}
local events={};function vim:SendMouseButtonEvent(x,y,button,down)events[#events+1]={x,y,button,down}end
env.task.wait=function()end
local settings={Aimbot=true,ShotDelay=.32,AimbotMethod='Mouse'}
local library={functions={GetClosestGoal=function()return goal,65 end,Goal2Team=function()end}}
local raw=app.Functions['root.106'](env,{[0]=settings,[1]=library,[2]='Desktop',[3]=100,[4]=100})
local ok,message=pcall(raw)
assert(ok,tostring(message));assert(#events==2 and events[1][4]==true and events[2][4]==false,'original VM emits mouse press and release')
-- Integration: same recovered VM callback, dispatched by normal jump input.
events={};settings.AutoGuard=true;settings.AutoGuardKeybind='L';e:Install(env,settings);e:SetAutoPlay(true)
own.Character.ball=part(root.Position);oh.FloorMaterial='Ground';root.AssemblyLinearVelocity.Y=0
e.InShotRange=function()return true end;e.CanTakeShot=function()return true end;e.OffenseStep=function()return true end
env.task.spawn=function(f)f()end;env.task.delay=function()end
env.task.wait=function()oh.FloorMaterial='Air';root.AssemblyLinearVelocity.Y=8 end
local callback=app.CustomizeClosure('root.106',raw,env,{})
function vim:SendKeyEvent(down)if down then callback()end end
local pressed,released=0,0;env.keypress=function()pressed=pressed+1;callback()end;env.keyrelease=function()released=released+1 end
e.Clock=2;e:AutoPlayStep(own.Character,oh,root)
assert(#events==2 and pressed==1 and released==1 and not e.Shooting,'native and executor jump cannot double-dispatch original shot')
return 'PASS: unmodified recovered root.106 produces mouse press/release, full Auto-play uses original JumpRequest timing once, executor Space cleanup and duplicate-input suppression'
'''
source=(folder.parent/'Ultimate.Blessed.decoded.lua').read_text(encoding='utf-8')
print(run(lua.replace('SOURCE','[====['+source+']====]')).decode())
