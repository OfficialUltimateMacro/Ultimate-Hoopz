import pathlib
from lua_runtime import run
source=(pathlib.Path(__file__).resolve().parents[1]/'Ultimate.Blessed.decoded.lua').read_text()
lua=r'''
_G.ULTIMATE_BLESSED_INSPECT=true;bit32={}
local app=assert(load(SOURCE,'offense simulation','t',_G))();local e=app.Extensions
local mt={}
local function v(x,y,z)return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},mt)end
mt.__add=function(a,b)return v(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
mt.__sub=function(a,b)return v(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
mt.__mul=function(a,b)if type(a)=='number'then a,b=b,a end;return v(a.X*b,a.Y*b,a.Z*b)end
mt.__div=function(a,b)return v(a.X/b,a.Y/b,a.Z/b)end
mt.__index=function(a,k)if k=='Magnitude'then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z)elseif k=='Dot'then return function(a,b)return a.X*b.X+a.Y*b.Y+a.Z*b.Z end end end
local function signal()local s={};function s:Connect(f)local c={Connected=true};function c:Disconnect()self.Connected=false end;return c end;return s end
local function part(pos)local p={Position=pos,Parent=true};function p:IsA(k)return k=='BasePart'end;return p end
local function player(pos)
 local r=part(pos);r.AssemblyLinearVelocity=v();r.CFrame={RightVector=v(0,0,1)}
 local h={Health=100,FloorMaterial='Ground',Jumping=signal(),moves=0};function h:MoveTo(p)self.point=p;self.moves=self.moves+1 end
 local c={Parent=true,root=r,h=h};function c:FindFirstChild(n)if n=='HumanoidRootPart'then return self.root elseif n=='Basketball'then return self.ball end end;function c:FindFirstChildOfClass()return self.h end
 return {Character=c,Neutral=true},h,r
end
local own,oh,root=player(v(100,3,0));local enemy,eh,er=player(v(200,3,200));local friend,fh,fr=player(v(104,3,0))
own.Team='blue';own.Neutral=false;friend.Team='blue';friend.Neutral=false
local players={LocalPlayer=own};function players:GetPlayers()return{own,enemy,friend}end
local input={down={}};function input:GetFocusedTextBox()return self.focus end;function input:IsKeyDown(k)return self.down[k]end
local runService={Heartbeat=signal(),bindings={}};function runService:BindToRenderStep(n,p,f)self.bindings[n]=f end;function runService:UnbindFromRenderStep(n)self.bindings[n]=nil end
local goal=part(v(0,12,0));local farGoal=part(v(220,12,0));local cs={goals={goal,farGoal}};function cs:GetTagged()return self.goals end
local world={wall=false,edge=false,blockShot=false}
function world:Raycast(origin,d,params)
 assert(params.FilterType=='Exclude' and #params.FilterDescendantsInstances==3 and params.RespectCanCollide)
 if d.Y < -8 and d.X==0 and d.Z==0 then
  if self.edge and origin.Z>1 then return nil end
  return {Position=v(origin.X,0,origin.Z),Normal=v(0,1,0),Material='Ground'}
 end
 if self.blockAll then return {Instance={},Normal=v(1,0,0)}end
 if self.blockShot and d.Y>1 then return {Instance={},Normal=v(1,0,0)}end
 if self.wall and math.abs(d.Z)<1 and math.abs(d.X)>1 then return {Instance={},Normal=v(1,0,0)}end
 return nil
end
function world:GetDescendants()return{}end
local queue,keys={},{}
local vim={};function vim:SendKeyEvent(down,key)keys[#keys+1]={down,key};if self.fail then error('unavailable')end end
local services={Players=players,UserInputService=input,RunService=runService,CollectionService=cs,VirtualInputManager=vim}
local env={game={GetService=function(_,n)return assert(services[n],n)end},workspace=world,Vector3={new=v},RaycastParams={new=function()return{}end},Enum={KeyCode=setmetatable({},{__index=function(_,k)return k end}),Material={Air='Air',Water='Water'},RaycastFilterType={Exclude='Exclude'},RenderPriority={Camera={Value=200}}},task={spawn=function(f)queue[#queue+1]=f end,delay=function(_,f)queue[#queue+1]=f end}}
local s={AutoGuard=true,AutoGuardKeybind='L',Aimbot=true,AimbotType='Low',BallMagnet=true,BallReach=true}
env.task.wait=function()oh.FloorMaterial='Air';root.AssemblyLinearVelocity.Y=5 end
e:Install(env,s);e:SetAutoPlay(true);own.Character.ball=part(root.Position+v(0,0,-1))
assert(s.AutoPlayDribble and not e:NearestGoal({Position=v(1000,3,0)}),'goal distance bound')
local reads=e:ReadOpponents(root);assert(#reads==0,'teammate and remote court excluded')
er.Position=root.Position+v(-10,0,0);er.AssemblyLinearVelocity=v(100,0,0)
reads=e:ReadOpponents(root);assert(#reads==1 and math.abs(reads[1].Velocity.Magnitude-32)<.01,'velocity bounded')
er.Position=v(200,3,200);er.AssemblyLinearVelocity=v()
e:OffenseStep(own.Character,oh,root);assert(e.OffenseGoal==goal and e.ShotSpot and e.AutoMovePoint,'route toward calibrated ring')
assert(e.AutoMovePoint.X<root.Position.X,'moves toward shot position')
local spot=e.ShotSpot;assert(math.abs((spot-goal.Position).Magnitude-65)<.01,'height-aware 3D shooting distance')
runService.bindings[e.RenderName]();assert(oh.moves>0,'render moves WITH possession')
root.Position=spot;root.AssemblyLinearVelocity=v();e.Clock=1
assert(not e:OffenseStep(own.Character,oh,root));e.Clock=1.3;assert(e:OffenseStep(own.Character,oh,root),'open and settled allows shot')
er.Position=root.Position+v(-5,0,0);eh.FloorMaterial='Air'
e.Clock=2;e.OpenSince=nil;e.SettlePosition=nil;assert(not e:OffenseStep(own.Character,oh,root),'airborne blocker: pump fake first')
assert(e.AutoPlayStatus=='Pump fake: defender in the air' and keys[#keys][2]=='R','pump fake uses R')
e.Clock=2.2;assert(not e:OffenseStep(own.Character,oh,root),'still waiting for blocker to land')
e.Clock=2.5;assert(e:OffenseStep(own.Character,oh,root),'pump fake bounded: shoots by .45s even if blocker hangs')
assert(e.ShotBlockReason=='Contested: shooting anyway' and not e.AutoMovePoint,'contest reported, no endless dribble')
e:ReleaseDribbleKeys(true)
er.Position=root.Position+v(-1,0,0);eh.FloorMaterial='Ground';e.Clock=2.55;assert(e:OffenseStep(own.Character,oh,root),'zero space still shoots')
-- Inside the ring: drive to the rim and press T, not back out to the 3.
er.Position=v(200,3,200);e:ResetOffense();e.OffenseGoal=goal;e.GoalDirection=v(1,0,0);e.OffenseCharacter=own.Character
local saved=root.Position;root.Position=v(30,3,0);e.Clock=2.5;assert(not e:OffenseStep(own.Character,oh,root))
assert(e.DunkMode and e.AutoMovePoint and e.AutoMovePoint.X<30,'drives toward rim inside 3pt ring')
root.Position=v(4,3,0);e.Clock=2.6;e:OffenseStep(own.Character,oh,root);assert(keys[#keys][2]=='T' and keys[#keys][1] and e.DunkAttempts==1,'T dunk at rim')
e.Clock=2.7;e:OffenseStep(own.Character,oh,root);assert(e.DunkAttempts==1,'dunk cooldown')
s.AutoPlayDunk=false;e.Clock=4;e:OffenseStep(own.Character,oh,root);assert(not e.DunkMode,'auto-dunk toggle off');s.AutoPlayDunk=true
e:ReleaseDribbleKeys(true);root.Position=saved;e:ResetOffense();e.OffenseGoal=goal;e.GoalDirection=v(1,0,0);e.OffenseCharacter=own.Character
er.Position=v(200,3,200);eh.FloorMaterial='Ground'
world.wall=true;local point=e:SteerTo(root,root.Position+v(-20,0,0),{});assert(point and math.abs(point.Z-root.Position.Z)>1,'route around blocked straight path')
world.wall=false;world.edge=true
point=e:SteerTo({Position=v(100,3,0)},v(100,3,20),{});assert(not point or point.Z<=1,'no unsupported floor route')
world.edge=false;world.blockShot=true;assert(not e:CanTakeShot(root),'obstructed shot rejected');world.blockShot=false
local raycast=world.Raycast
world.Raycast=function(self,origin,d,params)
 if d.Y>1 then return{Instance={},Position=goal.Position+v(0,0,1)}end
 return raycast(self,origin,d,params)
end
assert(e:CanTakeShot(root),'rim/backboard endpoint does not reject an arced shot')
world.Raycast=function(self,origin,d,params)
 if d.Y>1 then return{Instance={},Position=root.Position+v(-15,3,0)}end
 return raycast(self,origin,d,params)
end
assert(not e:CanTakeShot(root) and e.ShotBlockReason=='Shot line blocked','distant obstacle still blocks')
world.Raycast=raycast
-- Screenshot key mapping remains available; tactical ball-protection policy
-- is covered by test_ball_protection, rather than requiring random moves.
for i,name in ipairs({'F','G','R','V','C','B','H'})do
 e:ReleaseDribbleKeys(true);e.Clock=3+i;e.MoveCooldowns={};e.LastDribble=-100
 assert(e:PulseDribble(name),'supported control '..name)
 assert(keys[#keys][1] and keys[#keys][2]==name,'mapped key '..name)
 e:ReleaseDribbleKeys(true);assert(not keys[#keys][1] and keys[#keys][2]==name,'release '..name)
end
local count=#keys
e:ReleaseDribbleKeys(true);e.Clock=11;input.focus=true;count=#keys;assert(not e:PulseDribble('F') and #keys==count);input.focus=nil
s.AutoGuardKeybind='F';assert(not e:PulseDribble('F'),'do not toggle guard on mapped key');s.AutoGuardKeybind='L'
e.Clock=20;e.MoveCooldowns={};e.LastDribble=-100;e:ReleaseDribbleKeys(true)
er.Position=root.Position+v(-10,0,0);er.AssemblyLinearVelocity=v();eh.FloorMaterial='Ground'
local before=#keys
e:ChooseDribble(root,root.Position+v(0,0,8),e:ReadOpponents(root),own.Character.ball)
assert(#keys>before,'stationary pressure still gets a randomized chain')
e.Clock=21;e.OpponentMemory=nil;er.Position=root.Position+v(-15,0,0);er.AssemblyLinearVelocity=v(14,0,0)
e:ChooseDribble(root,root.Position+v(-8,0,0),e:ReadOpponents(root),own.Character.ball)
assert(keys[#keys][1] and (keys[#keys][2]=='R' or keys[#keys][2]=='V' or keys[#keys][2]=='B' or keys[#keys][2]=='F' or keys[#keys][2]=='G'),'closing pressure uses safe randomized chain')
e:ReleaseDribbleKeys(true)
-- Disabling between queueing and execution must prevent a shot.
er.Position=v(200,3,200);root.Position=spot;e:ResetOffense();e.Clock=12;e:AutoPlayStep(own.Character,oh,root);e.Clock=12.3
local shots=0;e.AimAction=function()shots=shots+1 end;e:AutoPlayStep(own.Character,oh,root);assert(e.Shooting)
e:SetAutoPlay(false);for _,f in ipairs(queue)do f()end;assert(shots==0 and not e.Shooting and not next(e.DribbleKeys),'queued shot cancellation and key cleanup')
-- Simulated movement loop reaches a usable shooting position from outside range.
e:SetAutoPlay(true);root.Position=v(110,3,0);e:ResetOffense();queue={}
for i=1,160 do
 e.Clock=e.Clock+.1;e:AutoPlayStep(own.Character,oh,root)
 if e.AutoMovePoint then
  local d=e.AutoMovePoint-root.Position
  root.Position=root.Position+d/math.max(1,d.Magnitude)*math.min(d.Magnitude,1.6)
 end
 local current=queue;queue={};for _,f in ipairs(current)do f()end
 if shots>0 then break end
end
assert(shots==1 and e:InShotRange(root),'positioning loop arrives and shoots')
world.blockAll=true;root.Position=v(110,3,0);e.Clock=e.Clock+2;e:ResetOffense();e:OffenseStep(own.Character,oh,root);assert(not e.AutoMovePoint,'fully blocked route stops')
e:Destroy();assert(not next(e.DribbleKeys) and not runService.bindings[e.RenderName])
return 'PASS: possession movement, shot positioning and arrival simulation, teammate/court filters, bounded opponent prediction, bounded pump fake on airborne blocker, contested and zero-space shots, inside-ring rim drive and T dunk, obstruction gates, obstacle/ledge steering, screenshot F/G/R/V/C inputs and cooldown/release, focus/key conflicts, queued-shot cancellation, blocked-route stop and cleanup'
'''.replace('SOURCE','[====['+source+']====]')
print(run(lua).decode())
