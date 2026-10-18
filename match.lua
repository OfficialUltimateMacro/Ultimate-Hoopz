-- Keep all decisions on one local court. Never acquire a server-wide holder
-- first and then let that stranger choose the defended basket.
local function attribute(object,key)
    if object and type(object.GetAttribute)=="function" then
        local ok,value=pcall(object.GetAttribute,object,key)
        if ok and (type(value)=="string" or type(value)=="number" or type(value)=="boolean") then return value end
    end
end
local function mflat(v)return Extension.Environment.Vector3.new(v.X,0,v.Z)end
function Extension:GoalLabel(goal)
    if not goal then return "unlocked" end
    local path=goal.Name or "Goal"
    if type(goal.GetFullName)=="function" then local ok,v=pcall(goal.GetFullName,goal);if ok then path=v end end
    local p=goal.Position
    return path..string.format(" [%.0f,%.0f,%.0f]",p.X,p.Y,p.Z)
end
function Extension:LockMatch(goal)
    local _,_,root=characterParts(self.Player)
    if not root then return end
    goal=goal or self:NearestGoal(root,self.Settings.AutoPlayBasket)
    self.MatchGoal,self.MatchChoice=goal,self.Settings.AutoPlayBasket
    self.MatchOpponent=nil
    self.MatchAnchor=root.Position
    self.ContextReason=goal and "court locked at local player" or "no local basket"
    self.DefenseGoal,self.LastDefenseTarget,self.Holder=nil,nil,nil
    self.RecoveryBall,self.RecoveryUntil=nil,nil
    if self.ResetOffense then self:ResetOffense() end
    self:StopAutoMove()
    self.State,self.PendingState=nil,nil
    self:Log("match",self.ContextReason..": "..self:GoalLabel(goal))
end
function Extension:EnsureMatch()
    if self.MatchChoice~=self.Settings.AutoPlayBasket or (not self.MatchGoal or not self.MatchGoal.Parent)
        and self.Clock>=(self.NextContextLock or -100) then
        self.NextContextLock=self.Clock+1;self:LockMatch()
    end
    return self.MatchGoal
end
function Extension:MatchPosition(position)
    local goal=self.MatchGoal
    if not goal then return true end -- legacy isolated unit fixtures only
    if math.abs(position.Y-goal.Position.Y)>45 or mflat(position-goal.Position).Magnitude>125 then return false end
    -- Voronoi boundary prevents crossing into an adjacent half court. A small
    -- margin admits bodies/balls on the shared painted boundary.
    local d=mflat(position-goal.Position).Magnitude
    for _,other in ipairs(self:Goals())do
        if other~=goal and other.Parent and math.abs(other.Position.Y-goal.Position.Y)<15
            and mflat(position-other.Position).Magnitude+8<d then return false end
    end
    return true
end
function Extension:MatchPlayer(player)
    local _,_,root=characterParts(player)
    if not root or not self:MatchPosition(root.Position) then return false end
    if attribute(self.Player,"Ingame")==true and attribute(player,"Ingame")==false then return false end
    for _,key in ipairs({"Court","CourtId","CourtID","MatchId","MatchID","GameId"})do
        local ours=attribute(self.Player,key) or attribute(self.Player.Character,key)
        local theirs=attribute(player,key) or attribute(player.Character,key)
        if ours~=nil and theirs~=nil and ours~=theirs then return false end
    end
    local selected=self.Settings.AutoPlayOpponent
    if selected and selected~="Auto (this court)" and player~=self.Player then return player.Name==selected end
    return true
