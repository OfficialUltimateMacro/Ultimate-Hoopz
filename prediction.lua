-- Auto-play tuning is deliberately separate from Blessed's AutoGuardPrediction.
-- Uses observed positions/physics velocity only; not knowledge of future input.
local tuning = {
    {Key="AutoPlayPrediction", Title="Auto-play prediction", Default=300, Min=0, Max=600, Step=10, Suffix=" ms"},
    {Key="AutoPlayPredictionSmoothing", Title="Prediction smoothing", Default=35, Min=0, Max=100, Step=1, Suffix="%"},
    {Key="AutoPlayMaxLead", Title="Maximum predicted distance", Default=12, Min=2, Max=18, Step=0.5, Suffix=" studs"},
    {Key="AutoPlayDefenseSpacing", Title="Defense close-out spacing", Default=4, Min=2, Max=10, Step=0.5, Suffix=" studs"},
    {Key="AutoPlayContestDistance", Title="Auto-play contest distance", Default=9, Min=4, Max=12, Step=0.5, Suffix=" studs"},
}
local function finite(n) return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge end
local function bounded(value, default, low, high)
    local number=tonumber(value)
    if not finite(number) then number=default end
    return math.max(low,math.min(high,number))
end
local function pflat(self, vector) return self.Environment.Vector3.new(vector.X,0,vector.Z) end
local function validVector(v) return v and finite(v.X) and finite(v.Y) and finite(v.Z) end
local function limitVelocity(self, velocity)
    local speed=velocity.Magnitude
    return speed>32 and velocity*(32/speed) or velocity
end
function Extension:AutoPlayOption(key)
    for _, option in ipairs(tuning) do
        if option.Key==key then return bounded(self.Settings and self.Settings[key],option.Default,option.Min,option.Max) end
    end
end
function Extension:InitAutoPlayTuning(settings)
    for _, option in ipairs(tuning) do settings[option.Key]=bounded(settings[option.Key],option.Default,option.Min,option.Max) end
    if type(settings.AutoPlayAdaptivePrediction)~="boolean" then settings.AutoPlayAdaptivePrediction=true end
end
function Extension:SetAutoPlayOption(key,value)
    if not self.Settings then return end
    for _, option in ipairs(tuning) do
        if option.Key==key then
            self.Settings[key]=bounded(value,option.Default,option.Min,option.Max)
            return self.Settings[key]
        end
    end
end
function Extension:InstallPredictionControls(section)
    self:InitAutoPlayTuning(self.Settings)
    section:NewToggle({Title="Adaptive Auto-play prediction",Default=self.Settings.AutoPlayAdaptivePrediction,Callback=function(value)
        self.Settings.AutoPlayAdaptivePrediction=value==true
    end})
    -- Real recovered UI supports NewSlider with Min/Max/Step/Default/Callback. Older mock/minimal
    -- sections may not; lack of a widget must not break start/stop controls.
    if type(section.NewSlider)=="function" then
        for _, definition in ipairs(tuning) do
            local option=definition
            -- Blessed's recovered slider errors on a string Suffix (startup harness:
            -- 'attempt to sub a string with a number'), so the unit goes in the title.
            section:NewSlider({Title=option.Title.." ("..option.Suffix:gsub("^%s+","")..")",Min=option.Min,Max=option.Max,Step=option.Step,
                Default=self:AutoPlayOption(option.Key),Callback=function(value) self:SetAutoPlayOption(option.Key,value) end})
        end
    end
end
function Extension:ResetMotionReads()
    self.OpponentMemory=setmetatable({},{__mode="k"})
    self.LastDefensePrediction=nil
