from pathlib import Path
from lua_runtime import run
folder=Path(__file__).resolve().parent;source=(folder.parent/'Ultimate.Blessed.decoded.lua').read_text();fixture=(folder/'sim_fixture.lua').read_text()
lua=r'''_G.ULTIMATE_BLESSED_INSPECT=true;bit32={}
local F=(function() FIXTURE end)();local app=assert(load(SOURCE,'local headphones','t',_G))();local e=app.Extensions;local env=F.env;local v=F.v
local all,timers={},{};local nextLoaded=true
local function instance(class)
 local o={ClassName=class,Destroyed=false,Loaded=F.signal(),Activated=F.signal(),FocusLost=F.signal(),InputBegan=F.signal()}
 if class=='Sound'then o.IsLoaded=nextLoaded end
 function o:IsA(k)return k==self.ClassName or k=='BasePart' and self.ClassName=='Part'end
 function o:FindFirstChild(name)for _,x in ipairs(all)do if x.Parent==self and x.Name==name and not x.Destroyed then return x end end end
 function o:Destroy()if self.Destroyed then return end;self.Destroyed=true;self.Parent=nil;for _,x in ipairs(all)do if x.Parent==self then x:Destroy()end end end
 function o:Play()self.Played=true end;function o:Stop()self.Stopped=true end
 all[#all+1]=o;return o
end
env.Instance={new=instance};env.Color3={fromRGB=function(r,g,b)return{r,g,b}end}
env.CFrame.new=function(x,y,z)return v(x,y,z)end
env.UDim2={new=function(xs,xo,ys,yo)return{X={Scale=xs,Offset=xo},Y={Scale=ys,Offset=yo}}end}
env.UDim={new=function(s,o)return{Scale=s,Offset=o}end}
env.Enum.Material.Neon='Neon';env.Enum.Material.SmoothPlastic='SmoothPlastic';env.Enum.Font={Gotham='Gotham'}
env.Enum.UserInputType.MouseMovement='MouseMovement';env.Enum.UserInputType.Touch='Touch'
F.input.InputChanged=F.signal();F.input.InputEnded=F.signal()
local soundService=instance('SoundService');local getService=env.game.GetService
env.game.GetService=function(self,name)if name=='SoundService'then return soundService end;return getService(self,name)end
env.task.delay=function(t,f)timers[#timers+1]={t,f}end
local function putHead(character)
 local head=F.part(v(10,5,0),'Head');head.Size=v(2,1,1)
 head.CFrame=setmetatable({},{__mul=function(_,offset)return{Position=head.Position+offset}end})
 local original=character.FindFirstChild;character.FindFirstChild=function(self,name)if name=='Head'then return self.head end;return original(self,name)end
 character.head=head;return head
end
local head=putHead(F.own.Character)
local s={AutoGuard=true,AutoGuardKeybind='L',Aimbot=true};e:Install(env,s)
assert(not e.LocalHeadphonesEnabled and not e.LocalMusicSound,'default off independent of autoplay')
e:SetLocalHeadphones(true);local model=e.LocalHeadphonesModel
assert(model and model.Parent==F.own.Character and not s.AutoPlay,'custom visual independent of gameplay')
local parts=0;for _,part in ipairs(all)do if part.Parent==model and part.ClassName=='Part'then
 parts=parts+1;assert(part.Massless and not part.CanCollide and not part.CanTouch and not part.CanQuery and not part.Anchored,'no collision/mass interference')
end end
assert(parts==16 and head.CanCollide==nil,'curved band, round cups/cushions/rings; head untouched')
e:UpdateLocalHeadphones();assert(e.LocalHeadphonesModel==model,'no duplicate visuals')
assert(not e:PlayLocalMusic('garbage') and not e:PlayLocalMusic('0') and not e.LocalMusicSound,'invalid/blank ids cannot start audio')
assert(e:PlayLocalMusic(' rbxassetid://12345 ',.35));local first=e.LocalMusicSound
assert(first.Parent==soundService and first.SoundId=='rbxassetid://12345' and first.Looped and first.Played and first.Volume==.35,'client Sound configured')
assert(e:PlayLocalMusic('54321',5) and first.Destroyed and first.Stopped and first.Loaded:Count()==0,'replacement cleans previous sound and handler')
assert(e.LocalMusicSound.Volume==1,'volume clamped')
local oldMusic=e.LocalMusicSound
local newPlayer=F.player(v(0,3,0),'Me');F.own.Character=newPlayer.Character
local newHead=putHead(F.own.Character);e:UpdateLocalHeadphones()
assert(model.Destroyed and e.LocalHeadphonesHead==newHead and e.LocalMusicSound==oldMusic,'respawn reattaches without restarting audio')
e:SetLocalHeadphones(false);assert(not e.LocalHeadphonesModel and not e.LocalMusicSound and oldMusic.Destroyed,'toggle off cleans all playback and cosmetics')
for _,timer in ipairs(timers)do timer[2]()end
assert(e.LocalMusicStatus=='Local headphones off','stale timers cannot overwrite off status')
nextLoaded=false;assert(e:PlayLocalMusic('11111'));local loading=e.LocalMusicSound
for _,timer in ipairs(timers)do timer[2]()end
assert(e.LocalMusicStatus:find('did not load'),'unavailable audio is reported')
loading.IsLoaded=true;loading.Loaded:Fire();assert(e.LocalMusicStatus:find('Playing locally'),'load event updates status')
assert(e.LocalMusicStatus:find('Playing locally'),'load event updates status')
-- Roblox ID that never loads explains the privacy rule.
nextLoaded=false;assert(e:PlayLocalMusic('77777'));for _,timer in ipairs(timers)do timer[2]()end
assert(e.LocalMusicStatus:find('privacy'),'blocked Roblox ID explains audio privacy')
-- MP3/OGG link: downloaded, validated, saved and played through getcustomasset.
nextLoaded=true
local files={}
env.writefile=function(path,data)files[path]=data end;env.isfile=function(path)return files[path]~=nil end
env.makefolder=function()end;env.isfolder=function()return false end
env.getcustomasset=function(path)assert(files[path],'asset from saved file');return 'rbxasset://custom/'..path end
local http=env.game.HttpGet
env.game.HttpGet=function(_,url)if url:find('bad')then return '<html>not audio</html>' end;return 'ID3'..string.rep('x',64) end
assert(not e:PlayLocalMusic('https://example.com/bad.mp3') and e.LocalMusicStatus:find('did not return MP3/OGG'),'non-audio link rejected')
assert(e:PlayLocalMusic('https://example.com/song.mp3',.5),'mp3 link plays')
assert(e.LocalMusicSound.SoundId:find('^rbxasset://custom/UltimateMusic/track_') and e.LocalMusicSound.SoundId:find('%.mp3$'),'link saved and loaded locally')
files['mysong.ogg']='OggS'..string.rep('y',64)
assert(e:PlayLocalMusic('mysong.ogg') and e.LocalMusicSound.SoundId=='rbxasset://custom/mysong.ogg','workspace file plays')
assert(not e:PlayLocalMusic('missing.mp3') and e.LocalMusicStatus:find('File not found'),'missing file reported')
local gca=env.getcustomasset;env.getcustomasset=nil
assert(not e:PlayLocalMusic('mysong.ogg') and e.LocalMusicStatus:find('cannot play audio files'),'executor without getcustomasset explained')
env.getcustomasset=gca;env.game.HttpGet=http
assert(e:PlayLocalMusic('11111'));nextLoaded=false
e.Screen=instance('ScreenGui');e.Screen.Parent=true;e:OpenLocalMusicPanel();local panel=e.LocalMusicPanel
local id=panel:FindFirstChild('AudioId');local play=panel:FindFirstChild('Play');local stop=panel:FindFirstChild('Stop');local close=panel:FindFirstChild('Close');local volume=panel:FindFirstChild('Volume')
assert(id.Text=='11111','panel retains entered ID, no hard-coded track')
local count=#e.Connections;e:OpenLocalMusicPanel();assert(e.LocalMusicPanel==panel and #e.Connections==count,'reopening reuses panel and handlers')
volume.Text='150';volume.FocusLost:Fire();assert(volume.Text=='100' and e.LocalMusicSound.Volume==1,'live volume clamped')
nextLoaded=true;id.Text='22222';volume.Text='25';play.Activated:Fire();assert(e.LocalMusicSound.SoundId=='rbxassetid://22222' and e.LocalMusicSound.Volume==.25,'play button uses fields')
close.Activated:Fire();assert(not panel.Visible and e.LocalMusicSound,'closing panel only hides controls')
e:OpenLocalMusicPanel();assert(panel.Visible,'reopen hidden panel')
local title=panel:FindFirstChild('Title');local initial=panel.Position
title.InputBegan:Fire({UserInputType='MB1',Position=v(10,10,0)})
F.input.InputChanged:Fire({UserInputType='MouseMovement',Position=v(40,25,0)})
assert(panel.Position.X.Offset==initial.X.Offset+30 and panel.Position.Y.Offset==initial.Y.Offset+15,'drag title moves panel')
F.input.InputEnded:Fire({UserInputType='MB1'});local held=panel.Position
F.input.InputChanged:Fire({UserInputType='MouseMovement',Position=v(100,100,0)});assert(panel.Position==held,'release ends drag')
stop.Activated:Fire();assert(not e.LocalMusicSound and e.LocalHeadphonesEnabled,'stop preserves visual toggle')
e:PlayLocalMusic('33333');local last=e.LocalMusicSound;e:Destroy()
assert(last.Destroyed and panel.Destroyed and not e.LocalHeadphonesEnabled and not e:PlayLocalMusic('44444'),'unload cleanup and no playback after destroy')
assert(F.input.InputChanged:Count()==0 and F.input.InputEnded:Count()==0,'drag handlers disconnected')
return 'PASS: local custom visual (curved band, round cups), MP3/OGG link and workspace-file playback via getcustomasset, privacy/missing/unsupported messages, no physics mutation, respawn, ID/volume validation, playback replacement/loading/error, draggable reusable controls, off/stop/unload and stale-callback cleanup'
'''
print(run(lua.replace('FIXTURE',fixture).replace('SOURCE','[====['+source+']====]')).decode())
