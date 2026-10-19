from pathlib import Path
from lua_runtime import run
folder=Path(__file__).resolve().parent
source=(folder.parent/'Ultimate.Blessed.decoded.lua').read_text()
fixture=(folder/'sim_fixture.lua').read_text()
lua=r'''_G.ULTIMATE_BLESSED_INSPECT=true;bit32={}
local F=(function() FIXTURE end)()
local app=assert(load(SOURCE,'protection','t',_G))();local e=app.Extensions;local v=F.v
local s={AutoGuard=true,AutoGuardKeybind='L',Aimbot=true}
e:Install(F.env,s);e:SetAutoPlay(true)
local root=F.root;root.Position=v(60,3,0);root.CFrame=F.frame(root.Position,root.Position+v(1,0,0))
local ball=F.part(root.Position+v(0,0,-1),'Ball');F.own.Character.ball=ball
local threat={Position=root.Position+v(-3,0,-2),Predicted=root.Position+v(-3,0,-2),Velocity=v()}
e.Clock=10;e:ChooseDribble(root,root.Position+v(-2,0,6),{threat},ball)
assert(e.LastMove=='F','exposed left hand moves behind back to safe right side')
local sent=#F.keys;e.Clock=10.11;e:ChooseDribble(root,root.Position+v(-2,0,6),{threat},ball)
assert(#F.keys==sent,'exposed transfer waits on cooldown instead of crossing unsafely')
e:ReleaseDribbleKeys(true);e.Clock=11;e.DribbleDecisionUntil=nil;e.MoveCooldowns.F=100
sent=#F.keys;e:ChooseDribble(root,root.Position+v(-2,0,6),{threat},ball)
assert(#F.keys==sent,'unavailable safe move never becomes random unsafe move')
e.MoveCooldowns={};ball.Position=root.Position+v(0,0,1);sent=#F.keys
e:ChooseDribble(root,root.Position+v(-2,0,6),{threat},ball)
assert(#F.keys>sent and (e.LastMove=='R' or e.LastMove=='V' or e.LastMove=='B'),'protected hand chains fakes without unsafe crossover')
assert(e:EscapeMove(1,1,false)==nil and e:EscapeMove(-1,-1,false)==nil,'preserve protected hand')
assert(e:EscapeMove(1,-1,false)=='F' and e:EscapeMove(-1,1,false)=='G','body-space hand transfers')
e.Clock=12;sent=#F.keys;e:ChooseDribble(root,root.Position+v(-8,0,0),{},ball);assert(#F.keys>sent,'open lane continues requested randomized chain')
e.State='Own';e.OffenseGoal=F.goal;e.AutoMovePoint=root.Position+v(-3,0,6);e.OpponentReads={threat}
local face=e:DesiredFacing(root);local away=(root.Position-threat.Predicted).Unit
assert(e.ProtectFacing and face:Dot(away)>0.98,'back faces defender while dribbling')
e.AutoMovePoint=nil;face=e:DesiredFacing(root)
assert(e.ProtectFacing,'stationary possession remains shielded before setup')
e.PreparingShot=true;face=e:DesiredFacing(root);assert(not e.ProtectFacing and face:Dot((F.goal.Position-root.Position).Unit)>0.95,'square to hoop when preparing shot')
e.PreparingShot=false
e.AutoMovePoint=root.Position+v(-3,0,6);e.DunkMode=true;root.Position=v(8,3,0);e:DesiredFacing(root)
assert(not e.ProtectFacing,'dunk approach does not turn back to rim')
F.own.Character.attrs.Action='Dunking';assert(not e:PulseDribble('C'));e.Clock=20;assert(not e:PulseDribble('C'),'never dribble during dunk even with stale action')
return 'PASS: safe hand transfer, protected-hand retention, no random cooldown fallback, commitment, open-lane randomized chains and dunk input exclusion'
'''
print(run(lua.replace('FIXTURE',fixture).replace('SOURCE','[====['+source+']====]')).decode())
