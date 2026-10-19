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
local lock={locked=false}
function lock:GetIsMouseLocked()return self.locked end
function lock:OnMouseLockToggled()self.locked=not self.locked end
own.PlayerScripts={FindFirstChild=function()return {} end}
env.require=function()return {GetCameras=function()return {activeMouseLockController=lock} end}end
local s={Aimbot=true,AutoGuard=true,AutoGuardKeybind='L'};e:Install(env,s);e:SetAutoPlay(true)
world.Raycast=function()return nil end
own.Character.ball=part(root.Position+v(0,0,-1));oh.AutoRotate=true
root.CFrame=frame(root.Position,root.Position+v(-1,0,0))
local camera={CameraSubject=oh,CFrame=frame(root.Position+v(12,8,0),root.Position)};world.CurrentCamera=camera
e.OpponentReads={{Position=root.Position+v(-10,0,0),Predicted=root.Position+v(-10,0,0)}}
e.AutoMovePoint=root.Position+v(-8,0,8);local initialCamera=camera.CFrame
e.OffenseGoal=goal
local originalRootFrame=root.CFrame
e:UpdateAutoFacing(.05);assert(oh.AutoRotate and lock.locked and camera.CFrame~=initialCamera,'native shift-lock and camera engage')
for _=1,20 do e:UpdateAutoFacing(1/60) end
assert(root.CFrame==originalRootFrame,'script must not force root orientation')
local want=e:DesiredFacing(root)
assert(e.ProtectFacing and want.X>0.95,'turn back toward close defender')
local d0=(camera.CFrame.Position-root.Position).Magnitude
for _=1,240 do e:UpdateAutoFacing(1/60) end
local d1=(camera.CFrame.Position-root.Position).Magnitude
assert(math.abs(d1-d0)<1.5 and d1>=10,'camera radius stable, no creeping zoom-in ('..d0..'->'..d1..')')
assert(camera.CFrame.Position.Y>root.Position.Y+5,'elevated court view')
local toGoal=goal.Position-root.Position;local lk=camera.CFrame.LookVector
assert(lk.X>0.8,'shift-lock camera looks away from defender to shield ball')
e.OpponentReads={};e.PreparingShot=true;for _=1,180 do e:UpdateAutoFacing(1/60) end
lk=camera.CFrame.LookVector;assert((lk.X*toGoal.X+lk.Z*toGoal.Z)>0,'resume basket view for shot setup')
local before=camera.CFrame.Position;e.AutoMovePoint=root.Position+v(8,0,-8);e:UpdateAutoFacing(1/60);e.AutoMovePoint=root.Position+v(-8,0,8);e:UpdateAutoFacing(1/60)
assert((camera.CFrame.Position-before).Magnitude<1,'route flips do not jerk camera')
input.GetMouseDelta=function()return {Magnitude=4}end;e:UpdateAutoFacing(.05)
assert(oh.AutoRotate==true and not e.AutoFacingHumanoid,'mouse motion yields control')
input.GetMouseDelta=function()return {Magnitude=0}end;e.Clock=1;e:UpdateAutoFacing(.05);assert(oh.AutoRotate and lock.locked)
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
return 'PASS: eased body yaw, stable elevated basket-facing camera (no zoom creep or route-flip jerk), no teleport, mouse/manual/shot/possession/toggle cleanup, original AutoRotate preservation, stationary-position shot settling despite stale velocity'
'''
print(run(lua.replace('SOURCE','[====['+source+']====]')).decode())
