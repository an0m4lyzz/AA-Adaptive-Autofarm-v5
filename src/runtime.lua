-- Pure native orchestration. Child readback is authoritative; one action at a time.
local makeFlow=require('./flow')
return function(C,makeAuto,makeDungeon,cfg,log)
    log=log or C.logger()
    local supported={Story=true,Dungeon=true,Infinite=true,Challenge=true,Raid=true,Legend=true,Portal=true}
    local r={auto=makeAuto(C,cfg,log),route=makeDungeon(C).engine(cfg,log),armed=false,
        state='IDLE',reason='Native Auto OFF',pending=nil,placements=0,upgrades=0,confirmations=0,
        runs=0,wins=0,losses=0,flowConfirmations=0}
    r.extras=makeFlow(C,cfg)
    local function sync(self)
        self.placements=self.auto.placements;self.upgrades=self.auto.upgrades
        self.confirmations=(self.auto.confirmations or 0)+self.route.confirmations+self.flowConfirmations+self.extras.confirmations
        self.pending=self.flowPending or self.route.pending or self.auto.pending or self.extras.pending
    end
    local function identity(self,s)
        self.run=s.run;self.roundToken=s.roundToken;self.stage=s.stage;self.placeId=s.placeId;self.observedMode=s.mode
    end
    local function same(self,s)
        return self.run==s.run and self.roundToken==s.roundToken and self.stage==s.stage
            and self.placeId==s.placeId and self.observedMode==s.mode
    end
    local function dungeonReady(s)
        if not C.finite(s.dungeonAt) or s.now<s.dungeonAt or s.now-s.dungeonAt>5 then return 'Dungeon cache stale or unavailable' end
        local d=s.dungeon
        if type(d)~='table' or d.valid~=true then return 'Dungeon schema unknown: '..tostring(type(d)=='table' and d.reason) end
        if d.dead or (d.lives~=nil and (not C.finite(d.lives) or d.lives<=0)) then return 'Dungeon death or lives exhausted' end
        return nil
    end
    function r:stop(reason,state)
        self.extras:stop(reason)
        self.auto:stop(reason,state);self.route:stop(reason,state)
        self.armed=false;self.flowPending=nil;self.pending=nil;self.state=state or 'BLOCKED';self.reason=tostring(reason)
        sync(self);log:add('NATIVE '..self.state,self.reason)
    end
    function r:reject(reason) self:stop('Native request rejected/unconfirmed: '..tostring(reason)) end
    function r:readiness(s,pending)
        return self.auto:readiness(s,pending)
    end
    local function failChild(self,child)
        if not child.armed then self:stop(child.reason,child.state);return true end
        return false
    end
    local function armCombat(self,s)
        if s.mode~=self.mode then self:stop('Unexpected combat mode after native transition');return false end
        if not self.auto:arm(s) then self:stop(self.auto.reason,self.auto.state);return false end
        identity(self,s);self.extras:arm(s);self.finishAt=nil;self.waitingReset=nil;self.startAttempted=false;self.state='RUNNING';self.reason='Experimental native combat'
        return true
    end
    function r:arm(s)
        if self.pending then self:stop('Pending native action cannot be rearmed');return false end
        if type(s)~='table' or not C.finite(s.now) or not C.finite(cfg.maxSeconds) or cfg.maxSeconds<30 then
            self:stop('Native snapshot/session time limit unavailable');return false
        end
        if s.externalControllerActive or s.mutationFence or s.transportBlocked then
            self:stop('External controller, mutation fence or outstanding native request');return false
        end
        if s.dead or s.defeated or (s.resultVisible and s.outcome~='Victory') then self:stop('Death, Defeat or unknown result observed');return false end
        self.mode=(s.mode=='Dungeon' or (s.inMatch==false and cfg.mode=='Dungeon')) and 'Dungeon' or s.mode
        if not supported[self.mode] then self:stop('Native Auto mode unsupported');return false end
        if self.mode=='Dungeon' then
            if cfg.dungeonConsent~=true then self:stop('Explicit existing-run Dungeon permission required');return false end
            local why=dungeonReady(s);if why then self:stop(why);return false end
            if not self.route:arm(s) then self:stop(self.route.reason,self.route.state);return false end
        end
        self.auto.placements=0;self.auto.upgrades=0;self.auto.confirmations=0;self.auto.runs=0;self.auto.wins=0;self.auto.losses=0
        self.route.confirmations=0;self.flowConfirmations=0;self.runs=0;self.wins=0;self.losses=0
        self.flowPending=nil;self.waitingReset=nil;self.startAttempted=false;self.countedRound=nil
        self.startedAt=s.now;identity(self,s)
        if self.mode~='Dungeon' or (s.inMatch==true and s.resultVisible~=true) then
            if not armCombat(self,s) then return false end
        else self.auto:stop('Waiting for existing Dungeon route','IDLE') end
        self.armed=true;self.state='RUNNING';self.reason='Experimental native '..self.mode
        sync(self);return true
    end
    local function flow(self,s,kind,timeout,expected)
        self.flowPending={kind=kind,at=s.now,timeout=timeout,expected=expected,run=s.run,roundToken=s.roundToken}
        self.state='WAITING';self.reason='Awaiting observed '..kind;sync(self)
        return {kind=kind,expected=expected}
    end
    local function replayAllowed(self,s)
        return self.mode=='Story' and cfg.replay==true and cfg.replayFreeConfirmed==true and C.contextMatches(cfg.replayContext,s)
            and self.runs<cfg.maxRuns
    end
    local function verifyFlow(self,s)
        local p=self.flowPending
        if s.now-p.at>p.timeout then self:stop(p.kind..' feedback timeout; no automatic retry');return end
        local confirmed=false
        if p.kind=='start' then
            if cfg.autoStartWaves~=true then self:stop('Automatic wave-start permission revoked');return end
            if not same(self,s) then self:stop('Unexpected round change during start');return end
            confirmed=s.started==true or s.voteStartFinished==true
        elseif p.kind=='replay' or p.kind=='next' then
            local allowed
            if p.kind=='replay' then
                allowed=self.mode=='Story' and cfg.replay==true and cfg.replayFreeConfirmed==true
                    and C.contextMatches(cfg.replayContext,p.expected) and self.runs<cfg.maxRuns
            else allowed=self.mode=='Story' and cfg.autoNextStory==true and self.runs<cfg.maxRuns end
            if not allowed then self:stop(p.kind..' permission/context revoked');return end
            local newRound=s.run~=nil and s.run~=p.run and s.roundToken~=nil and s.roundToken~=p.roundToken
            local verified=s.stageVerified==true and s.modeVerified==true
            local matches=C.contextMatches(p.expected,s)
            if verified and (p.kind=='replay' or newRound) and not matches then
                self:stop('Unexpected '..p.kind..' context');return
            end
            confirmed=newRound and verified and matches and s.inMatch==true and s.resultVisible==false
                and s.unitsComplete==true and type(s.units)=='table' and #s.units==0
            if confirmed then self.waitingReset={kind=p.kind};identity(self,s) end
        elseif p.kind=='lobby' then
            if cfg.autoReturnLobby~=true then self:stop('Automatic lobby-return permission revoked');return end
            confirmed=s.observedLobby==true and s.inMatch==false
        end
        if confirmed then
            self.flowConfirmations+=1;self.flowPending=nil;sync(self)
            if p.kind=='lobby' then self:stop('Observed return to lobby; native session ended','COMPLETE')
            else self.state='RUNNING';self.reason='Native '..p.kind..' confirmed by observation' end
        end
    end
    local function childTick(self,child,s)
        local a=child:tick(s);sync(self)
        if failChild(self,child) then return nil end
        self.state=child.state;self.reason=child.reason;return a
    end
    function r:tick(s)
        if not self.armed then return nil end
        if type(s)~='table' or not C.finite(s.now) or s.now<self.startedAt
            or not C.finite(cfg.maxSeconds) or s.now-self.startedAt>=cfg.maxSeconds then
            self:stop('Native session time limit or invalid clock');return nil
        end
        if s.externalControllerActive then self:stop('External controller active; native mutation stopped');return nil end
        if self.mode~='Dungeon' and same(self,s) and s.resultVisible and self.countedRound~=self.roundToken
            and (s.outcome=='Victory' or s.outcome=='Defeat') then
            self.runs+=1;self.countedRound=self.roundToken
            if s.outcome=='Victory' then self.wins+=1 else self.losses+=1 end
        end
        if s.dead or s.defeated or (s.resultVisible and s.outcome~='Victory') then self:stop('Death, Defeat or unknown result observed');return nil end
        if self.mode=='Dungeon' then
            if cfg.dungeonConsent~=true then self:stop('Existing-run Dungeon permission revoked');return nil end
            local why=dungeonReady(s);if why then self:stop(why);return nil end
        end
        if cfg.goal=='Acquire' and C.finite(s.ownedAt) and s.now>=s.ownedAt and s.now-s.ownedAt<=15 then
            for _,u in ipairs(type(s.owned)=='table' and s.owned or {}) do
                if type(u)=='table' and C.isRukia(u.id) and u.statScope=='collection' and type(u.uuid)=='string' and u.uuid~='' then
                    self:stop('Exact collection Rukia acquired','GOAL_MET');return nil
                end
            end
        end
        if self.auto.pending and s.resultVisible then self:stop('Result arrived with unconfirmed combat action');return nil end
        if self.flowPending then verifyFlow(self,s);sync(self);return nil end
        local rp=self.route.pending
        local entering=rp and rp.expected.kind=='enter'
        if not same(self,s) and not entering and not self.waitingReset then
            self:stop('Unexpected match/stage/native round change');return nil
        end
        if rp then
            if s.now-rp.at>rp.timeout then self:stop(rp.name..' feedback timeout; no automatic retry');return nil end
            local expected=rp.expected
            if expected.kind=='chest' and cfg.dungeonOpenChests~=true then
                self:stop('Final Dungeon chest permission revoked');return nil
            elseif expected.kind=='buy' and (not C.finite(cfg.dungeonShopCap)
                or self.route.spent+expected.price>cfg.dungeonShopCap) then
                self:stop('Dungeon shop budget permission reduced');return nil
            end
            local a=childTick(self,self.route,s)
            if self.armed and entering and not self.route.pending then
                self.waitingReset={kind='enter',depth=expected.depth,choice=expected.choice};identity(self,s)
            end
            sync(self);return a
        end
        if self.auto.pending then return childTick(self,self.auto,s) end
        if self.extras.pending then return childTick(self,self.extras,s) end
        if s.transportBlocked or s.mutationFence then self:stop('Native mutation fence or outstanding request');return nil end
        if self.waitingReset then
            local wait=self.waitingReset
            if wait.kind=='enter' then
                local d=s.dungeon
                if not d.level.active or d.level.depth~=wait.depth or d.level.choice~=wait.choice then
                    self:stop('Confirmed Dungeon level changed before combat rearm');return nil
                end
            elseif not same(self,s) then self:stop('Unexpected replay round change before combat rearm');return nil end
            if s.inMatch~=true or s.resultVisible~=false then
                self.state='WAIT_MATCH';self.reason='Awaiting verified new match and cleared result';return nil
            end
            if self.route.entered then self.route.entered.reset=true end
            armCombat(self,s);sync(self);return nil
        end
        if s.resultVisible then
            self.auto:stop('Observed Victory','RESULT')
            if self.mode=='Dungeon' then return childTick(self,self.route,s) end
            self.finishAt=self.finishAt or s.now
            if s.now-self.finishAt<(cfg.finishDelay or 0) then self.state='WAITING';self.reason='Configured finish delay';return nil end
            if self.mode=='Story' and cfg.autoNextStory==true and self.runs<cfg.maxRuns then
                if type(s.nextStoryId)~='string' or s.nextStoryId=='' or s.nextStoryId==s.stage then
                    self:stop('Next Story stage unavailable from loaded progression data');return nil
                end
                return flow(self,s,'next',20,{kind='next_story',stage=s.nextStoryId,mode='Story',placeId=s.placeId})
            elseif replayAllowed(self,s) then
                return flow(self,s,'replay',20,{kind='replay',stage=s.stage,mode=s.mode,placeId=s.placeId})
            elseif cfg.autoReturnLobby==true then
                return flow(self,s,'lobby',20,{kind='lobby',stage=s.stage,mode=s.mode,placeId=s.placeId})
            end
            self:stop('Observed '..self.mode..' Victory; native session ended','RESULT');return nil
        end
        if self.mode=='Dungeon' and not self.auto.armed then return childTick(self,self.route,s) end
        if cfg.autoStartWaves==true and not self.startAttempted and s.started==false and s.voteStartFinished==false then
            self.startAttempted=true;return flow(self,s,'start',8,{kind='start',stage=s.stage,mode=s.mode,placeId=s.placeId})
        end
        local extra=childTick(self,self.extras,s)
        if not self.armed or extra then return extra end
        if self.extras.soldRoles.all then self.state='HOLDING';self.reason='Scheduled sale complete; holding until outcome';return nil end
        if self.extras.soldRoles.farm then
            s=table.clone(s);s.roster=table.clone(s.roster)
            for i,u in ipairs(s.roster) do if u.role=='farm' then s.roster[i]=table.clone(u);s.roster[i].runtimeDisabled=true end end
        end
        return childTick(self,self.auto,s)
    end
    function r:text(s)
        return 'NATIVE '..self.state..' | '..self.reason..'\nConfirmed placements='..self.placements..
            ' upgrades='..self.upgrades..' flow='..self.confirmations..' | finished runs='..self.runs..
            '\n'..self.auto:text(s)..'\n'..self.route:text(s)
    end
    return r
end
