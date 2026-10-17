import pathlib,json
from lua_runtime import run
source=(pathlib.Path(__file__).resolve().parents[1]/'Ultimate.Blessed.decoded.lua').read_text()
lua=r'''
_G.ULTIMATE_BLESSED_INSPECT=true
local source=SOURCE
local function inspect() return assert(load(source,'logo tests','t',_G))() end
bit32={};local app=inspect()
local hits,writes,created=0,0,{}
local env={typeof=function()return 'Instance'end,Enum={ScaleType={Fit='Fit'},Font={Fantasy='Fantasy'}},UDim2={fromScale=function(x,y)return{x,y}end},Color3={fromRGB=function(r,g,b)return{r,g,b}end}}
env.game={HttpGet=function(_,url)hits=hits+1;assert(url:find('OfficialUltimateMacro/Ultimate%-Hoopz'));return string.char(137,80,78,71,13,10,26,10)..'image' end}
env.isfile=function()return false end
env.writefile=function(path,data)writes=writes+1;assert(data:byte(1)==137)end
env.getcustomasset=function()return 'rbxasset://Ultimate-logo.png'end
env.Instance={new=function(class)local item={ClassName=class};created[#created+1]=item;return item end}
local function target()return {ZIndex=3,FindFirstChild=function()return nil end}end
local a,b=target(),target()
app.ApplyProperty(a,'Image','ultimate://wordmark',env)
app.ApplyProperty(b,'Image','ultimate://wordmark',env)
assert(a.Image=='rbxasset://Ultimate-logo.png' and b.Image==a.Image)
assert(hits==1 and writes==1 and #created==0,'shared logo loads once')
app.ApplyProperty(a,'Text','unchanged',env);assert(a.Text=='unchanged')
local fallback=inspect();env.getcustomasset=nil
local c=target();fallback.ApplyProperty(c,'Image','ultimate://wordmark',env)
assert(c.Image=='' and #created==1 and created[1].Text=='Ultimate','fallback replaces old branding')
assert(created[1].Parent==c and created[1].ZIndex==4)
local failed=inspect();env.getcustomasset=function()error('unsupported')end
failed.ApplyProperty(target(),'Image','ultimate://wordmark',env)
assert(#created==2 and created[2].Text=='Ultimate','failed custom asset falls back')
return 'logo cache, both image slots, fallback, and property pass-through passed'
'''.replace('SOURCE','[====['+source+']====]')
print(run(lua).decode())
