-- Suspected abnormal pickups (possible ball-magnet/remote-touch use).
-- Client observations only: replication delay, hidden server hitboxes and
-- dropped frames mean this can never prove cheating. Results are called
-- "suspected" and never "confirmed". Only possession that appears in the
-- locked opponent's hands while the last fresh sample showed the ball well
-- beyond a generous reach allowance is counted. A magnet that physically
-- drags the ball close before pickup looks like a normal pickup and is not.
local PICKUP = {
    BaseReach = 9, MinDistance = 14, Latency = 0.25, Margin = 2,
    StaleAge = 0.25, Tau = 120, Window = 300, History = 1.2, MaxSamples = 90,
    MaxEvents = 8, Spacing = 5,
}
Extension.PickupConfig = PICKUP
local function pkey(player) return player and tostring(player.UserId or player.Name) or nil end
local function pflat(v) return Extension.Environment.Vector3.new(v.X, 0, v.Z) end
function Extension:ResetPickupEvidence(reason)
    self.PickupEvidence = {Key=nil, Name=nil, Goal=self.MatchGoal, Events={}, Normal=0, Rejected={}, Possession=0}
    self.PickupHistory, self.PickupMarks = {}, {Teleport={}, Respawn={}}
    self.RimConfirmedKey, self.RimPromptCount, self.RimAutoActive = nil, nil, false
    if reason and self.Log then self:Log("evidence", "reset: "..reason) end
end
-- One ball must be on the locked court: held by a court player or loose.
function Extension:CourtBallSample()
    local goal = self.MatchGoal
    if not goal or not goal.Parent then return nil, "no locked court" end
    local found, count = nil, 0
    local players = {}
    for _, player in ipairs(self:PlayerList()) do
        local character, _, root = characterParts(player)
        if character and self:MatchPlayer(player) then
            players[player] = {Position=root.Position, Velocity=root.AssemblyLinearVelocity, Character=character}
            local held = heldBall(character)
            if held then
                local part = ballPart(held)
                count = count+1
                found = {Position=(part and part.Position) or root.Position, Holder=player}
            end
        end
    end
    for part in pairs(self:BallSet()) do
        if part.Parent and not self:BallOwner(part) and self:MatchPosition(part.Position) then
            count = count+1
            found = {Position=part.Position, Velocity=part.AssemblyLinearVelocity}
        end
    end
    if count == 0 then return nil, "no ball on court" end
    if count > 1 then return nil, "multiple balls on court" end
    found.Players = players
    return found
