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
    -- A physical Space press is a manual jump/shot; ignore our own synthetic
    -- Space pulses and the jump an Auto-play shot is performing.
    local space = enum.KeyCode.Space
    if space and input:IsKeyDown(space) and not self.Shooting and not self.ExecutorJumpHeld
        and not (self.DribbleKeys and self.DribbleKeys[space]) then
        self.ManualUntil = self.Clock + 0.3; return true
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
    if settings and settings.AutoPlayKeybind and input.KeyCode == settings.AutoPlayKeybind
        and input.KeyCode ~= settings.AutoGuardKeybind then
        self.Settings, self.InputCaptures = settings, captures
        self:SetAutoPlay(not settings.AutoPlay)
        if captures[2] and type(captures[2].Notification) == "function" then
            pcall(function()
                captures[2].Notification().new({Title = "Auto-play", Description = settings.AutoPlay and "Enabled" or "Disabled", Duration = 2})
            end)
        end
        return
    end
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
    self.AutoMovePoint, self.LastMoveToPoint = nil, nil
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
    if self.AutoPlayToggle and type(self.AutoPlayToggle.SetValue) == "function" then
        pcall(self.AutoPlayToggle.SetValue, enabled)
    end
    if enabled then
        self.AutoPlaySnapshot = {}
        for _, name in ipairs({"Aimbot", "AutoGuard", "BallMagnet", "BallReach"}) do
            self.AutoPlaySnapshot[name] = self.Settings[name]
            self:SetFeature(name, true)
        end
        self.AutoPlayStatus = "Experimental: scanning"
    else
        if self.ResetOffense then self:ResetOffense() end
        self:StopAutoMove()
        for name, value in pairs(self.AutoPlaySnapshot or {}) do
            -- Restore only values that still match the ones Auto-play applied.
            if self.Settings[name] == true then self:SetFeature(name, value) end
        end
        self.AutoPlaySnapshot, self.AutoPlayStatus = nil, "Off"
    end
end
function Extension:LooseBall(root)
    local nearest, best = nil, 50
    for part in pairs(self:BallSet()) do
        if part.Parent and not self:BallOwner(part) then
            local d = distance(root.Position, part.Position)
            if d < best then nearest, best = part, d end
        end
    end
    return nearest
end
function Extension:InShotRange(root)
    local high = self.Settings.AimbotType == "High"
    local minimum, maximum = high and 57 or 58, high and 73 or 74
    local goals = self.Goals and self:Goals() or self.Collection:GetTagged("FieldGoals")
    for _, goal in ipairs(goals) do
        if goal:IsA("BasePart") then
            local d = distance(root.Position, goal.Position)
            if d >= minimum and d < maximum then return true end
        end
    end
    return false
