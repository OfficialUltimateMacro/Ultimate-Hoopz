-- Custom client-created cosmetic and local Sound; no pass/ownership remotes.
function Extension:MusicStatus(text)
    self.LocalMusicStatus=text
    if self.MusicStatusLabel then pcall(function()self.MusicStatusLabel.Text=text end) end
end
function Extension:RemoveHeadphonesModel()
    if self.LocalHeadphonesModel then pcall(function()self.LocalHeadphonesModel:Destroy()end) end
    self.LocalHeadphonesModel,self.LocalHeadphonesHead=nil,nil
end
function Extension:UpdateLocalHeadphones()
    if not self.LocalHeadphonesEnabled then return end
    local character=self.Player and self.Player.Character
    local head=character and character:FindFirstChild("Head")
    if self.LocalHeadphonesModel and self.LocalHeadphonesModel.Parent==character
        and self.LocalHeadphonesHead==head then return end
    self:RemoveHeadphonesModel()
    if not head or not head:IsA("BasePart") then self:MusicStatus("Waiting for your character's head");return end
    local env=self.Environment
    local model=env.Instance.new("Model");model.Name="UltimateLocalHeadphones"
    self.LocalHeadphonesModel=model
    local ok,err=pcall(function()
        local width=math.max(.35,head.Size.X/2)
        local top=head.Size.Y/2+.1
        local dark=env.Color3.fromRGB(22,24,36)
        local cushion=env.Color3.fromRGB(8,9,14)
        local accent=env.Color3.fromRGB(255,95,163)
        local cylinder=env.Enum.PartType and env.Enum.PartType.Cylinder
        local function piece(name,size,offset,color,neon,round,roll)
            local part=env.Instance.new("Part");part.Name=name;part.Size=size
            part.Anchored=false;part.Massless=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false
            part.CastShadow=false
            part.Color=color;part.Material=neon and env.Enum.Material.Neon or env.Enum.Material.SmoothPlastic
            if round and cylinder then part.Shape=cylinder end
            local placement=env.CFrame.new(offset.X,offset.Y,offset.Z)
            if roll and env.CFrame.Angles then placement=placement*env.CFrame.Angles(0,0,roll) end
            part.CFrame=head.CFrame*placement
            part.Parent=model
            local weld=env.Instance.new("WeldConstraint");weld.Part0=head;weld.Part1=part;weld.Parent=part
        end
        local v=env.Vector3.new
        -- Curved headband: seven short segments on an arc over the head.
        local reachX,reachY=width+.18,top+.05
        for k=0,6 do
            local angle=math.rad(-72+k*24)
            local x,y=math.sin(angle)*reachX,math.cos(angle)*reachY
            piece("Band"..k,v(.34,.11,.26),v(x,y-.02,0),dark,false,false,-angle)
            if k>=2 and k<=4 then piece("BandGlow"..k,v(.3,.03,.1),v(x,y+.05,0),accent,true,false,-angle) end
        end
        -- Round ear cups (cylinder axis points out of the ear), cushions and rings.
        for _,side in ipairs({-1,1})do
            local tag=side<0 and "Left" or "Right"
            piece(tag.."Cushion",v(.14,.66,.66),v(side*(width+.05),-.02,0),cushion,false,true)
            piece(tag.."Cup",v(.24,.78,.78),v(side*(width+.22),-.02,0),dark,false,true)
            piece(tag.."Ring",v(.05,.5,.5),v(side*(width+.36),-.02,0),accent,true,true)
        end
        model.Parent=character;self.LocalHeadphonesHead=head
    end)
    if not ok then self:RemoveHeadphonesModel();self:MusicStatus("Headphone visual unavailable: "..tostring(err)) end
end
function Extension:StopLocalMusic()
    if self.LocalMusicLoaded then disconnect(self.LocalMusicLoaded);self.LocalMusicLoaded=nil end
    local sound=self.LocalMusicSound;self.LocalMusicSound=nil
    if sound then pcall(function()sound:Stop();sound:Destroy()end) end
    self:MusicStatus(self.LocalHeadphonesEnabled and "Music stopped (local only)" or "Local headphones off")
