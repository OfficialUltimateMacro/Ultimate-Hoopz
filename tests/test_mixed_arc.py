from pathlib import Path
from lua_runtime import run
source=(Path(__file__).resolve().parents[1]/'Ultimate.Blessed.decoded.lua').read_text()
lua=r'''_G.ULTIMATE_BLESSED_INSPECT=true;bit32={}
local app=assert(load(SOURCE,'mixed','t',_G))()
assert(app.Preferences.AimbotType=='High' and app.Prototypes.root[6][1974]=='High')
local settings={AimbotType='Mixed arc'}
local player={Power=70};function player:GetAttribute(k)return self[k]end;function player:SetAttribute(k,v)self[k]=v end
local env={game={Players={LocalPlayer=player}}}
local calls=0
local f=app.CustomizeClosure('root.175',function(d)
 calls=calls+1
 if settings.AimbotType=='Low' then player.Power=75;return d+10 end
 player.Power=85;return d+30
end,env,{[0]=settings})
assert(f(5)==25 and player.Power==80 and settings.AimbotType=='Mixed arc' and calls==2,'actual offset and power midpoint')
settings.AimbotType='Low';assert(f(5)==15 and player.Power==75 and calls==3,'existing Low untouched')
settings.AimbotType='High';assert(f(5)==35 and player.Power==85 and calls==4,'existing High untouched')
settings.AimbotType='Mixed arc';player.Power=70
local bad=app.CustomizeClosure('root.175',function()player.Power=90;error('endpoint failure')end,env,{[0]=settings})
assert(not pcall(bad,65) and settings.AimbotType=='Mixed arc' and player.Power==70,'error restores mode and power')
local seen
local picker=app.CustomizeClosure('root.1083.232.12.644',function(_,config)seen=config;return config end,env,{})
picker({}, {Title='Type',Data={'Low','High'},Default=settings.AimbotType})
assert(table.concat(seen.Data,',')=='Low,Mixed arc,High' and seen.Default=='Mixed arc','picker order and default')
-- Integration with the recovered desktop endpoint functions and dispatcher.
setmetatable(env,{__index=_G});env.warn=function()end
settings.AimbotMethod='Mouse'
env.LowPC=app.Functions['root.142'](env,{})
env.HighPC=app.Functions['root.173'](env,{})
local native=app.Functions['root.175'](env,{[0]=settings,[1]='Desktop'})
local mixed=app.CustomizeClosure('root.175',native,env,{[0]=settings,[1]='Desktop'})
for _,d in ipairs({58,60,65,70,72})do
 settings.AimbotType='Low';local lo=native(d);local lp=player.Power
 settings.AimbotType='High';local hi=native(d);local hp=player.Power
 settings.AimbotType='Mixed arc';local mid=mixed(d)
 assert(type(mid)=='number' and math.abs(mid-(lo+hi)/2)<1e-8 and player.Power==(lp+hp)/2,'native midpoint at '..d)
end
return 'PASS: Mixed arc midpoint, power, default, picker order, Low/High compatibility and error restoration'
'''
print(run(lua.replace('SOURCE','[====['+source+']====]')).decode())
