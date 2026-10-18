import pathlib
from lua_runtime import run
source=(pathlib.Path(__file__).resolve().parents[1]/'Ultimate.Blessed.decoded.lua').read_text(encoding='utf-8')
lua=r'''
_G.ULTIMATE_BLESSED_INSPECT=true;bit32={}
local app=assert(load(SOURCE,'collision tests','t',_G))();local e=app.Extensions
local function pos(x)return setmetatable({x=x},{__sub=function(a,b)return{Magnitude=math.abs(a.x-b.x)}end})end
local function part(group,collide,anchored)
 local p={CollisionGroup=group,CanCollide=collide,Anchored=anchored,Parent=true}
 function p:IsA(k)return k=='BasePart'end
 return p
end
local function player(x)
 local h={Health=100};local c={Parent=true,HumanoidRootPart={Position=pos(x)},h=h,Torso=part('Players',false,false),UpperTorso=part('Players',true,false),LowerTorso=part('Players',false,false),LeftLeg=part('Players',false,false)}
 function c:FindFirstChild(n)return self[n]end;function c:FindFirstChildOfClass()return self.h end
 return {Character=c}
end
local own,near,far=player(0),player(5),player(40)
e.Player=own;e.Players={GetPlayers=function()return{own,near,far}end};e.Settings={PlayerCollisions=false,AutoPlay=false}
e:SetPlayerCollisions(false);assert(not next(e.CollisionParts),'off is inert')
e:SetPlayerCollisions(true)
assert(own.Character.Torso.CanCollide and near.Character.Torso.CanCollide and near.Character.Torso.CollisionGroup=='Default')
assert(not far.Character.Torso.CanCollide and not own.Character.LeftLeg.CanCollide,'nearby torso only')
assert(own.Character.HumanoidRootPart.CanCollide==nil,'root untouched')
-- Replicated changes between updates become the latest baseline, then restore.
near.Character.Torso.CollisionGroup='NewServerGroup';e:UpdatePlayerCollisions();assert(near.Character.Torso.CollisionGroup=='Default')
near.Character.HumanoidRootPart.Position=pos(30);e:UpdatePlayerCollisions()
assert(not near.Character.Torso.CanCollide and near.Character.Torso.CollisionGroup=='NewServerGroup','leaving radius restores latest baseline')
near.Character.HumanoidRootPart.Position=pos(5);e:UpdatePlayerCollisions()
local old=own.Character;own.Character=player(0).Character;e:UpdatePlayerCollisions()
assert(not old.Torso.CanCollide and old.Torso.CollisionGroup=='Players','respawn restores old rig')
assert(own.Character.Torso.CanCollide,'new rig applied')
own.Character.h.Health=0;e:UpdatePlayerCollisions();assert(not next(e.CollisionParts) and not near.Character.Torso.CanCollide,'death restores all')
own.Character.h.Health=100;own.Character.UpperTorso.Anchored=true;e:UpdatePlayerCollisions()
assert(own.Character.UpperTorso.CollisionGroup=='Players','anchored body not changed')
-- A value changed externally just before disable is preserved.
near.Character.Torso.CollisionGroup='ChangedOnDisable';e:SetPlayerCollisions(false)
assert(near.Character.Torso.CollisionGroup=='ChangedOnDisable' and not near.Character.Torso.CanCollide)
assert(own.Character.UpperTorso.CanCollide==true and not own.Character.LowerTorso.CanCollide and not next(e.CollisionParts))
e:SetPlayerCollisions(true);e.Run={UnbindFromRenderStep=function()end};e:Destroy()
assert(not e.Alive and not e.Settings.PlayerCollisions and not next(e.CollisionParts) and not own.Character.Torso.CanCollide,'unload restores properties')
return 'PASS: default-off, nearby torso collision/group changes, root/limb/anchored exclusions, distance/death/respawn restoration, latest server baseline and external-value preservation, disable/unload cleanup'
'''.replace('SOURCE','[====['+source+']====]')
print(run(lua).decode())
