"""Counts engine calls and Lua CPU time over the same simulated 10 s scenarios.
Usage: python tests/test_performance.py [build.lua]  (default: current build).
Budgets assert the optimized build; pass an older build path to measure it
(budgets are then reported, not asserted). Mock CPU time is relative only."""
import json,pathlib,sys
from lua_runtime import run
folder=pathlib.Path(__file__).resolve().parent
target=pathlib.Path(sys.argv[1]) if len(sys.argv)>1 else folder.parent/'Ultimate.Blessed.decoded.lua'
source=target.read_text(encoding='utf-8');fixture=(folder/'sim_fixture.lua').read_text(encoding='utf-8')
lua=r'''
_G.ULTIMATE_BLESSED_INSPECT=true;bit32={}
local F=(function() FIXTURE end)()
local app=assert(load(SOURCE,'perf','t',_G))();local e=app.Extensions
local v,C=F.v,F.count
local s={AutoGuard=true,AutoGuardKeybind='L',Aimbot=true,AimbotType='Low',BallMagnet=false,BallReach=true}
e:Install(F.env,s);e:SetAutoPlay(true)
e.AimAction=function()end
local function reset()for k in pairs(C)do C[k]=nil end end
-- Separate planning (Heartbeat/Tick) from per-frame (render) work.
local planT,renderT,maxRender=0,0,0
local tick=e.Tick;e.Tick=function(self,dt)local t=os.clock();local a,b=tick(self,dt);planT=planT+(os.clock()-t);return a,b end
local function wrapRender()
 local f=F.run.bindings[e.RenderName];if not f or F.wrapped==f then return end
 local w=function(dt)local t=os.clock();f(dt);local d=os.clock()-t;renderT=renderT+d;if d>maxRender then maxRender=d end end
 F.run.bindings[e.RenderName]=w;F.wrapped=w
end
local function measure(frames,each)
 reset();wrapRender();planT,renderT,maxRender=0,0,0
 collectgarbage();collectgarbage();local m0=collectgarbage('count')
 local t=os.clock()
 for i=1,frames do each(i);F.step(e,1/60) end
 local r={cpu_ms=(os.clock()-t)*1000,plan_ms=planT*1000,render_ms=renderT*1000,render_max_us=maxRender*1e6}
 collectgarbage();collectgarbage();r.mem_kb_growth=collectgarbage('count')-m0
 r.heartbeat_connections=F.run.Heartbeat:Count();r.added_connections=F.world.DescendantAdded:Count()
 for k,n in pairs(C)do r[k]=n end;return r
end
-- A: holding the ball 100 studs out, defender shadowing between us and the goal.
local ball=F.part(F.root.Position,'Basketball');ball.Owner=F.own.Character;F.own.Character.ball=ball
local A=measure(600,function()
 local d=F.goal.Position-F.root.Position;d=v(d.X,0,d.Z);local m=math.max(.01,d.Magnitude)
 F.er.Position=F.root.Position+d/m*6;F.er.AssemblyLinearVelocity=F.root.AssemblyLinearVelocity
 e.LastShot=F.now or 0 -- keep it in the movement phase for a pure movement profile
end)
-- B: no ball, loose ball 30 studs away (pickup scanning).
F.own.Character.ball=nil;F.er.Position=v(300,3,300)
local loose=F.part(F.root.Position+v(0,0,30),'Basketball');loose.Owner=nil;F.balls[1]=loose
F.world.DescendantAdded:Fire(loose)
local B=measure(600,function()end)
-- C: defending a dribbling attacker 10 studs away (adaptive 20 Hz planning).
F.balls[1]=nil;loose.Parent=nil
F.enemy.Character.ball=F.container(F.enemy.Character,true);F.own.Character.ball=nil
local D=measure(600,function(i)
 F.er.Position=v(60,3,8*math.sin(i/20));F.er.AssemblyLinearVelocity=v(0,0,8*math.cos(i/20)*3)
end)
e:Destroy()
local function enc(t)local p={};for k,n in pairs(t)do p[#p+1]=string.format('"%s":%s',k,type(n)=='number' and string.format('%.3f',n) or tostring(n))end;table.sort(p);return '{'..table.concat(p,',')..'}'end
return '{"holding_ball_10s":'..enc(A)..',"seeking_ball_10s":'..enc(B)..',"defending_10s":'..enc(D)..'}'
'''.replace('FIXTURE',fixture).replace('SOURCE','[====['+source+']====]')
result=json.loads(run(lua).decode())
print(json.dumps(result,indent=1,sort_keys=True))
if len(sys.argv)==1:
    A,B=result['holding_ball_10s'],result['seeking_ball_10s']
    assert A.get('RaycastParams',0)<=25, 'ray params cached'
    assert A.get('Raycast',0)<=4000, 'raycast budget while dribbling'
    assert A.get('MoveTo',0)<=150, 'MoveTo only on meaningful changes'
    assert B.get('GetDescendants',0)<=1, 'no repeated full-workspace scans'
    assert A.get('GetTagged',0)<=20, 'goal list cached'
    D=result['defending_10s']
    assert D.get('MoveTo',0)<=400 and D.get('RaycastParams',0)<=25, 'defense call budget'
    assert D.get('heartbeat_connections',0)==1, 'single heartbeat connection'
    print('PASS: performance budgets')
