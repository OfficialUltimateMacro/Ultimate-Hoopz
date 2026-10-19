"""Suspected abnormal pickup evidence and conditional strategy selection.
Deterministic frame sampling on the shared fixture. Client-side logic only:
this verifies the evidence rules, not any live opponent's behaviour."""
from pathlib import Path
from lua_runtime import run
folder=Path(__file__).resolve().parent
source=(folder.parent/'Ultimate.Blessed.decoded.lua').read_text()
fixture=(folder/'sim_fixture.lua').read_text()
lua=r'''_G.ULTIMATE_BLESSED_INSPECT=true;bit32={}
local F=(function() FIXTURE end)()
local app=assert(load(SOURCE,'evidence','t',_G))();local e=app.Extensions;local v=F.v
local s={AutoGuard=true,AutoGuardKeybind='L',Aimbot=true,AimbotType='High'}
e:Install(F.env,s)
local notices={}
e.InputCaptures={[2]={Notification=function()return {new=function(t)notices[#notices+1]=t end} end}}
F.root.Position=v(60,3,10);F.er.Position=v(70,3,-10)
F.own.Character.ball=F.container(F.own.Character,true);F.enemy.Character.ball=F.container(F.enemy.Character,false)
e:SetAutoPlay(true)
assert(e.MatchGoal==F.goal,'court locked')
for k in pairs(notices)do notices[k]=nil end -- Auto Guard lock notice
assert(s.AutoPlayMagnetResponse=='Manual confirm' and s.AutoPlayRimOverride==false,'defaults: manual confirmation, no override')
local loose=F.part(v(40,3,0),'Basketball');loose.Owner=nil
local function sync()
 for _,pl in ipairs({F.own,F.enemy})do local c=pl.Character;local b=c.ball;if b and b.ballPart then b.ballPart.Position=c.root.Position+v(0,0,-1) end end
end
local function hold(who,at)
 F.own.Character.ball:SetBall(who=='us');F.enemy.Character.ball:SetBall(who=='them')
 if who=='loose' then loose.Parent=true;loose.Position=at or loose.Position;F.balls={loose};F.world.DescendantAdded:Fire(loose)
 else loose.Parent=nil;F.balls={} end
 sync()
end
local function tick(n,dt)for i=1,n do e.Clock=e.Clock+(dt or 1/60);sync();e:SamplePickups() end end
local function events()return #e.PickupEvidence.Events end
local function level()return (e:PickupLevel()) end
local function rejected(reason)for k,n in pairs(e.PickupEvidence.Rejected)do if k:find(reason,1,true) then return n end end;return 0 end
-- A loose ball far from the opponent appears in his hands on the next frame.
local function anomaly(gap)
 hold('us');tick(20)
 F.er.Position=v(65,3,0);F.er.AssemblyLinearVelocity=v();hold('loose',v(65-(gap or 25),3,0));tick(20)
 hold('them');tick(20)
end
-- 0. A static rack/decor ball on the court must not make every sample ambiguous.
local rack=F.part(v(30,3,30),'Basketball');rack.Owner=nil;F.world.DescendantAdded:Fire(rack)
local function hold2(who,at) hold(who,at);F.balls[#F.balls+1]=rack end
hold2('us');tick(10);F.er.Position=F.root.Position+v(3,0,0);tick(3);hold2('them');tick(10)
assert(e.PickupEvidence.Normal>=1,'evaluated despite a static rack ball on court')
local summary=e:EvidenceSummary();assert(summary:find('samples%['),'sampler diagnostics shown')
e.Clock=e.Clock+6
-- 1. Normal steals never add evidence (opponent in contact range).
for i=1,5 do
 hold('us');tick(20);F.er.Position=F.root.Position+v(3,0,0);tick(5);hold('them');tick(20);e.Clock=e.Clock+6
end
assert(events()==0 and e.PickupEvidence.Normal>=6 and level()=='none','normal steals are not evidence')
-- Contested/failed shot then nearby rebound: normal.
hold('loose',F.er.Position+v(6,0,0));tick(20);hold('them');tick(20)
assert(events()==0,'nearby rebound is normal')
-- 2. One anomalous pickup is insufficient.
e.Clock=e.Clock+10;anomaly(25)
assert(events()==1 and level()=='none','one anomaly is insufficient')
e:UpdateRimStrategy();assert(not e.AdaptiveRimOnly and #notices==0,'no prompt after one event')
-- 3. Duplicates and stale samples add nothing.
hold('loose',F.er.Position+v(0,0,-1));tick(10);hold('them');tick(10)
assert(events()==1,'dribble flicker in same possession not recounted')
e.Clock=e.Clock+8;hold('us');tick(20);F.er.Position=v(65,3,0);hold('loose',v(40,3,0));tick(20)
e.Clock=e.Clock+0.5;hold('them');tick(1)
assert(events()==1 and rejected('stale')>=1,'stale sample rejected')
-- 4. Resets are rejected: opponent teleport, made basket handover, ball teleport.
e.Clock=e.Clock+8;hold('us');tick(20);hold('loose',v(40,3,0));tick(20)
F.er.Position=v(65,3,40);tick(1);F.er.Position=v(65,3,0);tick(1);hold('them');tick(5)
assert(events()==1 and rejected('teleported')>=1,'teleport rejected')
e.Clock=e.Clock+8;hold('us');tick(20);hold('loose',v(0.5,13,0));tick(2);loose.Position=v(0.5,10,0);tick(2)
hold('them');tick(5)
assert(events()==1 and rejected('made-basket')>=1,'made-basket handover rejected')
e.Clock=e.Clock+8;hold('us');tick(20);hold('loose',v(40,3,0));tick(3);loose.Position=v(15,3,0);tick(1);hold('them');tick(5)
assert(events()==1 and rejected('ball teleported')>=1,'ball teleport (inbound) rejected')
-- Fast ball toward the opponent (pass/rebound in flight) is within allowance.
e.Clock=e.Clock+8;hold('us');tick(20);hold('loose',v(45,3,0));loose.AssemblyLinearVelocity=v(80,0,0);tick(3)
hold('them');tick(5);loose.AssemblyLinearVelocity=v()
assert(events()==1,'velocity allowance covers a fast incoming ball')
-- 5. Independent anomalies accumulate; manual mode prompts but does not act.
e.MatchOpponent=F.enemy
e.Clock=e.Clock+8;anomaly(26)
assert(events()==2 and level()=='suspected','two independent anomalies: suspected')
e:UpdateRimStrategy()
assert(not e.AdaptiveRimOnly and #notices==1 and notices[1].Title=='Suspected abnormal pickups','manual mode prompts only')
assert(not tostring(notices[1].Description):lower():find('cheat'),'never labelled a cheater')
e:UpdateRimStrategy();assert(#notices==1,'prompt not repeated for the same evidence')
assert(e:ConfirmSuspectedOpponent() and (e:UpdateRimStrategy()) and e.AdaptiveRimOnly,'manual confirmation activates')
assert(tostring(e.AdaptiveReason):find('suspected'),'reason shown')
-- 6. Decay: confirmation expires, normal strategy resumes.
e.Clock=e.Clock+400;e:UpdateRimStrategy()
assert(not e.AdaptiveRimOnly and e.RimConfirmedKey==nil and level()=='none','evidence decay exits the strategy')
-- 7. Auto mode needs strong evidence (3 independent, large excess).
s.AutoPlayMagnetResponse='Auto (experimental)'
anomaly(30);e.Clock=e.Clock+8;anomaly(30)
e:UpdateRimStrategy();assert(level()=='suspected' and not e.AdaptiveRimOnly,'auto ignores suspected')
e.Clock=e.Clock+8;anomaly(32);e:UpdateRimStrategy()
assert(level()=='strong' and e.AdaptiveRimOnly,'auto activates after strong repeated evidence')
e.Clock=e.Clock+250;e:UpdateRimStrategy();assert(not e.AdaptiveRimOnly,'auto exits when evidence decays')
-- 8. Off mode never acts; override acts without evidence and without accusing.
s.AutoPlayMagnetResponse='Off';e.Clock=e.Clock+8;anomaly(30);e.Clock=e.Clock+8;anomaly(30);e.Clock=e.Clock+8;anomaly(30)
e:UpdateRimStrategy();assert(not e.AdaptiveRimOnly,'off mode ignores evidence')
s.AutoPlayRimOverride=true;e:UpdateRimStrategy()
assert(e.AdaptiveRimOnly and tostring(e.AdaptiveReason):find('override'),'override works without accusation')
e:ClearRimStrategy();e:UpdateRimStrategy();assert(not e.AdaptiveRimOnly and s.AutoPlayRimOverride==false,'clear button resets')
-- 9. Scoping: evidence for another opponent / court change resets.
s.AutoPlayMagnetResponse='Manual confirm'
local other=F.player(v(80,3,0),'Second');other.Character.ball=F.container(other.Character,false)
local ps=F.env.game:GetService('Players');function ps:GetPlayers()return {F.own,F.enemy,other}end;e.PlayerCache=nil
e.MatchOpponent=other
hold('us');tick(20);hold('loose',v(40,3,0));tick(20);hold('them');tick(10)
assert(rejected('not the locked opponent')>=1,'pickups by a non-locked player are not counted for him')
e.MatchOpponent=nil;local before=events()
other.Character.ball:SetBall(true);F.enemy.Character.ball:SetBall(false);loose.Parent=nil;F.balls={};tick(1)
assert(events()==0 and rejected('direct transfer')>=1,'opponent switch resets evidence; a pass is not a pickup')
other.Character.ball:SetBall(false);hold('us');tick(5)
e:LockMatch(F.farGoal);tick(2)
assert(events()==0 and e.PickupEvidence.Goal==F.farGoal,'court change clears evidence')
local found=false;for _,line in ipairs(e.EventLog)do if line:find('reset: court changed',1,true)then found=true end end
assert(found,'court reset logged with reason')
local ok=e:ConfirmSuspectedOpponent();assert(not ok,'confirmation refused without evidence')
e:SetAutoPlay(false)
return 'PASS: normal steals/rebounds ignored, single anomaly insufficient, flicker/stale/teleport/made-basket/ball-teleport rejected, velocity allowance, suspected prompt without action, manual confirm, decay exit, auto needs strong, off mode, override without accusation, opponent/court scoping and reset'
'''
print(run(lua.replace('FIXTURE',fixture).replace('SOURCE','[====['+source+']====]')).decode())
