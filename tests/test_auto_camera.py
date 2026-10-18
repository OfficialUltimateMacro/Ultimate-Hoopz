import ast,pathlib
from lua_runtime import run
folder=pathlib.Path(__file__).resolve().parent
source=(folder.parent/'Ultimate.Blessed.decoded.lua').read_text(encoding='utf-8')
# Share the deterministic vector/world/services fixture, not its assertions.
tree=ast.parse((folder/'test_ultimate_offense.py').read_text(encoding='utf-8'))
raw=next(ast.literal_eval(n.value.func.value) for n in tree.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='lua' for t in n.targets))
setup=raw.split('local s={AutoGuard=true')[0]
lua=setup+r'''
local function frame(position,target)
 local f={Position=position,LookVector=(target-position)/math.max(.001,(target-position).Magnitude),RightVector=v(0,0,1)}
 function f:Lerp(other,alpha)assert(alpha>0 and alpha<=1);return other end
 return f
end
env.CFrame={lookAt=frame}
local s={Aimbot=true,AutoGuard=true,AutoGuardKeybind='L'};e:Install(env,s);e:SetAutoPlay(true)
own.Character.ball=part(root.Position+v(0,0,-1));oh.AutoRotate=true
root.CFrame=frame(root.Position,root.Position+v(-1,0,0))
local camera={CameraSubject=oh,CFrame=frame(root.Position+v(12,8,0),root.Position)};world.CurrentCamera=camera
e.OpponentReads={{Position=root.Position+v(-10,0,0),Predicted=root.Position+v(-10,0,0)}}
e.AutoMovePoint=root.Position+v(-8,0,8);local initialCamera=camera.CFrame
e:UpdateAutoFacing(.05);assert(oh.AutoRotate==false and camera.CFrame~=initialCamera,'camera and body turn near defender')
assert((root.CFrame.Position-root.Position).Magnitude<.001,'no positional teleport')
assert(root.CFrame.LookVector.Z>.4,'body faces chosen route')
input.GetMouseDelta=function()return {Magnitude=4}end;e:UpdateAutoFacing(.05)
assert(oh.AutoRotate==true and not e.AutoFacingHumanoid,'mouse motion yields control')
input.GetMouseDelta=function()return {Magnitude=0}end;e.Clock=1;e:UpdateAutoFacing(.05);assert(not oh.AutoRotate)
e.Shooting=true;e:UpdateAutoFacing(.05);assert(oh.AutoRotate,'release for original shot camera');e.Shooting=false
e:UpdateAutoFacing(.05);s.AutoPlayCamera=false;e:UpdateAutoFacing(.05);assert(oh.AutoRotate,'camera toggle off restores body')
s.AutoPlayCamera=true;e:UpdateAutoFacing(.05);input.down.W=true;e:UpdateAutoFacing(.05);assert(oh.AutoRotate,'manual movement restores')
input.down.W=nil;e.Clock=2;e:UpdateAutoFacing(.05);own.Character.ball=nil;e:UpdateAutoFacing(.05);assert(oh.AutoRotate,'lost possession restores')
own.Character.ball=part(root.Position);oh.AutoRotate=false;e:UpdateAutoFacing(.05);e:ReleaseAutoFacing();assert(oh.AutoRotate==false,'preserve original false')
-- Position-based settling handles a stationary body with stale velocity.
e.Settings.AimbotType='Low';e.OffenseCharacter=own.Character;e.OffenseGoal=goal;e.GoalDirection=v(1,0,0)
root.Position=v(math.sqrt(65*65-81),3,0);root.AssemblyLinearVelocity=v(9,0,0)
e.CanTakeShot=function()return true end;e.Clock=3
assert(not e:OffenseStep(own.Character,oh,root));e.Clock=3.25;assert(not e:OffenseStep(own.Character,oh,root));e.Clock=3.55
assert(e:OffenseStep(own.Character,oh,root),'stale velocity does not stall jump attempt')
e:Destroy()
return 'PASS: camera/body route alignment without teleport, mouse/manual/shot/possession/toggle cleanup, original AutoRotate preservation, stationary-position shot settling despite stale velocity'
'''
print(run(lua.replace('SOURCE','[====['+source+']====]')).decode())
