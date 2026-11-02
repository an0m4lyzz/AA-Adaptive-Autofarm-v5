-- Explicit single-action Story tests. No route claim, replay or emitted tick actions.
return function(C,cfg,log)
    local T={state='IDLE',reason='No supervised action attempted',pending=nil,placements=0,upgrades=0,
        attemptRun=nil,attempted={}}
    function T:quote(kind,s,p)
        if kind~='place' and kind~='upgrade' then return nil,'Unsupported test action' end
        if self.pending or s.transportBlocked then return nil,'A request/test is still pending' end
        if self.state=='UNCONFIRMED' and self.attemptRun==s.run then
            return nil,'Previous test unconfirmed; inspect the report and enter a fresh match'
        end
        if self.attemptRun==s.run and self.attempted[kind] then
            return nil,'One '..kind..' test already attempted this run; inspect the report'
        end
        if not s.inMatch or not s.stageVerified or not s.modeVerified or s.mode~='Story' then
            return nil,'An observed free Story match is required'
        end
        if not s.started or s.resultVisible then return nil,'Start waves in an unfinished match first' end
        if s.unitsComplete~=true then return nil,'Tower observation incomplete' end
        if not C.finite(s.now) or not C.finite(s.rosterAt) or s.now-s.rosterAt<0 or s.now-s.rosterAt>15 then
            return nil,'Fresh equipped records unavailable'
        end
        if type(p)~='table' or type(p.entries)~='table' or #p.entries~=1 or p.source~='user-recorded' then
            return nil,'Record exactly one own tower first'
        end
        if not C.contextMatches(p,s) then return nil,'Recorded stage/mode/place differs' end
        if p.costScale~=nil and (not C.finite(s.costScale) or p.costScale~=s.costScale) then
            return nil,'Cost modifier changed or became unknown; record again'
        end
        local e=p.entries[1]
        if type(e)~='table' or type(e.uuid)~='string' or e.uuid=='' or type(e.id)~='string' or e.id==''
            or C.distance(e.pos,e.pos)~=0 or not C.finite(e.cost) or e.cost<=0 then
            return nil,'Recorded position or deployment price invalid'
        end
        local equipped
        for _,u in ipairs(s.roster or {}) do if u.uuid==e.uuid and u.id==e.id then equipped=u;break end end
        if not equipped then return nil,'Recorded unit is no longer equipped' end
        if p.testSlot~=nil and (p.testSlot~=cfg.trialSlot or equipped.slot~=p.testSlot) then
            return nil,'Selected test slot changed; record its current tower again'
        end
        if C.finite(equipped.cost) and equipped.cost~=e.cost then return nil,'Deployment price changed; record again' end
        local q={kind=kind,uuid=e.uuid,id=e.id,pos={e.pos[1],e.pos[2],e.pos[3]},cost=e.cost,
            slot=equipped.slot,run=s.run,stage=s.stage,mode=s.mode,placeId=s.placeId,at=s.now}
        if kind=='place' then
            for _,u in ipairs(s.units or {}) do
                if u.uuid==e.uuid and u.id==e.id then
                    return nil,'Target already placed; save its test profile, then use a fresh copy of this stage'
                end
                if C.distance(u.pos,e.pos)<=3 then return nil,'Another tower occupies the recorded position' end
            end
        else
            local found
            for _,u in ipairs(s.units or {}) do
                if u.uuid==e.uuid and u.id==e.id and C.distance(u.pos,e.pos)<=3 then
                    if found then return nil,'Recorded upgrade target is ambiguous' end
                    found=u
                end
            end
            if not found or not found.key then return nil,'Recorded tower is not present' end
            if not C.finite(found.level) or found.level<0 or found.level%1~=0
                or not C.finite(found.nextCost) or found.nextCost<=0 then
                return nil,'Current upgrade level or next price unknown'
            end
            q.key=found.key;q.level=found.level;q.cost=found.nextCost
        end
        local reserve=C.finite(cfg.reserve) and math.max(0,cfg.reserve) or 0
        if not C.finite(s.cash) or s.cash-reserve<q.cost then
            return nil,'Need '..q.cost..' match Yen + '..reserve..' reserve; have '..tostring(s.cash or '?')
        end
        return q
    end
    function T:begin(kind,s,p,displayed)
        local q,why=self:quote(kind,s,p)
        if not q then return nil,why end
        if type(displayed)~='table' or not C.finite(displayed.at) or s.now-displayed.at<0 or s.now-displayed.at>5
            or displayed.kind~=q.kind or displayed.uuid~=q.uuid or displayed.id~=q.id or displayed.cost~=q.cost
            or displayed.run~=q.run or not C.contextMatches(displayed,s) or displayed.key~=q.key
            or displayed.slot~=q.slot or displayed.level~=q.level or C.distance(displayed.pos,q.pos)>0.01 then
            return nil,'Displayed price/target changed or expired; review the refreshed button'
        end
        if self.attemptRun~=s.run then self.attemptRun=s.run;self.attempted={} end
        self.attempted[kind]=true
        q.before={};for _,u in ipairs(s.units or {}) do if u.key then q.before[u.key]=true end end
        q.cashBefore=s.cash
        self.pending=q;self.state='WAITING';self.reason='One '..kind..' request; awaiting exact tower readback'
        self.last={kind=kind,id=q.id,cost=q.cost,cashBefore=s.cash}
        log:add('TRIAL ATTEMPT',kind..' '..q.id..' | quoted match Yen='..q.cost..'; no automatic retry')
        return {kind=kind,uuid=q.uuid,id=q.id,pos=table.clone(q.pos),key=q.key}
    end
    local function finish(self,state,reason,s)
        self.pending=nil;self.state=state;self.reason=reason
        if self.last and s then self.last.cashAfter=s.cash end
        log:add('TRIAL '..state,reason)
    end
    function T:cancel(reason)
        if self.pending then finish(self,'UNCONFIRMED',reason or 'Test cancelled; result unconfirmed') end
    end
    function T:tick(s)
        local q=self.pending;if not q then return nil end
        if not C.finite(s.now) or s.now-q.at>8 or s.now<q.at then
            finish(self,'UNCONFIRMED','Feedback deadline exceeded; no automatic retry',s);return nil
        end
        if s.run~=q.run or not s.inMatch or not s.stageVerified or not s.modeVerified or s.mode~='Story'
            or not C.contextMatches(q,s)
            or s.unitsComplete~=true or s.resultVisible then
            finish(self,'UNCONFIRMED','Match/observation changed before confirmation',s);return nil
        end
        if q.kind=='place' then
            local match,ambiguous=C.placementVerified(q,s.units)
            if ambiguous then finish(self,'UNCONFIRMED','Multiple matching new towers; placement is ambiguous',s)
            elseif match then
                self.placements+=1
                finish(self,'OBSERVED','New exact '..q.id..' tower observed at the recorded position after request',s)
            end
        else
            for _,u in ipairs(s.units or {}) do
                if u.key==q.key and u.uuid==q.uuid and u.id==q.id and C.distance(u.pos,q.pos)<=3
                    and C.finite(u.level) and u.level>q.level then
                    if u.level==q.level+1 then
                        self.upgrades+=1
                        finish(self,'OBSERVED','Exact '..q.id..' tower upgrade '..q.level..' → '..u.level..' observed',s)
                    else finish(self,'UNCONFIRMED','Unexpected upgrade jump; result unconfirmed',s) end
                    break
                end
            end
        end
        return nil -- this observer never starts a second action
    end
    function T:text()
        local out='Single-action test: '..self.state..' | '..self.reason..
            '\nObserved trial placements='..self.placements..' | upgrades='..self.upgrades
        if self.last then
            out=out..'\nLast test='..self.last.kind..' '..self.last.id..' | quoted match Yen='..self.last.cost..
                ' | cash before='..tostring(self.last.cashBefore)..' after='..tostring(self.last.cashAfter or '?')..
                ' (balance changes are not attributed costs)'
        end
        return out
    end
    return T
end
