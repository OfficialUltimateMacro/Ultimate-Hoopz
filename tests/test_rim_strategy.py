"""Conditional rim strategy versus normal play, frame-stepped on the shared
fixture. Mock movement only: verifies decisions, positions and scoping."""
from pathlib import Path
from lua_runtime import run
folder=Path(__file__).resolve().parent
source=(folder.parent/'Ultimate.Blessed.decoded.lua').read_text()
fixture=(folder/'sim_fixture.lua').read_text()
lua=r'''_G.ULTIMATE_BLESSED_INSPECT=true;bit32={}
local F=(function() FIXTURE end)()
local app=assert(load(SOURCE,'rim','t',_G))();local e=app.Extensions;local v=F.v
local s={AutoGuard=true,AutoGuardKeybind='L',Aimbot=true,AimbotType='High',ShotDelay=0.28}
e:Install(F.env,s);e.InputCaptures={[2]={Notification=function()return {new=function()end} end}}
local shots=0;e.AimAction=function()shots=shots+1 end
local function flat(a)return v(a.X,0,a.Z)end
local function frames(n,each)for i=1,n do if each then each(i) end;F.step(e,1/60) end end
local function setup(us,them,who)
 e:SetAutoPlay(false);F.queue={};F.root.Position=us;F.root.AssemblyLinearVelocity=v();F.oh.point=nil
 F.er.Position=them;F.er.AssemblyLinearVelocity=v()
 F.own.Character.ball=F.container(F.own.Character,who=='us');F.enemy.Character.ball=F.container(F.enemy.Character,who=='them')
 F.balls={};shots=0;e.LastShot=-100
 e:SetAutoPlay(true);e.LastRootPosition=F.root.Position;e.ShotAttempts=0;e.DunkAttempts=0
end
local rim=v(0,3,0)
-- R1 offense: open at the jumper ring. Normal takes the jumper; the
-- conditional strategy drives to the rim and dunks instead.
setup(v(64,3,0),v(300,3,300),'us');frames(180)
assert(shots>=1,'normal play takes the open jumper')
s.AutoPlayRimOverride=true;setup(v(64,3,0),v(300,3,300),'us')
local start=flat(F.root.Position-rim).Magnitude
frames(150)
assert(shots==0 and e.AdaptiveRimOnly and e.DunkMode,'strategy prefers the drive over the jumper')
assert(flat(F.root.Position-rim).Magnitude<start-15,'strategy drives toward the rim')
frames(240)
assert((e.DunkAttempts or 0)>=1,'strategy dunks at the rim')
-- R1b bounded fallback: blocked rim lane for 2.5 s allows a space-checked jumper.
setup(v(64,3,0),v(300,3,300),'us');frames(2)
e:UpdateRimStrategy();assert(e.AdaptiveRimOnly,'override active');e.RimBlockedSince=e.Clock-3;e.OffenseCharacter=F.own.Character;e.OffenseGoal=F.goal;e.OpponentReads={}
e:OffenseStep(F.own.Character,F.oh,F.root)
assert(not e.DunkMode,'fallback jumper allowed after blocked lane')
local logged=false;for _,l in ipairs(e.EventLog)do if l:find('rim lane blocked',1,true)then logged=true end end;assert(logged,'fallback logged')
-- R2 defense: normal closes out near the attacker. With the rim strategy on,
-- an attacker INSIDE shooting range is still closed out (live clip: camping
-- under the rim gave a shooter open threes every possession).
s.AutoPlayRimOverride=false
setup(v(40,3,12),v(50,3,0),'them');frames(240)
local normalGap=flat(F.root.Position-F.er.Position).Magnitude
assert(normalGap<=7 and e.DefenseMode~=nil and not tostring(e.DefenseMode):find('Rim strategy'),'normal: close out near attacker ('..normalGap..')')
s.AutoPlayRimOverride=true;setup(v(40,3,12),v(50,3,0),'them');frames(240)
local gap=flat(F.root.Position-F.er.Position).Magnitude
assert(gap<=7 and tostring(e.DefenseMode):find('close out shooter'),'strategy: shooter in range is closed out ('..gap..', '..tostring(e.DefenseMode)..')')
local face=e.DefenseFacing;local want=flat(F.er.Position-F.root.Position).Unit
assert(face and face:Dot(want)>0.9,'still faces the attacker')
-- Lateral reaction on the close-out.
frames(120,function(i)F.er.Position=v(50,3,i*0.15) end)
local toRim=flat(F.root.Position-rim);local dir=flat(F.er.Position-rim).Unit
assert((toRim-dir*toRim:Dot(dir)).Magnitude<3,'close-out reacts laterally to the attacker')
-- R3 attacker beyond shooting range: wait on his line at the range edge
-- (<= 55 studs from the rim), not under the rim and not glued to him.
setup(v(10,3,0),v(100,3,0),'them');frames(60*4)
toRim=flat(F.root.Position-rim)
assert(tostring(e.DefenseMode):find('range edge') and toRim.Magnitude>=50 and toRim.Magnitude<=58,'waits at the range edge ('..toRim.Magnitude..')')
-- R3b he walks into range: closed out within about a second.
local closed,entered
frames(200,function(i)F.er.Position=v(math.max(66,100-i*0.27),3,0)
 if not entered and (F.goal.Position-F.er.Position).Magnitude<=80 then entered=i end
 if entered and not closed and flat(F.root.Position-F.er.Position).Magnitude<=7.5 then closed=i end end)
assert(entered and closed and closed-entered<=70,'closes out within ~1.2 s of the attacker entering range ('..tostring(entered)..'->'..tostring(closed)..', '..flat(F.root.Position-F.er.Position).Magnitude..')')
-- R4 attacker inside 20 studs -> normal rim protection/contest, not camping offsets.
setup(v(10,3,0),v(15,3,0),'them');frames(60)
assert(not tostring(e.DefenseMode):find('Rim strategy'),'normal rim protection inside 20 studs')
-- R5 loose ball while camping -> recover it.
setup(v(10,3,0),v(50,3,0),'them');frames(60)
F.enemy.Character.ball:SetBall(false);local loose=F.part(v(20,3,8),'Basketball');F.balls={loose};F.world.DescendantAdded:Fire(loose)
frames(60)
assert(e.State=='Loose' and e.RecoveryBall==loose,'loose ball recovery while strategy active')
-- R6 scoping: confirmation for one opponent does not apply to another.
s.AutoPlayRimOverride=false;s.AutoPlayMagnetResponse='Manual confirm'
e.PickupEvidence.Key=tostring(F.enemy.UserId or F.enemy.Name);e.RimConfirmedKey=e.PickupEvidence.Key
e.PickupEvidence.Events={{T=e.Clock,Excess=10,Possession=1},{T=e.Clock,Excess=10,Possession=2}}
e.MatchOpponent=F.enemy;e:UpdateRimStrategy();assert(e.AdaptiveRimOnly,'confirmed opponent: active')
local other=F.player(v(30,3,0),'Other');e.MatchOpponent=other;e:UpdateRimStrategy()
assert(not e.AdaptiveRimOnly,'different opponent: normal strategy')
e:SetAutoPlay(false)
return 'PASS: normal jumper vs strategy drive+dunk, bounded blocked-lane fallback, shooter in range closed out even under the strategy (facing, lateral), range-edge wait beyond range, close-out within 1.2 s of entering range, inside-20 normal contest, loose-ball recovery, opponent scoping'
'''
print(run(lua.replace('FIXTURE',fixture).replace('SOURCE','[====['+source+']====]')).decode())