end
function Extension:AutoPlayStep(character, humanoid, root)
    if self:IsManual() then
        if self.ResetOffense and self.OffenseCharacter then self:ResetOffense() end
        self:StopAutoMove(); self.AutoPlayStatus = "Paused: manual input"; return
    end
    if heldBall(character) then
        self:ClearTarget()
        if self.OffenseStep and not self:OffenseStep(character, humanoid, root) then return end
        self:StopAutoMove()
        self.AutoPlayStatus = "Open shot: settling"
        if self.Settings.Aimbot and self.AimAction and not self.Shooting and self.Clock - self.LastShot >= 1.25 and self:InShotRange(root) then
            self.Shooting, self.LastShot, self.AutoPlayStatus = true, self.Clock, "Shooting (experimental)"
            self.Environment.task.spawn(function()
                local function valid()
                    return self.Alive and self.Settings.AutoPlay and not self:IsManual() and self.Player.Character == character
                        and humanoid.Health > 0 and heldBall(character) and self:InShotRange(root)
                        and (not self.CanTakeShot or self:CanTakeShot(root))
                end
                local ok, message = pcall(function()
                    if not valid() then return end
                    self.ShotAttempt = {Valid=valid, Dispatched=false}
                    local goalAtShot=self.OffenseGoal
                    local attempt=self.ShotAttempt
                    self.ShotAttempts=(self.ShotAttempts or 0)+1
                    self.AutoJumpSuppressUntil=self.Clock+0.7
                    self.AutoPlayStatus = "Jumping for shot"
                    -- JumpRequest starts Blessed's delayed shot BEFORE takeoff.
                    -- Schedule that same routine independently of jump detection.
                    attempt.Dispatched=true
                    self.Environment.task.spawn(function()
                        local shotOK,shotError=pcall(function()
                            if attempt.Valid() then
                                self.AimDepth=(self.AimDepth or 0)+1
                                local aimOK,aimError=pcall(self.AimAction)
                                self.AimDepth=math.max(0,self.AimDepth-1)
                                if not aimOK then error(aimError,0) end
                                attempt.Ran=true
                                -- Verify from the routine's own completion; the
                                -- original yields for ShotDelay before clicking.
                                if self.StartShotTrack then self:StartShotTrack("Shot", character, self.OffenseGoal or goalAtShot, nil) end
                            end
                        end)
                        attempt.Completed=true
                        if not shotOK then attempt.Error=tostring(shotError) end
                    end)
                    local jumped=self:RequestAutoJump(humanoid,root,valid)
                    self.LastJumpConfirmed=jumped
                    for _=1,40 do
                        if attempt.Completed or not self.Alive then break end
                        self.Environment.task.wait(0.025)
                    end
                    if attempt.Error then error(attempt.Error) end
                    self.LastShotResult=jumped and "Shot routine sent with jump" or "Shot routine sent; jump unconfirmed"

                    self.AutoPlayStatus=self.LastShotResult
                end)
                if not ok then
                    self.LastShotResult = "Shot error: " .. tostring(message)
                    self.AutoPlayStatus = self.LastShotResult
                end
                if self.ReleaseJumpKey then self:ReleaseJumpKey() end
                self.ShotAttempt = nil
                self.Shooting = false
            end)
        end
    elseif self.Target and self.Settings.AutoGuard then
        if self.ResetOffense and self.OffenseCharacter then self:ResetOffense() end
        self:StopAutoMove(); self.AutoPlayStatus = "Defending the Ball Check target"
    else
        if self.ResetOffense and self.OffenseCharacter then self:ResetOffense() end
        local ball = self:LooseBall(root)
        if ball then
            local reads = self.ReadOpponents and self:ReadOpponents(root) or {}
            local close = (ball.Position-root.Position).Magnitude < 6
            self.AutoMovePoint = (not close and self.SteerTo) and (self:SteerTo(root, ball.Position, reads) or ball.Position) or ball.Position
            self.AutoPlayStatus = self.AutoMovePoint and "Seeking loose ball" or "Pickup route blocked"
        else self:StopAutoMove(); self.AutoPlayStatus = "Scanning nearby balls" end
    end