end
function Extension:SetLocalHeadphones(enabled)
    self.LocalHeadphonesEnabled=enabled==true and self.Alive
    if self.LocalHeadphonesToggle and not self.HeadphoneToggleSync then
        self.HeadphoneToggleSync=true
        pcall(self.LocalHeadphonesToggle.SetValue,self.LocalHeadphonesEnabled)
        self.HeadphoneToggleSync=false
    end
    if not self.LocalHeadphonesEnabled then self:StopLocalMusic();self:RemoveHeadphonesModel();return end
    self:UpdateLocalHeadphones()
    if not self.LocalMusicSound then self:MusicStatus("Headphones on; paste an MP3/OGG link or use the UltimateMusic folder") end
end
-- Roblox only plays audio an experience may use (same creator, <6 s, or
-- Roblox/licensed catalog); other users' IDs are private and fail silently.
-- So the default path is NOT Roblox audio: MP3/OGG links or files are
-- written to the executor workspace and played through getcustomasset,
-- which is local to this client and needs no asset permission.
local function audioKind(bytes)
    if type(bytes)~="string" or #bytes<16 then return nil end
    if bytes:sub(1,3)=="ID3" then return "mp3" end
    if bytes:sub(1,4)=="OggS" then return "ogg" end
    local a,b=bytes:byte(1,2)
    if a==255 and b and b>=224 then return "mp3" end
    return nil
end
local MUSIC_FOLDER="UltimateMusic"
-- Executor functions can live on the script environment or only in getgenv().
function Extension:ExecutorFunction(...)
    local env=self.Environment or {}
    local genv
    pcall(function() genv=(env.getgenv or rawget(_G,"getgenv"))() end)
    for _,name in ipairs({...}) do
        local f=env[name]
        if type(f)~="function" and type(genv)=="table" then f=genv[name] end
        if type(f)~="function" then f=rawget(_G,name) end
        if type(f)=="function" then return f end
    end
    return nil
end
-- Share links to direct download links (Dropbox, Google Drive, GitHub,
-- OneDrive embed-free links stay as they are).
function Extension:NormalizeMusicLink(url)
    local id=url:match("drive%.google%.com/file/d/([%w_%-]+)") or url:match("drive%.google%.com/open%?id=([%w_%-]+)")
    if id then return "https://drive.google.com/uc?export=download&id="..id end
    if url:find("dropbox%.com/") then
        if url:find("[?&]dl=0") then return (url:gsub("([?&])dl=0","%1dl=1")) end
        if not url:find("[?&]dl=1") and not url:find("[?&]raw=1") then return url..(url:find("?",1,true) and "&" or "?").."dl=1" end
    end
    local user,repo,rest=url:match("^https?://github%.com/([^/]+)/([^/]+)/blob/(.+)$")
    if user then return "https://raw.githubusercontent.com/"..user.."/"..repo.."/"..rest end
    return url
end
-- Binary-safe download: request()/http_request() first (follows redirects),
-- then game:HttpGet.
function Extension:DownloadAudio(url)
    local request=self:ExecutorFunction("request","http_request")
    if not request then
        local env=self.Environment or {}
        local syn=env.syn or rawget(_G,"syn");local http=env.http or rawget(_G,"http")
        request=(type(syn)=="table" and syn.request) or (type(http)=="table" and http.request) or nil
    end
    if request then
        local ok,res=pcall(request,{Url=url,Method="GET"})
        if ok and type(res)=="table" and type(res.Body)=="string" and (res.StatusCode==nil or (res.StatusCode>=200 and res.StatusCode<300)) then
            return res.Body
        end
    end
    local ok,data=pcall(function() return self.Environment.game:HttpGet(url) end)
    if ok and type(data)=="string" then return data end
    return nil,tostring(data)