end
function Extension:MotionRead(player,character,part)
    self.OpponentMemory=self.OpponentMemory or setmetatable({},{__mode="k"})
    local previous=self.OpponentMemory[player]
    local now=self.Clock
    local position,raw=part.Position,part.AssemblyLinearVelocity
    local zero=self.Environment.Vector3.new(0,0,0)
    if not finite(now) or not validVector(position) or not validVector(raw) then
        self.OpponentMemory[player]=nil
        return zero,0,"invalid motion"
    end
    raw=pflat(self,raw)
    if previous and previous.Character==character and previous.Root==part and previous.LastRead==now
        and (position-previous.LastPosition).Magnitude<0.001 and (raw-previous.Raw).Magnitude<0.001 then
        return previous.Velocity,previous.Confidence,previous.Reason
    end
    local elapsed=previous and now-previous.Time or 0
    local frameTime=previous and now-previous.LastRead or 0
    local reset=previous and (previous.Character~=character or previous.Root~=part or elapsed<0 or elapsed>0.5)
    local displacement=previous and pflat(self,position-previous.Position) or zero
    local teleported=previous and elapsed>=0 and elapsed<=0.5 and displacement.Magnitude>math.max(10,45*elapsed+2)
    local velocity,confidence,reason=raw,1,"physics"
    if reset or teleported then
        velocity,confidence,reason=zero,0,teleported and "position reset" or "stale/new character"
    elseif previous then
        local stopped=raw.Magnitude<0.75
        local turned=raw.Magnitude>3 and previous.Raw.Magnitude>3
            and raw:Dot(previous.Raw)<-0.2*raw.Magnitude*previous.Raw.Magnitude
        local started=raw.Magnitude>6 and previous.Velocity.Magnitude<1.5
        if stopped then
            velocity,reason=zero,"stopped"
        elseif started then
            -- Restart from a stop: smoothing toward the old zero velocity
            -- lagged (synthetic stop-and-go error +20%); trust physics.
            velocity,confidence,reason=raw,0.8,"start"
        elseif turned then
            -- Do not average a new crossover with old opposite-direction motion.
            velocity,confidence,reason=raw,0.4,"direction change"
        else
            if elapsed>=0.06 and elapsed<=0.5 then
                local measured=displacement/elapsed
                if measured.Magnitude<=45 then velocity=raw*0.55+measured*0.45;reason="position + physics" end
            end
            if frameTime>0 and frameTime<=0.5 then
                local timeConstant=self:AutoPlayOption("AutoPlayPredictionSmoothing")/100*0.18
                local alpha=frameTime/(frameTime+timeConstant)
                velocity=previous.Velocity*(1-alpha)+velocity*alpha
            end
        end
    end
    velocity=limitVelocity(self,velocity)
    local sampleTime,samplePosition=now,position
    if previous and not reset and not teleported and elapsed<0.06 then sampleTime,samplePosition=previous.Time,previous.Position end
    self.OpponentMemory[player]={Character=character,Root=part,Time=sampleTime,Position=samplePosition,
        LastRead=now,LastPosition=position,Raw=raw,Velocity=velocity,Confidence=confidence,Reason=reason}
    return velocity,confidence,reason
end
function Extension:PredictionLead(gap,defensive)
    local base=self:AutoPlayOption("AutoPlayPrediction")/1000
    if defensive and self.Settings.AutoPlayAdaptivePrediction~=false then
        return math.min(0.6,base/0.3*math.max(0.2,math.min(0.5,0.2+(gap or 0)/50)))
    end
    return base
end
function Extension:PredictionOffset(velocity,lead,confidence)
    local factor=self.Settings.AutoPlayAdaptivePrediction~=false and (confidence or 1) or (confidence==0 and 0 or 1)
    local offset=pflat(self,velocity)*lead*factor
    local cap=self:AutoPlayOption("AutoPlayMaxLead")
    if offset.Magnitude>cap then offset=offset*(cap/offset.Magnitude) end
    return offset
end
function Extension:BoundPredictedPosition(position,offset)
    local target=position+offset
    if self.MatchPosition then
        for _=1,4 do
            if self:MatchPosition(target) then return target end
            offset=offset*0.5;target=position+offset
        end
        return position
    end
    return target
end
