"""Auto-play prediction tuning, motion reads and defense wiring.
Deterministic mock-world checks only: they verify bounds, resets, caps,
routing and cleanup, plus a synthetic prediction-error comparison. They do
not measure live Hoopz behaviour or network latency."""
from pathlib import Path
from lua_runtime import run
folder=Path(__file__).resolve().parent
source=(folder.parent/'Ultimate.Blessed.decoded.lua').read_text(encoding='utf-8')
fixture=(folder/'sim_fixture.lua').read_text(encoding='utf-8')
lua=r'''_G.ULTIMATE_BLESSED_INSPECT=true;bit32={}
local F=(function() FIXTURE end)()
local app=assert(load(SOURCE,'prediction','t',_G))();local e=app.Extensions;local v=F.v
local nan,inf=0/0,math.huge
local s={AutoGuardKeybind='L',Aimbot=true,AimbotType='High',AutoPlayPrediction=nan,AutoPlayPredictionSmoothing=inf,
 AutoPlayMaxLead=-inf,AutoPlayDefenseSpacing=0,AutoPlayContestDistance='99',AutoPlayAdaptivePrediction='yes'}
e:Install(F.env,s)
local out={}
-- 1. Install-time sanitising: NaN/inf/zero/strings -> default or clamp.
assert(s.AutoPlayPrediction==300 and s.AutoPlayPredictionSmoothing==35 and s.AutoPlayMaxLead==12,'NaN/inf fall back to defaults')
assert(s.AutoPlayDefenseSpacing==2 and s.AutoPlayContestDistance==12,'zero and out-of-range strings clamp')
assert(s.AutoPlayAdaptivePrediction==true,'adaptive defaults on for non-boolean')
-- 2. Slider callbacks clamp, and a minimal section without NewSlider is fine.
local sliders,toggles={},{}
local section={NewSlider=function(_,d)assert(d.Suffix==nil,'no Suffix (Blessed slider rejects strings)');sliders[(d.Title:gsub(' %(.*%)$',''))]=d end,NewToggle=function(_,d)toggles[d.Title]=d end}
e:InstallPredictionControls(section)
assert(sliders['Auto-play prediction'] and sliders['Defense close-out spacing'] and toggles['Adaptive Auto-play prediction'],'controls created')
local p=sliders['Auto-play prediction']
p.Callback(nan);assert(s.AutoPlayPrediction==300,'slider NaN -> default')
p.Callback(inf);assert(s.AutoPlayPrediction==300,'slider inf -> default')
p.Callback(-5);assert(s.AutoPlayPrediction==0,'slider negative clamps to 0')
p.Callback(5000);assert(s.AutoPlayPrediction==600,'slider clamps to 600')
p.Callback(250);assert(s.AutoPlayPrediction==250 and e:AutoPlayOption('AutoPlayPrediction')==250,'slider value applied')
toggles['Adaptive Auto-play prediction'].Callback(false);assert(s.AutoPlayAdaptivePrediction==false,'adaptive toggle')
toggles['Adaptive Auto-play prediction'].Callback(true)
assert(pcall(e.InstallPredictionControls,e,{NewToggle=function()end}),'section without sliders tolerated')
assert(e:SetAutoPlayOption('NotAnOption',5)==nil,'unknown option ignored')
-- 3. Settings-table rebind: a new table is sanitised and read immediately.
local s2={AutoGuardKeybind='L',AutoPlayPrediction=450}
e:Install(F.env,s2);assert(e.Settings==s2 and s2.AutoPlayDefenseSpacing==4 and e:AutoPlayOption('AutoPlayPrediction')==450,'rebind sanitises new table')
s=s2
-- 4. Horizons: adaptive defensive lead reproduces the old 0.2-0.5 s curve at 300 ms.
s.AutoPlayPrediction=300
assert(math.abs(e:PredictionLead(0,true)-0.2)<1e-9 and math.abs(e:PredictionLead(15,true)-0.5)<1e-9,'adaptive = previous defaults')
s.AutoPlayAdaptivePrediction=false
assert(math.abs(e:PredictionLead(0,true)-0.3)<1e-9 and math.abs(e:PredictionLead(40,true)-0.3)<1e-9,'fixed horizon ignores gap')
s.AutoPlayPrediction=0;assert(e:PredictionLead(20,true)==0,'0 ms disables lead')
s.AutoPlayAdaptivePrediction=true;s.AutoPlayPrediction=600;assert(e:PredictionLead(50,true)<=0.6,'adaptive lead bounded')
s.AutoPlayPrediction=300
-- 5. Motion reads: steady, stop, reversal, respawn, root change, teleport, stale, rollback, cap, invalid.
local pl={};local char={};local part={Position=v(50,3,0),AssemblyLinearVelocity=v(-16,0,0)}
e:ResetMotionReads();e.Clock=10
local vel,conf,why=e:MotionRead(pl,char,part);assert(conf==1 and vel.X<-15,'first read uses physics')
for i=1,6 do e.Clock=e.Clock+0.05;part.Position=part.Position+v(-0.8,0,0);vel,conf,why=e:MotionRead(pl,char,part) end
assert(conf==1 and math.abs(vel.X+16)<1.5,'steady motion ~16 studs/s ('..vel.X..')')
local before=vel;vel,conf,why=e:MotionRead(pl,char,part);assert(vel==before,'same-frame cache')
part.AssemblyLinearVelocity=v(0.2,0,0);e.Clock=e.Clock+0.05;vel,conf,why=e:MotionRead(pl,char,part)
assert(vel.Magnitude<1e-6 and why=='stopped','stop rejects old motion')
part.AssemblyLinearVelocity=v(-16,0,0);e.Clock=e.Clock+0.05;e:MotionRead(pl,char,part)
part.AssemblyLinearVelocity=v(16,0,0);e.Clock=e.Clock+0.05;part.Position=part.Position+v(0.5,0,0);vel,conf,why=e:MotionRead(pl,char,part)
assert(why=='direction change' and conf<1 and vel.X>0,'crossover not averaged with old direction')
local newChar={};e.Clock=e.Clock+0.05;vel,conf,why=e:MotionRead(pl,newChar,part)
assert(conf==0 and vel.Magnitude==0,'respawn resets')
e.Clock=e.Clock+0.05;e:MotionRead(pl,newChar,part)
local newRoot={Position=part.Position,AssemblyLinearVelocity=part.AssemblyLinearVelocity};e.Clock=e.Clock+0.05
vel,conf=e:MotionRead(pl,newChar,newRoot);assert(conf==0,'root change resets')
e.Clock=e.Clock+0.05;e:MotionRead(pl,newChar,newRoot)
newRoot.Position=newRoot.Position+v(40,0,0);e.Clock=e.Clock+0.1;vel,conf,why=e:MotionRead(pl,newChar,newRoot)
assert(conf==0 and why=='position reset','teleport detected')
e.Clock=e.Clock+2;vel,conf,why=e:MotionRead(pl,newChar,newRoot);assert(conf==0,'stale sample resets')
e.Clock=e.Clock-5;vel,conf,why=e:MotionRead(pl,newChar,newRoot);assert(conf==0,'clock rollback resets')
newRoot.AssemblyLinearVelocity=v(300,0,0);e.Clock=e.Clock+0.05;vel=e:MotionRead(pl,newChar,newRoot)
assert(vel.Magnitude<=32+1e-6,'speed capped at 32')
newRoot.Position=v(nan,3,0);vel,conf,why=e:MotionRead(pl,newChar,newRoot);assert(conf==0 and why=='invalid motion','NaN position rejected')
-- 6. Lead-distance cap and confidence scaling.
s.AutoPlayMaxLead=3
local off=e:PredictionOffset(v(30,0,0),0.5,1);assert(math.abs(off.Magnitude-3)<1e-9,'max lead cap')
off=e:PredictionOffset(v(4,0,0),0.5,0.5);assert(math.abs(off.Magnitude-1)<1e-9,'adaptive scales by confidence')
s.AutoPlayAdaptivePrediction=false;off=e:PredictionOffset(v(4,0,0),0.5,0.5);assert(math.abs(off.Magnitude-2)<1e-9,'fixed ignores partial confidence')
off=e:PredictionOffset(v(4,0,0),0.5,0);assert(off.Magnitude==0,'zero confidence never predicts')
s.AutoPlayAdaptivePrediction=true;s.AutoPlayMaxLead=12
-- 7. Adjacent-court rejection.
F.farGoal.Position=v(120,12,0);e.MatchGoal=F.goal
local inside=e:BoundPredictedPosition(v(50,3,0),v(10,0,0));assert(inside.X==60,'on-court prediction kept')
local clipped=e:BoundPredictedPosition(v(55,3,0),v(20,0,0));assert(e:MatchPosition(clipped) and clipped.X<75,'prediction pulled back onto own court ('..clipped.X..')')
local held=e:BoundPredictedPosition(v(124,3,0),v(80,0,0));assert(e:MatchPosition(held) or held.X==124,'unsafe prediction falls back')
F.farGoal.Position=v(600,12,0)
-- 8. Defense uses Auto-play tuning (not AutoGuardPrediction).
local root,er=F.root,F.er
F.own.Character.ball=F.container(F.own.Character,false);F.enemy.Character.ball=F.container(F.enemy.Character,true)
e.Settings.AutoPlay=true
local function defend(myPos,hisPos,hisVel)
 root.Position=myPos;er.Position=hisPos;er.AssemblyLinearVelocity=hisVel or v();e:ResetMotionReads()
 e.Clock=e.Clock+0.2;e.OpponentReads=e:ReadOpponents(root);return e:DefenseStep(F.own.Character,F.oh,root,F.enemy)
end
s.AutoGuardPrediction=999
s.AutoPlayDefenseSpacing=4;local t4=defend(v(50,3,10),v(70,3,0))
s.AutoPlayDefenseSpacing=9;local t9=defend(v(50,3,10),v(70,3,0))
local d4,d9=(t4-er.Position).Magnitude,(t9-er.Position).Magnitude
assert(math.abs(d4-4)<0.6 and math.abs(d9-9)<0.6 and e.DefenseMode=='Close out','close-out spacing setting used ('..d4..','..d9..')')
s.AutoPlayDefenseSpacing=4
s.AutoPlayPrediction=0;local still=defend(v(50,3,10),v(70,3,0),v(0,0,16))
s.AutoPlayPrediction=500;local lead=defend(v(50,3,10),v(70,3,0),v(0,0,16))
assert(lead.Z-still.Z>2,'prediction slider moves the defensive spot ('..(lead.Z-still.Z)..')')
assert(e.LastDefensePrediction and e.LastDefensePrediction.Lead>0,'prediction recorded for status')
s.AutoPlayPrediction=300
F.enemy.Character.attrs.Action='Shooting';F.oh.Jump=false;e.LastJump=-100;F.oh.FloorMaterial='Ground'
s.AutoPlayContestDistance=4;defend(v(64,3,0),v(70,3,0));assert(not F.oh.Jump,'no contest beyond contest distance (6 > 4)')
s.AutoPlayContestDistance=9;e.LastJump=-100;defend(v(64,3,0),v(70,3,0));assert(F.oh.Jump,'contest inside contest distance')
F.enemy.Character.attrs.Action=nil;F.oh.Jump=false
-- 9. Blocked targets: wall in the way -> checked detour or hold; ray budget respected.
F.world.wallX=62;F.world.wallHalf=1.5
local t=defend(v(50,3,0),v(80,3,0))
assert(e.DefenseRaycasts<=25,'raycast budget per decision')
if t then assert(e:WalkClear(root.Position,t,e:MakeRayParams()) and e.DefenseRoute and e.DefenseRoute:find('detour'),'detour is checked')
else assert(tostring(e.DefenseIntent):find('blocked'),'hold when blocked') end
F.world.wallHalf=1000
t=defend(v(50,3,0),v(80,3,0));assert(t==nil and tostring(e.DefenseIntent):find('blocked') and e.LastDefenseTarget==nil,'fully walled: hold, no stale target')
F.world.wallX=nil;F.world.wallHalf=nil
-- 10. DefendedGoal with no eligible basket keeps the current one (old nil arithmetic).
e.MatchGoal=nil;e.DefenseGoal=F.goal
local far={Position=v(0,3,149),AssemblyLinearVelocity=v()}
local farGoal=F.farGoal.Position;F.farGoal.Position=v(5000,12,0)
local cs=F.env.game:GetService('CollectionService');local tagged=cs.GetTagged;cs.GetTagged=function()return{} end
local ok,res=pcall(e.DefendedGoal,e,far);cs.GetTagged=tagged;F.farGoal.Position=farGoal
assert(ok and res==F.goal,'no eligible basket: keep current, no error ('..tostring(res)..')')
-- 11. Cleanup: stopping Auto-play clears motion history.
e.OpponentMemory[F.enemy]={Time=1};e.Settings.AutoPlay=true;e:SetAutoPlay(false)
assert(next(e.OpponentMemory)==nil and e.LastDefensePrediction==nil,'stop clears motion state')
-- 12. Synthetic prediction error, 0.3 s ahead: old blend vs new reads.
local function path(kind,tt)
 if kind=='straight' then return v(80-16*tt,3,0),v(-16,0,0) end
 if kind=='crossover' then local per=0.6;local ph=math.floor(tt/per);local dir=(ph%2==0) and 1 or -1;local x=tt*0;local z=0
  for k=0,ph-1 do z=z+((k%2==0) and 1 or -1)*16*per end;z=z+dir*16*(tt-ph*per);return v(70-6*tt,3,z),v(-6,0,dir*16) end
 if kind=='stopgo' then local ph=math.floor(tt/0.8);local moving=ph%2==0;local base=math.floor((ph+1)/2)*0.8*16
  local x=80-base-(moving and 16*(tt-ph*0.8) or 0);return v(x,3,0),moving and v(-16,0,0) or v() end
end
local results={}
for _,kind in ipairs({'straight','crossover','stopgo'})do
 local memOld,errOld,errNew,n=nil,0,0,0
 e:ResetMotionReads();local who={};local ch={};local prt={}
 for i=0,240 do
  local tt=i/60;local pos,vel=path(kind,tt);prt.Position=pos;prt.AssemblyLinearVelocity=vel;e.Clock=100+tt
  -- old method (pre-change ReadOpponents)
  local ov=v(vel.X,0,vel.Z)
  if memOld then local el=e.Clock-memOld.Time;if el>=0.06 and el<=0.5 then local m=(pos-memOld.Position)/el;m=v(m.X,0,m.Z);if m.Magnitude<=45 then ov=ov*0.55+m*0.45 end end end
  if ov.Magnitude>32 then ov=ov*(32/ov.Magnitude) end
  if not memOld or e.Clock-memOld.Time>=0.06 then memOld={Time=e.Clock,Position=pos} end
  local nv,c=e:MotionRead(who,ch,prt)
  local newPred=pos+e:PredictionOffset(nv,0.3,c);local oldPred=pos+ov*0.3
  if i>=30 and i<=222 then local fut=path(kind,tt+0.3);errOld=errOld+(oldPred-fut).Magnitude;errNew=errNew+(newPred-fut).Magnitude;n=n+1 end
 end
 results[#results+1]=string.format('%s old %.2f new %.2f',kind,errOld/n,errNew/n)
 assert(errNew/n<=errOld/n*1.10+0.05,kind..' prediction error not worse than before')
end
e.MatchGoal=nil
return 'PASS: install/slider clamps (NaN/inf/0/strings), rebind, fixed vs adaptive horizons, stop/reversal/respawn/root/teleport/stale/rollback/invalid reads, speed+lead caps, adjacent-court bound, defense uses Auto-play spacing/prediction/contest settings, blocked-route detour or hold within 25 rays, DefendedGoal nil edge, cleanup | mean error studs @0.3s: '..table.concat(results,'; ')
'''
print(run(lua.replace('FIXTURE',fixture).replace('SOURCE','[====['+source+']====]')).decode())
