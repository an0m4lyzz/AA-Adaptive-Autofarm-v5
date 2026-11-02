-- Native automatic combat policy. Pure snapshots in; at most one request out.
-- Geometry and transport belong to their adapters. RPC replies are never proof.
return function(C,cfg,log)
    log=log or C.logger()
    local A={armed=false,state='IDLE',reason='Native Auto OFF',pending=nil,
        placements=0,upgrades=0,confirmations=0,runs=0,wins=0,losses=0,reportDue=false,
        targetStatus='Game default target priority'}
    local function cap(u)
        if not C.finite(u.spawnCap) or u.spawnCap<1 or u.spawnCap%1~=0 then return nil end
        return C.hasTrait(u,'Unique') and 1 or math.min(24,u.spawnCap)
    end
    local function acquired(s)
        if cfg.goal~='Acquire' or not C.finite(s.now) or not C.finite(s.ownedAt)
            or s.now<s.ownedAt or s.now-s.ownedAt>15 or type(s.owned)~='table' then return false end
        for _,u in ipairs(s.owned) do
            if type(u)=='table' and C.isRukia(u.id) and u.statScope=='collection'
                and type(u.uuid)=='string' and u.uuid~='' then return true end
        end
        return false
    end
    local function counts(s)
        local out={};for _,u in ipairs(s.roster or {}) do out[u.uuid]=0 end
        for _,v in ipairs(s.units or {}) do
            for _,u in ipairs(s.roster or {}) do
                if v.uuid==u.uuid and v.id==u.id then out[u.uuid]+=1;break end
            end
        end
        return out
    end
    local function spot(s,u)
        local list=type(s.autoSpots)=='table' and s.autoSpots[u.uuid]
        if type(list)~='table' then return nil end
        for i,e in ipairs(list) do
            if i>24 then break end
            local p=type(e)=='table' and e.pos
            if C.distance(p,p)==0 then
                local free=true
                for _,v in ipairs(s.units or {}) do if C.distance(v.pos,p)<=3 then free=false;break end end
                if free then return {p[1],p[2],p[3]} end
            end
        end
        return nil
    end
    function A:readiness(s,pending)
        if type(s)~='table' or type(s.roster)~='table' or type(s.units)~='table' then
            return {'Native snapshot/roster/tower schema unsupported'}
        end
        for _,u in ipairs(s.roster) do
            if type(u)~='table' or type(u.uuid)~='string' or u.uuid=='' or type(u.id)~='string' or u.id=='' then
                return {'Equipped UUID/ID schema unsupported'}
            end
        end
        for _,u in ipairs(s.units) do if type(u)~='table' then return {'Tower snapshot schema unsupported'} end end
        local b={}
        local function need(ok,why) if not ok then b[#b+1]=why end end
        need(s.run~=nil and s.roundToken~=nil,'Observed native round identity unavailable')
        need(s.inMatch==true and s.stageVerified==true,'Observed match/stage unavailable')
        need(s.modeVerified==true and table.find({'Story','Dungeon','Infinite','Challenge','Raid','Legend','Portal'},s.mode)~=nil,
            'Native Auto requires an observed supported mode; Events remain unavailable')
        need(s.externalControllerActive~=true,'External controller active; native mutation blocked')
        need(s.unitsComplete==true,'Own tower observation incomplete')
        need(s.rosterComplete==true,'Every equipped slot must be observed')
        need(C.finite(s.now) and C.finite(s.rosterAt) and s.now>=s.rosterAt and s.now-s.rosterAt<=15,'Fresh equipped UUIDs unavailable')
        need(C.finite(s.cash) and s.cash>=0,'Live match Yen unknown')
        need(C.finite(cfg.reserve) and cfg.reserve>=0 and C.finite(cfg.maxSeconds) and cfg.maxSeconds>=30,'Invalid session budget/limits')
        need(type(s.roster)=='table' and #s.roster>0 and #s.roster<=6,'Equipped roster must contain1–6 slots')
        need(type(s.units)=='table' and #s.units<=24,'Own tower target limit exceeds24')
        if not pending then
            need(s.transportBlocked~=true,'Native transport still outstanding')
            need(s.mutationFence~=true,'Previous mutation lacks exact feedback; enter a fresh round')
        end
        local seen,keys={},{}
        local current=counts(s)
        for _,u in ipairs(s.roster or {}) do
            local identity=type(u.uuid)=='string' and u.uuid~='' and type(u.id)=='string' and u.id~=''
            need(identity and not seen[u.uuid],'Equipped UUID/ID missing or duplicated')
            if identity then seen[u.uuid]=true end
            local limit=cap(u)
            need(limit~=nil,'Known positive integer spawn cap required: '..tostring(u.id))
            need(C.finite(u.cost) and u.cost>0,'Deployment price unknown: '..tostring(u.id))
            if limit and identity then
                need(current[u.uuid]<=limit,'Observed copies exceed equipped cap: '..u.id)
                if not pending and #(s.units or {})<24 and current[u.uuid]<limit then
                    need(spot(s,u)~=nil,'Observed placement spot unavailable: slot '..tostring(u.slot)..' '..u.id)
                end
            end
        end
        for _,u in ipairs(s.units or {}) do
            need(u.key~=nil and not keys[u.key] and C.distance(u.pos,u.pos)==0,'Tower key/position missing or ambiguous')
            if u.key then keys[u.key]=true end
        end
        return b
    end
    function A:stop(reason,state)
        if self.pending then self.uncertainRun=self.run;self.uncertainRound=self.roundToken end
        self.reportDue=self.armed or self.pending~=nil or self.reportDue
        self.armed=false;self.pending=nil;self.reason=tostring(reason);self.state=state or 'BLOCKED'
        log:add('AUTO '..self.state,self.reason)
    end
    function A:reject(reason) self:stop('Request rejected/unconfirmed: '..tostring(reason)) end
    function A:arm(s)
        if type(s)~='table' then self:stop('Native snapshot unavailable');return false end
        if self.pending then self:stop('Pending action cannot be rearmed');return false end
        if self.uncertainRun==s.run or (self.uncertainRound~=nil and self.uncertainRound==s.roundToken) then
            self:stop('Prior action unconfirmed; enter a fresh round');return false
        end
        local b=self:readiness(s,false)
        if #b>0 then self:stop(table.concat(b,'; '));return false end
        if s.resultVisible or s.defeated or s.dead then self:stop('Match already ended');return false end
        self.armed=true;self.state='RUNNING';self.reason='Experimental native combat'
        self.run=s.run;self.roundToken=s.roundToken;self.stage=s.stage;self.mode=s.mode;self.placeId=s.placeId
        self.startedAt=s.now;self.progressAt=s.now;self.lastWave=s.wave;self.lastAction=-math.huge
        self.cursor=1;self.dataWaitAt=nil;self.reportDue=false
        self.targetStatus=cfg.autoTarget=='first' and 'First priority awaits completed placements' or 'Game default target priority'
        log:add('AUTO ARM','Observed '..s.mode..'; bounded equipped targets')
        return true
    end
    function A:tick(s)
        if not self.armed then return nil end
        if type(s)~='table' then self:stop('Native snapshot unavailable');return nil end
        if acquired(s) then self:stop('Exact collection Rukia acquired','GOAL_MET');return nil end
        if not C.finite(s.now) or s.now<self.startedAt or s.now-self.startedAt>=cfg.maxSeconds then
            self:stop('Native session time limit or invalid clock');return nil
        end
        if s.run~=self.run or s.roundToken~=self.roundToken or s.stage~=self.stage or s.mode~=self.mode or s.placeId~=self.placeId then
            self:stop('Unexpected match/stage/native round change; arm verified round explicitly');return nil
        end
        if s.resultVisible or s.defeated or s.dead then
            self.runs+=1
            if s.outcome=='Victory' then self.wins+=1 elseif s.outcome=='Defeat' or s.defeated then self.losses+=1 end
            self:stop('Observed result: '..tostring(s.outcome or 'ended'),'RESULT');return nil
        end
        local b=self:readiness(s,self.pending~=nil)
        if #b>0 then self:stop(table.concat(b,'; '));return nil end
        if s.wave~=self.lastWave then self.progressAt=s.now;self.lastWave=s.wave end
        if self.pending then
            local p=self.pending
            if s.now-p.at>8 then self:stop(p.kind..' feedback timeout; no blind retry');return nil end
            local found,ambiguous
            if p.kind=='place' then found,ambiguous=C.placementVerified(p,s.units)
            elseif p.kind=='priority' then
                for _,u in ipairs(s.units) do
                    if u.key==p.key and u.uuid==p.uuid and u.id==p.id and C.distance(u.pos,p.pos)<=3
                        and type(u.priority)=='string' and u.priority==p.target then found=u;break end
                end
            else
                for _,u in ipairs(s.units) do
                    if u.key==p.key and u.uuid==p.uuid and u.id==p.id and C.distance(u.pos,p.pos)<=3
                        and C.finite(u.level) and u.level>p.level then
                        if u.level~=p.level+1 then self:stop('Unexpected upgrade level jump');return nil end
                        found=u;break
                    end
                end
            end
            if ambiguous then self:stop('Ambiguous placement feedback');return nil end
            if found then
                if p.kind=='place' then self.placements+=1;self.cursor=p.slotIndex%#s.roster+1
                elseif p.kind=='priority' then self.confirmations+=1
                else self.upgrades+=1 end
                self.pending=nil;self.lastAction=s.now;self.progressAt=s.now;self.state='RUNNING'
                log:add('AUTO CONFIRMED',p.kind..' '..p.id)
            end
            return nil
        end
        if s.now-self.progressAt>180 then self:stop('No wave/action progress for180 seconds');return nil end
        if not s.started or s.now-self.lastAction<1.5 then return nil end
        local current=counts(s);local hasCombat,combat,farm=false,false,false
        for _,u in ipairs(s.roster) do
            if u.role=='combat' or u.role=='unknown' or u.role==nil then hasCombat=true;if current[u.uuid]>0 then combat=true end end
            if u.role=='farm' and current[u.uuid]>0 then farm=true end
        end
        local options,missing={},false
        if #s.units<24 then
            for i,u in ipairs(s.roster) do
                if current[u.uuid]<cap(u) then
                    missing=true
                    local attack=u.role=='combat' or u.role=='unknown' or u.role==nil
                    local allowed=not hasCombat or combat or attack or (u.role=='farm' and not farm)
                    if allowed and s.cash-cfg.reserve>=u.cost then options[#options+1]={u=u,index=i,attack=attack} end
                end
            end
        end
        if missing then
            table.sort(options,function(a,b)
                if hasCombat and not combat and a.attack~=b.attack then return a.attack end
                local ac,bc=current[a.u.uuid],current[b.u.uuid]
                if (ac==0)~=(bc==0) then return ac==0 end
                if cfg.autoMethod=='Cheapest' and a.u.cost~=b.u.cost then return a.u.cost<b.u.cost end
                local da=(a.index-self.cursor)%#s.roster;local db=(b.index-self.cursor)%#s.roster
                return da<db
            end)
            local choice=options[1]
            if not choice then
                self.state='WAITING';self.reason=hasCombat and not combat and farm and 'Saving for first combat unit' or 'Waiting for affordable placement';return nil
            end
            local u=choice.u;local pos=spot(s,u)
            if not pos then self:stop('Observed placement spot unavailable: slot '..tostring(u.slot)..' '..u.id);return nil end
            local before={};for _,v in ipairs(s.units) do before[v.key]=true end
            self.pending={kind='place',uuid=u.uuid,id=u.id,pos=pos,before=before,at=s.now,slotIndex=choice.index}
            self.state='PLACE_WAIT';self.reason='Placing '..u.id..' | quoted Yen='..u.cost
            return {kind='place',uuid=u.uuid,id=u.id,pos=table.clone(pos)}
        end
        self.state='HOLDING'
        if cfg.autoTarget=='first' then
            local candidate,unavailable=nil,{}
            for _,u in ipairs(s.units) do
                local entry
                for _,v in ipairs(s.roster) do if v.uuid==u.uuid and v.id==u.id then entry=v;break end end
                if entry and entry.role~='farm' and entry.role~='buff' then
                    if type(u.priority)~='string' or u.priority=='' then unavailable[#unavailable+1]=u.id
                    elseif u.priority~='first' and not candidate then candidate=u end
                end
            end
            self.targetStatus=#unavailable>0 and 'Target priority unavailable: '..table.concat(unavailable,', ')
                or 'First priority observed on supported combat towers'
            if candidate then
                self.pending={kind='priority',key=candidate.key,uuid=candidate.uuid,id=candidate.id,
                    pos=table.clone(candidate.pos),target='first',at=s.now}
                self.state='PRIORITY_WAIT';self.reason='Requesting observed combat target priority: first'
                return {kind='priority',key=candidate.key,uuid=candidate.uuid,id=candidate.id,target='first'}
            end
        else self.targetStatus='Game default target priority' end
        if not cfg.upgrade then self.reason='Known caps/target limit reached; upgrades disabled';return nil end
        local best,unknown=nil,false
        for _,u in ipairs(s.units) do
            local equipped=false
            for _,v in ipairs(s.roster) do if v.uuid==u.uuid and v.id==u.id then equipped=true;break end end
            if equipped then
                local levelKnown=C.finite(u.level) and u.level>=0 and u.level%1==0
                local maximum=levelKnown and C.finite(u.maxLevel) and u.maxLevel>=0 and u.maxLevel%1==0 and u.level>=u.maxLevel
                if not maximum then
                    if not levelKnown or not C.finite(u.nextCost) or u.nextCost<=0 then unknown=true
                    elseif s.cash-cfg.reserve>=u.nextCost then
                        local cheap=cfg.autoUpgradeMethod=='Cheapest'
                        local better=not best or (cheap and (u.nextCost<best.nextCost or (u.nextCost==best.nextCost and u.level<best.level)))
                            or (not cheap and (u.level<best.level or (u.level==best.level and u.nextCost<best.nextCost)))
                        if better then best=u end
                    end
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
            self.dataWaitAt=self.dataWaitAt or s.now;self.reason='Waiting for known upgrade level/price; maximum unproven'
            if s.now-self.dataWaitAt>15 then self:stop('Upgrade level/price unavailable; maximum unproven') end
        else self.dataWaitAt=nil;self.reason='Known targets placed; waiting for funds or result' end
        return nil
    end
    function A:text(_s)
        return 'NATIVE AUTO: '..self.state..' | '..self.reason..'\nConfirmed placements='..self.placements..
            ' upgrades='..self.upgrades..' priority='..self.confirmations..' | wins='..self.wins..' losses='..self.losses..
            '\n'..self.targetStatus
    end
    return A
end
