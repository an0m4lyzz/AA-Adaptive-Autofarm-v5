-- [K] Anime Adventures Adaptive Unit Planner v5.1 (Delta / touch UI)
-- Automatic read-only run recorder: wave checkpoints, modifier cards, bosses, and results.
-- No external loader, network requests, payments, teleport bypasses, or key system.
-- EXPERIMENTAL: Game endpoints and inventory are based on publicly documented older AA builds.
-- Smart placer samples visible enemy routes and validates a spawn via live own-unit counts.
-- Some modes replace equipped units with random offers; those require live-mode adapters.
-- Event lobby queue can be learned once by observing your own normal event-join action.

if not game:IsLoaded() then game.Loaded:Wait() end
local P = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local WS = game:GetService('Workspace')
local UIS = game:GetService('UserInputService')
local HTTP = game:GetService('HttpService')
local LP = P.LocalPlayer
if not LP then return end
local ENV = (type(getgenv)=='function' and getgenv()) or _G
for _,oldKey in ipairs({'K_AA_V2','K_AA_V3','K_AA_V4','K_AA_V5'}) do
    local old=ENV[oldKey]
    if old and type(old.stop)=='function' then pcall(function() old.stop() end) end
end

local modes = {'Auto','Event','Story','Infinite','Legend','Raid','Dungeon','Portal','Challenge'}
local FILENAME = 'K_AA_Smart_v5_'..tostring(LP.UserId)..'.json'
local S = {
    alive=true, enabled=false, mode='Event', stage='unknown', map='unknown',
    maps={}, mapIntel={}, stageData={}, owned={}, ownedAt=0, teamPlan={}, teamReport={},
    eventQueue={}, queueLearning=false, queueLearningEnds=0,
    equipTemplate=nil,equipCandidate=nil,equipLearning=false,equipLearningEnds=0,
    equipChanges=0,lastEquipAt=0,counterReport={},counterLog={},bossNames={},
    autoQueue=false, run=0, wave=0, lastWave=0, startedAt=0, status='Loaded',
    options={place=true,upgrade=true,smartPlace=true,smartUpgrade=true,abilities=false,skip=true,start=true,replay=true,
        farming=true, savedMacros=true, maxTotal=16, maxEach=3,
        cardAdvisor=true, autoCards=false, cautiousSkip=true, autoEquip=false, stageScout=true,
        autoReport=true, autoCopyReport=true},
    goal='Balanced', farmTarget='Off', cardSnapshot={}, cardHistory={}, lastCardKey='',
    lastCardAttempt=0, lastCardAlert=0, cardConfidence=0, cardStatus='No cards detected', 
    inventory={}, inventoryAt=0, logs={}, unitReport={}, planReport={}, upgradeReport={}, lastPlanner=0, threatReport={},
}
ENV.K_AA_V5 = S
-- Read-only action signatures to learn event-specific placement/spell interfaces.
-- No UUID, account data, string content, or server payload is stored here.
S.eventActionBuffer={}
S.eventActionSeen={}
local run = {unitsFolder=nil, key='', count={}, records={}, savedIndex=1, nextSlot=1,
    candidate=1, pending=nil, lastPlace=0, lastUpgrade=0, lastAbility=0, lastStart=0,
    lastSkip=0, lastReplay=0, lastQueue=0, lastSave=0, hadResult=false,
    active=false, used={}, waveMax=0, inventoryWarned=false, upgradeIndex=0,
    badSpots={}, pendingUpgrade=nil, upgradeCooldown=setmetatable({}, {__mode="k"}),
    enemyPrev=setmetatable({}, {__mode="k"}), pathSamples={}, scanAt=0, unitScanAt=0, lastThreatAt=0}
local abilityAt=setmetatable({}, {__mode='k'})
local function note(message)
    S.status=tostring(message)
    if S.statusText then S.statusText.Text=S.status end
    print('[K] AA V4 | '..S.status)
    table.insert(S.logs,1,S.status)
    if #S.logs > 12 then table.remove(S.logs) end
end
local function readSettings()
    if type(readfile)~='function' or type(isfile)~='function' then return end
    if not isfile(FILENAME) then return end
    local ok,data=pcall(function() return HTTP:JSONDecode(readfile(FILENAME)) end)
    if not ok or type(data)~='table' then return end
    if type(data.maps)=='table' then S.maps=data.maps end
    if type(data.mapIntel)=='table' then S.mapIntel=data.mapIntel end
    if type(data.equipTemplate)=='table' and data.equipTemplate.verified==true then S.equipTemplate=data.equipTemplate end
    if type(data.cardHistory)=='table' then S.cardHistory=data.cardHistory end
    if type(data.eventQueue)=='table' then S.eventQueue=data.eventQueue end
    if data.goal=='Safe' or data.goal=='Balanced' or data.goal=='Rewards' then S.goal=data.goal end
    if data.farmTarget=='Off' or data.farmTarget=='Rukia' or data.farmTarget=='Griffin' then
        S.farmTarget=data.farmTarget
    end
    if type(data.mode)=='string' and table.find(modes,data.mode) then S.mode=data.mode end
    if type(data.options)=='table' then
        for k,v in pairs(S.options) do
            if type(v)=='boolean' and type(data.options[k])=='boolean' then S.options[k]=data.options[k] end
            if type(v)=='number' and type(data.options[k])=='number' then
                S.options[k]=math.clamp(math.floor(data.options[k]),1,32)
            end
        end
    end
    -- Never arm automation automatically after teleport/re-execution.
end
local function saveSettings()
    if type(writefile)~='function' then return false end
    local ok=pcall(function()
        writefile(FILENAME,HTTP:JSONEncode({maps=S.maps,mapIntel=S.mapIntel,equipTemplate=S.equipTemplate,eventQueue=S.eventQueue,
            mode=S.mode,options=S.options,goal=S.goal,farmTarget=S.farmTarget,
            cardHistory=S.cardHistory}))
    end)
    return ok
end
readSettings()
-- Auto-card needs the advisor enabled; reconcile old saved settings.
if S.options.autoCards then S.options.cardAdvisor=true end

local function endpoints()
    local folder=RS:FindFirstChild('endpoints')
    return folder and folder:FindFirstChild('client_to_server')
end
local function getRemote(name)
    local folder=endpoints()
    local remote=folder and folder:FindFirstChild(name)
    if remote and (remote:IsA('RemoteFunction') or remote:IsA('RemoteEvent')) then return remote end
end
local function call(name,...)
    local remote=getRemote(name)
    if not remote then return false,'Missing '..name end
    local args=table.pack(...)
    local ok,res=pcall(function()
        if remote:IsA('RemoteFunction') then return remote:InvokeServer(table.unpack(args,1,args.n)) end
        remote:FireServer(table.unpack(args,1,args.n))
        return true
    end)
    return ok and res~=false, ok and res or tostring(res)
end
local function value(parent,name)
    local v=parent and parent:FindFirstChild(name)
    if v and v:IsA('ValueBase') then return v.Value end
end
local function wave()
    return tonumber(value(WS,'_wave_num')) or 0
end
local function isMatch()
    return WS:FindFirstChild('_UNITS')~=nil and WS:FindFirstChild('_wave_num')~=nil
end
local function isStarted()
    local b=value(WS,'_waves_started')
    if b~=nil then return b==true end
    return wave()>=1
end
local function isFinished()
    local d=WS:FindFirstChild('_DATA')
    if value(d,'GameFinished')==true then return true end
    local r=LP:FindFirstChild('PlayerGui') and LP.PlayerGui:FindFirstChild('ResultsUI')
    return r and r:IsA('ScreenGui') and r.Enabled==true or false
end
local function owner(m)
    local stats=m:FindFirstChild('_stats')
    local who=value(stats,'player') or value(stats,'owner') or value(stats,'player_id')
    if typeof(who)=='Instance' then return who==LP end
    if type(who)=='number' then return who==LP.UserId end
    return tostring(who)==LP.Name or tostring(who)==tostring(LP.UserId)
end
local function ownUnits()
    local out={}
    local folder=WS:FindFirstChild('_UNITS')
    if folder then
        for _,m in ipairs(folder:GetChildren()) do
            if m:IsA('Model') and owner(m) then table.insert(out,m) end
        end
    end
    return out
end
local function unitPosition(m)
    local hit=m:FindFirstChild('_hitbox') or m.PrimaryPart
    if hit and hit:IsA('BasePart') then return hit.Position end
    local ok,cf=pcall(function() return m:GetPivot() end)
    return ok and cf.Position or nil
end
local function isFarmId(id)
    id=tostring(id):lower()
    for _,s in ipairs({'bulma','bulby','speedwagon','ceo','farm','money','idol'}) do
        if id:find(s,1,true) then return true end
    end
    return false
end
local function isFarmModel(m)
    return isFarmId(value(m:FindFirstChild('_stats'),'id') or m.Name)
end

-- Equipped units come from the *current player's* live collection tables, not hardcoded IDs.
-- Older AA builds exposed {equipped_slot, unit_id, uuid} in client-side unit records.
-- Runtime stat reader. Missing stats stay unknown (nil) instead of fabricated values.
local function stat(parent, keys)
    if not parent then return nil end
    for _,key in ipairs(keys) do
        local val=value(parent,key)
        if val~=nil then return val end
        if parent.GetAttribute then
            local ok,v=pcall(function() return parent:GetAttribute(key) end)
            if ok and v~=nil then return v end
        end
    end
    return nil
end
local function num(parent,keys)
    local v=stat(parent,keys)
    return tonumber(v)
end
local function textStat(parent,keys)
    local v=stat(parent,keys)
    return v==nil and nil or tostring(v)
end
local DAMAGE={'damage','dmg','attack_damage','total_damage','Damage','DamageStat'}
local SPEED={'spa','attack_speed','cooldown','attack_cooldown','attack_time','SPA','Speed'}
local RANGE={'range','attack_range','Range','radius','Radius'}
local UPGRADE_COST={'next_upgrade_cost','upgrade_cost','upgrade_price','upgradeCost','NextUpgradeCost'}
local DEPLOY_COST={'placement_cost','spawn_cost','place_cost','cost','price','PlaceCost'}
local function statTable(t, keys)
    if type(t)~='table' then return nil end
    for _,k in ipairs(keys) do
        local v=rawget(t,k)
        if type(v)=='number' or type(v)=='string' or type(v)=='boolean' then return v end
    end
    return nil
end
local function roleFrom(id,attack,tag)
    local t=(tostring(id or '')..' '..tostring(attack or '')..' '..tostring(tag or '')):lower()
    if isFarmId(t) or t:find('income',1,true) or t:find('economy',1,true) then return 'farm' end
    if t:find('support',1,true) or t:find('buffer',1,true) or t:find('commander',1,true)
        or t:find('wenda',1,true) or t:find('elfy',1,true) or t:find('leafy',1,true)
        or t:find('griffin_reincarnation',1,true) then return 'support' end
    if t:find('slow',1,true) or t:find('freeze',1,true) or t:find('stun',1,true)
        or t:find('stop',1,true) then return 'control' end
    return 'damage'
end
local function airFrom(t)
    t=tostring(t or ''):lower()
    return t:find('hill',1,true)~=nil or t:find('hybrid',1,true)~=nil
        or t:find('air',1,true)~=nil or t:find('flying',1,true)~=nil
