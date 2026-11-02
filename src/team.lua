-- Pure recorded-team orchestration. No Rukia-route claims or native calls.
return function(C,cfg,log)
    local T={armed=false,state='IDLE',reason='Team Auto OFF',pending=nil,
        placements=0,upgrades=0,wins=0,losses=0,runs=0,reportDue=false}
    local function role(e)
        return table.find({'combat','farm','buff'},e.role) and e.role or 'unknown'
    end
    local function matches(s,p)
        local out,used={},{}
        for i,e in ipairs(p.entries) do
            local found
            for _,u in ipairs(s.units or {}) do
                if u.key and u.uuid==e.uuid and u.id==e.id and C.distance(u.pos,e.pos)<=3 then
                    if found and found.key~=u.key then return nil,'Multiple towers match recorded target '..i end
                    found=u
                end
            end
            if found then
                if used[found.key] then return nil,'One tower matches multiple recorded targets' end
                used[found.key]=true;out[i]=found
            end
        end
        return out
    end
    function T:coverage(s,p)
        local count,total,missing=0,0,{}
        for _,u in ipairs(s.roster or {}) do
            total+=1;local found=false
            for i,e in ipairs(type(p)=='table' and type(p.entries)=='table' and p.entries or {}) do
                if i>24 then break end
                if type(e)=='table' and e.uuid==u.uuid and e.id==u.id then found=true;break end
            end
            if found then count+=1 else missing[#missing+1]='slot '..tostring(u.slot)..' '..u.id end
        end
        return count,total,missing
    end
    function T:readiness(s,p)
        local b=C.profileReadiness(s,p,cfg)
        if not s.modeVerified or s.mode~='Story' then b[#b+1]='Team Auto currently supports observed Story only' end
        if type(p)~='table' or p.kind~='team-v1' then b[#b+1]='Record a team profile first' end
        local covered,total,missing=self:coverage(s,p)
        if s.rosterComplete~=true then b[#b+1]='Declared equipped-slot data is incomplete or ambiguous' end
        if total==0 or covered~=total then b[#b+1]='Record every equipped slot: '..table.concat(missing,', ') end
        for _,u in ipairs(s.roster or {}) do
            if not C.finite(u.cost) or u.cost<=0 then b[#b+1]='Current deployment price unknown: '..u.id end
        end
        for _,u in ipairs(s.units or {}) do
            if type(p)=='table' and type(p.entries)=='table' then
                for _,e in ipairs(p.entries) do
                    if type(e)=='table' and u.uuid==e.uuid and u.id==e.id and C.distance(u.pos,u.pos)~=0 then
                        b[#b+1]='Live recorded tower position unavailable';break
                    end
                end
            end
        end
        if not C.finite(cfg.reserve) or cfg.reserve<0 or not C.finite(cfg.maxSeconds) or cfg.maxSeconds<30
            or not C.finite(cfg.maxRuns) or cfg.maxRuns<1 then b[#b+1]='Invalid session budget/limits' end
        if type(p)=='table' and type(p.entries)=='table' then
            for i,e in ipairs(p.entries) do
                if i>24 then break end
                if type(e)=='table' then
                    for j=1,i-1 do
                        local other=p.entries[j]
                        if type(other)=='table' and other.uuid==e.uuid and other.id==e.id and C.distance(other.pos,e.pos)<=3 then
                            b[#b+1]='Recorded copies too close for unique readback';break
                        end
                    end
                end
            end
            if #b==0 then local _,why=matches(s,p);if why then b[#b+1]=why end end
        end
        return b
    end
    function T:stop(reason,state)
        if self.pending then self.uncertainRun=self.run end
        local active=self.armed or self.pending~=nil
        self.armed=false;self.pending=nil;self.state=state or 'BLOCKED';self.reason=reason
        if active then self.reportDue=true end
        log:add('TEAM '..self.state,reason)
    end
    function T:reject(reason) self:stop('Request rejected/unconfirmed: '..tostring(reason)) end
    function T:arm(s,p)
        if self.uncertainRun==s.run then self:stop('Prior action unconfirmed; enter a fresh match');return false end
        local b=self:readiness(s,p)
        if #b>0 then self:stop(table.concat(b,'; '));return false end
        self.armed=true;self.state='RUNNING';self.reason='Supervised recorded Story team'
        self.run=s.run;self.startedAt=s.now;self.progressAt=s.now;self.lastWave=s.wave
        self.lastAction=-math.huge;self.pending=nil;self.countedRun=nil;self.runs=0;self.dataWaitAt=nil;self.reportDue=false
        log:add('TEAM ARM','Recorded Story team; no premium actions');return true
    end
    function T:tick(s,p)
        if not self.armed then return nil end
        if s.now-self.startedAt>=cfg.maxSeconds then self:stop('Team session time limit');return nil end
        if self.pending and self.pending.kind=='replay' then
            if s.now-self.pending.at>15 then self:stop('Replay reset/identity timeout');return nil end
            if s.run==self.run then return nil end
            if self.pending.roundToken and self.pending.roundToken==s.roundToken then return nil end
            if not s.inMatch or not s.stageVerified then return nil end
            if not C.contextMatches(p,s) or not s.modeVerified or s.mode~='Story' then self:stop('Replay changed stage/mode');return nil end
            if s.resultVisible then return nil end
            -- A fresh round must clear the recorded towers before new spending.
            for _,u in ipairs(s.units or {}) do
                for _,e in ipairs(p.entries) do if u.uuid==e.uuid and u.id==e.id then return nil end end
            end
            self.pending=nil;self.run=s.run;self.countedRun=nil;self.lastWave=s.wave;self.progressAt=s.now
            self.lastAction=-math.huge;self.state='RUNNING';self.dataWaitAt=nil
        elseif s.run~=self.run then self:stop('Match changed; recheck team before arming');return nil end
        if not s.inMatch or not s.stageVerified or not s.modeVerified or s.mode~='Story' or s.unitsComplete~=true then
            self:stop('Match/observation became unsupported');return nil
        end
        if s.wave~=self.lastWave then self.lastWave=s.wave;self.progressAt=s.now end
        if s.resultVisible then
            if self.countedRun~=s.run then
                self.countedRun=s.run;self.runs+=1
                if s.outcome=='Victory' then self.wins+=1 elseif s.outcome=='Defeat' then self.losses+=1 end
                log:add('TEAM RESULT',tostring(s.outcome)..' | source='..tostring(s.outcomeSource or 'UI'))
            end
            if self.pending then self:stop('Match ended during an unresolved action; replay stopped','RESULT');return nil end
            if s.outcome~='Victory' or not cfg.replay or not cfg.replayFreeConfirmed
                or not C.contextMatches(cfg.replayContext,s) or self.runs>=cfg.maxRuns then
                self:stop('Result: '..tostring(s.outcome)..'; replay stopped','RESULT');return nil
            end
            if s.transportBlocked then return nil end
            self.pending={kind='replay',at=s.now,roundToken=s.roundToken};self.state='REPLAY_WAIT';self.reason='Waiting for a fresh matching round'
            return {kind='replay'}
        end
        if self.pending then
            local q=self.pending
            if s.now-q.at>8 then self:stop(q.kind..' feedback timeout; no retry');return nil end
            local found,ambiguous
            if q.kind=='place' then found,ambiguous=C.placementVerified(q,s.units)
            else
                for _,u in ipairs(s.units) do
                    if u.key==q.key and u.uuid==q.uuid and u.id==q.id and C.distance(u.pos,q.pos)<=3 and C.finite(u.level) and u.level>q.level then
                        if u.level~=q.level+1 then self:stop('Unexpected upgrade jump');return nil end
                        found=u;break
                    end
                end
            end
            if ambiguous then self:stop('Ambiguous placement readback');return nil end
            if found then
                if q.kind=='place' then self.placements+=1 else self.upgrades+=1 end
                log:add('TEAM CONFIRMED',q.kind..' '..q.id)
                self.pending=nil;self.lastAction=s.now;self.progressAt=s.now;self.state='RUNNING'
            end
            return nil
        end
        local b=self:readiness(s,p)
        if #b>0 then self:stop(table.concat(b,'; '));return nil end
        if s.now-self.progressAt>180 then self:stop('No wave/action progress for 180 seconds');return nil end
        if not s.started or s.transportBlocked or s.now-self.lastAction<1.5 then return nil end
        local matched,why=matches(s,p)
        if not matched then self:stop(why);return nil end
        local missing,combatExists,farmExists,hasCombat={},false,false,false
        for i,e in ipairs(p.entries) do
            if role(e)=='combat' then hasCombat=true end
            if matched[i] then
                if role(e)=='combat' then combatExists=true elseif role(e)=='farm' then farmExists=true end
            else missing[#missing+1]={entry=e,index=i} end
        end
        if #missing>0 then
            local options={}
            for _,v in ipairs(missing) do
                local e=v.entry
                local allowed=not hasCombat or combatExists or role(e)=='combat' or (not farmExists and role(e)=='farm')
                if allowed and (e.wave or 0)<=s.wave and s.cash-cfg.reserve>=e.cost then options[#options+1]=v end
            end
            table.sort(options,function(a,b)
                local rank={combat=1,farm=2,buff=3,unknown=4}
                if combatExists then rank={farm=1,combat=2,buff=3,unknown=4} end
                local ra,rb=rank[role(a.entry)],rank[role(b.entry)]
                if ra~=rb then return ra<rb end
                if a.entry.cost~=b.entry.cost then return a.entry.cost<b.entry.cost end
                return a.index<b.index
            end)
            local chosen=options[1]
            if not chosen then
                self.state='WAITING';self.reason=not combatExists and farmExists and hasCombat and 'Saving for the first combat unit' or 'Waiting for an affordable recorded placement'
                return nil
            end
            local e=chosen.entry;local before={}
            for _,u in ipairs(s.units) do if u.key then before[u.key]=true end end
            self.pending={kind='place',uuid=e.uuid,id=e.id,pos=table.clone(e.pos),before=before,at=s.now}
            self.state='PLACE_WAIT';self.reason='Placing '..e.id..' | quoted Yen='..e.cost
            return {kind='place',uuid=e.uuid,id=e.id,pos=table.clone(e.pos)}
        end
        if not cfg.upgrade then self.state='HOLDING';self.reason='Recorded team placed; upgrades disabled';return nil end
        local best,bestIndex,unknown=nil,nil,false
        for i,u in pairs(matched) do
            local maximum=C.finite(u.maxLevel) and C.finite(u.level) and u.level>=u.maxLevel
            if not maximum then
                if not C.finite(u.level) or u.level<0 or u.level%1~=0 or not C.finite(u.nextCost) or u.nextCost<=0 then unknown=true
                elseif s.cash-cfg.reserve>=u.nextCost and (not best or u.level<best.level
                    or (u.level==best.level and (u.nextCost<best.nextCost or (u.nextCost==best.nextCost and i<bestIndex)))) then
                    best=u;bestIndex=i
                end
            end
        end
        if best then
            self.dataWaitAt=nil
            self.pending={kind='upgrade',uuid=best.uuid,id=best.id,key=best.key,pos=table.clone(best.pos),level=best.level,at=s.now}
            self.state='UPGRADE_WAIT';self.reason='Upgrading '..best.id..' | quoted Yen='..best.nextCost
            return {kind='upgrade',key=best.key,uuid=best.uuid,id=best.id}
        end
        if unknown then
            self.dataWaitAt=self.dataWaitAt or s.now
            self.reason='Waiting for known upgrade levels/prices'
            if s.now-self.dataWaitAt>15 then self:stop('Upgrade level/price unavailable; not treated as maximum') end
        else self.dataWaitAt=nil;self.reason='Recorded team placed; waiting for funds or the observed result' end
        if self.armed then self.state='HOLDING' end
        return nil
    end
    function T:text(s,p)
        local count,total,missing=self:coverage(s or {},p)
        return 'TEAM AUTO: '..self.state..' | '..self.reason..'\nRecorded slots '..count..' / '..total..
            ' | targets='..tostring(type(p)=='table' and type(p.entries)=='table' and #p.entries or 0)..
            (#missing>0 and '\nMissing: '..table.concat(missing,', ') or '')..
            '\nTeam-confirmed placements='..self.placements..' upgrades='..self.upgrades..
            ' | wins='..self.wins..' losses='..self.losses
    end
    return T
end
