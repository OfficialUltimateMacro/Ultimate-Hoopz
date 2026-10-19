-- Experimental possession planner. Reads current replicated positions/velocities;
-- it does not know opponents' future inputs or the game's court/team rules.
local function flat(v) return Extension.Environment.Vector3.new(v.X, 0, v.Z) end
local function unit(v)
    local length = v.Magnitude
    if length < 0.001 then return Extension.Environment.Vector3.new(1, 0, 0) end
    return v / length
end
local function rotate(v, angle)
    local c, s = math.cos(angle), math.sin(angle)
    return Extension.Environment.Vector3.new(v.X*c-v.Z*s, 0, v.X*s+v.Z*c)
end
-- Roblox RightVector for a horizontal look direction.
local function lateralOf(forward) return Extension.Environment.Vector3.new(-forward.Z, 0, forward.X) end
local function segmentDistance(point, a, b)
    local d = flat(b-a)
    local t = math.max(0, math.min(1, flat(point-a):Dot(d) / math.max(0.001, d:Dot(d))))
    return flat(point-(a+d*t)).Magnitude
end
local function ballPart(ball)
    if not ball then return nil end
    if ball:IsA("BasePart") then return ball end
    return ball:FindFirstChildWhichIsA("BasePart")
end
-- Hoopz marks the character's current Action ("Shooting", "Dunking", ...).
local function gameAction(character)
    if not character or type(character.GetAttribute) ~= "function" then return nil end
    local ok, value = pcall(character.GetAttribute, character, "Action")
    return ok and value or nil
end
Extension.GameAction = function(_, character) return gameAction(character) end

---------------------------------------------------------------------------
-- Shared caches (each read was previously repeated per frame / per call).
---------------------------------------------------------------------------
function Extension:PlayerList()
    if not self.PlayerCache or self.Clock-self.PlayerCacheTime >= 0.5 or self.Clock < self.PlayerCacheTime then
        self.PlayerCache, self.PlayerCacheTime = self.Players:GetPlayers(), self.Clock
    end
    return self.PlayerCache
