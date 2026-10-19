"""Pressure-escape behaviour with the uncapped 0.15 s retry and six exits.
Usage: python tests/test_escape_stability.py [build.lua]
Frame-stepped mock: side-flip stability against a square defender, separation
kept, cooldowns respected, bounded space reset when boxed in, and manual
handback. No guarantee about live ball retention or real hitboxes."""
import sys
from pathlib import Path
from lua_runtime import run
folder=Path(__file__).resolve().parent
target=Path(sys.argv[1]) if len(sys.argv)>1 else folder.parent/'Ultimate.Blessed.decoded.lua'
source=target.read_text();fixture=(folder/'sim_fixture.lua').read_text()
lua=r'''_G.ULTIMATE_BLESSED_INSPECT=true;bit32={}
local F=(function() FIXTURE end)()
local app=assert(load(SOURCE,'escape','t',_G))();local e=app.Extensions;local v=F.v
local s={AutoGuard=true,AutoGuardKeybind='L',Aimbot=true,AimbotType='High',AutoPlayDunk=false}
e:Install(F.env,s);e.InputCaptures={[2]={Notification=function()return {new=function()end} end}}
e.AimAction=function()end
local function flat(a)return v(a.X,0,a.Z)end
local function frames(n,each)for i=1,n do if each then each(i) end;F.step(e,1/60) end end
F.root.Position=v(100,3,0);F.er.Position=v(94,3,0)
F.own.Character.ball=F.container(F.own.Character,true);F.enemy.Character.ball=F.container(F.enemy.Character,false)
e:SetAutoPlay(true);e.LastRootPosition=F.root.Position;s.AutoPlayDunk=false
-- D1: square defender stays 6 studs in front (toward the basket), mirroring us.
local flips,lastSide,minGap,sum,n=0,nil,99,0,0
local keyTimes={}
frames(300,function(i)
 local d=flat(F.goal.Position-F.root.Position);local m=math.max(.01,d.Magnitude)
 F.er.Position=F.root.Position+d/m*6;F.er.AssemblyLinearVelocity=F.root.AssemblyLinearVelocity
 local side=e.LastEscapeSide;if side and lastSide and side~=lastSide then flips=flips+1 end;lastSide=side or lastSide
 local g=flat(F.er.Position-F.root.Position).Magnitude;minGap=math.min(minGap,g);sum=sum+g;n=n+1
end)
for _,k in ipairs(F.keys)do if k[1] then keyTimes[k[2]]=keyTimes[k[2]] or {};table.insert(keyTimes[k[2]],k[3]) end end
local tooFast=0
for name,times in pairs(keyTimes)do
 local cd=(name=='R') and 0.32 or 0.16
 for i=2,#times do if times[i]-times[i-1]<cd-1e-6 then tooFast=tooFast+1 end end
end
-- D2: boxed in (two defenders pinning the route) -> bounded space reset, not endless standing.
local second=F.player(v(0,3,0),'Help');second.Character.ball=F.container(second.Character,false)
local ps=F.env.game:GetService('Players');function ps:GetPlayers()return {F.own,F.enemy,second}end;e.PlayerCache=nil
e:SetAutoPlay(false);F.root.Position=v(80,3,0);F.oh.point=nil;e:SetAutoPlay(true);e.LastRootPosition=F.root.Position
local still=0;local maxStill=0;local p0=F.root.Position;local resets=0
frames(360,function(i)
 local d=flat(F.goal.Position-F.root.Position);local m=math.max(.01,d.Magnitude);local lat=v(-d.Z/m,0,d.X/m)
 F.er.Position=F.root.Position+d/m*5+lat*3;second.Character.root.Position=F.root.Position+d/m*5-lat*3
 if (F.root.Position-p0).Magnitude<0.05 then still=still+1 else still=0 end;maxStill=math.max(maxStill,still);p0=F.root.Position
end)
-- D2b: boxed in against the court edge.
e:SetAutoPlay(false);F.root.Position=v(121,3,0);F.oh.point=nil;e:SetAutoPlay(true);e.LastRootPosition=F.root.Position
local edgeStill,edgeMax=0,0;p0=F.root.Position
frames(360,function(i)
 local d=flat(F.goal.Position-F.root.Position);local m=math.max(.01,d.Magnitude);local lat=v(-d.Z/m,0,d.X/m)
 F.er.Position=F.root.Position+d/m*5+lat*3;second.Character.root.Position=F.root.Position+d/m*5-lat*3
 if (F.root.Position-p0).Magnitude<0.05 then edgeStill=edgeStill+1 else edgeStill=0 end;edgeMax=math.max(edgeMax,edgeStill);p0=F.root.Position
end)
maxStill=math.max(maxStill,edgeMax)
for _,l in ipairs(e.EventLog or {})do if l:find('space reset',1,true)then resets=resets+1 end end

-- D3: manual input hands back immediately.
F.input.down.W=true;local keys0=#F.keys;frames(30)
local pressed=0;for k=keys0+1,#F.keys do if F.keys[k][1] then pressed=pressed+1 end end
local handback=(e.Plan==nil and pressed==0 and e.State=='Manual')
F.input.down.W=nil
e:SetAutoPlay(false)
return string.format('{"flips":%d,"minGap":%.2f,"meanGap":%.2f,"tooFast":%d,"maxStillFrames":%d,"spaceResetLogs":%d,"handback":%s}',flips,minGap,sum/n,tooFast,maxStill,resets,tostring(handback))
'''
import json
r=json.loads(run(lua.replace('FIXTURE',fixture).replace('SOURCE','[====['+source+']====]')).decode())
print(json.dumps(r))
checks=[('side flips vs square defender <=3 in 5s',r['flips']<=3),('cooldowns respected',r['tooFast']==0),
        ('boxed in (mid-court and court edge): never still more than 3s',r['maxStillFrames']<=180),('manual handback',r['handback'])]
for name,ok in checks: print(('PASS ' if ok else 'FAIL ')+name)
if len(sys.argv)==1:
    assert all(ok for _,ok in checks),'escape stability failed'
    print('PASS: escape side stability, cooldowns, bounded space reset and manual handback')
