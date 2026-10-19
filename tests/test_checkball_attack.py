"""Check-ball possession from a live log pattern: reset ~99 studs out with
the ball, defender ~18 studs away closing and shadowing with a 0.25 s
reaction delay. A steal happens if
the defender stays within STEAL studs for 0.3 s. The possession must reach jumper
range and shoot. Usage: python tests/test_checkball_attack.py [build.lua]
Mock movement only; real steal reach and acceptance are not modelled."""
import sys,json
from pathlib import Path
from lua_runtime import run
folder=Path(__file__).resolve().parent
target=Path(sys.argv[1]) if len(sys.argv)>1 else folder.parent/'Ultimate.Blessed.decoded.lua'
source=target.read_text();fixture=(folder/'sim_fixture.lua').read_text()
lua=r'''_G.ULTIMATE_BLESSED_INSPECT=true;bit32={}
local F=(function() FIXTURE end)()
local app=assert(load(SOURCE,'checkball','t',_G))();local e=app.Extensions;local v=F.v
local s={AutoGuard=true,AutoGuardKeybind='L',Aimbot=true,AimbotType='High',ShotDelay=0.28}
e:Install(F.env,s);e.InputCaptures={[2]={Notification=function()return {new=function()end} end}}
local shots=0;e.AimAction=function()shots=shots+1 end
local function flat(a)return v(a.X,0,a.Z)end
local results={};local STEAL=STEALR
for trial,side in ipairs({0,6,-6,12}) do
 e:SetAutoPlay(false);F.queue={};F.oh.point=nil;shots=0;e.LastShot=-100
 F.root.Position=v(99,3,side);F.root.AssemblyLinearVelocity=v()
 F.er.Position=v(81,3,side*0.5);F.er.AssemblyLinearVelocity=v()
 F.own.Character.ball=F.container(F.own.Character,true);F.enemy.Character.ball=F.container(F.enemy.Character,false)
 e:SetAutoPlay(true);e.LastRootPosition=F.root.Position
 local close,stolen,shotAt=0,false,nil;local hist={}
 for i=1,60*8 do
  -- Defender: close in at 15 studs/s to 3 studs in front (toward the rim), then shadow.
  -- Defender reacts to where we were 0.25 s ago (human + network delay).
  hist[#hist+1]=F.root.Position;local seen=hist[math.max(1,#hist-15)]
  local toRim=flat(F.goal.Position-seen);local m=math.max(.01,toRim.Magnitude)
  local want=seen+toRim/m*3
  local d=flat(want-F.er.Position);local dm=d.Magnitude
  local step=math.min(dm,15/60)
  if dm>0.01 then F.er.Position=F.er.Position+d/dm*step;F.er.AssemblyLinearVelocity=d/dm*15 else F.er.AssemblyLinearVelocity=v() end
  F.step(e,1/60)
  local gap=flat(F.er.Position-F.root.Position).Magnitude
  if gap<STEAL then close=close+1/60 else close=math.max(0,close-1/60) end
  if close>=0.3 then stolen=true;break end
  if shots>0 then shotAt=i/60;break end
 end
 results[#results+1]=string.format('{"side":%d,"shot":%s,"stolen":%s}',side,shotAt and string.format('%.2f',shotAt) or 'null',tostring(stolen))
end
e:SetAutoPlay(false)
return '['..table.concat(results,',')..']'
'''
import os
steal=os.environ.get('STEAL','6')
r=json.loads(run(lua.replace('STEALR',steal).replace('FIXTURE',fixture).replace('SOURCE','[====['+source+']====]')).decode())
print(json.dumps(r))
shot=sum(1 for x in r if x['shot'] is not None)
print(f'{shot}/{len(r)} check-ball possessions reached range and shot')
if len(sys.argv)==1:
    assert shot==len(r),'check-ball possession must reach range and shoot before a steal'
    assert all(x['shot']<=5.0 for x in r),'shot within 5 s of the reset'
    print('PASS: check-ball attack reaches jumper range and shoots before a closing defender steals')
