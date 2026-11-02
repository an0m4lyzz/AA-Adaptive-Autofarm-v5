-- Read-only parsing of an existing client-service export. No game/executor APIs.
return function(C)
    local I={}
    I.itemAliases={SacredTreasure={'sacred_treasure','SacredTreasure'},StarFruit={'StarFruit'},
        StarFruitBlue={'StarFruitBlue'},StarFruitRed={'StarFruitRed'},StarFruitGreen={'StarFruitGreen'},
        StarFruitEpic={'StarFruitEpic'},DungeonKey={'dungeon_key','DungeonKey'},
        RerollToken={'reroll_token','RerollToken'},StarRemnant={'star_remnant','StarRemnant'},
        StatCube={'stat_cube','StatCube'},PerfectStatCube={'perfect_stat_cube','PerfectStatCube'}}
    local function get(t,k) if type(t)=='table' then return rawget(t,k) end end
    local function tableAt(t,k) local v=get(t,k);return type(v)=='table' and v or nil end
    local function number(t,keys)
        for _,k in ipairs(keys) do local v=get(t,k);if C.finite(v) then return v end end
    end
    local function text(t,keys)
        for _,k in ipairs(keys) do
            local v=get(t,k)
            if type(v)=='string' and #v>0 and #v<=160 then return v end
        end
    end
    local traitNames={unique='Unique',divine='Divine',celestial='Celestial',reaper='Reaper',
        godspeed='Godspeed',sniper='Sniper',golden='Golden'}
    local function readUnit(key,t)
        if type(t)~='table' or type(key)~='string' or #key==0 or #key>160 then return nil end
        for _,alias in ipairs({'uuid','unique_id'}) do
            local explicit=get(t,alias)
            if explicit~=nil and (type(explicit)~='string' or explicit~=key) then return nil end
        end
        local id=text(t,{'unit_id','unitId','id'});if not id then return nil end
        local stats=tableAt(t,'stats') or t
        local u={uuid=key,id=id,statScope='collection',traits={},potential={}}
        local keys={damage={'damage','dmg'},spa={'spa','attack_cooldown'},range={'range','attack_range'},
            cost={'placement_cost','spawn_cost','place_cost'},level={'level'},
            takedowns={'takedowns','kills'},worthiness={'worthiness'}}
        for field,names in pairs(keys) do u[field]=number(stats,names) or number(t,names) end
        for field,names in pairs({damageGrade={'damage_grade','damageGrade'},spaGrade={'spa_grade','spaGrade'},
            rangeGrade={'range_grade','rangeGrade'}}) do u[field]=text(stats,names) or text(t,names) end
        local traits=tableAt(t,'traits')
        if traits then
            for i=1,4 do
                local v=rawget(traits,i)
                local raw=type(v)=='string' and v or text(v,{'trait','trait_id'})
                if raw and #raw<=48 then u.traits[#u.traits+1]=traitNames[raw:lower()] or raw end
            end
        end
        if #u.traits==0 then
            local raw=text(t,{'trait','trait_name'})
            if raw then u.traits[1]=traitNames[raw:lower()] or raw end
        end
        if #u.traits>0 then u.trait=table.concat(u.traits,' + ') end
        for _,field in ipairs({'stat_damage','stat_attack_cooldown','stat_range'}) do
            local v=get(t,field);if C.finite(v) then u.potential[field]=v end
        end
        return u
    end
    function I.read(service,userId)
        local out={valid=false,owned={},roster={},resources={},truncated=false,rejected=0,
            equippedComplete=false,equippedDeclared=0,reason='Client schema unavailable'}
        local session=tableAt(service,'session')
        local profile=tableAt(session,'profile_data')
        local collection=tableAt(tableAt(session,'collection'),'collection_profile_data')
        local owned=tableAt(collection,'owned_units')
        if not session or not owned then return out end
        for _,source in pairs({service,session,profile,collection}) do
            for _,key in ipairs({'user_id','player_id','UserId'}) do
                local id=get(source,key)
                if id~=nil and ((type(id)~='number' and type(id)~='string') or tonumber(id)~=userId) then
                    out.reason='Client owner mismatch/unverified';return out
                end
            end
        end
        out.valid=true;out.reason='Partial local client-service collection'
        local byUUID={}
        local function add(uuid)
            if type(uuid)~='string' then return nil end
            if byUUID[uuid] then return byUUID[uuid] end
            local u=readUnit(uuid,rawget(owned,uuid))
            if u then byUUID[uuid]=u;out.owned[#out.owned+1]=u else out.rejected+=1 end
            return u
        end
        local equipped=tableAt(collection,'equipped_units')
        if equipped then
            out.equippedComplete=true
            local key=nil
            for i=1,32 do
                key=next(equipped,key);if key==nil then break end
                local slot=type(key)=='number' and key or type(key)=='string' and tonumber(key)
                if not C.finite(slot) or slot%1~=0 or slot<1 or slot>8
                    or (type(key)=='string' and key~=tostring(slot)) then out.equippedComplete=false end
                if i==32 and next(equipped,key)~=nil then out.equippedComplete=false end
            end
            for slot=1,8 do
                local numeric=rawget(equipped,slot)
                local named=rawget(equipped,tostring(slot))
                local ambiguous=numeric~=nil and named~=nil and numeric~=named
                local uuid=numeric;if uuid==nil then uuid=named end
                if uuid~=nil then out.equippedDeclared+=1 end
                if ambiguous then out.rejected+=1;out.equippedComplete=false;uuid=nil end
                local u=add(uuid)
                if u then
                    -- A UUID occupying multiple slots is ambiguous, so never
                    -- manufacture a second equipped record for it.
                    if u.slot then out.rejected+=1;out.equippedComplete=false else u.slot=slot;out.roster[#out.roster+1]=u end
                elseif uuid~=nil then out.equippedComplete=false
                end
            end
        end
        local key=nil
        for _=1,400 do
            key=next(owned,key);if key==nil then break end
            add(key)
        end
        if key~=nil and next(owned,key)~=nil then out.truncated=true end
        table.sort(out.owned,function(a,b) return a.id==b.id and a.uuid<b.uuid or a.id<b.id end)
        local items=tableAt(tableAt(session,'inventory'),'inventory_profile_data')
        items=tableAt(items,'normal_items')
        if items then
            for label,aliases in pairs(I.itemAliases) do
                for _,id in ipairs(aliases) do
                    local amount=rawget(items,id)
                    if type(amount)=='table' then amount=number(amount,{'amount','count','quantity'}) end
                    if C.finite(amount) and amount>=0 then out.resources[label]=amount;break end
                end
            end
        end
        local rerolls=number(profile,{'trait_reroll_tokens'})
        if rerolls and rerolls>=0 then out.resources.RerollToken=rerolls end
        return out
    end
    function I.current(binding)
        if type(binding)~='table' then return nil end
        local entry=tableAt(binding.registry,binding.name)
        return tableAt(entry,'module') or entry
    end
    function I.named(roots,names)
        local out={}
        for i=1,math.min(#roots,97) do
            local root=rawget(roots,i)
            local value=type(root)=='table' and rawget(root,'value')
            if type(value)=='table' then
                local parents={value}
                for _,key in ipairs({'CLIENT_SERVICE','CORE_SERVICE','client_services','core_services','services','_services','modules','_modules'}) do
                    local nested=tableAt(value,key);if nested then parents[#parents+1]=nested end
                end
                for _,parent in ipairs(parents) do
                    for j=1,math.min(#names,8) do
                        local name=rawget(names,j)
                        if type(name)=='string' and not out[name] and tableAt(parent,name) then
                            out[name]={registry=parent,name=name,source=tostring(rawget(root,'source') or 'cache')..'.'..name}
                        end
                    end
                end
            end
        end
        return out
    end
    function I.find(roots,userId)
        local seen={}
        local containers={'CLIENT_SERVICE','client_services','services','_services','modules','_modules'}
        for _,serviceName in ipairs({'ItemInventoryServiceClient','StatsServiceClient','GUIService'}) do
            for i=1,math.min(#roots,97) do
                local root=roots[i]
                local value=root and root.value
                if type(value)=='table' then
                    local parents={{value=value,path=root.source}}
                    for _,name in ipairs(containers) do
                        local v=tableAt(value,name)
                        if v then parents[#parents+1]={value=v,path=root.source..'.'..name} end
                    end
                    for _,parent in ipairs(parents) do
                        local entry=tableAt(parent.value,serviceName)
                        local service=tableAt(entry,'module') or entry
                        if service and not seen[service] then
                            seen[service]=true
                            local snapshot=I.read(service,userId)
                            if snapshot.valid then return {service=service,source=parent.path..'.'..serviceName,
                                registry=parent.value,name=serviceName,snapshot=snapshot} end
                        end
                    end
                end
            end
        end
        return nil
    end
    return I
end
