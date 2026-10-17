import pathlib
from lua_runtime import run
source = (pathlib.Path(__file__).resolve().parents[1]/'Ultimate.Blessed.decoded.lua').read_text()
lua = r'''
_G.ULTIMATE_BLESSED_INSPECT=true; bit32={}
local app=assert(load(SOURCE,'extension tests','t',_G))()
local e=app.Extensions
-- Isolate the previously shipped guard/pickup/shooting unit regressions.
-- Full possession planning has a separate 3D world simulation suite.
e.OffenseStep=nil;e.CanTakeShot=nil;e.SteerTo=nil
local function signal()
 local s={listeners={}}
 function s:Connect(fn) local c={Connected=true};function c:Disconnect()self.Connected=false end;self.listeners[#self.listeners+1]={fn,c};return c end
 function s:Fire(...)for _,v in ipairs(self.listeners)do if v[2].Connected then v[1](...)end end end
 return s
end
local mt={};local function vec(x)local v={X=x,Y=0,Z=0};return setmetatable(v,mt)end
mt.__sub=function(a,b)return {Magnitude=math.abs(a.X-b.X)}end
local function player()
 local h={Health=100,FloorMaterial='Ground',Jumping=signal(),moves=0};function h:MoveTo(p)self.moves=self.moves+1;self.destination=p end
 local r={Position=vec(0),AssemblyLinearVelocity={Y=0}}
 local c={Parent=true,humanoid=h,root=r};function c:FindFirstChildOfClass()return self.humanoid end;function c:FindFirstChild(n)if n=='HumanoidRootPart'then return self.root elseif n=='Basketball'then return self.ball end end
 return {Character=c},h,r
end
local own,oh,orr=player();local a,ah=player();local b,bh=player()
local input={down={}};function input:GetFocusedTextBox()return self.focus end;function input:IsKeyDown(k)return self.down[k]end
local rs={Heartbeat=signal(),bindings={}};function rs:BindToRenderStep(n,p,f)self.bindings[n]=f end;function rs:UnbindFromRenderStep(n)self.bindings[n]=nil end
local ps={LocalPlayer=own};function ps:GetPlayers()return {own,a,b}end
local collection={goals={}};function collection:GetTagged()return self.goals end
local env={Enum={KeyCode=setmetatable({},{__index=function(_,k)return k end}),Material={Air='Air'},RenderPriority={Camera={Value=200}}},task={spawn=function(fn)fn()end},workspace={parts={}}}
function env.workspace:GetDescendants()return self.parts end
local services={Players=ps,UserInputService=input,RunService=rs,CollectionService=collection};env.game={GetService=function(_,n)return assert(services[n],n)end}
local function settings()return {Aimbot=true,AutoGuard=true,AutoGuardKeybind='L',AutoGuardBallCheck=true,BallMagnet=true,BallReach=true,AimbotType='Low'}end
local s=settings();e:Install(env,s);assert(s.AimbotKeybind==nil and s.AutoPlay==false and s.AutoGuardJumpMatch)
local newer=settings();e:Install(env,newer);s=newer
local title,aimChanges,guardChanges=nil,0,0
local captures={[0]=s,[1]={SetValue=function()aimChanges=aimChanges+1 end},[3]={SetValue=function()guardChanges=guardChanges+1 end},[2]={Notification=function()return{new=function(t)title=t.Title end}end}}
local handler=app.CustomizeClosure('root.2169',function()error('old handler ran')end,env,captures)
handler({KeyCode='L'},false);assert(not s.AutoGuard and s.Aimbot and title=='Auto Guard' and aimChanges==0 and guardChanges==1)
handler({KeyCode='L'},true);handler({KeyCode='X'},false);assert(not s.AutoGuard)
input.focus=true;handler({KeyCode='L'},false);assert(not s.AutoGuard);input.focus=nil
handler({KeyCode='L'},false);assert(s.AutoGuard and s.Aimbot and guardChanges==2)
local selected=a;e.Selector=function()return selected end
e:SelectTarget(a);ah.Jumping:Fire(true);assert(oh.Jump and e.LastJump==e.Clock)
oh.Jump=false;ah.Jumping:Fire(true);assert(not oh.Jump,'jump cooldown')
e.Clock=1;selected=b;ah.Jumping:Fire(true);assert(e.Target==b and not oh.Jump,'selector recheck switches carrier')
bh.Jumping:Fire(true);assert(oh.Jump,'new target jumps')
oh.Jump=false;e.Clock=2;ah.Jumping:Fire(true);assert(not oh.Jump,'old target disconnected')
selected=nil;bh.Jumping:Fire(true);assert(not e.Target and not oh.Jump,'lost ball clears target')
selected=a;e:SelectTarget(a);own.Character.ball=true;ah.Jumping:Fire(true);assert(not oh.Jump,'own possession blocks jump');own.Character.ball=nil
input.down.W=true;ah.Jumping:Fire(true);assert(not oh.Jump,'manual movement blocks jump');input.down.W=nil;e.Clock=3
s.AutoGuard=false;ah.Jumping:Fire(true);assert(not oh.Jump);s.AutoGuard=true
local old=e.JumpConnection;a.Character=select(1,player()).Character;e:SelectTarget(a);assert(not old.Connected and e.TargetCharacter==a.Character,'respawn rebind')
e:ClearTarget();selected=nil
s.Aimbot=false;s.AutoGuard=false;s.BallMagnet=false;s.BallReach=false
e:SetAutoPlay(true);assert(s.Aimbot and s.AutoGuard and s.BallMagnet and s.BallReach)
e.AutoMovePoint=vec(8);rs.bindings[e.RenderName]();assert(oh.moves==1,'render uses rebound settings')
input.down.W=true;local n=oh.moves;rs.bindings[e.RenderName]();assert(oh.moves==n);e:AutoPlayStep(own.Character,oh,orr);assert(e.AutoPlayStatus=='Paused: manual input' and not e.AutoMovePoint)
input.down.W=nil;e.Clock=4;e:SetAutoPlay(false);assert(not s.Aimbot and not s.AutoGuard and not s.BallMagnet and not s.BallReach)
local function part(name,x,owner)local p={Name=name,Position=vec(x),Parent=true,owner=owner};function p:IsA(t)return t=='BasePart'end;function p:IsDescendantOf(c)return c==self.owner end;return p end
local loose=part('Basketball',10);local owned=part('Ball',2,b.Character);env.workspace.parts={owned,loose,part('Ball',70)}
assert(e:LooseBall(orr)==loose);loose.owner=a.Character;assert(e:LooseBall(orr)==nil,'cached pickup rechecks ownership')
collection.goals={part('goal',60)};s.AutoGuard=true;e:SetAutoPlay(true);own.Character.ball=true
local shots=0;e.AimAction=function()shots=shots+1 end
e:AutoPlayStep(own.Character,oh,orr);assert(shots==1 and not e.Shooting)
e:AutoPlayStep(own.Character,oh,orr);assert(shots==1,'shot cooldown')
e.Clock=6;collection.goals={part('goal',20)};e:AutoPlayStep(own.Character,oh,orr);assert(shots==1,'calibrated range only')
own.Character.ball=nil;oh.Health=0;e:Tick(.2);assert(not e.Target and not e.AutoMovePoint);oh.Health=100
e:Destroy();assert(not e.Alive and not rs.bindings[e.RenderName]);for _,c in ipairs(e.Connections)do assert(not c.Connected)end
return 'guard-only L and notification, input capture, selector jump identity/cooldown/possession/respawn, settings rebind, autoplay ownership/manual pause/pickup/range/cooldown, death and cleanup passed'
'''.replace('SOURCE','[====['+source+']====]')
print(run(lua).decode())
