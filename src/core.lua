-- Pure Luau: no Roblox globals, executor introspection, or remote calls.
local C = {}
C.version = '6.0.3'
C.recipe = {status='historical',takedowns=7500,items={SacredTreasure=200,
    StarFruit=12,StarFruitBlue=5,StarFruitRed=3,StarFruitGreen=4,StarFruitEpic=1}}
C.itemOrder = {'SacredTreasure','StarFruit','StarFruitBlue','StarFruitRed','StarFruitGreen','StarFruitEpic'}
C.itemLabels = {SacredTreasure='Sacred Treasure',StarFruit='Star Fruit',StarFruitBlue='Blue',
    StarFruitRed='Red',StarFruitGreen='Green',StarFruitEpic='Rainbow'}
C.defaults = {goal='Acquire',targetTrait='Unique',targetGrade='SSS',reserve=0,maxRuns=1,
    maxSeconds=1200,upgrade=true,replay=false,replayFreeConfirmed=false,protocolConfirmed=false,
    routeConfirmed=false,traitCap=0,statCap=0,inventoryPath='',resourcePath='',cashPath='',
    mode='Dungeon',logDisk=false,selectedUuid=''}
function C.finite(x) return type(x)=='number' and x==x and math.abs(x)<1e12 end
function C.deficit(have,need)
    if not C.finite(have) then return nil end
    return math.max(0,need-have)
end
function C.isRukia(id) return id=='rukia_2' or id=='rukia_2_evo' end
function C.chooseRukia(units,uuid)
    for _,u in ipairs(units or {}) do if C.isRukia(u.id) and u.uuid==uuid then return u end end
    if type(uuid)=='string' and uuid~='' then return nil end
    for _,u in ipairs(units or {}) do if C.isRukia(u.id) and u.statScope=='collection' then return u end end
    for _,u in ipairs(units or {}) do if C.isRukia(u.id) then return u end end
end
local consentKeys={routeConfirmed='routeContext',protocolConfirmed='protocolContext',replayFreeConfirmed='replayContext'}
function C.contextMatches(binding,s)
    return type(binding)=='table' and binding.stage==s.stage and binding.mode==s.mode and binding.placeId==s.placeId
end
function C.bindConsent(cfg,key,s)
    local target=consentKeys[key]
    if target then cfg[target]={stage=s.stage,mode=s.mode,placeId=s.placeId} end
end
local grades={['C-']=1,C=2,['C+']=3,['B-']=4,B=5,['B+']=6,['A-']=7,A=8,['A+']=9,
    ['S-']=10,S=11,['S+']=12,SS=13,SSS=14}
function C.hasTrait(u,target)
    if not u or type(target)~='string' or target=='' then return false end
    if u.trait==target then return true end
    if type(u.traits)=='table' then
        for i=1,4 do if rawget(u.traits,i)==target then return true end end
    end
    return false
end
function C.statsMet(u,target)
    if not u or u.statScope~='collection' or not grades[target] then return false end
    for _,key in ipairs({'damageGrade','spaGrade','rangeGrade'}) do
        if (grades[u[key]] or 0)<grades[target] then return false end
    end
    return C.finite(u.damage) and C.finite(u.spa) and u.spa>0 and C.finite(u.range)
end
function C.spendAllowed(p)
    if not p.enabled then return false,'Disabled' end
    if not p.verified or not p.fresh then return false,'Unverified or stale inventory/protocol' end
    if type(p.target)~='string' or p.target=='' then return false,'Target unknown' end
    if p.current==nil then return false,'Current result unknown' end
    if C.hasTrait({trait=p.current,traits=p.currentTraits},p.target) then return false,'Target protected' end
    for _,k in ipairs({'cap','spent','cost','balance'}) do
        if not C.finite(p[k]) then return false,'Unknown resource/cost' end
    end
    if p.cost<=0 or p.spent<0 or p.cap<0 or p.balance<p.cost or p.spent+p.cost>p.cap then
        return false,'Budget exhausted'
    end
    return true