end
-- MP3/OGG files the user put in workspace/UltimateMusic.
function Extension:MusicFolderTracks()
    local list=self:ExecutorFunction("listfiles")
    local isfolder=self:ExecutorFunction("isfolder")
    local tracks={}
    if not list or (isfolder and not isfolder(MUSIC_FOLDER)) then return tracks end
    local ok,files=pcall(list,MUSIC_FOLDER)
    if not ok or type(files)~="table" then return tracks end
    for _,path in ipairs(files) do
        local lower=tostring(path):lower()
        if (lower:match("%.mp3$") or lower:match("%.ogg$")) and not lower:match("track_%d+%.%w+$") then tracks[#tracks+1]=tostring(path) end
    end
    table.sort(tracks)
    return tracks
end
local function fileLabel(path) return (tostring(path):match("([^/\\]+)$") or tostring(path)) end
function Extension:ResolveMusicSource(value)
    local id=value:match("^(%d+)$") or value:match("^rbxassetid://(%d+)$")
    if id then
        if #id>20 or not id:find("[1-9]") then return nil,"Enter an MP3/OGG link, a file name, or a numeric Roblox audio ID" end
        return "rbxassetid://"..id,"Roblox audio "..id,id
    end
    local custom=self:ExecutorFunction("getcustomasset","getsynasset")
    local writefile=self:ExecutorFunction("writefile")
    local isfile=self:ExecutorFunction("isfile")
    local makefolder=self:ExecutorFunction("makefolder")
    local isfolder=self:ExecutorFunction("isfolder")
    local isLink=value:match("^https?://[%w%._%-]+[/%?]?") ~= nil
    local lowerValue=value:lower()
    local isFile=lowerValue:match("%.mp3$") or lowerValue:match("%.ogg$")
    if not isLink and not isFile then return nil,"Enter an MP3/OGG link, a file name, or a numeric Roblox audio ID" end
    if not custom then return nil,"This executor cannot play audio files (no getcustomasset)" end
    local path
    if isLink then
        if not writefile then return nil,"This executor cannot save audio files (no writefile)" end
        local url=self:NormalizeMusicLink(value)
        if url:find("youtube%.com") or url:find("youtu%.be") or url:find("spotify%.com") or url:find("soundcloud%.com") then
            return nil,"Streaming pages are not audio files. Use a direct .mp3/.ogg link or put the file in workspace/"..MUSIC_FOLDER
        end
        local hash=0;for k=1,math.min(#url,200) do hash=(hash*31+url:byte(k))%2147483647 end
        if makefolder and not (isfolder and isfolder(MUSIC_FOLDER)) then pcall(makefolder,MUSIC_FOLDER) end
        local cached
        for _,kind in ipairs({"mp3","ogg"}) do
            local candidate=MUSIC_FOLDER.."/track_"..tostring(hash).."."..kind
            if isfile and isfile(candidate) then cached=candidate end
        end
        if cached then path=cached else
            self:MusicStatus("Downloading audio...")
            local data,why=self:DownloadAudio(url)
            if not data then return nil,"Download failed: "..tostring(why) end
            if #data>20*1024*1024 then return nil,"Audio file is larger than 20 MB" end
            local kind=audioKind(data)
            if not kind then
                local head=data:sub(1,200):lower()
                if head:find("<html") or head:find("<!doctype") then return nil,"Link returned a web page, not audio. Use a direct download link" end
                return nil,"Link did not return MP3/OGG audio"
            end
            path=MUSIC_FOLDER.."/track_"..tostring(hash).."."..kind
            if not pcall(writefile,path,data) then
                path="UltimateMusic_track_"..tostring(hash).."."..kind
                if not pcall(writefile,path,data) then return nil,"Could not save the downloaded audio" end
            end
        end
    else
        path=value
        if isfile and not isfile(path) and isfile(MUSIC_FOLDER.."/"..value) then path=MUSIC_FOLDER.."/"..value end
        if isfile and not isfile(path) then return nil,"File not found in the executor workspace: "..value end
    end
    local ok,asset=pcall(custom,path)
    if not ok or type(asset)~="string" or asset=="" then return nil,"Executor could not load the audio file: "..tostring(asset) end
    return asset,(isLink and "downloaded track" or fileLabel(path)),value
end
function Extension:PlayLocalMusic(raw,volume,keepPlaylist)
    if not self.Alive then return false end
    local value=tostring(raw or ""):match("^%s*(.-)%s*$")
    if value=="" then
        -- Empty box: play the workspace music folder as a playlist.
        local tracks=self:MusicFolderTracks()
        if #tracks==0 then self:MusicStatus("Paste a direct MP3/OGG link, or put MP3/OGG files in your executor's workspace/"..MUSIC_FOLDER.." folder and press Play");return false end
        self.MusicPlaylist,self.MusicTrackIndex=tracks,1
        return self:PlayLocalMusic(tracks[1],volume,true)
    end
    if not keepPlaylist then self.MusicPlaylist,self.MusicTrackIndex=nil,nil end
    local soundId,label,remember=self:ResolveMusicSource(value)
    if not soundId then self:MusicStatus(label);return false end
    local playlist,index=self.MusicPlaylist,self.MusicTrackIndex
    self:StopLocalMusic();self.LocalMusicID=(playlist and "") or remember
    self.MusicPlaylist,self.MusicTrackIndex=playlist,index
    self.LocalMusicVolume=math.max(0,math.min(1,tonumber(volume) or self.LocalMusicVolume or .35))
    self:SetLocalHeadphones(true)
    local sound
    local suffix=playlist and string.format(" (%d/%d)",index,#playlist) or ""
    local ok,err=pcall(function()
        sound=self.Environment.Instance.new("Sound");self.LocalMusicSound=sound
        sound.Name="UltimateLocalMusic";sound.SoundId=soundId
        sound.Volume=self.LocalMusicVolume;sound.Looped=not playlist or #playlist<2
        sound.Parent=self.Environment.game:GetService("SoundService")
        if sound.Loaded then self.LocalMusicLoaded=sound.Loaded:Connect(function()
            if self.LocalMusicSound==sound then self:MusicStatus("Playing locally: "..label..suffix) end
        end) end
        if playlist and #playlist>1 and sound.Ended then
            self:Connect(sound.Ended,function() if self.LocalMusicSound==sound then self:NextLocalTrack(1) end end)
        end
        self:MusicStatus("Loading "..label..suffix)
        sound:Play()
        if sound.IsLoaded then self:MusicStatus("Playing locally: "..label..suffix) end
        self.Environment.task.delay(8,function()
            if self.LocalMusicSound==sound and not sound.IsLoaded then
                self:MusicStatus(soundId:find("^rbxassetid://") and "Audio did not load: Roblox blocked this audio ID (privacy). Use a direct MP3/OGG link or a file in workspace/"..MUSIC_FOLDER
                    or "Audio file did not load; try another MP3/OGG")
            end
        end)
    end)
    if not ok then self:StopLocalMusic();self:MusicStatus("Local audio unavailable: "..tostring(err));return false end
    return true
end
function Extension:NextLocalTrack(step)
    local playlist=self.MusicPlaylist
    if not playlist or #playlist==0 then
        playlist=self:MusicFolderTracks()
        if #playlist==0 then self:MusicStatus("No MP3/OGG files in workspace/"..MUSIC_FOLDER);return false end
        self.MusicPlaylist,self.MusicTrackIndex=playlist,0
    end
    local index=((self.MusicTrackIndex or 0)-1+(step or 1))%#playlist+1
    self.MusicTrackIndex=index
    return self:PlayLocalMusic(playlist[index],self.LocalMusicVolume,true)
end
function Extension:OpenLocalMusicPanel()
    if not self.Alive then return end
    if self.LocalMusicPanel and self.LocalMusicPanel.Parent then self.LocalMusicPanel.Visible=true;return end
    local env=self.Environment
    local parent=self.Screen
    if not parent then
        local playerGui=self.Player and self.Player:FindFirstChildOfClass("PlayerGui")
        if not playerGui then self:MusicStatus("Music controls unavailable: no local GUI");return end
        parent=env.Instance.new("ScreenGui");parent.Name="UltimateLocalMusicGui";parent.ResetOnSpawn=false;parent.Parent=playerGui
        self.LocalMusicOwnedGui=parent
    end
    local function make(class,properties,parentObject)
        local item=env.Instance.new(class)
        for key,value in pairs(properties)do item[key]=value end
        item.Parent=parentObject;return item
    end
    local panel=make("Frame",{Name="UltimateLocalMusicPanel",Size=env.UDim2.new(0,330,0,262),Position=env.UDim2.new(.5,-165,.5,-131),BackgroundColor3=env.Color3.fromRGB(17,23,39),BorderSizePixel=0,Active=true,ZIndex=100},parent)
    self.LocalMusicPanel=panel
    make("UICorner",{CornerRadius=env.UDim.new(0,8)},panel)
    local function text(class,name,caption,x,y,w,h)
        return make(class,{Name=name,Text=caption,Position=env.UDim2.new(0,x,0,y),Size=env.UDim2.new(0,w,0,h),BackgroundColor3=env.Color3.fromRGB(29,37,56),TextColor3=env.Color3.fromRGB(245,245,250),BorderSizePixel=0,TextSize=14,Font=env.Enum.Font.Gotham,ZIndex=101},panel)
    end
    local title=text("TextLabel","Title","Ultimate | Local music",10,8,270,28)
    title.Active=true
    local close=text("TextButton","Close","X",290,8,30,28)
    local id=text("TextBox","AudioId",self.LocalMusicID or "",10,46,310,32)
    id.PlaceholderText="MP3/OGG link or file (empty = UltimateMusic folder)";id.ClearTextOnFocus=false
    if env.Enum.TextTruncate then pcall(function() id.TextTruncate=env.Enum.TextTruncate.AtEnd end) end
    local volumeLabel=text("TextLabel","VolumeLabel","Volume (0-100)",10,88,160,28)
    local volume=text("TextBox","Volume",tostring(math.floor((self.LocalMusicVolume or .35)*100)),180,88,140,28)
    volume.ClearTextOnFocus=false
    local play=text("TextButton","Play","Play",10,126,150,30)
    local stop=text("TextButton","Stop","Stop",170,126,150,30)
    local previous=text("TextButton","Previous","< Prev (folder)",10,164,150,30)
    local nextTrack=text("TextButton","Next","Next (folder) >",170,164,150,30)
    self.MusicStatusLabel=text("TextLabel","Status",self.LocalMusicStatus or "Plays MP3/OGG links or files locally; Roblox IDs are often blocked",10,204,310,48)
    self.MusicStatusLabel.TextWrapped=true
    self:Connect(close.Activated,function()panel.Visible=false end)
    self:Connect(play.Activated,function()self:PlayLocalMusic(id.Text,(tonumber(volume.Text) or 35)/100)end)
    self:Connect(stop.Activated,function()self.MusicPlaylist,self.MusicTrackIndex=nil,nil;self:StopLocalMusic()end)
    self:Connect(previous.Activated,function()self.LocalMusicVolume=(tonumber(volume.Text) or 35)/100;self:NextLocalTrack(-1)end)
    self:Connect(nextTrack.Activated,function()self.LocalMusicVolume=(tonumber(volume.Text) or 35)/100;self:NextLocalTrack(1)end)
    self:Connect(volume.FocusLost,function()
        local amount=math.max(0,math.min(100,tonumber(volume.Text) or 35))
        volume.Text=tostring(amount);self.LocalMusicVolume=amount/100
        if self.LocalMusicSound then self.LocalMusicSound.Volume=amount/100 end
    end)
    local dragStart,origin
    self:Connect(title.InputBegan,function(input)
        if input.UserInputType==env.Enum.UserInputType.MouseButton1 or input.UserInputType==env.Enum.UserInputType.Touch then dragStart,origin=input.Position,panel.Position end
    end)
    self:Connect(self.Input.InputChanged,function(input)
        if dragStart and (input.UserInputType==env.Enum.UserInputType.MouseMovement or input.UserInputType==env.Enum.UserInputType.Touch) then
            local delta=input.Position-dragStart
            panel.Position=env.UDim2.new(origin.X.Scale,origin.X.Offset+delta.X,origin.Y.Scale,origin.Y.Offset+delta.Y)
        end
    end)
    self:Connect(self.Input.InputEnded,function(input)
        if input.UserInputType==env.Enum.UserInputType.MouseButton1 or input.UserInputType==env.Enum.UserInputType.Touch then dragStart,origin=nil,nil end
    end)
end
function Extension:DestroyLocalHeadphones()
    self:SetLocalHeadphones(false)
    if self.LocalMusicPanel then pcall(function()self.LocalMusicPanel:Destroy()end) end
    if self.LocalMusicOwnedGui then pcall(function()self.LocalMusicOwnedGui:Destroy()end) end
    self.LocalMusicPanel,self.MusicStatusLabel,self.LocalMusicOwnedGui=nil,nil,nil
end