end
function Extension:SelectMatchHolder(character)
    self:EnsureMatch()
    local own=heldBall(character)
    if own then
        local ok,part=pcall(function() return own:IsA("BasePart") and own or own:FindFirstChild("Ball") end)
        if ok then self.PossessionBall=part end
        return "Own",self.Player
    end
    local _,_,root=characterParts(self.Player)
    if not root then return "Loose",nil end
    if not self.MatchGoal or not self.MatchGoal.Parent then self.ContextReason="No court locked: use Lock viewed hoop";return "Loose",nil end
    local candidates={}
    for _,player in ipairs(self:PlayerList())do
        if player~=self.Player and self:MatchPlayer(player) and heldBall(player.Character) then
            local teammate=self.Player.Team~=nil and player.Team==self.Player.Team
                and self.Player.Neutral==false and player.Neutral==false
            local _,_,other=characterParts(player)
            candidates[#candidates+1]={Player=player,Kind=teammate and "Teammate" or "Opponent",Distance=(root.Position-other.Position).Magnitude}
        end
    end
    for _,c in ipairs(candidates)do if c.Player==self.MatchOpponent then return c.Kind,c.Player end end
    -- Once the opponent is known, do not replace them with another server
    -- player holding a different ball during a release or dribble.
    if self.MatchOpponent and self:MatchPlayer(self.MatchOpponent) then return "Loose",nil end
    table.sort(candidates,function(a,b)return a.Distance<b.Distance end)
    local first=candidates[1]
    if first and candidates[2] and candidates[2].Distance-first.Distance<10 then
        self.ContextReason="multiple holders on court: select Opponent";return "Loose",nil
    end
    if first then
        if first.Kind=="Opponent" then
            self.MatchOpponent=first.Player
            self:Log("match","opponent locked "..first.Player.Name.." | "..self:GoalLabel(self.MatchGoal))
        end
        return first.Kind,first.Player
    end
    return "Loose",nil
end
function Extension:LockViewedHoop()
    local camera=self.Environment.workspace.CurrentCamera
    if not camera then return end
    local best,score=nil,-1
    for _,goal in ipairs(self:Goals())do
        local delta=goal.Position-camera.CFrame.Position
        if delta.Magnitude<170 and delta.Magnitude>1 then
            local alignment=delta.Unit:Dot(camera.CFrame.LookVector)
            if alignment>0.85 and alignment>score then best,score=goal,alignment end
        end
    end
    if best then self:LockMatch(best) else self.ContextReason="Look toward the intended rim, then lock again";self:Log("match",self.ContextReason) end
end
function Extension:RecoveryStep(character,humanoid,root)
    local preferred=self.RecoveryBall or (self.ShotTrack and self.ShotTrack.Ball)
    local ball,best=nil,85
    for candidate in pairs(self:BallSet())do
        if candidate.Parent and not self:BallOwner(candidate) and self:MatchPosition(candidate.Position) then
            local d=(candidate.Position-root.Position).Magnitude
            if candidate==preferred and d<85 then ball=candidate;break end
            if d<best then ball,best=candidate,d end
        end
    end
    if not ball then self:StopAutoMove();self.StopReason="no loose ball on locked court";self.AutoPlayStatus="Watching court for rebound";return end
    local velocity=ball.AssemblyLinearVelocity or self.Environment.Vector3.new()
    local gravity=self.Environment.workspace.Gravity or 196.2
    local height=math.max(0,ball.Position.Y-root.Position.Y)
    local t=math.min(1.2,math.max(0,(velocity.Y+math.sqrt(velocity.Y*velocity.Y+2*gravity*height))/gravity))
    local lead=mflat(velocity)*math.min(t,0.9)
    if lead.Magnitude>25 then lead=lead.Unit*25 end
    local point=self.Environment.Vector3.new(ball.Position.X,root.Position.Y,ball.Position.Z)+lead
    if not self:MatchPosition(point) then point=self.Environment.Vector3.new(ball.Position.X,root.Position.Y,ball.Position.Z) end
    local params=self:MakeRayParams()
    if not self:HasFloor(point,params) then self:StopAutoMove();self.StopReason="rebound landing point unsupported";return end
    local target=self:SteerTo(root,point,self:ReadOpponents(root))
    self.AutoMovePoint=target
    self.RecoveryTarget,self.RecoveryBall=point,ball
    self.AutoPlayStatus=height>5 and "Rebounding: predicting landing" or "Recovering loose ball"
    self.StopReason=target and nil or "at recovery point"
end