end
function C.sanitize(raw)
    local cfg={}
    for k,v in pairs(C.defaults) do cfg[k]=v end
    if type(raw)~='table' then return cfg end
    for k,v in pairs(cfg) do
        if type(raw[k])==type(v) then cfg[k]=raw[k] end
    end
    for k,limit in pairs({reserve=1000000,maxRuns=100,maxSeconds=7200,traitCap=1000,statCap=1000}) do
        if not C.finite(cfg[k]) then cfg[k]=C.defaults[k] end
        cfg[k]=math.clamp(math.floor(cfg[k]),0,limit)
    end
    cfg.maxRuns=math.max(1,cfg.maxRuns);cfg.maxSeconds=math.max(30,cfg.maxSeconds)
    if not table.find({'Acquire','Trait','Stats','Evolution','Build'},cfg.goal) then cfg.goal='Acquire' end
    if not grades[cfg.targetGrade] then cfg.targetGrade='SSS' end
    if not table.find({'Unique','Divine','Celestial','Reaper','Godspeed','Sniper'},cfg.targetTrait) then cfg.targetTrait='Unique' end
    for _,key in ipairs({'inventoryPath','resourcePath','cashPath'}) do cfg[key]=cfg[key]:sub(1,200) end
    if not table.find({'Dungeon','Story','Infinite','Challenge','Portal','Raid','Event','Legend'},cfg.mode) then cfg.mode='Dungeon' end
    -- Spending/arming/protocol confirmations are session-specific and never restored.
    cfg.routeConfirmed=false;cfg.protocolConfirmed=false;cfg.replayFreeConfirmed=false
    return cfg
end
function C.outcome(texts)
    local win,loss=false,false
    for _,s in ipairs(texts or {}) do
        s=tostring(s):lower():gsub('<.->',''):gsub('^%s+',''):gsub('%s+$','')
        if s=='victory' or s=='victory!' then win=true end
        if s=='defeat' or s=='defeat!' or s=='failed' then loss=true end
    end
    if win==loss then return 'unknown' end
    return win and 'Victory' or 'Defeat'
end
function C.distance(a,b)
    if type(a)~='table' or type(b)~='table' then return math.huge end
    for i=1,3 do if not C.finite(a[i]) or not C.finite(b[i]) then return math.huge end end
    return math.sqrt((a[1]-b[1])^2+(a[2]-b[2])^2+(a[3]-b[3])^2)
end
function C.placementVerified(p,units)
    for _,u in ipairs(units or {}) do
        if u.key and not p.before[u.key] and u.uuid==p.uuid and u.id==p.id
            and C.distance(u.pos,p.pos)<=3 then return u end
    end
    return nil
