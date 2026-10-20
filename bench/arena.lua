-- Ultimate 1v1 benchmark arena (mock physics; see README in bench.py).
-- Placeholders are substituted by bench.py.
_G.ULTIMATE_BLESSED_INSPECT=true;bit32={}
local F=(function() FIXTURE end)()
local app=assert(load(SOURCE,'arena','t',_G))();local e=app.Extensions;local v=F.v
local P=PROFILE
math.randomseed(SEED)
local rnd=math.random
F.farGoal.Position=v(600,12,0)
local notes={}
local s={AutoGuard=false,AutoGuardKeybind='L',Aimbot=true,AimbotType='High',ShotDelay=0.28,BallMagnet=false,BallReach=true}
e:Install(F.env,s)
for k,x in pairs(TUNE) do e[k]=x end
e.InputCaptures={[2]={Notification=function()return {new=function(t)notes[#notes+1]=t end} end}}
if RESPONSE~='' then s.AutoPlayMagnetResponse=RESPONSE end
local own,enemy,root,er,oh,eh=F.own,F.enemy,F.root,F.er,F.oh,F.eh
local goal=F.goal
local dt=1/60
local function flat(a)return v(a.X,0,a.Z)end
local function fd(a,b)return flat(a-b).Magnitude end
local rim=v(goal.Position.X,3,goal.Position.Z)
local function segd(p,a,b)
 local ab=flat(b-a);local t=math.max(0,math.min(1,flat(p-a):Dot(ab)/math.max(.001,ab:Dot(ab))))
 return flat(p-(a+ab*t)).Magnitude
end
own.Character.ball=F.container(own.Character,false);enemy.Character.ball=F.container(enemy.Character,false)
-- ---------------------------------------------------------------- state
local M={us={},them={}}
for _,k in ipairs({'us','them'})do
 M[k]={poss=0,pts=0,jA=0,jRel=0,jMade=0,stripped=0,dA=0,dMade=0,dBlocked=0,stolen=0,clock=0,oreb=0,dreb=0,looseLost=0,threes=0,twos=0}
end
local hold,offense='none','us'
local loose,looseAt,flight=nil,0,nil
local wind={}          -- wind.us / wind.them: {t,len,dist}
local dunk={}          -- dunk.us / dunk.them: {t,from}
local air={us=0,them=0}
local stun=0
local protect=0
local shotStart=0
local now=0
local hist={}
local checkUntil=0
local aiPlan={}
local keyIndex=1
local ourAttr,theirAttr=own.Character.attrs,enemy.Character.attrs
local events={}
local function log(t)if #events<4000 then events[#events+1]=string.format('%.1f %s',now,t) end end
local function clearBalls()for _,b in ipairs(F.balls)do b.Parent=nil end;F.balls={} end
local function setHold(who)
 hold=who
 own.Character.ball:SetBall(who=='us');enemy.Character.ball:SetBall(who=='them')
 if who~='loose' then clearBalls();loose=nil end
end
local function placeLoose(pos)
 clearBalls();loose=F.part(pos,'Basketball');loose.Owner=nil;F.balls={loose};F.world.DescendantAdded:Fire(loose);looseAt=now
 own.Character.ball:SetBall(false);enemy.Character.ball:SetBall(false);hold='loose'
end
local function newPossession(who)
 offense=who;M[who].poss=M[who].poss+1
 local a=(rnd()-0.5)*1.0
 local dir=v(math.cos(a),0,math.sin(a))
 local o=rim+dir*99;local d=rim+dir*81
 if who=='us' then root.Position=o;er.Position=d else er.Position=o;root.Position=d end
 root.AssemblyLinearVelocity=v();er.AssemblyLinearVelocity=v();oh.point=nil
 clearBalls();flight=nil;wind={};dunk={};ourAttr.Action=nil;theirAttr.Action=nil
 setHold(who);shotStart=now;checkUntil=now+0.5;hist={}
 local sa=a+(rnd()-0.5)*0.5;aiPlan={spot=rim+v(math.cos(sa),0,math.sin(sa))*62,drive=false,next=0}
end
local pending=nil
-- Live-ball turnovers: the new holder keeps the ball in place briefly before
-- the game's check-ball reset (lets the pickup sampler see the transfer).
local function changePossession(to,live)
 if live then setHold(to);wind={};dunk={};ourAttr.Action=nil;theirAttr.Action=nil;pending={to=to,at=now+0.6}
 else newPossession(to) end
end
local function shooterP(d3,gap,defAir)
 local p=(d3>=P.lo and d3<=P.hi) and P.make or 0.08
 if gap<6 then p=p*(0.55+0.45*gap/6) end
 if defAir and gap<6 then p=p*0.6 end
 return p
end
local function other(k)return k=='us' and 'them' or 'us' end
local function rootOf(k)return k=='us' and root or er end
-- ---------------------------------------------------------------- shots
e.AimAction=function()
 if hold=='us' and not wind.us and not dunk.us then
  wind.us={t=0,len=s.ShotDelay+0.12,dist=fd(goal.Position,root.Position),at=root.Position}
  ourAttr.Action='Shooting';M.us.jA=M.us.jA+1
 end
end
local function release(k)
 local w=wind[k];wind[k]=nil
 local r=rootOf(k);local opp=rootOf(other(k))
 if k=='us' then ourAttr.Action=nil else theirAttr.Action=nil end
 local gap=fd(r.Position,opp.Position)
 local made=rnd()<shooterP(w.dist,gap,air[other(k)]>0)
 M[k].jRel=M[k].jRel+1
 own.Character.ball:SetBall(false);enemy.Character.ball:SetBall(false);hold='air'
 clearBalls();local part=F.part(r.Position+v(0,4,0),'Basketball');part.Owner=nil;F.balls={part};F.world.DescendantAdded:Fire(part)
 flight={part=part,t=0,from=part.Position,made=made,k=k,pts=(fd(r.Position,rim)>=50) and 3 or 2}
 log(k..' jumper '..string.format('%.0f',w.dist)..' gap '..string.format('%.1f',gap)..(made and ' MAKE' or ' miss'))
end
local function startDunk(k)
 dunk[k]={t=0,from=rootOf(k).Position};M[k].dA=M[k].dA+1
 if k=='us' then ourAttr.Action='Dunking' else theirAttr.Action='Dunking' end
end
local function finishDunk(k)
 local r=rootOf(k);local opp=rootOf(other(k));dunk[k]=nil
 if k=='us' then ourAttr.Action=nil else theirAttr.Action=nil end
 local gap=fd(opp.Position,rim)
 local p=0.93
 if gap<4 then p=air[other(k)]>0 and 0.45 or 0.75 end
 if rnd()<p then
  M[k].dMade=M[k].dMade+1;M[k].pts=M[k].pts+2;M[k].twos=M[k].twos+1;log(k..' DUNK')
  changePossession(other(k))
 else
  M[k].dBlocked=M[k].dBlocked+1;log(k..' dunk blocked')
  local a=rnd()*math.pi-math.pi/2;placeLoose(rim+v(math.cos(a),0,math.sin(a))*(4+rnd()*6))
  flight={rebound=true,k=k}
 end
end
-- ---------------------------------------------------------------- AI
local function aiDefend()
 hist[#hist+1]=root.Position
 if now<checkUntil or stun>0 then er.AssemblyLinearVelocity=v();return end
 local seen=hist[math.max(1,#hist-math.floor(P.delay*60))]
 local toRim=flat(rim-seen);local m=math.max(.01,toRim.Magnitude)
 local want=seen+toRim/m*math.min(P.spacing,m)
 local d=flat(want-er.Position);local dm=d.Magnitude
 local step=math.min(dm,P.speed*dt)
 if dm>.01 then er.Position=er.Position+d/dm*step;er.AssemblyLinearVelocity=d/dm*P.speed else er.AssemblyLinearVelocity=v() end
 if (wind.us or dunk.us) and fd(er.Position,root.Position)<8 and air.them<=0 then
  local w=wind.us or dunk.us;if w.t>=P.delay then air.them=0.6 end
 end
end
local function aiMoveTo(p,speed)
 local d=flat(p-er.Position);local dm=d.Magnitude
 local step=math.min(dm,(speed or P.speed)*dt)
 if dm>.05 then er.Position=er.Position+d/dm*step;er.AssemblyLinearVelocity=d/dm*(speed or P.speed) else er.AssemblyLinearVelocity=v() end
 return dm
end
local function aiOffense()
 if now<checkUntil or wind.them or dunk.them then er.AssemblyLinearVelocity=v();return end
 local held=now-shotStart
 local gap=fd(er.Position,root.Position)
 local between=segd(root.Position,er.Position,rim)<4 and fd(root.Position,rim)<fd(er.Position,rim)
 if aiPlan.drive then
  aiMoveTo(rim)
  if fd(er.Position,rim)<=8 then startDunk('them') end
  return
 end
 local dm=aiMoveTo(aiPlan.spot)
 if now>=aiPlan.next then
  aiPlan.next=now+0.25
  if fd(er.Position,rim)<=72 and (gap>=P.shootGap or held>P.patience) and dm<3 then
   wind.them={t=0,len=0.4,dist=fd(goal.Position,er.Position)};theirAttr.Action='Shooting';M.them.jA=M.them.jA+1
  elseif not between and fd(er.Position,rim)<75 and rnd()<P.driveBias then aiPlan.drive=true
  elseif dm<3 and rnd()<0.35 then
   local side=flat(aiPlan.spot-rim);local lat=v(-side.Z,0,side.X).Unit
   local np=aiPlan.spot+lat*((rnd()<0.5) and -12 or 12);np=rim+flat(np-rim).Unit*62;aiPlan.spot=np
  elseif rnd()<0.08 then aiPlan.drive=true end
 end
end
local function aiChaseLoose()
 if not loose then return end
 if now-looseAt<P.delay then return end
 aiMoveTo(loose.Position)
end
-- ---------------------------------------------------------------- loop
newPossession('us')
e:SetAutoPlay(true)
local total=POSS*2
local frames=0
while M.us.poss+M.them.poss<=total and frames<60*60*30 do
 frames=frames+1;now=now+dt
 if pending and now>=pending.at then local to=pending.to;pending=nil;newPossession(to) end
 -- our inputs dispatched by Ultimate last frame
 while keyIndex<=#F.keys do
  local k=F.keys[keyIndex];keyIndex=keyIndex+1
  if k[1] and hold=='us' and not pending and not wind.us and not dunk.us then
   if k[2]=='T' then
    if fd(root.Position,rim)<=12 and air.us<=0 then startDunk('us') end
   elseif k[2]=='F' or k[2]=='G' or k[2]=='R' or k[2]=='V' or k[2]=='C' or k[2]=='B' or k[2]=='H' then
    protect=(k[2]=='R') and 0.6 or 0.4
    if fd(er.Position,root.Position)<7 and rnd()<P.breakChance then stun=0.4 end
   end
  end
 end
 if oh.Jump then oh.Jump=false;if air.us<=0 then air.us=0.6 end end
 oh.FloorMaterial=air.us>0 and 'Air' or 'Ground'
 eh.FloorMaterial=air.them>0 and 'Air' or 'Ground'
 -- AI
 if pending then er.AssemblyLinearVelocity=v()
 elseif hold=='us' then aiDefend()
 elseif hold=='them' then aiOffense()
 elseif hold=='loose' then aiChaseLoose() end
 -- dunk motion
 for _,k in ipairs({'us','them'})do local d=dunk[k];if d then
  d.t=d.t+dt;local r=rootOf(k);r.Position=d.from+(v(rim.X,r.Position.Y,rim.Z)+flat(d.from-rim).Unit*1.5-d.from)*math.min(1,d.t/0.5)
  if d.t>=0.5 then finishDunk(k) end end end
 local freeze=wind.us and wind.us.at
 F.step(e,dt)
 if freeze then root.Position=freeze;root.AssemblyLinearVelocity=v() end
 -- Body collision: players cannot overlap (2.5 studs between roots).
 do local d=flat(root.Position-er.Position);local m=d.Magnitude
  if m<2.5 and not dunk.us and not dunk.them then
   local n=m>0.01 and d/m or v(1,0,0)
   if freeze then er.Position=root.Position-n*2.5 else root.Position=er.Position+n*2.5 end
  end end
 if dunk.us then oh.point=nil end
 -- windups and strips
 for _,k in ipairs({'us','them'})do local w=wind[k];if w then
  w.t=w.t+dt
  local opp=rootOf(other(k));local gap=fd(opp.Position,rootOf(k).Position)
  local reach=(k=='us') and P.stripReach or 4.5
  if gap<reach and rnd()<((k=='us') and P.strip or 1.2)*dt then
   wind[k]=nil;if k=='us' then ourAttr.Action=nil else theirAttr.Action=nil end
   M[k].stripped=M[k].stripped+1;log(k..' stripped during shot (gap '..string.format('%.1f',gap)..')')
   changePossession(other(k),true)
  elseif w.t>=w.len then release(k) end
 end end
 -- dribble steals
 if pending then
 elseif hold=='us' and not wind.us and not dunk.us then
  local gap=fd(er.Position,root.Position)
  if gap<P.stealReach and rnd()<P.steal*(protect>0 and 0.25 or 1)*dt then M.us.stolen=M.us.stolen+1;log('us stolen (gap '..string.format('%.1f',gap)..')');changePossession('them',true) end
 elseif hold=='them' and not wind.them and not dunk.them then
  local gap=fd(er.Position,root.Position)
  if gap<4.0 and rnd()<0.5*dt then M.them.stolen=M.them.stolen+1;log('them stolen');changePossession('us',true) end
 end
 -- flight
 if flight and flight.part then
  flight.t=flight.t+dt;local f=flight
  f.part.Position=f.from+(goal.Position-f.from)*math.min(1,f.t/0.9)
  if f.t>=0.9 then
   if f.made then
    M[f.k].jMade=M[f.k].jMade+1;M[f.k].pts=M[f.k].pts+f.pts
    if f.pts==3 then M[f.k].threes=M[f.k].threes+1 else M[f.k].twos=M[f.k].twos+1 end
    changePossession(other(f.k))
   else
    local a=rnd()*math.pi-math.pi/2;local k=f.k
    placeLoose(rim+v(math.cos(a),0,math.sin(a))*(5+rnd()*9));flight={rebound=true,k=k}
   end
  end
 end
 -- loose ball pickups
 if hold=='loose' and loose then
  local du,dt2=fd(root.Position,loose.Position),fd(er.Position,loose.Position)
  local shooter=flight and flight.k
  local winner
  if du<=3 then winner='us' elseif dt2<=P.pick and now-looseAt>=0.1 then winner='them' end
  if winner then
   if dt2<=P.pick and dt2>3 and winner=='them' then log('them pickup from '..string.format('%.1f',dt2)) end
   if shooter==winner then M[winner].oreb=M[winner].oreb+1;setHold(winner);shotStart=now;flight=nil
   else M[winner].dreb=M[winner].dreb+1;if shooter then M[shooter].looseLost=M[shooter].looseLost+1 end;changePossession(winner,true) end
  elseif now-looseAt>6 then changePossession(other(offense)) end
 end
 -- shot clock
 if not pending and (hold=='us' or hold=='them') and now-shotStart>24 and not wind[hold] and not dunk[hold] then
  M[hold].clock=M[hold].clock+1;log(hold..' shot clock');changePossession(other(hold))
 end
 if DEBUG and (frames%15==0 or (hold=="loose" and frames%3==0)) then log(string.format('[%s/%s] st=%s %s | rim %.0f gap %.1f %s',hold,offense,tostring(e.State),tostring(e.AutoPlayStatus or e.DefenseIntent),fd(root.Position,rim),fd(root.Position,er.Position),loose and string.format('loose %.1f/%.1f',fd(root.Position,loose.Position),fd(er.Position,loose.Position)) or '')) end
 air.us=math.max(0,air.us-dt);air.them=math.max(0,air.them-dt);stun=math.max(0,stun-dt);protect=math.max(0,protect-dt)
end
local level=e.PickupLevel and e:PickupLevel() or 'n/a'
local ev=e.PickupEvidence and #e.PickupEvidence.Events or -1
local samples=e.PickupMarks and e.PickupMarks.Samples or {}
local function obj(t)local r={};for k,x in pairs(t)do r[#r+1]=string.format('"%s":%s',k,type(x)=='number' and string.format('%g',x) or ('"'..tostring(x)..'"')) end;return '{'..table.concat(r,',')..'}' end
e:SetAutoPlay(false)
return '{"us":'..obj(M.us)..',"them":'..obj(M.them)..',"seconds":'..string.format('%.1f',now)..
 ',"level":"'..tostring(level)..'","evidence":'..ev..',"rimOnly":'..tostring(e.AdaptiveRimOnly==true)..',"notices":'..#notes..
 ',"normal":'..(e.PickupEvidence and e.PickupEvidence.Normal or -1)..',"rejected":'..obj(e.PickupEvidence and e.PickupEvidence.Rejected or {})..',"decision":"'..tostring(e.PickupEvidence and e.PickupEvidence.LastDecision)..'"'..',"samples":'..obj(samples)..',"log":['..(function()local r={};for i,x in ipairs(events)do r[i]=string.format('%q',x) end;return table.concat(r,',')end)()..']}'
