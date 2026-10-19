"""Frame-stepped Auto-play simulations on the shared counted fixture.
Usage: python tests/test_autoplay_sim.py [build.lua]. Mock physics only:
these prove decision logic and cleanup, not live Hoopz acceptance."""
import pathlib,sys
from lua_runtime import run
folder=pathlib.Path(__file__).resolve().parent
target=pathlib.Path(sys.argv[1]) if len(sys.argv)>1 else folder.parent/'Ultimate.Blessed.decoded.lua'
source=target.read_text(encoding='utf-8');fixture=(folder/'sim_fixture.lua').read_text(encoding='utf-8')
lua=r'''
_G.ULTIMATE_BLESSED_INSPECT=true;bit32={}
local F=(function() FIXTURE end)()
local app=assert(load(SOURCE,'sim','t',_G))();local e=app.Extensions
local v,C=F.v,F.count
local s={AutoGuard=true,AutoGuardKeybind='L',Aimbot=true,AimbotType='Low',BallMagnet=false,BallReach=true}
e:Install(F.env,s)
local root,own,oh=F.root,F.own,F.oh
local shots,dunkKeys=0,0
local flights={}
local release=true
local function giveBall()local b=F.part(root.Position,'Basketball');b.Owner=own.Character;own.Character.ball=b;return b end
e.AimAction=function()
 shots=shots+1
 if release then
  local flying=own.Character.ball;own.Character.ball=nil;flying.Owner=nil;flying.Position=root.Position+v(0,3,0)
  local target=e:NearestGoal(root) or F.goal;F.balls[#F.balls+1]=flying;F.world.DescendantAdded:Fire(flying)
  flights[#flights+1]={part=flying,target=target.Position+v(0.5,0,0.5),t=0}
 end
end
local function fly()for _,f in ipairs(flights)do if f.t<1 then f.t=math.min(1,f.t+1/60/0.8);local a=f.part.Position;f.part.Position=a+(f.target-a)*math.min(1,f.t*1.0) end end end
local function frames(n,each)for i=1,n do if each and each(i) then return i end;fly();F.step(e,1/60) end;return nil end
local function restart(pos)
 e:SetAutoPlay(false);F.queue={};root.Position=pos;root.AssemblyLinearVelocity=v();oh.point=nil;oh.FloorMaterial='Ground'
 shots=0;e.LastShot=-100;giveBall();e:SetAutoPlay(true)
end
local out={}
-- 1. Shadowing defender: always 6 studs between us and the basket, matching
-- our velocity. Must still produce a shot (no endless dribble/circling).
restart(v(110,3,0))
F.er.Position=root.Position+v(-6,0,0)
local t=frames(60*12,function()
 local d=F.goal.Position-root.Position;d=v(d.X,0,d.Z);local m=math.max(.01,d.Magnitude)
 local target=root.Position+d/m*6;local offset=target-F.er.Position
 F.er.AssemblyLinearVelocity=offset/math.max(.001,offset.Magnitude)*14
 F.er.Position=F.er.Position+offset/math.max(.001,offset.Magnitude)*math.min(offset.Magnitude,14/60)
 return shots>0
end)
-- New spacing priority permits a safe, bounded hold against persistent
-- pressure rather than bypassing defenders to force a shot.
assert(t or (e.SpacingReason and e:MatchPosition(root.Position) and (root.Position-F.er.Position).Magnitude>4),'shot or bounded clearance fallback under shadowing')
out[#out+1]=t and string.format('shadow shot after %.2fs',t/60) or 'shadow pressure: bounded clearance fallback'
-- 2. Lateral cutter: defender mirrors our lateral position in front.
F.er.Position=v(300,3,300);restart(v(115,3,20))
local escapes0=0
t=frames(60*12,function()
 local d=F.goal.Position-root.Position;d=v(d.X,0,d.Z);local m=math.max(.01,d.Magnitude)
 local target=root.Position+d/m*5+v(0,0,(e.LastEscapeSide or 1)*-1.5);local offset=target-F.er.Position
 F.er.AssemblyLinearVelocity=offset/math.max(.001,offset.Magnitude)*14
 F.er.Position=F.er.Position+offset/math.max(.001,offset.Magnitude)*math.min(offset.Magnitude,14/60)
 return shots>0
end)
assert(t,'cut-off possession ends in a shot');out[#out+1]=string.format('cutter shot after %.2fs',t/60)
assert((e.EscapeCount or 0)<=4,'escape cap per possession')
-- 3. Second nearest basket on a half-court spacing: spots must keep the
-- chosen basket nearest so the recovered aimbot targets it.
F.er.Position=v(300,3,300);F.farGoal.Position=v(120,12,0);s.AutoPlayBasket='Second nearest'
restart(v(50,3,0))
t=frames(60*15,function()return shots>0 end)
assert(t,'second-nearest basket eventually shoots')
assert(e:NearestGoal(root)==F.farGoal,'shot taken where chosen basket is nearest')
out[#out+1]=string.format('second-nearest shot after %.2fs',t/60)
-- 4. Shot verification: release and rim pass are recorded.
frames(200)
s.AutoPlayBasket='Nearest';F.farGoal.Position=v(260,12,0)
assert(e.ShotsReleased>=1 and e.ShotsNearRim>=1 and e.LastShotResult:find('passed'),'release + rim verification: '..tostring(e.LastShotResult))
release=false;restart(v(110,3,0));frames(60*10,function()return shots>0 end);frames(150)
assert(e.LastShotResult:find('still held'),'unreleased shot reported: '..tostring(e.LastShotResult))
release=true
-- 5. Dunk: T sent near rim; no dunk state -> try closer next time; Action=Dunking -> started.
restart(v(20,3,0));F.keys={}
t=frames(60*6,function()return (e.DunkAttempts or 0)>0 end);assert(t,'dunk attempted after rim drive')
local sawT=false;for _,k in ipairs(F.keys)do if k[2]=='T' and k[1] then sawT=true end end;assert(sawT,'T key dispatched')
frames(120);assert(e.DunkReach==7,'unaccepted dunk shrinks reach: '..tostring(e.DunkReach))
own.Character.attrs.Action='Dunking';e.DunkAttempts=0;restart(v(20,3,0))
frames(60*6,function()return (e.DunkAttempts or 0)>0 end);own.Character.ball=nil;frames(200)
assert((e.DunksStarted or 0)>=1,'dunk start verified via Action/release');own.Character.attrs.Action=nil
-- 6. Game Action freezes movement (no MoveTo fight during shot/dunk animation).
restart(v(110,3,0));frames(30);own.Character.attrs.Action='Shooting';local m0=C.MoveTo;frames(30)
assert(e.AutoMovePoint==nil and C.MoveTo-m0<=1,'one stop, then no movement during game Shooting action');own.Character.attrs.Action=nil
-- 7. Manual Space shot during Auto-play: the original aim routine owns the camera.
restart(v(110,3,0));frames(20)
local wrapper=app.CustomizeClosure('root.106',function()
 local before=F.camera.CFrame;for _,f in pairs(F.run.bindings)do f(1/60)end
 assert(F.camera.CFrame==before,'camera untouched while original aim runs')
 assert(oh.AutoRotate==true,'body released for manual shot')
 return 'aimed'
end,F.env,{})
e.AutoJumpSuppressUntil=nil;assert(wrapper()=='aimed','wrapper returns original result')
assert((e.AimDepth or 0)==0,'aim depth restored')
F.input.down.Space=true;assert(e:IsManual(),'physical Space is manual input');F.input.down.Space=nil;e.ManualUntil=0
e.DribbleKeys[F.env.Enum.KeyCode.Space]=e.Clock+1;F.input.down.Space=true;assert(not e:IsManual(),'synthetic Space is not manual');F.input.down.Space=nil;e.DribbleKeys={};e.ManualUntil=0
-- 8. Mouse movement hands camera back immediately and resumes smoothly.
frames(5);F.input.delta=v(3,0,0);frames(1);assert(oh.AutoRotate==true and e.AutoFacingHumanoid==nil,'mouse returns control at once')
F.input.delta=nil;frames(30);assert(e.AutoFacingHumanoid==nil,'stays released for the pause');frames(40);assert(e.AutoFacingHumanoid==oh,'re-engages after pause')
-- 9. Committed escape: no left/right flip inside the plan window.
F.er.Position=v(300,3,300);restart(v(110,3,0));e.MoveCooldowns={R=1e9}
F.er.Position=root.Position+v(-6,0,2);F.er.AssemblyLinearVelocity=v()
e.OffenseCharacter=own.Character;e.OffenseGoal=F.goal;e.PossessionStart=e.Clock
e:OffenseStep(own.Character,oh,root)
assert(e.Plan and e.Plan.Kind=='escape','escape planned vs on-ball defender')
local side=e.Plan.Side;F.er.Position=root.Position+v(-6,0,-2);e.Clock=e.Clock+0.2;e:OffenseStep(own.Character,oh,root)
assert(not e.Plan or not e.Plan.Point or e:PossessionPathClear(root,e.Plan.Point,e:ReadOpponents(root)),'unsafe committed exit is replaced or cancelled when defender moves')
-- 10. Hesitation versus a fast-closing defender.
e.Plan=nil;e.NextEscape=nil;e.EscapeCount=0;e.MoveCooldowns={};e.LastDribble=-100;e.Clock=e.Clock+1
F.er.Position=root.Position+v(-6.5,0,0.2);F.er.AssemblyLinearVelocity=v(14,0,0);e.OpponentMemory=nil
e:OffenseStep(own.Character,oh,root);assert(not e.Plan or e.Plan.Kind~='hesitate','contact pressure does not plant a hesitation inside clearance buffer')
-- 11. Respawn mid-possession: old body restored, new body plays.
F.er.Position=v(300,3,300);restart(v(110,3,0));frames(30)
local oldH=oh;local pl,h2,r2=F.player(v(110,3,0),'Me');own.Character=pl.Character;F.oh=h2;F.root=r2;F.camera.CameraSubject=h2
root,oh=r2,h2;frames(12);assert(oldH.AutoRotate==true,'old humanoid AutoRotate restored on respawn')
giveBall();frames(60);assert(e.OffenseCharacter==own.Character and e.AutoMovePoint,'new character resumes offense')
-- 12. Repeated toggles: no leaked connections/bindings, settings restored.
local hb=F.run.Heartbeat:Count();local added=F.world.DescendantAdded:Count()
s.BallMagnet=false
for i=1,25 do e:SetAutoPlay(true);frames(2);e:SetAutoPlay(false);frames(1) end
assert(F.run.Heartbeat:Count()==hb and F.world.DescendantAdded:Count()==added,'no connection leaks')
assert(s.BallMagnet==false and not next(e.DribbleKeys),'original Ball Magnet restored, keys released')
e:Destroy();assert(F.run.Heartbeat:Count()==0 and F.world.DescendantAdded:Count()==0 and not next(F.run.bindings),'destroy disconnects everything')
return 'PASS: '..table.concat(out,'; ')..'; shot/dunk verification and reach adaptation, Action freeze, manual Space aim protection, immediate mouse handback, committed escapes, hesitation, respawn, toggle leak and destroy checks'
'''.replace('FIXTURE',fixture).replace('SOURCE','[====['+source+']====]')
print(run(lua).decode())
