from pathlib import Path
from lua_runtime import run
folder=Path(__file__).resolve().parent;source=(folder.parent/'Ultimate.Blessed.decoded.lua').read_text();fixture=(folder/'sim_fixture.lua').read_text()
lua=r'''_G.ULTIMATE_BLESSED_INSPECT=true;bit32={}
local F=(function() FIXTURE end)();local app=assert(load(SOURCE,'adaptive','t',_G))();local e=app.Extensions;local v=F.v
local s={AutoGuard=true,AutoGuardKeybind='L',Aimbot=true,AimbotType='High',ShotDelay=.28}
e:Install(F.env,s);assert(s.AutoGuard==false,'Auto Guard off by default');s.AutoGuard=true -- user enables it
F.own.Character.ball=F.container(F.own.Character,true)
local shown,notices;local notices={}
local setter=app.CustomizeClosure('root.1061',function(value)s.AutoGuard=value end,F.env,{[0]=s})
local caps={[0]=s,[1]={SetValue=function()end},[3]={SetValue=function(value)shown=value;setter(value)end},[2]={Notification=function()return{new=function(row)notices[#notices+1]=row end}end}}
e.InputCaptures=caps;e:SetAutoPlay(true)
assert(not s.AutoGuard and shown==false and notices[#notices].Title=='Auto Guard' and notices[#notices].Description:find('Disabled'),'start disables and notifies standalone guard')
e:GuardKey({KeyCode='L'},false,caps);assert(not s.AutoGuard and shown==false and notices[#notices].Description:find('Disabled'),'L cannot reenable standalone guard')
setter(true);assert(not s.AutoGuard and shown==false,'UI toggle cannot reenable guard')
local mobile=app.CustomizeClosure('root.1168',function()error('native guard toggle ran')end,F.env,{})
mobile();assert(not s.AutoGuard,'mobile toggle blocked too')
s.AutoGuard=true;e:Tick(.01);assert(not s.AutoGuard,'external change corrected while autoplay on')
e:SetAutoPlay(false);assert(s.AutoGuard,'previous standalone setting restored after autoplay')
e:SetAutoPlay(true);e.MatchOpponent=F.enemy
local root=F.root;root.Position=v(100,3,0);F.er.Position=v(80,3,0)
e:ObserveRisk(F.enemy,'jumper_not_released');assert(not e.AdaptiveRimOnly,'one failure does not classify opponent')
e:ObserveRisk(F.enemy,'jumper_not_released');assert(not e.AdaptiveRimOnly and e:RiskProfile(F.enemy,false).Unreleased==2,'failed releases remain diagnostics only')
e.Clock=5;e.OffenseCharacter=F.own.Character;e.OffenseGoal=F.goal;e:OffenseStep(F.own.Character,F.oh,root)
assert(not e.DunkMode,'failed releases do not force a rim drive')
F.enemy.Character.ball=F.container(F.enemy.Character,true);F.own.Character.ball:SetBall(false)
e.State='Opponent';local target=e:DefenseStep(F.own.Character,F.oh,root,F.enemy)
assert(e.DefenseMode~='Adaptive hoop protection' and target,'offensive adaptation does not force hoop camping')
local other=F.player(v(200,3,0),'DifferentOpponent');e.MatchOpponent=other;e:SyncRisk();assert(not e.AdaptiveRimOnly,'adaptation is opponent-specific')
F.own.Character.ball:SetBall(true);root.Position=v(64,3,0);e.OffenseGoal=F.goal;e.ForceShot=true
e.OpponentReads={{Player=F.enemy,Position=v(65,3,0),Predicted=v(65,3,0),Velocity=v()}}
assert(e:CanTakeShot(root) and e.ShotContested,'contested in-range jumper is allowed (user preference)')
e.OpponentReads={};assert(e:CanTakeShot(root),'clear shot remains available')
e.State='Own';e.PreparingShot=false;e.Shooting=false;e.AutoMovePoint=nil;e.Clock=10;e.LastDribble=-100;e.MoveCooldowns={}
e:ProtectiveIdle();assert(e.LastMove=='R' or e.LastMove=='V' or e.LastMove=='B','waiting still uses protective dribble moves')
root.Position=v(8,3,0);e.DunkMode=true;e.OpponentReads={{Player=F.enemy,Position=v(4,3,0),Predicted=v(4,3,0),Velocity=v()}}
assert(e:TryDunk(root,F.goal),'close to the rim the dunk goes up even with a defender on the body (user preference)')
local target=e:RimFinishPoint(root,F.goal,{{Player=F.enemy,Position=v(6,3,3),Predicted=v(6,3,3),Velocity=v()}})
assert(target.Z<-1 and math.abs(target.Y-root.Position.Y)<.01,'rim finish steps to the side away from the defender')
e.OpponentReads={};local original=F.world.Raycast;F.world.Raycast=function()return nil end
e:ResetOffense();e.OffenseCharacter=F.own.Character;e.OffenseGoal=F.goal;e.ReadOpponents=function()return{}end
local before=e.DunkAttempts or 0;e:OffenseStep(F.own.Character,F.oh,root)
assert(not e.AutoMovePoint and (e.DunkAttempts or 0)==before,'no raw rim fallback or T input when floor support unavailable')
local third=F.player(v(80,3,0),'ReleaseFailureOpponent');e.MatchOpponent=third;e:SyncRisk()
for i=1,2 do e.ShotTrack={Kind='Shot',Released=false};e:FinishShotTrack('Not a release: ball taken by opponent') end
assert(not e.AdaptiveRimOnly,'shot-result failures cannot force rim-only')
for i=1,20 do e:ObserveRisk(third,'turnover') end
assert(not e.AdaptiveRimOnly,'ordinary turnovers never force strategy')
return 'PASS: guard lock across key/UI/mobile/external edits, off notice and restoration; opponent-specific adaptation, contested in-range shots allowed, hoop protection, protective waiting and safe dunk gating'
'''
print(run(lua.replace('FIXTURE',fixture).replace('SOURCE','[====['+source+']====]')).decode())