end
local function recent(mark, now, window) return mark ~= nil and now-mark <= window end
-- Per-frame sampler (cheap: a few positions). Called only while Auto-play runs.
function Extension:SamplePickups()
    if not self.PickupEvidence then self:ResetPickupEvidence() end
    local ev, marks, now = self.PickupEvidence, self.PickupMarks, self.Clock
    if ev.Goal ~= self.MatchGoal then
        local had = ev.Goal ~= nil
        self:ResetPickupEvidence(had and "court changed" or nil)
        ev, marks = self.PickupEvidence, self.PickupMarks
        marks.MatchChanged = now
    end
    local inGame
    pcall(function() inGame = self.Player:GetAttribute("Ingame") end)
    if inGame ~= marks.InGame then
        if marks.InGameSeen then marks.InGameChanged = now end
        marks.InGame, marks.InGameSeen = inGame, true
    end
    local history = self.PickupHistory
    local sample, why = self:CourtBallSample()
    if not sample then
        local last = history[#history]
        if why == "multiple balls on court" then marks.Ambiguous = now
        elseif why == "no ball on court" and last then marks.OutOfCourt = now end
        return
    end
    sample.T = now
    local previous = history[#history]
    if previous then
        local dt = now-previous.T
        if dt > 0 and dt < 0.5 then
            local jump = (sample.Position-previous.Position).Magnitude
            if sample.Holder == previous.Holder and jump > 20 then marks.BallTeleport = now end
            if not sample.Velocity then sample.Velocity = (sample.Position-previous.Position)/dt end
            for player, info in pairs(sample.Players) do
                local before = previous.Players[player]
                if before then
                    if before.Character ~= info.Character then marks.Respawn[pkey(player)] = now
                    elseif (info.Position-before.Position).Magnitude > 25 then marks.Teleport[pkey(player)] = now end
                end
            end
        end
        -- Made basket: the ball drops through the hoop (handover follows).
        local goal = self.MatchGoal.Position
        if pflat(sample.Position-goal).Magnitude < 2.5 and previous.Position.Y >= goal.Y and sample.Position.Y < goal.Y-0.5 then
            marks.Made = now
        end
        if sample.Holder ~= previous.Holder and sample.Holder and sample.Holder ~= ev.LastHolder then
            ev.Possession = ev.Possession+1
        end
    end
    sample.Velocity = sample.Velocity or self.Environment.Vector3.new()
    if sample.Holder then ev.LastHolder = sample.Holder end
    if previous and sample.Holder and previous.Holder ~= sample.Holder then self:EvaluatePickup(previous, sample) end
    history[#history+1] = sample
    while #history > PICKUP.MaxSamples or (history[1] and now-history[1].T > PICKUP.History) do table.remove(history, 1) end
end
function Extension:RejectPickup(name, reason)
    local ev = self.PickupEvidence
    ev.Rejected[reason] = (ev.Rejected[reason] or 0)+1
    ev.LastDecision = "rejected ("..reason..")"
    if self.Log then self:Log("evidence", tostring(name).." pickup rejected: "..reason) end
end
-- Evaluate one possession change into a court player's hands.
function Extension:EvaluatePickup(previous, current)
    local holder, now, ev, marks = current.Holder, self.Clock, self.PickupEvidence, self.PickupMarks
    if holder == self.Player then return end
    local teammate = self.Player.Team ~= nil and holder.Team == self.Player.Team and self.Player.Neutral == false and holder.Neutral == false
    if teammate then return end
    -- Continuation of the same possession (dribble reparent flicker).
    for k = #self.PickupHistory, 1, -1 do
        local s = self.PickupHistory[k]
        if now-s.T > 0.6 then break end
        if s.Holder == holder then return end
    end
    local key, name = pkey(holder), holder.Name
    if self.MatchOpponent and self.MatchOpponent ~= holder then return self:RejectPickup(name, "not the locked opponent") end
    if ev.Key and ev.Key ~= key then
        self:ResetPickupEvidence("opponent changed")
        ev, marks = self.PickupEvidence, self.PickupMarks
    end
    ev.Key, ev.Name = key, name
    local age = current.T-previous.T
    if previous.Holder and previous.Holder ~= self.Player then return self:RejectPickup(name, "direct transfer between other players (pass)") end
    if age > PICKUP.StaleAge then return self:RejectPickup(name, string.format("stale sample %.2fs", age)) end
    local before = previous.Players[holder]
    if not before then return self:RejectPickup(name, "no prior opponent sample") end
    if recent(marks.Respawn[key], now, 1.5) then return self:RejectPickup(name, "opponent respawned") end
    if recent(marks.Teleport[key], now, 1.5) then return self:RejectPickup(name, "opponent teleported (reset)") end
    if (self.ResetUntil and now < self.ResetUntil+1) or recent(marks.Respawn[pkey(self.Player)], now, 1.5)
        or recent(marks.Teleport[pkey(self.Player)], now, 1.5) then return self:RejectPickup(name, "local reset/respawn") end
    if recent(marks.BallTeleport, now, 1) then return self:RejectPickup(name, "ball teleported (inbound/reset)") end
    if recent(marks.Made, now, 3) then return self:RejectPickup(name, "made-basket handover") end
    if recent(marks.OutOfCourt, now, 2) then return self:RejectPickup(name, "ball left court (dead ball)") end
    if recent(marks.Ambiguous, now, 1) then return self:RejectPickup(name, "ambiguous ownership (multiple balls)") end
    if recent(marks.InGameChanged, now, 2) or recent(marks.MatchChanged, now, 2) then return self:RejectPickup(name, "match state changed") end
    local offset = previous.Position-before.Position
    local reach = pflat(offset).Magnitude+math.max(0, math.abs(offset.Y)-6)
    local speed = previous.Velocity.Magnitude+before.Velocity.Magnitude
    local threshold = math.max(PICKUP.MinDistance, PICKUP.BaseReach+speed*(age+PICKUP.Latency)+PICKUP.Margin)
    local kind = previous.Holder == self.Player and "steal" or "loose ball"
    if reach <= threshold then
        ev.Normal = ev.Normal+1
        ev.LastDecision = string.format("normal %s %.1f <= %.1f studs", kind, reach, threshold)
        if self.Log then self:Log("evidence", name.." "..ev.LastDecision) end
        return
    end
    local last = ev.Events[#ev.Events]
    if last and last.Possession == ev.Possession then return self:RejectPickup(name, "already counted this possession") end
    if last and now-last.T < PICKUP.Spacing then return self:RejectPickup(name, "too soon after previous event") end
    ev.Events[#ev.Events+1] = {T=now, Distance=reach, Threshold=threshold, Excess=reach-threshold, Possession=ev.Possession, Kind=kind}
    while #ev.Events > PICKUP.MaxEvents do table.remove(ev.Events, 1) end
    ev.LastDecision = string.format("accepted %s %.1f studs (allowance %.1f)", kind, reach, threshold)
    if self.Log then self:Log("evidence", name.." "..ev.LastDecision) end
end
-- Decayed evidence for the current opponent. Levels: none / suspected /
-- strong. "Strong" is still a client-side suspicion, never a confirmation.
function Extension:PickupLevel()
    local ev, now = self.PickupEvidence, self.Clock
    if not ev then return "none", 0, 0, 0, nil end
    local score, excess, kept = 0, {}, {}
    for _, e in ipairs(ev.Events) do
        if now-e.T <= PICKUP.Window then
            kept[#kept+1] = e
            score = score+math.exp(-(now-e.T)/PICKUP.Tau)
            excess[#excess+1] = e.Excess
        end
    end
    ev.Events = kept
    table.sort(excess)
    local median = #excess > 0 and excess[math.floor((#excess+1)/2)] or 0
    local last = kept[#kept]
    local level = "none"
    if #kept >= 3 and score >= 2.4 and median >= 6 then level = "strong"
    elseif #kept >= 2 and score >= 1.5 then level = "suspected" end
    return level, score, #kept, median, last and now-last.T or nil
end
function Extension:Notify(title, text, duration)
    local captures = self.InputCaptures
    if captures and captures[2] and type(captures[2].Notification) == "function" then
        pcall(function() captures[2].Notification().new({Title=title, Description=text, Duration=duration or 6}) end)
    end
    self.LastNotice = title..": "..text
end
function Extension:EvidenceSummary()
    local level, score, count, median, age = self:PickupLevel()
    local ev = self.PickupEvidence or {Normal=0}
    return string.format("%s suspected events=%d score=%.2f median excess=%.1f last=%s normal=%d",
        level, count, score, median, age and string.format("%.0fs", age) or "-", ev.Normal or 0), level, score, count
end
-- Decide normal vs conditional strategy (plan tick, logs only on change).
function Extension:UpdateRimStrategy()
    if not self.PickupEvidence then self:ResetPickupEvidence() end
    local ev = self.PickupEvidence
    local mode = self.Settings.AutoPlayMagnetResponse or "Manual confirm"
    local summary, level, score, count = self:EvidenceSummary()
    local opponent = self.MatchOpponent
    local scoped = ev.Key ~= nil and opponent ~= nil and pkey(opponent) == ev.Key and self:MatchPlayer(opponent)
    local active, reason = false, nil
    if self.Settings.AutoPlayRimOverride then
        active, reason = true, "manual strategy override (test; not an accusation)"
    elseif mode == "Off" then
        reason = "detection response off"
    elseif not scoped then
        reason = "no evidence for the locked opponent"
    elseif mode == "Manual confirm" then
        if self.RimConfirmedKey == ev.Key then
            if score >= 0.6 then active, reason = true, "you confirmed suspected abnormal pickups by "..tostring(ev.Name)
            else
                self.RimConfirmedKey = nil
                self:Log("strategy", "evidence expired: confirmation cleared")
                reason = "evidence expired"
            end
        elseif level ~= "none" and (self.RimPromptCount or 0) < count then
            self.RimPromptCount = count
            local _, _, _, median, age = self:PickupLevel()
            self:Notify("Suspected abnormal pickups", string.format(
                "%s: %d pickups beyond reach (median +%.1f studs, last %.0fs ago). Client-side estimate only. Press Confirm suspected opponent to use the rim strategy.",
                tostring(ev.Name), count, median, age or 0), 8)
            self:Log("strategy", "prompted for confirmation: "..summary)
            reason = "awaiting your confirmation"
        else reason = level == "none" and "insufficient evidence" or "awaiting your confirmation" end
    elseif mode == "Auto (experimental)" then
        if self.RimAutoActive and score < 1.0 then self.RimAutoActive = false
        elseif not self.RimAutoActive and level == "strong" then self.RimAutoActive = true end
        active = self.RimAutoActive
        reason = active and "automatic: strong repeated suspected pickups by "..tostring(ev.Name) or "automatic: evidence below strong"
    end
    if active ~= (self.AdaptiveRimOnly == true) then
        self:Log("strategy", (active and "conditional rim strategy ON: " or "normal strategy: ")..tostring(reason).." | "..summary)
    end
    self.AdaptiveRimOnly, self.AdaptiveReason = active, reason
    return active
end
function Extension:ConfirmSuspectedOpponent()
    if not self.PickupEvidence then self:ResetPickupEvidence() end
    local ev = self.PickupEvidence
    local summary, level = self:EvidenceSummary()
    local opponent = self.MatchOpponent
    if level == "none" or not opponent or pkey(opponent) ~= ev.Key then
        self:Notify("Rim strategy", "No current suspected evidence for the locked opponent. Use Rim strategy override to test without evidence.", 6)
        self:Log("strategy", "confirmation refused: "..summary)
        return false
    end
    self.RimConfirmedKey = ev.Key
    self:Notify("Rim strategy", "Using the rim strategy against "..tostring(ev.Name).." while evidence stays fresh. "..summary, 6)
    self:Log("strategy", "user confirmed: "..summary)
    return true
end
function Extension:ClearRimStrategy()
    self.RimConfirmedKey, self.RimAutoActive = nil, false
    self.Settings.AutoPlayRimOverride = false
    if self.RimOverrideToggle and type(self.RimOverrideToggle.SetValue) == "function" then pcall(self.RimOverrideToggle.SetValue, false) end
    self:Log("strategy", "cleared by user")
end