end
-- Equipped roster is read from client-exposed collections where available. No
-- stat is guessed when absent and no unseen remote is invoked to fetch inventory.
local function scanEquipped()
    local bySlot={}
    local function add(t)
        if type(t)~='table' then return end
        local slot=tonumber(rawget(t,'equipped_slot') or rawget(t,'equippedSlot'))
        local uuid=rawget(t,'uuid') or rawget(t,'unique_id')
        local id=rawget(t,'unit_id') or rawget(t,'unitId')
        if not slot or slot<1 or slot>8 or not uuid or not id then return end
        local m=bySlot[slot]
        if not m then
            m={slot=slot,uuid=tostring(uuid),id=tostring(id)}
            bySlot[slot]=m
        end
        local source=rawget(t,'stats')
        if type(source)~='table' then source=t end
        m.damage=tonumber(statTable(source,DAMAGE)) or m.damage
        m.spa=tonumber(statTable(source,SPEED)) or m.spa
        m.range=tonumber(statTable(source,RANGE)) or m.range
        m.cost=tonumber(statTable(source,DEPLOY_COST)) or m.cost
        m.maxPlaced=tonumber(statTable(source,{'placement_limit','max_placements','max_units','spawn_cap'})) or m.maxPlaced
        m.trait=tostring(statTable(t,{'trait','trait_name'}) or m.trait or '')
        m.attack=tostring(statTable(t,{'attack_type','placement_type','unit_type'}) or m.attack or '')
        m.role=roleFrom(m.id,m.attack,statTable(t,{'role','unit_role'}))
        m.farm=m.role=='farm'
        m.air=airFrom(m.attack)
    end
    local function inspect(t)
        if type(t)~='table' then return end
        add(t)
        local lists={rawget(t,'owned_units'),rawget(t,'equipped_units'),rawget(t,'units')}
        local profile=rawget(t,'collection_profile_data')
        if type(profile)=='table' then
            lists[#lists+1]=rawget(profile,'owned_units')
            lists[#lists+1]=rawget(profile,'equipped_units')
        end
        for _,list in pairs(lists) do
            if type(list)=='table' then
                for _,entry in pairs(list) do add(entry) end
            end
        end
    end
    if type(getgc)=='function' then
        local ok,items=pcall(function() return getgc(true) end)
        if ok and type(items)=='table' then
            for i,obj in ipairs(items) do
                if i>25000 then break end
                if type(obj)=='table' then inspect(obj) end
            end
        end
    end
    local list={}
    for _,u in pairs(bySlot) do
        u.role=u.role or roleFrom(u.id,u.attack)
        u.farm=u.role=='farm'
        u.air=u.air or false
        list[#list+1]=u
    end
    table.sort(list,function(a,b) return a.slot<b.slot end)
    S.inventory=list
    S.inventoryAt=os.clock()
    return list
end
-- ================ V5 STAGE SCOUT / OWNED ROSTER / COUNTERS ================
-- Observations are evidence, not a complete datamine. Unknown fields stay unknown.
local COUNTERS = {'flying','shield','regen','armored','tank','burst','fast','boss',
    'magicResist','physicalResist','fireResist','iceResist','clone','fortify'}
local UNIT_HINTS = {
    {pattern='bulby',role='farm'}, {pattern='bulma',role='farm'}, {pattern='c.e.o',role='farm'},
    {pattern='speedwagon',role='farm'}, {pattern='griffin_reincarnation',role='support'},
    {pattern='commander',role='support'}, {pattern='elfy',role='support'},
    {pattern='wenda',role='support'}, {pattern='reliable student',role='control'},
    {pattern='snow reaper',role='control'}, {pattern='shadowgirl',role='control'},
    {pattern='blood',property='antiRegen'}, {pattern='ashborn',property='antiRegen'},
    {pattern='inhuman',property='antiRegen'},
}
local function lower(x) return string.lower(tostring(x or '')) end
local function contains(s,w) return string.find(s,w,1,true)~=nil end
local function scanOwned()
    local byUUID={}
    local touched=0
    local function ingest(t)
        if type(t)~='table' then return end
        local uid=rawget(t,'uuid') or rawget(t,'unique_id')
        local unitId=rawget(t,'unit_id') or rawget(t,'unitId')
        if not uid or not unitId then return end
        touched=touched+1
        local k=tostring(uid)
        local u=byUUID[k] or {uuid=k,id=tostring(unitId)}
        byUUID[k]=u
        local stats=rawget(t,'stats')
        if type(stats)~='table' then stats=t end
        local function fill(field,keys)
            local v=statTable(stats,keys) or statTable(t,keys)
            if v~=nil then u[field]=v end
        end
        fill('damage',DAMAGE);fill('spa',SPEED);fill('range',RANGE)
        fill('cost',DEPLOY_COST);fill('trait',{'trait','trait_name','trait_id'})
        fill('attack',{'placement_type','attack_type','unit_type','target_type'})
        fill('element',{'element','affinity','damage_type','attack_affinity'})
        fill('role',{'role','unit_role'})
        fill('rarity',{'rarity','unit_rarity'})
        fill('hits',{'hits','hit_count','multi_hit','multi_hits','attack_hits'})
        fill('skill',{'ability','passive','effect','skill','special'})
        fill('equippedSlot',{'equipped_slot','equippedSlot'})
        u.damage=tonumber(u.damage);u.spa=tonumber(u.spa)
        u.range=tonumber(u.range);u.cost=tonumber(u.cost)
        u.hits=tonumber(u.hits)
        u.equippedSlot=tonumber(u.equippedSlot)
        u.role=roleFrom(u.id,u.attack,u.role)
        u.farm=u.role=='farm'
        u.air=airFrom(u.attack)
        local terms=lower(u.id..' '..tostring(u.skill or '')..' '..tostring(u.element or '')..' '..tostring(u.attack or ''))
        local function hasAny(...)
            for i=1,select('#',...) do if contains(terms,select(i,...)) then return true end end
            return false
        end
        u.multiHit=(u.hits and u.hits>=2) or hasAny('multi hit','multihit','shatter','multi-hit')
        u.antiRegen=hasAny('bleed','regeneration suppression','anti regen','anti-regen','burn','inhuman','ashborn')
        u.control=hasAny('slow','freeze','stun','time stop','rewind','pushback') or u.role=='control'
        u.trueDamage=hasAny('true damage','true_damage')
        u.bossBonus=hasAny('reaper','boss damage','boss_damage') or contains(lower(u.trait),'reaper')
        u.element=lower(u.element)
        for _,hint in ipairs(UNIT_HINTS) do
            if contains(terms,hint.pattern) then
                if hint.role then u.role=hint.role;u.farm=u.role=='farm' end
                if hint.property then u[hint.property]=true end
            end
        end
    end
    local function walk(t,depth)
        if type(t)~='table' or depth>3 then return end
        ingest(t)
        for _,key in ipairs({'owned_units','equipped_units','units','collection','collection_profile_data','session'}) do
            local child=rawget(t,key)
            if type(child)=='table' then walk(child,depth+1) end
        end
        if depth<=2 then
            local visited=0
            for _,v in pairs(t) do
                visited=visited+1;if visited>500 then break end
                if type(v)=='table' then ingest(v) end
            end
        end
    end
    if type(getgc)=='function' then
        local ok,objects=pcall(function() return getgc(true) end)
        if ok and type(objects)=='table' then
            for i,v in ipairs(objects) do
                if i>30000 then break end
                if type(v)=='table' then
                    local looksRelevant=rawget(v,'collection_profile_data') or rawget(v,'owned_units')
                        or rawget(v,'equipped_units') or rawget(v,'session')
                    if looksRelevant then walk(v,0) end
                end
            end
        end
    end
    for _,v in ipairs(S.inventory) do
        if not byUUID[v.uuid] then
            ingest({uuid=v.uuid,unit_id=v.id,equipped_slot=v.slot,stats=v})
        end
    end
    local arr={}
    for _,v in pairs(byUUID) do arr[#arr+1]=v end
    table.sort(arr,function(a,b) return a.id==b.id and a.uuid<b.uuid or a.id<b.id end)
    S.owned=arr
    S.ownedAt=os.clock()
    return arr,touched
end

local function stageData()
    local o={id=S.map,name='Unknown',world='Unknown',rawKeys={}}
    local mc=WS:FindFirstChild('_MAP_CONFIG')
    local endpoint=mc and mc:FindFirstChild('GetLevelData')
    if endpoint and endpoint:IsA('RemoteFunction') then
        local ok,d=pcall(function() return endpoint:InvokeServer() end)
        if ok and type(d)=='table' then
            o.id=tostring(d.id or S.map)
            o.name=tostring(d.name or d.level_name or o.id)
            o.world=tostring(d.world or d.world_id or 'Unknown')
            for k,v in pairs(d) do
                if type(k)=='string' and (type(v)=='string' or type(v)=='number') then
                    if contains(lower(k),'boss') or contains(lower(k),'difficult')
                        or contains(lower(k),'affinit') or contains(lower(k),'mode')
                        or contains(lower(k),'element') then
                        o.rawKeys[#o.rawKeys+1]=k..'='..tostring(v):sub(1,80)
                    end
                end
            end
        end
    end
    S.stageData=o
    return o
end
local function threatRecord()
    local key=S.mode..' :: '..S.map
    if type(S.mapIntel[key])~='table' then S.mapIntel[key]={seen={},bosses={},firstWave={},bossWaves={},scans=0,lastSeen=0} end
    local rec=S.mapIntel[key]
    rec.seen=type(rec.seen)=='table' and rec.seen or {}
    rec.bosses=type(rec.bosses)=='table' and rec.bosses or {}
    rec.firstWave=type(rec.firstWave)=='table' and rec.firstWave or {}
    rec.bossWaves=type(rec.bossWaves)=='table' and rec.bossWaves or {}
    return rec
end
local function enemyProfile(m)
    local info={name=tostring(m.Name),flags={},hp=0,affinity='',evidence={}}
    local st=m:FindFirstChild('_stats')
    local parts={lower(m.Name)}
    local attrs={}
    for _,source in ipairs({m,st}) do
        if source then
            local ok,a=pcall(function() return source:GetAttributes() end)
            if ok and type(a)=='table' then
                for k,v in pairs(a) do
                    local lk=lower(k)
                    local active=(type(v)=='boolean' and v==true)
                        or (type(v)=='number' and v>0)
                        or (type(v)=='string' and v~='' and v~='none' and v~='false' and v~='0')
                    if #attrs<24 and active then attrs[#attrs+1]=lk..':'..tostring(v) end
                end
            end
            for _,c in ipairs(source:GetChildren()) do
                if c:IsA('ValueBase') then
                    local lk=lower(c.Name)
                    if contains(lk,'trait') or contains(lk,'type') or contains(lk,'effect')
                        or contains(lk,'resist') or contains(lk,'shield') or contains(lk,'boss')
                        or contains(lk,'fly') or contains(lk,'regen') or contains(lk,'armor') then
                        local value=c.Value
                        local active=(type(value)=='boolean' and value==true)
                            or (type(value)=='number' and value>0)
                            or (type(value)=='string' and value~='' and value~='none'
                                and value~='false' and value~='0')
                        if active then attrs[#attrs+1]=lk..':'..tostring(value) end
                    end
                end
            end
        end
    end
    local joined=table.concat(attrs,' ')
    local src=table.concat(parts,' ')..' '..joined
    local function flag(key,words)
        for _,w in ipairs(words) do
            if contains(src,w) then info.flags[key]=true;return end
        end
    end
    flag('flying',{'flying','flyer','airborne','air enemy','air:true','flying:true'})
    flag('shield',{'shield','shatterable','barrier'})
    flag('regen',{'regen','regeneration','vampir'})
    flag('armored',{'armor','armour'})
    flag('tank',{'tank','fortified','bulwark'})
    flag('burst',{'burst'})
    flag('fast',{'speedy','swift','speed boost','fast enemy','frenzy'})
    flag('clone',{'clone','split'})
    flag('fortify',{'fortify','flagbearer'})
    flag('boss',{'boss','raid boss','raid_boss'})
    flag('magicResist',{'magic_resistance','magic resistance','magicresist','magic resist'})
    flag('physicalResist',{'physical_resistance','physical resistance','physicalresist','physical resist'})
    flag('fireResist',{'fire_resistance','fire resistance','fire resist'})
    flag('iceResist',{'ice_resistance','ice resistance','ice resist'})
    info.hp=num(st,{'hp','health','max_hp','maxHealth','max_health'}) or 0
    local namedBoss=lower(m.Name)
    if info.hp>0 and S.maxEnemyHP and info.hp>math.max(S.maxEnemyHP*3,200000) then info.flags.boss=true end
    if info.flags.boss then info.bossName=tostring(m.Name) end
    info.affinity=tostring(stat(st,{'affinity','damage_affinity','element'}) or '')
    return info
end
local function stageCounters()
    local report={}
    local seen={}
    local current=S.threatReport or {}
    local rec=threatRecord()
    for _,key in ipairs(COUNTERS) do
        local n=tonumber(current[key] or 0) or 0
        local previous=tonumber(rec.seen[key] or 0) or 0
        if n>0 or previous>0 then
            seen[key]=true
            report[#report+1]=key..': '..(n>0 and 'LIVE' or 'learned')
        end
    end
    return seen,report
end
local function matchBonus(u,seen)
    local points=0; local why={}
    local function add(cond,amount,reason)
        if cond then points=points+amount;why[#why+1]=reason end
    end
    add(seen.flying and u.air,80,'air/hybrid coverage')
    add(seen.flying and not u.air and u.role=='damage',-35,'cannot target flight')
    add(seen.shield and u.multiHit,55,'multi-hit shields')
    add(seen.regen and u.antiRegen,42,'regeneration suppression')
    add(seen.armored and u.role=='damage' and not contains(lower(u.skill),'full aoe'),15,'non-full-AoE')
    add(seen.boss and u.bossBonus,38,'boss damage')
    add((seen.burst or seen.fast) and u.control,25,'speed control')
    add(seen.clone and u.role=='damage',10,'clone clearance')
    add(seen.magicResist and contains(lower(u.element),'physical'),38,'physical vs magic resist')
    add(seen.physicalResist and contains(lower(u.element),'magic'),38,'magic vs physical resist')
    add((seen.magicResist or seen.physicalResist) and u.trueDamage,48,'true vs resist')
    add(seen.iceResist and contains(lower(u.element),'fire'),24,'fire vs ice resist')
    if u.farm then points=points-15 end
    return points,table.concat(why,'; ')
end
local function scoreOwned(u,seen)
    local dps=(u.damage and u.spa and u.spa>0) and u.damage/u.spa or nil
    local p=dps and math.log(1+dps)*5 or 0
    if u.role=='damage' then p=p+30
    elseif u.role=='farm' then p=p+15
    elseif u.role=='control' then p=p+23
    elseif u.role=='support' then p=p+18 end
    if u.range then p=p+math.min(u.range,70)*.18 end
    if u.cost then p=p-math.log(1+math.max(0,u.cost))*1.6 end
    if contains(lower(u.trait),'unique') then p=p+12 end
    local extra,why=matchBonus(u,seen)
    return p+extra,why
end
local function recommendTeam()
    if #S.owned==0 then scanOwned() end
    local seen,flags=stageCounters()
    local candidates={}
    for _,u in ipairs(S.owned) do
        local score,reason=scoreOwned(u,seen)
        candidates[#candidates+1]={unit=u,score=score,reason=reason}
    end
    table.sort(candidates,function(a,b)
        if a.score==b.score then return a.unit.id<b.unit.id end
        return a.score>b.score
    end)
    local selected,used,usedIds={},{},{}
    local needFarm=(S.mode=='Infinite' or S.mode=='Dungeon' or S.mode=='Event')
    local function addBest(predicate)
        for _,candidate in ipairs(candidates) do
            local u=candidate.unit
            if not used[u.uuid] and not usedIds[u.id] and predicate(u) then
                used[u.uuid]=true;usedIds[u.id]=true;selected[#selected+1]=candidate
                return true
            end
        end
        return false
    end
    local slots=6
    addBest(function(u) return u.role=='damage' and (u.air or not seen.flying) end)
    if seen.flying then addBest(function(u) return u.air and u.role=='damage' end) end
    if seen.shield then addBest(function(u) return u.multiHit and u.role=='damage' end) end
    if seen.regen then addBest(function(u) return u.antiRegen and u.role=='damage' end) end
    if seen.magicResist or seen.physicalResist then
        addBest(function(u) return u.trueDamage or (seen.magicResist and contains(u.element,'physical'))
            or (seen.physicalResist and contains(u.element,'magic')) end)
    end
    if needFarm then addBest(function(u) return u.role=='farm' end) end
    addBest(function(u) return u.control or u.role=='control' end)
    addBest(function(u) return u.role=='support' end)
    while #selected<slots do if not addBest(function() return true end) then break end end
    -- Fill repeated IDs only if the roster has fewer than six distinct units.
    if #selected<slots then
        for _,c in ipairs(candidates) do
            if #selected>=slots then break end
            if not used[c.unit.uuid] then
                used[c.unit.uuid]=true;selected[#selected+1]=c
            end
        end
    end
    S.teamPlan=selected
    S.teamReport={}
    S.teamReport[#S.teamReport+1]='STAGE '..tostring((S.stageData or {}).name or S.map)..' / '..S.mode
    S.teamReport[#S.teamReport+1]='COUNTERS '..(#flags>0 and table.concat(flags,', ') or 'No confirmed threats yet')
    local equiv=0
    local existing={}
    for _,u in ipairs(S.inventory) do existing[u.uuid]=true end
    for i,sel in ipairs(selected) do
        local u=sel.unit
        if existing[u.uuid] then equiv=equiv+1 end
        S.teamReport[#S.teamReport+1]=i..'. '..u.id..' '..(existing[u.uuid] and '[equipped]' or '[bench]')..
            ' '..u.role..' '..tostring(u.trait or '')..' score='..string.format('%.1f',sel.score)..
            (sel.reason~='' and (' reason='..sel.reason) or '')
    end
    S.teamReport[#S.teamReport+1]='Current team matches '..equiv..'/'..#selected..' suggested selections.'
    local function selectedHas(predicate)
        for _,entry in ipairs(selected) do if predicate(entry.unit) then return true end end
        return false
    end
    if seen.flying and not selectedHas(function(u) return u.air end) then
        S.teamReport[#S.teamReport+1]='WARNING: no VERIFIED hill/hybrid air counter found in roster scan.'
    end
    if seen.shield and not selectedHas(function(u) return u.multiHit end) then
        S.teamReport[#S.teamReport+1]='WARNING: no VERIFIED shield-breaking/multi-hit counter found.'
    end
    if seen.regen and not selectedHas(function(u) return u.antiRegen end) then
        S.teamReport[#S.teamReport+1]='WARNING: no VERIFIED regen suppression found.'
    end
    return selected
end
local function v5ScanStage()
    local folder=WS:FindFirstChild('_ENEMIES')
    local tally={count=0,air=0,boss=0,moving=0}
    local bossNames={}
    if folder then
        for _,m in ipairs(folder:GetChildren()) do
            if m:IsA('Model') then
                tally.count=tally.count+1
                local info=enemyProfile(m)
                for key in pairs(info.flags) do tally[key]=(tally[key] or 0)+1 end
                if info.flags.flying then tally.air=tally.air+1 end
                if info.flags.boss then
                    if #bossNames<6 then bossNames[#bossNames+1]=info.name end
                end
                if tally.count>=90 then break end
            end
        end
    end
    S.counterReport=tally
    S.bossNames=bossNames
    local rec=threatRecord()
    for _,key in ipairs(COUNTERS) do
        if (tally[key] or 0)>0 then
            rec.seen[key]=math.max(rec.seen[key] or 0,tally[key])
            if not rec.firstWave[key] or wave()<rec.firstWave[key] then rec.firstWave[key]=wave() end
        end
    end
    for _,name in ipairs(bossNames) do
        if #name<90 then
            rec.bosses[name]=true
            if not rec.bossWaves[name] or wave()<rec.bossWaves[name] then
                rec.bossWaves[name]=wave()
            end
        end
    end
    rec.scans=(rec.scans or 0)+1
    rec.lastSeen=os.time()
    local nextBoss=nil
    for _,w in pairs(rec.bossWaves) do
        if type(w)=='number' and w>=wave() and (not nextBoss or w<nextBoss) then nextBoss=w end
    end
    tally.nextKnownBossWave=nextBoss
    tally.bossSoon=nextBoss and nextBoss-wave()<=3 or false
    S.threatReport=S.threatReport or {}
    for _,key in ipairs(COUNTERS) do
        S.threatReport[key]=tally[key] or 0
    end
    if (tally.flying or 0)>0 then S.threatReport.air=tally.flying end
    if (tally.boss or 0)>0 then S.threatReport.boss=tally.boss end
    S.threatReport.bossSoon=tally.bossSoon
    S.threatReport.nextKnownBossWave=tally.nextKnownBossWave
end
-- ======================== END V5 SCOUT ========================

local function liveUnit(m)
    local stats=m and m:FindFirstChild('_stats')
    local v={model=m,id=tostring(stat(stats,{'id','unit_id'}) or (m and m.Name) or ''),
        uuid=textStat(stats,{'uuid','unique_id'}),
        damage=num(stats,DAMAGE),spa=num(stats,SPEED),range=num(stats,RANGE),
        nextCost=num(stats,UPGRADE_COST),
        level=num(stats,{'upgrade','upgrade_level','level','Upgrade'}),
        maxLevel=num(stats,{'max_upgrade','max_upgrades','max_level','MaxUpgrade'}),
        attack=textStat(stats,{'attack_type','placement_type','unit_type','target_type'}),
        role=textStat(stats,{'role','unit_role'}),
        trait=textStat(stats,{'trait','trait_name'})}
    v.role=roleFrom(v.id,v.attack,v.role)
    v.farm=v.role=='farm'
    v.air=airFrom(v.attack)
    v.element=lower(textStat(stats,{'element','affinity','damage_type','attack_affinity'}))
    local skill=lower(textStat(stats,{'passive','skill','ability','effect'}) or '')
    local idstr=lower(v.id..' '..skill..' '..v.element..' '..tostring(v.trait or ''))
    v.multiHit=contains(idstr,'multi-hit') or contains(idstr,'multi hit') or contains(idstr,'shatter')
        or (num(stats,{'hits','hit_count','multi_hits'}) or 0)>=2
    v.antiRegen=contains(idstr,'bleed') or contains(idstr,'burn')
        or contains(idstr,'inhuman') or contains(idstr,'ashborn')
    v.trueDamage=contains(idstr,'true damage') or contains(idstr,'true_damage')
    v.bossBonus=contains(idstr,'reaper') or contains(idstr,'boss damage')
    v.control=v.role=='control' or contains(idstr,'slow') or contains(idstr,'freeze')
        or contains(idstr,'stun') or contains(idstr,'stop')
    for _,owned in ipairs(S.owned) do
        if (v.uuid and owned.uuid==v.uuid) or owned.id==v.id then
            v.multiHit=v.multiHit or owned.multiHit
            v.antiRegen=v.antiRegen or owned.antiRegen
            v.trueDamage=v.trueDamage or owned.trueDamage
            v.bossBonus=v.bossBonus or owned.bossBonus
            v.control=v.control or owned.control
            v.element=(v.element~='' and v.element or owned.element)
            break
        end
    end
    v.dps=(v.damage and v.spa and v.spa>0) and v.damage/v.spa or nil
    v.pos=unitPosition(m)
    return v
end
local function bestLiveMatch(inv)
    if not inv then return nil end
    for _,m in ipairs(ownUnits()) do
        local info=liveUnit(m)
        if (info.uuid and info.uuid==inv.uuid) or info.id==inv.id then
            return info
        end
    end
end
local function scanMoney()
    local roots={WS:FindFirstChild('_DATA'),LP:FindFirstChild('leaderstats'),LP,
        LP:FindFirstChild('PlayerGui') and LP.PlayerGui:FindFirstChild('_DATA')}
    for _,root in pairs(roots) do
        local amount=num(root,{'yen','Yen','money','Money','cash','Cash','currency','Currency'})
        if amount then return amount end
    end
    return nil
end
local function mapId()
    local conf=WS:FindFirstChild('_MAP_CONFIG')
    local remote=conf and conf:FindFirstChild('GetLevelData')
    if remote and remote:IsA('RemoteFunction') then
        local ok,d=pcall(function() return remote:InvokeServer() end)
        if ok and type(d)=='table' then
            return tostring(d.id or d.name or game.PlaceId)
        end
    end
    return tostring(game.PlaceId)
end
local function currentKey()
    return S.mode..' :: '..S.map
end
local function profile()
    local k=currentKey()
    if not S.maps[k] then S.maps[k]={steps={},created=os.time()} end
    return S.maps[k]
end
local function resetMatch()
    run.unitsFolder=WS:FindFirstChild('_UNITS')
    run.count={};run.records={};run.savedIndex=1;run.nextSlot=1;run.candidate=1
    run.pending=nil;run.lastPlace=0;run.hadResult=false;run.active=true;run.used={}
    run.waveMax=0;run.inventoryWarned=false
    run.badSpots={};run.enemyPrev=setmetatable({}, {__mode='k'});run.pathSamples={}
    run.pendingUpgrade=nil;run.scoringTowers=nil;run.sampleOverlaps=nil;run.knownRange=nil
    run.upgradeCooldown=setmetatable({}, {__mode='k'})
    S.map=mapId()
    stageData()
    run.key=currentKey()
    if S.farmTarget=='Off' then
        -- Existing behavior for other modes. Not automatically used for target farms.
        scanEquipped()
        scanOwned()
        recommendTeam()
    else
        -- Preserve the manually checked roster. Re-running getgc(true) during
        -- a match caused serious stability concerns on mobile/Delta.
        note('Goal-farm match: preserved '..#S.inventory..
            ' verified equipped slots. Skipping heavy ownership scans.')
    end
    note('Run ready: '..run.key..' | equipped '..#S.inventory..' | saved steps '..#profile().steps)
end

-- Placement locations are generated from observed enemy positions + downward raycasts.
-- An unverified placement is never considered successful merely because the remote returned nil.
local function enemyCenter()
    local folder=WS:FindFirstChild('_ENEMIES')
    if not folder then return nil end
    local positions={}
    for _,m in ipairs(folder:GetChildren()) do
        if m:IsA('Model') then
            local p=unitPosition(m)
            if p then positions[#positions+1]=p end
            if #positions>=12 then break end
        end
    end
    if #positions==0 then return nil end
    local sum=Vector3.zero
    for _,v in ipairs(positions) do sum=sum+v end
    return sum/#positions
end
local function castGround(point)
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    local exclude={}
    local enemies=WS:FindFirstChild('_ENEMIES')
    local units=WS:FindFirstChild('_UNITS')
    if enemies then table.insert(exclude,enemies) end
    if units then table.insert(exclude,units) end
    if LP.Character then table.insert(exclude,LP.Character) end
    params.FilterDescendantsInstances=exclude
    local r=WS:Raycast(point+Vector3.new(0,60,0),Vector3.new(0,-150,0),params)
    if not r or r.Normal.Y<0.7 then return nil end
    if not r.Instance.CanCollide then return nil end
    return r.Position+Vector3.new(0,1,0)
end
-- ============ ADAPTIVE PLANNER: ENEMY ROUTES, COVERAGE, UNIT VALUE ============
-- Path samples come from visible enemies we have actually observed moving.
-- This is deliberately not a claim to know hidden waypoints or server placement rules.
local function pathPoint(pos)
    if not pos then return end
    local last=run.pathSamples[#run.pathSamples]
    if last and (Vector3.new(last.x,last.y,last.z)-pos).Magnitude<5 then return end
    run.pathSamples[#run.pathSamples+1]={x=pos.X,y=pos.Y,z=pos.Z,t=os.clock()}
    if #run.pathSamples>100 then table.remove(run.pathSamples,1) end
end
local function observePath()
    local now=os.clock()
    if now-run.scanAt<1.5 then return end
    run.scanAt=now
    local enemies=WS:FindFirstChild('_ENEMIES')
    local threat={count=0,air=0,boss=0,moving=0}
    if not enemies then S.threatReport=threat;return end
    for _,enemy in ipairs(enemies:GetChildren()) do
        if enemy:IsA('Model') then
            threat.count=threat.count+1
            local es=enemy:FindFirstChild('_stats')
            local typ=tostring(stat(es,{'enemy_type','type','trait','traits'}) or ''):lower()
            local name=enemy.Name:lower()
            if typ:find('air',1,true) or typ:find('fly',1,true)
                or name:find('flying',1,true) then threat.air=threat.air+1 end
            if typ:find('boss',1,true) or name:find('boss',1,true) then threat.boss=threat.boss+1 end
            local pos=unitPosition(enemy)
            if pos then
                local prev=run.enemyPrev[enemy]
                if prev and (pos-prev).Magnitude>3 then
                    threat.moving=threat.moving+1
                    local distance=(pos-prev).Magnitude
                    local parts=math.min(8,math.floor(distance/5))
                    if parts>0 and distance<110 then
                        for j=1,parts do pathPoint(prev:Lerp(pos,j/parts)) end
                    end
                elseif not prev and #run.pathSamples<10 then
                    pathPoint(pos)
                end
                run.enemyPrev[enemy]=pos
            end
        end
    end
    S.threatReport=threat
    if S.options.stageScout and os.clock()-(S.lastStageScan or 0)>3 then
        S.lastStageScan=os.clock()
        v5ScanStage()
        if os.clock()-(S.lastScoutSave or 0)>45 then
            S.lastScoutSave=os.clock();saveSettings()
        end
    end
end
local function coverageAt(pos,rad)
    if not pos then return 0 end
    rad=tonumber(rad) or 17 -- unknown range: heuristic ONLY, not a unit stat
    local covered=0
    for _,sample in ipairs(run.pathSamples) do
        local x,z=sample.x-pos.X,sample.z-pos.Z
        if x*x+z*z < rad*rad then covered=covered+1 end
    end
    return covered
end
local function otherTowerCoverage(sample,exclude)
    local result=0
    for _,m in ipairs(ownUnits()) do
        if m~=exclude then
            local info=liveUnit(m)
            if info.role=='damage' or info.role=='control' then
                if info.pos then
                    local dx,dz=info.pos.X-sample.x,info.pos.Z-sample.z
                    local rad=info.range or 17
                    if dx*dx+dz*dz<rad*rad then result=result+1 end
                end
            end
        end
    end
    return result
end
local function spotScore(point,inv)
    if not point then return -1e9 end
    local existing=run.scoringTowers or {}
    for _,tower in ipairs(existing) do
        if tower.pos and (tower.pos-point).Magnitude<5 then return -1e9 end
    end
    if inv.role=='farm' then
        -- Never waste a farm placement on a defense-critical section of path.
        for _,sm in ipairs(run.pathSamples) do
            local dx,dz=point.X-sm.x,point.Z-sm.z
            if dx*dx+dz*dz<140 then return -1000 end
        end
        return 10
    end
    local range=inv.range or (run.knownRange or 19)
    if inv.role=='support' then
        -- Most buffs need friendly towers inside their effect radius, not enemies.
        local allied=0
        for _,tower in ipairs(existing) do
            if tower.role=='damage' and tower.pos then
                local distance=(tower.pos-point).Magnitude
                if distance<range then
                    allied=allied+1+math.min((tower.dps or 0)/1000,3)
                end
            end
        end
        if allied>0 then return allied*24 end
        return -1e6
    end
    local hit=0;local distinct=0;local nearbyPath=0
    for i,sm in ipairs(run.pathSamples) do
        local dx,dz=point.X-sm.x,point.Z-sm.z
        local distance=dx*dx+dz*dz
        if distance<16 then nearbyPath=nearbyPath+1 end
        if distance<range*range then
            hit=hit+1
            local overlap=(run.sampleOverlaps and run.sampleOverlaps[i]) or 0
            distinct=distinct+1/(1+overlap*.7)
        end
    end
    if nearbyPath>1 then return -1e7 end
    if (S.threatReport.boss or 0)>0 then distinct=distinct*1.35 end
    if inv.air and (S.threatReport.air or 0)>0 then distinct=distinct*1.30 end
    if hit==0 then return -1e6 end
    return distinct*2+hit*.3-nearbyPath*15
end
local function bestAutoLocation(inv)
    run.scoringTowers={}
    for _,m in ipairs(ownUnits()) do
        run.scoringTowers[#run.scoringTowers+1]=liveUnit(m)
    end
    run.sampleOverlaps={}
    for i,sm in ipairs(run.pathSamples) do
        local overlap=0
        for _,tower in ipairs(run.scoringTowers) do
            if (tower.role=='damage' or tower.role=='control') and tower.pos then
                local dx,dz=tower.pos.X-sm.x,tower.pos.Z-sm.z
                local rad=tower.range or 17
                if dx*dx+dz*dz<rad*rad then overlap=overlap+1 end
            end
        end
        run.sampleOverlaps[i]=overlap
    end
    local known=bestLiveMatch(inv)
    run.knownRange=(known and known.range) or 19
    if #run.pathSamples<2 then return nil,0,'Waiting to observe enemy route' end
    local best,bestScore=nil,-1e9
    local sources={}
    for i=1,#run.pathSamples,math.max(1,math.floor(#run.pathSamples/14)) do
        sources[#sources+1]=run.pathSamples[i]
    end
    -- Limit raycasts; cache search for 4.5 seconds between placements.
    local checked=0
    local rad=inv.role=='farm' and 23 or 9
    for _,src in ipairs(sources) do
        for dir=0,3 do
            local a=dir*math.pi/2 + (inv.slot%3)*.24
            local where=Vector3.new(src.x+math.cos(a)*rad,src.y,src.z+math.sin(a)*rad)
            local point=castGround(where)
            checked=checked+1
            if point then
                local cell=math.floor(point.X/4)..':'..math.floor(point.Z/4)
                if (run.badSpots[cell] or 0)<=os.clock() then
                    local score=spotScore(point,inv)
                    if score>bestScore then best,bestScore=point,score end
                end
            end
            if checked>=60 then break end
        end
        if checked>=60 then break end
    end
    if not best or bestScore<0 then return nil,bestScore,'No valid high-coverage spot found' end
    return best,bestScore,'Route coverage estimate; server must verify'
end
local function placedRoleCounts()
    local c={farm=0,damage=0,support=0,control=0,air=0}
    for _,m in ipairs(ownUnits()) do
        local info=liveUnit(m)
        c[info.role]=(c[info.role] or 0)+1
        if info.air and info.role=='damage' then c.air=c.air+1 end
    end
    return c
end
local function placementCap(inv)
    if tostring(inv.trait or ''):lower():find('unique',1,true) then return 1 end
    local default=S.options.maxEach
    if inv.farm then default=math.max(2,default) end
    return math.max(1,math.min(inv.maxPlaced or default,default))
end
local function candidatePriority(inv,roles)
    if countForSlot(inv.slot)>=placementCap(inv) then return -1e9,'placement cap' end
    local yen=scanMoney()
    if yen and inv.cost and yen<inv.cost then return -1e9,'not affordable' end
    local threat=S.threatReport or {}
    local w=wave()
    local expectedEnd= S.mode=='Infinite' and 60 or S.mode=='Dungeon' and 20 or 30
    local early=w<=math.floor(expectedEnd*.30)
    local live=bestLiveMatch(inv)
    local dps=(live and live.dps) or ((inv.damage and inv.spa and inv.spa>0) and inv.damage/inv.spa) or nil
    local attackRange=(live and live.range) or inv.range
    local score,reason=0,'general coverage'
    local counters=stageCounters()
    local counterPoints,counterWhy=matchBonus(inv,counters)
    if inv.role=='farm' then
        if not S.options.farming or not early then return -1e9,'farm window closed' end
        score=(roles.damage>=1 and 38 or -35) + (roles.farm==0 and 24 or -roles.farm*18)
        score=score-(threat.count or 0)*1.2
        reason='economy while defense is established'
    elseif inv.role=='damage' then
        score=30 + math.log(1+(dps or 1))*4 + math.min(attackRange or 16,60)*.15
        if roles.damage==0 then score=score+65;reason='first defense' end
        if (threat.air or 0)>0 and roles.air==0 then
            if inv.air then score=score+75;reason='urgent anti-air' else score=score-22 end
        end
        if (threat.boss or 0)>0 then score=score+12 end
        if threat.bossSoon then score=score+9 end
        if counterWhy~='' then reason=counterWhy end
        score=score-roles.damage*5
        if inv.cost and inv.cost>0 then score=score-math.log(1+inv.cost)*1.5 end
    elseif inv.role=='control' then
        score= (roles.damage>0 and 32 or 0) + ((threat.count or 0)>6 and 25 or 0)
        score=score-roles.control*25
        reason='control enemy swarms'
    elseif inv.role=='support' then
        score=(roles.damage>=2 and 26 or -20)-roles.support*22
        reason='buff established carries'
    end
    if inv.role~='farm' then score=score+counterPoints end
    if (inv.cost or 0)>0 and yen and yen>0 and inv.cost<=yen*.35 and inv.role=='damage' then score=score+12 end
    return score,reason
end
local function nextSmartUnit()
    if #S.inventory==0 then return nil end
    local roles=placedRoleCounts()
    local choices={}
    for _,inv in ipairs(S.inventory) do
        local score,reason=candidatePriority(inv,roles)
        choices[#choices+1]={unit=inv,score=score,reason=reason}
    end
    table.sort(choices,function(a,b)
        if a.score==b.score then return a.unit.slot<b.unit.slot end
        return a.score>b.score
    end)
    S.planReport={}
    for i,choice in ipairs(choices) do
        if i<=8 then S.planReport[#S.planReport+1]=
            choice.unit.id..' ['..choice.unit.role..'] priority='..math.floor(choice.score)..' ('..choice.reason..')'
        end
    end
    local best=choices[1]
    if best and best.score>-1e6 then return best.unit,best.reason end
    return nil
end
local function smartUpgradeChoice()
    local roles=placedRoleCounts()
    local yen=scanMoney()
    local w=wave()
    local threat=S.threatReport or {}
    local choices={}
    for _,m in ipairs(ownUnits()) do
        local v=liveUnit(m)
        local lv=v.level or 0
        local ready=not v.maxLevel or lv<v.maxLevel
        local lastFail=run.upgradeCooldown[m] or 0
        local affordable=not (yen and v.nextCost and v.nextCost>yen)
        if ready and lastFail<=os.clock() and affordable then
            local score=0
            local reason='stat-based estimate'
            local counters=stageCounters()
            local points,reasonCounter=matchBonus(v,counters)
            if v.role=='farm' then
                local limit=(S.mode=='Infinite' and 18 or S.mode=='Dungeon' and 7 or 9)
                score= (w<=limit and roles.damage>0) and 48-lv*4 or -70
                if (threat.count or 0)>9 then score=score-35 end
                reason='farm return before late waves'
            elseif v.role=='damage' then
                -- Favor damage-per-second and coverage, not round-robin upgrades.
                local base=math.log(1+(v.dps or 2))*8
                score=32+base+math.min(v.range or 15,55)*.12
                if (threat.boss or 0)>0 then score=score+15 end
                if threat.bossSoon then score=score+20 end
                if (threat.air or 0)>0 and v.air then score=score+32 end
                if lv<2 then score=score+7 end
                local extraDamage=num(m:FindFirstChild('_stats'),{'next_damage','upgrade_damage','next_upgrade_damage'})
                local extraSpa=num(m:FindFirstChild('_stats'),{'next_spa','next_attack_speed'})
                if extraDamage and extraSpa and extraSpa>0 and v.dps then
                    local gained=extraDamage/extraSpa-v.dps
                    if gained>0 then
                        score=score+(gained/(math.max(300,v.nextCost or 2000)))*200
                        reason='observed next-level DPS per Yen'
                    end
                else
                    reason='current DPS/coverage proxy; next-level stats unavailable'
                end
                if v.nextCost then score=score-math.log(1+v.nextCost)*2 end
            elseif v.role=='control' then
                score= (threat.count or 0)>5 and 40 or 13
                reason='crowd-control threshold'
            elseif v.role=='support' then
                score=roles.damage>=2 and 29 or -12
                reason='upgrade buffs after damage core'
            end
            if v.role~='farm' then
                score=score+points
                if reasonCounter~='' then reason=reason..'; '..reasonCounter end
            end
            choices[#choices+1]={unit=v,score=score,reason=reason}
        end
    end
    table.sort(choices,function(a,b) return a.score>b.score end)
    S.upgradeReport={}
    for i,v in ipairs(choices) do
        if i<=6 then
            S.upgradeReport[#S.upgradeReport+1]=
                v.unit.id..' lv='..tostring(v.unit.level or '?')..
                ' dps='..(v.unit.dps and string.format('%.1f',v.unit.dps) or '?')..
                ' cost='..tostring(v.unit.nextCost or '?')..
                ' score='..string.format('%.1f',v.score)..' ('..v.reason..')'
        end
    end
    if choices[1] and choices[1].score>0 then return choices[1] end
end
local function smartUpgradeOne()
    local pending=run.pendingUpgrade
    if pending then
        if not pending.model or not pending.model.Parent then run.pendingUpgrade=nil
        else
            local updated=liveUnit(pending.model)
            if updated.level and pending.level and updated.level>pending.level then
                run.pendingUpgrade=nil
            elseif os.clock()-pending.at<6 then
                return
            else
                run.upgradeCooldown[pending.model]=os.clock()+16
                run.pendingUpgrade=nil
            end
        end
    end
    local best=smartUpgradeChoice()
    if not best then return end
    local v=best.unit
    if not v.model then return end
    run.pendingUpgrade={model=v.model,level=v.level,at=os.clock()}
    task.spawn(function()
        local ok,detail=call('upgrade_unit_ingame',v.model)
        if not ok then
            run.upgradeCooldown[v.model]=os.clock()+16
            run.pendingUpgrade=nil
            if type(detail)=='string' and detail:find('Missing ',1,true) then note(detail) end
        end
    end)
end
-- ====================== END ADAPTIVE PLANNER ======================

local function autoLocation(slot,stepIndex)
    local center=enemyCenter()
    if not center then return nil end
    local farm=slot.farm and S.options.farming
    local idx=(stepIndex+run.candidate-2)%48
    local ring=math.floor(idx/12)
    local radius=(farm and 17 or 6)+(ring* (farm and 5 or 4))
    local a=(idx%12)*(math.pi/6)+((slot.slot%3)*.13)
    local candidate=center+Vector3.new(math.cos(a)*radius,0,math.sin(a)*radius)
    return castGround(candidate)
end
local function countForSlot(slot)
    return run.count[slot] or 0
end
local function limitForSlot(u)
    return u.farm and math.max(2,S.options.maxEach) or S.options.maxEach
end
local function findSlot(slot)
    for _,u in ipairs(S.inventory) do if u.slot==slot then return u end end
end
local function nextUnit()
    if #S.inventory==0 then return nil end
    for n=1,#S.inventory do
        local idx=(run.nextSlot-1)%#S.inventory+1
        run.nextSlot=idx+1
        local u=S.inventory[idx]
        if countForSlot(u.slot)<limitForSlot(u) then return u end
    end
end
local function totalPlaced()
    local n=0
    for _,c in pairs(run.count) do n=n+c end
    return n
end
local function matchedPlacement(uuid,where,previousCount)
    local matches=0
    for _,m in ipairs(ownUnits()) do
        local ms=m:FindFirstChild('_stats')
        local id=value(ms,'uuid')
        local p=unitPosition(m)
        if tostring(id)==tostring(uuid) and p and (p-where).Magnitude<5 then
            return true
        end
        matches=matches+1
    end
    return matches>previousCount -- fallback for builds without per-unit UUID values
end
local function recordSuccessful(step)
    local prof=profile()
    if step.isSaved then return end
    if #prof.steps>=40 then return end
    local key=tostring(step.slot)..':'..math.floor(step.pos.X)..':'..math.floor(step.pos.Z)
    for _,prev in ipairs(prof.steps) do
        if prev.key==key then return end
    end
    local entry={slot=step.slot,x=step.pos.X,y=step.pos.Y,z=step.pos.Z,
        wave=step.wave,key=key}
    table.insert(prof.steps,entry)
    if os.clock()-run.lastSave>2 then run.lastSave=os.clock();saveSettings() end
end
local function finishPending()
    local p=run.pending
    if not p then return false end
    if matchedPlacement(p.unit.uuid,p.pos,p.before) then
        run.count[p.unit.slot]=countForSlot(p.unit.slot)+1
        recordSuccessful({slot=p.unit.slot,pos=p.pos,wave=p.wave,isSaved=p.isSaved})
        if p.isSaved then run.savedIndex=run.savedIndex+1 end
        run.pending=nil
        run.candidate=run.candidate+1
        note('Placed '..p.unit.id..' | '..totalPlaced()..'/'..S.options.maxTotal..' | wave '..wave())
        return true
    end
    if os.clock()-p.when<5 then return true end
    run.pending=nil
    if p.pos then
        local cell=math.floor(p.pos.X/4)..':'..math.floor(p.pos.Z/4)
        run.badSpots[cell]=os.clock()+240 -- avoid retrying rejected location
    end
    run.candidate=run.candidate+1
    if p.isSaved then
        p.tries=(p.tries or 0)+1
        if p.tries>=3 then
            run.savedIndex=run.savedIndex+1
        else
            run.used[run.savedIndex]=p.tries
        end
    end
    return false
end
local function placeOne()
    if not S.options.place or not isStarted() or isFinished() then return end
    if totalPlaced()>=S.options.maxTotal then return end
    if os.clock()-run.lastPlace<4.5 then return end
    if run.pending then
        if finishPending() then return end
    end
    if #S.inventory==0 then
        if os.clock()-S.inventoryAt>15 then scanEquipped() end
        if not run.inventoryWarned then
            run.inventoryWarned=true
            note('No equipped UUIDs detected. Tap COPY DIAGNOSTICS for debugging.')
        end
        return
    end
    local unit,point,fromSaved=false,nil,false
    if S.options.smartPlace then
        local reason
        unit,reason=nextSmartUnit()
        if unit then
            local explanation
            point,_,explanation=bestAutoLocation(unit)
            if not point then
                if os.clock()-(run.lastPlanWarn or 0)>16 then
                    run.lastPlanWarn=os.clock()
                    note('Planner: '..tostring(explanation))
                end
                return
            end
        end
    end
    local saved=profile().steps
    while not unit and S.options.savedMacros and run.savedIndex<=#saved do
        local step=saved[run.savedIndex]
        local this=findSlot(tonumber(step.slot))
        if this and countForSlot(this.slot)<limitForSlot(this) and tonumber(step.x) then
            unit=this
            point=Vector3.new(step.x,step.y,step.z)
            fromSaved=true
            break
        else
            run.savedIndex=run.savedIndex+1
        end
    end
    if not unit and not S.options.smartPlace then
        unit=nextUnit()
        if not unit then return end
        point=autoLocation(unit,totalPlaced()+1)
        if not point then
            if math.floor(os.clock())%15==0 then note('Waiting for visible enemies to locate the path...') end
            return
        end
    end
    if not unit or not point then return end
    local before=#ownUnits()
    local c=CFrame.new(point)
    run.pending={unit=unit,pos=point,before=before,when=os.clock(),wave=wave(),
        isSaved=fromSaved,tries=fromSaved and (run.used[run.savedIndex] or 0) or 0}
    run.lastPlace=os.clock()
    task.spawn(function()
        local ok,detail=call('spawn_unit',unit.uuid,c)
        if S.alive and not ok and type(detail)=='string' and detail:find('Missing ',1,true) then
            note('Placement remote unavailable: '..detail)
        end
    end)
end
local function upgradeOne()
    if S.options.smartUpgrade then return smartUpgradeOne() end
    local units=ownUnits()
    if #units==0 then return end
    table.sort(units,function(a,b)
        local fa,fb=isFarmModel(a),isFarmModel(b)
        if fa~=fb and wave()<=12 and S.options.farming then return fa end
        local sa,sb=a:FindFirstChild('_stats'),b:FindFirstChild('_stats')
        local al=tonumber(value(sa,'upgrade')) or 0
        local bl=tonumber(value(sb,'upgrade')) or 0
        return al<bl
    end)
    run.upgradeIndex=run.upgradeIndex+1
    for offset=0,#units-1 do
        local u=units[(run.upgradeIndex+offset-1)%#units+1]
        local stats=u:FindFirstChild('_stats')
        local level=tonumber(value(stats,'upgrade'))
        local max=tonumber(value(stats,'max_upgrade'))
        if not level or not max or level<max then
            task.spawn(function() call('upgrade_unit_ingame',u) end)
            return
        end
    end
end
local function abilityOne()
    for _,u in ipairs(ownUnits()) do
        local stats=u:FindFirstChild('_stats')
        local ability=value(stats,'active_attack')
        if ability~=nil and tostring(ability)~='' and tostring(ability)~='nil'
            and os.clock()-(abilityAt[u] or 0)>28 then
            abilityAt[u]=os.clock()
            task.spawn(function() call('use_active_attack',u) end)
            return
        end
    end
end

-- Optional one-time learner: captures only endpoints whose *names* describe
-- joining/starting an event. It never records inventory, payment or summon calls.
local function enc(v,depth)
    depth=depth or 0
    if depth>3 then return nil end
    local ty=typeof(v)
    if ty=='string' and #v<160 then return {t='str',v=v} end
    if ty=='number' and v==v and math.abs(v)<1e12 then return {t='num',v=v} end
    if ty=='boolean' then return {t='bool',v=v} end
    if ty=='Vector3' then return {t='v3',v={v.X,v.Y,v.Z}} end
    if ty=='CFrame' then return {t='cf',v={v:GetComponents()}} end
    if type(v)=='table' then
        local out={};local n=0
        for k,a in pairs(v) do
            n=n+1;if n>20 then return nil end
            if type(k)~='string' and type(k)~='number' then return nil end
            local item=enc(a,depth+1)
            if not item then return nil end
            out[tostring(k)]=item
        end
        return {t='tab',v=out}
    end
    return nil -- Instances cannot safely be persisted between games
end
local function dec(data)
    if type(data)~='table' then return nil end
    if data.t=='str' or data.t=='num' or data.t=='bool' then return data.v end
    if data.t=='v3' then return Vector3.new(table.unpack(data.v)) end
    if data.t=='cf' then return CFrame.new(table.unpack(data.v)) end
    if data.t=='tab' then
        local out={}
        for k,v in pairs(data.v) do out[tonumber(k) or k]=dec(v) end
        return out
    end
end
-- ============= V5 OPT-IN LOADOUT EQUIP LEARNING =============
-- The player must perform one normal equip action. Unknown remote signatures
-- cannot be inferred from names, and replay stops on failed verification.
local function allowedEquipName(name)
    name=lower(name)
    if contains(name,'unequip') or contains(name,'purchase') or contains(name,'buy')
        or contains(name,'sell') or contains(name,'delete') or contains(name,'summon')
        or contains(name,'trait') then return false end
    return contains(name,'equip') and contains(name,'unit')
end
local function encodedContains(data,wanted)
    if type(data)~='table' then return false end
    if data.t=='str' and tostring(data.v)==tostring(wanted) then return true end
    if data.t=='tab' then
        for _,v in pairs(data.v or {}) do if encodedContains(v,wanted) then return true end end
    end
    return false
end
local function replaceEncoded(data,old,new)
    if type(data)~='table' then return end
    if data.t=='str' and tostring(data.v)==old then data.v=new
    elseif data.t=='tab' then
        for _,v in pairs(data.v) do replaceEncoded(v,old,new) end
    end
end
local function captureEquipAction(remote,method,args)
    if not S.equipLearning or os.clock()>S.equipLearningEnds then return end
    if not allowedEquipName(remote.Name) or not remote:IsDescendantOf(RS) then return end
    local encoded={}
    for i=1,args.n do
        encoded[i]=enc(args[i]);if not encoded[i] then return end
    end
    local uuid
    local numUUIDs=0
    for _,u in ipairs(S.owned) do
        local found=false
        for _,e in ipairs(encoded) do
            if encodedContains(e,u.uuid) then found=true;break end
        end
        if found then uuid=u.uuid;numUUIDs=numUUIDs+1 end
        if numUUIDs>1 then break end
    end
    if numUUIDs~=1 then return end
    for _,already in ipairs(S.inventory) do
        if already.uuid==uuid then return end -- a no-op on an already-equipped unit is not valid training
    end
    local draft={name=remote.Name,method=method,args=encoded,exampleUUID=uuid,verified=false}
    task.defer(function()
        if not S.alive or not S.equipLearning then return end
        S.equipCandidate=draft
        S.equipLearning=false
        note('Equip call found ('..draft.name..'). Checking actual team change...')
        task.delay(3,function()
            if not S.alive then return end
            scanEquipped()
            local ok=false
            for _,v in ipairs(S.inventory) do if v.uuid==uuid then ok=true;break end end
            if ok then
                draft.verified=true
                S.equipTemplate=draft
                saveSettings()
                note('Equip mapping learned and confirmed. Auto-equip can now be enabled.')
            else
                note('Equip action was observed but could not verify roster: auto-equip unavailable.')
            end
        end)
    end)
end
local function tryEquipTeam()
    if not S.options.autoEquip or S.enabled==false or isMatch() then return end
    if not S.equipTemplate or not S.equipTemplate.verified then return end
    if os.clock()-(S.lastEquipAt or 0)<12 then return end
    if (S.equipChanges or 0)>=6 then return end
    if #S.owned==0 or S.map=='unknown' then return end
    if #S.teamPlan==0 then recommendTeam() end
    local inSlot={}
    for _,unit in ipairs(S.inventory) do inSlot[unit.uuid]=true end
    local beforeMatches=0
    for _,sel in ipairs(S.teamPlan) do
        if inSlot[sel.unit.uuid] then beforeMatches=beforeMatches+1 end
    end
    local needed
    for _,sel in ipairs(S.teamPlan) do
        if not inSlot[sel.unit.uuid] then needed=sel.unit;break end
    end
    if not needed then return end
    local tpl=S.equipTemplate
    if not getRemote(tpl.name) then return end
    local cloned=HTTP:JSONDecode(HTTP:JSONEncode(tpl.args))
    for _,d in ipairs(cloned) do replaceEncoded(d,tpl.exampleUUID,needed.uuid) end
    local args={}
    for i,e in ipairs(cloned) do args[i]=dec(e) end
    S.lastEquipAt=os.clock();S.equipChanges=(S.equipChanges or 0)+1
    task.spawn(function()
        local ok,msg=call(tpl.name,table.unpack(args,1,#args))
        if not ok then
            S.options.autoEquip=false
            note('Equip remote failed; disabled AUTO EQUIP: '..tostring(msg))
            return
        end
        task.wait(3.5)
        scanEquipped()
        local verified=false
        for _,u in ipairs(S.inventory) do if u.uuid==needed.uuid then verified=true;break end end
        if verified then
            local afterMap={}
            for _,unit in ipairs(S.inventory) do afterMap[unit.uuid]=true end
            local afterMatches=0
            for _,sel in ipairs(S.teamPlan) do
                if afterMap[sel.unit.uuid] then afterMatches=afterMatches+1 end
            end
            if afterMatches<=beforeMatches then
                S.options.autoEquip=false
                note('Equip did not improve the team; auto-equip stopped to prevent cycling slots.')
            else
                note('Verified equipping '..needed.id..' (team fit '..afterMatches..'/'..#S.teamPlan..')')
                recommendTeam()
            end
        else
            S.options.autoEquip=false
            note('Equip did not verify in inventory; AUTO EQUIP stopped.')
        end
    end)
end
-- ============== END V5 EQUIP ==============

local function isJoinName(name)
    name=tostring(name):lower()
    if name:find('purchase') or name:find('buy') or name:find('summon')
        or name:find('roll') or name:find('trait') then return false end
    local isRelevant=name:find('lobby') or name:find('matchmak') or name:find('queue')
        or name:find('join') or name:find('start_game') or name:find('event')
        or name:find('play_level')
    return isRelevant~=nil
end
local function installCapture()
    if type(hookmetamethod)~='function' or type(getnamecallmethod)~='function'
        or type(newcclosure)~='function' then return false,'No hook support' end
    local old
    local ok,err=pcall(function()
        old=hookmetamethod(game,'__namecall',newcclosure(function(self,...)
            if S.alive and S.equipLearning and os.clock()<S.equipLearningEnds then
                local method=getnamecallmethod()
                local own=type(checkcaller)=='function' and checkcaller()
                if not own and (method=='InvokeServer' or method=='FireServer')
                    and typeof(self)=='Instance' and self:IsDescendantOf(RS) then
                    local args=table.pack(...)
                    captureEquipAction(self,method,args)
                end
            end
            if S.alive and S.queueLearning and os.clock()<S.queueLearningEnds then
                local method=getnamecallmethod()
                local own=type(checkcaller)=='function' and checkcaller()
                if not own and (method=='InvokeServer' or method=='FireServer')
                    and typeof(self)=='Instance' and isJoinName(self.Name)
                    and self:IsDescendantOf(RS) then
                    local args=table.pack(...)
                    local encoded={};local all=true
                    for i=1,args.n do
                        encoded[i]=enc(args[i])
                        if not encoded[i] then all=false;break end
                    end
                    if all and #S.eventQueue<6 then
                        local r={name=self.Name,args=encoded,method=method}
                        task.defer(function()
                            if not S.alive then return end
                            table.insert(S.eventQueue,r)
                            note('Learned event join action '..#S.eventQueue..': '..self.Name)
                            saveSettings()
                        end)
                    end
                end
            end
            if S.alive and S.options.autoReport and S.mode=='Event'
                and isMatch() and #S.eventActionBuffer<30 then
                local method=getnamecallmethod()
                local own=type(checkcaller)=='function' and checkcaller()
                if not own and (method=='FireServer' or method=='InvokeServer')
                    and typeof(self)=='Instance' and self:IsDescendantOf(RS) then
                    local name=tostring(self.Name)
                    local low=name:lower()
                    local relevant=low:find('place',1,true) or low:find('spawn',1,true)
                        or low:find('spell',1,true) or low:find('card',1,true)
                        or low:find('offer',1,true) or low:find('ability',1,true)
                        or low:find('unit',1,true)
                    if relevant and not low:find('purchase',1,true)
                        and not low:find('buy',1,true)
                        and not low:find('summon',1,true) then
                        local args=table.pack(...)
                        local shape={}
                        for i=1,math.min(args.n,7) do
                            local v=args[i]
                            local typ=typeof(v)
                            if typ=='table' then
                                local keys={};local count=0
                                for key in pairs(v) do
                                    count=count+1
                                    if #keys<4 then keys[#keys+1]=type(key) end
                                    if count>=16 then break end
                                end
                                typ='table['..table.concat(keys,',')..']'
                            elseif typ=='string' then
                                typ='string('..math.min(#v,999)..')'
                            end
                            shape[#shape+1]=typ
                        end
                        local signature=name..'/'..method..' args='..args.n..
                            ' ['..table.concat(shape,', ')..']'
                        if not S.eventActionSeen[signature] then
                            S.eventActionSeen[signature]=true
                            S.eventActionBuffer[#S.eventActionBuffer+1]=signature
                        end
                    end
                end
            end
            return old(self,...)
        end))
    end)
    return ok,err
end
-- Mobile stability hotfix: do NOT install a permanent __namecall hook on load.
-- A preexisting hook from older injections only disappears after restarting Roblox.
local captureOK,captureErr=false,'Disabled by mobile stability mode (restart Roblox to clear old hooks)'
local function replayQueue()
    if #S.eventQueue==0 then return false end
    task.spawn(function()
        for _,action in ipairs(S.eventQueue) do
            if not S.alive or not S.enabled or isMatch() then return end
            local args={}
            for i,e in ipairs(action.args) do args[i]=dec(e) end
            local ok,detail=call(action.name,table.unpack(args,1,#action.args))
            if not ok then note('Event queue action failed: '..tostring(detail)) end
            task.wait(2)
        end
    end)
    return true
end


-- ================== RESEARCH-INFORMED CARD DECISION ENGINE ==================
-- Uses only visible game UI, NEVER fabricates server remote names for cards.
-- Defaults to advisor mode. Automatic input requires a detectable, distinct set of
-- options and executor-provided UI input support. This is NOT a guaranteed clear.
local gui -- forward declaration; assigned when the mobile UI is created
local tipBanner,tipTitle,tipDetail -- always-visible card recommendation overlay
local function cleanText(s)
    s=tostring(s or ''):gsub('<.->',' '):gsub('%s+',' ')
    return (s:gsub('^%s+',''):gsub('%s+$',''))
end
local function visible(thing)
    local x=thing
    while x and x~=game do
        if x:IsA('ScreenGui') and not x.Enabled then return false end
        if x:IsA('GuiObject') and not x.Visible then return false end
        x=x.Parent
    end
    return true
end
local function readDesc(container)
    local all={};local n=0
    for _,x in ipairs(container:GetDescendants()) do
        if (x:IsA('TextLabel') or x:IsA('TextButton') or x:IsA('TextBox'))
            and visible(x) and #all<15 then
            local v=cleanText(x.Text)
            if #v>2 and #v<250 then
                table.insert(all,v)
                n=n+1
            end
        end
    end
    if container:IsA('TextButton') then table.insert(all,cleanText(container.Text)) end
    return table.concat(all,' | '):sub(1,540)
end
local function isCandidate(text)
    local low=text:lower()
    local keywords={'curse','bless','enemy','tower','damage','attack','speed',
        'range','hoard','luck','currency','path','regen','health','shield',
        'upgrade','ritual','clone','merge','astral','spell','relic',
        'chest','cash','gold','buff','rare','true dmg'}
    for _,w in ipairs(keywords) do if low:find(w,1,true) then return true end end
    return false
end
local function cardFrame(button)
    -- Prefer a single choice's immediate card container, not the entire choice panel.
    local parent=button.Parent
    for i=1,3 do
        if not parent or not parent:IsA('GuiObject') then break end
        local t=readDesc(parent)
        if #t>=24 and isCandidate(t) then return parent,t end
        parent=parent.Parent
    end
    return button,cleanText(button:IsA('TextButton') and button.Text or button.Name)
end
local function scanCards()
    local guiRoot=LP:FindFirstChild('PlayerGui')
    if not guiRoot then return {} end
    local candidates={};local seen={};local inspected=0
    for _,b in ipairs(guiRoot:GetDescendants()) do
        if (b:IsA('TextButton') or b:IsA('ImageButton')) and visible(b)
            and b.AbsoluteSize.X>=25 and b.AbsoluteSize.Y>=15
            and not b:IsDescendantOf(gui) then
            local low=(b.Name..' '..(b:IsA('TextButton') and b.Text or '')):lower()
            local looksLikeVote = low:find('vote') or low:find('card') or
                low:find('choose') or low:find('pick') or low:find('select') or
                low:find('accept') or low:find('reward') or low:find('curse') or
                low:find('bless') or low:find('option')
            -- Only inspect descendants for buttons in plausible card menus.
            -- Old code traversed nested GUI trees for nearly EVERY Roblox UI button.
            local ancestry=b.Parent;local context=''
            for depth=1,4 do
                if not ancestry or not ancestry:IsA('GuiObject') then break end
                context=context..' '..ancestry.Name:lower()
                ancestry=ancestry.Parent
            end
            local inDecision=context:find('card',1,true) or
                context:find('vote',1,true) or context:find('modifier',1,true) or
                context:find('option',1,true) or context:find('choice',1,true) or
                context:find('curse',1,true) or context:find('bless',1,true) or
                context:find('reward',1,true) or context:find('relic',1,true)
            if looksLikeVote or inDecision then
                inspected=inspected+1
                if inspected>50 then break end
                local f,t=cardFrame(b)
                if #t>=24 and isCandidate(t)
                    and not t:lower():find('purchase',1,true)
                    and not t:lower():find('robux',1,true) then
                    local id=t:lower():sub(1,130)
                    if not seen[id] then
                        seen[id]=true
                        table.insert(candidates,{text=t,button=b,frame=f})
                    end
                end
            end
        end
    end
    -- Distinct choices only. If too many menus appear, no automatic click.
    return candidates
end
local function scoreCard(raw)
    local t=raw:lower();local score=0;local reasons={};local risk=0;local benefit=0
    local function plus(points,word)
        score=score+points; benefit=benefit+math.max(0,points)
        reasons[#reasons+1]=word..' '..(points>=0 and '+' or '')..points
    end
    local function minus(points,word)
        score=score-points;risk=risk+points
        reasons[#reasons+1]=word..' -'..points
    end
    local function has(s) return t:find(s,1,true)~=nil end
    local function any(list)
        for _,s in ipairs(list) do if has(s) then return true end end
        return false
    end
    -- These identifiable blessings come from documented Dungeon 20 lists.
    if any({'philosopher','philosophers stone'}) then plus(90,'rare-chest conversion') end
    if has('genie lamp') then plus(55,'chest luck') end
    if has('mask of riches') then plus(70,'half-cost units') end
    if any({'golden mushroom','golden branch'}) then plus(35,'economy') end
    if any({'fishhook','fish hook','chest luck'}) and not has('genie lamp') then plus(22,'chest luck') end
    if any({'glacial axe','enemy slow','enemies move slower','enemies will move -'}) then plus(40,'enemy slow') end
    if any({'archmage','magic tome','mage coat','magic dmg','magic damage'}) then plus(32,'magic DPS') end
    if any({'aures','headsplitt','physical dmg','physical damage'}) then plus(32,'physical DPS') end
    if any({'celestial blade','true dmg','true damage'}) then plus(55,'true damage') end
    if any({'sy lvanthorn','sylvanthorn','elf bow','range increase'}) then plus(19,'range') end
    if any({'reaper scythe','reaper sythe','boss damage'}) then plus(22,'boss DPS') end
    if any({'scimitar','sword','ninja belt','attack speed','damage increase'}) then plus(22,'attack') end
    if any({'placement cost','upgrade cost','cost reduction','discount'}) then plus(22,'lower cost') end
    if any({'chest','rare'}) and not any({'curse','enemy','reward','philosopher','genie','fishhook'}) then plus(10,'chest') end
    -- Fool's Hunt powers require selecting a target tower. These are advice scores,
    -- not permission to cast them blindly.
    if has('astral summon') then plus(60,'recover equipped unit')
    elseif has('astral gate') then plus(24,'future astral odds') end
    if has('ritual') then plus(35,'potential Divine General') end
    if has('clone') then plus(26,'copy high-upgrade unit') end
    if has('merge') then plus(17,'merge duplicate towers') end
    if has('random buff') then plus(21,'target strongest carry') end
    if has('refund') then plus(8,'recover Yen') end
    -- Fool's Hunt presents generic blessings such as "+12% Attack" and "+15% Range".
    -- Score the positive modifier itself, not just named Dungeon items.
    local attackPct=tonumber(t:match('%+(%d+)%%%s*attack'))
    local rangePct=tonumber(t:match('%+(%d+)%%%s*range'))
    if attackPct and not has('enemy attack') then
        plus(math.clamp(attackPct*1.8,8,42),'tower attack +%')
    end
    if rangePct and not has('enemy range') then
        plus(math.clamp(rangePct*1.05,5,30),'tower range +%')
    end
    -- Costly curses; unknown values are NEVER presumed safe.
    if any({'new path','extra path','additional path','enemy paths','more paths'}) then minus(72,'extra lanes') end
    if any({'curse of chaos','all curses are random'}) then minus(90,'random curses') end
    if any({'curse of burst','burst trait','faster spawns','spawn frequency'}) then minus(76,'burst') end
    if any({'curse of frenzy','curse of wind','fast enemies','enemy speed','enemies move faster'}) then
        -- Repeated Wave 8-16 losses: speed shortens the time available to kill.
        local severe=S.mode=='Event' and wave()<=18
        minus(severe and 77 or 55,'enemy speed')
    end
    if any({'curse of flight','flying trait','flying enemies'}) then minus(50,'air threat') end
    if any({'curse of shielding','shield','curse of armor','armr trait'}) then minus(36,'shields/armor') end
    if any({'curse of vamp','curse of regen','regeneration','enemies regenerate','enemy regen'}) then minus(42,'regeneration') end
    if any({'curse of health','enemy health','enemies get +','strong enemies','tank enemies'}) then minus(45,'enemy HP') end
    -- Fool's Hunt has physical/magic resistance curses, not blessings.
    -- Never treat these as a neutral 0-score choice.
    local physicalResist=any({'enemy physical resist','enemies physical resist'})
    local magicResist=any({'enemy magic resist','enemies magic resist'})
    if physicalResist then minus(28,'enemy physical resist') end
    if magicResist then minus(28,'enemy magic resist') end
    if magicResist and S.mode=='Event' then
        local magic,physical=0,0
        for _,tower in ipairs(ownUnits()) do
            local st=tower:FindFirstChild('_stats')
            local typ=lower(stat(st,{'damage_type','attack_affinity','element','affinity',
                'attack_type','damage_affinity'}))
            if contains(typ,'magic') then magic=magic+1
            elseif contains(typ,'physical') then physical=physical+1 end
        end
        if magic>=2 and magic>physical then
            minus(28,'magic-heavy active team')
        end
    end
    if has('resistant enemies') and not physicalResist and not magicResist then
        minus(45,'enemy resistance')
    end
    if has('spellproof enemies') and not magicResist then
        minus(30,'enemy magic resistance')
    end
    if any({'curse of eruption','curse of explosion','explosive death'}) then minus(52,'stuns on death') end
    if any({'curse of shopping','shop prices'}) then minus(12,'higher prices') end
    if any({'curse of money','hoard drops','reduced money'}) then minus(22,'reduced economy') end
    if any({'dodge','dodging','miss chance'}) then minus(32,'enemy dodge') end
    -- Reward multipliers may make curses worthwhile for a heavily overpowered team.
    if any({'event currency','event reward','portal chance','drop chance','stars per wave','candies per wave',
        'aprilcoins','april coins'}) then
        local pct=tonumber(t:match('currency[^%%]*%+(%d+)%%')) or
                  tonumber(t:match('reward[^%%]*%+(%d+)%%')) or
                  tonumber(t:match('drop[^%%]*%+(%d+)%%')) or
                  tonumber(t:match('%+(%d+)%%%s*april%s*coins')) or
                  tonumber(t:match('(%d+)%%[^|]-currency'))
        local gain=math.clamp((pct or 15)*(S.goal=='Rewards' and 2.65 or 0.35),
            5,S.goal=='Rewards' and 100 or 35)
        plus(gain,'event reward (+'..tostring(pct or '?')..'%)')
    end
    if has('curse') and benefit==0 and risk==0 then minus(25,'unknown curse') end
    -- Late-run failure costs multiply; reward mode tolerates more risk.
    local w=wave()
    local remaining=(S.mode=='Event' and math.max(0,30-w)) or (S.mode=='Dungeon' and 20) or 30
    local stageRisk=(w>=20 and 1.35 or w>=10 and 1.15 or 1)
    if S.goal=='Safe' then score=score-risk*.55*stageRisk
    elseif S.goal=='Rewards' then score=score-risk*.12*stageRisk
    else score=score-risk*.15*stageRisk end
    if remaining<=10 then score=score-risk*(S.goal=='Rewards' and .22 or .15) end
    return math.floor(score*10)/10,risk,benefit,table.concat(reasons,', ')
end
local function decideCards()
    local entries=scanCards()
    S.cardSnapshot={}
    for _,entry in ipairs(entries) do
        entry.score,entry.risk,entry.benefit,entry.reason=scoreCard(entry.text)
        S.cardSnapshot[#S.cardSnapshot+1]={text=entry.text,score=entry.score,
            risk=entry.risk,benefit=entry.benefit,reason=entry.reason}
    end
    table.sort(entries,function(a,b) return a.score>b.score end)
    if #entries<2 then
        S.cardStatus='Need at least 2 recognized choices; '..#entries..' found'
        return nil
    end
    if #entries>5 then S.cardStatus='Too many candidate buttons; refusing auto-vote';return nil end
    local top=entries[1]
    local second=entries[2]
    local gap=top.score-second.score
    local key=tostring(wave())..'|'..top.text:sub(1,90)
    S.cardStatus='Best score '..top.score..' (margin '..math.floor(gap)..'): '..top.text:sub(1,100)
    if gap<8 then S.cardStatus=S.cardStatus..' | too close to auto-pick' end
    return {entry=top,key=key,margin=gap,count=#entries}
end
local function tryCardPress(btn)
    if not btn or not btn.Parent or not visible(btn) then return false,'Invisible button' end
    if type(firesignal)=='function' then
        local ok=pcall(function() firesignal(btn.Activated) end)
        if ok then return true,'Activated event' end
        ok=pcall(function() firesignal(btn.MouseButton1Click) end)
        if ok then return true,'Mouse click event' end
    end
    -- Executor-dependent mouse input: may fail under Android/Delta.
    local ok,why=pcall(function()
        local vim=game:GetService('VirtualInputManager')
        local pos=btn.AbsolutePosition+btn.AbsoluteSize*.5
        vim:SendMouseButtonEvent(pos.X,pos.Y,0,true,game,0)
        task.wait(.07)
        vim:SendMouseButtonEvent(pos.X,pos.Y,0,false,game,0)
    end)
    return ok,ok and 'VIM click' or tostring(why)
end
local function tickCards()
    if not S.options.cardAdvisor or not isMatch() or isFinished() then
        if tipBanner then tipBanner.Visible=false end
        return
    end
    local decision=decideCards()
    if not decision then
        if tipBanner then tipBanner.Visible=false end
        return
    end
    if tipBanner and tipTitle and tipDetail then
        local first=tostring(decision.entry.text):match('^[^|]+') or tostring(decision.entry.text)
        first=cleanText(first):sub(1,46)
        tipTitle.Text='PICK: '..first
        local strategy=S.goal=='Rewards' and 'BIG REWARDS' or
            (S.goal=='Safe' and 'SAFE CLEAR' or 'BALANCED')
        local confidence=decision.margin<6 and ' | CLOSE CALL' or ''
        tipDetail.Text=strategy..' | auto '..(S.options.autoCards and 'ON' or 'OFF')..
            ' | score '..math.floor(decision.entry.score)..confidence
        tipBanner.Visible=true
    end
    if decision.key~=S.lastCardKey and os.clock()-S.lastCardAlert>3 then
        S.lastCardKey=decision.key
        S.lastCardAlert=os.clock()
        note('CARD ADVISOR: '..S.cardStatus)
    end
    -- Card choosing is independent of FULL AUTO for Fool's Hunt random units.
    if not S.options.autoCards then return end
    if decision.margin<6 or decision.count>4 or decision.count<2 then return end
    -- Never auto-click unless at least two distinct, readable alternatives are present.
    if os.clock()-S.lastCardAttempt<12 then return end
    local riskCap=S.goal=='Safe' and 55 or S.goal=='Rewards' and 72 or 65
    if decision.entry.risk>riskCap then return end
    -- Powers are target-sensitive actions; card voting does not cast spells.
    local lc=decision.entry.text:lower()
    for _,spell in ipairs({'astral summon','astral gate','ritual','clone','merge',
        'random buff','refund'}) do
        if lc:find(spell,1,true) then return end
    end
    S.lastCardAttempt=os.clock()
    local ok,how=tryCardPress(decision.entry.button)
    table.insert(S.cardHistory,1,{wave=wave(),map=S.map,goal=S.goal,
        text=decision.entry.text:sub(1,300),score=decision.entry.score,
        successInput=ok,method=how,time=os.time()})
    while #S.cardHistory>45 do table.remove(S.cardHistory) end
    note('Card '..(ok and 'input attempted' or 'NOT clicked')..': '..tostring(how))
    saveSettings()
end
-- ================== END CARD DECISION ENGINE ==================


-- ================== V5.1 HANDS-FREE RUN REPORTER ==================
-- Runs separately from full autofarm. No remote calls that place/upgrade/vote.
-- Clipboard is just the latest report; local file is the safer backup when supported.
local REPORT_FILE='K_AA_AutoReport_'..tostring(LP.UserId)..'_'..tostring(game.PlaceId)..'.txt'
local reporter={active=false,closed=false,folder=nil,lines={},seenCards={},
    seenBosses={},seenThreats={},seenConfirms={},lastWave=-1,lastCardsAt=0,lastEnemiesAt=0,
    diskCache=nil,session=0,lastTick=0,filesOK=false,
    pendingEndAt=0,finalEnemyLogged=false}
local function reportText()
    return table.concat(reporter.lines,'\n')
end
local function persistReport(line)
    local chunk=line..'\n'
    if type(appendfile)=='function' then
        local ok=pcall(function()
            if type(isfile)=='function' and not isfile(REPORT_FILE)
                and type(writefile)=='function' then writefile(REPORT_FILE,'') end
            appendfile(REPORT_FILE,chunk)
        end)
        if ok then reporter.filesOK=true;return true end
    end
    if type(writefile)=='function' then
        if reporter.diskCache==nil then
            reporter.diskCache=''
            if type(readfile)=='function' then
                pcall(function()
                    if type(isfile)~='function' or isfile(REPORT_FILE) then
                        reporter.diskCache=readfile(REPORT_FILE) or ''
                    end
                end)
            end
        end
        reporter.diskCache=reporter.diskCache..chunk
        local ok=pcall(function() writefile(REPORT_FILE,reporter.diskCache) end)
        if ok then reporter.filesOK=true;return true end
    end
    return false
end
local function copyReport()
    if type(setclipboard)~='function' then return false end
    local txt=reportText()
    if #txt==0 then return false end
    return pcall(function() setclipboard(txt) end)
end
local function recordLine(kind,detail,copyNow)
    local txt=string.format('[%s][wave=%s][%s] %s',
        os.date('%Y-%m-%d %H:%M:%S'),tostring(wave()),kind,
        tostring(detail or ''):gsub('[\r\n]+',' / '):sub(1,2500))
    reporter.lines[#reporter.lines+1]=txt
    if #reporter.lines>240 then table.remove(reporter.lines,1) end
    persistReport(txt)
    if copyNow and S.options.autoCopyReport then
        if copyReport() then note('AUTO REPORT copied: '..kind..' | saved='..tostring(reporter.filesOK)) end
    end
end
local function resultText()
    local pgui=LP:FindFirstChild('PlayerGui')
    local result=pgui and pgui:FindFirstChild('ResultsUI')
    if not result or not result.Enabled then
        return 'Unconfirmed (no active results panel)'
    end
    -- Hidden template labels can contain both VICTORY and DEFEAT.
    -- Only use visible descendants, and never trust demo placeholder values.
    local words={}
    for _,x in ipairs(result:GetDescendants()) do
        if (x:IsA('TextLabel') or x:IsA('TextButton'))
            and visible(x) and #words<35 then
            local word=cleanText(x.Text)
            if #word>0 and #word<=100 then words[#words+1]=word end
        end
    end
    local desc=table.concat(words,' | '):sub(1,450)
    local low=desc:lower()
    local victory=low:find('victory',1,true)~=nil
    local defeat=low:find('defeat',1,true)~=nil or low:find('failed',1,true)~=nil
    local placeholder=low:find('999999',1,true)~=nil
        or low:find('1234567890',1,true)~=nil
    local status='Unconfirmed'
    if not placeholder then
        if defeat and not victory then status='Defeat'
        elseif victory and not defeat then status='Victory' end
    end
    -- Fool's Hunt is a 30-wave run. A visible victory template before wave 30
    -- is not evidence of a clear, even if it is the only detected label.
    local stage=string.lower(tostring((S.stageData or {}).name or ''))
    if S.mode=='Event' and (S.map=='april2_event' or stage:find("fool",1,true))
        and wave()<30 and status=='Victory' then status='Unconfirmed' end
    if placeholder then
        return status..' | placeholder result labels found; wave='..wave()
    end
    return status..' | '..desc
end
local function unitSnapshot()
    local sample={}
    local units=ownUnits()
    for _,u in ipairs(units) do
        if #sample>=14 then break end
        local stats=u:FindFirstChild('_stats')
        local id=tostring(stat(stats,{'id','unit_id'}) or u.Name):sub(1,50)
        local lvl=stat(stats,{'upgrade','upgrade_level','upgrade_lvl','level'})
        local dmg=num(stats,DAMAGE)
        sample[#sample+1]=id..'(up='..tostring(lvl or '?')..
            ',dmg='..tostring(dmg or '?')..')'
    end
    return 'placed='..#units..' yen='..tostring(scanMoney() or '?')..
        ' towers='..table.concat(sample,', ')
end
local function enemyFolderProbe()
    local names={};local checked=0
    for _,item in ipairs(WS:GetChildren()) do
        checked=checked+1
        if checked>85 then break end
        if item:IsA('Folder') or item:IsA('Model') then
            if #names<22 then
                local count=0
                for _,child in ipairs(item:GetChildren()) do
                    if child:IsA('Model') then count=count+1 end
                end
                names[#names+1]=tostring(item.Name):sub(1,40)..'('..count..' models)'
            end
        end
    end
    return 'top-level workspace containers='..table.concat(names,', ')
end
local function enemySnapshot()
    local folder=WS:FindFirstChild('_ENEMIES')
    if not folder then return 'enemy folder not visible' end
    local seen={};local total=0
    for _,m in ipairs(folder:GetChildren()) do
        if m:IsA('Model') then
            total=total+1
            local id=tostring(m.Name):sub(1,65)
            if #seen<12 then
                local st=m:FindFirstChild('_stats')
                local hp=num(st,{'hp','health','current_health','max_health'})
                seen[#seen+1]=id..(hp and ('(hp='..math.floor(hp)..')') or '')
            end
        end
    end
    return 'enemy_count='..total..' first_enemies='..table.concat(seen,', ')
end
local function startReport()
    reporter.active=true;reporter.closed=false
    reporter.folder=WS:FindFirstChild('_UNITS')
    reporter.lastWave=-1;reporter.seenCards={};reporter.seenBosses={};reporter.seenThreats={};reporter.seenConfirms={}
    reporter.lastCardsAt=0;reporter.lastEnemiesAt=0
    reporter.pendingEndAt=0;reporter.finalEnemyLogged=false
    S.eventActionBuffer={};S.eventActionSeen={}
    reporter.session=reporter.session+1
    reporter.lines={}
    -- Inventory getgc(true) allocates a large object snapshot on mobile and
    -- provides no offered units in Fool's Hunt. Defer to manual UNIT scans.
    pcall(function() S.map=mapId();stageData() end)
    local equipped={}
    for _,unit in ipairs(S.inventory) do
        if #equipped>=8 then break end
        equipped[#equipped+1]=tostring(unit.slot)..':'..tostring(unit.id):sub(1,55)
    end
    recordLine('START','session='..reporter.session..' | mode='..S.mode..
        ' | map='..tostring(S.map)..' | stage='..
        tostring((S.stageData or {}).name or '?')..
        ' | equipped='..table.concat(equipped,', '),false)
    note('AUTO REPORT recording | no need to start full auto')
    if S.farmTarget~='Off' then
        recordLine('FARM OBJECTIVE','target='..S.farmTarget..
            ' | mode='..S.mode..
            ' | automatic dungeon rooms/chests/summoning: NOT VERIFIED',false)
    end
    if S.mode=='Event' then
        recordLine('EVENT AUTOPLAY STATUS',
            'Fool Hunt replaces equipped units. Standard equipped scan='..
            #S.inventory..' | event random-offer / spell adapter NOT validated.',false)
        recordLine('WORKSPACE PROBE',enemyFolderProbe(),false)
    end
end
local function finishReport(reason)
    if not reporter.active then return end
    recordLine('END',reason..' | wave='..wave()..' | '..unitSnapshot()..
        ' | '..enemySnapshot()..' | result='..resultText(),true)
    reporter.active=false
    reporter.closed=true
    if S.options.autoCopyReport then copyReport() end
    note('AUTO REPORT finished: '..(reporter.filesOK and REPORT_FILE or 'memory only')..
        ' | clipboard='..tostring(type(setclipboard)=='function'))
end
local function tickReporter()
    local inGame=isMatch()
    if not inGame then
        if reporter.active then finishReport('Match ended, lobby returned, or teleport') end
        reporter.closed=false
        return
    end
    local folder=WS:FindFirstChild('_UNITS')
    local w=wave()
    local finished=isFinished()
    if reporter.active and reporter.folder~=folder then
        finishReport('Match instance changed')
    end
    if reporter.active and w<=1 and reporter.lastWave>=5 and not finished then
        finishReport('Wave reset; previous run ended')
    end
    if reporter.closed then
        if finished or w>1 then return end
        reporter.closed=false
    end
    if not reporter.active then startReport() end
    if w~=reporter.lastWave then
        reporter.lastWave=w
        if w==1 or (w>0 and w%5==0) then
            recordLine('CHECKPOINT',unitSnapshot()..' | '..enemySnapshot(),w==30)
        end
    end
    local now=os.clock()
    if #S.eventActionBuffer>0 then
        local buffer=S.eventActionBuffer
        S.eventActionBuffer={}
        for _,signature in ipairs(buffer) do
            recordLine('EVENT ACTION SHAPE',signature,false)
        end
    end
    if now-reporter.lastEnemiesAt>=2.5 and not finished then
        reporter.lastEnemiesAt=now
        local ok=pcall(v5ScanStage)
        if ok then
            for _,name in ipairs(S.bossNames or {}) do
                if not reporter.seenBosses[name] then
                    reporter.seenBosses[name]=true
                    recordLine('BOSS','first seen: '..tostring(name):sub(1,100)..
                        ' | '..unitSnapshot(),true)
                end
            end
            for _,flag in ipairs(COUNTERS) do
                if (S.counterReport[flag] or 0)>0 and not reporter.seenThreats[flag] then
                    reporter.seenThreats[flag]=true
                    recordLine('ENEMY TRAIT','first seen: '..flag..
                        ' | count='..tostring(S.counterReport[flag]),false)
                end
            end
        end
    end
    if now-reporter.lastCardsAt>=3.0 and not finished then
        reporter.lastCardsAt=now
        local ok,cards=pcall(scanCards)
        if ok and type(cards)=='table' and #cards>=2 and #cards<=5 then
            local choiceLines={};local ids={}
            for _,card in ipairs(cards) do
                local rawLabel=tostring(card.text or ''):sub(1,340)
                local label=rawLabel:gsub('%s*|%s*[Cc]onfirm%s*',''):gsub('%s+$','')
                local score=scoreCard(label)
                choiceLines[#choiceLines+1]=label..' [estimated score='..score..']'
                ids[#ids+1]=label
                -- UI confirmation text suggests a selection, but is not server proof.
                if rawLabel:lower():find('| confirm',1,true) then
                    local confirmKey=tostring(w)..'|'..label
                    if not reporter.seenConfirms[confirmKey] then
                        reporter.seenConfirms[confirmKey]=true
                        recordLine('POSSIBLE CARD CHOICE','confirmation visible for: '..label,false)
                    end
                end
            end
            table.sort(ids)
            local key=tostring(w)..'|'..table.concat(ids,'<>')
            if not reporter.seenCards[key] then
                reporter.seenCards[key]=true
                recordLine('CARDS','choices='..#cards..
                    ' | '..table.concat(choiceLines,' || '),true)
            end
        end
    end
    if finished then
        if reporter.pendingEndAt==0 then
            reporter.pendingEndAt=now
            if not reporter.finalEnemyLogged then
                reporter.finalEnemyLogged=true
                recordLine('MATCH FINISH FLAG',
                    'game signaled finish at wave '..w..' | '..enemySnapshot(),true)
            end
        end
        local panel=LP:FindFirstChild('PlayerGui')
        panel=panel and panel:FindFirstChild('ResultsUI')
        local shown=panel and panel:IsA('ScreenGui') and panel.Enabled
        if (shown and now-reporter.pendingEndAt>=0.8) or
            now-reporter.pendingEndAt>=6 then
            finishReport(shown and 'Visible result panel detected'
                or 'GameFinished flag; result panel not visible')
        end
    else
        reporter.pendingEndAt=0
    end
end
-- ================== END HANDS-FREE RUN REPORTER ==================

-- Compact, scrollable mobile UI (no dependencies).
local parent=LP:WaitForChild('PlayerGui')
if type(gethui)=='function' then pcall(function() parent=gethui() end) end
gui=Instance.new('ScreenGui')
gui.Name='K_AA_V5_GUI';gui.ResetOnSpawn=false;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=parent
S.gui=gui
local function mk(class,props,p)
    local item=Instance.new(class)
    for k,v in pairs(props) do item[k]=v end
    item.Parent=p
    return item
end
local C={bg=Color3.fromRGB(17,22,32),button=Color3.fromRGB(43,53,69),
    active=Color3.fromRGB(30,122,98),muted=Color3.fromRGB(76,83,94),
    text=Color3.fromRGB(244,246,251),focus=Color3.fromRGB(122,202,241)}
local root=mk('Frame',{Size=UDim2.fromOffset(318,442),Position=UDim2.new(.5,-159,.5,-221),
    BackgroundColor3=C.bg,BorderSizePixel=0,Active=true},gui)
mk('UICorner',{CornerRadius=UDim.new(0,12)},root)
local header=mk('TextLabel',{Size=UDim2.new(1,-48,0,40),Text='[K] AA SMART COUNTERS v5',
    BackgroundTransparency=1,TextColor3=C.text,TextSize=14,Font=Enum.Font.GothamBold,Active=true},root)
local shrink=mk('TextButton',{Size=UDim2.fromOffset(34,32),Position=UDim2.new(1,-39,0,4),
    Text='_',BackgroundColor3=C.button,TextColor3=C.text,Font=Enum.Font.GothamBold,TextSize=20},root)
local info=mk('TextLabel',{Size=UDim2.new(1,-18,0,41),Position=UDim2.fromOffset(9,395),
    BackgroundTransparency=1,TextWrapped=true,TextColor3=C.focus,
    TextSize=11,Font=Enum.Font.Gotham,Text=S.status},root)
S.statusText=info
-- Visible near the top even when the main menu is minimized.
tipBanner=mk('Frame',{Size=UDim2.fromOffset(308,65),
    Position=UDim2.new(.5,-154,0,30),BackgroundColor3=Color3.fromRGB(23,91,74),
    BackgroundTransparency=.06,BorderSizePixel=0,Visible=false,
    ZIndex=25},gui)
mk('UICorner',{CornerRadius=UDim.new(0,10)},tipBanner)
tipTitle=mk('TextLabel',{Position=UDim2.fromOffset(9,6),
    Size=UDim2.new(1,-18,0,26),BackgroundTransparency=1,
    Font=Enum.Font.GothamBold,TextSize=14,TextWrapped=true,
    TextXAlignment=Enum.TextXAlignment.Left,TextColor3=Color3.fromRGB(255,255,255),
    ZIndex=26,Text='PICK: waiting for cards'},tipBanner)
tipDetail=mk('TextLabel',{Position=UDim2.fromOffset(9,33),
    Size=UDim2.new(1,-18,0,26),BackgroundTransparency=1,
    Font=Enum.Font.Gotham,TextSize=11,TextWrapped=true,
    TextXAlignment=Enum.TextXAlignment.Left,TextColor3=Color3.fromRGB(231,250,239),
    ZIndex=26,Text='Recommendations only'},tipBanner)
local scroll=mk('ScrollingFrame',{Position=UDim2.fromOffset(8,121),Size=UDim2.new(1,-16,0,266),
    BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,CanvasSize=UDim2.fromOffset(0,750)},root)
local flow=mk('UIListLayout',{Padding=UDim.new(0,6),FillDirection=Enum.FillDirection.Vertical,
    SortOrder=Enum.SortOrder.LayoutOrder},scroll)
flow:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
    scroll.CanvasSize=UDim2.fromOffset(0,flow.AbsoluteContentSize.Y+12)
end)
-- Compact two-row section tabs. Actions are assigned to exactly one section.
local sections={'PLAY','CARDS','FARM','REPORTS','UNITS','OTHER'}
local sectionDescriptions={
    PLAY='Select a mode. Full Auto is separate from card selection.',
    CARDS='Pick a strategy. Card advice works with Full Auto OFF.',
    FARM='Placement and upgrade options require Full Auto ON.',
    REPORTS='Run log and auto-copy work during normal manual play.',
    UNITS='Team scanner, inventory and learned equip settings.',
    OTHER='Event matchmaking and script controls.'
}
local sectionPrefixes={
    {'START FULL AUTO','PLAY'},{'CHECK FARM READINESS','PLAY'},
    {'MODE:','PLAY'},{'FARM TARGET:','PLAY'},{'COPY FARM GUIDE','PLAY'},
    {'AUTO CHOOSE BEST CARD','CARDS'},{'CARD STRATEGY','CARDS'},
    {'SET BIG REWARDS','CARDS'},{'CARD ADVISOR','CARDS'},
    {'COPY CARD CHOICES','CARDS'},
    {'AUTO PLACE','FARM'},{'SMART SPOTS','FARM'},
    {'REUSE GENERATED','FARM'},{'AUTO UPGRADE','FARM'},
    {'SMART UPGRADE','FARM'},{'AUTO ABILITIES','FARM'},
    {'AUTO START WAVES','FARM'},{'AUTO SKIP WAVES','FARM'},
    {'AUTO REPLAY','FARM'},{'PRIORITIZE MONEY','FARM'},
    {'CAUTIOUS WAVE','FARM'},{'PLACEMENTS PER UNIT','FARM'},
    {'MAX TOTAL PLACEMENTS','FARM'},{'CLEAR THIS MAP MACRO','FARM'},
    {'AUTO-LOG','REPORTS'},{'AUTO-COPY','REPORTS'},
    {'COPY COMPLETE AUTO REPORT','REPORTS'},
    {'SHOW AUTO REPORT STATUS','REPORTS'},
    {'COPY MAP / BOSSES','REPORTS'},
    {'COPY UNIT / PLACEMENT','REPORTS'},
    {'COPY DIAGNOSTICS','REPORTS'},
    {'SCOUT MAP','UNITS'},{'AUTO EQUIP','UNITS'},
    {'SCAN ALL OWNED','UNITS'},{'RECOMMEND BEST TEAM','UNITS'},
    {'LEARN EQUIP','UNITS'},{'STOP EQUIP','UNITS'},
    {'SCAN EQUIPPED','UNITS'},
    {'AUTO EVENT REJOIN','OTHER'},{'LEARN EVENT JOIN','OTHER'},
    {'FINISH LEARNING','OTHER'},{'STOP + CLOSE GUI','OTHER'}
}
local function sectionForLabel(label)
    local upper=string.upper(tostring(label or ''))
    for _,prefix in ipairs(sectionPrefixes) do
        if upper:sub(1,#prefix[1])==prefix[1] then return prefix[2] end
    end
    return 'OTHER'
end
local activeSection='CARDS'
local tabButtons={}
local menuItems={}
local sectionHelp=mk('TextLabel',{LayoutOrder=0,Size=UDim2.new(1,-4,0,45),
    BackgroundTransparency=1,Text=sectionDescriptions[activeSection],
    TextColor3=C.focus,TextSize=11,TextWrapped=true,
    Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left},scroll)
local function selectSection(chosen)
    activeSection=chosen
    sectionHelp.Text=sectionDescriptions[chosen] or ''
    for _,item in ipairs(menuItems) do
        item.button.Visible=item.section==chosen
    end
    for key,tab in pairs(tabButtons) do
        tab.BackgroundColor3=key==chosen and C.active or C.button
        tab.TextColor3=C.text
    end
    scroll.CanvasPosition=Vector2.new(0,0)
end
for index,section in ipairs(sections) do
    local col=(index-1)%3
    local line=math.floor((index-1)/3)
    local tab=mk('TextButton',{
        Size=UDim2.fromOffset(96,30),
        Position=UDim2.fromOffset(11+col*101,45+line*34),
        Text=section,
        BackgroundColor3=section==activeSection and C.active or C.button,
        BorderSizePixel=0,TextColor3=C.text,
        TextSize=11,Font=Enum.Font.GothamBold,
        AutoButtonColor=true},root)
    mk('UICorner',{CornerRadius=UDim.new(0,7)},tab)
    tab.MouseButton1Click:Connect(function()
        if S.alive then selectSection(section) end
    end)
    tabButtons[section]=tab
end
local order=0
local function button(txt,cb,groupOverride)
    order=order+1
    local section=groupOverride or sectionForLabel(txt)
    local b=mk('TextButton',{LayoutOrder=order,Size=UDim2.new(1,-4,0,41),
        Text=txt,Visible=section==activeSection,
        BackgroundColor3=C.button,BorderSizePixel=0,TextColor3=C.text,
        Font=Enum.Font.GothamSemibold,TextSize=12,
        TextWrapped=true,AutoButtonColor=true},scroll)
    mk('UICorner',{CornerRadius=UDim.new(0,7)},b)
    menuItems[#menuItems+1]={button=b,section=section}
    b.MouseButton1Click:Connect(function() if S.alive then cb(b) end end)
    return b
end
local main
button('CHECK FARM READINESS',function()
    if not isMatch() then
        note('Readiness: join your chosen match first. No auto matchmaking in this preset.')
        return
    end
    if #S.inventory==0 then
        note('NOT READY: roster IDs unavailable. Scan owned/equipped manually in UNITS.')
    elseif not WS:FindFirstChild('_ENEMIES') then
        note('NOT READY: enemy path folder missing. Avoid automatic placement.')
    elseif not getRemote('spawn_unit') then
        note('NOT READY: spawn_unit endpoint missing. Automatic placement unavailable.')
    elseif S.farmTarget=='Rukia' then
        note('Basic combat inputs found, but Dungeon room/chest logic is manual.')
    elseif S.farmTarget=='Griffin' then
        note('Griffin evolution farming: equip base Griffin and let it hit enemies '..
            'for takedowns; placement still needs supervised testing.')
    else
        note('Basic inputs found; no guarantee of working placement/upgrades.')
    end
end)
main=button('START FULL AUTO (OFF)',function(b)
    if not S.enabled and S.farmTarget~='Off' then
        if (S.farmTarget=='Rukia' and S.mode~='Dungeon') or
            (S.farmTarget=='Griffin' and S.mode~='Infinite') then
            note('Goal farm mode mismatch: choose correct mode in PLAY.')
            return
        end
        if not isMatch() then
            note('Enter the '..(S.farmTarget=='Rukia' and 'Dungeon' or 'Infinite')..
                ' match manually before testing combat automation.')
            return
        end
        if #S.inventory==0 then
            note('Goal farm not ready: no equipped-unit IDs found. '..
                'Go to UNITS and inspect equipped roster manually first.')
            return
        end
        if not WS:FindFirstChild('_ENEMIES') then
            note('Goal farm not ready: enemy path folder is missing. '..
                'Keep manual control; send report.')
            return
        end
        if not getRemote('spawn_unit') then
            note('Goal farm not ready: placement remote is unavailable.')
            return
        end
    end
    if not S.enabled and S.mode=='Event' and #S.inventory==0 then
        note('Event autoplay not ready: no equipped roster. Leave Full Auto OFF; use CARDS instead.')
        return
    end
    S.enabled=not S.enabled
    b.Text=S.enabled and 'STOP FULL AUTO (RUNNING)' or 'START FULL AUTO (OFF)'
    b.BackgroundColor3=S.enabled and C.active or C.button
    if S.enabled then
        if isMatch() then resetMatch() end
        note('AUTO ON: '..S.mode..' | placing, upgrading, replaying')
    else
        run.pending=nil
        note('AUTO STOPPED. Saved macros retained.')
    end
end)
local modeButton
local targetButton
modeButton=button('MODE: '..S.mode..' (tap to change)',function(b)
    local idx=table.find(modes,S.mode) or 1
    S.mode=modes[idx%#modes+1]
    b.Text='MODE: '..S.mode..' (tap to change)'
    if (S.farmTarget=='Rukia' and S.mode~='Dungeon') or
        (S.farmTarget=='Griffin' and S.mode~='Infinite') then
        S.farmTarget='Off'
        if targetButton then targetButton.Text='FARM TARGET: OFF (tap)' end
    end
    if isMatch() then S.map=mapId();run.key=currentKey();run.savedIndex=1 end
    saveSettings();note('Selected '..S.mode)
end)
targetButton=button('FARM TARGET: '..string.upper(S.farmTarget)..' (tap)',function(b)
    if S.enabled or isMatch() then
        note('Change the farm target only in the lobby, while Full Auto is OFF.')
        return
    end
    local choices={'Off','Rukia','Griffin'}
    local idx=table.find(choices,S.farmTarget) or 1
    S.farmTarget=choices[idx%#choices+1]
    if S.farmTarget=='Rukia' then
        S.mode='Dungeon'
        note('RUKIA: Dungeon rare chests. Keys, rooms, and chests are manual for now.')
    elseif S.farmTarget=='Griffin' then
        S.mode='Infinite'
        note('GRIFFIN OWNED: use Infinite to build 7,500 takedowns/assists. '..
            'Check Periapt Ascension manually; no unit sacrifices automated.')
    else
        note('Farm target disabled; existing modes are unchanged.')
    end
    modeButton.Text='MODE: '..S.mode..' (tap to change)'
    b.Text='FARM TARGET: '..string.upper(S.farmTarget)..' (tap)'
    saveSettings()
end)
button('COPY FARM GUIDE / CHECKLIST',function()
    local lines={'[K] ANIME ADVENTURES GOAL FARM',
        'Selected='..S.farmTarget..' Mode='..S.mode,
        'FULL AUTO='..tostring(S.enabled),
        'Combat autofarm requires observed unit IDs, enemy paths and valid placement endpoint.',
        'Automatic keys, chests, summoning, sacrifices and rerolls are DISABLED.'}
    if S.farmTarget=='Rukia' then
        lines[#lines+1]='1. Acquire/verify a Dungeon Key and enter Dungeon manually.'
        lines[#lines+1]='2. Clear the random Dungeon rooms (20 depths); prefer rare/golden chest outcomes.'
        lines[#lines+1]='3. Keep rare chests until the final boss; check in-game rules before opening.'
        lines[#lines+1]='4. Snow Reaper (War) is chance-based; no guaranteed number of runs.'
        lines[#lines+1]='5. Replay with a new key is never automated by this preset.'
    elseif S.farmTarget=='Griffin' then
        lines[#lines+1]='1. You already own Griffin. Equip the BASE Griffin before entering Infinite.'
        lines[#lines+1]='2. Choose an easy Infinite map so Griffin gets 7,500 takedowns (assists count).'
        lines[#lines+1]='3. Check the Griffin unit details in-game for remaining takedowns.'
        lines[#lines+1]='4. Reach 100% Ascension with the Periapt/Egg of the King (manual).'
        lines[#lines+1]='5. Ascend Griffin only after requirements are met (manual confirmation).'
        lines[#lines+1]='6. If Griffin is already evolved, select Rukia Dungeon instead.'
        lines[#lines+1]='No banner summon, auto-sacrifice, or auto-evolution is attempted.'
    else
        lines[#lines+1]='Choose FARM TARGET in PLAY to select Rukia or Griffin.'
    end
    local txt=table.concat(lines,'\n')
    if type(setclipboard)=='function' and pcall(function() setclipboard(txt) end) then
        note('Target farm guide copied; '..S.farmTarget)
    else
        print(txt);note('Target farm guide printed to executor console')
    end
end)
-- Fool's Hunt card controls appear immediately under MODE for easy mobile access.
local advisorBtn
local autoCardButton
autoCardButton=button('AUTO CHOOSE BEST CARD: '..(S.options.autoCards and 'ON' or 'OFF'),
    function(b)
        S.options.autoCards=not S.options.autoCards
        if S.options.autoCards then
            S.options.cardAdvisor=true
            if advisorBtn then
                advisorBtn.Text='CARD ADVISOR: ON'
                advisorBtn.BackgroundColor3=C.active
            end
        end
        b.Text='AUTO CHOOSE BEST CARD: '..(S.options.autoCards and 'ON' or 'OFF')
        b.BackgroundColor3=S.options.autoCards and C.active or C.muted
        saveSettings()
        note(S.options.autoCards and
            'AUTO CARD ON (experimental): card choices only; FULL AUTO remains separate'
            or 'AUTO CARD OFF: recommendations remain visible')
    end)
autoCardButton.BackgroundColor3=S.options.autoCards and C.active or C.muted
local function cardStrategyText()
    return S.goal=='Rewards' and 'BIG REWARDS (AprilCoins)'
        or (S.goal=='Safe' and 'SAFE CLEAR' or 'BALANCED')
end
local strategyButton
strategyButton=button('CARD STRATEGY: '..cardStrategyText()..' (tap)',function(b)
    local goals={'Safe','Balanced','Rewards'}
    local n=table.find(goals,S.goal) or 2
    S.goal=goals[n%#goals+1]
    b.Text='CARD STRATEGY: '..cardStrategyText()..' (tap)'
    saveSettings();note('Card strategy: '..cardStrategyText())
end)
button('SET BIG REWARDS (APRILCOINS)',function()
    S.goal='Rewards'
    strategyButton.Text='CARD STRATEGY: '..cardStrategyText()..' (tap)'
    saveSettings();note('BIG REWARDS selected: prioritize AprilCoins while rating curse risk')
end)
local function toggle(label,key)
    local b
    b=button('',function()
        S.options[key]=not S.options[key]
        if key=='cardAdvisor' and not S.options.cardAdvisor and S.options.autoCards then
            S.options.autoCards=false
            if autoCardButton then
                autoCardButton.Text='AUTO CHOOSE BEST CARD: OFF'
                autoCardButton.BackgroundColor3=C.muted
            end
        end
        b.Text=label..': '..(S.options[key] and 'ON' or 'OFF')
        b.BackgroundColor3=S.options[key] and C.active or C.muted
        saveSettings()
    end,sectionForLabel(label))
    b.Text=label..': '..(S.options[key] and 'ON' or 'OFF')
    b.BackgroundColor3=S.options[key] and C.active or C.muted
    return b
end
toggle('AUTO PLACE (no recording)','place')
toggle('SMART SPOTS / UNIT ROLES','smartPlace')
toggle('REUSE generated map macros','savedMacros')
toggle('AUTO UPGRADE','upgrade')
toggle('SMART UPGRADE PRIORITIES','smartUpgrade')
toggle('AUTO ABILITIES','abilities')
toggle('AUTO START WAVES','start')
toggle('AUTO SKIP WAVES','skip')
toggle('AUTO REPLAY','replay')
toggle('PRIORITIZE MONEY UNITS','farming')
advisorBtn=toggle('CARD ADVISOR','cardAdvisor')
toggle('AUTO-LOG RUN (no autofarm needed)','autoReport')
toggle('AUTO-COPY CARDS / BOSSES / END','autoCopyReport')
button('COPY COMPLETE AUTO REPORT',function()
    if copyReport() then note('Full run report copied; '..#reporter.lines..' entries')
    else note('Clipboard unavailable; see '..REPORT_FILE..' or executor console'); print(reportText()) end
end)
button('SHOW AUTO REPORT STATUS',function()
    note('Reporter '..(S.options.autoReport and 'ON' or 'OFF')..' | lines='..#reporter.lines..
        ' | local file='..tostring(reporter.filesOK)..' | '..REPORT_FILE)
end)
toggle('CAUTIOUS WAVE SKIP','cautiousSkip')
toggle('SCOUT MAP / ENEMY COUNTERS','stageScout')
toggle('AUTO EQUIP RECOMMENDED (learn first)','autoEquip')
button('SCAN ALL OWNED UNITS (bench included)',function()
    scanEquipped()
    local items,touched=scanOwned()
    recommendTeam()
    note('Owned scan: '..#items..' distinct units; '..touched..' records inspected')
end)
button('RECOMMEND BEST TEAM FOR THIS MAP',function()
    if isMatch() then S.map=mapId();stageData() end
    scanEquipped();scanOwned();local list=recommendTeam()
    note('Team plan generated for '..S.map..' ('..#list..' units). COPY COUNTER REPORT to inspect.')
end)
button('COPY MAP / BOSSES / TEAM COUNTERS',function()
    if isMatch() then v5ScanStage() end
    recommendTeam()
    local data=S.stageData or {}
    local flags,report=stageCounters()
    local learned=threatRecord()
    local knownBosses={}
    for boss in pairs(learned.bosses) do
        if #knownBosses>=12 then break end
        knownBosses[#knownBosses+1]=boss..' (wave '..tostring(learned.bossWaves[boss] or '?')..')'
    end
    local lines={'[K] AA V5 MAP REPORT | map='..S.map..' mode='..S.mode..' wave='..wave(),
        'stage='..tostring(data.name)..' world='..tostring(data.world),
        'known map modifiers='..table.concat(data.rawKeys or {},'; '),
        'enemy live='..tostring((S.counterReport or {}).count or 0),
        'live bosses='..table.concat(S.bossNames or {},', '),
        'previously observed bosses='..table.concat(knownBosses,', '),
        'next known boss wave='..tostring((S.counterReport or {}).nextKnownBossWave or 'unknown'),
        'counter evidence='..table.concat(report,', '),
        'owned='..#S.owned..' equipped='..#S.inventory,
        'autoEquip='..tostring(S.options.autoEquip)..' equipRemoteVerified='..tostring(S.equipTemplate and S.equipTemplate.verified),
        'BEST TEAM (heuristic; unknown stats excluded, not invented):'}
    for _,line in ipairs(S.teamReport) do lines[#lines+1]=line end
    lines[#lines+1]='Owned examples:'
    for i,u in ipairs(S.owned) do
        if i>20 then break end
        lines[#lines+1]=i..') '..u.id..' type='..tostring(u.attack or '?')..
            ' element='..tostring(u.element or '?')..' trait='..tostring(u.trait or '?')..
            ' damage='..tostring(u.damage or '?')..' spa='..tostring(u.spa or '?')
    end
    lines[#lines+1]='NOTE: unknown boss/element data is unknown; live scouting & previous scans only.'
    local txt=table.concat(lines,'\n')
    print(txt)
    if type(setclipboard)=='function' then pcall(function() setclipboard(txt) end);note('Map and team report copied')
    else note('Report printed in executor console') end
end)
button('LEARN EQUIP ACTION (manual once)',function()
    if not captureOK then note('Hook unavailable: '..tostring(captureErr));return end
    scanEquipped();scanOwned()
    S.equipLearning=true;S.equipLearningEnds=os.clock()+30
    note('In lobby, equip a unit normally within 30 sec. Mapping is saved only after verification.')
end)
button('STOP EQUIP LEARNING',function()
    S.equipLearning=false
    note('Equip learning stopped')
end)
button('COPY CARD CHOICES / DEBUG',function()
    local result={'AA SMART CARD SCAN | mode='..S.mode..' map='..S.map..' wave='..wave()..
        ' goal='..S.goal..' | '..S.cardStatus}
    for i,v in ipairs(S.cardSnapshot) do
        if i>8 then break end
        result[#result+1]=i..') SCORE='..v.score..' RISK='..v.risk..
            ' | '..v.text:sub(1,350)..' | '..v.reason
    end
    local txt=table.concat(result,'\n')
    if type(setclipboard)=='function' then pcall(function() setclipboard(txt) end)
        note('Copied card report: '..#S.cardSnapshot..' choices')
    else print(txt);note('Card report printed in console') end
end)
local queueBtn
queueBtn=button('AUTO EVENT REJOIN: OFF',function(b)
    S.autoQueue=not S.autoQueue
    b.Text='AUTO EVENT REJOIN: '..(S.autoQueue and 'ON' or 'OFF')
    b.BackgroundColor3=S.autoQueue and C.active or C.muted
    note('Event rejoin '..(S.autoQueue and 'armed' or 'disabled')..' ('..#S.eventQueue..' learned actions)')
end)
button('LEARN EVENT JOIN (one-time setup)',function()
    if not captureOK then note('Cannot learn queue: '..tostring(captureErr));return end
    S.eventQueue={}
    S.queueLearning=true
    S.queueLearningEnds=os.clock()+25
    saveSettings()
    note('NOW select/join your event normally within 25 seconds. Then tap FINISH.')
end)
button('FINISH LEARNING / SAVE EVENT JOIN',function()
    S.queueLearning=false
    saveSettings()
    note('Saved '..#S.eventQueue..' event queue actions. Toggle AUTO EVENT REJOIN.')
end)
button('PLACEMENTS PER UNIT: '..S.options.maxEach,function(b)
    S.options.maxEach=S.options.maxEach%5+1
    b.Text='PLACEMENTS PER UNIT: '..S.options.maxEach
    saveSettings()
end)
button('MAX TOTAL PLACEMENTS: '..S.options.maxTotal,function(b)
    S.options.maxTotal=({8,12,16,20,24})[(table.find({8,12,16,20,24},S.options.maxTotal) or 3)%5+1]
    b.Text='MAX TOTAL PLACEMENTS: '..S.options.maxTotal
    saveSettings()
end)
button('SCAN EQUIPPED UNITS NOW',function()
    local units=scanEquipped()
    note('Read '..#units..' equipped units; open COPY UNIT REPORT for details')
end)
button('COPY UNIT / PLACEMENT / UPGRADE REPORT',function()
    local lines={'AA v5 adaptive counter report (no full UUIDs)',
        'mode='..S.mode..' map='..S.map..' wave='..wave()..
        ' yen='..tostring(scanMoney() or 'unavailable')..
        ' path_samples='..#run.pathSamples..
        ' enemies='..tostring((S.threatReport or {}).count or 0)..
        ' air='..tostring((S.threatReport or {}).air or 0)}
    for _,inv in ipairs(S.inventory) do
        local live=bestLiveMatch(inv)
        local dps=(live and live.dps) or (inv.damage and inv.spa and inv.spa>0 and inv.damage/inv.spa)
        lines[#lines+1]='slot '..inv.slot..' '..inv.id..' role='..inv.role..
            ' trait='..tostring(inv.trait)..' type='..tostring(inv.attack)..
            ' dps='..tostring(dps or '?')..
            ' range='..tostring((live and live.range) or inv.range or '?')..
            ' deploy='..tostring(inv.cost or '?')..
            ' count='..countForSlot(inv.slot)..'/'..placementCap(inv)
    end
    local emitted=0
    for _,model in ipairs(ownUnits()) do
        if emitted>=3 then break end
        local stats=model:FindFirstChild('_stats')
        if stats then
            local keys={}
            for _,child in ipairs(stats:GetChildren()) do
                if #keys>=26 then break end
                if child:IsA('ValueBase') then keys[#keys+1]=child.Name end
            end
            table.sort(keys)
            lines[#lines+1]='VISIBLE STAT KEYS ('..model.Name..'): '..table.concat(keys,',')
            emitted=emitted+1
        end
    end
    lines[#lines+1]='PLACEMENT PRIORITY:'
    for _,line in ipairs(S.planReport or {}) do lines[#lines+1]=line end
    lines[#lines+1]='UPGRADE PRIORITY:'
    for _,line in ipairs(S.upgradeReport or {}) do lines[#lines+1]=line end
    lines[#lines+1]='NOTE: missing values=?; predicted positions must be verified by game.'
    local txt=table.concat(lines,'\n')
    print(txt)
    if type(setclipboard)=='function' then pcall(function() setclipboard(txt) end);note('Planner report copied')
    else note('Planner report in Delta console') end
end)
button('COPY DIAGNOSTICS',function()
    local remotes={}
    local folder=endpoints()
    if folder then
        for _,r in ipairs(folder:GetChildren()) do
            if r:IsA('RemoteFunction') or r:IsA('RemoteEvent') then
                table.insert(remotes,r.Name)
            end
        end
    end
    table.sort(remotes)
    local inv={}
    for _,v in ipairs(S.inventory) do table.insert(inv,v.slot..'='..v.id..'#'..v.uuid:sub(1,6)) end
    local txt='AA v5 | place='..game.PlaceId..' | map='..S.map..' | mode='..S.mode..
        ' | wave='..wave()..' | match='..tostring(isMatch())..
        ' | units='..#ownUnits()..' | equipped='..table.concat(inv,',')..
        ' | placements='..totalPlaced()..' | saved='..#profile().steps..
        ' | joinLearned='..#S.eventQueue..' | hook='..tostring(captureOK)..
        ' | remotes='..table.concat(remotes,',')
    print('[K] '..txt)
    if type(setclipboard)=='function' then pcall(function() setclipboard(txt) end);note('Diagnostics copied')
    else note('Diagnostics in Delta console (no clipboard)') end
end)
button('CLEAR THIS MAP MACRO',function()
    S.maps[currentKey()]={steps={}}
    run.savedIndex=1
    saveSettings();note('Cleared saved placements for '..currentKey())
end)
button('STOP + CLOSE GUI',function() S.stop() end)
local moving=false;local initial,at
header.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then
        moving=true;initial=input.Position;at=root.Position
        input.Changed:Connect(function()
            if input.UserInputState==Enum.UserInputState.End then moving=false end
        end)
    end
end)
UIS.InputChanged:Connect(function(input)
    if moving and (input.UserInputType==Enum.UserInputType.Touch or
        input.UserInputType==Enum.UserInputType.MouseMovement) then
        local d=input.Position-initial
        root.Position=UDim2.new(at.X.Scale,at.X.Offset+d.X,at.Y.Scale,at.Y.Offset+d.Y)
    end
end)
shrink.MouseButton1Click:Connect(function()
    local open=scroll.Visible
    scroll.Visible=not open
    info.Visible=not open
    for _,tab in pairs(tabButtons) do tab.Visible=not open end
    root.Size=open and UDim2.fromOffset(318,42) or UDim2.fromOffset(318,442)
    shrink.Text=open and '+' or '_'
end)
function S.stop()
    S.enabled=false;S.alive=false;S.queueLearning=false
    if reporter.active then pcall(function() finishReport('Script closed manually') end) end
    pcall(saveSettings)
    if S.gui then S.gui:Destroy() end
    if ENV.K_AA_V5==S then ENV.K_AA_V5=nil end
end

-- A conservative tick: at most one placement every 4.5 seconds, one upgrade/3s.
-- Lobby attempts happen only after learning an actual join request.
task.spawn(function()
    while S.alive do
        task.wait(0.45)
        if S.equipLearning and os.clock()>=S.equipLearningEnds then
            S.equipLearning=false;note('Equip learning expired (nothing verified).')
        end
        if S.queueLearning and os.clock()>=S.queueLearningEnds then
            S.queueLearning=false
            saveSettings()
            note('Event learning ended. Captured '..#S.eventQueue..' actions.')
        end
        if S.options.autoReport and os.clock()-reporter.lastTick>=0.7 then
            reporter.lastTick=os.clock()
            local ok,err=pcall(tickReporter)
            if not ok and os.clock()-(reporter.lastErrorAt or 0)>15 then
                reporter.lastErrorAt=os.clock()
                recordLine('RECORDER ERROR',tostring(err):sub(1,250),false)
            end
        elseif not S.options.autoReport and reporter.active then
            pcall(function() finishReport('Auto-report turned off') end)
        end
        -- Advice/auto-card picking works during manual play; FULL AUTO stays off.
        if S.options.cardAdvisor and os.clock()-(S.lastCardScan or 0)>2.5 then
            S.lastCardScan=os.clock()
            pcall(tickCards)
        elseif not S.options.cardAdvisor and tipBanner then
            tipBanner.Visible=false
        end
        if S.enabled then
            local now=os.clock()
            if isMatch() then
                local folder=WS:FindFirstChild('_UNITS')
                local w=wave()
                if run.unitsFolder~=folder or not run.active or
                    (w<=1 and run.waveMax>=3 and not isFinished()) then
                    resetMatch()
                end
                run.waveMax=math.max(run.waveMax,w)
                if not isFinished() then
                    observePath()
                    if now-run.unitScanAt>30 and #S.inventory==0 then
                        run.unitScanAt=now;scanEquipped()
                    end
                end
                if isFinished() then
                    if not run.hadResult then
                        run.hadResult=true;S.run=S.run+1
                        saveSettings();note('Completed run #'..S.run..' | '..S.map)
                    end
                    if S.options.replay and S.farmTarget~='Rukia'
                        and now-run.lastReplay>9 then
                        run.lastReplay=now
                        task.spawn(function() call('set_game_finished_vote','replay') end)
                    end
                else
                    if not isStarted() and S.options.start and now-run.lastStart>8 then
                        run.lastStart=now
                        task.spawn(function() call('vote_start') end)
                    end
                    if isStarted() then
                        if S.options.place then placeOne() end
                        if S.options.upgrade and now-run.lastUpgrade>3 then
                            run.lastUpgrade=now;upgradeOne()
                        end
                        if S.options.abilities and now-run.lastAbility>4 then
                            run.lastAbility=now;abilityOne()
                        end
                        if S.options.skip and (not S.options.cautiousSkip or (wave()<9 and #ownUnits()>=2)) and now-run.lastSkip>8 then
                            run.lastSkip=now
                            for _,name in ipairs({'vote_skip_wave','vote_skip','skip_wave'}) do
                                if getRemote(name) then
                                    task.spawn(function() call(name) end)
                                    break
                                end
                            end
                        end
                    end
                end
            else
                run.active=false
                if S.options.autoEquip and S.equipTemplate and S.equipTemplate.verified then
                    if now-(S.lastOwnedScan or 0)>50 then
                        S.lastOwnedScan=now;scanEquipped();scanOwned();recommendTeam()
                    end
                    tryEquipTeam()
                end
                if S.autoQueue and S.mode=='Event' and #S.eventQueue>0 and now-run.lastQueue>35
                    and (not S.options.autoEquip or not S.equipTemplate or (S.equipChanges or 0)>=6
                      or (S.lastEquipAt or 0)==0 or now-S.lastEquipAt>10) then
                    run.lastQueue=now
                    note('Trying learned event matchmaking commands...')
                    replayQueue()
                end
            end
        end
    end
end)
note('v5.1 mobile SAFE MODE loaded: no startup hook or automatic getgc scan. Reports: '..REPORT_FILE)