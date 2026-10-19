from pathlib import Path
from lua_runtime import run
folder=Path(__file__).resolve().parent;source=(folder.parent/'Ultimate.Blessed.decoded.lua').read_text();fixture=(folder/'sim_fixture.lua').read_text()
lua=r'''_G.ULTIMATE_BLESSED_INSPECT=true;bit32={}
local F=(function() FIXTURE end)();local app=assert(load(SOURCE,'spacing','t',_G))();local e=app.Extensions;local v=F.v
local s={AutoGuard=true,AutoGuardKeybind='L',Aimbot=true,AimbotType='High'};e:Install(F.env,s)
F.root.Position=v(100,3,0);F.own.Character.ball=F.container(F.own.Character,true);e:SetAutoPlay(true)
local root=F.root;local opponent={Player=F.enemy,Position=v(90,3,0),Predicted=v(90,3,0),Velocity=v()}
assert(not e:PossessionPathClear(root,v(80,3,0),{opponent}),'reject crossing body buffer even if endpoint looks clear')
local point=e:SteerTo(root,v(70,3,0),{opponent});assert(point and e:PossessionPathClear(root,point,{opponent}),'choose wider detour')
root.Position=v(94,3,0)
assert(not e:PossessionPathClear(root,v(91,3,0),{opponent}),'crowded route cannot move closer')
point=e:SteerTo(root,v(70,3,0),{opponent});assert(point and (point-opponent.Position).Magnitude>4.75,'crowded fallback increases separation')
assert(not e:PossessionPathClear(root,v(130,3,0),{}),'retreat stays on court')
-- The forced-shot timeout retains defender reads instead of passing {}.
root.Position=v(100,3,0);e.OffenseCharacter=F.own.Character;e.OffenseGoal=F.goal;e.PossessionStart=0;e.Clock=20
local count;e.CanTakeShot=function()return false end;e.ReadOpponents=function()return {opponent}end
e.SteerTo=function(_,_,_,reads)count=#reads;return nil end
e:OffenseStep(F.own.Character,F.oh,root);assert(count==1,'timeout cannot bypass avoidance')
-- .08s spacing is accepted, with independent key release.
e.LastDribble=-100;e.MoveCooldowns={};e.Clock=30;assert(e:PulseDribble('R'));e:ReleaseDribbleKeys(true)
e.Clock=30.08;assert(e:PulseDribble('F'),'faster global input interval');e:ReleaseDribbleKeys(true)
-- At 13 studs use more than the contact-range fake pool.
math.randomseed(1234);e.Clock=40;e.Plan=nil;e.DribbleDecisionUntil=nil;e.MoveCooldowns={};e.LastDribble=-100;e.LastMove=nil
local threat={Position=root.Position+v(-13,0,0),Predicted=root.Position+v(-13,0,0),Velocity=v()};local seen={}
for i=1,30 do e.Clock=40+i*.08;e:ReleaseDribbleKeys(true);e:ChooseDribble(root,root.Position+v(0,0,8),{threat},F.own.Character.ball);seen[e.LastMove or '?']=true end
assert(seen.C and seen.H and (seen.F or seen.G),'expanded spaced dribble variety')
return 'PASS: swept clearance, wider detour, crowded retreat, court boundary, timeout avoidance, .08s inputs and expanded move variety'
'''
print(run(lua.replace('FIXTURE',fixture).replace('SOURCE','[====['+source+']====]')).decode())
