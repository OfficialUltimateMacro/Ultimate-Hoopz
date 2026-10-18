from pathlib import Path
from lua_runtime import run
folder=Path(__file__).resolve().parent
source=(folder.parent/'Ultimate.Blessed.decoded.lua').read_text()
fixture=(folder/'sim_fixture.lua').read_text()
lua=r'''_G.ULTIMATE_BLESSED_INSPECT=true;bit32={}
local F=(function() FIXTURE end)()
local app=assert(load(SOURCE,'court','t',_G))();local e=app.Extensions;local v=F.v
local s={AutoGuard=true,AutoGuardKeybind='L',Aimbot=true,AimbotType='Mixed arc'}
e:Install(F.env,s)
F.root.Position=v(60,3,0);F.er.Position=v(75,3,0);F.enemy.Character.ball=F.container(F.enemy.Character,true)
local stranger=F.player(v(260,3,0),'OtherCourt');stranger.Character.ball=F.container(stranger.Character,true)
local ps=F.env.game:GetService('Players');function ps:GetPlayers()return {F.own,stranger,F.enemy}end
e.PlayerCache=nil;e:SetAutoPlay(true)
local state,who=e:ReadPossession(F.own.Character)
assert(state=='Opponent' and who==F.enemy and e.MatchGoal==F.goal,'ignore first global holder on adjacent court')
assert(e:DefendedGoal(stranger.Character.root)==F.goal,'stranger cannot change hoop')
F.enemy.Character.ball:SetBall(false)
state=e:ReadPossession(F.own.Character);assert(state=='Loose','other court holder cannot masquerade as steal')
assert(e.MatchOpponent==F.enemy,'opponent identity survives shot/turnover')
F.own.Character.ball=F.container(F.own.Character,true);e:ReadPossession(F.own.Character)
local ownBall=e.PossessionBall;assert(ownBall,'own ball identity recorded')
e:StartShotTrack('Shot',F.own.Character,F.goal);F.own.Character.ball:SetBall(false);ownBall.Owner=nil;ownBall.Position=v(48,15,0);F.balls={ownBall}
F.world.DescendantAdded:Fire(ownBall);e.Clock=1;e:TrackShot();e.Clock=1.2;e:TrackShot()
assert(e.ShotsReleased==1 and e.ShotTrack.Ball==ownBall,'release tracked despite global stranger holder')
ownBall.AssemblyLinearVelocity=v(-10,0,0);e:RecoveryStep(F.own.Character,F.oh,F.root)
assert(e.RecoveryBall==ownBall and e.RecoveryTarget.X<ownBall.Position.X,'rebound anticipates flight')
assert(e:GoalLabel(F.goal)~=e:GoalLabel(F.farGoal),'goal diagnostics include coordinates')
e:LockMatch(F.farGoal);assert(e.MatchOpponent==nil and e.MatchGoal==F.farGoal,'explicit court correction')
-- Dunk input must not stop the approach or pretend an animation began.
e:LockMatch(F.goal);F.root.Position=v(8,3,0);F.own.Character.ball=F.container(F.own.Character,true)
e.OffenseCharacter=F.own.Character;e.OffenseGoal=F.goal;e:OffenseStep(F.own.Character,F.oh,F.root)
assert(e.DunkAttempts==1 and e.AutoMovePoint and not e.DunkingUntil,'move and T together')
e:SetAutoPlay(false);assert(not next(e.DribbleKeys),'held keys cleaned on disable')
return 'PASS: court/opponent lock, global-holder rejection, real ball release/rebound, unique goal logs, court correction and moving dunk input'
'''
print(run(lua.replace('FIXTURE',fixture).replace('SOURCE','[====['+source+']====]')).decode())
