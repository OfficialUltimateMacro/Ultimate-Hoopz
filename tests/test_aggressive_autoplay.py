from pathlib import Path
from lua_runtime import run
folder=Path(__file__).resolve().parent
source=(folder.parent/'Ultimate.Blessed.decoded.lua').read_text()
fixture=(folder/'sim_fixture.lua').read_text()
lua=r'''_G.ULTIMATE_BLESSED_INSPECT=true;bit32={}
local F=(function() FIXTURE end)()
local app=assert(load(SOURCE,'aggressive','t',_G))();local e=app.Extensions;local v=F.v
local s={AutoGuard=true,AutoGuardKeybind='L',Aimbot=true,AimbotType='High',ShotDelay=.28}
e:Install(F.env,s);e:SetAutoPlay(true)
local root=F.root;root.Position=v(64,3,0);F.own.Character.ball=F.container(F.own.Character,true)
e.OffenseGoal=F.goal;e.State='Opponent';e.DefenseFacing=v(-1,0,0);e.AutoMovePoint=nil
e.OpponentReads={{Position=v(70,3,0),Predicted=v(70,3,0),Velocity=v()}}
local face=e:DesiredFacing(root)
assert(e.ProtectFacing and face.X<-.95,'new possession shields immediately before state transition or route')
e.OpponentReads={};assert(e:DesiredFacing(root).X>.95,'no defender read uses back-to-rim protective fallback')
-- Randomized chains keep advancing without immediate repeat, within cooldowns.
e.Clock=10;e.Plan=nil;e.PreparingShot=false;e.LastMove=nil
local ball=F.own.Character.ball.ballPart;local seen={};local last
for i=1,20 do
 e.Clock=10+i*.11;e:ReleaseDribbleKeys(true)
 e:ChooseDribble(root,root.Position+v(0,0,8),{},ball)
 if e.LastDribble==e.Clock then assert(e.LastMove~=last,'no immediate duplicate');last=e.LastMove;seen[last]=true end
end
local variety=0;for _ in pairs(seen)do variety=variety+1 end
assert(variety>=3,'multiple move options in randomized chains')
-- Open, stopped shot settles in one decision interval, not two .12s waits.
e:ResetOffense();e.State='Own';e.OffenseCharacter=F.own.Character;e.OffenseGoal=F.goal
e.ReadOpponents=function()return {}end;e.CanTakeShot=function()return true end
e.Clock=20;root.AssemblyLinearVelocity=v();assert(not e:OffenseStep(F.own.Character,F.oh,root))
e.Clock=20.07;assert(e:OffenseStep(F.own.Character,F.oh,root),'faster open-shot readiness')
assert(e.PreparingShot and not (e:DesiredFacing(root).X>0),'face rim during setup')
function F.own:GetAttribute(k)if k=='Power'then return 85 end end
for i=1,140 do e.Clock=30+i*.51;e:CaptureTrace() end
assert(#e.TraceLog==120 and e.TraceLog[120]:find('power=85') and e.TraceLog[120]:find('setup=true'),'bounded detailed trace')
e:Log('test','fallback trace');assert(e.EventLog[#e.EventLog]:find('run ') and e.EventLog[#e.EventLog]:find('#'),'ordered run-aware events')
e:SetAutoPlay(false);assert(e.State=='Off' and e.StateSince==e.Clock and not e.ProtectFacing,'honest disabled diagnostics')
return 'PASS: possession-first stationary shield, protective fallback, rapid varied chains, quick shot setup, power/tactical trace bounds and ordered session logs'
'''
print(run(lua.replace('FIXTURE',fixture).replace('SOURCE','[====['+source+']====]')).decode())

