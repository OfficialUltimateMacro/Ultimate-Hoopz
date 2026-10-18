import ast,pathlib
from lua_runtime import run
folder=pathlib.Path(__file__).resolve().parent;source=(folder.parent/'Ultimate.Blessed.decoded.lua').read_text(encoding='utf-8')
t=ast.parse((folder/'test_ultimate_offense.py').read_text(encoding='utf-8'))
raw=next(ast.literal_eval(n.value.func.value) for n in t.body if isinstance(n,ast.Assign) and any(isinstance(x,ast.Name) and x.id=='lua' for x in n.targets))
lua=raw.split('local s={AutoGuard=true')[0]+r'''
e:Install(env,{Aimbot=true,AutoGuard=true,AutoGuardKeybind='L'});e:SetAutoPlay(true)
e.Clock=10;assert(e:PulseDribble('R'));local first=e.DribbleKeys.R;assert(math.abs(first-10.04)<.001)
e.Clock=10.05;assert(not e:PulseDribble('F'),'minimum global spacing');e:ReleaseDribbleKeys(true)
e.Clock=10.11;assert(e:PulseDribble('F'),'second move after .11s');e:ReleaseDribbleKeys(true)
e.Clock=10.22;assert(e:PulseDribble('G'));e:ReleaseDribbleKeys(true)
e.Clock=10.36;assert(not e:PulseDribble('G'),'same move has separate cooldown')
e.Clock=10.41;assert(e:PulseDribble('R'),'R returns after .4s');e:ReleaseDribbleKeys(true)
own.Character.ball=part(root.Position+v(0,0,-1));e.AutoMovePoint=root.Position+v(0,0,8)
e.OpponentReads={{Position=root.Position+v(-10,0,0),Predicted=root.Position+v(-10,0,0),Velocity=v(),Airborne=false}}
e.Clock=12;runService.bindings[e.RenderName](1/60);assert(e.LastDribble==12,'render dispatches without planner tick')
e:ReleaseDribbleKeys(true);e.Clock=12.11;runService.bindings[e.RenderName](1/60);assert(e.LastDribble==12.11,'cached route allows next move between planning scans')
e:ReleaseDribbleKeys(true);local n=#keys;input.down.W=true;e.Clock=12.3;runService.bindings[e.RenderName](1/60);assert(#keys==n,'manual movement pauses render dribble')
input.down.W=nil;e:SetAutoPlay(false);assert(not next(e.DribbleKeys),'disable releases all keys')
return 'PASS: .10s move spacing, .20s same-move and .40s R cooldown, .04s holds, render cadence independent of route planner, manual pause and cleanup'
'''
print(run(lua.replace('SOURCE','[====['+source+']====]')).decode())