end
function Extension:Goals()
    local cache = self.GoalCache
    local stale = not cache or self.Clock-self.GoalCacheTime >= 2 or self.Clock < self.GoalCacheTime
    if not stale then for _, goal in ipairs(cache) do if not goal.Parent then stale = true; break end end end
    if stale then
        cache = {}
        for _, goal in ipairs(self.Collection:GetTagged("FieldGoals")) do
            if goal:IsA("BasePart") then cache[#cache+1] = goal end
        end
        self.GoalCache, self.GoalCacheTime = cache, self.Clock
    end
    return cache
end
function Extension:MakeRayParams()
    local env = self.Environment
    if not env.RaycastParams or not env.workspace.Raycast then return nil end
    if self.RayParamsCache and self.Clock-self.RayParamsTime < 1 and self.Clock >= self.RayParamsTime then
        return self.RayParamsCache
    end
    local params = env.RaycastParams.new()
    params.FilterType = env.Enum.RaycastFilterType.Exclude
    local exclude = {}
    for _, player in ipairs(self:PlayerList()) do
        if player.Character then exclude[#exclude+1] = player.Character end
    end
    params.FilterDescendantsInstances, params.IgnoreWater, params.RespectCanCollide = exclude, false, true
    self.RayParamsCache, self.RayParamsTime = params, self.Clock
    return params
end
-- Event-driven ball index: one initial scan, then DescendantAdded. Replaces a
-- full workspace:GetDescendants() every second while looking for loose balls.
local function isBallPart(part)
    return part and part:IsA("BasePart") and (part.Name == "Ball" or part.Name == "Basketball")
end
function Extension:BallSet()
    local workspace = self.Environment.workspace
    local listening = self.BallListening
    if not self.BallIndex or (not listening and self.Clock-(self.BallScanTime or -100) >= 3) then
        self.BallIndex = self.BallIndex or {}
        for _, part in ipairs(workspace:GetDescendants()) do
            if isBallPart(part) then self.BallIndex[part] = true end
        end
        self.BallScanTime = self.Clock
        if not listening and workspace.DescendantAdded then
            self.BallListening = true
            self:Connect(workspace.DescendantAdded, function(part)
                if isBallPart(part) then self.BallIndex[part] = true end
            end)
        end
    end
    for part in pairs(self.BallIndex) do
        if not part.Parent then self.BallIndex[part] = nil end
    end
    return self.BallIndex
end
function Extension:BallOwner(part)
    for _, player in ipairs(self:PlayerList()) do
        if player.Character and part:IsDescendantOf(player.Character) then return player end
    end
    return nil
end

---------------------------------------------------------------------------
-- Inputs
---------------------------------------------------------------------------
function Extension:ReleaseDribbleKeys(all)
    for key, deadline in pairs(self.DribbleKeys or {}) do
        if all or self.Clock >= deadline then
            if self.VirtualInput then pcall(self.VirtualInput.SendKeyEvent, self.VirtualInput, false, key, false, self.Environment.game) end
            self.DribbleKeys[key] = nil
        end
    end
end
function Extension:ResetOffense()
    self:ReleaseDribbleKeys(true)
    if self.Environment then self:ReleaseJumpKey() end
    if self.ReleaseAutoFacing then self:ReleaseAutoFacing() end
    self.OffenseGoal, self.OffenseCharacter, self.ShotSpot, self.SpotScore = nil, nil, nil, nil
    self.OpenSince, self.ProgressPosition, self.ProgressTime, self.StuckUntil = nil, nil, nil, nil
    self.LastPlan = nil
    self.RouteDirection, self.RouteHoldUntil = nil, nil
    self.SettlePosition,self.SettleSince=nil,nil
    self.DunkMode, self.DriveUntil, self.DunkingUntil = nil, nil, nil
    self.Plan, self.EscapeCount, self.NextEscape, self.PossessionStart = nil, 0, nil, nil
    self.DribbleDecisionUntil=nil
    self.PreparingShot=false
    self.FakeShotStart, self.ForceShot, self.AttackMode = nil, nil, nil
    self.FreezeSince, self.FreezeLogged = nil, nil
end
function Extension:ReleaseJumpKey()
    if not self.Environment then return end
    if self.ExecutorJumpHeld then
        if type(self.Environment.keyrelease)=="function" then pcall(self.Environment.keyrelease,0x20) end
        self.ExecutorJumpHeld=false
    end
    local key = self.Environment.Enum.KeyCode.Space
    if self.DribbleKeys and self.DribbleKeys[key] then
        if self.VirtualInput then pcall(self.VirtualInput.SendKeyEvent,self.VirtualInput,false,key,false,self.Environment.game) end
        self.DribbleKeys[key] = nil
    end
end
function Extension:RequestAutoJump(humanoid, root, valid)
    humanoid.Jump = true
    local states = self.Environment.Enum.HumanoidStateType
    if states and type(humanoid.ChangeState) == "function" then
        pcall(humanoid.ChangeState,humanoid,states.Jumping)
    end
    -- Use the game's normal jump input too; some character controllers consume
    -- or overwrite the Jump property before the next simulation step.
    if not self.Input:IsKeyDown(self.Environment.Enum.KeyCode.Space) then
        if type(self.Environment.keypress)=="function" and type(self.Environment.keyrelease)=="function" then
            self.ExecutorJumpHeld=true
            local ok=pcall(self.Environment.keypress,0x20)
            if not ok then self.ExecutorJumpHeld=false end
            self.Environment.task.delay(0.12,function() self:ReleaseJumpKey() end)
        end
        if not self.VirtualInput then
            local ok, service = pcall(self.Environment.game.GetService,self.Environment.game,"VirtualInputManager")
            if ok then self.VirtualInput=service end
        end
        if self.VirtualInput then
            local key = self.Environment.Enum.KeyCode.Space
            self.DribbleKeys = self.DribbleKeys or {}
            self.DribbleKeys[key] = self.Clock+0.08
            pcall(self.VirtualInput.SendKeyEvent,self.VirtualInput,true,key,false,self.Environment.game)
            self.Environment.task.delay(0.08,function() self:ReleaseJumpKey() end)
        end
    end
    for _=1,20 do
        if not valid() then self:ReleaseJumpKey();return false end
        if humanoid.FloorMaterial == self.Environment.Enum.Material.Air and root.AssemblyLinearVelocity.Y > 1 then
            self:ReleaseJumpKey();return true
        end
        self.Environment.task.wait(0.025)
    end
    self:ReleaseJumpKey()
    return false
end
function Extension:PulseKey(name, hold, cooldown, force)
    if self:IsManual() or self.Shooting then return false end
    if not force and (not self.Settings.AutoPlayDribble or self.Clock-(self.LastDribble or -100) < 0.075) then return false end
    local key = self.Environment.Enum.KeyCode[name]
    self.MoveCooldowns = self.MoveCooldowns or {}
    if self.Clock-(self.MoveCooldowns[name] or -100) < cooldown then return false end
    if key == self.Settings.AutoGuardKeybind or key == self.Settings.AutoPlayKeybind then return false end
    if self.Input:IsKeyDown(key) then return false end
    if not self.VirtualInput then
        local ok, service = pcall(self.Environment.game.GetService,self.Environment.game,"VirtualInputManager")
        if not ok or not service then self.DribbleStatus="Input unavailable";return false end
        self.VirtualInput = service
    end
    self.DribbleKeys = self.DribbleKeys or {}
    self.DribbleKeys[key] = self.Clock+hold
    local ok = pcall(self.VirtualInput.SendKeyEvent,self.VirtualInput,true,key,false,self.Environment.game)
    if not ok then self:ReleaseDribbleKeys(true);self.DribbleStatus="Input unavailable";return false end
    self.LastDribble,self.DribbleStatus,self.LastMove = self.Clock,name,name
    self.MoveCounts=self.MoveCounts or {};self.MoveCounts[name]=(self.MoveCounts[name] or 0)+1
    self.MoveCooldowns[name] = self.Clock
    -- Release independently of the planner too, even if its heartbeat stops.
    self.Environment.task.delay(hold+0.005,function()
        if self.DribbleKeys[key] then
            pcall(self.VirtualInput.SendKeyEvent,self.VirtualInput,false,key,false,self.Environment.game)
            self.DribbleKeys[key]=nil
        end
    end)
    return true
end
function Extension:PulseDribble(name)
    -- Wait (bounded 0.6 s) while Hoopz reports an action from a previous move.
    local action = gameAction(self.Player and self.Player.Character)
    if action=="Shooting" or action=="Dunking" then return false end
    if action ~= nil and action ~= "" then
        if self.ActionSeenValue ~= action then
            self.ActionSeenValue, self.ActionSeenSince = action, self.Clock
            self.ActionsSeen = self.ActionsSeen or {}
            if not self.ActionsSeen[action] then
                self.ActionsSeen[action] = true
                if self.Log then self:Log("action", "Hoopz Action value seen: "..tostring(action)) end
            end
        end
        if self.Clock-(self.ActionSeenSince or self.Clock) < 0.6 then return false end
    else self.ActionSeenValue = nil end
    return self:PulseKey(name, 0.04, name == "R" and 0.32 or 0.16)
end

---------------------------------------------------------------------------
-- World reads
---------------------------------------------------------------------------
function Extension:ReadOpponents(root)
    local result = {}
    self.OpponentMemory=self.OpponentMemory or setmetatable({},{__mode="k"})
    for _, player in ipairs(self:PlayerList()) do
        local sameTeam = self.Player.Team and player.Team == self.Player.Team
            and self.Player.Neutral == false and player.Neutral == false
        if player ~= self.Player and not sameTeam and (not self.MatchGoal or self:MatchPlayer(player)) then
            local character, humanoid, other = characterParts(player)
            if character and math.abs(other.Position.Y-root.Position.Y) < 12
                and flat(other.Position-root.Position).Magnitude < 90 then
                local velocity = flat(other.AssemblyLinearVelocity)
                local previous=self.OpponentMemory[player]
                local elapsed=previous and self.Clock-previous.Time or 0
                if elapsed>=0.06 and elapsed<=0.5 then
                    local measured=flat(other.Position-previous.Position)/elapsed
                    if measured.Magnitude<=45 then velocity=velocity*0.55+measured*0.45 end
                end
                if velocity.Magnitude > 32 then velocity = unit(velocity)*32 end
                if not previous or elapsed>=0.06 or elapsed<0 then
                    self.OpponentMemory[player]={Time=self.Clock,Position=other.Position,Velocity=velocity}
                end
                result[#result+1] = {
                    Player=player, Position=other.Position, Predicted=other.Position+velocity*0.3,
                    Velocity=velocity, Airborne=humanoid.FloorMaterial == self.Environment.Enum.Material.Air
                }
            end
        end
    end
    return result
end
function Extension:HasFloor(position, params)
    if not params then return false end
    local v = self.Environment.Vector3
    local hit = self.Environment.workspace:Raycast(position+v.new(0,2,0), v.new(0,-9,0), params)
    return hit ~= nil and hit.Normal.Y > 0.7 and hit.Material ~= self.Environment.Enum.Material.Water
end
function Extension:WalkClear(a, b, params)
    if not params then return false end
    local delta = flat(b-a)
    local right = rotate(unit(delta), math.pi/2)*1.6
    for _, side in ipairs({-1,0,1}) do
        if self.Environment.workspace:Raycast(a+right*side, delta, params) then return false end
    end
    return self:HasFloor(a+delta*0.5, params) and self:HasFloor(a+delta, params)
end
function Extension:NearestGoal(root, choice)
    local goals = {}
    for _, goal in ipairs(self:Goals()) do
        if goal.Parent and math.abs(goal.Position.Y-root.Position.Y) < 30
            and distance(goal.Position,root.Position) <= 145 then goals[#goals+1] = goal end
    end
    table.sort(goals, function(a,b) return distance(a.Position,root.Position) < distance(b.Position,root.Position) end)
    return goals[choice == "Second nearest" and 2 or 1]
end
-- True when the recovered aimbot (which targets the closest goal) would aim
-- at our chosen basket from this position.
function Extension:GoalIsNearestAt(position, goal)
    local own = (goal.Position-position).Magnitude
    for _, other in ipairs(self:Goals()) do
        if other ~= goal and other.Parent and (other.Position-position).Magnitude < own then return false end
    end
    return true
end
function Extension:SpaceAt(position, opponents)
    local nearest, jumping = 100, false
    for _, opponent in ipairs(opponents) do
        local d = math.min(flat(position-opponent.Position).Magnitude, flat(position-opponent.Predicted).Magnitude)
        nearest = math.min(nearest, d)
        if opponent.Airborne and d < 17 then jumping = true end
    end
    return nearest, jumping
end
function Extension:ShotLaneClear(root, goal, params)
    if not params or not goal then return false end
    -- Conservative straight line to basket; this is not a ballistic simulation.
    local hit = self.Environment.workspace:Raycast(root.Position, goal.Position-root.Position, params)
    self.LastLaneHit = hit
    if hit==nil or hit.Instance==goal then return true end
    -- The goal's rim/backboard can intercept a straight diagnostic ray even
    -- though the recovered shot follows an arc into that same basket.
    return hit.Position and (hit.Position-goal.Position).Magnitude<=5
        and hit.Position.Y>=goal.Position.Y-2
end
-- Opponent-specific outcome adaptation; these counters do not detect cheating.
function Extension:RiskProfile(player,create)
    if not player or not (player.UserId or player.Name) then return end
    self.RiskProfiles=self.RiskProfiles or {}
    local key=tostring(player.UserId or player.Name)
    local profile=self.RiskProfiles[key]
    if not profile and create then
        local count=0;local oldest,oldTime
        for k,v in pairs(self.RiskProfiles)do count=count+1;if not oldTime or v.Updated<oldTime then oldest,oldTime=k,v.Updated end end
        if count>=12 then self.RiskProfiles[oldest]=nil end
        profile={Turnovers=0,Unreleased=0,Updated=self.Clock,Name=player.Name};self.RiskProfiles[key]=profile
    end
    return profile
end
function Extension:SyncRisk()
    local profile=self:RiskProfile(self.MatchOpponent,false)
    local mode=profile and profile.RimOnly==true or false
    if mode~=self.AdaptiveRimOnly then
        self.AdaptiveRimOnly=mode;self.Plan,self.ShotSpot,self.LastPlan=nil,nil,nil
    end
    self.AdaptiveReason=profile and string.format("%s: losses=%d failed jumpers=%d",profile.Name or "opponent",profile.Turnovers,profile.Unreleased) or nil
end
function Extension:ObserveRisk(player,kind)
    local profile=self:RiskProfile(player,true);if not profile then return end
    if self.Clock-profile.Updated>90 then profile.Turnovers,profile.Unreleased=0,0 end
    profile.Updated=self.Clock
    if kind=="turnover" then profile.Turnovers=profile.Turnovers+1 else profile.Unreleased=profile.Unreleased+1 end
    if not profile.RimOnly and (profile.Turnovers>=3 or profile.Unreleased>=2) then
        profile.RimOnly=true
        self:Log("adapt","Rim-only + hoop protection for "..tostring(profile.Name)..": repeated confirmed losses; cheating not established")
    end
    self:SyncRisk()
end
function Extension:CanTakeShot(root)
    if self.AdaptiveRimOnly then self.ShotBlockReason="Adaptive rim-only: jumpers suspended";return false end
    local goal = self.OffenseGoal
    if not goal or not goal.Parent then self.ShotBlockReason="No attack basket selected";return false end
    if self:NearestGoal(root) ~= goal then self.ShotBlockReason="Selected basket is not the nearest";return false end
    if not self:InShotRange(root) then self.ShotBlockReason="Outside shooting range";return false end
    local space,jumping=self:SpaceAt(root.Position,self.OpponentReads or {})
    self.ShotContested=space<12 or jumping
    if self.ShotContested then self.ShotBlockReason=(jumping and space>=12) and "Waiting for jump contest to clear" or "Waiting for 12 studs of shot space";return false end
    if not self:ShotLaneClear(root,goal,self:MakeRayParams()) then
        -- After 8 s, a straight-line miss that ends near the hoop (rim/net
        -- structure) no longer blocks; a real wall in between still does.
        local hit=self.LastLaneHit
        if not (self.ForceShot and hit and hit.Position and (hit.Position-goal.Position).Magnitude<=15) then
            self.ShotBlockReason="Shot line blocked";return false
        end
        self.ShotBlockReason="Line hit near the hoop for 8s: shooting anyway"
        return true
    end
    -- Defenders never veto the shot: contested shots go up immediately.
    local space, jumping = self:SpaceAt(root.Position, self.OpponentReads or {})
    self.ShotContested = space < 10 or jumping
    self.ShotBlockReason = self.ShotContested and "Contested: shooting anyway" or "Open and in range"
    return true
end
function Extension:ShotRadius(root, goal)
    local radius3d = self.Settings.AimbotType == "High" and 64 or (self.Settings.AimbotType=="Mixed arc" and 64.5 or 65)
    local dy = goal.Position.Y-root.Position.Y
    return math.sqrt(math.max(1,radius3d*radius3d-dy*dy))
end
function Extension:PickShotSpot(root, opponents, params)
    local goal = self.OffenseGoal
    local radius = self:ShotRadius(root, goal)
    -- Sample around the side we are actually on now, not only the side we
    -- picked the ball up on.
    local base = unit(flat(root.Position-goal.Position))
    local best, score = nil, math.huge
    local function evaluate(position)
        if not self:GoalIsNearestAt(position, goal) then return math.huge end
        if not self:HasFloor(position,params) then return math.huge end
        local space, jumping = self:SpaceAt(position,opponents)
        local travel = flat(position-root.Position).Magnitude
        local cost = travel*0.38 + math.max(0,18-space)*4 + (jumping and 15 or 0)
        for _, opponent in ipairs(opponents) do
            cost = cost + math.max(0,8-segmentDistance(opponent.Predicted,root.Position,position))*2
        end
        if not self:ShotLaneClear({Position=position},goal,params) then cost=cost+60 end
        return cost
    end
    for _, degrees in ipairs({0,-20,20,-40,40,-60,60,-80,80,-110,110}) do
        local position = goal.Position+rotate(base,math.rad(degrees))*radius
        position = self.Environment.Vector3.new(position.X,root.Position.Y,position.Z)
        local cost = evaluate(position)
        if cost < score then best,score=position,cost end
    end
    -- Hysteresis: keep the current spot unless a clearly better one appears.
    if self.ShotSpot and best and flat(self.ShotSpot-best).Magnitude > 3 then
        local current = evaluate(self.Environment.Vector3.new(self.ShotSpot.X,root.Position.Y,self.ShotSpot.Z))
        if current < score + 8 then best, score = self.ShotSpot, current end
    end
    self.ShotSpot,self.SpotScore = best,score
    return best
end
-- Local fan steering with branch-and-bound: costs that need no raycasts are
-- computed first; rays only run for candidates that can still win. The chosen
-- point is identical to evaluating every candidate fully.
-- Conservative avatar buffer, not a claim about the game's hidden steal volume.
function Extension:PossessionPathClear(root,point,opponents)
    if not heldBall(self.Player and self.Player.Character) then return true end
    if self.MatchGoal and not self:MatchPosition(point) then self.SpacingReason="exit would leave locked court";return false end
    for _,opponent in ipairs(opponents)do
        local radius=(self.AdaptiveRimOnly and 10 or 8)+math.min(2,(opponent.Velocity and opponent.Velocity.Magnitude or 0)*0.025)
        for _,position in ipairs({opponent.Position,opponent.Predicted})do
            local start=flat(root.Position-position).Magnitude
            local finish=flat(point-position).Magnitude
            local along=segmentDistance(position,root.Position,point)
            if start>=radius then
                if along<radius then self.SpacingReason="route intersects defender buffer";return false end
            elseif finish<start+0.75 or along<start-0.1 then
                self.SpacingReason="crowded: only separation-increasing exits allowed";return false
            end
        end
    end
    self.SpacingReason="clearance route accepted"
    return true
end
function Extension:ReactiveRoute(root)
    if not self.AutoMovePoint or self.PreparingShot or self.Shooting then return end
    if self.Clock<(self.NextReactiveScan or -100) then return end
    self.NextReactiveScan=self.Clock+0.05
    local reads=self:ReadOpponents(root);self.OpponentReads=reads
    if self:PossessionPathClear(root,self.AutoMovePoint,reads) then return end
    local reason=self.SpacingReason
    local destination=self.ShotSpot or self.AutoMovePoint
    self.Plan,self.RouteHoldUntil,self.RouteDirection=nil,nil,nil
    local replacement=self:SteerTo(root,destination,reads)
    self.RerouteCount=(self.RerouteCount or 0)+1
    if replacement then self.AutoMovePoint=replacement;self.AutoPlayStatus="Reactive evasion: changed path"
    else self:StopAutoMove();self.AutoPlayStatus="Clearance blocked: waiting for a safe exit" end
    if self.Clock>=(self.NextRerouteLog or -100) then
        self.NextRerouteLog=self.Clock+0.5
        self:Log("reroute",tostring(reason).." -> "..(replacement and "alternate path" or "stop; no supported safe exit"))
    end
end
function Extension:SteerTo(root, destination, opponents)
    local params = self:MakeRayParams()
    local delta = flat(destination-root.Position)
    if delta.Magnitude < 0.6 then return nil end
    local length = math.min(8,delta.Magnitude)
    local candidates = {}
    for _, degrees in ipairs({0,-30,30,-60,60,-90,90,-120,120,-150,150,180}) do
        local point = root.Position+rotate(unit(delta),math.rad(degrees))*length
        local space = self:SpaceAt(point,opponents)
        local cost = flat(destination-point).Magnitude + math.max(0,14-space)*4
        for _, opponent in ipairs(opponents) do
            cost = cost + math.max(0,5-segmentDistance(opponent.Predicted,root.Position,point))*5
        end
        local direction = unit(point-root.Position)
        if self.RouteDirection and self.RouteHoldUntil and self.Clock < self.RouteHoldUntil then
            cost = cost + (1-direction:Dot(self.RouteDirection))*5
        end
        for _, opponent in ipairs(opponents) do
            if flat(opponent.Position-root.Position).Magnitude < 14 then
                cost = cost + math.max(0,8-flat(point-opponent.Predicted).Magnitude)*2
                local intercept=opponent.Position+opponent.Velocity*math.min(0.5,length/16)
                cost=cost+math.max(0,7-flat(point-intercept).Magnitude)*3
            end
        end
        if self.StuckUntil and self.Clock < self.StuckUntil then
            cost = cost + (degrees == 0 and 30 or 0) + (degrees*(self.EscapeSide or 1) < 0 and 8 or 0)
        end
        candidates[#candidates+1] = {Point=point, Cost=cost}
    end
    table.sort(candidates, function(a,b) return a.Cost < b.Cost end)
    local best, score = nil, math.huge
    for _, candidate in ipairs(candidates) do
        if candidate.Cost >= score then break end
        local point = candidate.Point
        if self:PossessionPathClear(root,point,opponents) and self:WalkClear(root.Position,point,params) then
            local total = candidate.Cost
            local ahead=point+unit(destination-point)*math.min(4,flat(destination-point).Magnitude)
            if not self:WalkClear(point,ahead,params) then total=total+14 end
            if total < score then best,score=point,total end
        end
    end
    if best then
        if not self.RouteHoldUntil or self.Clock >= self.RouteHoldUntil then self.RouteHoldUntil=self.Clock+0.6 end
        self.RouteDirection=unit(best-root.Position)
    end
    return best
end

---------------------------------------------------------------------------
-- Body and camera: shift-lock style. The body squares toward the attack
-- (rim / drive / escape facing) while the camera sits behind at a constant
-- radius looking up the court. Yaw is rate-limited so it never swings.
---------------------------------------------------------------------------
function Extension:ReleaseAutoFacing()
    local humanoid=self.AutoFacingHumanoid
    if humanoid then
        pcall(function()
            if humanoid.AutoRotate==true then humanoid.AutoRotate=self.SavedAutoRotate end
        end)
    end
    local controller=self.OwnedMouseLock
    self.OwnedMouseLock=nil
    if controller then pcall(function()
        if controller:GetIsMouseLocked() then controller:OnMouseLockToggled() end
    end) end
    self.AutoFacingHumanoid,self.SavedAutoRotate=nil,nil
    self.FaceYaw,self.CameraYaw,self.CameraDistance,self.CameraCurrentDistance=nil,nil,nil,nil
    self.CameraPitch,self.CameraFirstPerson=nil,nil
end
-- Use Roblox's camera controller to rotate the body in shift-lock. Never
-- assign HumanoidRootPart.CFrame: that fights the native movement controller.
function Extension:AcquireMouseLock()
    if self.MouseLockUnavailable and self.Clock<self.MouseLockUnavailable then return false end
    local ok,controller=pcall(function()
        local scripts=self.Player.PlayerScripts or self.Player:FindFirstChild("PlayerScripts")
        local module=scripts and scripts:FindFirstChild("PlayerModule")
        local loader=self.Environment.require or require
        local playerModule=module and loader(module)
        local cameras=playerModule and playerModule:GetCameras()
        return cameras and cameras.activeMouseLockController
    end)
    if not ok or not controller or type(controller.GetIsMouseLocked)~="function"
        or type(controller.OnMouseLockToggled)~="function" then
        self.MouseLockUnavailable=self.Clock+3
        self.CameraControlStatus="Enable native shift-lock manually (controller unavailable)"
        return false
    end
    local success=pcall(function()
        if not controller:GetIsMouseLocked() then controller:OnMouseLockToggled();self.OwnedMouseLock=controller end
    end)
    self.CameraControlStatus=success and "Native shift-lock: camera drives body" or "Native shift-lock unavailable"
    return success
end
-- A camera hit only counts as a wall when it is real, visible, anchored
-- geometry: not the dribbled ball, hitboxes, effects or invisible barriers.
function Extension:IsCameraBlocker(hit)
    local part = hit and hit.Instance
    if not part then return false end
    local ok, blocks = pcall(function()
        if part.Name == "Ball" or part.Name == "Basketball" then return false end
        if part.Transparency > 0.6 or part.Anchored == false then return false end
        local size = part.Size
        if math.max(size.X, size.Y, size.Z) < 4 then return false end
        if part.FindFirstAncestor and part:FindFirstAncestor("Hitboxes") then return false end
        return true
    end)
    if not ok then return true end
    return blocks
end
local atan2 = math.atan2 or math.atan
local function yawOf(d) return atan2(d.X, d.Z) end
local function wrapAngle(a) return (a+math.pi)%(2*math.pi)-math.pi end
local function approachYaw(current, target, rate, maxSpeed, dt)
    if not current then return target end
    dt = math.min(dt, 0.1)
    local step = wrapAngle(target-current)*(1-math.exp(-rate*dt))
    local limit = maxSpeed*dt
    if step > limit then step = limit elseif step < -limit then step = -limit end
    return current + step
end
function Extension:CameraIntervention()
    local env=self.Environment
    local types=env.Enum.UserInputType
    if types and type(self.Input.IsMouseButtonPressed)=="function" then
        for _, button in ipairs({types.MouseButton2}) do
            local ok,down=pcall(self.Input.IsMouseButtonPressed,self.Input,button)
            if ok and down then return true end
        end
    end
    if type(self.Input.GetMouseDelta)=="function" then
        local ok,delta=pcall(self.Input.GetMouseDelta,self.Input)
        if ok and delta and delta.Magnitude>1 then return true end
    end
    return false
end
-- Desired body facing for the current offensive situation.
function Extension:DesiredFacing(root)
    local goal=self.OffenseGoal
    local toGoal=goal and goal.Parent and flat(goal.Position-root.Position)
    local goalDir=toGoal and toGoal.Magnitude>0.5 and unit(toGoal)
    local move=self.AutoMovePoint and flat(self.AutoMovePoint-root.Position)
    local moveDir=move and move.Magnitude>0.6 and unit(move)
    self.ProtectFacing=false
    local owns=heldBall(self.Player and self.Player.Character)
    if self.State=="Opponent" and not owns then return self.DefenseFacing end
    if owns and self.Settings.AutoPlayDribble and (not self.DunkMode or (toGoal and toGoal.Magnitude>18)) and not self.PreparingShot then
        local threat,nearest=nil,90
        for _,opponent in ipairs(self.OpponentReads or {})do
            local offset=flat(root.Position-opponent.Predicted)
            local d=offset.Magnitude
            if d>0.1 and d<nearest then threat,nearest=offset,d end
        end
        local away=threat and unit(threat) or (goalDir and goalDir*(-1))
        if away then
            self.ProtectFacing=true
            return unit(away*0.95+(moveDir or away)*0.05)
        end
    end
    local plan=self.Plan
    if plan and plan.Facing then return plan.Facing end
    if not moveDir then return goalDir end
    if not goalDir then return moveDir end
    -- Square up near the rim and while escaping laterally; run with the ball
    -- when moving away from the basket instead of back-pedalling.
    local agreement=moveDir:Dot(goalDir)
    if toGoal.Magnitude<16 then return unit(moveDir+goalDir*3) end
    if agreement < -0.35 then return moveDir end
    return unit(moveDir+goalDir*1.4)
end
function Extension:UpdateAutoFacing(dt)
    local env=self.Environment
    if not env or not env.CFrame or not self.Alive or not self.Settings.AutoPlay or not self.Settings.AutoPlayCamera
        or self.Shooting or (self.AimDepth or 0)>0 or self:IsManual() then self:ReleaseAutoFacing();return end
    local character,humanoid,root=characterParts(self.Player)
    local offense=heldBall(character)
    local defending=not offense and self.State=="Opponent" and self.DefenseFacing~=nil
    if offense and self.Clock-(self.LastShieldRead or -100)>=0.05 then
        self.OpponentReads=self:ReadOpponents(root);self.LastShieldRead=self.Clock
    end
    if not humanoid or not (offense or defending) then self:ReleaseAutoFacing();return end
    local action=gameAction(character)
    if action=="Shooting" or action=="Dunking" then self:ReleaseAutoFacing();return end
    local camera=env.workspace.CurrentCamera
    if camera and env.Enum.CameraType and camera.CameraType==env.Enum.CameraType.Scriptable then
        self:ReleaseAutoFacing();return
    end
    if self:CameraIntervention() then self.CameraPauseUntil=self.Clock+1 end
    -- A camera pause only pauses camera/body assistance; movement continues.
    if self.CameraPauseUntil and self.Clock<self.CameraPauseUntil then self:ReleaseAutoFacing();return end
    local face=self:DesiredFacing(root)
    if not face then self:ReleaseAutoFacing();return end
    if self.AutoFacingHumanoid~=humanoid then
        self:ReleaseAutoFacing();self.AutoFacingHumanoid=humanoid;self.SavedAutoRotate=humanoid.AutoRotate
        local look=root.CFrame and root.CFrame.LookVector
        if look and flat(look).Magnitude>0.1 then self.FaceYaw=yawOf(look) end
    end
    humanoid.AutoRotate=true
    self:AcquireMouseLock()
    self.FaceYaw=approachYaw(self.FaceYaw,yawOf(face),12,9,dt)
    local bodyDir=env.Vector3.new(math.sin(self.FaceYaw),0,math.cos(self.FaceYaw))
    -- Native shift-lock aligns the character with camera yaw.
    if not camera or camera.CameraSubject~=humanoid then self.CameraYaw,self.CameraDistance=nil,nil;return end
    -- Camera orbits the same focus Roblox uses, at YOUR current zoom radius,
    -- so handing control back to the default camera never jumps.
    local focus=root.Position+env.Vector3.new(0,1.5,0)
    if not self.CameraDistance then
        local offset=camera.CFrame.Position-focus
        local radius=offset.Magnitude
        if radius~=radius or radius<2 then self.CameraFirstPerson=true end
        self.CameraDistance=math.max(8,math.min(40,radius==radius and radius or 14))
        self.CameraCurrentDistance=self.CameraDistance
        self.CameraPitch=math.asin(math.max(-0.99,math.min(0.99,offset.Y/math.max(radius,0.001))))
        local look=camera.CFrame.LookVector
        if look and flat(look).Magnitude>0.1 then self.CameraYaw=yawOf(look) end
    end
    if self.CameraFirstPerson then return end
    local viewDir
    if defending then
        -- Defense: keep the attacker in frame from the basket side.
        viewDir=self.DefenseFacing
    else
        local goal=self.OffenseGoal
        local toGoal=goal and goal.Parent and flat(goal.Position-root.Position)
        viewDir=self.ProtectFacing and face or bodyDir
        if not self.ProtectFacing and toGoal and toGoal.Magnitude>8 and unit(toGoal):Dot(bodyDir)>-0.2 then viewDir=unit(bodyDir*0.65+unit(toGoal)*0.35) end
    end
    local quickTurn=defending or self.ProtectFacing
    self.CameraYaw=approachYaw(self.CameraYaw,yawOf(viewDir),quickTurn and 12 or 6,quickTurn and 10 or 5,dt)
    -- Ease pitch into a court-reading band, never into the floor or overhead.
    local wantPitch=math.max(0.28,math.min(0.6,self.CameraPitch or 0.36))
    self.CameraPitch=(self.CameraPitch or wantPitch)+(wantPitch-(self.CameraPitch or wantPitch))*(1-math.exp(-2*math.min(dt,0.1)))
    local camDir=env.Vector3.new(math.sin(self.CameraYaw),0,math.cos(self.CameraYaw))
    local back=camDir*(-math.cos(self.CameraPitch))+env.Vector3.new(0,math.sin(self.CameraPitch),0)
    local wanted=self.CameraDistance
    local params=self:MakeRayParams()
    local hit=params and env.workspace:Raycast(focus,back*wanted,params)
    if hit and hit.Position and self:IsCameraBlocker(hit) then
        wanted=math.max(4,(hit.Position-focus).Magnitude-0.8)
    end
    local current=self.CameraCurrentDistance or wanted
    local rate=wanted<current and 10 or 2.5
    current=current+(wanted-current)*(1-math.exp(-rate*math.min(dt,0.1)))
    self.CameraCurrentDistance=current
    camera.CFrame=env.CFrame.lookAt(focus+back*current,focus)
end

---------------------------------------------------------------------------
-- Dribble choice. Reactive picks plus coordinated escape moves.
---------------------------------------------------------------------------
function Extension:ChooseDribble(root, point, opponents, ball)
    if not point or not ball or (self.Plan and self.Plan.Kind=="hesitate" and self.Clock < self.Plan.Until)
        or self.Clock<(self.DribbleDecisionUntil or -100) then return end
    local threat,nearest=nil,16
    for _,opponent in ipairs(opponents)do
        local d=math.min(flat(opponent.Position-root.Position).Magnitude,flat(opponent.Predicted-root.Position).Magnitude)
        if d<nearest then threat,nearest=opponent,d end
    end
    local right=root.CFrame.RightVector
    local handPart=ballPart(ball)
    local hand=handPart and flat(handPart.Position-root.Position):Dot(right) or 0
    local threatPosition=threat and ((flat(threat.Position-root.Position).Magnitude<flat(threat.Predicted-root.Position).Magnitude) and threat.Position or threat.Predicted)
    local threatSide=threatPosition and flat(threatPosition-root.Position):Dot(right) or 0
    local routeSide=flat(point-root.Position):Dot(right)
    -- Protect the opposite hand from the defender. Do not cross toward a
    -- steal threat just to keep producing keys; open lanes need no move.
    local safeSide=threatSide>0.6 and -1 or (threatSide< -0.6 and 1 or (routeSide>=0 and 1 or -1))
    local exposed=hand*threatSide>0.15
    local candidates={}
    local function add(name) if name~=self.LastMove then candidates[#candidates+1]=name end end
    if exposed and math.abs(hand)>0.2 then
        add(safeSide>0 and "F" or "G") -- safe transfer gets first chance
    else
        -- Random fast chains preserve the protected hand rather than using
        -- a blind crossover or hand switch into the defender.
        add("R");add("V");add("B")
        if not threat or nearest>=12 then add("C");add("H");add("F");add("G")
        elseif nearest>=8 and math.abs(hand)>0.2 then
            -- At usable separation add a behind-the-back only toward the
            -- free side; contact-range chains remain protective fakes.
            if hand*safeSide<0 then add(safeSide>0 and "F" or "G") end
        end
        for i=#candidates,2,-1 do local j=math.random(i);candidates[i],candidates[j]=candidates[j],candidates[i] end
    end
    for _,move in ipairs(candidates)do
        if self:PulseDribble(move) then
            self.DribbleDecisionUntil=self.Clock+0.075
            self.DribbleStatus="Chain "..move.." | protect "..(safeSide>0 and "right" or "left")
            return
        end
    end
    self.DribbleStatus="Chain waiting: safe moves busy or action in progress"

end
-- Move that carries the ball to the escape side: behind-the-back from the
-- off hand, a cross when already on that side, or a fake toward the other
-- side when the defender is square.
function Extension:ProtectiveIdle()
    if self.State~="Own" or self.AutoMovePoint or self.PreparingShot or self.Shooting
        or (self.AimDepth or 0)>0 or not self.Settings.AutoPlayDribble or self:IsManual() then return end
    local choices={"R","V","B"};local start=math.random(3)
    for i=0,2 do
        local move=choices[(start+i-1)%3+1]
        if move~=self.LastMove and self:PulseDribble(move) then self.DribbleStatus="Holding clearance: "..move;return end
    end
end
function Extension:EscapeMove(side, hand, square)
    if hand*side>0.2 then return nil end -- already protected: do not cross back into contact
    if square then return side > 0 and "V" or "B" end
    if math.abs(hand)>0.2 then return side>0 and "F" or "G" end
    return nil -- unknown ball hand: move to safety without guessing a crossover

end
-- Commit to a short lateral escape or hesitation when an on-ball defender
-- is in the path. Committed plans prevent left/right flip-flopping; a cap per
-- possession prevents endless circling.
function Extension:PlanEscape(root, destination, opponents, ball)
    local now = self.Clock
    local plan = self.Plan
    if plan then
        local reached = plan.Point and flat(plan.Point-root.Position).Magnitude < 1
        if now < plan.Until and not reached and (not plan.Point or self:PossessionPathClear(root,plan.Point,opponents)) then return plan end
        self.Plan = nil
        if plan.Kind == "escape" then
            -- Completion check: did the escape create separation?
            local still = false
            for _, opponent in ipairs(opponents) do
                if flat(opponent.Position-root.Position).Magnitude < 4 then still = true end
            end
            self.EscapeFailed = self.EscapeFailed or {}
            self.EscapeFailed[plan.Side] = still and now or nil
        end
        if plan.Kind == "hesitate" then self.NextEscape = now else self.NextEscape = now+0.7 end
        plan = nil
    end
    if (self.EscapeCount or 0) >= 4 or now < (self.NextEscape or -100) then return nil end
    local forward = unit(flat(destination-root.Position))
    local lateral = lateralOf(forward)
    local defender, gap = nil, 10
    for _, opponent in ipairs(opponents) do
        local offset = flat(opponent.Position-root.Position)
        local d = offset.Magnitude
        if d < gap and d > 0.01 and unit(offset):Dot(forward) > 0.35 then defender, gap = opponent, d end
    end
    if not defender then return nil end
    local params = self:MakeRayParams()
    local defenderSide = flat(defender.Predicted-root.Position):Dot(lateral)
    local part = ballPart(ball)
    local hand = part and flat(part.Position-root.Position):Dot(root.CFrame.RightVector) or 0
    local square = math.abs(defenderSide) < 1.2
    local preferred
    if square then
        preferred = -(self.LastEscapeSide or 1)
    else preferred = defenderSide > 0 and -1 or 1 end
    local closingSpeed = -flat(defender.Position-root.Position):Dot(defender.Velocity)/math.max(gap,0.01)
    -- Do not repeat a side that just failed to create space.
    local failed = self.EscapeFailed or {}
    if failed[preferred] and now-failed[preferred] < 2 then preferred = -preferred end
    local chosen,bestScore=nil,-math.huge
    for _,side in ipairs({preferred,-preferred})do
        -- At contact, create lateral/backward separation rather than driving
        -- through the handler's hands. Score both exits against every defender.
        local point=root.Position+lateral*side*7+forward*(gap<6 and -2 or 2)
        if self:PossessionPathClear(root,point,opponents) and self:WalkClear(root.Position,point,params) then
            local clearance=30
            for _,opponent in ipairs(opponents)do
                clearance=math.min(clearance,flat(opponent.Predicted-point).Magnitude)
            end
            local bodySide=(point-root.Position):Dot(root.CFrame.RightVector)>=0 and 1 or -1
            local protected=hand*bodySide>0 and 0.7 or 0
            local score=clearance+protected+(side==preferred and 0.4 or 0)
            if score>bestScore then chosen,bestScore={Side=side,BodySide=bodySide,Point=point},score end
        end
    end
    if not chosen then return nil end
    self.EscapeCount = (self.EscapeCount or 0)+1
    self.LastEscapeSide = chosen.Side
    if closingSpeed > 8 and gap >= 9 and gap < 10 and self.Clock-((self.MoveCooldowns or {}).R or -100) >= 0.4 then
        -- Hesitation: plant briefly with a fake-out, then escape away from
        -- where the defender committed.
        self.Plan = {Kind="hesitate", Until=now+0.22, Side=chosen.Side, Facing=forward}
        self:PulseDribble("R")
        self.EscapeCount = self.EscapeCount-1
        return self.Plan
    end
    self.Plan = {Kind="escape", Until=now+0.5, Side=chosen.Side, Point=chosen.Point, Facing=forward}
    local move=self:EscapeMove(chosen.BodySide,hand,square and gap>7)
    if move then self:PulseDribble(move) end
    return self.Plan
end

---------------------------------------------------------------------------
-- Dunks
---------------------------------------------------------------------------
function Extension:TryDunk(root, goal)
    if self:SpaceAt(root.Position,self.OpponentReads or {})<(self.AdaptiveRimOnly and 10 or 8) then self.ShotBlockReason="Dunk lane crowded: waiting for clearance";return false end
    local reach=flat(goal.Position-root.Position).Magnitude
    if reach>(self.DunkReach or 9) then return false end
    local axis=unit(flat(root.Position-goal.Position))
    local approach=self.Environment.Vector3.new(goal.Position.X,root.Position.Y,goal.Position.Z)+axis*2.5
    if not self:PossessionPathClear(root,approach,self.OpponentReads or {})
        or not self:WalkClear(root.Position,approach,self:MakeRayParams()) then
        self.ShotBlockReason="Dunk approach obstructed: hold clearance";return false
    end
    if not self:PulseKey("T",0.65,1.2,true) then return false end
    self.DunkAttempts=(self.DunkAttempts or 0)+1
    self.LastShotResult="Dunk key T sent at "..string.format("%.1f",reach).." studs"
    self.AutoPlayStatus="Dunking"
    self.DunkingUntil=nil -- Input is not proof the server started a dunk.
    if self.StartShotTrack then self:StartShotTrack("Dunk", self.Player.Character, goal, reach) end
    return true
end

---------------------------------------------------------------------------
-- Offense decision loop (10 Hz)
---------------------------------------------------------------------------
function Extension:OffenseStep(character, humanoid, root)
    if self.Shooting then self:StopAutoMove();return false end
    if self.OffenseCharacter ~= character then self:ResetOffense();self.OffenseCharacter=character end
    local now = self.Clock
    self:SyncRisk()
    self.PreparingShot=false
    self.PossessionStart = self.PossessionStart or now
    local held = now-self.PossessionStart
    local action = gameAction(character)
    if action == "Shooting" or action == "Dunking" then
        self.FreezeSince = self.FreezeSince or now
        if now-self.FreezeSince > 2.5 then
            if not self.FreezeLogged and self.Log then self:Log("watchdog", "Action "..tostring(action).." stale >2.5s: resuming") end
            self.FreezeLogged = true; action = nil
        end
    else self.FreezeSince, self.FreezeLogged = nil, nil end
    if action == "Shooting" or action == "Dunking" then
        self:StopAutoMove();self:ReleaseDribbleKeys(true)
        self.AutoPlayStatus = "Game action in progress: "..tostring(action or "dunk")
        return false
    end
    if not self.OffenseGoal or not self.OffenseGoal.Parent then
        self.OffenseGoal = self.MatchGoal or self:NearestGoal(root,self.Settings.AutoPlayBasket)
        if not self.OffenseGoal then self:StopAutoMove();self.AutoPlayStatus="No nearby attack basket";return false end
        self.GoalDirection = unit(flat(root.Position-self.OffenseGoal.Position))
    end
    local goal=self.OffenseGoal
    local opponents = self:ReadOpponents(root)
    self.OpponentReads = opponents
    local space, jumping = self:SpaceAt(root.Position,opponents)
    local grounded = humanoid.FloorMaterial ~= self.Environment.Enum.Material.Air
    local rimDistance = distance(root.Position,goal.Position)
    local minimum = self.Settings.AimbotType == "High" and 57 or 58
    local params = self:MakeRayParams()
    self.ForceShot = held >= 8
    -- Rim attack: inside the jumper ring the calibrated shot cannot score, so
    -- drive and dunk instead of backing out. Also drive from the near edge of
    -- the ring when pressed hard and the corridor to the rim is empty.
    if self.Settings.AutoPlayDunk ~= false then
        if self.AdaptiveRimOnly or rimDistance < minimum-3 then self.DunkMode=true
        elseif rimDistance > minimum and not (self.DriveUntil and now < self.DriveUntil) then self.DunkMode=false end
        if not self.DunkMode and space < 5 and rimDistance < 64 and held < 5 then
            local corridor = true
            for _, opponent in ipairs(opponents) do
                if segmentDistance(opponent.Predicted, root.Position, goal.Position) < 4
                    and flat(opponent.Position-goal.Position).Magnitude < rimDistance then corridor = false end
            end
            if corridor then self.DunkMode, self.DriveUntil = true, now+3 end
        end
    else self.DunkMode=false end
    if self.DunkMode then
        self.OpenSince,self.SettlePosition,self.SettleSince=nil,nil,nil
        if grounded then self:TryDunk(root,goal) end
        local approach = unit(flat(root.Position-goal.Position))
        local rim=goal.Position+approach*2.5
        rim=self.Environment.Vector3.new(rim.X,root.Position.Y,rim.Z)
        local plan = self:PlanEscape(root, rim, opponents, heldBall(character))
        local point = plan and plan.Point
        if not point and not plan then
            point=self:SteerTo(root,rim,opponents)
        end
        if plan and plan.Kind=="hesitate" then self:StopAutoMove();self.AutoPlayStatus="Hesitation at the rim"
        elseif point then
            self.AutoMovePoint=point;self.AutoPlayStatus=plan and "Rim drive: lateral escape" or "Driving to the rim"
            if not plan then self:ChooseDribble(root,point,opponents,heldBall(character)) end
        else self:StopAutoMove();self.AutoPlayStatus="No safe rim lane: hold and shield" end
        return false
    end
    local canShoot = self:CanTakeShot(root)
    if canShoot and grounded then
        local contested = space < 10 or jumping
        -- Sweet spot: open and early in the possession, take one more step
        -- into the middle of the calibrated power table.
        local high = self.Settings.AimbotType == "High"
        local low, top = high and 59 or 60, high and 71 or 72
        if not contested and held < 0.5 and (rimDistance < low or rimDistance > top) and self.ShotSpot then
            local point = self:SteerTo(root,self.ShotSpot,opponents)
            if point then self.AutoMovePoint=point;self.AutoPlayStatus="Stepping into the sweet spot";return false end
        end
        self.PreparingShot=true
        self:StopAutoMove();self:ReleaseDribbleKeys(true)
        self.Plan = nil
        -- Pump fake: a defender already in the air close by will come down
        -- before we release. Bounded to 0.45 s so it never stalls.
        local blocker = false
        for _, opponent in ipairs(opponents) do
            if opponent.Airborne and flat(opponent.Position-root.Position).Magnitude < 7 then blocker = true end
        end
        if blocker then
            self.FakeShotStart = self.FakeShotStart or now
            if now-self.FakeShotStart < 0.25 then
                if now-self.FakeShotStart < 0.05 then self:PulseKey("R",0.04,0.4,true) end
                self.AutoPlayStatus="Pump fake: defender in the air";return false
            end
        end
        if contested then self.AutoPlayStatus="Contested shot";self.FakeShotStart=nil;return true end
        if not self.SettlePosition or flat(root.Position-self.SettlePosition).Magnitude > 0.7 then
            self.SettlePosition,self.SettleSince=root.Position,now
        end
        local stationary = flat(root.AssemblyLinearVelocity).Magnitude < 3
            or now-(self.SettleSince or now)>=0.06
        if not stationary then self.AutoPlayStatus="Stopping for shot";return false end
        self.OpenSince = self.OpenSince or now
        self.AutoPlayStatus="Open shot: settling"
        if now-self.OpenSince >= 0.06 then self.FakeShotStart=nil;return true end
        return false
    end
    self.OpenSince=nil
    self.SettlePosition,self.SettleSince=nil,nil
    if canShoot then self:StopAutoMove();self.AutoPlayStatus="Stopping for shot";return false end
    -- Shot clock: after 4.5 s stop shopping for the perfect spot and attack
    -- the nearest legal point on the ring in a straight line.
    self.AttackMode = held >= 4.5
    if self.AttackMode then
        local radius = self:ShotRadius(root, goal)
        local spot = goal.Position+unit(flat(root.Position-goal.Position))*radius
        self.ShotSpot = self.Environment.Vector3.new(spot.X,root.Position.Y,spot.Z)
    elseif not self.LastPlan or now-self.LastPlan >= 0.35 or not self.ShotSpot then
        self.LastPlan=now;self:PickShotSpot(root,opponents,params)
    end
    if not self.ShotSpot then self:StopAutoMove();self.AutoPlayStatus="No supported shot position";return false end
    if not self.ProgressTime then self.ProgressTime,self.ProgressPosition=now,root.Position
    elseif now-self.ProgressTime >= 1.5 then
        if flat(root.Position-self.ProgressPosition).Magnitude < 0.6 then
            self.EscapeSide=-(self.EscapeSide or 1);self.StuckUntil=now+1.2;self.LastPlan=nil
        end
        self.ProgressTime,self.ProgressPosition=now,root.Position
    end
    local plan = not self.AttackMode and self:PlanEscape(root, self.ShotSpot, opponents, heldBall(character)) or nil
    if plan and plan.Kind == "hesitate" then
        self:StopAutoMove();self.AutoPlayStatus="Hesitation: reading the defender";return false
    end
    local point = plan and plan.Point or self:SteerTo(root,self.ShotSpot,opponents)
    if point then
        self.AutoMovePoint=point
        if plan then self.AutoPlayStatus=(plan.Side>0 and "Escape right" or "Escape left")
        elseif self.AttackMode then self.AutoPlayStatus="Shot clock: attacking the ring"
        else self.AutoPlayStatus=jumping and "Reading defender jump: creating space" or (space < 12 and "Evading defender" or "Routing to shot position") end
        if not plan then self:ChooseDribble(root,point,opponents,heldBall(character)) end
    else self:StopAutoMove();self:ReleaseDribbleKeys(true);self.AutoPlayStatus="Route blocked: waiting to replan" end
    return false
end

---------------------------------------------------------------------------
-- Shot / dunk verification from available game state: input dispatched,
-- Hoopz Action attribute, ball leaving the hand, closest ball-to-rim pass.
---------------------------------------------------------------------------
function Extension:StartShotTrack(kind, character, goal, reach)
    self.AttemptSerial=(self.AttemptSerial or 0)+1
    local power="?";pcall(function()power=tostring(self.Player:GetAttribute("Power"))end)
    self:Log("attempt",string.format("#%d %s routine completed | arc=%s power=%s delay=%s goal=%s",
        self.AttemptSerial,kind,tostring(self.Settings.AimbotType),power,tostring(self.Settings.ShotDelay),self:GoalLabel(goal)))
    self.ShotTrack = {Kind=kind, Character=character, Goal=goal, Start=self.Clock, Reach=reach,
        Released=false, MinDistance=math.huge, Ball=self.PossessionBall}
end
function Extension:FinishShotTrack(text)
    local track = self.ShotTrack
    self.ShotTrack = nil
    if not track then return end
    if track.Kind=="Shot" and not track.Released and (text:find("ball taken") or text:find("still held")) then
        self:ObserveRisk(self.MatchOpponent,"jumper_not_released")
    end
    if track.Action then text = text.." [Action="..tostring(track.Action).."]" end
    self.LastShotResult = text
    if self.Log then self:Log(track.Kind == "Dunk" and "dunk" or "shot", text) end
    if track.Kind == "Dunk" then
        if track.Released or track.Action == "Dunking" then
            self.DunksStarted = (self.DunksStarted or 0)+1
        else
            -- T was not accepted from this distance: try closer next time.
            self.DunkReach = math.max(4, (self.DunkReach or 9)-2)
            self.LastShotResult = text.."; next dunk at "..tostring(self.DunkReach).." studs"
        end
    end
end
function Extension:TrackShot()
    local track = self.ShotTrack
    if not track then return end
    local character = track.Character
    if self.Player.Character ~= character then self:FinishShotTrack("Cancelled: character changed"); return end
    local action = gameAction(character)
    if action == "Shooting" or action == "Dunking" then track.Action = action end
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not track.Released then
        if heldBall(character) then
            track.LeftAt = nil
            if self.Clock-track.Start > 1.0 then
                self:FinishShotTrack(track.Kind == "Dunk" and "Dunk: no dunk state and ball still held"
                    or "Shot input sent but ball still held after 1s")
            end
            return
        end
        -- Out of our hands: confirm it is a release, not a dribble reparent
        -- (regained within 0.3 s) or a strip (an opponent now holds it).
        track.LeftAt = track.LeftAt or self.Clock
        local kind, who = self.ReadPossession and self:ReadPossession(character)
        if kind == "Opponent" then
            self:FinishShotTrack("Not a release: ball taken by "..tostring(who and who.Name or "opponent"))
            return
        end
        if self.Clock-track.LeftAt < 0.15 then return end
        track.Released, track.ReleaseTime = true, self.Clock
        -- Bind to one ball: the loose ball nearest to us at release.
        local best, bestDistance = track.Ball, nil
        for part in pairs(self:BallSet()) do
            if not track.Ball and part.Parent and not self:BallOwner(part) and root
                and (not self.MatchGoal or self:MatchPosition(part.Position)) then
                local d = (part.Position-root.Position).Magnitude
                if d<40 and (not bestDistance or d < bestDistance) then best, bestDistance = part, d end
            end
        end
        track.Ball = best
        if track.Kind == "Shot" then self.ShotsReleased = (self.ShotsReleased or 0)+1 end
        return
    end
    local goal = track.Goal
    local ball = track.Ball
    if goal and goal.Parent and ball and ball.Parent then
        local d = (ball.Position-goal.Position).Magnitude
        if d < track.MinDistance then track.MinDistance = d end
    end
    local elapsed = self.Clock-track.ReleaseTime
    local regained = heldBall(character) ~= nil
    if elapsed >= 2.5 or (regained and elapsed > 0.3) then
        local closest = track.MinDistance
        local text
        if track.Kind == "Dunk" then text = "Dunk released"
        elseif closest == math.huge then text = "Shot released (ball flight not tracked)"
        elseif closest <= 3.5 then
            self.ShotsNearRim = (self.ShotsNearRim or 0)+1
            text = string.format("Shot released; passed %.1f studs from rim (score not verifiable)", closest)
        else text = string.format("Shot released; closest %.1f studs from rim", closest) end
        self:FinishShotTrack(text)
    end
end
