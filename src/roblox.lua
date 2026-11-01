-- Native observations only. Historical transport signatures remain EXPERIMENTAL.
return function(C, env, cfg, log)
    local Players=game:GetService('Players')
    local RS=game:GetService('ReplicatedStorage')
    local WS=game:GetService('Workspace')
    local LP=Players.LocalPlayer
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
        nextCost={'next_upgrade_cost','upgrade_cost'},level={'upgrade','upgrade_level'},
        takedowns={'takedowns','kills'},worthiness={'worthiness'},slot={'equipped_slot','equippedSlot'}}
    local function record(node,scope)
        local st=child(node,'_stats') or child(node,'stats') or node
        local u={uuid=stringValue(st,{'uuid','unique_id'}),id=stringValue(st,{'unit_id','unitId','id'}),
            trait=stringValue(st,{'trait','trait_name'}),statScope=scope,
            damageGrade=stringValue(st,{'damage_grade','damageGrade'}),
            spaGrade=stringValue(st,{'spa_grade','spaGrade'}),
            rangeGrade=stringValue(st,{'range_grade','rangeGrade'})}
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
        self.owned=units;self.roster=roster
        self.ownedAt=#roots>0 and now or nil;self.rosterAt=#roster>0 and now or nil
        self.inventorySource=#roots>0 and 'partial player-replicated collection' or 'not exposed through configured paths'
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
        self.resources=resources;self.resourcesAt=r and now or nil
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
    function A:busy() return env.K_AA_NETWORK_PENDING~=nil end
    function A:issue(kind,args)
        if not self.alive or self:busy() then return false,'Transport busy/closed' end
        local remote
        if kind=='map' then remote=child(child(WS,'_MAP_CONFIG'),'GetLevelData')
        else remote=self:remote(({place='spawn_unit',upgrade='upgrade_unit_ingame',replay='set_game_finished_vote'})[kind]) end
        if not remote or not (remote:IsA('RemoteFunction') or remote:IsA('RemoteEvent')) then
            return false,'Required observed endpoint unavailable'
        end
        local mark={kind=kind,at=os.clock(),run=self.run}
        env.K_AA_NETWORK_PENDING=mark
        local thread=task.spawn(function()
            local ok,res=pcall(function()
                if remote:IsA('RemoteFunction') then return remote:InvokeServer(table.unpack(args)) end
                remote:FireServer(table.unpack(args));return nil
            end)
            if env.K_AA_NETWORK_PENDING==mark then env.K_AA_NETWORK_PENDING=nil end
            if not self.alive then return end
            if kind=='map' then
                if ok and type(res)=='table' and self.run==mark.run and not mark.expired then
                    local id=res.id or res.level_id
                    if type(id)=='string' or type(id)=='number' then
                        self.stage=tostring(id):sub(1,100);self.stageSource='GetLevelData observed'
                        self.stageName=tostring(res.name or res.level_name or id):sub(1,100)
                        local mode=res.mode or res.gamemode
                        if table.find({'Story','Infinite','Challenge','Dungeon','Raid','Portal','Event','Legend'},mode) then self.mode=mode end
                        log:add('STAGE',self.stage..' | '..self.stageName)
                    end
                else log:add('MAP READ','No current stage evidence') end
            elseif not ok or res==false then
                self.failures[#self.failures+1]='Remote '..kind..' rejected/error'
            end
        end)
        mark.thread=thread
        return true
    end
    function A:poll()
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
        local mapConfig=child(WS,'_MAP_CONFIG');local mapModel=child(WS,'_MAP')
        local started=scalar(WS,{'_waves_started'})
        local finished=scalar(child(WS,'_DATA'),{'GameFinished'})
        -- The user's live lobby also contains _UNITS and _wave_num. Those alone
        -- are insufficient evidence of a match. These markers are observations,
        -- not a rule inferred from the selected Dungeon preset.
        local lobby=w==0 and started~=true and child(WS,'_LOBBIES')~=nil
            and (child(WS,'_EVOLVE')~=nil or child(WS,'_traits')~=nil)
        local context=lobby and 'Lobby (observed markers)' or
            (folder~=nil and waveNode~=nil and 'Match objects observed' or 'Unknown')
        if folder~=self.lastFolder or w<self.lastWave or mapConfig~=self.lastConfig
            or mapModel~=self.lastMap or waveNode~=self.lastWaveNode
            or context~=self.lastContext
            or (started==false and self.lastStarted==true)
            or (finished==false and self.lastFinished==true) then
            self.run+=1;self.lastFolder=folder;self.stage=nil;self.mode=nil
            self.stageSource='unknown';self.stageName=nil;self.resultHidden=false;self.mapRequested=false
            self.path={};self.previous=setmetatable({},{__mode='k'})
            self.nextInventory=0
        end
        self.lastConfig=mapConfig;self.lastMap=mapModel;self.lastWaveNode=waveNode
        self.lastContext=context
        self.lastStarted=started;self.lastFinished=finished
        self.lastWave=w
        if now>=self.nextInventory then self:refreshInventory(now) end
        local units={};self.models={};local unitsComplete=true
        if folder then
            local children=folder:GetChildren();unitsComplete=#children<=120
            for i,m in ipairs(children) do
                if i>120 then break end
                if m:IsA('Model') and own(m) then
                    local u=record(m,'battle')
                    if u then
                        u.key=m;u.pos=point(m);self.models[m]=m;units[#units+1]=u
                    end
                end
            end
        end
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
        -- resource was observed, but its meaning is not established by a lobby
        -- field name. It must not silently satisfy the match-Yen readiness gate.
        local rawResource=numericValue(playerStats,'resource')
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
        local s={now=now,run=tostring(self.run),inMatch=folder~=nil and waveNode~=nil and not lobby,context=context,
            started=scalar(WS,{'_waves_started'})==true or w>0,stage=self.stage or 'unknown',
            stageName=self.stageName or 'unknown',stageVerified=self.stage~=nil,stageSource=self.stageSource,
            mode=self.mode or cfg.mode or 'Unknown',modeVerified=self.mode~=nil,
            placeId=game.PlaceId,wave=w,cash=money,cashSource=moneySource,units=units,unitsComplete=unitsComplete,
            wallet=wallet,walletSources=walletSources,rawResource=rawResource,
            owned=owned,ownedAt=#owned>0 and now or self.ownedAt,roster=self.roster,rosterAt=self.rosterAt,
            resources=self.resources,resourcesAt=self.resourcesAt,resultVisible=show or finished==true,outcome=outcome,
            resultTexts=texts,enemies=count,pathSamples=#self.path,transportBlocked=self:busy(),
            inventorySource=self.inventorySource}
        if s.inMatch and not self.mapRequested and not self:busy() then
            self.mapRequested=true;self:issue('map',{})
        end
        return s
    end
    function A:dispatch(action)
        if action.kind=='place' then
            return self:issue('place',{action.uuid,CFrame.new(table.unpack(action.pos))})
        elseif action.kind=='upgrade' and self.models[action.key] then
            return self:issue('upgrade',{self.models[action.key]})
        elseif action.kind=='replay' then return self:issue('replay',{'replay'}) end
        return false,'Unsupported action'
    end
    function A:record(s,costText)
        if not s.inMatch or not s.stageVerified then return nil,'Stage identity unavailable' end
        if s.unitsComplete~=true then return nil,'Tower observation incomplete; recording disabled' end
        if not s.rosterAt or s.now-s.rosterAt>15 then return nil,'Equipped collection UUIDs unavailable' end
        local costs={}
        for i,token in ipairs(string.split(tostring(costText or ''),',')) do costs[i]=tonumber(token) end
        local roster={};for _,u in ipairs(s.roster) do roster[u.uuid]=u end
        local p={stage=s.stage,mode=s.mode,placeId=s.placeId,source='user-recorded',entries={}}
        for _,u in ipairs(s.units) do
            local r=roster[u.uuid]
            if not r or r.id~=u.id or not u.pos then return nil,'Cannot map every own tower to exact equipped UUID/position' end
            local cost=r.cost or u.cost or costs[r.slot]
            if not C.finite(cost) or cost<=0 then return nil,'Deployment cost missing; enter comma-separated costs by slot' end
            if #p.entries>=24 then return nil,'At most 24 recorded placements' end
            p.entries[#p.entries+1]={uuid=u.uuid,id=u.id,slot=r.slot,pos=u.pos,cost=cost,wave=0,
                costSource=r.cost and 'observed collection' or u.cost and 'observed battle' or 'user-recorded'}
        end
        table.sort(p.entries,function(a,b)
            if a.slot~=b.slot then return a.slot<b.slot end
            return a.pos[1]==b.pos[1] and a.pos[3]<b.pos[3] or a.pos[1]<b.pos[1]
        end)
        if #p.entries==0 then return nil,'Place your team manually first' end
        return p
    end
    function A:close() self.alive=false end
    return A
end
