-- Portable, data-only macros. Records this controller's exact receipts; no hooks.
return function(C,cfg,log)
    local M={armed=false,recording=false,state='IDLE',reason='Macro OFF',placements=0,upgrades=0,confirmations=0,
        runs=0,wins=0,losses=0,index=1,pending=nil,actors={},recordActors={}}
    local kinds={place=true,upgrade=true,sell=true,priority=true,ability=true,skip=true}
    function M:recordable(kind) return kinds[kind]==true end
    function M:rosterCheckpoint()
        if type(self.rosterBindings)~='table' then return nil end
        local out={};for _,r in ipairs(self.rosterBindings) do out[#out+1]={slot=r.slot,id=r.id,uuid=r.uuid} end;return out
    end
    local function bindRoster(s)
        if s.rosterComplete~=true or type(s.roster)~='table' or #s.roster<1 or #s.roster>6 then return nil end
        local out,seen={},{}
        for _,r in ipairs(s.roster) do
            if not C.finite(r.slot) or r.slot%1~=0 or r.slot<1 or r.slot>6 or seen[r.slot]
                or type(r.id)~='string' or r.id=='' or type(r.uuid)~='string' or r.uuid=='' then return nil end
            seen[r.slot]=true;out[#out+1]={slot=r.slot,id=r.id,uuid=r.uuid}
        end
        table.sort(out,function(a,b)return a.slot<b.slot end);return out
    end
    local function sameRoster(a,b)
        if type(a)~='table' or type(b)~='table' or #a~=#b then return false end
        local slots={};for _,r in ipairs(a) do slots[r.slot]=r end
        for _,r in ipairs(b) do local old=slots[r.slot];if not old or old.id~=r.id or old.uuid~=r.uuid then return false end end
        return true
    end
    local function plain(t,keys)
        if type(t)~='table' then return false end
        for k in pairs(t) do if not keys[k] then return false end end
        return true
    end
    function M:signature(d)
        if not self:validate(d).valid then return nil end
        local parts={d.stage,tostring(d.placeId),d.mode}
        for _,s in ipairs(d.steps) do
            parts[#parts+1]=s.kind..':'..s.wave..':'..s.timeout..':'..tostring(s.priority or '')
            if s.target then parts[#parts+1]=s.target.slot..':'..s.target.id..':'..s.target.actor end
            if s.pos then for _,x in ipairs(s.pos) do parts[#parts+1]=string.format('%.17g',x) end end
        end
        local text=table.concat(parts,'|');local h=5381
        for i=1,#text do h=(h*33+string.byte(text,i))%4294967296 end
        return 'm1:'..string.format('%08x',h)..':'..#d.steps
    end
    function M:validate(d,bytes)
        local function bad(reason) return {valid=false,errors=reason} end
        if bytes and bytes>262144 then return bad('Macro exceeds256 KiB') end
        if not plain(d,{schema=true,name=true,stage=true,placeId=true,mode=true,steps=true}) or d.schema~=1
            or type(d.name)~='string' or #d.name>40 or not d.name:match('^[%w_%-]+$')
            or type(d.stage)~='string' or #d.stage<1 or #d.stage>160 or not C.finite(d.placeId)
            or type(d.mode)~='string' or type(d.steps)~='table' or #d.steps<1 or #d.steps>2000 then return bad('Unsupported macro header/format') end
        local count=0;for k in pairs(d.steps) do count+=1;if type(k)~='number' or k%1~=0 or k<1 or k>#d.steps then return bad('Sparse step list') end end
        if count~=#d.steps then return bad('Invalid step list') end
        local placed={}
        for i,s in ipairs(d.steps) do
            if not plain(s,{kind=true,wave=true,target=true,pos=true,priority=true,timeout=true}) or not kinds[s.kind]
                or not C.finite(s.wave) or s.wave<0 or s.wave>10000 or not C.finite(s.timeout) or s.timeout<1 or s.timeout>120 then return bad('Invalid step '..i) end
            if s.kind~='skip' then
                local t=s.target
                if not plain(t,{slot=true,id=true,actor=true}) or not C.finite(t.slot) or t.slot%1~=0 or t.slot<1 or t.slot>6
                    or type(t.id)~='string' or #t.id<1 or #t.id>100 or not C.finite(t.actor) or t.actor%1~=0 or t.actor<1 or t.actor>2000 then return bad('Invalid actor '..i) end
                if s.kind=='place' then
                    if C.distance(s.pos,s.pos)~=0 or #s.pos~=3 or placed[t.actor] then return bad('Invalid position/duplicate actor '..i) end
                    placed[t.actor]=true
                elseif not placed[t.actor] then return bad('Actor used before placement '..i) end
            end
            if s.kind=='priority' and not table.find({'first','last','strongest','weakest','closest','farthest'},s.priority) then return bad('Unsupported priority') end
        end
        return {valid=true,steps=d.steps}
    end
    function M:startRecording(s,name)
        if self.armed or s.unitsComplete~=true or not s.stageVerified or not s.modeVerified then return false,'Recording context unavailable' end
        if type(name)~='string' or not name:match('^[%w_%-]+$') or #name>40 then return false,'Use a short letters/numbers/underscore name' end
        self.data={schema=1,name=name,stage=s.stage,placeId=s.placeId,mode=s.mode,steps={}}
        self.recordActors={};self.recording=true;self.recordRound=s.roundToken;return true
    end
    function M:captureManual(before,after,kind)
        if not kinds[kind] or kind=='skip' or before.unitsComplete~=true or after.unitsComplete~=true
            or before.roundToken~=after.roundToken or before.run~=after.run or before.stage~=after.stage then return nil,'Manual capture context/action unsupported' end
        local old,new={},{}
        for _,u in ipairs(before.units or {}) do if not u.key or old[u.key] then return nil,'Ambiguous prior tower identity' end;old[u.key]=u end
        for _,u in ipairs(after.units or {}) do if not u.key or new[u.key] then return nil,'Ambiguous current tower identity' end;new[u.key]=u end
        local change
        local function add(p) if change then return false end;change=p;return true end
        for key,u in pairs(new) do
            local b=old[key]
            if not b then
                if kind~='place' or not add({kind=kind,uuid=u.uuid,id=u.id,pos=u.pos,before=old}) then return nil,'Multiple/different changes observed' end
            elseif b.id~=u.id or b.uuid~=u.uuid or C.distance(b.pos,u.pos)>0.05 then return nil,'Actor identity/position changed'
            else
                local level=b.level~=u.level;local priority=b.priority~=u.priority;local cast=b.lastCast~=u.lastCast
                if level or priority or cast then
                    local good=(kind=='upgrade' and level and not priority and not cast and C.finite(b.level) and u.level==b.level+1)
                        or (kind=='priority' and priority and not level and not cast)
                        or (kind=='ability' and cast and not level and not priority and C.finite(b.lastCast) and C.finite(u.lastCast) and u.lastCast>b.lastCast)
                    if not good or not add({kind=kind,key=key,uuid=u.uuid,id=u.id,pos=u.pos,level=b.level,target=u.priority,lastCast=b.lastCast}) then return nil,'Multiple/different changes observed' end
                end
            end
        end
        for key,b in pairs(old) do if not new[key] then
            if kind~='sell' or not add({kind=kind,key=key,uuid=b.uuid,id=b.id,pos=b.pos}) then return nil,'Multiple/different changes observed' end
        end end
        if change then change.macroWave=before.wave;return change end
        return nil,'No exact supported state change observed'
    end
    function M:record(p,s)
        if not self.recording then return false,'Recorder OFF' end
        if s.roundToken~=self.recordRound or s.stage~=self.data.stage or #self.data.steps>=2000 then self.recording=false;return false,'Recording boundary/limit reached' end
        if not kinds[p.kind] then return false,'Action not supported by macro schema' end
        local step={kind=p.kind,wave=p.macroWave or p.wave or s.wave or 0,timeout=30}
        if p.kind~='skip' then
            local slot;for _,r in ipairs(s.roster or {}) do if r.uuid==p.uuid and r.id==p.id then slot=r.slot;break end end
            if not slot then return false,'Exact equipped copy unavailable' end
            local actor
            if p.kind=='place' then
                local u,ambiguous=C.placementVerified(p,s.units)
                if not u or ambiguous then return false,'Placement receipt ambiguous' end
                actor=#self.data.steps+1;self.recordActors[u.key]=actor;step.pos=table.clone(p.pos)
            else actor=self.recordActors[p.key] end
            if not actor then return false,'Actor was not recorded; capture its placement first' end
            step.target={slot=slot,id=p.id,actor=actor}
            if p.kind=='priority' then step.priority=p.target end
        end
        self.data.steps[#self.data.steps+1]=step;return true
    end
    function M:readiness(s)
        local b={};local validation=self:validate(self.data)
        if not validation.valid then return {validation.errors} end
        if s.stage~=self.data.stage or s.placeId~=self.data.placeId or s.mode~=self.data.mode then b[#b+1]='Macro stage/place/mode mismatch' end
        if not s.stageVerified or not s.modeVerified or s.rosterComplete~=true or s.unitsComplete~=true then b[#b+1]='Macro needs complete observed data' end
        if s.transportBlocked or s.mutationFence or s.externalControllerActive then b[#b+1]='Existing native/external action blocks macro' end
        for _,step in ipairs(self.data.steps) do if step.target then
            local found=false;for _,r in ipairs(s.roster or {}) do if r.slot==step.target.slot and r.id==step.target.id then found=true;break end end
            if not found then b[#b+1]='Macro equipped slot mismatch';break end
        end end
        return b
    end
    function M:arm(s)
        local b=self:readiness(s);if #b>0 then self:stop(table.concat(b,'; '));return false end
        local roster=bindRoster(s);local previous=self.resumeBindings or self.rosterBindings
        if not roster or (previous and not sameRoster(previous,roster)) then self:stop('Macro equipped copy changed; explicit playback approval required');return false end
        self.rosterBindings=roster;self.resumeBindings=nil
        self.armed=true;self.recording=false;self.state='RUNNING';self.reason='Data-only macro armed';self.index=1
        self.run=s.run;self.round=s.roundToken;self.stage=s.stage;self.at=s.now;self.waitAt=s.now;self.eligibleIndex=nil;self.pending=nil;self.actors={}
        self.placements=0;self.upgrades=0;self.confirmations=0;return true
    end
    function M:stop(reason,state) self.armed=false;self.pending=nil;self.state=state or 'BLOCKED';self.reason=tostring(reason) end
    function M:reject(reason) self:stop(reason) end
    function M:tick(s)
        if not self.armed then return nil end
        if s.run~=self.run or s.roundToken~=self.round or s.stage~=self.stage or s.resultVisible
            or s.unitsComplete~=true or s.externalControllerActive then self:stop('Macro context/result changed');return nil end
        if s.now-self.at>math.min(7200,cfg.maxSeconds or 1200) then self:stop('Macro duration cap');return nil end
        if not sameRoster(self.rosterBindings,bindRoster(s)) then self:stop('Macro equipped copy changed; re-arm explicitly');return nil end
        if self.pending then
            local p=self.pending;local found
            if s.now-p.at>8 then self:stop('Macro action unconfirmed; no automatic retry');return nil end
            if p.kind=='place' then local ambiguous;found,ambiguous=C.placementVerified(p,s.units);if ambiguous then self:stop('Macro placement ambiguous');return nil end
            elseif p.kind=='sell' then
                found=true;for _,u in ipairs(s.units) do if u.key==p.key then found=false end end
            elseif p.kind=='skip' then found=s.wave>p.wave or (s.wave==p.wave and s.skipFinished==true)
            else
                for _,u in ipairs(s.units) do if u.key==p.key and u.uuid==p.uuid and u.id==p.id then
                    if p.kind=='upgrade' and u.level==p.level+1 then found=u
                    elseif p.kind=='priority' and u.priority==p.target then found=u
                    elseif p.kind=='ability' and C.finite(u.lastCast) and u.lastCast>p.lastCast then found=u end
                end end
            end
            if found then
                if p.kind=='place' then self.actors[p.actor]=found.key;self.placements+=1
                elseif p.kind=='upgrade' then self.upgrades+=1 else self.confirmations+=1 end
                self.index+=1;self.pending=nil;self.eligibleIndex=nil;self.waitAt=s.now;self.reason='Exact macro action observed'
            end
            return nil
        end
        if s.transportBlocked or s.mutationFence then self:stop('Macro transport fenced');return nil end
        local step=self.data.steps[self.index]
        if not step then self.state='HOLDING';self.reason='Macro steps finished; awaiting match outcome';return nil end
        if not s.started or (cfg.macroIgnoreTiming~=true and s.wave<step.wave) then self.reason='Waiting for macro wave';return nil end
        if self.eligibleIndex~=self.index then self.waitAt=s.now;self.eligibleIndex=self.index end
        if s.now-self.waitAt>step.timeout then self:stop('Macro precondition timeout; action unsent');return nil end
        local action={kind=step.kind};local p={kind=step.kind,at=s.now}
        if step.kind=='skip' then
            if not s.skipOffer or s.skipOffer.wave~=s.wave or s.skipFinished~=false then self.reason='Waiting for current skip offer';return nil end
            action.offerToken=s.skipOffer.token;action.wave=s.wave;p.wave=s.wave
        else
            local roster;for _,r in ipairs(s.roster or {}) do if r.slot==step.target.slot and r.id==step.target.id then roster=r;break end end
            if not roster then self:stop('Macro equipped copy changed');return nil end
            p.uuid=roster.uuid;p.id=roster.id;p.actor=step.target.actor;action.uuid=p.uuid;action.id=p.id
            if step.kind=='place' then
                local count=0;for _,u in ipairs(s.units) do if u.uuid==p.uuid then count+=1 end end
                if not C.finite(roster.spawnCap) or count>=roster.spawnCap then self:stop('Macro known placement cap');return nil end
                if not C.finite(roster.cost) or not C.finite(s.cash) or s.cash-(cfg.reserve or 0)<roster.cost then self.reason='Waiting for quoted placement cash';return nil end
                p.pos=table.clone(step.pos);p.before={};for _,u in ipairs(s.units) do p.before[u.key]=true end;action.pos=table.clone(step.pos)
            else
                p.key=self.actors[p.actor];action.key=p.key;local tower
                for _,u in ipairs(s.units) do if u.key==p.key and u.uuid==p.uuid and u.id==p.id then tower=u;break end end
                if not tower then self:stop('Macro actor unavailable');return nil end
                p.pos=tower.pos
                if step.kind=='upgrade' then
                    if not C.finite(tower.level) or not C.finite(tower.nextCost) or not C.finite(s.cash) or s.cash-(cfg.reserve or 0)<tower.nextCost then self.reason='Waiting for exact upgrade quote/cash';return nil end
                    p.level=tower.level
                elseif step.kind=='sell' then
                    if tower.sellable~=true or tower.id=='bulma' then self:stop('Macro sale not supported for this tower');return nil end
                elseif step.kind=='priority' then p.target=step.priority;action.target=step.priority
                elseif step.kind=='ability' then
                    if tower.castReady~=true or not C.finite(tower.lastCast) or type(tower.activeAttack)~='string' or tower.activeAttack:find(':',1,true) then self.reason='Waiting for known normal ability';return nil end
                    p.lastCast=tower.lastCast
                end
            end
        end
        self.pending=p;self.state='WAITING';self.reason='Macro '..step.kind..' awaiting exact feedback';return action
    end
    function M:text() return 'MACRO '..self.state..' | step '..self.index..' | '..self.reason end
    return M
end