end
function Extension:Tick(dt)
    if not self.Alive or not self.Settings then return end
    self.Clock = self.Clock + math.max(0, math.min(dt, 0.5))
    if self.ReleaseDribbleKeys then self:ReleaseDribbleKeys(false) end
    if self.ShotTrack and self.TrackShot then self:TrackShot() end
    self.TickAccumulator = (self.TickAccumulator or 0) + dt
    if self.TickAccumulator < 0.1 then return end
    self.TickAccumulator = 0
    if self.Settings.PlayerCollisions and self.UpdatePlayerCollisions then self:UpdatePlayerCollisions() end
    local character, humanoid, root = characterParts(self.Player)
    if not humanoid then
        if self.ResetOffense then self:ResetOffense() end
        self:ClearTarget(); self:StopAutoMove(); self.AutoPlayStatus = "Waiting for respawn"; return
    end
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
        settings.AutoPlayDribble = true
        settings.AutoPlayBasket = "Nearest"
        settings.PlayerCollisions = false
        settings.AutoPlayKeybind = environment.Enum.KeyCode.J
        settings.AutoPlayCamera = true
        settings.AutoPlayDunk = true
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
    settings.AutoPlayDribble = true
    settings.AutoPlayBasket = "Nearest"
    settings.PlayerCollisions = false
    settings.AutoPlayKeybind = environment.Enum.KeyCode.J
    settings.AutoPlayCamera = true
    settings.AutoPlayDunk = true
    self:Connect(self.Run.Heartbeat, function(dt)
        local ok, message = pcall(self.Tick, self, dt)
        if not ok then
            self:StopAutoMove(); self:SetAutoPlay(false)
            self.AutoPlayStatus = "Paused: " .. tostring(message)
        end
    end)
    self.RenderName = "UltimateAutoPlay_" .. tostring(self)
    self.Run:BindToRenderStep(self.RenderName, environment.Enum.RenderPriority.Camera.Value + 1, function(dt)
        if self.UpdateAutoFacing then
            local ok=pcall(self.UpdateAutoFacing,self,dt or 1/60)
            if not ok and self.ReleaseAutoFacing then self:ReleaseAutoFacing() end
        end
        if self.Alive and self.Settings.AutoPlay and self.AutoMovePoint and not self.Target and not self:IsManual() then
            local character, humanoid, root = characterParts(self.Player)
            local action = humanoid and self.GameAction and self:GameAction(character)
            if action == "Shooting" or action == "Dunking" then
                self:StopAutoMove()
            elseif humanoid and not self.Shooting then
                -- Re-issue MoveTo only when the target meaningfully changes
                -- (or to refresh Roblox's 8 s MoveTo timeout).
                local last = self.LastMoveToPoint
                if not self.AutoMoving or self.LastMoveToHumanoid ~= humanoid or not last
                    or (last-self.AutoMovePoint).Magnitude > 0.4 or self.Clock-(self.LastMoveToTime or -100) > 1 then
                    humanoid:MoveTo(self.AutoMovePoint); self.AutoMoving = true
                    self.LastMoveToPoint, self.LastMoveToTime, self.LastMoveToHumanoid = self.AutoMovePoint, self.Clock, humanoid
                end
                local ball = heldBall(character)
                if self.ChooseDribble and ball then
                    pcall(self.ChooseDribble,self,root,self.AutoMovePoint,self.OpponentReads or {},ball)
                end
            end
        end
    end)
end
function Extension:InstallControls(section)
    if self.ControlsInstalled or not self.Settings then return end
    self.ControlsInstalled = true
    section:NewToggle({Title = "Match target jump", Default = true, Callback = function(value)
        self.Settings.AutoGuardJumpMatch = value
    end})
    self.AutoPlayToggle = section:NewToggle({Title = "Auto-play", Default = false, Callback = function(value)
        self:SetAutoPlay(value)
    end})
    section:NewKeybind({Title = "Auto-play key", Default = self.Settings.AutoPlayKeybind, Hold = false, Callback = function(value)
        self.Settings.AutoPlayKeybind = value
    end})
    section:NewToggle({Title = "Auto-play dribble", Default = true, Callback = function(value)
        self.Settings.AutoPlayDribble = value
        if not value and self.ReleaseDribbleKeys then self:ReleaseDribbleKeys(true) end
    end})
    section:NewToggle({Title = "Auto-play camera", Default = true, Callback = function(value)
        self.Settings.AutoPlayCamera=value
        if not value and self.ReleaseAutoFacing then self:ReleaseAutoFacing() end
    end})
    section:NewToggle({Title = "Auto-dunk", Default = true, Callback = function(value)
        self.Settings.AutoPlayDunk=value
    end})
    section:NewButton({Title = "Shot status", Callback = function()
        local captures=self.InputCaptures
        if captures and captures[2] and type(captures[2].Notification)=="function" then
            pcall(function()
                captures[2].Notification().new({Title="Auto-play shot status",Description=(self.LastShotResult or "No shot routine sent yet")
                    .."\n"..tostring(self.AutoPlayStatus).." / "..tostring(self.ShotBlockReason or "-")
                    .."\nShots sent "..tostring(self.ShotAttempts or 0).." | released "..tostring(self.ShotsReleased or 0)
                    .." | reached rim "..tostring(self.ShotsNearRim or 0)
                    .."\nDunks sent "..tostring(self.DunkAttempts or 0).." | started "..tostring(self.DunksStarted or 0),Duration=8})
            end)
        end
    end})
    section:NewDropdown({Title = "Attack basket", Data = {"Nearest", "Second nearest"}, Default = "Nearest", Callback = function(value)
        self.Settings.AutoPlayBasket = value
        if self.ResetOffense then self:ResetOffense() end
    end})
    section:NewToggle({Title = "Player collisions", Default = false, Callback = function(value)
        self:SetPlayerCollisions(value)
    end})
end
-- Local torso contact only. No impulses, velocity changes, or ownership calls.
function Extension:RestoreCollisionPart(part, record)
    for key, saved in pairs(record) do
        pcall(function()
            if part[key] == saved.Applied then part[key] = saved.Original end
        end)
    end
end
function Extension:ClearPlayerCollisions()
    for part, record in pairs(self.CollisionParts or {}) do self:RestoreCollisionPart(part, record) end
    self.CollisionParts = {}
end
function Extension:SetPlayerCollisions(enabled)
    if not self.Settings then return end
    self.Settings.PlayerCollisions = enabled == true and self.Alive
    if self.Settings.PlayerCollisions then
        self:UpdatePlayerCollisions()
    else self:ClearPlayerCollisions();self.CollisionStatus = "Off" end
end
function Extension:UpdatePlayerCollisions()
    if not self.Alive or not self.Settings.PlayerCollisions then self:ClearPlayerCollisions();return end
    local character, _, root = characterParts(self.Player)
    local wanted = {}
    if character then
        for _, player in ipairs(self.Players:GetPlayers()) do
            local other, _, otherRoot = characterParts(player)
            if other and (player == self.Player or distance(root.Position,otherRoot.Position) <= 20) then
                for _, name in ipairs({"Torso", "UpperTorso", "LowerTorso"}) do
                    local part = other:FindFirstChild(name)
                    if part and part:IsA("BasePart") and not part.Anchored then wanted[part] = true end
                end
            end
        end
    end
    self.CollisionParts = self.CollisionParts or {}
    for part, record in pairs(self.CollisionParts) do
        if not wanted[part] then self:RestoreCollisionPart(part,record);self.CollisionParts[part] = nil end
    end
    local applied, failed = 0, false
    for part in pairs(wanted) do
        local record = self.CollisionParts[part] or {}
        self.CollisionParts[part] = record
        for key, value in pairs({CanCollide=true, CollisionGroup="Default"}) do
            local ok = pcall(function()
                local current = part[key]
                if not record[key] then record[key] = {Original=current,Applied=value}
                elseif current ~= value then record[key].Original = current end
                if current ~= value then part[key] = value end
            end)
            if not ok then failed = true end
        end
        applied = applied+1
    end
    self.CollisionStatus = failed and "Some local properties unavailable" or (applied > 0 and "Local torso contacts enabled" or "Waiting for character")
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
    self:SetPlayerCollisions(false)
    if self.ResetOffense then self:ResetOffense() end
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
        return function(...)
            -- Let the normal JumpRequest path keep its original ShotDelay timing.
            -- Claim once; the queued fallback must not issue a duplicate shot.
            if Extension.Shooting and Extension.Settings and Extension.Settings.AutoPlay then
                local attempt=Extension.ShotAttempt
                if not attempt or attempt.Dispatched or not attempt.Valid() then return end
                attempt.Dispatched=true
                Extension.AimDepth=(Extension.AimDepth or 0)+1
                local ok,message=pcall(original,...)
                Extension.AimDepth=math.max(0,Extension.AimDepth-1)
                attempt.Ran=ok or nil
                attempt.Completed=true
                if not ok then attempt.Error=tostring(message) end
                return
            end
            if Extension.Settings and Extension.Settings.AutoPlay and Extension.AutoJumpSuppressUntil
                and Extension.Clock < Extension.AutoJumpSuppressUntil then return end
            -- Manual Space shot: keep the camera assist off the camera while
            -- the original routine aims it (it saves, aims, clicks, restores).
            Extension.AimDepth=(Extension.AimDepth or 0)+1
            if Extension.ReleaseAutoFacing then pcall(Extension.ReleaseAutoFacing, Extension) end
            local results=table.pack(pcall(original,...))
            Extension.AimDepth=math.max(0,Extension.AimDepth-1)
            if not results[1] then error(results[2],0) end
            return table.unpack(results,2,results.n)
        end
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
