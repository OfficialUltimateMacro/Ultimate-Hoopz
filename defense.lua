-- Basket-aware defense for Auto-play. Hoopz half-court play attacks one hoop;
-- the defended basket is the goal on the attacker's court (nearest to the
-- attacker, kept for the possession), never simply the hoop nearest to us.
local function dflat(v) return Extension.Environment.Vector3.new(v.X, 0, v.Z) end
local function dunit(v)
    local m = v.Magnitude
    if m < 0.001 then return Extension.Environment.Vector3.new(1, 0, 0) end
    return v / m
end
local function dsegment(point, a, b)
    local d = dflat(b-a)
    local t = math.max(0, math.min(1, dflat(point-a):Dot(d) / math.max(0.001, d:Dot(d))))
    return dflat(point-(a+d*t)).Magnitude
end
function Extension:DefendedGoal(attackerRoot)
    if self.MatchGoal and self.MatchGoal.Parent then
        self.DefenseGoal=self.MatchGoal
        return self.MatchGoal
    end
    local current = self.DefenseGoal
    local best, bestDistance
    for _, goal in ipairs(self:Goals()) do
        if goal.Parent and math.abs(goal.Position.Y-attackerRoot.Position.Y) < 30 then
            local d = dflat(goal.Position-attackerRoot.Position).Magnitude
            if d <= 150 and (not bestDistance or d < bestDistance) then best, bestDistance = goal, d end
        end
    end
    if current and current.Parent and best ~= current then
        local d = dflat(current.Position-attackerRoot.Position).Magnitude
        -- Sticky: only switch when the other hoop is clearly the attacker's.
        if d <= 150 and d < bestDistance+25 then return current end
    end
    if best ~= current then
        self.DefenseGoal = best
        if best and self.Log then self:Log("defense", "defending basket "..tostring(best.Name)) end
    end
    return best
end
function Extension:AttackerRead(attacker, root)
    for _, read in ipairs(self.OpponentReads or {}) do
        if read.Player == attacker then return read end
    end
    return nil
end
-- One defensive decision. Returns the movement target (or nil to hold) and
-- the reason, plus sets DefenseFacing toward the attacker.
function Extension:DefenseStep(character, humanoid, root, attacker)
    local _, attackerHumanoid, attackerRoot = characterParts(attacker)
    if not attackerRoot then self:StopAutoMove(); self.DefenseIntent = "No live attacker"; return nil end
    self.OpponentReads = self:ReadOpponents(root)
    local goal = self:DefendedGoal(attackerRoot)
    if not goal then self:StopAutoMove(); self.DefenseIntent = "No basket on the attacker's court"; return nil end
    local read = self:AttackerRead(attacker, root)
    local velocity = read and read.Velocity or dflat(attackerRoot.AssemblyLinearVelocity)
    if velocity.Magnitude > 32 then velocity = dunit(velocity)*32 end
    local here = root.Position
    local gap = dflat(attackerRoot.Position-here).Magnitude
    local lead = math.max(0.2, math.min(0.5, 0.2+gap/50))
    local rim = self.Environment.Vector3.new(goal.Position.X, here.Y, goal.Position.Z)
    -- Lead drives toward the rim fully; side-to-side crossovers only a
    -- little, enough to offset our slower lateral speed without overshooting.
    local axis = dunit(dflat(rim-attackerRoot.Position))
    local driveVelocity = axis*math.max(0, velocity:Dot(axis))
    local sideVelocity = velocity-axis*velocity:Dot(axis)
    local predicted = attackerRoot.Position+driveVelocity*lead+sideVelocity*0.3
    local attackerFlat = self.Environment.Vector3.new(predicted.X, here.Y, predicted.Z)
    local toRim = dflat(rim-attackerFlat)
    local rimDistance = toRim.Magnitude
    local direction = dunit(toRim)
    local lateral = self.Environment.Vector3.new(-direction.Z, 0, direction.X)
    local driveSpeed = velocity:Dot(direction)
    local shooterRange = (goal.Position-attackerRoot.Position).Magnitude <= 80
    -- How far along the attacker->rim axis we are; <= 0.5 means level/behind.
    local along = dflat(here-attackerFlat):Dot(direction)
    local mode, spacing
    if self.TurnoverRetreat and (along>3 or rimDistance<10 or self.Clock-(self.TurnoverAt or self.Clock)>2.5) then self.TurnoverRetreat=nil end
    if self.TurnoverRetreat and along<3 then
        mode="Transition: protect hoop"
        spacing=math.max(4,rimDistance-10)
    elseif along < 0.5 then
        mode = "Recover"
        spacing = math.min(rimDistance*0.6, 9)
        -- Beaten on a drive close to the basket: sprint to the rim itself
        -- instead of chasing the attacker's back.
        if rimDistance < 30 and driveSpeed > 4 then spacing = math.max(spacing, rimDistance-3) end
    elseif rimDistance < 22 or (driveSpeed > 8 and rimDistance < 60) then
        mode = "Protect rim"
        spacing = math.max(2.5, math.min(6, rimDistance*0.35))
    elseif shooterRange then
        mode = "Close out"
        spacing = 4
    else
        mode = "Contain"
        spacing = 6
    end
    spacing = math.min(spacing, math.max(0.5, rimDistance-1))
    local target = attackerFlat+direction*spacing
    -- Recover around the attacker, not through him.
    if (mode == "Recover" or mode=="Transition: protect hoop") and dsegment(attackerFlat, here, target) < 2.5 then
        local side = dflat(here-attackerFlat):Dot(lateral) >= 0 and 1 or -1
        if mode=="Transition: protect hoop" then
            target=target+lateral*side*6
        else target = attackerFlat+lateral*side*4+direction*2 end
    end
    -- Never drift farther from the basket than the attacker (out of bounds /
    -- onto another court), and keep on supported floor.
    if dflat(target-rim).Magnitude > dflat(attackerFlat-rim).Magnitude+2 then
        target = attackerFlat+direction*math.max(spacing, 2)
    end
    local params = self:MakeRayParams()
    if params and not self:HasFloor(target, params) then
        target = self.LastDefenseTarget or here
    end
    self.LastDefenseTarget = target
    self.DefenseFacing = dunit(dflat(attackerRoot.Position-here))
    self.DefenseGoalPosition = rim
    -- Contest only real shots/dunks or a rising jump close in front.
    local attackerAction = self.GameAction and self:GameAction(attacker.Character)
    local rising = attackerHumanoid.FloorMaterial == self.Environment.Enum.Material.Air
        and attackerRoot.AssemblyLinearVelocity.Y > 8
    if (attackerAction == "Shooting" or attackerAction == "Dunking" or rising) and gap < 9 and along > -1
        and humanoid.FloorMaterial ~= self.Environment.Enum.Material.Air and self.Clock-self.LastJump >= 0.6 then
        humanoid.Jump, self.LastJump = true, self.Clock
        self.ContestCount = (self.ContestCount or 0)+1
        if self.Log then self:Log("defense", "contest jump ("..tostring(attackerAction or "rising")..")") end
    end
    self.DefenseMode = mode
    if dflat(target-here).Magnitude < 1 then
        self:StopAutoMove()
        self.DefenseIntent = mode..": holding good basket-side spot"
        return nil
    end
    self.AutoMovePoint = target
    self.DefenseIntent = mode
    return target
end