end
function C.readiness(s,p,cfg)
    local blockers={}
    local function need(ok,msg) if not ok then blockers[#blockers+1]=msg end end
    need(s.inMatch,'Enter a match manually')
    need(s.unitsComplete==true,'Tower observation is incomplete; cannot validate placements safely')
    need(s.stageVerified==true,'Stage identity not observed')
    need(cfg.routeConfirmed==true and C.contextMatches(cfg.routeContext,s),'Confirm this stage actually advances the Rukia objective')
    need(cfg.protocolConfirmed==true and C.contextMatches(cfg.protocolContext,s),'Placement protocol needs confirmation for this stage')
    need(s.transportBlocked~=true,'An earlier remote request is still outstanding')
    need(C.finite(s.rosterAt) and s.now-s.rosterAt<=15,'Fresh equipped UUIDs unavailable')
    need(C.finite(s.cash),'Live match Yen unknown')
    if type(p)~='table' or type(p.entries)~='table' then
        blockers[#blockers+1]='Record current own placements first';return blockers
    end
    need(p.stage==s.stage and p.placeId==s.placeId and p.mode==s.mode,'Recorded profile does not match this stage/mode')
    need(p.source=='user-recorded','Uncertified old macro; record again for this patch')
    need(#p.entries>0 and #p.entries<=24,'Profile must have 1–24 placements')
    local seen={}
    for _,u in ipairs(s.roster or {}) do seen[u.uuid]=u end
    for i,e in ipairs(p.entries) do
        if i>24 then break end
        if type(e)~='table' then blockers[#blockers+1]='Malformed recorded placement';break end
        local u=seen[e.uuid]
        need(u~=nil and u.id==e.id,'Profile slot '..i..' identity not currently equipped')
        need(C.finite(e.cost) and e.cost>0,'Profile slot '..i..' deployment cost unknown')
        need(C.distance(e.pos,e.pos)==0,'Profile slot '..i..' position invalid')
    end
    return blockers
end
function C.logger(cap)
    local l={lines={},dropped=0,cap=math.clamp(cap or 240,10,300),last='',repeatCount=0}
    function l:add(kind,detail)
        local line=tostring(kind):sub(1,40)..' | '..tostring(detail):gsub('[\r\n]',' '):sub(1,450)
        if line==self.last then self.repeatCount+=1;return end
        self.last=line;self.repeatCount=0
        self.lines[#self.lines+1]=line
        if #self.lines>self.cap then table.remove(self.lines,1);self.dropped+=1 end
    end
    function l:text() return 'Dropped old log lines='..self.dropped..'\n'..table.concat(self.lines,'\n') end
    return l
end
function C.recorder(log)
    local r={wins=0,losses=0,units={},resources={},lastWave=-1}
    function r:observe(s)
        if self.run~=s.run then
            self.run=s.run;self.counted=false;self.outcome=nil;self.units={};self.lastWave=-1
            log:add(s.inMatch and 'RUN OBSERVED' or 'LOBBY',s.run..' | result unconfirmed')
        end
        if s.wave~=self.lastWave then
            self.lastWave=s.wave
            if s.wave==1 or s.wave%5==0 then log:add('WAVE',s.wave..' | own='..#s.units..' yen='..tostring(s.cash)) end
        end
        if s.resultVisible and self.outcome~=s.outcome then
            self.outcome=s.outcome;log:add('RESULT OBSERVED',s.outcome)
            if not self.counted and (s.outcome=='Victory' or s.outcome=='Defeat') then
                self.counted=true
                if s.outcome=='Victory' then self.wins+=1 else self.losses+=1 end
            end
            log:add('RESULT LABELS',table.concat(s.resultTexts or {},' | '):sub(1,350))
        end
        local nextUnits={}
        for _,u in ipairs(s.units) do
            local prev=self.units[u.key]
            if not prev then log:add('OWN TOWER OBSERVED',u.id..' | upgrade='..tostring(u.level))
            elseif C.finite(u.level) and C.finite(prev.level) and u.level>prev.level then
                log:add('UPGRADE OBSERVED',u.id..' | '..prev.level..' -> '..u.level)
            end
            nextUnits[u.key]={level=u.level}
        end
        self.units=nextUnits
        for k,v in pairs(s.resources or {}) do
            local old=self.resources[k]
            if C.finite(old) and C.finite(v) and old~=v then
                log:add('RESOURCE DELTA',k..' '..old..' -> '..v..' (source/attribution unconfirmed)')
            end
        end
        self.resources=table.clone(s.resources or {})
    end
    return r
end
function C.goalMet(s,cfg)
    local u=C.chooseRukia(s.owned,cfg.selectedUuid)
    if not u or u.statScope~='collection' or not s.ownedAt or s.now-s.ownedAt>15 then return false end
    if cfg.goal=='Acquire' then return true end
    if cfg.goal=='Trait' then return C.hasTrait(u,cfg.targetTrait) end
    if cfg.goal=='Stats' then return C.statsMet(u,cfg.targetGrade) end
    if cfg.goal=='Evolution' then return u.id=='rukia_2_evo' end
    return u.id=='rukia_2_evo' and C.hasTrait(u,cfg.targetTrait) and C.statsMet(u,cfg.targetGrade)
end
function C.plan(s,cfg)
    local u=C.chooseRukia(s.owned,cfg.selectedUuid)
    if not u or u.statScope~='collection' then return 'Acquire Snow Reaper (War)',
        'Historical route: Dungeon final chest. Confirm Update 21 reward table before spending a key. Pity/rate unknown.' end
    if not C.hasTrait(u,cfg.targetTrait) then return 'Trait target: '..cfg.targetTrait,
        'Current='..tostring(u.trait or 'unknown')..'. Reroll protocol unavailable; manual rolls only, within your budget.' end
    if not C.statsMet(u,cfg.targetGrade) then return 'Stat target: '..cfg.targetGrade,
        'Inspect raw DMG/SPA/RNG and grades. Historical: build worthiness before rerolling; single-stat cubes preserve other stats.' end
    if u.id~='rukia_2_evo' then return 'Evolution materials',
        'Historical recipe below; verify in current Evolve menu. Evolution stays manual.' end
    return 'Build target met','Verified fields match the selected targets; absolute stat maximum and current patch meta remain unverified.'
end
function C.engine(cfg,log)
    local e={cfg=cfg,log=log or C.logger(),armed=false,state='IDLE',reason='Full Auto OFF',
        wins=0,losses=0,placements=0,upgrades=0,runs=0,pending=nil,index=1,resultRun=nil}
    function e:stop(reason,state)
        self.armed=false;self.state=state or 'BLOCKED';self.reason=reason;self.pending=nil
        self.log:add(self.state,reason)
    end
    function e:arm(s,p)
        local b=C.readiness(s,p,self.cfg)
        if #b>0 then self:stop(table.concat(b,'; '));return false end
        self.armed=true;self.state='RUNNING';self.reason='Supervised recorded combat'
        self.run=s.run;self.started=s.now;self.progressAt=s.now;self.lastWave=s.wave
        self.index=1;self.runs=0;self.pending=nil;self.resultRun=nil;self.lastAction=-math.huge
        self.log:add('ARM','Experimental recorded combat; no premium actions');return true
    end
    function e:reject(reason) self:stop('Action rejected: '..tostring(reason)) end
    function e:tick(s,p)
        if not self.armed then return nil end
        if C.goalMet(s,self.cfg) then self:stop('Selected progression goal reached','GOAL_MET');return nil end
        if s.now-self.started>=self.cfg.maxSeconds then self:stop('Session time limit');return nil end
        if s.run~=self.run then
            if self.pending and self.pending.kind=='replay' then
                if s.now-self.pending.at>15 then self:stop('Replay stage identity timeout');return nil end
                if not s.inMatch or not s.stageVerified then return nil end
                if p.stage~=s.stage or p.mode~=s.mode or p.placeId~=s.placeId then
                    self:stop('Replay changed stage/mode');return nil
                end
                self.pending=nil;self.run=s.run;self.index=1;self.resultRun=nil
                self.progressAt=s.now;self.lastWave=s.wave;self.state='RUNNING'
            else self:stop('Match changed; recheck stage and identities');return nil end
        end
        if not s.inMatch then self:stop('Match left; result unconfirmed');return nil end
        if s.unitsComplete~=true then self:stop('Tower observation became incomplete');return nil end
        if s.wave~=self.lastWave then self.lastWave=s.wave;self.progressAt=s.now end
        if s.resultVisible then
            if self.pending and self.pending.kind=='replay' then
                if s.now-self.pending.at>15 then self:stop('Replay did not transition within timeout') end
                return nil
            end
            if self.resultRun~=s.run then
                self.resultRun=s.run
                if s.outcome=='Victory' then self.wins+=1
                elseif s.outcome=='Defeat' then self.losses+=1 end
                self.log:add('RESULT',tostring(s.outcome));self.runs+=1
            end
            local free=s.modeVerified==true and table.find({'Story','Infinite','Challenge'},s.mode)~=nil
            if s.outcome~='Victory' or not self.cfg.replay or not self.cfg.replayFreeConfirmed
                or not C.contextMatches(self.cfg.replayContext,s)
                or not free or self.runs>=self.cfg.maxRuns then
                self:stop('Result: '..tostring(s.outcome)..'; replay stopped','RESULT');return nil
            end
            self.pending={kind='replay',at=s.now};self.state='REPLAY_WAIT'
            return {kind='replay'}
        end
        if self.pending then
            local q=self.pending
            local confirmed
            if q.kind=='place' then confirmed=C.placementVerified(q,s.units)
            elseif q.kind=='upgrade' then
                for _,u in ipairs(s.units) do
                    if u.key==q.key and u.uuid==q.uuid and u.id==q.id
                        and C.finite(u.level) and u.level>q.level then confirmed=u;break end
                end
            end
            if confirmed then
                self.log:add('CONFIRMED',q.kind..' '..q.id)
                if q.kind=='place' then self.index+=1;self.placements+=1 else self.upgrades+=1 end
                self.pending=nil;self.lastAction=s.now;self.progressAt=s.now
            elseif s.now-q.at>8 then self:stop(q.kind..' feedback timeout; no blind retry') end
            return nil
        end
        local b=C.readiness(s,p,self.cfg)
        if #b>0 then self:stop(table.concat(b,'; '));return nil end
        if s.now-self.progressAt>180 then self:stop('No wave/action progress for 180 seconds');return nil end
        if not s.started or s.now-self.lastAction<1.5 or s.transportBlocked then return nil end
        local entry=p.entries[self.index]
        if entry then
            -- Existing exact placements are skipped, never reported as actions we performed.
            for _,u in ipairs(s.units) do
                if u.uuid==entry.uuid and u.id==entry.id and C.distance(u.pos,entry.pos)<=3 then
                    self.index+=1;return nil
                end
            end
            if (entry.wave or 0)>s.wave or s.cash-self.cfg.reserve<entry.cost then return nil end
            local before={};for _,u in ipairs(s.units) do before[u.key]=true end
            self.pending={kind='place',at=s.now,uuid=entry.uuid,id=entry.id,pos=entry.pos,before=before}
            return {kind='place',uuid=entry.uuid,id=entry.id,pos=entry.pos}
        end
        if self.cfg.upgrade then
            local best,score
            for _,u in ipairs(s.units) do
                local belongs=false
                for _,v in ipairs(p.entries) do
                    if v.uuid==u.uuid and v.id==u.id and C.distance(v.pos,u.pos)<=3 then belongs=true;break end
                end
                if belongs and C.finite(u.level) and C.finite(u.nextCost) and u.nextCost>0
                    and s.cash-self.cfg.reserve>=u.nextCost then
                    local value=(C.finite(u.damage) and C.finite(u.spa) and u.spa>0) and u.damage/u.spa or 1
                    local rank=value/u.nextCost
                    if not score or rank>score then best=u;score=rank end
                end
            end
            if best then
                self.pending={kind='upgrade',at=s.now,key=best.key,uuid=best.uuid,id=best.id,level=best.level}
                return {kind='upgrade',key=best.key}
            end
        end
        return nil
    end
    return e
end
return C
