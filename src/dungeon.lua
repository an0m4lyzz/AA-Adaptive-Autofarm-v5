-- Pure, bounded Dungeon observation and action planning. No getters or remotes.
return function(C)
    local D={}
    local function get(t,k) if type(t)=='table' then return rawget(t,k) end;return nil end
    local function number(v) return C.finite(v) and v>=0 end
    local function integer(v) return number(v) and v==math.floor(v) end
    local function scalar(v) return type(v)=='string' or type(v)=='boolean' or C.finite(v) end
    -- Stable copied values make source mutations and table addresses unusable as feedback.
    local function copy(value,depth,budget)
        local ty=type(value)
        if ty~='table' then if value==nil or scalar(value) then return value end;error('Unsupported source value') end
        if depth>5 then error('Nested source exceeds observation bound') end
        local out={}
        for k,v in pairs(value) do
            budget.n+=1
            if budget.n>1024 or (type(k)~='string' and not integer(k)) then error('Source exceeds observation bound') end
            out[k]=copy(v,depth+1,budget)
        end
        return out
    end
    local function token(v)
        if type(v)~='table' then local text=tostring(v);return type(v)..':'..#text..':'..text end
        local keys={};for k in pairs(v) do keys[#keys+1]=k end
        table.sort(keys,function(a,b) return type(a)..tostring(a)<type(b)..tostring(b) end)
        local parts={'{'}
        for _,k in ipairs(keys) do parts[#parts+1]=token(k)..'='..token(v[k])..';' end
        parts[#parts+1]='}';return table.concat(parts)
    end
    local function array(t,limit)
        if type(t)~='table' then error('Missing source array') end
        local count=0
        for k in pairs(t) do if not integer(k) or k<1 or k>limit then error('Unsupported source array') end;count+=1 end
        if count~=#t then error('Sparse source array') end
        return count
    end
    local flags={['0']=true,['1']=true,['2']=true,['3']=true,['4']=true,['5']=true,['6']=true,['7']=true}
    local choices={['1']=true,['2']=true,['3']=true}
    function D.snapshot(service,core,level)
        local ok,result=pcall(function()
            local source=get(get(get(service,'session'),'profile_data'),'dungeon_data')
            local types,items=get(core,'TYPES'),get(core,'ITEMS')
            if type(source)~='table' or type(types)~='table' or type(items)~='table' then error('Loaded Dungeon schema unavailable') end
            local phaseTypes={}
            for name,kind in pairs({SHOP='Shop',SHRINE='Shrine',OPEN_CHEST='Chest'}) do
                local id=get(types,name)
                if not scalar(id) or type(id)=='boolean' or phaseTypes[id] then error('Unknown Dungeon TYPES') end
                phaseTypes[id]=kind
            end
            local started,finished=get(source,'_started'),get(source,'_finished')
            if type(started)~='boolean' or (finished~=nil and type(finished)~='boolean') then error('Unknown Dungeon run flags') end
            local resource=get(source,'_resources')
            local money,normal,rare=get(resource,'money'),get(resource,'treasure'),get(resource,'treasure_gold')
            if not number(money) or not integer(normal) or not integer(rare) then error('Dungeon resources unreadable') end
            local d={valid=true,source='DungeonServiceClient.session.profile_data.dungeon_data',started=started,
                dead=get(source,'_dead')~=nil and get(source,'_dead')~=false,finished=finished==true,
                money=money,normalChests=normal,rareChests=rare,rooms={},itemCounts={},phases={}}
            local maxRooms=get(core,'NUM_ROOMS');if maxRooms~=nil and (not integer(maxRooms) or maxRooms<1) then error('Unknown room limit') end
            d.maxRooms=maxRooms
            local nextRooms=get(source,'next')
            if type(nextRooms)~='table' then error('Room offers unreadable') end
            local roomCount=0
            for choice,room in pairs(nextRooms) do
                roomCount+=1
                if not choices[choice] or roomCount>3 or type(room)~='table' then error('Unknown room choice schema') end
                local depth,rawFlags=get(room,'_d'),get(room,'_t')
                if not integer(depth) or depth<1 or type(rawFlags)~='table' then error('Room depth/flags unreadable') end
                local observed={}
                for id,on in pairs(rawFlags) do
                    local key=tostring(id)
                    if not flags[key] or type(on)~='boolean' then error('Unknown room flag') end
                    observed[key]=on
                end
                d.rooms[choice]={choice=choice,depth=depth,flags=observed,token=token({depth,observed})}
            end
            local selected=get(source,'selected_next')
            if selected~=nil then
                local choice,lives=get(selected,'choice_str'),get(selected,'lives')
                if not choices[choice] or not integer(lives) then error('Selected room/lives unreadable') end
                d.choice=choice;d.lives=lives
                d.depth=d.rooms[choice] and d.rooms[choice].depth or nil
                d.selectedToken=token(copy(selected,0,{n=0}))
            else d.selectedToken='none' end
            local ld=get(level,'_dungeon')
            d.level={active=ld~=nil,token='none'}
            if ld~=nil then
                local depth,choice,lives,done=get(ld,'depth'),get(ld,'choice_str'),get(ld,'lives'),get(ld,'finished')
                if not integer(depth) or depth<1 or not choices[choice] or (lives~=nil and not integer(lives))
                    or (done~=nil and type(done)~='boolean') then error('Native Dungeon level identity unreadable') end
                local identity=copy(ld,0,{n=0})
                d.level={active=true,depth=depth,choice=choice,lives=lives,finished=done,identity=identity,token=token(identity)}
                d.depth=depth
                if d.choice==nil then d.choice=choice;d.lives=lives end
            end
            d.active=d.level.active;d.levelToken=d.level.token
            local inventory=get(source,'_items')
            if inventory==nil then inventory={} end
            array(inventory,256)
            for _,item in ipairs(inventory) do
                local id=get(item,'id');if type(id)~='string' or id=='' then error('Dungeon item identity unreadable') end
                d.itemCounts[id]=(d.itemCounts[id] or 0)+1
            end
            local queue=get(source,'current_shops');array(queue,16)
            for i,rawPhase in ipairs(queue) do
                local kind=phaseTypes[get(rawPhase,'_t')]
                if not kind then error('Unknown current Dungeon phase') end
                local data=get(rawPhase,'data')
                if data==nil and kind=='Chest' then data={} end
                array(data,32)
                local phase={kind=kind,token=token(copy(rawPhase,0,{n=0})),offers={}}
                if kind=='Shop' then
                    for index,offer in ipairs(data) do
                        local id=get(offer,'id')
                        if type(id)~='string' or id=='' then error('Shop offer identity unreadable') end
                        local base=get(get(items,id),'cost');if not number(base) then base=nil end
                        local price=get(offer,'currentCost')
                        if not integer(price) then price=nil end
                        -- No default multiplier: discounts must be observed by the adapter.
                        local def=get(items,id)
                        phase.offers[index]={index=index,id=id,baseCost=base,price=price,
                            name=type(get(def,'name'))=='string' and get(def,'name'):sub(1,100) or id,
                            description=type(get(def,'description'))=='string' and get(def,'description'):sub(1,500) or nil,
                            priceSource=price~=nil and 'observed currentCost' or 'unknown'}
                    end
                elseif kind=='Shrine' then
                    phase.acceptKnown=#data>0
                    for index,offer in ipairs(data) do
                        local id,ty=get(offer,'id'),get(offer,'_t')
                        local def=type(id)=='string' and get(items,id)
                        if ty~='Item' or type(def)~='table' then phase.acceptKnown=false end
                        phase.offers[index]={id=id,type=ty,name=type(get(def,'name'))=='string' and get(def,'name'):sub(1,100) or id,
                            description=type(get(def,'description'))=='string' and get(def,'description'):sub(1,500) or nil}
                    end
                end
                d.phases[i]=phase
            end
            d.phase=d.phases[1] or {kind='None',token='none',offers={}}
            d.nextPhaseToken=d.phases[2] and d.phases[2].token or 'none'
            d.phaseToken=d.phase.token
            d.roomToken=token(d.rooms)
            d.keyToken=token({started=d.started,dead=d.dead,finished=d.finished,selected=d.selectedToken,
                rooms=d.roomToken,level=d.levelToken})
            d.stateToken=token({key=d.keyToken,phase=d.phaseToken,money=money,normal=normal,rare=rare,items=d.itemCounts})
            return d
        end)
        if ok then return result end
        return {valid=false,reason=tostring(result),source='DungeonServiceClient.session.profile_data.dungeon_data'}
    end

    function D.engine(cfg,log)
        log=log or C.logger()
        local e={cfg=cfg,log=log,armed=false,state='IDLE',reason='Dungeon OFF',pending=nil,confirmations=0,spent=0}
        function e:stop(reason,state)
            if self.pending then self.unresolved=true end
            self.armed=false;self.state=state or 'BLOCKED';self.reason=reason;self.pending=nil
            self.log:add(self.state,reason)
        end
        local function acquired(s)
            if cfg.goal~='Acquire' or not C.finite(s.now) or not C.finite(s.ownedAt)
                or s.now<s.ownedAt or s.now-s.ownedAt>15 then return false end
            local u=C.chooseRukia(s.owned)
            return u~=nil and u.statScope=='collection' and C.isRukia(u.id)
        end
        local function ready(s,verifying)
            if type(s)~='table' or not C.finite(s.now) or not C.finite(s.dungeonAt)
                or s.now<s.dungeonAt or s.now-s.dungeonAt>5 then return 'Dungeon cache stale or unavailable' end
            local d=s.dungeon
            if type(d)~='table' or d.valid~=true then return 'Dungeon schema unknown: '..tostring(d and d.reason) end
            if s.externalControllerActive then return 'External controller active; Dungeon stopped' end
            if not verifying and (s.transportBlocked or s.mutationFence) then return 'Native mutation fence or outstanding request' end
            if d.dead or (s.resultVisible and s.outcome=='Defeat') then return 'Dungeon death or Defeat observed' end
            if d.lives~=nil and d.lives<=0 then return 'Dungeon lives exhausted' end
            if type(s.inMatch)~='boolean' then return 'Match activity unknown' end
            return nil
        end
        local function baseline(d)
            return {normal=d.normalChests,rare=d.rareChests,money=d.money,depth=d.depth}
        end
        local function observeCurrent(self,d)
            local level=d.level
            if not level.active then return end
            local r=self.currentRoom
            if not r or r.depth~=level.depth or r.choice~=level.choice then
                r={depth=level.depth,choice=level.choice,expected={},resolved={},completed=false}
                self.currentRoom=r;self.transitionWaitAt=nil
            end
            -- Offers at the native room's exact depth describe the room being played.
            -- Keep these flags when the profile replaces them with forward offers.
            local room=d.rooms[level.choice]
            if room and room.depth==level.depth and not r.completed then
                r.expected={Shop=room.flags['1']==true,Shrine=room.flags['7']==true,
                    Chest=room.flags['5']==true or room.flags['6']==true}
            end
        end
        local function waitTransition(self,s,reason)
            self.transitionWaitAt=self.transitionWaitAt or s.now
            if s.now-self.transitionWaitAt>20 then
                self:stop('Dungeon post-Victory transition timeout; '..reason..'; no automatic retry')
            else self.state='WAIT_TRANSITION';self.reason=reason end
            return nil
        end
        function e:arm(s)
            if self.unresolved then self:stop('Prior Dungeon action unresolved; reload and inspect manually');return false end
            local why=ready(s,false)
            if why then self:stop(why);return false end
            if acquired(s) then self:stop('Exact permanent Rukia ownership observed','GOAL_MET');return false end
            if s.dungeon.started~=true then self:stop('No already-started Dungeon run; start manually');return false end
            if cfg.dungeonPreset~=nil and cfg.dungeonPreset~='Safe' and cfg.dungeonPreset~='Rewards' then self:stop('Unknown Dungeon preset');return false end
            local cap=cfg.dungeonShopCap
            if cap~=nil and (not number(cap) or cap>1000000) then self:stop('Invalid Dungeon shop budget');return false end
            self.armed=true;self.state='RUNNING';self.reason='Existing Dungeon run armed'
            self.started=s.now;self.spent=0;self.pending=nil;self.bought={};self.entered=nil;self.last=baseline(s.dungeon)
            self.currentRoom=nil;self.transitionWaitAt=nil;self.lobbyVictory=false;self.acceptedShrines={};observeCurrent(self,s.dungeon)
            self.log:add('DUNGEON ARM',self.reason);return true
        end
        function e:reject(reason) self:stop('Dungeon action rejected: '..tostring(reason)) end
        local function action(self,s,name,args,expected,timeout)
            expected.beforeKeyToken=s.dungeon.keyToken
            if expected.kind=='continue' then
                expected.normal=s.dungeon.normalChests;expected.rareCount=s.dungeon.rareChests
                expected.money=s.dungeon.money;expected.levelToken=s.dungeon.levelToken
                expected.phaseKind=s.dungeon.phase.kind
            end
            local p={at=s.now,name=name,expected=expected,timeout=timeout or 8}
            self.pending=p;self.state='WAITING';self.reason='Awaiting observed '..name
            return {kind='dungeon',name=name,args=args,expected=expected}
        end
        local function confirmed(q,d,s)
            local x=q.expected
            if x.kind=='enter' then
                return d.started and d.level.active and d.level.depth==x.depth and d.level.choice==x.choice
                    and (d.levelToken~=x.beforeLevelToken or s.roundToken~=x.beforeRoundToken)
            elseif x.kind=='continue' then
                return d.phase.token==x.nextPhaseToken and d.normalChests==x.normal and d.rareChests==x.rareCount
                    and ((x.finishing and d.started==false and d.normalChests==0 and d.rareChests==0)
                        or (not x.finishing and d.started==true and d.money==x.money and d.levelToken==x.levelToken))
            elseif x.kind=='buy' then
                return d.keyToken==x.beforeKeyToken and d.started and d.phase.kind=='Shop' and d.money==x.money-x.price
                    and (d.itemCounts[x.id] or 0)==x.itemCount+1
            elseif x.kind=='chest' then
                return d.keyToken==x.beforeKeyToken and d.phase.kind=='Chest' and d.started and d.normalChests==x.normal-(x.rare and 0 or 1)
                    and d.rareChests==x.rareCount-(x.rare and 1 or 0)
            elseif x.kind=='shrine' then
                if d.keyToken~=x.beforeKeyToken or not d.started or d.money~=x.money then return false end
                for id,n in pairs(x.items) do if (d.itemCounts[id] or 0)~=n.before+n.gain then return false end end
                return true
            end
            return false
        end
        local ranks={Safe={['1']=1,['2']=2,['3']=3,['4']=4,['7']=5,['0']=6},
            Rewards={['3']=1,['4']=2,['1']=3,['2']=4,['7']=5,['0']=6}}
        local function pick(d,preset,minDepth)
            if d.choice and d.rooms[d.choice] and (not minDepth or d.rooms[d.choice].depth>minDepth) then return d.rooms[d.choice] end
            local rank=ranks[preset or 'Safe'];local best,bscore
            for _,choice in ipairs({'1','2','3'}) do
                local room=d.rooms[choice]
                if room and (not minDepth or room.depth>minDepth) then
                    local score=7
                    for flag,on in pairs(room.flags) do if on and rank[flag] then score=math.min(score,rank[flag]) end end
                    if not best or score<bscore then best=room;bscore=score end
                end
            end
            return best
        end
        function e:tick(s)
            if not self.armed then return nil end
            local why=ready(s,self.pending~=nil)
            if why then self:stop(why);return nil end
            local d=s.dungeon
            observeCurrent(self,d)
            if cfg.dungeonPreset~=nil and cfg.dungeonPreset~='Safe' and cfg.dungeonPreset~='Rewards' then self:stop('Unknown Dungeon preset');return nil end
            if acquired(s) then self:stop('Exact permanent Rukia ownership observed','GOAL_MET');return nil end
            local limit=number(cfg.maxSeconds) and cfg.maxSeconds or 1200
            if s.now-self.started>=limit then self:stop('Dungeon session time limit');return nil end
            if self.pending then
                local p=self.pending
                if confirmed(p,d,s) then
                    self.confirmations+=1
                    if p.expected.kind=='buy' then self.spent+=p.expected.price;self.bought[p.expected.id]=true end
                    if p.expected.kind=='shrine' then self.acceptedShrines[p.expected.phaseToken]=true end
                    if p.expected.kind=='enter' then
                        self.entered={reset=s.inMatch==true and s.resultVisible~=true};self.transitionWaitAt=nil
                    end
                    if p.expected.kind=='continue' then
                        if self.currentRoom then self.currentRoom.resolved[p.expected.phaseKind]=true end
                        self.transitionWaitAt=d.phase.kind=='None' and s.now or nil
                    end
                    self.pending=nil;self.last=baseline(d);self.state='RUNNING';self.reason='Dungeon action confirmed by observed state'
                    self.log:add('DUNGEON CONFIRMED',p.name)
                elseif s.now-p.at>p.timeout then self:stop(p.name..' feedback timeout; no automatic retry') end
                return nil
            end
            if d.started~=true then self:stop('Dungeon run ended; no new key-consuming run started','COMPLETE');return nil end
            if self.last and (d.normalChests<self.last.normal or d.rareChests<self.last.rare or d.money<self.last.money
                or (d.depth and self.last.depth and d.depth<self.last.depth)) then
                self:stop('Dungeon counters regressed outside a pending action');return nil
            end
            self.last=baseline(d)
            if self.entered then
                if not self.entered.reset then
                    if s.inMatch and s.resultVisible~=true then self.entered.reset=true end
                    self.state='WAIT_MATCH';self.reason='Awaiting new Dungeon match result reset';return nil
                end
                if s.resultVisible~=true or s.outcome~='Victory' then
                    self.state='WAIT_MATCH';self.reason='Awaiting confirmed entered-room Victory';return nil
                end
                self.entered=nil
            end
            if s.inMatch and (s.resultVisible~=true or s.outcome~='Victory') then
                self.state='WAIT_MATCH';self.reason='Awaiting confirmed Dungeon Victory';return nil
            end
            local phase=d.phase
            local last=d.finished or (d.maxRooms~=nil and d.depth~=nil and d.depth>=d.maxRooms)
            local finishing=last and d.nextPhaseToken=='none'
            local current=self.currentRoom
            if s.resultVisible and s.outcome=='Victory' then
                if current and not current.completed then
                    current.completed=true;self.transitionWaitAt=self.transitionWaitAt or s.now
                elseif not current and not self.lobbyVictory then
                    self.lobbyVictory=true;self.transitionWaitAt=self.transitionWaitAt or s.now
                end
            end
            if self.transitionWaitAt and s.now-self.transitionWaitAt>20 then
                return waitTransition(self,s,'Awaiting replicated Dungeon phase or forward offers')
            end
            if phase.kind=='None' then
                if current and current.completed then
                    for kind,expected in pairs(current.expected) do
                        if expected and not current.resolved[kind] then
                            return waitTransition(self,s,'Awaiting expected post-Victory '..kind..' phase')
                        end
                    end
                end
                if last then return waitTransition(self,s,'Awaiting final Dungeon chest phase') end
            else self.transitionWaitAt=nil end
            if last and cfg.dungeonOpenChests~=true then
                self:stop('Final Dungeon chest permission required before finishing');return nil
            end
            if last and finishing and phase.kind~='Chest' and (d.normalChests>0 or d.rareChests>0) then
                self:stop('Unopened final Dungeon chests; refusing last nonchest continuation');return nil
            end
            if phase.kind=='Shop' then
                local cap=cfg.dungeonShopCap or 0
                if number(cap) and cap>0 then
                    local counts={}
                    for _,offer in ipairs(phase.offers) do counts[offer.id]=(counts[offer.id] or 0)+1 end
                    local ordered=table.clone(phase.offers);local order={};local index=0
                    for id in tostring(cfg.dungeonBuyOrder or ''):gmatch('[%w_%-]+') do index+=1;order[id]=index end
                    if index>0 then table.sort(ordered,function(a,b)
                        local ar,br=order[a.id] or 1000,order[b.id] or 1000
                        return ar==br and a.index<b.index or ar<br
                    end) end
                    for _,offer in ipairs(ordered) do
                        if not self.bought[offer.id] and counts[offer.id]==1 and integer(offer.price) and offer.price<=d.money and self.spent+offer.price<=cap then
                            return action(self,s,'dungeon_buy_shop',{offer.index},{kind='buy',id=offer.id,index=offer.index,
                                price=offer.price,money=d.money,itemCount=d.itemCounts[offer.id] or 0,phaseToken=phase.token})
                        end
                    end
                end
                return action(self,s,'dungeon_continue_shop',{},
                    {kind='continue',phaseToken=phase.token,nextPhaseToken=d.nextPhaseToken,finishing=finishing})
            elseif phase.kind=='Shrine' then
                if cfg.dungeonShrines==true and phase.acceptKnown and not self.acceptedShrines[phase.token] then
                    local allow={};for id in tostring(cfg.dungeonShrineItems or ''):gmatch('[%w_%-]+') do allow[id]=true end
                    local accepted,items=true,{}
                    for _,offer in ipairs(phase.offers) do
                        if not allow[offer.id] then accepted=false;break end
                        items[offer.id]=items[offer.id] or {before=d.itemCounts[offer.id] or 0,gain=0}
                        items[offer.id].gain+=1
                    end
                    if accepted and next(items)~=nil then
                        return action(self,s,'dungeon_shrine_accept',{}, {kind='shrine',items=items,money=d.money,phaseToken=phase.token})
                    end
                end
                return action(self,s,'dungeon_continue_shop',{},
                    {kind='continue',phaseToken=phase.token,nextPhaseToken=d.nextPhaseToken,finishing=finishing})
            elseif phase.kind=='Chest' then
                if last and cfg.dungeonOpenChests==true and (d.rareChests>0 or d.normalChests>0) then
                    local rare=d.rareChests>0
                    return action(self,s,'dungeon_open_chest',rare and {true} or {},
                        {kind='chest',rare=rare,normal=d.normalChests,rareCount=d.rareChests})
                end
                if last and (d.normalChests>0 or d.rareChests>0) then self:stop('Unopened final Dungeon chests; refusing finish');return nil end
                return action(self,s,'dungeon_continue_shop',{},
                    {kind='continue',phaseToken=phase.token,nextPhaseToken=d.nextPhaseToken,finishing=finishing})
            elseif phase.kind~='None' then self:stop('Unknown Dungeon phase');return nil end
            local room=pick(d,cfg.dungeonPreset,current and current.depth or nil)
            if not room then return waitTransition(self,s,'Awaiting verified forward Dungeon room offers') end
            return action(self,s,'dungeon_enter_room',{room.choice},{kind='enter',choice=room.choice,depth=room.depth,
                beforeLevelToken=d.levelToken,beforeRoundToken=s.roundToken},20)
        end
        function e:text(_s)
            return 'Dungeon '..self.state..' | '..self.reason..' | confirmed='..self.confirmations..' | shop spent='..self.spent
        end
        return e
    end
    return D
end
