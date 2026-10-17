-- Readable additions to Blessed. Acquisition stays in its original Ball Check
-- selector; jump matching subscribes to that selector's current player only.
UltimateExtensions = {
    Alive = true, Connections = {}, LastJump = -100, LastShot = -100,
    LastBallScan = -100, Clock = 0, AutoPlayStatus = "Off", ManualUntil = 0
}
local Extension = UltimateExtensions
local function disconnect(connection) if connection then connection:Disconnect() end end
local function characterParts(player)
    local character = player and player.Character
    if not character or not character.Parent then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if humanoid and root and humanoid.Health > 0 then return character, humanoid, root end
end
local function heldBall(character)
    return character and character:FindFirstChild("Basketball")
end
local function distance(a, b)
    return (a - b).Magnitude
end
function Extension:Connect(signal, callback)
    local connection = signal:Connect(callback)
    self.Connections[#self.Connections + 1] = connection
    return connection
end
function Extension:ClearTarget()
    disconnect(self.JumpConnection)
    self.JumpConnection, self.Target, self.TargetCharacter, self.TargetHumanoid = nil, nil, nil, nil
end
function Extension:IsManual()
    local input, enum = self.Input, self.Environment.Enum
    if input:GetFocusedTextBox() then return true end
    for _, name in ipairs({"W", "A", "S", "D", "Up", "Down", "Left", "Right"}) do
        if input:IsKeyDown(enum.KeyCode[name]) then self.ManualUntil = self.Clock + 0.3; return true end
    end
    return self.Clock < self.ManualUntil
end
function Extension:MirrorJump(player, humanoid)
    if not self.Alive or not self.Settings or not self.Settings.AutoGuard
        or not self.Settings.AutoGuardJumpMatch or self:IsManual() then return false end
    -- Re-run the SAME selector, including Ball Check and its 50-stud limit.
    local selected = self.Selector and self.Selector()
    if selected ~= player then self:SelectTarget(selected); return false end
    if self.Target ~= player or self.TargetHumanoid ~= humanoid or player.Character ~= self.TargetCharacter then return false end
    local ownCharacter, ownHumanoid = characterParts(self.Player)
    if not ownHumanoid or heldBall(ownCharacter) or ownHumanoid.FloorMaterial == self.Environment.Enum.Material.Air
        or self.Clock - self.LastJump < 0.25 then return false end
    ownHumanoid.Jump, self.LastJump = true, self.Clock
    return true
end
function Extension:SelectTarget(player)
    local character, humanoid, root = characterParts(player)
    if self.Target == player and self.TargetCharacter == character and self.TargetHumanoid == humanoid then return end
    self:ClearTarget()
    if not character or not self.Settings or not self.Settings.AutoGuard then return end
    self.Target, self.TargetCharacter, self.TargetHumanoid = player, character, humanoid
    self.JumpConnection = humanoid.Jumping:Connect(function(active)
        if active then self:MirrorJump(player, humanoid) end
    end)
    -- Also catch a jump already underway when a new carrier is selected.
    if humanoid.FloorMaterial == self.Environment.Enum.Material.Air and root.AssemblyLinearVelocity.Y > 1 then
        self:MirrorJump(player, humanoid)
    end
end
function Extension:SetFeature(name, value)
    local captures = self.InputCaptures
    local toggle = captures and captures[name == "Aimbot" and 1 or (name == "AutoGuard" and 3 or -1)]
    self.Settings[name] = value
    if toggle and type(toggle.SetValue) == "function" then pcall(toggle.SetValue, value) end
    if name == "AutoGuard" and not value then self:ClearTarget() end
end
function Extension:GuardKey(input, processed, captures)
    if not self.Alive or processed or self.Input:GetFocusedTextBox() then return end
    local settings = captures[0] or self.Settings
    if not settings or input.KeyCode ~= settings.AutoGuardKeybind then return end
    self.Settings, self.InputCaptures = settings, captures
    local enabled = not settings.AutoGuard
    self:SetFeature("AutoGuard", enabled)
    -- Guard-only notification: never fall through into the old Aimbot branch.
    if captures[2] and type(captures[2].Notification) == "function" then
        pcall(function()
            captures[2].Notification().new({Title = "Auto Guard", Description = enabled and "Enabled" or "Disabled", Duration = 2})
        end)
    end
end
function Extension:StopAutoMove()
    self.AutoMovePoint = nil
    if self.AutoMoving then
        local _, humanoid, root = characterParts(self.Player)
        if humanoid then humanoid:MoveTo(root.Position) end
    end
    self.AutoMoving = false
end
function Extension:SetAutoPlay(enabled)
    if not self.Settings then return end
    enabled = enabled == true
    if self.Settings.AutoPlay == enabled then return end
    self.Settings.AutoPlay = enabled
    if enabled then
        self.AutoPlaySnapshot = {}
        for _, name in ipairs({"Aimbot", "AutoGuard", "BallMagnet", "BallReach"}) do
            self.AutoPlaySnapshot[name] = self.Settings[name]
            self:SetFeature(name, true)
        end
        self.AutoPlayStatus = "Experimental: scanning"
    else
        self:StopAutoMove()
        for name, value in pairs(self.AutoPlaySnapshot or {}) do
            -- Restore only values that still match the ones Auto-play applied.
            if self.Settings[name] == true then self:SetFeature(name, value) end
        end
        self.AutoPlaySnapshot, self.AutoPlayStatus = nil, "Off"
    end
end
function Extension:LooseBall(root)
    if self.Clock - self.LastBallScan >= 1 then
        self.LastBallScan, self.Balls = self.Clock, {}
        local players = self.Players:GetPlayers()
        for _, part in ipairs(self.Environment.workspace:GetDescendants()) do
            if part:IsA("BasePart") and (part.Name == "Ball" or part.Name == "Basketball") then
                local owned = false
                for _, player in ipairs(players) do
                    if player.Character and part:IsDescendantOf(player.Character) then owned = true; break end
                end
                if not owned then self.Balls[#self.Balls + 1] = part end
            end
        end
    end
    local nearest, best = nil, 50
    for _, part in ipairs(self.Balls or {}) do
        if part.Parent then
            local owned = false
            for _, player in ipairs(self.Players:GetPlayers()) do
                if player.Character and part:IsDescendantOf(player.Character) then owned = true; break end
            end
            local d = distance(root.Position, part.Position)
            if not owned and d < best then nearest, best = part, d end
        end
    end
    return nearest
end
function Extension:InShotRange(root)
    local high = self.Settings.AimbotType == "High"
    local minimum, maximum = high and 57 or 58, high and 73 or 74
    local goals = self.Collection:GetTagged("FieldGoals")
    for _, goal in ipairs(goals) do
        if goal:IsA("BasePart") then
            local d = distance(root.Position, goal.Position)
            if d >= minimum and d < maximum then return true end
        end
    end
    return false
end
function Extension:AutoPlayStep(character, humanoid, root)
    if self:IsManual() then self:StopAutoMove(); self.AutoPlayStatus = "Paused: manual input"; return end
    if heldBall(character) then
        self:StopAutoMove()
        self.AutoPlayStatus = "Waiting for calibrated shot position"
        if self.Settings.Aimbot and self.AimAction and not self.Shooting and self.Clock - self.LastShot >= 1.25 and self:InShotRange(root) then
            self.Shooting, self.LastShot, self.AutoPlayStatus = true, self.Clock, "Shooting (experimental)"
            self.Environment.task.spawn(function()
                if self.Alive and self.Settings.AutoPlay and self.Player.Character == character and heldBall(character) then
                    humanoid.Jump = true
                    local ok, message = pcall(self.AimAction)
                    if not ok then self.AutoPlayStatus = "Shot unavailable: " .. tostring(message) end
                end
                self.Shooting = false
            end)
        end
    elseif self.Target and self.Settings.AutoGuard then
        self:StopAutoMove(); self.AutoPlayStatus = "Defending the Ball Check target"
    else
        local ball = self:LooseBall(root)
        if ball then
            self.AutoMovePoint, self.AutoPlayStatus = ball.Position, "Seeking loose ball"
        else self:StopAutoMove(); self.AutoPlayStatus = "Scanning nearby balls" end
    end
end
function Extension:Tick(dt)
    if not self.Alive or not self.Settings then return end
    self.Clock = self.Clock + math.max(0, math.min(dt, 0.5))
    self.TickAccumulator = (self.TickAccumulator or 0) + dt
    if self.TickAccumulator < 0.1 then return end
    self.TickAccumulator = 0
    local character, humanoid, root = characterParts(self.Player)
    if not humanoid then self:ClearTarget(); self:StopAutoMove(); self.AutoPlayStatus = "Waiting for respawn"; return end
    if self.Settings.AutoGuard and self.Selector and not heldBall(character) and not self:IsManual() then
        self:SelectTarget(self.Selector())
    else self:ClearTarget() end
    if self.Settings.AutoPlay then self:AutoPlayStep(character, humanoid, root) end
end
function Extension:Install(environment, settings)
    -- Blessed can initialize a second settings table while choosing its game
    -- branch. Rebind to that table without installing a second event loop.
    if self.Installed then
        self.Settings = settings
        settings.AimbotKeybind = nil
        settings.AutoGuardJumpMatch = UltimatePreferences.MatchTargetJump
        settings.AutoPlay = false
        return
    end
    self.Installed, self.Environment, self.Settings = true, environment, settings
    self.Players = environment.game:GetService("Players")
    self.Player = self.Players.LocalPlayer
    self.Input = environment.game:GetService("UserInputService")
    self.Run = environment.game:GetService("RunService")
    self.Collection = environment.game:GetService("CollectionService")
    settings.AimbotKeybind = nil
    settings.AutoGuardJumpMatch = UltimatePreferences.MatchTargetJump
    settings.AutoPlay = false
    self:Connect(self.Run.Heartbeat, function(dt)
        local ok, message = pcall(self.Tick, self, dt)
        if not ok then
            self:StopAutoMove(); self:SetAutoPlay(false)
            self.AutoPlayStatus = "Paused: " .. tostring(message)
        end
    end)
    self.RenderName = "UltimateAutoPlay_" .. tostring(self)
    self.Run:BindToRenderStep(self.RenderName, environment.Enum.RenderPriority.Camera.Value + 1, function()
        if self.Alive and self.Settings.AutoPlay and self.AutoMovePoint and not self.Target and not self:IsManual() then
            local character, humanoid = characterParts(self.Player)
            if humanoid and not heldBall(character) then humanoid:MoveTo(self.AutoMovePoint); self.AutoMoving = true end
        end
    end)
end
function Extension:InstallControls(section)
    if self.ControlsInstalled or not self.Settings then return end
    self.ControlsInstalled = true
    section:NewToggle({Title = "Match target jump", Default = true, Callback = function(value)
        self.Settings.AutoGuardJumpMatch = value
    end})
    section:NewToggle({Title = "Auto-play (Experimental)", Default = false, Callback = function(value)
        self:SetAutoPlay(value)
    end})
end
function Extension:ObserveInstance(target, key, value, environment)
    if key == "Name" and value == "RobloxGameGui" and environment.typeof(target) == "Instance" then
        self.Screen = target
        self:Connect(target.Destroying, function() self:Destroy() end)
    end
end
function Extension:Destroy()
    if not self.Alive then return end
    self:SetAutoPlay(false)
    self:ClearTarget(); self:StopAutoMove()
    self.Alive = false
    for _, connection in ipairs(self.Connections) do disconnect(connection) end
    self.Connections = {}
    if self.Run and self.RenderName then self.Run:UnbindFromRenderStep(self.RenderName) end
end
customizeClosure = function(name, original, environment, captures)
    if name == "root.2169" then
        Extension.InputCaptures = captures
        return function(input, processed) return Extension:GuardKey(input, processed, captures) end
    elseif name == "root.2115" then
        Extension.Selector = original
        return function(...)
            local player = original(...)
            if Extension.Installed then Extension:SelectTarget(player) end
            return player
        end
    elseif name == "root.106" then
        Extension.AimAction = original
    elseif name == "root.2138" then
        return function(...)
            if Extension.Installed and Extension:IsManual() then Extension:ClearTarget(); return end
            return original(...)
        end
    end
    return original
end
local function observeUltimateRoot(environment, registers, pc)
    local settings = registers[15]
    if (not Extension.Installed or Extension.Settings ~= settings) and type(settings) == "table" and settings.AutoGuardKeybind ~= nil
        and settings.AntiDrop ~= nil and settings.BallMagnetStrength ~= nil then
        Extension:Install(environment, settings)
    end
    if pc == 1213 and Extension.Installed then Extension:InstallControls(registers[23]) end
end
