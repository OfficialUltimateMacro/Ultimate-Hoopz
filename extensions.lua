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
-- Possession. Blessed's own selector counts a player as the handler only when
-- Character.Basketball contains a "Ball"; an empty container can remain after
-- a turnover. Once that layout has been observed, require it.
local BallLayout = {Learned = false}
local function heldBall(character)
    local container = character and character:FindFirstChild("Basketball")
    if not container then return nil end
    local ok, ball = pcall(function() return container.FindFirstChild and container:FindFirstChild("Ball") end)
    if ok and ball then BallLayout.Learned = true; return container end
    if BallLayout.Learned then return nil end
    return container
end
local function distance(a, b)
    return (a - b).Magnitude
end
-- Bounded diagnostics: a ring buffer of transitions/events, never per-frame.
function Extension:Log(kind, text)
    local log = self.EventLog or {}
    self.EventLog = log
    local stamp = string.format("T+%.1f", self.Clock-(self.AutoPlayStarted or 0))
    local okDate, wall = pcall(function() return os.date("%H:%M:%S") end)
    if okDate and wall then stamp = wall.." "..stamp end
    self.EventSequence=(self.EventSequence or 0)+1
    log[#log+1] = stamp.." [run "..tostring(self.RunSerial or 0).." #"..self.EventSequence.."] "..kind..": "..tostring(text)
    if #log > 60 then table.remove(log, 1) end
end
function Extension:CaptureTrace()
    if not self.Settings.AutoPlay or self.Clock<(self.NextTrace or -100) then return end
    self.NextTrace=self.Clock+0.5
    local _,h,root=characterParts(self.Player)
    if not root then return end
    local goal=self.OffenseGoal or self.MatchGoal
    local power="?";pcall(function()power=tostring(self.Player:GetAttribute("Power"))end)
    local gap,predGap=999,999
    for _,read in ipairs(self.OpponentReads or {})do
        gap=math.min(gap,distance(root.Position,read.Position));predGap=math.min(predGap,distance(root.Position,read.Predicted))
    end
    local row=string.format("run="..tostring(self.RunSerial or 0).." T+%.2f state=%s pos=(%.1f,%.1f,%.1f) speed=%.1f rim=%.1f power=%s shield=%s setup=%s move=%s route=%s shot=%s",
        self.Clock-(self.AutoPlayStarted or 0),tostring(self.State),root.Position.X,root.Position.Y,root.Position.Z,
        root.AssemblyLinearVelocity.Magnitude,goal and distance(root.Position,goal.Position) or -1,power,
        tostring(self.ProtectFacing==true),tostring(self.PreparingShot==true),tostring(self.DribbleStatus).." spacing="..tostring(self.SpacingReason or "-"),
        tostring(self.AutoPlayStatus),tostring(self.ShotBlockReason))
    row=row..string.format(" gap=%.1f predictedGap=%.1f reroutes=%d retreat=%s",gap,predGap,self.RerouteCount or 0,tostring(self.TurnoverRetreat==true))
    row=row.." strategy="..(self.AdaptiveRimOnly and "rim" or "normal").." refused="..tostring(self.MoveRefusal or "-")
    self.TraceLog=self.TraceLog or {};table.insert(self.TraceLog,row)
    if #self.TraceLog>120 then table.remove(self.TraceLog,1) end
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
    if input:GetFocusedTextBox() then self.ManualReason = "typing"; return true end
    for _, name in ipairs({"W", "A", "S", "D", "Up", "Down", "Left", "Right"}) do
        if input:IsKeyDown(enum.KeyCode[name]) then self.ManualUntil = self.Clock + 0.3; self.ManualReason = name; return true end
    end
    -- A physical Space press is a manual jump/shot; ignore our own synthetic
    -- Space pulses and the jump an Auto-play shot is performing.
    local space = enum.KeyCode.Space
    if space and input:IsKeyDown(space) and not self.Shooting and not self.ExecutorJumpHeld
        and not (self.DribbleKeys and self.DribbleKeys[space]) then
        self.ManualUntil = self.Clock + 0.3; self.ManualReason = "Space"; return true
    end
    return self.Clock < self.ManualUntil
end
function Extension:MirrorJump(player, humanoid)
    if not self.Alive or not self.Settings or not (self.Settings.AutoGuard or self.Settings.AutoPlay)
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
    if not character or not self.Settings or not (self.Settings.AutoGuard or self.Settings.AutoPlay) then return end
    self.Target, self.TargetCharacter, self.TargetHumanoid = player, character, humanoid
    self.JumpConnection = humanoid.Jumping:Connect(function(active)
        if active then self:MirrorJump(player, humanoid) end
    end)
    -- Also catch a jump already underway when a new carrier is selected.
    if humanoid.FloorMaterial == self.Environment.Enum.Material.Air and root.AssemblyLinearVelocity.Y > 1 then
        self:MirrorJump(player, humanoid)
    end
end
function Extension:GuardOffNotice()
    local captures=self.InputCaptures
    if captures and captures[2] and type(captures[2].Notification)=="function" then
        pcall(function() captures[2].Notification().new({Title="Auto Guard",Description="Disabled (Auto-play handles defense)",Duration=2}) end)
    end
end
function Extension:EnforceGuardOff(notify)
    if not self.Settings or not self.Settings.AutoPlay or self.GuardUISync then return end
    self.GuardUISync=true
    self:SetFeature("AutoGuard",false)
    self.GuardUISync=false
    if notify then self:GuardOffNotice() end
end
function Extension:SetFeature(name, value)
    if name=="AutoGuard" and self.Settings.AutoPlay then value=false end
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
    local enabled = not settings.AutoPlay and not settings.AutoGuard
    self:SetFeature("AutoGuard", enabled)
    -- Guard-only notification: never fall through into the old Aimbot branch.
    if captures[2] and type(captures[2].Notification) == "function" then
        pcall(function()
            captures[2].Notification().new({Title = "Auto Guard", Description = enabled and "Enabled" or (settings.AutoPlay and "Disabled (Auto-play handles defense)" or "Disabled"), Duration = 2})
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
        self.RunSerial=(self.RunSerial or 0)+1
        self.NextTrace=nil
        -- Auto-play defends on its own, so Blessed's Auto Guard is switched
        -- off (one movement writer) and restored when Auto-play stops.
        self.AutoPlaySnapshot, self.AutoPlayApplied = {}, {}
        -- Ball Magnet is never enabled automatically; only the user turns it on.
        for name, value in pairs({Aimbot=true, AutoGuard=false, BallReach=true}) do
            self.AutoPlaySnapshot[name] = self.Settings[name]
            self.AutoPlayApplied[name] = value
            self:SetFeature(name, value)
        end
        self.AutoPlayStarted, self.State, self.StateSince = self.Clock, nil, self.Clock
        self.AutoPlayStatus = "Experimental: scanning"
        if self.LockMatch then self:LockMatch() end
        self:EnforceGuardOff(true)
        self:Log("toggle", "Auto-play enabled (Auto Guard off)")
    else
        if self.ResetOffense then self:ResetOffense() end
        self:StopAutoMove()
        for name, value in pairs(self.AutoPlaySnapshot or {}) do
            -- Restore only values that still match the ones Auto-play applied.
            if self.Settings[name] == (self.AutoPlayApplied or {})[name] then self:SetFeature(name, value) end
        end
        self.AutoPlaySnapshot, self.AutoPlayApplied, self.AutoPlayStatus = nil, nil, "Off"
        self.State, self.PendingState = "Off", nil
        self.StateSince,self.Holder,self.StopReason=self.Clock,nil,"Auto-play disabled"
        self.PreparingShot,self.ProtectFacing=false,false
        self:Log("toggle", "Auto-play disabled (Auto Guard restored)")
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
    local minimum, maximum = high and 57 or 58, (high or self.Settings.AimbotType=="Mixed arc") and 73 or 74
    local goals = self.Goals and self:Goals() or self.Collection:GetTagged("FieldGoals")
    for _, goal in ipairs(goals) do
        if goal:IsA("BasePart") then
            local d = distance(root.Position, goal.Position)
            if d >= minimum and d < maximum then return true end
        end
    end
    return false
end
local function isTeammate(self, player)
    return self.Player.Team ~= nil and player.Team == self.Player.Team
        and self.Player.Neutral == false and player.Neutral == false
end
-- Raw possession read: who holds the ball right now.
function Extension:ReadPossession(character)
    return self:SelectMatchHolder(character)
end
-- Explicit state with debouncing so brief reparenting during a dribble or a
-- delayed replication does not flip offense/defense.
function Extension:UpdateState(character, humanoid, root)
    local now = self.Clock
    local state, holder, reason
    local last = self.LastRootPosition
    self.LastRootPosition = root.Position
    if last and (root.Position-last).Magnitude > 25 then
        self.ResetUntil = now+0.25 -- brief settle only; the defender is closing during check ball
        self:Log("reset", string.format("teleport %.0f studs (score/reset or respawn)", (root.Position-last).Magnitude))
    end
    local busy = self.Shooting or (self.AimDepth or 0) > 0
    if self:IsManual() then state, reason = "Manual", tostring(self.ManualReason or "input")
    elseif self.ResetUntil and now < self.ResetUntil then state, reason = "Reset", "position reset"
    elseif busy then state, reason = "Shot", self.Shooting and "shot routine" or ((self.AimDepth or 0) > 0 and "aim routine" or "dunk")
    else
        local raw, who = self:ReadPossession(character)
        local committed = self.State
        if raw=="Opponent" and committed=="Own" then
            state,holder=raw,who;self.PendingState=nil
        elseif raw == committed or committed == nil or committed == "Manual" or committed == "Reset" or committed == "Shot" or committed == "Off" then
            state, holder = raw, who
            self.PendingState = nil
        else
            -- Leaving our own possession needs longer confirmation (dribble
            -- reparenting); other changes confirm quickly.
            -- A confirmed opponent holder is acted on quickly (steal); a ball
            -- briefly out of our container waits longer (dribble reparent).
            local hold = (committed == "Own" and raw == "Loose") and 0.3 or (raw == "Loose" and 0.25 or 0.12)
            if self.PendingState ~= raw then self.PendingState, self.PendingSince = raw, now end
            if now-self.PendingSince >= hold then state, holder = raw, who; self.PendingState = nil
            else state, holder = committed, self.Holder end
        end
        reason = holder and holder.Name or "ball"
    end
    if state ~= self.State then
        self:Log("state", tostring(self.State).." -> "..state.." ("..tostring(reason)..")")
        self.LastTransition = tostring(self.State).."->"..state.." ("..tostring(reason)..")"
        local was = self.State
        if state=="Opponent" and (was=="Own" or was=="Shot" or was=="Loose") then
            self.TurnoverRetreat=true;self.TurnoverAt=now
            if self.ObserveRisk then self:ObserveRisk(holder,"turnover") end
            self:ReleaseDribbleKeys(true)
            self:Log("turnover","confirmed holder "..tostring(holder and holder.Name).."; retreat to hoop")
        end
        if state=="Own" then self.TurnoverRetreat=nil end
        self.State, self.StateSince = state, now
        if was == "Own" and state ~= "Shot" and self.ResetOffense then self:ResetOffense() end
        if state ~= "Opponent" then self.DefenseGoal, self.LastDefenseTarget, self.DefenseFacing = nil, nil, nil end
        if state ~= "Own" and state ~= "Shot" then self.ShotSpot = nil end
        self.AutoMovePoint = nil
    end
    self.Holder = holder
    return state, holder
end
function Extension:AutoPlayStep(character, humanoid, root)
    local state, holder = self:UpdateState(character, humanoid, root)
    if self.UpdateRimStrategy then self:UpdateRimStrategy() end
    if state == "Manual" then
        if self.ResetOffense and self.OffenseCharacter then self:ResetOffense() end
        self:StopAutoMove(); self.StopReason = "manual input ("..tostring(self.ManualReason)..")"
        self.AutoPlayStatus = "Paused: manual input"; return
    end
    if state == "Reset" then
        if self.ResetOffense and self.OffenseCharacter then self:ResetOffense() end
        self:StopAutoMove(); self.StopReason = "dead ball / reset"; self.AutoPlayStatus = "Reset: waiting"; return
    end
    if state == "Shot" then self.StopReason = "shot/dunk in progress"; return end
    if state == "Opponent" then
        if self.ResetOffense and self.OffenseCharacter then self:ResetOffense() end
        self:DefenseStep(character, humanoid, root, holder)
        self.StopReason = self.AutoMovePoint and nil or self.DefenseIntent
        self.AutoPlayStatus = "Defense: "..tostring(self.DefenseIntent); return
    end
    if state == "Teammate" then
        if self.ResetOffense and self.OffenseCharacter then self:ResetOffense() end
        self:StopAutoMove(); self.StopReason = "teammate has the ball"; self.AutoPlayStatus = "Teammate possession"; return
    end
    if state == "Own" and not heldBall(character) then
        -- Possession change still being confirmed: do not run offense
        -- without the ball; keep still until the state settles.
        self:StopAutoMove(); self.StopReason = "confirming possession"; return
    end
    if state == "Own" then
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
    else
        if self.ResetOffense and self.OffenseCharacter then self:ResetOffense() end
        self:RecoveryStep(character,humanoid,root)
    end
end
function Extension:Tick(dt)
    if not self.Alive or not self.Settings then return end
    self.Clock = self.Clock + math.max(0, math.min(dt, 0.5))
    if self.Settings.AutoPlay and self.Settings.AutoGuard then self:EnforceGuardOff(false) end
    if self.LocalHeadphonesEnabled and self.UpdateLocalHeadphones and self.Clock>=(self.NextHeadphonesUpdate or -100) then
        self.NextHeadphonesUpdate=self.Clock+0.5
        local ok,message=pcall(self.UpdateLocalHeadphones,self)
        if not ok then self:MusicStatus("Headphones unavailable: "..tostring(message)) end
    end
    if self.ReleaseDribbleKeys then self:ReleaseDribbleKeys(false) end
    if self.ShotTrack and self.TrackShot then self:TrackShot() end
    if self.Settings.AutoPlay and self.SamplePickups then
        local ok,message=pcall(self.SamplePickups,self)
        if not ok and self.Clock>=(self.NextSampleError or -100) then
            self.NextSampleError=self.Clock+5;self:Log("error","pickup sampler: "..tostring(message))
        end
    end
    self:CaptureTrace()
    self.TickAccumulator = (self.TickAccumulator or 0) + dt
    -- Faster decisions when an attacker is close; 10 Hz otherwise.
    if self.TickAccumulator < (self.PlanInterval or 0.1) then return end
    self.TickAccumulator = 0
    self.PlanCount = (self.PlanCount or 0)+1
    self:Watchdogs()
    if self.Settings.PlayerCollisions and self.UpdatePlayerCollisions then self:UpdatePlayerCollisions() end
    local character, humanoid, root = characterParts(self.Player)
    if not humanoid then
        if self.ResetOffense then self:ResetOffense() end
        if self.ShotTrack and self.FinishShotTrack then self:FinishShotTrack("Cancelled: character died/reset") end
        if self.State ~= "Dead" and self.Settings.AutoPlay then self:Log("state", tostring(self.State).." -> Dead"); self.State = "Dead" end
        self.Shooting, self.ShotAttempt, self.AimDepth, self.DunkingUntil = false, nil, 0, nil
        self:ClearTarget(); self:StopAutoMove(); self.AutoPlayStatus = "Waiting for respawn"; return
    end
    self:WatchCharacter(character, humanoid)
    if (self.Settings.AutoGuard or self.Settings.AutoPlay) and self.Selector and not heldBall(character) and not self:IsManual() then
        self:SelectTarget(self.Selector())
    else self:ClearTarget() end
    if self.Settings.AutoPlay then self:AutoPlayStep(character, humanoid, root) end
end
-- Bounded recovery for confirmed stale internal state. Genuine game actions
-- and manual input are not overridden.
function Extension:Watchdogs()
    local now = self.Clock
    if self.Shooting then
        self.ShootingSince = self.ShootingSince or now
        if now-self.ShootingSince > 4 then
            self:Log("watchdog", "shot routine flag stuck 4s: cleared")
            self.Shooting, self.ShotAttempt = false, nil
        end
    else self.ShootingSince = nil end
    if (self.AimDepth or 0) > 0 then
        self.AimSince = self.AimSince or now
        if now-self.AimSince > 5 then self:Log("watchdog", "aim depth stuck 5s: cleared"); self.AimDepth = 0 end
    else self.AimSince = nil end
    -- Stalled movement: a destination we are not approaching.
    local _, humanoid, root = characterParts(self.Player)
    if root and self.AutoMovePoint and self.Settings.AutoPlay then
        local away = (self.AutoMovePoint-root.Position).Magnitude
        if not self.StallPosition or (root.Position-self.StallPosition).Magnitude > 0.5 then
            self.StallPosition, self.StallSince = root.Position, now
        elseif away > 3 and now-self.StallSince > 2 then
            self:Log("watchdog", string.format("movement stalled %.1fs, %.0f studs from target: re-issued", now-self.StallSince, away))
            self.LastMoveToPoint, self.StallSince = nil, now
        end
    else self.StallPosition = nil end
    local close = self.State == "Opponent" and self.Holder and characterParts(self.Holder)
    local _, _, holderRoot = characterParts(self.Holder)
    self.PlanInterval = (close and root and holderRoot and (holderRoot.Position-root.Position).Magnitude < 18) and 0.05 or 0.1
end
-- Death/knockdown instrumentation (the recording shows bodies breaking apart;
-- the cause is not visible on video).
function Extension:WatchCharacter(character, humanoid)
    if self.WatchedCharacter == character then return end
    for _, connection in ipairs(self.CharacterConnections or {}) do disconnect(connection) end
    self.CharacterConnections, self.WatchedCharacter = {}, character
    if humanoid.Died then
        self.CharacterConnections[1] = humanoid.Died:Connect(function()
            self:Log("character", "Humanoid died (action="..tostring(self.GameAction and self:GameAction(character))..")")
        end)
    end
    if humanoid.StateChanged then
        self.CharacterConnections[2] = humanoid.StateChanged:Connect(function(_, new)
            local name = tostring(new)
            if name:find("Physics") or name:find("Ragdoll") or name:find("FallingDown") or name:find("Dead") or name:find("PlatformStanding") then
                self:Log("character", "state "..name)
            end
        end)
    end
end
function Extension:StatusText()
    local now=self.Clock
    local function name(player) return player and player.Name or "-" end
    local character=self.Player and self.Player.Character
    local action=self.GameAction and self:GameAction(character)
    local manual=self.Clock<(self.ManualUntil or 0) and string.format("%s %.1fs", tostring(self.ManualReason), self.ManualUntil-now) or "none"
    local _,_,root=characterParts(self.Player)
    local moveDistance=root and self.AutoMovePoint and distance(root.Position,self.AutoMovePoint)
    local moveContext=moveDistance and string.format(" | target %.1f studs away",moveDistance) or ""
    local lines={
        string.format("State %s for %.1fs | %s", tostring(self.State or "-"), now-(self.StateSince or now), self.LastTransition or "-"),
        "Holder "..name(self.Holder).." | jump target "..name(self.Target),
        "Court "..self:GoalLabel(self.MatchGoal).." | opponent "..name(self.MatchOpponent),
        "Context "..tostring(self.ContextReason or "-").." | "..tostring(self.CameraControlStatus or "camera idle"),
        "Basket "..tostring((self.State=="Opponent" and self.DefenseGoal or self.OffenseGoal) and (self.State=="Opponent" and self.DefenseGoal or self.OffenseGoal).Name or "-")
            .." | intent "..tostring(self.State=="Opponent" and self.DefenseIntent or self.AutoPlayStatus),
        "Stopped: "..tostring(self.AutoMovePoint and "moving" or (self.StopReason or "-")).." | manual "..manual..moveContext,
        "Action "..tostring(action).." | shooting "..tostring(self.Shooting==true).." aim "..tostring(self.AimDepth or 0)
            .." dunking "..tostring(self.DunkingUntil~=nil and now<self.DunkingUntil),
        (self.LastShotResult or "No shot yet").." / "..tostring(self.ShotBlockReason or "-"),
        "Shots sent "..tostring(self.ShotAttempts or 0).." released "..tostring(self.ShotsReleased or 0)
            .." near rim "..tostring(self.ShotsNearRim or 0).." | dunks "..tostring(self.DunkAttempts or 0).."/"..tostring(self.DunksStarted or 0)
            .." | contests "..tostring(self.ContestCount or 0),
        "Dribble "..tostring(self.DribbleStatus or "-").." | shield "..tostring(self.ProtectFacing==true).." | setup "..tostring(self.PreparingShot==true),
        "Refused: move "..tostring(self.MoveRefusal or "-").." | route "..tostring(self.SpacingReason or "-"),
        "Defense "..tostring(self.DefenseMode or "-").." vs "..name(self.State=="Opponent" and self.Holder or nil).." | "..tostring(self.DefenseIntent or "-"),
        "Strategy "..tostring(self.AdaptiveRimOnly and "CONDITIONAL rim strategy" or "normal").." ("..tostring(self.Settings.AutoPlayMagnetResponse or "Manual confirm")
            ..(self.Settings.AutoPlayRimOverride and ", override" or "")..") | "..tostring(self.AdaptiveReason or "-"),
        "Evidence "..(self.EvidenceSummary and (self:EvidenceSummary()) or "-").." | last "..tostring(self.PickupEvidence and self.PickupEvidence.LastDecision or "-"),
        "Arc "..tostring(self.Settings.AimbotType).." delay "..tostring(self.Settings.ShotDelay).." | planning "..tostring(self.PlanCount or 0),
        "Last error: "..tostring(self.LastError or "none"),
    }
    local log=self.EventLog or {}
    for k=math.max(1,#log-3),#log do lines[#lines+1]=log[k] end
    return table.concat(lines,"\n")
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
        settings.AutoPlayMagnetResponse = settings.AutoPlayMagnetResponse or "Manual confirm"
        settings.AutoPlayRimOverride = false
        settings.BallMagnet = UltimatePreferences.BallMagnet
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
    settings.AutoPlayMagnetResponse = "Manual confirm"
    settings.AutoPlayRimOverride = false
    settings.BallMagnet = UltimatePreferences.BallMagnet
    self:Connect(self.Run.Heartbeat, function(dt)
        local ok, message = pcall(self.Tick, self, dt)
        if not ok then
            -- Recover from a single bad frame; only repeated errors disable.
            self.LastError = tostring(message)
            self:Log("error", self.LastError)
            self:StopAutoMove()
            if self.ResetOffense then pcall(self.ResetOffense, self) end
            self.ErrorTimes = self.ErrorTimes or {}
            local times = self.ErrorTimes
            times[#times+1] = self.Clock
            while times[1] and self.Clock-times[1] > 10 do table.remove(times, 1) end
            if #times >= 5 then
                self:SetAutoPlay(false)
                self.AutoPlayStatus = "Paused after repeated errors: " .. tostring(message)
            else self.AutoPlayStatus = "Recovered from error: " .. tostring(message) end
        end
    end)
    self.RenderName = "UltimateAutoPlay_" .. tostring(self)
    self.Run:BindToRenderStep(self.RenderName, environment.Enum.RenderPriority.Camera.Value + 1, function(dt)
        if self.UpdateAutoFacing then
            local ok=pcall(self.UpdateAutoFacing,self,dt or 1/60)
            if not ok and self.ReleaseAutoFacing then self:ReleaseAutoFacing() end
        end
        if self.Alive and self.Settings.AutoPlay and not self.AutoMovePoint and self.Player
            and heldBall(self.Player.Character) and self.ProtectiveIdle then self:ProtectiveIdle() end
        if self.Alive and self.Settings.AutoPlay and self.AutoMovePoint and not self:IsManual() then
            local character, humanoid, root = characterParts(self.Player)
            local action = humanoid and self.GameAction and self:GameAction(character)
            if (action == "Shooting" or action == "Dunking") and not self.FreezeLogged then
                self:StopAutoMove()
            elseif humanoid and not self.Shooting then
                local owned=heldBall(character)
                if not owned and self.State=="Own" then
                    self:StopAutoMove();self:ReleaseDribbleKeys(true);return
                end
                if owned and self.Environment.Vector3 then
                    self:ReactiveRoute(root)
                    if not self.AutoMovePoint then return end
                end
                -- Re-issue MoveTo only when the target meaningfully changes
                -- (or to refresh Roblox's 8 s MoveTo timeout).
                local last = self.LastMoveToPoint
                if not self.AutoMoving or self.LastMoveToHumanoid ~= humanoid or not last
                    or (last-self.AutoMovePoint).Magnitude > 0.4 or self.Clock-(self.LastMoveToTime or -100) > 1 then
                    humanoid:MoveTo(self.AutoMovePoint); self.AutoMoving = true
                    self.LastMoveToPoint, self.LastMoveToTime, self.LastMoveToHumanoid = self.AutoMovePoint, self.Clock, humanoid
                end
                local ball = (self.State == "Own" or self.State == nil) and heldBall(character)
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
                captures[2].Notification().new({Title="Auto-play status",Description=self:StatusText(),Duration=10})
            end)
        end
    end})
    section:NewButton({Title = "Copy Auto-play log", Callback = function()
        local counts={};for key,count in pairs(self.MoveCounts or {})do counts[#counts+1]=key.."="..count end;table.sort(counts)
        local text=self:StatusText().."\nMoves "..table.concat(counts,", ").."\n--- events ---\n"..table.concat(self.EventLog or {},"\n")
            .."\n--- tactical trace (0.5s samples, latest 60s) ---\n"..table.concat(self.TraceLog or {},"\n")
        local copy=self.Environment.setclipboard or self.Environment.toclipboard
        if type(copy)=="function" then pcall(copy,text) end
        self.LastLogCopy=text
    end})
    -- Conditional strategy against suspected abnormal pickups. Manual confirm
    -- (default) only prompts; Auto acts after strong repeated evidence;
    -- Override forces the rim strategy for testing without evidence.
    section:NewDropdown({Title="Magnet response",Data={"Manual confirm","Off","Auto (experimental)"},Default="Manual confirm",Callback=function(value)
        self.Settings.AutoPlayMagnetResponse=value
        self.RimAutoActive=false
        self:Log("strategy","response mode "..tostring(value))
    end})
    section:NewButton({Title="Confirm suspected opponent",Callback=function() self:ConfirmSuspectedOpponent() end})
    self.RimOverrideToggle=section:NewToggle({Title="Rim strategy override",Default=false,Callback=function(value)
        self.Settings.AutoPlayRimOverride=value==true
        self:Log("strategy","override "..(value and "on" or "off"))
    end})
    section:NewButton({Title="Clear rim strategy",Callback=function() self:ClearRimStrategy() end})
    section:NewDropdown({Title = "Attack basket", Data = {"Nearest", "Second nearest"}, Default = "Nearest", Callback = function(value)
        self.Settings.AutoPlayBasket = value
        if self.ResetOffense then self:ResetOffense() end
    end})
    local names={"Auto (this court)"}
    for _,player in ipairs(self:PlayerList()) do if player~=self.Player then names[#names+1]=player.Name end end
    section:NewDropdown({Title="Opponent",Data=names,Default="Auto (this court)",Callback=function(value)
        self.Settings.AutoPlayOpponent=value;self.MatchOpponent=nil
    end})
    section:NewButton({Title="Lock court here",Callback=function() self:LockMatch() end})
    section:NewButton({Title="Lock viewed hoop",Callback=function() self:LockViewedHoop() end})
    self.LocalHeadphonesToggle=section:NewToggle({Title="Local headphones",Default=false,Callback=function(value)
        self:SetLocalHeadphones(value)
    end})
    section:NewButton({Title="Music controls",Callback=function()self:OpenLocalMusicPanel()end})
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
    if self.DestroyLocalHeadphones then self:DestroyLocalHeadphones() end
    self:SetPlayerCollisions(false)
    if self.ResetOffense then self:ResetOffense() end
    self:ClearTarget(); self:StopAutoMove()
    self.Alive = false
    for _, connection in ipairs(self.Connections) do disconnect(connection) end
    for _, connection in ipairs(self.CharacterConnections or {}) do disconnect(connection) end
    self.CharacterConnections, self.WatchedCharacter = {}, nil
    self.Connections = {}
    if self.Run and self.RenderName then self.Run:UnbindFromRenderStep(self.RenderName) end
end
customizeClosure = function(name, original, environment, captures)
    if name=="root.1061" then
        return function(value,...)
            if Extension.Settings and Extension.Settings.AutoPlay then
                local result=original(false,...)
                if value and not Extension.GuardUISync then Extension:EnforceGuardOff(true) end
                return result
            end
            return original(value,...)
        end
    elseif name=="root.1168" then
        return function(...)
            if Extension.Settings and Extension.Settings.AutoPlay then Extension:EnforceGuardOff(true);return end
            return original(...)
        end
    elseif name == "root.1083.232.12.644" then
        return function(section, config, ...)
            if type(config)=="table" and config.Title=="Type" and type(config.Data)=="table" then
                local low,high=false,false
                for _,value in ipairs(config.Data) do low=low or value=="Low";high=high or value=="High" end
                if low and high then config.Data={"Low","Mixed arc","High"} end
            end
            return original(section,config,...)
        end
    elseif name == "root.175" then
        return function(...)
            local settings=captures[0]
            if not settings or settings.AimbotType~="Mixed arc" then return original(...) end
            local player=environment.game.Players.LocalPlayer
            local previousPower=player:GetAttribute("Power")
            local args=table.pack(...)
            local ok,result,power=pcall(function()
                settings.AimbotType="Low"
                local low=original(table.unpack(args,1,args.n))
                local lowPower=player:GetAttribute("Power")
                settings.AimbotType="High"
                local high=original(table.unpack(args,1,args.n))
                local highPower=player:GetAttribute("Power")
                assert(type(low)=="number" and type(high)=="number","Arc endpoint unavailable")
                local midPower=type(lowPower)=="number" and type(highPower)=="number" and (lowPower+highPower)/2 or previousPower
                return (low+high)/2,midPower
            end)
            settings.AimbotType="Mixed arc"
            player:SetAttribute("Power",ok and power or previousPower)
            if not ok then error(result,0) end
            return result
        end
    elseif name == "root.2169" then
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
            if Extension.Settings and Extension.Settings.AutoPlay
                and not heldBall(Extension.Player and Extension.Player.Character) then
                return -- Defensive contest jumps must not start an aim routine.
            end
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
            if Extension.Installed and Extension.Settings and Extension.Settings.AutoPlay then return end
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
