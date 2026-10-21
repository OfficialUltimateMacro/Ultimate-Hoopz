"""Opponent tosses the ball up to himself (live clip pattern): Auto-play must
track the ball's landing point and keep guarding him, beat him to the ball
when it lands closer to us, and not treat his catch as a turnover. Shots
still use rebound mode. Mock physics only (gravity 196.2)."""
from pathlib import Path
from lua_runtime import run
folder=Path(__file__).resolve().parent
source=(folder.parent/'Ultimate.Blessed.decoded.lua').read_text(encoding='utf-8')
fixture=(folder/'sim_fixture.lua').read_text(encoding='utf-8')
lua=r'''_G.ULTIMATE_BLESSED_INSPECT=true;bit32={}
local F=(function() FIXTURE end)()
local app=assert(load(SOURCE,'toss','t',_G))();local e=app.Extensions;local v=F.v
local s={AutoGuardKeybind='L',Aimbot=true,AimbotType='High',ShotDelay=0.28}
e:Install(F.env,s);e.InputCaptures={[2]={Notification=function()return {new=function()end} end}}
e.AimAction=function()end
local function flat(a)return v(a.X,0,a.Z)end
local ball,bv=nil,nil
local function fly(dt)
 if ball and ball.Parent then
  bv=v(bv.X,bv.Y-196.2*dt,bv.Z);ball.Position=ball.Position+bv*dt
  if ball.Position.Y<=3 then ball.Position=v(ball.Position.X,3,ball.Position.Z);bv=v() end
  ball.AssemblyLinearVelocity=bv
 end
end
local function frames(n,each)for i=1,n do if each then each(i) end;fly(1/60);F.step(e,1/60) end end
local function setup(us,them)
 e:SetAutoPlay(false);F.queue={};F.root.Position=us;F.root.AssemblyLinearVelocity=v();F.oh.point=nil
 F.er.Position=them;F.er.AssemblyLinearVelocity=v();F.enemy.Character.attrs.Action=nil
 F.own.Character.ball=F.container(F.own.Character,false);F.enemy.Character.ball=F.container(F.enemy.Character,true)
 F.balls={};ball=nil;e.TossFrom=nil
 e:SetAutoPlay(true);e.LastRootPosition=F.root.Position
 frames(90)
end
local function toss(vel)
 F.enemy.Character.ball:SetBall(false)
 ball=F.part(F.er.Position+v(0,4,0),'Basketball');ball.Owner=nil;bv=vel;ball.AssemblyLinearVelocity=vel
 F.balls={ball};F.world.DescendantAdded:Fire(ball)
end
local function runTo(p,speed)
 return function()local d=flat(p-F.er.Position);local m=d.Magnitude
  if m>0.1 then local step=math.min(m,speed/60);F.er.Position=F.er.Position+d/m*step;F.er.AssemblyLinearVelocity=d/m*speed else F.er.AssemblyLinearVelocity=v() end end
end
local out={}
-- A. He throws it up over to the far side and runs after it: guard the catch.
setup(v(40,3,0),v(52,3,0))
assert(e.State=='Opponent','guarding before the toss')
toss(v(-10,70,-22))
local statuses={}
frames(40,function(i)runTo(v(45,3,-17),16)();statuses[tostring(e.AutoPlayStatus)]=true end)
local cut=false;for k in pairs(statuses)do if k:find('Toss: cutting off the catch') then cut=true end end
assert(cut,'guards the catch point while the ball is up')
for k in pairs(statuses)do assert(not k:find('Watching court'),'never idles while the ball is in the air') end
local land=e.TossFrom and e.RecoveryBall and e.RecoveryBall.Position
local rimSide=flat(F.root.Position).Magnitude<flat(F.er.Position).Magnitude+2
assert(rimSide,'stays on the rim side of the receiver')
out[#out+1]=string.format('catch-side gap %.1f',flat(F.root.Position-F.er.Position).Magnitude)
-- He catches his own toss: same possession, no turnover retreat.
frames(60,runTo(v(45,3,-17),16))
F.balls={};ball.Parent=nil;ball=nil;F.enemy.Character.ball:SetBall(true)
frames(30)
assert(e.State=='Opponent' and not e.TurnoverRetreat,'own catch is not a turnover retreat')
-- B. Toss that lands next to us while he is farther away: beat him to it.
setup(v(40,3,0),v(52,3,0))
toss(v(-14,55,0))
local beat=false
frames(45,function(i)if tostring(e.AutoPlayStatus):find('beating him') then beat=true end end)
assert(beat,'goes for a toss that lands closer to us')
-- C. A real shot (Action Shooting) is a rebound, not a toss.
setup(v(40,3,0),v(60,3,0))
F.enemy.Character.attrs.Action='Shooting';frames(6)
toss(v(-40,45,0))
F.enemy.Character.attrs.Action=nil
local tossy=false;frames(30,function()if tostring(e.AutoPlayStatus):find('Toss') then tossy=true end end)
assert(e.TossFrom and e.TossFrom.Shot and not tossy,'shots keep rebound handling')
e:SetAutoPlay(false)
return 'PASS: toss over the defender -> guards the catch on the rim side (no idle), own catch not a turnover, close toss contested, shots keep rebound mode | '..table.concat(out,'; ')
'''
print(run(lua.replace('FIXTURE',fixture).replace('SOURCE','[====['+source+']====]')).decode())
