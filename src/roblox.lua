-- Native observations plus an explicit, experimental cached-client reader.
local makeInventory=require('./inventory')
local makeDungeon=require('./dungeon')
return function(C, env, cfg, log)
    local Players=game:GetService('Players')
    local RS=game:GetService('ReplicatedStorage')
    local WS=game:GetService('Workspace')
    local LP=Players.LocalPlayer
    local inventoryParser=makeInventory(C)
    local dungeonParser=makeDungeon(C)
    local A={alive=true,models={},owned={},roster={},resources={},ownedAt=nil,rosterAt=nil,
        nextInventory=0,run=0,lastWave=0,lastFolder=nil,stage=nil,mode=nil,stageSource='unknown',
        path={},previous=setmetatable({},{__mode='k'}),nextMapTry=0,failures={},replies={}}
    local function child(p,n) return p and p:FindFirstChild(n) end
    local function scalar(p,keys)
        if not p then return nil end
        for _,k in ipairs(keys) do
            local v=p:GetAttribute(k)
            if v==nil then local item=child(p,k);if item and item:IsA('ValueBase') then v=item.Value end end
            if v~=nil then return v end
        end
        return nil
    end
    local function number(p,keys)
        local n=tonumber(scalar(p,keys));return C.finite(n) and n or nil
    end
    local function stringValue(p,keys)
        local v=scalar(p,keys)
        return (type(v)=='string' or type(v)=='number') and tostring(v) or nil
    end
    local function numericValue(p,key)
        local v=child(p,key)
        if not v or not (v:IsA('NumberValue') or v:IsA('IntValue')) then return nil end
        return C.finite(v.Value) and v.Value or nil
    end
    -- Shared only in memory. A controller reload must not manufacture a new
    -- round merely by resetting its local run counter or Loader cache.
    local function syncRound(self,frame)
        if not frame then
            local units,wave=child(WS,'_UNITS'),child(WS,'_wave_num')
            local w=number(WS,{'_wave_num'}) or 0;local started=scalar(WS,{'_waves_started'})
            local lobby=w==0 and started~=true and child(WS,'_LOBBIES')
                and (child(WS,'_EVOLVE') or child(WS,'_traits'))
            frame={waveNode=wave,w=w,started=started,finished=scalar(child(WS,'_DATA'),{'GameFinished'}),
                context=lobby and 'Lobby' or units and wave and 'Match' or 'Unknown'}
        end
        local previous=env.K_AA_NATIVE_ROUND
        local job=type(game.JobId)=='string' and game.JobId~='' and game.JobId or nil
        local changed=type(previous)~='table'
        if not changed then
            changed=previous.placeId~=game.PlaceId or (previous.job and job and previous.job~=job)
                or (previous.waveNode and frame.waveNode and previous.waveNode~=frame.waveNode)
                or (frame.waveNode and C.finite(previous.w) and frame.w<previous.w)
                or (frame.started==false and previous.started==true)
                or (frame.finished==false and previous.finished==true)
                or (frame.context~='Unknown' and previous.context~='Unknown' and frame.context~=previous.context)
        end
        local token=changed and {} or previous.token
        local function retain(key)
            local v=frame[key]
            if v~=nil then return v end
            if not changed then return previous[key] end
        end
        local context=frame.context
        if context=='Unknown' and not changed then context=previous.context end
        env.K_AA_NATIVE_ROUND={token=token,placeId=game.PlaceId,job=job or (not changed and previous.job or nil),
            waveNode=retain('waveNode'),w=frame.waveNode and frame.w or (not changed and previous.w or nil),
            started=retain('started'),finished=retain('finished'),context=context}
        if changed then
            local old=env.K_AA_MUTATION_FEEDBACK
            if old and old.roundToken~=token then env.K_AA_MUTATION_FEEDBACK=nil end
        end
        self.roundToken=token;return token
    end
    function A:mutationFenced()
        local fence=env.K_AA_MUTATION_FEEDBACK
        return type(fence)=='table' and fence.roundToken==self.roundToken
    end
    function A:confirmMutation(token)
        local fence=env.K_AA_MUTATION_FEEDBACK
        if token and type(fence)=='table' and fence.token==token then
            env.K_AA_MUTATION_FEEDBACK=nil
            if self.lastMutation and self.lastMutation.feedbackToken==token then self.lastMutation.feedbackState='exact readback observed' end
            return true
        end
        return false
    end
    local function cleanText(value,uuid)
        if type(value)~='string' then return '<'..type(value)..'>' end
        local s=value:gsub('<.->',''):gsub('%c',' ')
        if type(uuid)=='string' and #uuid>0 then s=s:gsub(uuid:gsub('(%W)','%%%1'),'<unit>') end
        s=s:gsub(string.rep('%x',8)..'%-'..string.rep('%x',4)..'%-'..string.rep('%x',4)..'%-'..
            string.rep('%x',4)..'%-'..string.rep('%x',12),'<unit>'):gsub(string.rep('%x',32),'<unit>')
        return s:sub(1,180)
    end
    local function replyText(value,uuid)
        local ty=type(value)
        if ty=='nil' then return 'nil' end
        if ty=='boolean' then return tostring(value) end
        if ty=='number' then return C.finite(value) and tostring(value) or '<nonfinite number>' end
        if ty=='string' then return 'string: '..cleanText(value,uuid) end
        if ty=='table' then
            local fields={}
            for _,k in ipairs({'success','ok','error','message','reason','status','code'}) do
                local v=rawget(value,k);local vt=type(v)
                if vt=='string' then fields[#fields+1]=k..'='..cleanText(v,uuid)
                elseif vt=='boolean' or (vt=='number' and C.finite(v)) then fields[#fields+1]=k..'='..tostring(v) end
            end
            return 'table: '..(#fields>0 and table.concat(fields,'; ') or 'unclassified contents omitted')
        end
        return '<'..ty..'>'
    end
    local function disconnectMessages(self)
        if self.messageConnection then pcall(function() self.messageConnection:Disconnect() end) end
        if self.messageMark then self.messageMark.watchState='closed' end
        self.messageConnection=nil;self.messageMark=nil
    end
    local function watchMessages(self,mark)
        disconnectMessages(self)
        mark.messages={};mark.watchState='unavailable'
        local event=child(child(child(RS,'endpoints'),'server_to_client'),'show_message')
        if not event or not event:IsA('RemoteEvent') then return end
        local ok,connection=pcall(function()
            return event.OnClientEvent:Connect(function(message)
                if self.alive and self.messageMark==mark and self.run==mark.run
                    and os.clock()-mark.at<=8 and #mark.messages<4 and type(message)=='string' then
                    local text=cleanText(message,mark.redactUuid)
                    mark.messages[#mark.messages+1]=text;log:add('GAME MESSAGE',mark.kind..' | '..text)
                end
            end)
        end)
        if ok and connection then
            self.messageConnection=connection;self.messageMark=mark;mark.watchState='open'
        end
    end
    function A:placementSurface(pos,id)
        local check={run=self.run,reason='Not checked'};self.lastSurfaceCheck=check
        local function fail(reason) check.reason=reason;return nil,reason end
        if C.distance(pos,pos)~=0 then return fail('Recorded position invalid') end
        check.recorded={pos[1],pos[2],pos[3]}
        local terrain=child(WS,'_terrain')
        if not terrain then return fail('Observed _terrain container missing') end
        local ground,hill=child(terrain,'ground'),child(terrain,'hill')
        if not ground and not hill then return fail('Observed terrain has no supported ground/hill root') end
        local def=type(self.definitions)=='table' and type(id)=='string' and rawget(self.definitions,id) or nil
        if type(def)~='table' then return fail('Loaded unit placement definition unavailable') end
        local hillUnit,hybrid=rawget(def,'hill_unit'),rawget(def,'hybrid_placement')
        if (hillUnit~=nil and type(hillUnit)~='boolean') or (hybrid~=nil and type(hybrid)~='boolean') then
            return fail('Unsupported unit placement flags')
        end
        if not Vector3 or not RaycastParams or not Enum or not Enum.RaycastFilterType then
            return fail('Terrain raycast capability unavailable')
        end
        local ok,hit=pcall(function()
            local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include
            params.FilterDescendantsInstances={terrain}
            return WS:Raycast(Vector3.new(pos[1],pos[2]+80,pos[3]),Vector3.new(0,-400,0),params)
        end)
        if not ok then return fail('Terrain raycast failed') end
        if not hit or not hit.Instance then return fail('No observed terrain surface at the recorded X/Z') end
        local at=hit.Instance;local reachedTerrain=false
        for _=1,12 do
            if not at then break end
            if at.Name=='_donotplace' then return fail('Hit a _donotplace surface') end
            if at==terrain then reachedTerrain=true;break end
            at=at.Parent
        end
        if not reachedTerrain then return fail('Terrain ancestry incomplete; surface unsupported') end
        local function within(root) return root and (hit.Instance==root or hit.Instance:IsDescendantOf(root)) end
        local class=within(ground) and 'ground' or within(hill) and 'hill' or nil
        if not class then return fail('First terrain hit is not a supported ground/hill surface') end
        if (class=='hill' and not hillUnit and not hybrid) or (class=='ground' and hillUnit) then
            return fail('Observed surface does not match the unit ground/hill rule')
        end
        local p=hit.Position;local normal=hit.Normal
        if not p or not C.finite(p.X) or not C.finite(p.Y) or not C.finite(p.Z)
            or not normal or not C.finite(normal.Y) or normal.Y<=0 then return fail('Terrain hit has invalid position/normal') end
        if math.abs(p.X-pos[1])>0.05 or math.abs(p.Z-pos[3])>0.05 then return fail('Raycast changed recorded X/Z') end
        -- A body-centre sample must not select an upper deck or a distant lower
        -- floor. Three studs is a conservative supported projection window,
        -- not an assumed unit offset or a fallback placement height.
        if p.Y>pos[2]+0.05 or pos[2]-p.Y>3 then return fail('Surface height conflicts with the saved sample') end
        check.pos={p.X,p.Y,p.Z};check.source='_terrain.'..class;check.normalY=normal.Y;check.reason='Observed surface'
        return table.clone(check.pos),check.source
    end
    local function point(m)
        local p=child(m,'_hitbox') or m.PrimaryPart
        if p and p:IsA('BasePart') then return {p.Position.X,p.Position.Y,p.Position.Z} end
        return nil -- no fabricated pivot for empty models
    end
    local function own(m)
        local st=child(m,'_stats')
        local who=scalar(st,{'player','owner','player_id'})
        return who==LP or who==LP.UserId or who==LP.Name or who==tostring(LP.UserId)
    end
    local function path(raw,playerOnly)
        if type(raw)~='string' or #raw>200 then return nil end
        local parts=string.split(raw,'/')
        if #parts>12 then return nil end
        local roots={player=LP,workspace=WS,gui=child(LP,'PlayerGui')}
        if playerOnly and parts[1]~='player' then return nil end
        local p=roots[parts[1]]
        for i=2,#parts do
            if parts[i]=='' then return nil end
            p=child(p,parts[i]);if not p then return nil end
        end
        return p
    end
    local fields={damage={'damage','dmg'},spa={'spa','attack_cooldown','attack_speed'},
        range={'range','attack_range'},cost={'placement_cost','spawn_cost','place_cost'},
        nextCost={'next_upgrade_cost','upgrade_cost'},level={'upgrade','upgrade_level'},maxLevel={'max_upgrade'},
        takedowns={'takedowns','kills'},worthiness={'worthiness'},slot={'equipped_slot','equippedSlot'}}
    local function record(node,scope)
        local st=child(node,'_stats') or child(node,'stats') or node
        local u={uuid=stringValue(st,{'uuid','unique_id'}),id=stringValue(st,{'unit_id','unitId','id'}),
            priority=stringValue(st,{'priority'}),
            trait=stringValue(st,{'trait','trait_name'}),statScope=scope,
            damageGrade=stringValue(st,{'damage_grade','damageGrade'}),
            spaGrade=stringValue(st,{'spa_grade','spaGrade'}),
            rangeGrade=stringValue(st,{'range_grade','rangeGrade'})}
        u.activeAttack=stringValue(st,{'active_attack'})
        u.lastCast=numericValue(st,'last_active_cast');u.cooldown=numericValue(st,'active_attack_cooldown')
        local clockNow=type(tick)=='function' and tick() or nil
        if C.finite(clockNow) and C.finite(u.lastCast) and C.finite(u.cooldown) and u.cooldown>0 then
            u.castReady=clockNow>=u.lastCast+u.cooldown
        end
        for k,keys in pairs(fields) do u[k]=number(st,keys) end
        if not u.uuid or not u.id then return nil end
        return u
    end
    function A:refreshInventory(now)
        self.nextInventory=now+4
        local roots={}
        if cfg.inventoryPath~='' then
            local custom=path(cfg.inventoryPath,true);if custom then roots[#roots+1]=custom end
        else
            for _,raw in ipairs({'player/owned_units','player/collection_profile_data/owned_units',
                'player/_data/owned_units','player/collection/owned_units'}) do
                local root=path(raw,true);if root then roots[#roots+1]=root end
            end
        end
        local units,byUUID,roster={}, {}, {}
        local visited=0
        for _,root in ipairs(roots) do
            for _,node in ipairs(root:GetChildren()) do
                visited+=1;if visited>400 then break end
                local u=record(node,'collection')
                if u and not byUUID[u.uuid] then
                    byUUID[u.uuid]=true;units[#units+1]=u
                    if C.finite(u.slot) and u.slot>=1 and u.slot<=8 then roster[#roster+1]=u end
                end
            end
        end
        if self.clientBinding then self.clientService=inventoryParser.current(self.clientBinding) end
        local cached=self.clientService and inventoryParser.read(self.clientService,LP.UserId)
        if cached and cached.valid and cfg.inventoryPath=='' then units=cached.owned;roster=cached.roster end
        self.owned=units;self.roster=roster
        self.rosterComplete=cached and cached.valid and cfg.inventoryPath=='' and cached.equippedComplete==true or false
        self.equippedDeclared=cached and cached.valid and cached.equippedDeclared or nil
        self.ownedAt=#roots>0 and now or nil;self.rosterAt=#roster>0 and now or nil
        self.inventorySource=#roots>0 and 'partial player-replicated collection' or 'not exposed through configured paths'
        if cached and cached.valid and cfg.inventoryPath=='' then
            self.ownedAt=now
            self.inventorySource='partial client cache: '..tostring(self.clientSource)..
                ' | recognized='..#units..' equipped='..#roster..' rejected='..cached.rejected..
                ' truncated='..tostring(cached.truncated)..' equipped-complete='..tostring(self.rosterComplete)
        elseif cached and not cached.valid and #roots==0 then
            self.inventorySource='client cache schema unavailable; observations cleared'
        end
        local r=cfg.resourcePath~='' and path(cfg.resourcePath,true) or path('player/_data/items',true)
        local resources={}
        local aliases={SacredTreasure={'sacred_treasure','SacredTreasure'},StarFruit={'StarFruit'},
            StarFruitBlue={'StarFruitBlue'},StarFruitRed={'StarFruitRed'},StarFruitGreen={'StarFruitGreen'},
            StarFruitEpic={'StarFruitEpic'},DungeonKey={'dungeon_key','DungeonKey'},
            RerollToken={'reroll_token','RerollToken'},StarRemnant={'star_remnant','StarRemnant'},
            StatCube={'stat_cube','StatCube'},PerfectStatCube={'perfect_stat_cube','PerfectStatCube'}}
        if r then
            for key,names in pairs(aliases) do
                resources[key]=number(r,names)
                if resources[key]==nil then
                    for _,name in ipairs(names) do
                        local item=child(r,name)
                        local count=number(item,{'amount','count','quantity'})
                        if count~=nil then resources[key]=count;break end
                    end
                end
            end
        end
        if cached and cached.valid and cfg.resourcePath=='' then
            for key,amount in pairs(cached.resources) do resources[key]=amount end
        end
        self.resources=resources;self.resourcesAt=(r or (cached and cached.valid)) and now or nil
    end
    -- Manual only: a single loaded-module snapshot and a bounded read of known
    -- Loader closure upvalues. No service getter/initializer is ever called.
    function A:startClientCache(includeDungeon)
        if not self.alive then return false,'Reader closed' end
        if self:busy() then return false,'Another request is still pending' end
        if self.clientService then
            local dungeonRetry=includeDungeon==true and not self.dungeonAttempted
            if dungeonRetry then self.dungeonAttempted=true end
            if not dungeonRetry and (self.definitions or self.combatAttempted) then
                self.nextInventory=0;self.cacheDone=true;return true
            end
            -- One additional explicit read if static data loaded after the
            -- inventory. Reuse the retained Loader export; never initialize it.
            self.combatAttempted=true
        elseif self.cacheAttempted then return false,'Client cache read already attempted this session' end
        local retainedLoader=self.loaderExport
        self.cacheAttempted=true
        local getLoaded=getloadedmodules
        local getUpvalues=type(debug)=='table' and rawget(debug,'getupvalues')
        if type(getLoaded)~='function' or type(getUpvalues)~='function' then
            self.cacheReport='CLIENT CACHE READER: unsupported; getloadedmodules/debug.getupvalues unavailable'
            self.cacheDone=true;return false,self.cacheReport
        end
        local loaderModule=child(child(RS,'src'),'Loader')
        if not loaderModule or not loaderModule:IsA('ModuleScript') then
            self.cacheReport='CLIENT CACHE READER: observed Loader module missing'
            self.cacheDone=true;return false,self.cacheReport
        end
        local mark={at=os.clock(),kind='client-cache',jobId=game.JobId}
        env.K_AA_CLIENT_CACHE_PENDING=mark;self.cacheDone=false
        self.cacheReport='CLIENT CACHE READER: manual read pending; no initializer/getter calls'
        task.spawn(function()
            local trace={}
            local function valid()
                return self.alive and not mark.expired and os.clock()-mark.at<=8
            end
            local ok,found=pcall(function()
                if not valid() then error('Read cancelled/expired',0) end
                local listed,loaded=pcall(getLoaded)
                if not listed or type(loaded)~='table' then error('Loaded-module enumeration unavailable',0) end
                local function listed(target)
                    if not target then return false end
                    for i=1,math.min(#loaded,8192) do if rawget(loaded,i)==target then return true end end
                    return false
                end
                local present=listed(loaderModule)
                if not present then error('Loader not confirmed already loaded; require skipped',0) end
                trace[#trace+1]='Exact Loader listed as loaded; no service lookup functions called'
                if not valid() then error('Read cancelled/expired',0) end
                local loader=retainedLoader
                if type(loader)~='table' then
                    local readOK,result=pcall(require,loaderModule)
                    if not readOK or type(result)~='table' then error('Loaded Loader export unavailable',0) end
                    loader=result
                end
                if not valid() then error('Read cancelled/expired',0) end
                local roots={{value=loader,source='Loader export'}}
                for _,field in ipairs({'init','load_client_service','load_core_service'}) do
                    local fn=rawget(loader,field)
                    local readCount=0
                    if type(fn)=='function' then
                        local valuesOK,values=pcall(getUpvalues,fn)
                        if valuesOK and type(values)=='table' then
                            local key=nil
                            for index=1,32 do
                                local value;key,value=next(values,key);if key==nil then break end
                                readCount=index
                                if type(value)=='table' then
                                    roots[#roots+1]={value=value,source='Loader.'..field..'.upvalue#'..index}
                                end
                            end
                        end
                    end
                    trace[#trace+1]='Loader.'..field..' type='..type(fn)..'; upvalues examined='..readCount
                    if not valid() then error('Read cancelled/expired',0) end
                end
                local match=inventoryParser.find(roots,LP.UserId)
                if not match then error('No supported existing local service session; no getter fallback',0) end
                match.loader=loader
                match.dungeonBindings=inventoryParser.named(roots,{'DungeonServiceClient','DungeonServiceCore','ProgressionServiceCore'})
                -- Only the exact, reported-loaded static Units export. Never
                -- call load_data or recurse into the numeric child modules.
                local unitsModule=child(child(child(RS,'src'),'Data'),'Units')
                if unitsModule and unitsModule:IsA('ModuleScript') and listed(unitsModule) then
                    if not valid() then error('Read cancelled/expired',0) end
                    local dataOK,data=pcall(require,unitsModule)
                    if dataOK and type(data)=='table' then match.definitions=data end
                    trace[#trace+1]='Reported-loaded Units export: '..(match.definitions and 'table' or 'unavailable')
                    if not valid() then error('Read cancelled/expired',0) end
                else trace[#trace+1]='Units not confirmed loaded; static require skipped' end
                return match
            end)
            if env.K_AA_CLIENT_CACHE_PENDING==mark then env.K_AA_CLIENT_CACHE_PENDING=nil end
            if not self.alive then return end
            if mark.expired or os.clock()-mark.at>8 then
                self.cacheDone=true
                self.cacheReport='CLIENT CACHE READER: deadline exceeded; late results rejected'
                return
            end
            self.cacheDone=true
            if ok then
                self.clientBinding={registry=found.registry,name=found.name}
                self.clientService=found.service;self.clientSource=found.source;self.nextInventory=0
                self.loaderExport=found.loader;self.definitions=found.definitions
                self.dungeonBindings=found.dungeonBindings
                self.cacheReport='CLIENT CACHE READER: existing session found (experimental)\nCache source: '..found.source..
                    '\nInitial read recognized units='..#found.snapshot.owned..' equipped='..#found.snapshot.roster..
                    '; incomplete ownership is not absence. Explicit getter/initializer calls: 0.'
                log:add('CLIENT CACHE','Existing session found; current fields require comparison in game')
            else self.cacheReport='CLIENT CACHE READER: unavailable | '..tostring(found):sub(1,250) end
            self.cacheReport=self.cacheReport..'\n'..table.concat(trace,'\n')
        end)
        return true
    end
    -- Explicit, one-shot metadata collection. Never calls a module, reads Source,
    -- captures GUI text/Value data, or changes inventory/automation readiness.
    function A:probePaths()
        if not self.alive or self.probing then return nil,'Diagnostic unavailable or already running' end
        self.probing=true
        local ok,result=pcall(function()
            local began=os.clock()
            local rows={'DATA PATH DIAGNOSTIC (manual, selective, metadata only)',
                'Values, source code and UUID record names are omitted. No modules or remotes are invoked.',
                'Instance paths only; this cannot establish whether inventory lives in client Lua tables.'}
            local queue,seen={},{}
            local cursor
            local visited,truncated=0,false
            local uuidPattern=string.rep('%x',8)..'%-'..string.rep('%x',4)..'%-'..
                string.rep('%x',4)..'%-'..string.rep('%x',4)..'%-'..string.rep('%x',12)
            local compactPattern=string.rep('%x',32)
            local function name(raw)
                raw=tostring(raw)
                if raw:find(uuidPattern) or raw:find(compactPattern)
                    or (#raw>=24 and raw:match('^[%da-fA-F%-]+$'))
                    or (#raw>5 and raw:match('^%d+$')) then
                    return '<record>'
                end
                return raw:gsub('[%c/|]','_'):sub(1,60)
            end
            local function push(item,label,depth,limit,group)
                if not item or seen[item] then return end
                if #queue>=180 then truncated=true;return end
                seen[item]=true
                local row={item=item,label=label,depth=depth,limit=limit,group=group}
                -- Finish the observed client subtree before optional metadata
                -- can consume the shared budget. This does not execute modules.
                if group=='client' and cursor then table.insert(queue,cursor,row)
                else queue[#queue+1]=row end
            end
            local scripts=child(LP,'PlayerScripts');local gui=child(LP,'PlayerGui')
            local src=child(RS,'src')
            push(child(src,'client'),'replicated/src/client',0,4,'client')
            push(child(src,'core'),'replicated/src/core',0,2,'replicated')
            push(child(src,'Loader'),'replicated/src/Loader',0,1,'replicated')
            push(child(gui,'_R'),'gui/_R',0,1,'wrapper')
            push(LP,'player',0,3,'player')
            push(scripts,'player/PlayerScripts',0,4,'scripts')
            push(RS,'replicated',0,3,'replicated')
            push(gui,'gui',0,1,'gui')
            -- Explicit cheap lookups keep common code roots visible even if
            -- ReplicatedStorage has more children than the per-node budget.
            for _,key in ipairs({'src','Modules','Client','_Client','Framework','Services'}) do
                push(child(RS,key),'replicated/'..key,1,3,'replicated')
            end
            local function relevant(raw)
                raw=raw:lower()
                for _,word in ipairs({'src','module','loader','client','data','profile','session',
                    'collection','inventory','unit','service','framework','package','replica','state','item','stat'}) do
                    if raw:find(word,1,true) then return true end
                end
                return false
            end
            local function rank(raw)
                raw=raw:lower()
                for _,term in ipairs({'clientservice','session','profile','collection','inventory','playerdata','replica'}) do
                    if raw:find(term,1,true) then return 0 end
                end
                if raw:find('service',1,true) or raw:find('controller',1,true) or raw:find('loader',1,true) then return 1 end
                return 2
            end
            for _,p in ipairs({'player/owned_units','player/collection_profile_data/owned_units',
                'player/_data/owned_units','player/collection/owned_units','player/_data/items'}) do
                rows[#rows+1]='CANDIDATE '..p..': '..(path(p,true) and 'present' or 'missing')
            end
            cursor=1
            while cursor<=#queue do
                if not self.alive or os.clock()-began>2.5 then truncated=true;break end
                local q=queue[cursor];cursor+=1;visited+=1
                local item=q.item;local keys={}
                local attrOK,attrs=pcall(function() return item:GetAttributes() end)
                if attrOK and type(attrs)=='table' then
                    for k,v in pairs(attrs) do
                        if #keys>=12 then truncated=true;break end
                        keys[#keys+1]=name(k)..':'..typeof(v)
                    end
                    table.sort(keys)
                end
                rows[#rows+1]=(q.label..' ['..item.ClassName..'] attributes='..
                    (#keys>0 and table.concat(keys,',') or 'none')):sub(1,260)
                local container=item:IsA('Folder') or item:IsA('Configuration')
                    or item==LP or item==scripts or item==RS or item==gui
                    or ((q.group=='scripts' or q.group=='client') and item:IsA('ModuleScript'))
                    or (q.group=='wrapper' and item==child(gui,'_R'))
                local descend=q.group~='replicated' or q.depth==0 or relevant(item.Name)
                if q.group=='player' and item.Name=='_settings' then descend=false end
                if q.group=='scripts' and item.Name=='PlayerModule' then descend=false end
                if container and descend and q.depth<q.limit then
                    local childrenOK,kids=pcall(function() return item:GetChildren() end)
                    if childrenOK then
                        local selected={}
                        for i,v in ipairs(kids) do
                            if i>256 then truncated=true;break end
                            local skip=(q.group=='player' and (v==gui or v==scripts or v==LP.Character))
                            skip=skip or v:IsA('BillboardGui') or v:IsA('SurfaceGui')
                            if not skip and v.Name~='K_AA_Rukia_V6' then selected[#selected+1]=v end
                        end
                        if q.group=='client' then
                            table.sort(selected,function(a,b)
                                local ra,rb=rank(a.Name),rank(b.Name)
                                return ra==rb and a.Name<b.Name or ra<rb
                            end)
                        end
                        if #selected>48 then truncated=true end
                        -- Inserting client children at the active cursor is
                        -- stack-like, so reverse insertion preserves priority.
                        local count=math.min(#selected,48,180-#queue)
                        if #selected>count then truncated=true end
                        for offset=1,count do
                            local i=q.group=='client' and count-offset+1 or offset
                            local v=selected[i]
                            push(v,q.label..'/'..name(v.Name),q.depth+1,q.limit,q.group)
                        end
                    else rows[#rows+1]=q.label..' children unavailable' end
                end
                if visited%20==0 then task.wait() end
            end
            rows[#rows+1]='Metadata nodes='..visited..' / 180; limited/cancelled='..tostring(truncated)
            local text=table.concat(rows,'\n')
            if #text>30000 then text=text:sub(1,30000);truncated=true end
            return {text=text,visited=visited,truncated=truncated,at=began}
        end)
        self.probing=false
        if not ok then return nil,'Metadata diagnostic failed: '..tostring(result):sub(1,160) end
        self.pathDiagnostic=result
        return result
    end
    local function visible(x)
        while x and x~=game do
            if x:IsA('ScreenGui') and not x.Enabled then return false end
            if x:IsA('GuiObject') and not x.Visible then return false end
            x=x.Parent
        end
        return true
    end
    function A:result()
        local root=child(child(LP,'PlayerGui'),'ResultsUI')
        if not root or not visible(root) then self.resultHidden=true;return false,'unknown',{} end
        local queue={{root,0}};local cursor=1;local texts={};local complete=true
        -- Bounded walk of the known ResultsUI ONLY; no full PlayerGui traversal.
        while cursor<=#queue and cursor<=200 do
            local row=queue[cursor];local x,depth=row[1],row[2];cursor+=1
            if visible(x) then
                if x:IsA('TextLabel') or x:IsA('TextButton') then
                    local txt=x.Text:gsub('<.->',''):sub(1,100)
                    if #texts<40 then texts[#texts+1]=txt else complete=false end
                end
                local kids=x:GetChildren()
                if depth>=6 and #kids>0 then complete=false end
                if depth<6 then
                    for i,v in ipairs(kids) do
                        if i>40 or #queue>=200 then complete=false;break end
                        queue[#queue+1]={v,depth+1}
                    end
                end
            end
        end
        if cursor<=#queue then complete=false end
        local finished=scalar(child(WS,'_DATA'),{'GameFinished'})==true
        local trusted=complete and (self.resultHidden or finished) and self.lastWave>0
        return true,trusted and C.outcome(texts) or 'unknown',texts
    end
    function A:remote(name)
        local r=child(child(RS,'endpoints'),'client_to_server')
        r=child(r,name)
        return r and (r:IsA('RemoteFunction') or r:IsA('RemoteEvent')) and r or nil
    end
    function A:watchResults()
        self:watchWaveOffers()
        if not self.alive then return false end
        if self.resultConnection then return true end
        local event=child(child(child(RS,'endpoints'),'server_to_client'),'game_finished')
        if not event or not event:IsA('RemoteEvent') then self.resultWatchState='unavailable';return false end
        local token={};self.resultWatchToken=token
        local ok,connection=pcall(function()
            return event.OnClientEvent:Connect(function(data)
                if not self.alive or self.resultWatchToken~=token then return end
                local w=number(WS,{'_wave_num'}) or 0
                if w<=0 or not self.stage then self.resultEventReport='Event outside an identified active round';return end
                local victory
                if type(data)=='table' then victory=rawget(data,'victory') end
                if type(victory)~='boolean' then self.resultEventReport='Unsupported victory type='..type(victory);return end
                local outcome=victory and 'Victory' or 'Defeat';local run=tostring(self.run)
                local previous=self.resultEvent
                if previous and previous.run==run and previous.stage==self.stage then
                    if previous.outcome~=outcome then previous.ambiguous=true;self.resultEventReport='Conflicting result events' end
                    return
                end
                self.resultEvent={run=run,stage=self.stage,outcome=outcome,at=os.clock(),wave=w}
                self.resultEventReport='Boolean '..outcome..' event; requires current finished marker'
                log:add('RESULT EVENT',outcome..' | waiting for current finished marker')
            end)
        end)
        if not ok or not connection then self.resultWatchToken=nil;self.resultWatchState='unavailable';return false end
        self.resultConnection=connection;self.resultWatchState='on';return true
    end
    function A:stopResultWatch()
        if self.skipConnection then pcall(function() self.skipConnection:Disconnect() end);self.skipConnection=nil end
        self.resultWatchToken=nil
        if self.resultConnection then pcall(function() self.resultConnection:Disconnect() end) end
        self.resultConnection=nil;self.resultWatchState='off'
    end
    function A:watchWaveOffers()
        if self.skipConnection or not self.alive then return end
        local event=child(child(child(RS,'endpoints'),'server_to_client'),'start_vote_wave_skip')
        if not event or not event:IsA('RemoteEvent') then return end
        local ok,conn=pcall(function() return event.OnClientEvent:Connect(function()
            if not self.alive or not self.stage then return end
            self.skipSerial=(self.skipSerial or 0)+1
            self.skipOffer={token=tostring(self.run)..':'..self.skipSerial,wave=number(WS,{'_wave_num'}),
                at=os.clock(),roundToken=self.roundToken}
        end) end)
        if ok then self.skipConnection=conn end
    end
    function A:busy()
        -- Some executors retain globals across teleports. An old server's
        -- outstanding call cannot mutate this verified different server.
        local job=game.JobId
        if type(job)=='string' and job~='' then
            for _,key in ipairs({'K_AA_NETWORK_PENDING','K_AA_CLIENT_CACHE_PENDING'}) do
                local mark=env[key]
                if type(mark)=='table' and type(mark.jobId)=='string' and mark.jobId~='' and mark.jobId~=job then env[key]=nil end
            end
        end
        return env.K_AA_NETWORK_PENDING~=nil or env.K_AA_CLIENT_CACHE_PENDING~=nil
    end
    local function acceptLevel(self,data,source)
        if type(data)~='table' then return false end
        local id=rawget(data,'id') or rawget(data,'level_id')
        if (type(id)~='string' and type(id)~='number') or tostring(id)=='' then return false end
        self.stage=tostring(id):sub(1,100);self.stageSource=source
        self.levelData=data
        local name=rawget(data,'name') or rawget(data,'level_name')
        self.stageName=type(name)=='string' and name:sub(1,100) or self.stage
        local mode=rawget(data,'mode') or rawget(data,'gamemode') or rawget(data,'_gamemode')
        local modes={story='Story',infinite='Infinite',challenge='Challenge',dungeon='Dungeon',
            raid='Raid',portal='Portal',event='Event',legend='Legend'}
        self.mode=type(mode)=='string' and modes[mode:lower()] or nil
        -- Paid/special contexts take precedence over a generic gamemode.
        if rawget(data,'_dungeon') then self.mode='Dungeon'
        elseif rawget(data,'_is_map_or_portal_level') then self.mode='Portal'
        elseif rawget(data,'_event_contract') then self.mode='Event' end
        return true
    end
    function A:issue(kind,args,geometry)
        if not self.alive or self:busy() then return false,'Transport busy/closed' end
        if kind~='map' and type(env.ZenoHub)=='table' then return false,'Close Zeno before native automation' end
        if kind~='map' then
            local previous=self.roundToken;local current=syncRound(self)
            if previous and current~=previous then return false,'Native round changed; refresh before sending' end
            if self:mutationFenced() then return false,'Prior mutation lacks exact feedback in this round; enter a fresh match' end
        end
        local remote
        if kind=='map' then remote=child(child(WS,'_MAP_CONFIG'),'GetLevelData')
        elseif kind=='dungeon' then remote=self:remote(geometry.endpoint)
        else remote=self:remote(({place='spawn_unit',upgrade='upgrade_unit_ingame',replay='set_game_finished_vote',
            start='vote_start',lobby='teleport_back_to_lobby',priority='change_priority',next='set_game_finished_vote',ability='use_active_attack',
            skip='vote_wave_skip',sell='sell_unit_ingame'})[kind]) end
        if not remote or not (remote:IsA('RemoteFunction') or remote:IsA('RemoteEvent')) then
            return false,'Required observed endpoint unavailable'
        end
        local mark={kind=kind,at=os.clock(),run=self.run,jobId=game.JobId}
        if kind~='map' then
            mark.feedbackToken={};mark.feedbackState='awaiting exact readback'
            env.K_AA_MUTATION_FEEDBACK={roundToken=self.roundToken,token=mark.feedbackToken,kind=kind}
            mark.endpoint=remote.Name;mark.reply='pending'
            mark.redactUuid=geometry and geometry.uuid or (type(args[1])=='string' and args[1] or nil)
            if geometry and geometry.recorded and geometry.pos then
                mark.geometry={recorded=table.clone(geometry.recorded),pos=table.clone(geometry.pos),source=geometry.source}
            end
            self.lastMutation=mark;watchMessages(self,mark)
        end
        env.K_AA_NETWORK_PENDING=mark
        local thread=task.spawn(function()
            local ok,res,extra=pcall(function()
                if remote:IsA('RemoteFunction') then return remote:InvokeServer(table.unpack(args)) end
                remote:FireServer(table.unpack(args));return nil
            end)
            if env.K_AA_NETWORK_PENDING==mark then env.K_AA_NETWORK_PENDING=nil end
            if not self.alive then return end
            if kind=='map' then
                if self.run==mark.run then self.mapRequested=false end
                if ok and type(res)=='table' and self.run==mark.run and not mark.expired
                    and os.clock()-mark.at<=8 then
                    if acceptLevel(self,res,'GetLevelData observed') then
                        self.mapStatus='Stage read succeeded'
                        log:add('STAGE',self.stage..' | '..self.stageName)
                    else self.mapStatus='Stage response had no supported ID' end
                else self.mapStatus='Stage read failed/expired';log:add('MAP READ','No current stage evidence') end
            else
                mark.elapsed=os.clock()-mark.at;mark.late=mark.expired or mark.elapsed>8
                mark.reply=(remote:IsA('RemoteEvent') and 'event sent; no reply' or replyText(res,mark.redactUuid))..
                    ' | extra='..replyText(extra,mark.redactUuid)
                mark.callOK=ok
                log:add('REMOTE REPLY',kind..' | run='..mark.run..' | '..(ok and '' or 'error | ')..mark.reply)
                local structuredFailure=type(res)=='table' and (rawget(res,'success')==false or rawget(res,'ok')==false)
                if self.run==mark.run and not mark.late and (not ok or res==false or structuredFailure) then
                    self.failures[#self.failures+1]='Remote '..kind..' rejected/error | '..mark.reply:sub(1,220)
                end
            end
        end)
        mark.thread=thread
        return true,nil,mark.feedbackToken
    end
    function A:poll()
        if self.messageMark and (self.run~=self.messageMark.run or os.clock()-self.messageMark.at>8) then disconnectMessages(self) end
        local cache=env.K_AA_CLIENT_CACHE_PENDING
        if cache and not cache.expired and os.clock()-cache.at>8 then
            cache.expired=true;self.cacheDone=true
            self.cacheReport='CLIENT CACHE READER: timeout; pending cache request remains locked; no retry'
            return self.cacheReport
        end
        local m=env.K_AA_NETWORK_PENDING
        if m and not m.expired and os.clock()-m.at>8 then
            m.expired=true
            -- The server request cannot be undone. Keep global lock until it returns.
            self.failures[#self.failures+1]='Remote timeout: '..m.kind..'; outstanding request locked'
        end
        return table.remove(self.failures,1)
    end
    function A:observe(now)
        local folder=child(WS,'_UNITS');local waveNode=child(WS,'_wave_num')
        local w=number(WS,{'_wave_num'}) or 0
        local mapConfig=child(WS,'_MAP_CONFIG');local mapModel=child(WS,'_map') or child(WS,'_MAP')
        local started=scalar(WS,{'_waves_started'})
        local finished=scalar(child(WS,'_DATA'),{'GameFinished'})
        local level=type(self.loaderExport)=='table' and rawget(self.loaderExport,'LevelData') or nil
        if type(level)~='table' then level=nil end
        -- The user's live lobby also contains _UNITS and _wave_num. Those alone
        -- are insufficient evidence of a match. These markers are observations,
        -- not a rule inferred from the selected Dungeon preset.
        local lobby=w==0 and started~=true and child(WS,'_LOBBIES')~=nil
            and (child(WS,'_EVOLVE')~=nil or child(WS,'_traits')~=nil)
        local context=lobby and 'Lobby (observed markers)' or
            (folder~=nil and waveNode~=nil and 'Match objects observed' or 'Unknown')
        syncRound(self,{waveNode=waveNode,w=w,started=started,finished=finished,
            context=lobby and 'Lobby' or folder and waveNode and 'Match' or 'Unknown'})
        if folder~=self.lastFolder or w<self.lastWave or mapConfig~=self.lastConfig
            or mapModel~=self.lastMap or waveNode~=self.lastWaveNode
            or context~=self.lastContext
            or (level and self.lastLevelData and level~=self.lastLevelData)
            or (started==false and self.lastStarted==true)
            or (finished==false and self.lastFinished==true) then
            self.run+=1;self.lastFolder=folder;self.stage=nil;self.mode=nil;self.levelData=nil
            self.stageSource='unknown';self.stageName=nil;self.resultHidden=false;self.mapRequested=false
            self.staleLevelData=self.lastLevelData;self.mapAttempts=0;self.nextMapTry=0;self.mapStatus='Not read yet'
            self.mapDeadline=now+30
            self.resultEvent=nil
            self.resultEventReport='No current-round result event'
            self.path={};self.previous=setmetatable({},{__mode='k'})
            self.nextInventory=0
        end
        self.lastConfig=mapConfig;self.lastMap=mapModel;self.lastWaveNode=waveNode
        self.lastContext=context
        self.lastStarted=started;self.lastFinished=finished
        self.lastWave=w
        if level then self.lastLevelData=level end
        if not lobby and folder and waveNode and level and level~=self.staleLevelData then
            acceptLevel(self,level,'Loader.LevelData observed')
        end
        if now>=self.nextInventory then self:refreshInventory(now) end
        local modifiers=child(child(WS,'_DATA'),'LevelModifiers')
        local costScale=numericValue(modifiers,'player_cost_scale')
        if not C.finite(costScale) or costScale<=0 or costScale>100 then costScale=nil end
        local function costs(u)
            local def=type(self.definitions)=='table' and rawget(self.definitions,u.id) or nil
            if type(def)~='table' then return end
            local farm=rawget(def,'farm_amount');local damage=rawget(def,'damage');local spa=rawget(def,'attack_cooldown')
            local unsellable=rawget(def,'unsellable')
            u.sellable=u.id~='bulma' and unsellable==false
            local cap=rawget(def,'spawn_cap')
            if C.finite(cap) and cap>=1 and cap<=100 and cap%1==0 then u.spawnCap=cap end
            if C.hasTrait(u,'Unique') then u.spawnCap=1 end
            local range=rawget(def,'range')
            if C.finite(range) and range>0 and range<=1000 then u.planningRange=range end
            if C.finite(farm) and farm>0 then u.role='farm';u.roleSource='Units.farm_amount'
            elseif rawget(def,'_show_as_buff_unit')==true then u.role='buff';u.roleSource='Units buff flag'
            elseif (C.finite(u.damage) and u.damage>0 and C.finite(u.spa) and u.spa>0)
                or (C.finite(damage) and damage>0 and C.finite(spa) and spa>0) then
                u.role='combat';u.roleSource='Observed/defined attack stats'
            else u.role='unknown';u.roleSource='Unclassified' end
            local upgrades=rawget(def,'upgrade')
            if C.finite(u.maxLevel) and (u.maxLevel<0 or u.maxLevel%1~=0) then u.maxLevel=nil end
            if not C.finite(u.maxLevel) and type(upgrades)=='table' then
                local last,gap,valid=0,false,true
                for i=1,40 do
                    local step=rawget(upgrades,i)
                    if step==nil then gap=true
                    elseif gap or type(step)~='table' then valid=false;break
                    else last=i end
                end
                if valid and rawget(upgrades,41)==nil and last<40 then u.maxLevel=last;u.maxLevelSource='Units.upgrade contiguous data' end
            elseif C.finite(u.maxLevel) then u.maxLevelSource='Observed max_upgrade' end
            local base=rawget(def,'cost')
            if C.finite(base) and base>0 then
                u.baseCost=base
                if u.cost==nil and costScale then
                    u.cost=base*costScale;u.costSource='Units.cost × observed player_cost_scale'
                end
            end
            if u.nextCost==nil and C.finite(u.level) and u.level>=0 and u.level<=40 and u.level%1==0 then
                local step=type(upgrades)=='table' and rawget(upgrades,u.level+1) or nil
                local nextCost=type(step)=='table' and rawget(step,'cost') or nil
                if C.finite(nextCost) and nextCost>0 and costScale then
                    u.nextCost=nextCost*costScale;u.nextCostSource='Units.upgrade × observed player_cost_scale'
                end
            end
        end
        -- Snapshot copies: a disappearing modifier cannot leave old effective
        -- costs stuck in the retained collection cache.
        local roster={}
        for _,u in ipairs(self.roster) do
            local copy=table.clone(u);costs(copy);roster[#roster+1]=copy
        end
        local units={};self.models={};local unitsComplete=true
        local enemyUnits={};local enemyComplete=true
        local csOK,collection=pcall(function() return game:GetService('CollectionService') end)
        if not csOK or not collection then enemyComplete=false end
        local scan={total=0,examined=0,own=0,missingIdentity=0,missingPosition=0}
        if folder then
            local children=folder:GetChildren();unitsComplete=#children<=120
            scan.total=#children
            for i,m in ipairs(children) do
                if i>120 then break end
                scan.examined+=1
                if m:IsA('Model') and own(m) then
                    scan.own+=1
                    local u=record(m,'battle')
                    if u then
                        costs(u);u.key=m;u.pos=point(m);self.models[m]=m;units[#units+1]=u
                        if C.distance(u.pos,u.pos)~=0 then scan.missingPosition+=1 end
                    else scan.missingIdentity+=1 end
                elseif m:IsA('Model') and collection then
                    local tagOK,tagged=pcall(function() return collection:HasTag(m,'pve_units') end)
                    local stats=child(m,'_stats');local owner=child(stats,'player')
                    if not tagOK then enemyComplete=false
                    elseif tagged and owner and owner:IsA('ObjectValue') and owner.Value==nil then
                        local hum=m:FindFirstChildOfClass('Humanoid')
                        local id=stringValue(stats,{'id'})
                        local bossId=type(self.levelData)=='table' and rawget(self.levelData,'boss')
                        local enemy={id=id,pos=point(m),health=hum and hum.Health}
                        if type(bossId)=='string' and id~=nil then enemy.boss=id==bossId end
                        enemyUnits[#enemyUnits+1]=enemy
                    end
                end
            end
        end
        if scan.missingIdentity>0 or scan.missingPosition>0 then unitsComplete=false end
        local owned=table.clone(self.owned);local known={}
        for _,u in ipairs(owned) do known[u.uuid]=true end
        for _,u in ipairs(units) do if not known[u.uuid] then owned[#owned+1]=u;known[u.uuid]=true end end
        local money,moneySource
        if cfg.cashPath and cfg.cashPath~='' then
            local m=path(cfg.cashPath,false)
            if m and m:IsA('ValueBase') then money=tonumber(m.Value);moneySource='user-bound match currency' end
        else
            for _,root in pairs({LP,child(LP,'_stats'),child(LP,'leaderstats')}) do
                money=number(root,{'yen','Yen','money','Money','cash','Cash'})
                if money~=nil then moneySource='local player currency';break end
            end
        end
        if not C.finite(money) then money=nil end
        local wallet,walletSources={},{}
        local playerStats=child(LP,'_stats')
        for label,key in pairs({Gold='gold_amount',Gems='gem_amount',SummerPearls='_resourceSummerPearls'}) do
            local amount=numericValue(playerStats,key)
            if amount~=nil then wallet[label]=amount;walletSources[label]='player/_stats/'..key end
        end
        -- Historical primary implementations use resource for match money.
        -- The same field in a lobby is never sufficient match evidence.
        local rawResource=numericValue(playerStats,'resource')
        if money==nil and (not cfg.cashPath or cfg.cashPath=='') and not lobby
            and folder and waveNode and (w>0 or started==true or self.stage~=nil)
            and rawResource~=nil and rawResource>=0 then
            money=rawResource;moneySource='player/_stats/resource (match only)'
        end
        local enemies=child(WS,'_ENEMIES');local count=0
        if enemies then
            for i,m in ipairs(enemies:GetChildren()) do
                if i>50 then break end
                if m:IsA('Model') then
                    count+=1;local p=point(m);local old=self.previous[m]
                    if p and old and C.distance(p,old)>1 then
                        self.path[#self.path+1]=p;if #self.path>80 then table.remove(self.path,1) end
                    end
                    self.previous[m]=p
                end
            end
        end
        local show,outcome,texts=self:result()
        local outcomeSource=outcome~='unknown' and 'Visible ResultsUI' or 'unknown'
        local resultEvent=self.resultEvent
        if resultEvent and resultEvent.run==tostring(self.run) and resultEvent.stage==self.stage
            and finished==true and now>=resultEvent.at and now-resultEvent.at<=10 and w>=resultEvent.wave then
            show=true
            if resultEvent.ambiguous or (outcome~='unknown' and outcome~=resultEvent.outcome) then
                outcome='unknown';outcomeSource='Conflicting result evidence'
            else outcome=resultEvent.outcome;outcomeSource='game_finished.victory + GameFinished' end
        end
        local dungeon={valid=false,reason='Named Dungeon cache exports unavailable'}
        local bindings=self.dungeonBindings
        if type(bindings)=='table' then
            local service=inventoryParser.current(bindings.DungeonServiceClient)
            local core=inventoryParser.current(bindings.DungeonServiceCore)
            local validOwner=true
            for _,root in pairs({service,type(service)=='table' and rawget(service,'session')}) do
                if type(root)=='table' then
                    local profile=rawget(root,'profile_data')
                    for _,ownerSource in pairs({root,profile}) do
                        if type(ownerSource)=='table' then
                            for _,key in ipairs({'user_id','player_id','UserId'}) do
                                local id=rawget(ownerSource,key)
                                if id~=nil and ((type(id)~='number' and type(id)~='string') or tonumber(id)~=LP.UserId) then validOwner=false end
                            end
                        end
                    end
                end
            end
            if validOwner then dungeon=dungeonParser.snapshot(service,core,self.levelData)
            else dungeon={valid=false,reason='Dungeon cache owner mismatch'} end
            if dungeon.valid and dungeon.phase.kind=='Shop' and cfg.dungeonShopCap>0 and type(core)=='table' then
                local helper=rawget(core,'sum_item_values')
                local session=type(service)=='table' and rawget(service,'session')
                local profile=type(session)=='table' and rawget(session,'profile_data')
                local raw=type(profile)=='table' and rawget(profile,'dungeon_data')
                -- Read-only calculation from the already-loaded core export,
                -- exactly once per observed shop state. Never a service getter.
                if self.shopQuoteToken~=dungeon.stateToken then
                    self.shopQuoteToken=dungeon.stateToken;self.shopQuoteScale=nil
                    if type(helper)=='function' then
                        local ok,value=pcall(helper,raw,'shop_prices')
                        if ok and C.finite(value) and value>=-1 and value<=100 then self.shopQuoteScale=value+1 end
                    end
                end
                if self.shopQuoteScale then
                    for _,offer in ipairs(dungeon.phase.offers) do
                        if offer.price==nil and C.finite(offer.baseCost) and offer.baseCost>=0 then
                            offer.price=math.ceil(offer.baseCost*self.shopQuoteScale)
                            offer.priceSource='Loaded Dungeon core shop_prices calculation × item cost'
                        end
                    end
                end
            end
        end
        local nextStoryId
        if cfg.autoNextStory==true and self.mode=='Story' and type(self.levelData)=='table'
            and rawget(self.levelData,'_is_actual_storymode')==true then
            local core=bindings and inventoryParser.current(bindings.ProgressionServiceCore)
            local fn=type(core)=='table' and rawget(core,'get_next_story_level')
            if type(fn)=='function' then
                local ok,nextLevel=pcall(fn,self.stage)
                local id=ok and (type(nextLevel)=='table' and rawget(nextLevel,'id') or nextLevel)
                if type(id)=='string' and #id>0 and #id<=100 and id~=self.stage then nextStoryId=id end
            end
        end
        local s={now=now,run=tostring(self.run),inMatch=folder~=nil and waveNode~=nil and not lobby,context=context,
            started=scalar(WS,{'_waves_started'})==true or w>0,stage=self.stage or 'unknown',
            stageName=self.stageName or 'unknown',stageVerified=self.stage~=nil,stageSource=self.stageSource,
            mode=self.mode or cfg.mode or 'Unknown',modeVerified=self.mode~=nil,
            placeId=game.PlaceId,wave=w,cash=money,cashSource=moneySource,units=units,unitsComplete=unitsComplete,
            towerScan=scan,
            roundToken=self.roundToken,mutationFence=self:mutationFenced(),
            externalControllerActive=type(env.ZenoHub)=='table',jobId=game.JobId,
            observedLobby=lobby==true,
            nextStoryId=nextStoryId,
            dungeon=dungeon,dungeonAt=dungeon.valid and now or nil,
            voteStartFinished=scalar(child(child(WS,'_DATA'),'VoteStart'),{'VotingFinished'}),
            skipFinished=scalar(child(child(WS,'_DATA'),'VoteSkip'),{'VotingFinished'}),
            skipOffer=self.skipOffer and self.skipOffer.roundToken==self.roundToken and now-self.skipOffer.at<=30 and self.skipOffer or nil,
            wallet=wallet,walletSources=walletSources,rawResource=rawResource,
            owned=owned,ownedAt=#owned>0 and now or self.ownedAt,roster=roster,rosterAt=self.rosterAt,
            rosterComplete=self.rosterComplete,equippedDeclared=self.equippedDeclared,
            costScale=costScale,definitionsAvailable=self.definitions~=nil,mapStatus=self.mapStatus,
            resources=self.resources,resourcesAt=self.resourcesAt,resultVisible=show or finished==true,outcome=outcome,outcomeSource=outcomeSource,
            resultTexts=texts,enemies=count,enemyUnits=enemyUnits,enemiesComplete=enemyComplete and unitsComplete,
            pathSamples=#self.path,transportBlocked=self:busy(),
            inventorySource=self.inventorySource}
        if s.inMatch and not s.stageVerified and not self.mapRequested and not self:busy()
            and now>=self.nextMapTry and (self.mapAttempts or 0)<3 and now<=(self.mapDeadline or now) then
            self.nextMapTry=now+3
            local sent,why=self:issue('map',{})
            if sent then self.mapAttempts=(self.mapAttempts or 0)+1 end
            -- task.spawn may finish synchronously. The transport lock, rather
            -- than its return value, determines whether a request is pending.
            self.mapRequested=sent and env.K_AA_NETWORK_PENDING~=nil
            if self.mapRequested then self.mapStatus='Stage request pending'
            elseif not sent then self.mapStatus=why end
        end
        return s
    end
    function A:dispatch(action)
        if action.kind=='place' then
            local pos,why=self:placementSurface(action.pos,action.id)
            if not pos then return false,'Placement blocked: '..tostring(why) end
            return self:issue('place',{action.uuid,CFrame.new(table.unpack(pos))},
                {recorded=action.pos,pos=pos,source=why,uuid=action.uuid})
        elseif action.kind=='upgrade' and self.models[action.key] then
            local model=self.models[action.key];local u=record(model,'battle')
            return self:issue('upgrade',{model},{uuid=action.uuid or (u and u.uuid)})
        elseif action.kind=='replay' then return self:issue('replay',{'replay'})
        elseif action.kind=='start' then
            if cfg.autoStartWaves~=true then return false,'Auto start waves permission is OFF' end
            return self:issue('start',{})
        elseif action.kind=='lobby' then
            if cfg.autoReturnLobby~=true then return false,'Automatic lobby-return permission is OFF' end
            return self:issue('lobby',{})
        elseif action.kind=='next' then
            if cfg.autoNextStory~=true then return false,'Next Story permission is OFF' end
            return self:issue('next',{'next_story'})
        elseif action.kind=='priority' then
            if not table.find({'first','last','strongest','weakest','closest','farthest'},action.target)
                or (action.target~=cfg.autoTarget and action.target~=cfg.autoBossTarget and not (action.macro and cfg.macroSession)) or not self.models[action.key] then
                return false,'Unsupported target setting or unknown own model'
            end
            return self:issue('priority',{self.models[action.key],action.target},{uuid=action.uuid})
        elseif action.kind=='ability' then
            local model=self.models[action.key];local u=model and record(model,'battle')
            if (cfg.autoAbilities~=true and not (action.macro and cfg.macroSession)) or not u or u.uuid~=action.uuid or u.id~=action.id or not u.castReady
                or type(u.activeAttack)~='string' or u.activeAttack=='' or u.activeAttack=='nil' or u.activeAttack:find(':',1,true) then
                return false,'Exact equipped ready normal ability unavailable'
            end
            return self:issue('ability',{model},{uuid=u.uuid})
        elseif action.kind=='skip' then
            local offer=self.skipOffer
            if (cfg.autoSkip~=true and not (action.macro and cfg.macroSession)) or not offer or action.offerToken~=offer.token or action.wave~=offer.wave
                or number(WS,{'_wave_num'})~=action.wave or offer.roundToken~=self.roundToken
                or scalar(child(child(WS,'_DATA'),'VoteSkip'),{'VotingFinished'})~=false then return false,'Current skip offer/readback unavailable' end
            return self:issue('skip',{})
        elseif action.kind=='sell' then
            local model=self.models[action.key];local u=model and record(model,'battle')
            local def=u and self.definitions and rawget(self.definitions,u.id)
            if not u or u.uuid~=action.uuid or u.id~=action.id or u.id=='bulma' or type(def)~='table'
                or rawget(def,'unsellable')~=false or ((cfg.sellAllWave or 0)<=0 and (cfg.sellFarmWave or 0)<=0 and not (action.macro and cfg.macroSession)) then
                return false,'Sale policy or exact sellability unavailable'
            end
            return self:issue('sell',{model},{uuid=u.uuid})
        elseif action.kind=='dungeon' then
            if cfg.dungeonConsent~=true then return false,'Dungeon session not explicitly armed' end
            local name,args=action.name,action.args
            if type(args)~='table' then return false,'Dungeon payload missing' end
            local allowed=false
            if name=='dungeon_enter_room' then allowed=#args==1 and (args[1]=='1' or args[1]=='2' or args[1]=='3')
            elseif name=='dungeon_continue_shop' then allowed=#args==0
            elseif name=='dungeon_open_chest' then
                allowed=cfg.dungeonOpenChests==true and (#args==0 or (#args==1 and args[1]==true))
            elseif name=='dungeon_buy_shop' then
                allowed=cfg.dungeonShopCap>0 and #args==1 and C.finite(args[1]) and args[1]>=1 and args[1]<=32 and args[1]%1==0
            elseif name=='dungeon_shrine_accept' then allowed=cfg.dungeonShrines==true and #args==0
            end
            if not allowed then return false,'Unsupported Dungeon action, payload or spending permission' end
            return self:issue('dungeon',args,{endpoint=name})
        end
        return false,'Unsupported action'
    end
    function A:combatReport(s)
        local function fmt(v) return v==nil and '?' or tostring(v) end
        local scan=s.towerScan or {}
        local rows={'COMBAT DATA (UUIDs omitted)',
            'Context='..fmt(s.context)..' | place='..fmt(s.placeId)..' | wave='..fmt(s.wave),
            'Stage='..fmt(s.stage)..' | source='..fmt(s.stageSource),
            'Mode='..fmt(s.mode)..' | observed='..fmt(s.modeVerified),
            'Cash='..fmt(s.cash)..' | source='..fmt(s.cashSource)..' | raw resource='..fmt(s.rawResource),
            'Loaded Units table='..fmt(s.definitionsAvailable)..' | player_cost_scale='..fmt(s.costScale),
            'Equipment complete='..fmt(s.rosterComplete)..' | declared slots='..fmt(s.equippedDeclared),
            'Map read='..fmt(self.mapStatus)..' | transport pending='..fmt(s.transportBlocked),
            'Unresolved mutation fence='..fmt(s.mutationFence)..' (survives reload within this executor)',
            'External Zeno loaded='..fmt(s.externalControllerActive)..' | native mutations blocked while loaded',
            'Dungeon cache='..fmt(s.dungeon and s.dungeon.valid)..' | reason='..fmt(s.dungeon and s.dungeon.reason),
            'Outcome='..fmt(s.outcome)..' | source='..fmt(s.outcomeSource)..' | result observer='..fmt(self.resultWatchState)..
                ' | event='..fmt(self.resultEventReport),
            'Tower scan: examined='..fmt(scan.examined)..' / '..fmt(scan.total)..' | own='..fmt(scan.own)..
                ' | missing identity='..fmt(scan.missingIdentity)..' | missing position='..fmt(scan.missingPosition)}
        local roster={}
        for _,u in ipairs(s.roster or {}) do
            roster[u.uuid]=u
            rows[#rows+1]='Equipped slot='..fmt(u.slot)..' id='..fmt(u.id)..' | base cost='..fmt(u.baseCost)..
                ' | effective cost='..fmt(u.cost)..' | source='..fmt(u.costSource)..' | role='..fmt(u.role)
        end
        for i,u in ipairs(s.units or {}) do
            if i>24 then rows[#rows+1]='Additional towers omitted';break end
            local r=roster[u.uuid]
            rows[#rows+1]='Tower '..i..' id='..fmt(u.id)..' | exact equipped match='..
                tostring(r~=nil and r.id==u.id)..' | position='..tostring(u.pos~=nil)..' | upgrade='..fmt(u.level)..
                ' | next cost='..fmt(u.nextCost)..' | max='..fmt(u.maxLevel)..' | source='..fmt(u.nextCostSource)..
                ' | DMG='..fmt(u.damage)..' SPA='..fmt(u.spa)..' range='..fmt(u.range)
        end
        for _,kind in ipairs({'spawn_unit','upgrade_unit_ingame'}) do
            rows[#rows+1]='Endpoint '..kind..' present='..tostring(self:remote(kind)~=nil)
        end
        return table.concat(rows,'\n')..'\n'..self:actionReport()
    end
    function A:inspectPlacement(p,s)
        if not self.alive or not s.inMatch or not s.stageVerified or not C.contextMatches(p,s)
            or type(p.entries)~='table' or #p.entries~=1 then return end
        local e=p.entries[1]
        if type(e)=='table' then self:placementSurface(e.pos,e.id) end
    end
    function A:actionReport()
        local function pointText(p)
            return C.distance(p,p)==0 and string.format('(%.3f, %.3f, %.3f)',p[1],p[2],p[3]) or '?'
        end
        local rows={}
        local surface=self.lastSurfaceCheck
        if surface then
            rows[#rows+1]='SURFACE CHECK | run='..surface.run..' | '..surface.reason..
                ' | recorded='..pointText(surface.recorded)..' | surface='..pointText(surface.pos)..
                ' | source='..tostring(surface.source or '?')..' | normalY='..tostring(surface.normalY or '?')
        end
        local m=self.lastMutation
        if not m then rows[#rows+1]='LAST MUTATION REQUEST: none'
        else
            rows[#rows+1]='LAST MUTATION REQUEST | '..m.kind..' | run='..m.run..' | endpoint='..m.endpoint..
                ' | elapsed='..tostring(m.elapsed or '?')..' | late='..tostring(m.late or false)
            if m.geometry then rows[#rows+1]='SENT POSITION | recorded='..pointText(m.geometry.recorded)..
                ' | sent='..pointText(m.geometry.pos)..' | source='..m.geometry.source end
            rows[#rows+1]='RPC RESPONSE | '..m.reply..' | callOK='..tostring(m.callOK)..' | feedback='..tostring(m.feedbackState)
            rows[#rows+1]='SCOPED GAME MESSAGES | observer='..tostring(m.watchState)..' | count='..#m.messages
            for _,v in ipairs(m.messages) do rows[#rows+1]='GAME MESSAGE | '..v end
        end
        return table.concat(rows,'\n'):sub(1,3000)
    end
    function A:record(s,costText)
        if not s.inMatch or not s.stageVerified then return nil,'Stage identity unavailable' end
        if s.unitsComplete~=true then return nil,'Tower observation incomplete; recording disabled' end
        if not s.rosterAt or s.now-s.rosterAt>15 then return nil,'Equipped collection UUIDs unavailable' end
        local costs={}
        for i,token in ipairs(string.split(tostring(costText or ''),',')) do costs[i]=tonumber(token) end
        local roster={};for _,u in ipairs(s.roster) do roster[u.uuid]=u end
        local p={stage=s.stage,mode=s.mode,placeId=s.placeId,source='user-recorded',costScale=s.costScale,entries={}}
        for _,u in ipairs(s.units) do
            local r=roster[u.uuid]
            if not r or r.id~=u.id or not u.pos then return nil,'Cannot map every own tower to exact equipped UUID/position' end
            local cost=u.cost or r.cost or costs[r.slot]
            if not C.finite(cost) or cost<=0 then return nil,'Deployment cost missing; enter comma-separated costs by slot' end
            if #p.entries>=24 then return nil,'At most 24 recorded placements' end
            p.entries[#p.entries+1]={uuid=u.uuid,id=u.id,slot=r.slot,pos=u.pos,cost=cost,wave=0,
                costSource=u.costSource or (u.cost and 'observed battle') or r.costSource or
                    (r.cost and 'observed collection') or 'user-recorded'}
        end
        table.sort(p.entries,function(a,b)
            if a.slot~=b.slot then return a.slot<b.slot end
            return a.pos[1]==b.pos[1] and a.pos[3]<b.pos[3] or a.pos[1]<b.pos[1]
        end)
        if #p.entries==0 then return nil,'Place your team manually first' end
        return p
    end
    function A:recordTestTarget(s,slot)
        if not C.finite(slot) or slot%1~=0 or slot<1 or slot>8 then return nil,'Invalid equipped test slot' end
        local target
        for _,u in ipairs(s.roster or {}) do if u.slot==slot then target=u;break end end
        if not target then return nil,'Selected test slot has no exposed equipped record' end
        local matches={}
        for _,u in ipairs(s.units or {}) do
            if u.uuid==target.uuid and u.id==target.id then matches[#matches+1]=u end
        end
        if #matches~=1 then return nil,'Place exactly one copy from test slot '..slot..'; current copies='..#matches end
        local selected=table.clone(s);selected.units=matches
        local p,why=self:record(selected,cfg.recordCosts)
        if p then p.testSlot=slot end
        return p,why
    end
    function A:recordTeam(s,previous)
        if not s.modeVerified or s.mode~='Story' then return nil,'Record teams in an observed Story match' end
        local roster={};for _,u in ipairs(s.roster or {}) do roster[u.uuid]=u end
        local selected,byUUID,ignored={}, {},0
        for _,u in ipairs(s.units or {}) do
            local r=roster[u.uuid]
            if r and r.id==u.id then selected[#selected+1]=u;byUUID[u.uuid]=u else ignored+=1 end
        end
        if #selected==0 then return nil,'Place an equipped unit manually, then record the team' end
        local snapshot=table.clone(s);snapshot.units=selected
        local p,why=self:record(snapshot,cfg.recordCosts)
        if not p then return nil,why end
        p.kind='team-v1';p.ignoredOwn=ignored
        local function copyEntry(e)
            if type(e)~='table' or type(e.uuid)~='string' or type(e.id)~='string' or C.distance(e.pos,e.pos)~=0
                or not C.finite(e.cost) or e.cost<=0 then return nil end
            return {uuid=e.uuid,id=e.id,slot=e.slot,pos=table.clone(e.pos),cost=e.cost,costSource=e.costSource,
                wave=0,role=e.role,roleSource=e.roleSource}
        end
        for _,e in ipairs(p.entries) do
            local u=byUUID[e.uuid];local r=roster[e.uuid]
            e.role=u.role or r.role or ((C.finite(u.damage) and u.damage>0 and C.finite(u.spa) and u.spa>0) and 'combat' or 'unknown')
            e.roleSource=u.roleSource or r.roleSource or 'Observed attack stats / unclassified'
        end
        if type(previous)=='table' and previous.kind=='team-v1' and C.contextMatches(previous,s) then
            if previous.costScale~=s.costScale then return nil,'Cost modifier changed; capture a new full team profile' end
            if type(previous.entries)=='table' then
                for i,e in ipairs(previous.entries) do
                    if i>24 then return nil,'Previous profile exceeds 24 placements' end
                    local r=type(e)=='table' and roster[e.uuid]
                    if r and r.id==e.id and not byUUID[e.uuid] then
                        local copy=copyEntry(e)
                        if not copy then return nil,'Previous team profile contains an invalid target' end
                        p.entries[#p.entries+1]=copy
                    end
                end
            end
        end
        if #p.entries>24 then return nil,'At most 24 recorded team placements' end
        table.sort(p.entries,function(a,b)
            local ra,rb=roster[a.uuid],roster[b.uuid]
            if ra.slot~=rb.slot then return ra.slot<rb.slot end
            return a.pos[1]==b.pos[1] and a.pos[3]<b.pos[3] or a.pos[1]<b.pos[1]
        end)
        return p
    end
    function A:checkTeamSurface(p,s)
        if not C.contextMatches(p,s) or type(p.entries)~='table' or #p.entries<1 or #p.entries>24 then
            return false,'Invalid team stage/profile'
        end
        for i,e in ipairs(p.entries) do
            local pos,why=self:placementSurface(e.pos,e.id)
            if not pos then return false,'Target '..i..' '..tostring(e.id)..': '..tostring(why) end
        end
        return true
    end
    function A:close()
        disconnectMessages(self)
        self:stopResultWatch()
        self.alive=false;self.clientService=nil;self.clientBinding=nil;self.loaderExport=nil;self.definitions=nil
    end
    return A
end
