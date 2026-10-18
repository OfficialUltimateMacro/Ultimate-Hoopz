"""Scenarios reproduced from the 2026-10-17 23-00-29 live recording.
Usage: python tests/test_video_regressions.py [build.lua] [--report]
Each scenario asserts a tactical outcome (basket-side position, facing,
recovery, reaction time, camera distance/continuity, no idle controller).
Blessed's original guard (root.2138) and Ball Check selector (root.2115) are
approximated by stand-ins so older builds are compared fairly. Mock physics:
this reproduces decision logic, not Hoopz server behaviour."""
import pathlib,sys,json
from lua_runtime import run
folder=pathlib.Path(__file__).resolve().parent
args=[a for a in sys.argv[1:] if not a.startswith('--')]
report='--report' in sys.argv
target=pathlib.Path(args[0]) if args else folder.parent/'Ultimate.Blessed.decoded.lua'
source=target.read_text(encoding='utf-8');fixture=(folder/'sim_fixture.lua').read_text(encoding='utf-8')
lua=r'''
_G.ULTIMATE_BLESSED_INSPECT=true;bit32={}
local F=(function() FIXTURE end)()
local app=assert(load(SOURCE,'video','t',_G))();local e=app.Extensions
local v,C=F.v,F.count
local s={AutoGuard=true,AutoGuardKeybind='L',Aimbot=true,AimbotType='Low',BallMagnet=false,BallReach=true,AutoGuardJumpMatch=true,AutoGuardOffset=3}
local own,oh,root,enemy,er,eh=F.own,F.oh,F.root,F.enemy,F.er,F.eh
F.goal.Position=v(0,12,0);F.farGoal.Position=v(400,12,0)
-- Stand-in for Blessed's Ball Check selector (root.2115): a holder whose
-- Character.Basketball contains a Ball, within 50 studs.
local function selector()
 local best,bd=nil,50
 for _,pl in ipairs({enemy})do local c=pl.Character;local b=c and c.ball
  if b and b.FindFirstChild and b:FindFirstChild('Ball')then local d=(c.root.Position-F.root.Position).Magnitude;if d<=bd then best,bd=pl,d end end end
 return best
end
app.CustomizeClosure('root.2115',selector,F.env,{})
-- Stand-in for Blessed's guard loop (root.2138): every 0.15 s, unless we
-- have a Basketball container, MoveTo near the predicted handler.
local guard=app.CustomizeClosure('root.2138',function()
 if not s.AutoGuard then return end
 if F.own.Character:FindFirstChild('Basketball') then return end
 local t=selector();if not t then return end
 local tr=t.Character.root;local d=F.root.Position-tr.Position;local m=math.max(.01,d.Magnitude)
 F.oh:MoveTo(tr.Position+tr.AssemblyLinearVelocity*0.2+d/m*s.AutoGuardOffset)
end,F.env,{})
local guardClock=0
local function frame()
 guardClock=guardClock+1/60;if guardClock>=0.15 then guardClock=0;guard() end
 F.step(e,1/60)
end
e:Install(F.env,s)
local R={}
local function flat(a)return v(a.X,0,a.Z)end
local function unitf(a)local m=a.Magnitude;return m>0 and a/m or v(1,0,0)end
-- Basket-side quality: distance from the attacker->rim line and progress along it.
local function quality()
 local rim=v(F.goal.Position.X,F.root.Position.Y,F.goal.Position.Z);local a=er.Position
 local dir=unitf(flat(rim-a));local rel=flat(F.root.Position-a)
 local along=rel:Dot(dir);local lateral=(rel-dir*along).Magnitude
 return along,lateral,(flat(rim-a)).Magnitude
end
local function facing()
 local look=F.root.CFrame.LookVector;local to=unitf(flat(er.Position-F.root.Position))
 return look.X*to.X+look.Z*to.Z
end
local function setup(us,them,ownHolds)
 e:SetAutoPlay(false);F.queue={};F.speed=16
 F.root.Position=us;F.root.AssemblyLinearVelocity=v();F.oh.point=nil;F.root.CFrame=F.frame(us,us+v(-1,0,0))
 er.Position=them;er.AssemblyLinearVelocity=v();eh.FloorMaterial='Ground'
 own.Character.ball=F.container(own.Character,ownHolds)
 enemy.Character.ball=F.container(enemy.Character,not ownHolds)
 F.camera.CameraSubject=F.oh;F.camera.CFrame=F.frame(F.root.Position+v(10,7,0),F.root.Position+v(0,1.5,0))
 F.input.delta=nil;e.ManualUntil=0;e.CameraPauseUntil=nil
 -- independent scenarios: clear busy flags a previous scenario may leave
 e.Shooting=false;e.AimDepth=0;e.ShotTrack=nil;e.DunkingUntil=nil;own.Character.attrs.Action=nil
 e:SetAutoPlay(true);e.LastRootPosition=F.root.Position
end
local function ok(name,cond,detail)R[#R+1]={name=name,pass=cond and true or false,detail=detail};end
-- Prime the learned layout: we held Basketball.Ball once (as in the match).
setup(v(70,3,0),v(300,3,300),true);for i=1,6 do frame()end
-- S1 (2:18-2:31, 3:14-3:27): empty Basketball container left on us after a
-- turnover; opponent dribbles side to side 25-30 studs out.
setup(v(62,3,0),v(90,3,8),false)
local good,first=0,nil
for i=1,240 do
 local t=i/60;er.Position=v(90,3,8*math.sin(t*2.5));er.AssemblyLinearVelocity=v(0,0,20*math.cos(t*2.5))
 frame()
 local along,lat=quality()
 if along>0.5 and lat<3.5 then good=good+1;first=first or t end
end
ok('S1 stale container: defends basket-side vs dribbling attacker',first and first<1.5 and good>150,string.format('first good %.2fs, good frames %d/240',first or -1,good))
-- S2 (2:32): attacker behind/beside us while we face the basket, then drives past.
setup(v(40,3,0),v(52,3,4),false)
for i=1,30 do frame() end
ok('S2 turns to face attacker behind',facing()>0.8,string.format('facing dot %.2f',facing()))
local recovered=nil
for i=1,150 do
 local t=i/60;er.AssemblyLinearVelocity=v(-16,0,-6);er.Position=er.Position+er.AssemblyLinearVelocity/60
 frame();local along,lat=quality();if t>0.3 and along>0.5 and lat<4 and not recovered then recovered=t end
end
ok('S2 recovers basket-side after being beaten',recovered and recovered<2.0,string.format('recovered at %s',tostring(recovered)))
-- S3 (2:07-2:15): turnover then baseline drive to the rim.
setup(v(30,3,6),v(32,3,-10),true);for i=1,12 do frame() end
own.Character.ball:SetBall(false);enemy.Character.ball:SetBall(true)
local react,protect=nil,nil
local start=F.now
for i=1,120 do
 local t=i/60;local d=flat(F.goal.Position-er.Position);local m=d.Magnitude
 if m>3 then er.AssemblyLinearVelocity=d/m*15;er.Position=er.Position+er.AssemblyLinearVelocity/60 end
 frame()
 if not react and e.State=='Opponent' and F.oh.point then react=t end
 local along=quality();if along>0 and not protect then protect=t end
end
local along,lat,rimd=quality()
ok('S3 turnover reaction time',react and react<0.4,string.format('defense movement after %s s',tostring(react)))
ok('S3 baseline drive: ends rim-side of attacker',along>-1.5 and (flat(F.root.Position-F.goal.Position)).Magnitude<12,string.format('along %.1f, our rim distance %.1f',along,(flat(F.root.Position-F.goal.Position)).Magnitude))
-- S4: repeated left/right changes at the arc; lateral tracking error.
setup(v(48,3,0),v(62,3,0),false)
local err,n,m0=0,0,C.MoveTo
for i=1,360 do
 local t=i/60;er.Position=v(62,3,9*math.sin(t*5));er.AssemblyLinearVelocity=v(0,0,45*math.cos(t*5))
 if er.AssemblyLinearVelocity.Magnitude>32 then er.AssemblyLinearVelocity=er.AssemblyLinearVelocity/er.AssemblyLinearVelocity.Magnitude*32 end
 frame();if t>1 then local along,lat=quality();err=err+lat;n=n+1 end
end
ok('S4 left/right changes: mean lateral error',err/n<3.5,string.format('mean %.2f studs, MoveTo %d over 6s',err/n,C.MoveTo-m0))
-- S5: other court's hoop is nearer to us than the attacker's hoop.
F.farGoal.Position=v(70,12,60)
setup(v(55,3,40),v(45,3,0),false)
for i=1,180 do frame() end
local along5,lat5=quality()
ok('S5 defends the attacker hoop, not the nearest hoop',along5>0.5 and lat5<3,string.format('along %.1f lateral %.1f',along5,lat5))
F.farGoal.Position=v(400,12,0)
-- S6: steal -> defense within 0.3 s; S7 dribble reparent keeps possession.
setup(v(66,3,0),v(90,3,30),true);for i=1,30 do frame() end
local released0=e.ShotsReleased or 0;local flips=0;local st=e.State
own.Character.ball:SetBall(false);for i=1,6 do frame();if e.State~=st then flips=flips+1 end end;own.Character.ball:SetBall(true);for i=1,30 do frame();if e.State~=st then flips=flips+1 end end
ok('S7 brief dribble reparent: no possession flip or fake release',flips==0 and (e.ShotsReleased or 0)==released0,string.format('flips %d state %s',flips,tostring(e.State)))
-- S8: death during a pending shot clears busy flags and tracker.
setup(v(66,3,0),v(300,3,300),true);for i=1,5 do frame() end
e.Shooting=true;e.AimDepth=1;e.ShotTrack={Kind='Shot',Character=own.Character,Start=e.Clock,Released=false,MinDistance=math.huge}
F.oh.Health=0;for i=1,8 do frame() end;F.oh.Health=100
ok('S8 death during shot clears flags',not e.Shooting and (e.AimDepth or 0)==0 and e.ShotTrack==nil,string.format('shooting %s aim %s track %s',tostring(e.Shooting),tostring(e.AimDepth),tostring(e.ShotTrack)))
-- S9: stale Shooting Action on us does not freeze the controller forever.
setup(v(110,3,0),v(300,3,300),true);own.Character.attrs.Action='Shooting'
local moved=nil;local p0=F.root.Position
for i=1,300 do frame();if not moved and (F.root.Position-p0).Magnitude>2 then moved=i/60 end end
own.Character.attrs.Action=nil
ok('S9 stale game Action: resumes within bound',moved and moved<3.2,string.format('moved after %s s',tostring(moved)))
-- S10: mouse intervention during defense pauses camera only.
setup(v(48,3,0),v(70,3,10),false);for i=1,20 do frame() end
F.input.delta=v(4,0,0);local m1=C.MoveTo;local p1=F.root.Position
for i=1,40 do er.Position=er.Position+v(0,0,-0.25);er.AssemblyLinearVelocity=v(0,0,-15);frame() end
F.input.delta=nil
ok('S10 camera intervention keeps defending',(F.root.Position-p1).Magnitude>1 and e.AutoFacingHumanoid==nil,string.format('moved %.1f studs, facing released %s',(F.root.Position-p1).Magnitude,tostring(e.AutoFacingHumanoid==nil)))
-- S11/S12: camera distance continuity and no head-level close-ups when a
-- small unanchored ball/hitbox part sits on the camera ray.
F.world.hook=function(origin,d)
 if origin.Y>F.root.Position.Y+1 and d.Y>0.5 and d.Magnitude>5 and d.Magnitude<45 then return {Instance={Name='Ball',Transparency=0,Anchored=false,Size=v(2,2,2)},Position=origin+d.Unit*3,Normal=v(0,1,0)}end
end
setup(v(80,3,0),v(300,3,300),true)
F.camera.CFrame=F.frame(F.root.Position+v(0,1.5,0)+v(9,6,0),F.root.Position+v(0,1.5,0))
local minD,maxJump,prev=1e9,0,nil
local engaged,samples=0,0
local function sample()
 samples=samples+1;if e.AutoFacingHumanoid then engaged=engaged+1 end
 local d=(F.camera.CFrame.Position-(F.root.Position+v(0,1.5,0))).Magnitude;minD=math.min(minD,d)
 if prev then maxJump=math.max(maxJump,(F.camera.CFrame.Position-prev).Magnitude-(F.root.AssemblyLinearVelocity.Magnitude/60)) end
 prev=F.camera.CFrame.Position
end
for i=1,120 do frame();sample() end
-- turnover to defense, then steal back
own.Character.ball:SetBall(false);enemy.Character.ball:SetBall(true);er.Position=F.root.Position+v(-20,0,10)
for i=1,120 do frame();sample() end
enemy.Character.ball:SetBall(false);own.Character.ball:SetBall(true)
for i=1,120 do frame();sample() end
F.world.hook=nil
ok('S12 no close-up snaps from small parts on the camera ray',minD>=8 and engaged>samples*0.5,string.format('min camera radius %.2f, assist engaged %d/%d frames',minD,engaged,samples))
ok('S11 camera continuity across possessions',maxJump<2.5,string.format('max frame jump %.2f',maxJump))
-- Original shot routine: aims and restores the camera; assist stays off it.
setup(v(66,3,0),v(300,3,300),true);for i=1,30 do frame() end
local wrapper=app.CustomizeClosure('root.106',function()
 local saved=F.camera.CFrame
 F.camera.CFrame=F.frame(F.root.Position+v(0,3,5),F.goal.Position)
 local aimed=F.camera.CFrame;for i=1,6 do for _,f in pairs(F.run.bindings)do f(1/60)end end
 assert(F.camera.CFrame==aimed,'assist wrote camera during original aim')
 F.camera.CFrame=saved
end,F.env,{})
e.AutoJumpSuppressUntil=nil
local okShot=pcall(wrapper)
prev=nil;minD=1e9;maxJump=0;for i=1,30 do frame();sample() end
ok('S11 original shot camera restore respected, smooth resume',okShot and maxJump<2.5,string.format('ok %s max jump %.2f',tostring(okShot),maxJump))
-- S13: justified stationary (good spot) vs stalled controller.
setup(v(56,3,0),v(62,3,0),false);for i=1,60 do frame() end
local m2=C.MoveTo;for i=1,180 do frame() end
ok('S13 holds a good spot without MoveTo spam',C.MoveTo-m2<=6,string.format('MoveTo %d in 3s; %s',C.MoveTo-m2,tostring(e.DefenseIntent)))
setup(v(20,3,40),v(70,3,0),false);F.speed=0;local before=#(e.EventLog or {})
for i=1,200 do frame() end;F.speed=16
local stalled=false;for _,line in ipairs(e.EventLog or {})do if tostring(line):find('stalled')then stalled=true end end
ok('S13 stalled controller detected and re-issued',stalled,'watchdog log present: '..tostring(stalled))
-- S14: competing movement writers (Auto Guard re-enabled during Auto-play).
setup(v(48,3,0),v(70,3,10),false);s.AutoGuard=true
local writes={};local orig=F.oh.MoveTo;F.oh.MoveTo=function(h,p)writes[#writes+1]=p;orig(h,p)end
for i=1,60 do frame() end;F.oh.MoveTo=orig
local flipflop=0;for k=3,#writes do local a,b,c=writes[k-2],writes[k-1],writes[k];if (a-b).Magnitude>3 and (b-c).Magnitude>3 and (a-c).Magnitude<1 then flipflop=flipflop+1 end end
ok('S14 single movement writer during Auto-play',flipflop==0,string.format('alternating writes %d of %d',flipflop,#writes))
s.AutoGuard=false
-- S15: long run with alternating possession, respawns and toggles.
local hb0=F.run.Heartbeat:Count();local gc0=collectgarbage('count')
for cycle=1,20 do
 setup(v(60+cycle,3,0),v(80,3,10),cycle%2==0)
 for i=1,180 do er.Position=v(80,3,10*math.sin(i/30));frame() end
 if cycle%4==0 then local pl,h2,r2=F.player(F.root.Position,'Me');own.Character=pl.Character;F.oh=h2;F.root=r2;F.camera.CameraSubject=h2 end
end
collectgarbage();collectgarbage()
local grow=collectgarbage('count')-gc0
ok('S15 long run: no connection growth, bounded memory/log',F.run.Heartbeat:Count()==hb0 and #(e.EventLog or {})<=60 and grow<4096,string.format('heartbeat %d->%d, log %d, mem +%.0f KB',hb0,F.run.Heartbeat:Count(),#(e.EventLog or {}),grow))
e:Destroy()
local out={}
for _,r in ipairs(R)do out[#out+1]=string.format('{"name":%q,"pass":%s,"detail":%q}',r.name,tostring(r.pass),r.detail or '')end
return '['..table.concat(out,',')..']'
'''.replace('FIXTURE',fixture).replace('SOURCE','[====['+source+']====]')
results=json.loads(run(lua).decode())
for r in results: print(('PASS ' if r['pass'] else 'FAIL ')+r['name']+' -- '+r['detail'])
failed=[r for r in results if not r['pass']]
if report: print(json.dumps({'passed':len(results)-len(failed),'failed':len(failed)}))
elif failed: raise SystemExit(f'{len(failed)} scenario(s) failed')
else: print(f'PASS: all {len(results)} video-derived scenarios')
