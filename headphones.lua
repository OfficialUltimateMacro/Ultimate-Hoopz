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
        local top=head.Size.Y/2+.12
        local dark=env.Color3.fromRGB(24,26,39)
        local cushion=env.Color3.fromRGB(10,11,17)
        local accent=env.Color3.fromRGB(255,95,163)
        local function piece(name,size,offset,color,neon)
            local part=env.Instance.new("Part");part.Name=name;part.Size=size
            part.Anchored=false;part.Massless=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false
            part.Color=color;part.Material=neon and env.Enum.Material.Neon or env.Enum.Material.SmoothPlastic
            part.CFrame=head.CFrame*env.CFrame.new(offset.X,offset.Y,offset.Z)
            part.Parent=model
            local weld=env.Instance.new("WeldConstraint");weld.Part0=head;weld.Part1=part;weld.Parent=part
        end
        local v=env.Vector3.new
        piece("BandTop",v(width*2+.28,.13,.3),v(0,top,0),dark)
        piece("BandAccent",v(width*2+.15,.035,.14),v(0,top+.075,0),accent,true)
        for _,side in ipairs({-1,1})do
            local tag=side<0 and "Left" or "Right"
            piece(tag.."Band",v(.12,top,.3),v(side*(width+.08),top/2,0),dark)
            piece(tag.."Cushion",v(.16,.63,.59),v(side*(width+.04),0,0),cushion)
            piece(tag.."Cup",v(.25,.72,.65),v(side*(width+.23),0,0),dark)
            piece(tag.."Accent",v(.035,.42,.35),v(side*(width+.375),0,0),accent,true)
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
    if not self.LocalMusicSound then self:MusicStatus("Headphones on; enter an audio ID to play") end
end
function Extension:PlayLocalMusic(raw,volume)
    if not self.Alive then return false end
    local value=tostring(raw or ""):match("^%s*(.-)%s*$")
    local id=value:match("^(%d+)$") or value:match("^rbxassetid://(%d+)$")
    if not id or #id>20 or not id:find("[1-9]") then self:MusicStatus("Enter a numeric Roblox audio ID");return false end
    self:StopLocalMusic();self.LocalMusicID=id
    self.LocalMusicVolume=math.max(0,math.min(1,tonumber(volume) or self.LocalMusicVolume or .35))
    self:SetLocalHeadphones(true)
    local sound
    local ok,err=pcall(function()
        sound=self.Environment.Instance.new("Sound");self.LocalMusicSound=sound
        sound.Name="UltimateLocalMusic";sound.SoundId="rbxassetid://"..id
        sound.Volume=self.LocalMusicVolume;sound.Looped=true
        sound.Parent=self.Environment.game:GetService("SoundService")
        if sound.Loaded then self.LocalMusicLoaded=sound.Loaded:Connect(function()
            if self.LocalMusicSound==sound then self:MusicStatus("Playing locally: "..id) end
        end) end
        self:MusicStatus("Loading audio (must be available to this experience)")
        sound:Play()
        if sound.IsLoaded then self:MusicStatus("Playing locally: "..id) end
        self.Environment.task.delay(8,function()
            if self.LocalMusicSound==sound and not sound.IsLoaded then
                self:MusicStatus("Audio did not load; check ID and audio permissions")
            end
        end)
    end)
    if not ok then self:StopLocalMusic();self:MusicStatus("Local audio unavailable: "..tostring(err));return false end
    return true
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
    local panel=make("Frame",{Name="UltimateLocalMusicPanel",Size=env.UDim2.new(0,330,0,220),Position=env.UDim2.new(.5,-165,.5,-110),BackgroundColor3=env.Color3.fromRGB(17,23,39),BorderSizePixel=0,Active=true,ZIndex=100},parent)
    self.LocalMusicPanel=panel
    make("UICorner",{CornerRadius=env.UDim.new(0,8)},panel)
    local function text(class,name,caption,x,y,w,h)
        return make(class,{Name=name,Text=caption,Position=env.UDim2.new(0,x,0,y),Size=env.UDim2.new(0,w,0,h),BackgroundColor3=env.Color3.fromRGB(29,37,56),TextColor3=env.Color3.fromRGB(245,245,250),BorderSizePixel=0,TextSize=14,Font=env.Enum.Font.Gotham,ZIndex=101},panel)
    end
    local title=text("TextLabel","Title","Ultimate | Local music",10,8,270,28)
    title.Active=true
    local close=text("TextButton","Close","X",290,8,30,28)
    local id=text("TextBox","AudioId",self.LocalMusicID or "",10,46,310,32)
    id.PlaceholderText="Roblox audio ID";id.ClearTextOnFocus=false
    local volumeLabel=text("TextLabel","VolumeLabel","Volume (0-100)",10,88,160,28)
    local volume=text("TextBox","Volume",tostring(math.floor((self.LocalMusicVolume or .35)*100)),180,88,140,28)
    volume.ClearTextOnFocus=false
    local play=text("TextButton","Play","Play",10,126,150,30)
    local stop=text("TextButton","Stop","Stop",170,126,150,30)
    self.MusicStatusLabel=text("TextLabel","Status",self.LocalMusicStatus or "Local only; headphones are custom cosmetics",10,166,310,44)
    self.MusicStatusLabel.TextWrapped=true
    self:Connect(close.Activated,function()panel.Visible=false end)
    self:Connect(play.Activated,function()self:PlayLocalMusic(id.Text,(tonumber(volume.Text) or 35)/100)end)
    self:Connect(stop.Activated,function()self:StopLocalMusic()end)
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
