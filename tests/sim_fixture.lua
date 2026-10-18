-- Shared deterministic Roblox-like world for simulation/performance suites.
-- Signals store callbacks; workspace exposes DescendantAdded and a large
-- descendant list; every expensive engine call is counted.
local F={count=setmetatable({},{__index=function()return 0 end})}
local C=F.count
local mt={}
local function v(x,y,z)return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},mt)end
F.v=v
mt.__add=function(a,b)return v(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
mt.__sub=function(a,b)return v(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
mt.__unm=function(a)return v(-a.X,-a.Y,-a.Z)end
mt.__mul=function(a,b)if type(a)=='number'then a,b=b,a end;return v(a.X*b,a.Y*b,a.Z*b)end
mt.__div=function(a,b)return v(a.X/b,a.Y/b,a.Z/b)end
mt.__eq=function(a,b)return a.X==b.X and a.Y==b.Y and a.Z==b.Z end
mt.__index=function(a,k)
 if k=='Magnitude'then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z)
 elseif k=='Unit'then local m=math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z);return v(a.X/m,a.Y/m,a.Z/m)
 elseif k=='Dot'then return function(a,b)return a.X*b.X+a.Y*b.Y+a.Z*b.Z end end
end
local function signal()
 local s={fns={}}
 function s:Connect(f)local c={Connected=true};self.fns[c]=f;function c:Disconnect()self.Connected=false;s.fns[c]=nil end;return c end
 function s:Fire(...)for _,f in pairs(self.fns)do f(...)end end
 function s:Count()local n=0;for _ in pairs(self.fns)do n=n+1 end;return n end
 return s
end
F.signal=signal
local function frame(position,target)
 local d=target-position;local m=math.max(.001,d.Magnitude);local look=d/m
 local right=v(-look.Z,0,look.X);local rm=math.max(.001,right.Magnitude)
 return {Position=position,LookVector=look,RightVector=right/rm}
end
F.frame=frame
local function part(pos,name)
 local p={Position=pos,Parent=true,Name=name or 'Part',AssemblyLinearVelocity=v()}
 function p:IsA(k)return k=='BasePart'end
 function p:IsDescendantOf(x)return self.Owner==x or (x==F.world and self.Parent~=nil) end
 function p:FindFirstChildWhichIsA()return nil end
 return p
end
F.part=part
local function player(pos,name)
 local r=part(pos,'HumanoidRootPart');r.CFrame=frame(pos,pos+v(-1,0,0))
 local h={Health=100,FloorMaterial='Ground',Jumping=signal(),moves=0,AutoRotate=true}
 function h:MoveTo(p)C.MoveTo=C.MoveTo+1;self.point=p;self.moves=self.moves+1 end
 function h:ChangeState()end
 local c={Parent=true,root=r,h=h,attrs={}}
 function c:FindFirstChild(n)if n=='HumanoidRootPart'then return self.root elseif n=='Basketball'then return self.ball end end
 function c:FindFirstChildOfClass()return self.h end
 function c:GetAttribute(k)return self.attrs[k]end
 local pl={Character=c,Neutral=true,Name=name or 'P'}
 return pl,h,r
end
F.player=player
F.world={DescendantAdded=signal(),DescendantRemoving=signal(),extra={}}
local world=F.world
function world:Raycast(origin,d,params)
 C.Raycast=C.Raycast+1
 if d.Y < -8 and math.abs(d.X)<1e-9 and math.abs(d.Z)<1e-9 then return {Position=v(origin.X,0,origin.Z),Normal=v(0,1,0),Material='Ground'} end
 if self.wallX and ((origin.X-self.wallX)*(origin.X+d.X-self.wallX)<0) and math.abs(origin.Z)<self.wallHalf then return {Instance={},Position=v(self.wallX,origin.Y,origin.Z),Normal=v(1,0,0)} end
 return nil
end
function world:GetDescendants()C.GetDescendants=C.GetDescendants+1;local t={};for i=1,4000 do t[i]=self.extra[i] or F.filler end;for _,b in ipairs(F.balls)do t[#t+1]=b end;return t end
F.filler=part(v(),'Filler')
F.balls={}
F.queue={}
F.keys={}
local own,oh,root=player(v(100,3,0),'Me')
F.own,F.oh,F.root=own,oh,root
local enemy,eh,er=player(v(300,3,300),'Defender');F.enemy,F.eh,F.er=enemy,eh,er
local players={LocalPlayer=own};function players:GetPlayers()C.GetPlayers=C.GetPlayers+1;return{own,enemy}end
local input={down={},mouse={}};function input:GetFocusedTextBox()return self.focus end;function input:IsKeyDown(k)return self.down[k]end
function input:IsMouseButtonPressed(b)return self.mouse[b]end
function input:GetMouseDelta()return self.delta or v()end
F.input=input
local runService={Heartbeat=signal(),bindings={}};function runService:BindToRenderStep(n,p,f)self.bindings[n]=f end;function runService:UnbindFromRenderStep(n)self.bindings[n]=nil end
F.run=runService
F.goal=part(v(0,12,0),'Goal');F.farGoal=part(v(260,12,0),'Goal2')
local cs={};function cs:GetTagged()C.GetTagged=C.GetTagged+1;return{F.goal,F.farGoal}end
local vim={};function vim:SendKeyEvent(down,key)F.keys[#F.keys+1]={down,key,F.now or 0}end
function vim:SendMouseButtonEvent()end
local camera={CameraSubject=oh,CFrame=frame(root.Position+v(12,6,0),root.Position),CameraType='Custom'}
world.CurrentCamera=camera;F.camera=camera
local services={Players=players,UserInputService=input,RunService=runService,CollectionService=cs,VirtualInputManager=vim}
F.env={game={GetService=function(_,n)return assert(services[n],n)end},workspace=world,Vector3={new=v},
 CFrame={lookAt=function(a,b)C.CFrame=C.CFrame+1;return frame(a,b)end},
 RaycastParams={new=function()C.RaycastParams=C.RaycastParams+1;return{}end},
 Enum={KeyCode=setmetatable({},{__index=function(_,k)return k end}),Material={Air='Air',Water='Water'},RaycastFilterType={Exclude='Exclude'},
  RenderPriority={Camera={Value=200}},CameraType={Scriptable='Scriptable'},UserInputType={MouseButton1='MB1',MouseButton2='MB2'},HumanoidStateType={Jumping='Jumping'}},
 task={spawn=function(f)F.queue[#F.queue+1]=f end,delay=function(t,f)F.queue[#F.queue+1]=f end,wait=function()end}}
function F.flush()local q=F.queue;F.queue={};for _,f in ipairs(q)do f()end end
-- Advance one frame: heartbeat, render binding, then simple humanoid motion.
function F.step(e,dt,speed)
 F.now=(F.now or 0)+dt
 F.run.Heartbeat:Fire(dt)
 for _,f in pairs(F.run.bindings)do f(dt)end
 F.flush()
 local h=F.oh
 if h.point and not e.Shooting then
  local d=h.point-F.root.Position;d=v(d.X,0,d.Z)
  local m=d.Magnitude
  if m>0.05 then local step=math.min(m,(speed or 16)*dt);F.root.Position=F.root.Position+d/m*step;F.root.AssemblyLinearVelocity=d/m*(speed or 16) else F.root.AssemblyLinearVelocity=v() end
 end
 if F.own.Character.ball then F.own.Character.ball.Position=F.root.Position+v(0,0,-1) end
end
return F
