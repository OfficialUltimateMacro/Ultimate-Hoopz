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
local function segmentDistance(point, a, b)
    local d = flat(b-a)
    local t = math.max(0, math.min(1, flat(point-a):Dot(d) / math.max(0.001, d:Dot(d))))
    return flat(point-(a+d*t)).Magnitude
end
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
function Extension:ReadOpponents(root)
    local result = {}
    self.OpponentMemory=self.OpponentMemory or setmetatable({},{__mode="k"})
    for _, player in ipairs(self.Players:GetPlayers()) do
        local sameTeam = self.Player.Team and player.Team == self.Player.Team
            and self.Player.Neutral == false and player.Neutral == false
        if player ~= self.Player and not sameTeam then
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
                self.OpponentMemory[player]={Time=self.Clock,Position=other.Position,Velocity=velocity}
                result[#result+1] = {
                    Player=player, Position=other.Position, Predicted=other.Position+velocity*0.3,
                    Velocity=velocity, Airborne=humanoid.FloorMaterial == self.Environment.Enum.Material.Air
                }
            end
        end
    end
    return result
end
function Extension:MakeRayParams()
    local env = self.Environment
    if not env.RaycastParams or not env.workspace.Raycast then return nil end
    local params = env.RaycastParams.new()
    params.FilterType = env.Enum.RaycastFilterType.Exclude
    local exclude = {}
    for _, player in ipairs(self.Players:GetPlayers()) do
        if player.Character then exclude[#exclude+1] = player.Character end
    end
    params.FilterDescendantsInstances, params.IgnoreWater, params.RespectCanCollide = exclude, false, true
    return params
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
    for _, goal in ipairs(self.Collection:GetTagged("FieldGoals")) do
        if goal:IsA("BasePart") and goal.Parent and math.abs(goal.Position.Y-root.Position.Y) < 30
            and distance(goal.Position,root.Position) <= 145 then goals[#goals+1] = goal end
    end
    table.sort(goals, function(a,b) return distance(a.Position,root.Position) < distance(b.Position,root.Position) end)
    return goals[choice == "Second nearest" and 2 or 1]
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
    if hit==nil or hit.Instance==goal then return true end
    -- The goal's rim/backboard can intercept a straight diagnostic ray even
    -- though the recovered shot follows an arc into that same basket.
    return hit.Position and (hit.Position-goal.Position).Magnitude<=5
        and hit.Position.Y>=goal.Position.Y-2
end
function Extension:CanTakeShot(root)
    local goal = self.OffenseGoal
    if not goal or not goal.Parent then self.ShotBlockReason="No attack basket selected";return false end
    if self:NearestGoal(root) ~= goal then self.ShotBlockReason="Selected basket is not the nearest";return false end
    local space, jumping = self:SpaceAt(root.Position, self:ReadOpponents(root))
    if space<12 then self.ShotBlockReason="Defender too close";return false end
    if jumping then self.ShotBlockReason="Defender contesting in the air";return false end
    if not self:InShotRange(root) then self.ShotBlockReason="Outside shooting range";return false end
    if not self:ShotLaneClear(root,goal,self:MakeRayParams()) then self.ShotBlockReason="Shot line blocked";return false end
    self.ShotBlockReason="Open and in range"
    return true
end
function Extension:PickShotSpot(root, opponents, params)
    local goal = self.OffenseGoal
    local radius3d = self.Settings.AimbotType == "High" and 64 or 65
    local dy = goal.Position.Y-root.Position.Y
    local radius = math.sqrt(math.max(1,radius3d*radius3d-dy*dy))
    local base = self.GoalDirection
    local best, score = nil, math.huge
    for _, degrees in ipairs({0,-20,20,-40,40,-60,60,-80,80}) do
        local position = goal.Position+rotate(base,math.rad(degrees))*radius
        position = self.Environment.Vector3.new(position.X,root.Position.Y,position.Z)
        if self:HasFloor(position,params) then
            local space, jumping = self:SpaceAt(position,opponents)
            local travel = flat(position-root.Position).Magnitude
            local cost = travel*0.38 + math.max(0,18-space)*4 + (jumping and 15 or 0)
            for _, opponent in ipairs(opponents) do
                cost = cost + math.max(0,8-segmentDistance(opponent.Predicted,root.Position,position))*2
            end
            if not self:ShotLaneClear({Position=position},goal,params) then cost=cost+60 end
            if self.ShotSpot and flat(position-self.ShotSpot).Magnitude < 3 then cost=cost-5 end
            if cost < score then best,score=position,cost end
        end
    end
    self.ShotSpot,self.SpotScore = best,score
    return best
end
function Extension:SteerTo(root, destination, opponents)
    local params = self:MakeRayParams()
    local delta = flat(destination-root.Position)
    if delta.Magnitude < 0.6 then return nil end
    local length = math.min(8,delta.Magnitude)
    local best,score = nil,math.huge
    for _, degrees in ipairs({0,-30,30,-60,60,-90,90}) do
        local point = root.Position+rotate(unit(delta),math.rad(degrees))*length
        if self:WalkClear(root.Position,point,params) then
            local space = self:SpaceAt(point,opponents)
            local cost = flat(destination-point).Magnitude + math.max(0,10-space)*3
            for _, opponent in ipairs(opponents) do
                cost = cost + math.max(0,5-segmentDistance(opponent.Predicted,root.Position,point))*5
            end
            -- Retain a clear exit briefly instead of changing left/right every
            -- scan. Prefer separation from the defender's predicted intercept.
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
            local ahead=point+unit(destination-point)*math.min(4,flat(destination-point).Magnitude)
            if not self:WalkClear(point,ahead,params) then cost=cost+14 end
            if self.StuckUntil and self.Clock < self.StuckUntil then
                cost = cost + (degrees == 0 and 30 or 0) + (degrees*self.EscapeSide < 0 and 8 or 0)
            end
            if cost < score then best,score=point,cost end
        end
    end
    if best then
        if not self.RouteHoldUntil or self.Clock >= self.RouteHoldUntil then self.RouteHoldUntil=self.Clock+0.6 end
        self.RouteDirection=unit(best-root.Position)
    end
    return best
end
function Extension:ReleaseAutoFacing()
    local humanoid=self.AutoFacingHumanoid
    if humanoid then
        pcall(function()
            if humanoid.AutoRotate==false then humanoid.AutoRotate=self.SavedAutoRotate end
        end)
    end
    self.AutoFacingHumanoid,self.SavedAutoRotate=nil,nil
end
function Extension:UpdateAutoFacing(dt)
    local env=self.Environment
    if not env or not env.CFrame or not self.Alive or not self.Settings.AutoPlay or not self.Settings.AutoPlayCamera
        or self.Shooting or not self.AutoMovePoint or self:IsManual() then self:ReleaseAutoFacing();return end
    local character,humanoid,root=characterParts(self.Player)
    if not humanoid or not heldBall(character) then self:ReleaseAutoFacing();return end
    local activeCamera=env.workspace.CurrentCamera
    if activeCamera and env.Enum.CameraType and activeCamera.CameraType==env.Enum.CameraType.Scriptable then
        self:ReleaseAutoFacing();return
    end
    local mouseType=env.Enum.UserInputType and env.Enum.UserInputType.MouseButton2
    local cameraInput=false
    if mouseType and type(self.Input.IsMouseButtonPressed)=="function" then
        local ok,down=pcall(self.Input.IsMouseButtonPressed,self.Input,mouseType)
        cameraInput=ok and down
    end
    if type(self.Input.GetMouseDelta)=="function" then
        local ok,delta=pcall(self.Input.GetMouseDelta,self.Input)
        if ok and delta and delta.Magnitude>2 then cameraInput=true end
    end
    if cameraInput then self.CameraPauseUntil=self.Clock+0.8 end
    if self.CameraPauseUntil and self.Clock<self.CameraPauseUntil then self:ReleaseAutoFacing();return end
    local nearby=self:SpaceAt(root.Position,self.OpponentReads or {})
    if nearby>20 then self:ReleaseAutoFacing();return end
    local direction=flat(self.AutoMovePoint-root.Position)
    if direction.Magnitude<0.6 then self:ReleaseAutoFacing();return end
    direction=unit(direction)
    if self.AutoFacingHumanoid~=humanoid then
        self:ReleaseAutoFacing();self.AutoFacingHumanoid=humanoid;self.SavedAutoRotate=humanoid.AutoRotate
    end
    humanoid.AutoRotate=false
    local alpha=1-math.exp(-8*math.min(dt,0.1))
    root.CFrame=root.CFrame:Lerp(env.CFrame.lookAt(root.Position,root.Position+direction),alpha)
    local camera=env.workspace.CurrentCamera
    if camera and camera.CameraSubject==humanoid then
        local focus=root.Position+env.Vector3.new(0,2,0)
        local offset=camera.CFrame.Position-focus
        local zoom=flat(offset).Magnitude
        if zoom>2 then
            local desired=focus-direction*zoom+env.Vector3.new(0,offset.Y,0)
            local params=self:MakeRayParams()
            local hit=params and env.workspace:Raycast(focus,desired-focus,params)
            if hit then desired=hit.Position+unit(focus-hit.Position)*0.6 end
            camera.CFrame=camera.CFrame:Lerp(env.CFrame.lookAt(desired,focus),1-math.exp(-4*math.min(dt,0.1)))
        end
    end
end
function Extension:PulseDribble(name)
    if not self.Settings.AutoPlayDribble or self.Clock-(self.LastDribble or -100) < 0.14
        or self:IsManual() or self.Shooting then return false end
    local key = self.Environment.Enum.KeyCode[name]
    self.MoveCooldowns = self.MoveCooldowns or {}
    if self.Clock-(self.MoveCooldowns[name] or -100) < (name == "R" and 0.55 or 0.28) then return false end
    if key == self.Settings.AutoGuardKeybind then return false end
    if self.Input:IsKeyDown(key) then return false end
    if not self.VirtualInput then
        local ok, service = pcall(self.Environment.game.GetService,self.Environment.game,"VirtualInputManager")
        if not ok or not service then self.DribbleStatus="Input unavailable";return false end
        self.VirtualInput = service
    end
    self.DribbleKeys = self.DribbleKeys or {}
    self.DribbleKeys[key] = self.Clock+0.04
    local ok = pcall(self.VirtualInput.SendKeyEvent,self.VirtualInput,true,key,false,self.Environment.game)
    if not ok then self:ReleaseDribbleKeys(true);self.DribbleStatus="Input unavailable";return false end
    self.LastDribble,self.DribbleStatus = self.Clock,name
    self.MoveCooldowns[name] = self.Clock
    -- Release independently of the planner too, even if its heartbeat stops.
    self.Environment.task.delay(0.045,function()
        if self.DribbleKeys[key] then
            pcall(self.VirtualInput.SendKeyEvent,self.VirtualInput,false,key,false,self.Environment.game)
            self.DribbleKeys[key]=nil
        end
    end)
    return true
end
function Extension:ChooseDribble(root, point, opponents, ball)
    if not point then return end
    local threat, nearest = nil, 18
    for _, opponent in ipairs(opponents) do
        local d = flat(opponent.Position-root.Position).Magnitude
        if d < nearest then threat,nearest=opponent,d end
    end
    if not threat then return end
    local right = root.CFrame.RightVector
    local routeSide = flat(point-root.Position):Dot(right)
    local threatSide = flat(threat.Predicted-root.Position):Dot(right)
    local closing = flat(threat.Position-root.Position):Dot(threat.Velocity) < -6
    local name
    local fakeReady = self.Clock-((self.MoveCooldowns or {}).R or -100) >= 0.55
    if fakeReady and (threat.Airborne or nearest < 16) then name="R"
    elseif closing and nearest < 8 then name=routeSide < 0 and "V" or "B"
    elseif nearest < 7 and math.abs(threatSide) < 2 then name="C"
    else
        local part = ball:IsA("BasePart") and ball or ball:FindFirstChildWhichIsA("BasePart")
        if part then
            local hand = flat(part.Position-root.Position):Dot(right)
            if routeSide > 1 and hand < -0.2 then name="F"
            elseif routeSide < -1 and hand > 0.2 then name="G" end
        elseif threatSide*routeSide < 0 then name="H" end
        if not name and nearest < 16 then name=math.abs(routeSide)>2 and "H" or "C" end
    end
    if name then self:PulseDribble(name) end
end
function Extension:OffenseStep(character, humanoid, root)
    if self.Shooting then self:StopAutoMove();return false end
    if self.OffenseCharacter ~= character then self:ResetOffense();self.OffenseCharacter=character end
    if not self.OffenseGoal or not self.OffenseGoal.Parent then
        self.OffenseGoal = self:NearestGoal(root,self.Settings.AutoPlayBasket)
        if not self.OffenseGoal then self:StopAutoMove();self.AutoPlayStatus="No nearby attack basket";return false end
        self.GoalDirection = unit(flat(root.Position-self.OffenseGoal.Position))
    end
    local opponents = self:ReadOpponents(root)
    self.OpponentReads = opponents
    local space, jumping = self:SpaceAt(root.Position,opponents)
    local canShoot = self:CanTakeShot(root)
    if canShoot and humanoid.FloorMaterial ~= self.Environment.Enum.Material.Air then
        self:StopAutoMove();self:ReleaseDribbleKeys(true)
        if not self.SettlePosition or flat(root.Position-self.SettlePosition).Magnitude > 0.7 then
            self.SettlePosition,self.SettleSince=root.Position,self.Clock
        end
        local stationary = flat(root.AssemblyLinearVelocity).Magnitude < 3
            or self.Clock-(self.SettleSince or self.Clock)>=0.2
        if not stationary then self.AutoPlayStatus="Stopping for shot";return false end
        self.OpenSince = self.OpenSince or self.Clock
        self.AutoPlayStatus="Open shot: settling"
        return self.Clock-self.OpenSince >= 0.25
    end
    self.OpenSince=nil
    self.SettlePosition,self.SettleSince=nil,nil
    -- Stop on an open spot first; take the shot only after movement settles.
    if canShoot then self:StopAutoMove();self.AutoPlayStatus="Stopping for shot";return false end
    local params = self:MakeRayParams()
    if not self.LastPlan or self.Clock-self.LastPlan >= 0.35 or not self.ShotSpot then
        self.LastPlan=self.Clock;self:PickShotSpot(root,opponents,params)
    end
    if not self.ShotSpot then self:StopAutoMove();self.AutoPlayStatus="No supported shot position";return false end
    if not self.ProgressTime then self.ProgressTime,self.ProgressPosition=self.Clock,root.Position
    elseif self.Clock-self.ProgressTime >= 1.5 then
        if flat(root.Position-self.ProgressPosition).Magnitude < 0.6 then
            self.EscapeSide=-(self.EscapeSide or 1);self.StuckUntil=self.Clock+1.2;self.LastPlan=nil
        end
        self.ProgressTime,self.ProgressPosition=self.Clock,root.Position
    end
    local point = self:SteerTo(root,self.ShotSpot,opponents)
    if point then
        self.AutoMovePoint=point
        self.AutoPlayStatus=jumping and "Reading defender jump: creating space" or (space < 12 and "Evading defender" or "Routing to shot position")
        self:ChooseDribble(root,point,opponents,heldBall(character))
    else self:StopAutoMove();self:ReleaseDribbleKeys(true);self.AutoPlayStatus="Route blocked: waiting to replan" end
    return false
end
