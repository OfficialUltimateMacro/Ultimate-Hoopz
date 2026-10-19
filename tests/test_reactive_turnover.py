from pathlib import Path
from lua_runtime import run
folder=Path(__file__).resolve().parent;source=(folder.parent/'Ultimate.Blessed.decoded.lua').read_text();fixture=(folder/'sim_fixture.lua').read_text()
lua=r'''_G.ULTIMATE_BLESSED_INSPECT=true;bit32={}
local F=(function() FIXTURE end)();local app=assert(load(SOURCE,'reactive turnover','t',_G))();local e=app.Extensions;local v=F.v
local s={AutoGuard=true,AutoGuardKeybind='L',Aimbot=true,AimbotType='High'};e:Install(F.env,s)
local root=F.root;root.Position=v(100,3,0);F.own.Character.ball=F.container(F.own.Character,true);e:SetAutoPlay(true)
local read={Player=F.enemy,Position=v(90,3,0),Predicted=v(90,3,0),Velocity=v()}
e.ReadOpponents=function()return {read}end;e.State='Own';e.ShotSpot=v(65,3,0);e.AutoMovePoint=v(80,3,0);e.Plan={Kind='escape',Point=e.AutoMovePoint,Until=10}
e.Clock=5;e:ReactiveRoute(root)
assert(e.RerouteCount==1 and e.Plan==nil and (not e.AutoMovePoint or e:PossessionPathClear(root,e.AutoMovePoint,{read})),'moving blocker cancels stale commitment and reroutes safely')
if e.AutoMovePoint then
 read.Position=(root.Position+e.AutoMovePoint)/2;read.Predicted=read.Position
 e.Clock=5.06;e:ReactiveRoute(root)
 assert(e.RerouteCount==2 and (not e.AutoMovePoint or e:PossessionPathClear(root,e.AutoMovePoint,{read})),'alternate route is invalidated when defender cuts across it')
end
-- Losing possession cannot continue the old offensive MoveTo during debounce.
F.own.Character.ball:SetBall(false);F.er.Position=v(95,3,0);F.enemy.Character.ball=F.container(F.enemy.Character,true)
e.State='Own';e.AutoMovePoint=v(80,3,0);e.AutoMoving=true
F.run.bindings[e.RenderName](1/60)
assert(e.AutoMovePoint==nil and F.oh.point==root.Position,'stale offensive movement stops immediately without ball')
e.Clock=6;e.ResetUntil=nil;e.PendingState=nil
local state,holder=e:UpdateState(F.own.Character,F.oh,root)
assert(state=='Opponent' and holder==F.enemy and e.TurnoverRetreat,'confirmed turnover has no normal debounce')
read.Position=F.er.Position;read.Predicted=read.Position
local target=e:DefenseStep(F.own.Character,F.oh,root,F.enemy)
assert(target and e.DefenseMode=='Transition: protect hoop' and (target-v(0,3,0)).Magnitude<20,'retreat aims near hoop, not attacker back')
local calls=0;local aim=app.CustomizeClosure('root.106',function()calls=calls+1 end,F.env,{})
aim();assert(calls==0 and not e.AimDepth,'defensive contest does not trigger aim callback')
F.own.Character.ball:SetBall(true);aim();assert(calls==1,'own-ball shots remain available')
e.Clock=8;e:CaptureTrace();local row=e.TraceLog[#e.TraceLog]
assert(row:find('gap=') and row:find('predictedGap=') and row:find('reroutes='),'diagnostics expose defender separation')
return 'PASS: live waypoint invalidation, alternate exit validation, immediate stale-route stop, confirmed turnover priority, hoop retreat, contest-aim suppression and gap diagnostics'
'''
print(run(lua.replace('FIXTURE',fixture).replace('SOURCE','[====['+source+']====]')).decode())
