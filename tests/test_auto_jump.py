import pathlib
from lua_runtime import run
source=(pathlib.Path(__file__).resolve().parents[1]/'Ultimate.Blessed.decoded.lua').read_text(encoding='utf-8')
lua=r'''
_G.ULTIMATE_BLESSED_INSPECT=true;bit32={}
local app=assert(load(SOURCE,'auto jump tests','t',_G))();local e=app.Extensions
local h={Health=100,FloorMaterial='Ground'};function h:ChangeState(s)self.changed=s end
local root={AssemblyLinearVelocity={Y=0}};local ball=true
local char={FindFirstChild=function(_,n)if n=='Basketball'then return ball end end}
local player={Character=char};local frames,events,shots=0,{},0;local mode='jump'
local input={};function input:IsKeyDown()return self.physicalSpace end
e.Settings={AutoPlay=true,Aimbot=true};e.Player=player;e.Input=input;e.IsManual=function()return false end
e.InShotRange=function()return true end;e.CanTakeShot=function()return true end;e.OffenseStep=function()return true end
local callback
local vim={SendKeyEvent=function(_,down,key)
 events[#events+1]={down,key}
 if down and callback then callback()end
end}
e.Environment={game={GetService=function()return vim end},Enum={KeyCode={Space='Space'},Material={Air='Air'},HumanoidStateType={Jumping='Jumping'}},task={spawn=function(f)f()end,delay=function()end,wait=function()
 frames=frames+1
 if mode=='jump' and frames==2 then h.FloorMaterial='Air';root.AssemblyLinearVelocity.Y=8
 elseif mode=='cancel' then e.Settings.AutoPlay=false end
end}}
callback=app.CustomizeClosure('root.106',function()
 assert(h.FloorMaterial=='Air' and root.AssemblyLinearVelocity.Y>1,'shot only after takeoff')
 shots=shots+1
end,e.Environment,{})
e.Clock=2;e:AutoPlayStep(char,h,root)
assert(shots==1 and frames==2 and h.changed=='Jumping' and not e.Shooting,'single shot after native jump')
assert(events[1][1] and events[1][2]=='Space' and events[#events][1]==false and not next(e.DribbleKeys),'Space pressed and released')
-- Timeout must not fire a grounded shot or leave Shooting stuck.
e.Clock=4;h.FloorMaterial='Ground';root.AssemblyLinearVelocity.Y=0;mode='blocked';frames=0
e:AutoPlayStep(char,h,root);assert(shots==1 and frames==12 and not e.Shooting and not next(e.DribbleKeys))
assert(e.AutoPlayStatus=='Jump did not start: retrying')
e.Clock=6;mode='cancel';frames=0;e:AutoPlayStep(char,h,root);assert(shots==1 and not e.Shooting and not next(e.DribbleKeys),'disable during takeoff cancels shot')
-- A physically held Space is not owned or released by automation.
e.Settings.AutoPlay=true;input.physicalSpace=true;mode='jump';frames=0;events={};h.FloorMaterial='Ground';root.AssemblyLinearVelocity.Y=0
assert(e:RequestAutoJump(h,root,function()return true end));assert(#events==0)
return 'PASS: native jump request and state fallback, rising-airborne confirmation, duplicate JumpRequest suppression, one shot after takeoff, blocked jump timeout/retry, cancellation and Space cleanup, physical Space preserved'
'''.replace('SOURCE','[====['+source+']====]')
print(run(lua).decode())
