local C=require('../src/core')
local factory=require('../src/roblox')
local makeTrial=require('../src/trial')
local n=0
local function check(name,fn)
    local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));n+=1;print('PASS '..name)
end
local function node(name,class,attrs,kids)
    local x={Name=name,ClassName=class or 'Folder',attrs=attrs or {},kids=kids or {}}
    function x:GetAttribute(k) return self.attrs[k] end
    function x:GetAttributes() return self.attrs end
    function x:FindFirstChild(k) for _,v in ipairs(self.kids) do if v.Name==k then return v end end end
    function x:GetChildren() return self.kids end
    function x:IsDescendantOf(parent)
        local at=self.Parent
        for _=1,16 do if at==parent then return true end;if not at then break end;at=at.Parent end
        return false
    end
    function x:IsA(k) return self.ClassName==k or k=='ValueBase' and self.ClassName:find('Value')~=nil end
    for _,v in ipairs(x.kids) do v.Parent=x end
    return x
end
local function world(apis)
    local gui=node('PlayerGui','PlayerGui')
    local player=node('LocalPlayer','Player',{yen=300},{gui});player.UserId=12
    local ws=node('Workspace','Workspace')
    local rs=node('ReplicatedStorage')
    local gameMock={PlaceId=9}
    function gameMock:GetService(k)
        return ({Players={LocalPlayer=player},Workspace=ws,ReplicatedStorage=rs})[k]
    end
    player.Parent=gameMock;ws.Parent=gameMock;rs.Parent=gameMock
    local deferred={}
    local taskMock={spawn=function(fn) local co=coroutine.create(fn);deferred[#deferred+1]=co;return co end,
        wait=function() end}
    local globals={game=gameMock,task=taskMock}
    for k,v in pairs(apis or {}) do globals[k]=v end
    setfenv(factory,setmetatable(globals,{__index=getfenv()}))
    local cfg=C.sanitize({});local env={};local log=C.logger()
    local a=factory(C,env,cfg,log)
    return a,env,cfg,ws,rs,gui,player,deferred
end
check('partial inventory absence is never synthesized as zero',function()
    local a=world();local s=a:observe(10)
    assert(s.resources.SacredTreasure==nil and #s.owned==0 and s.rosterAt==nil)
end)
check('observer never invokes a made-up inventory fetch',function()
    local a,_,_,_,_,_,_,tasks=world();a:observe(10)
    assert(#tasks==0)
end)
check('shared or unrelated units cannot become owned',function()
    local a,_,_,ws=world()
    local st=node('_stats','Folder',{uuid='other',unit_id='rukia_2',player_id=99})
    ws.kids={node('_UNITS','Folder',{}, {node('tower','Model',{}, {st})}),node('_wave_num','IntValue')}
    local s=a:observe(10);assert(#s.units==0 and #s.owned==0)
end)
check('collection values retain scope and source',function()
    local a,_,_,_,_,_,player=world()
    local record=node('entry','Folder',{uuid='a',unit_id='rukia_2',equipped_slot=1,damage=10,spa=5,range=20,
        damage_grade='SSS',spa_grade='SSS',range_grade='SSS'})
    player.kids[#player.kids+1]=node('owned_units','Folder',{}, {record})
    local s=a:observe(10)
    assert(#s.roster==1 and s.owned[1].statScope=='collection' and C.statsMet(s.owned[1],'SSS'))
end)
check('late remote completion cannot update a closed observer',function()
    local a,env,_,_,rs,_,_,tasks=world()
    local remote=node('spawn_unit','RemoteFunction')
    function remote:InvokeServer() return false end
    rs.kids={node('endpoints','Folder',{}, {node('client_to_server','Folder',{}, {remote})})}
    assert(a:issue('place',{}));assert(env.K_AA_NETWORK_PENDING~=nil)
    a:close();assert(coroutine.resume(tasks[1]))
    assert(env.K_AA_NETWORK_PENDING==nil and #a.failures==0)
end)
check('single flight lock blocks duplicate dispatch',function()
    local a,_,_,_,rs=world()
    local remote=node('spawn_unit','RemoteFunction')
    rs.kids={node('endpoints','Folder',{}, {node('client_to_server','Folder',{}, {remote})})}
    assert(a:issue('place',{}));assert(not a:issue('place',{}))
end)
check('result containing both outcomes cannot count as victory',function()
    local a,_,_,_,_,gui=world()
    local w=node('w','TextLabel');w.Text='Victory';w.Visible=true
    local l=node('l','TextLabel');l.Text='Defeat';l.Visible=true
    local r=node('ResultsUI','ScreenGui',{}, {w,l});r.Enabled=true;r.Parent=gui;gui.kids={r}
    a.resultHidden=true;a.lastWave=30
    local shown,result=a:result();assert(shown and result=='unknown')
end)
check('first visible result template is unconfirmed',function()
    local a,_,_,_,_,gui=world()
    local w=node('w','TextLabel');w.Text='Victory';w.Visible=true
    local r=node('ResultsUI','ScreenGui',{}, {w});r.Enabled=true;r.Parent=gui;gui.kids={r}
    a.lastWave=30
    local shown,result=a:result();assert(shown and result=='unknown')
end)
check('incomplete result traversal cannot verify an outcome',function()
    local a,_,_,_,_,gui=world();local labels={}
    for i=1,50 do local l=node('label'..i,'TextLabel');l.Text=i==1 and 'Victory' or 'other';l.Visible=true;labels[i]=l end
    local r=node('ResultsUI','ScreenGui',{},labels);r.Enabled=true;r.Parent=gui;gui.kids={r}
    a.lastWave=30;a.resultHidden=true
    local shown,result=a:result();assert(shown and result=='unknown')
end)
check('cost slots preserve empty positions',function()
    local a=world()
    local s={inMatch=true,unitsComplete=true,stageVerified=true,stage='test',mode='Story',placeId=9,now=1,rosterAt=1,
        roster={{uuid='a',id='rukia_2',slot=3}},units={{uuid='a',id='rukia_2',pos={1,2,3}}}}
    local p=a:record(s,'100,,300');assert(p and p.entries[1].cost==300)
end)
check('early same-folder map reset invalidates previous stage identity',function()
    local a,_,_,ws=world();local w=node('_wave_num','IntValue');w.Value=1
    local f=node('_UNITS');local mapA=node('_MAP_CONFIG');ws.kids={w,f,mapA}
    a:observe(10);a.stage='old';a.mapRequested=true
    w.Value=0;ws.kids={w,f,node('_MAP_CONFIG')}
    local s=a:observe(11)
    assert(not s.stageVerified and s.stage=='unknown')
end)
check('more than 120 workspace units is flagged incomplete',function()
    local a,_,_,ws=world();local kids={}
    for i=1,121 do kids[i]=node('tower'..i,'Model') end
    ws.kids={node('_UNITS','Folder',{},kids),node('_wave_num','IntValue')}
    local s=a:observe(10);assert(s.unitsComplete==false)
end)
check('finished flag without readable result stops as unknown',function()
    local a,_,_,ws=world();local w=node('_wave_num','IntValue');w.Value=1
    ws.kids={node('_UNITS'),w,node('_DATA','Folder',{GameFinished=true})}
    local s=a:observe(10);assert(s.resultVisible==true and s.outcome=='unknown')
end)
check('lobby markers do not become a match just because units and wave exist',function()
    local a,_,_,ws,_,_,_,tasks=world();local w=node('_wave_num','IntValue');w.Value=0
    ws.kids={node('_UNITS'),w,node('_LOBBIES'),node('_EVOLVE'),node('_traits')}
    local s=a:observe(10)
    assert(not s.inMatch and s.context=='Lobby (observed markers)' and #tasks==0)
end)
check('manual diagnostic exposes module paths and types without stored values',function()
    local a,_,_,_,rs,_,player,tasks=world()
    rs.kids={node('src','Folder',{}, {node('Loader','ModuleScript')})}
    player.kids[#player.kids+1]=node('Profile','Folder',{uuid='private-value',encoded='private-json'},
        {node('12345678-abcd-1234-abcd-123456789012','Folder',{unit_id='rukia_2'})})
    local d=a:probePaths()
    assert(d.text:find('replicated/src/Loader',1,true))
    assert(d.text:find('uuid:string',1,true))
    assert(not d.text:find('private-value',1,true) and not d.text:find('private-json',1,true))
    assert(not d.text:find('12345678-abcd-1234-abcd-123456789012',1,true))
    assert(#tasks==0 and #a.owned==0)
end)
check('manual diagnostic stops at a fixed node and output budget',function()
    local a,_,_,_,rs=world();local folders={}
    for i=1,200 do
        local kids={}
        for j=1,30 do kids[j]=node('Data'..j,'Folder') end
        folders[i]=node('Data'..i,'Folder',{},kids)
    end
    rs.kids=folders
    local d=a:probePaths()
    assert(d.visited<=180 and #d.text<=30000 and d.truncated==true)
end)
check('diagnostic is manual and cached rather than added to the polling loop',function()
    local a=world();a:observe(10);a:observe(11)
    assert(a.pathDiagnostic==nil)
    local d=a:probePaths();assert(a.pathDiagnostic==d)
    a:observe(12);assert(a.pathDiagnostic==d)
end)
check('diagnostic does not expand unrelated replicated asset folders',function()
    local a,_,_,_,rs=world();local touched=false
    local assets=node('Assets','Folder')
    function assets:GetChildren() touched=true;return {} end
    rs.kids={assets};a:probePaths();assert(not touched)
end)
check('diagnostic redacts braced and prefixed UUID record names',function()
    local a,_,_,_,_,_,player=world()
    local uuid='12345678-abcd-1234-abcd-123456789012'
    player.kids[#player.kids+1]=node('Inventory','Folder',{}, {
        node('{'..uuid..'}','Folder'),node('unit_'..uuid,'Folder'),
        node('unit_12345678abcd1234abcd123456789012','Folder')})
    local d=a:probePaths()
    assert(not d.text:find(uuid,1,true))
    assert(not d.text:find('12345678abcd1234abcd123456789012',1,true))
end)
check('observed account currency fields are readable without inventing match Yen',function()
    local a,_,_,_,_,_,player=world();player.attrs={}
    local gold=node('gold_amount','NumberValue');gold.Value=100
    local gems=node('gem_amount','NumberValue');gems.Value=200
    local pearls=node('_resourceSummerPearls','NumberValue');pearls.Value=300
    local resource=node('resource','NumberValue');resource.Value=400
    player.kids[#player.kids+1]=node('_stats','Folder',{}, {gold,gems,pearls,resource})
    local s=a:observe(10)
    assert(s.wallet.Gold==100 and s.wallet.Gems==200 and s.wallet.SummerPearls==300)
    assert(s.walletSources.Gold=='player/_stats/gold_amount')
    assert(s.rawResource==400 and s.cash==nil)
end)
check('wrong field types and absent currencies remain unknown',function()
    local a,_,_,_,_,_,player=world()
    local gems=node('gem_amount','StringValue');gems.Value='500'
    player.kids[#player.kids+1]=node('_stats','Folder',{}, {gems})
    local s=a:observe(10)
    assert(s.wallet.Gems==nil and s.wallet.SummerPearls==nil)
end)
check('client services survive crowded GUI settings and static data folders',function()
    local a,_,_,_,rs,gui,player=world()
    local settings,data,prompts={},{},{}
    for i=1,100 do
        settings[i]=node('option'..i,'BoolValue');data[i]=node('Definition'..i,'ModuleScript')
        prompts[i]=node('ProximityPromptCustomUI','BillboardGui')
    end
    player.kids[#player.kids+1]=node('_settings','Folder',{},settings);gui.kids=prompts
    local client=node('client','Folder',{}, {node('Services','Folder',{}, {node('ClientService','ModuleScript')})})
    rs.kids={node('src','Folder',{}, {node('Data','Folder',{},data),client})}
    local d=a:probePaths()
    assert(d.text:find('replicated/src/client/Services/ClientService',1,true))
    assert(not d.text:find('ProximityPromptCustomUI',1,true))
    assert(not d.text:find('player/_settings/option',1,true))
    assert(d.visited<=180)
end)
check('client inventory and session module names precede unrelated entries',function()
    local a,_,_,_,rs=world();local entries={}
    for i=1,70 do entries[i]=node('Effect'..i,'Folder') end
    entries[#entries+1]=node('SessionService','ModuleScript')
    rs.kids={node('src','Folder',{}, {node('client','Folder',{},entries)})}
    local d=a:probePaths()
    assert(d.text:find('replicated/src/client/SessionService',1,true))
end)
check('observed GUI wrapper model is listed without reading GUI text',function()
    local a,_,_,_,_,gui=world()
    gui.kids={node('_R','Model',{}, {node('Collection','ScreenGui')})}
    local d=a:probePaths()
    assert(d.text:find('gui/_R/Collection',1,true))
end)
check('near-capacity diagnostic keeps the highest priority client descendants',function()
    local a,_,_,_,rs=world()
    local branch=node('SessionService','ModuleScript')
    for _,key in ipairs({'AProfile','ACollection','AService','client'}) do
        local kids={branch}
        for i=1,47 do kids[#kids+1]=node('ZEffect'..i,'ModuleScript') end
        branch=node(key,'Folder',{},kids)
    end
    rs.kids={node('src','Folder',{}, {branch})}
    local d=a:probePaths()
    assert(d.visited<=180 and d.truncated)
    assert(d.text:find('replicated/src/client/AService/ACollection/AProfile/SessionService',1,true))
end)
local function cacheFixture(notLoaded)
    local loader=node('Loader','ModuleScript')
    local service={session={profile_data={user_id=12},collection={collection_profile_data={
        owned_units={unitA={unit_id='rukia_2',traits={{trait='unique'}}}},equipped_units={[1]='unitA'}}}}}
    local calls={loaded=0,required=0,upvalues=0}
    local registry={StatsServiceClient={module=service}}
    local init=function() error('must never initialize') end
    local apis={getloadedmodules=function() calls.loaded+=1;return notLoaded and {} or {loader} end,
        require=function(target) assert(target==loader);calls.required+=1;return {init=init} end,
        debug={getupvalues=function(fn)
            assert(fn==init);calls.upvalues+=1
            return {[17]=registry}
        end}}
    local a,env,cfg,ws,rs,gui,player,tasks=world(apis)
    rs.kids={node('src','Folder',{}, {loader})}
    return a,env,service,calls,tasks,apis,registry
end
check('cache connection is never attempted during automatic observation',function()
    local a,_,_,calls=cacheFixture();a:observe(10);a:observe(11)
    assert(calls.loaded==0 and calls.required==0 and calls.upvalues==0)
end)
check('manual cache connection reads existing session and refreshes roster',function()
    local a,env,service,calls,tasks=cacheFixture()
    assert(a:startClientCache());assert(env.K_AA_CLIENT_CACHE_PENDING)
    assert(coroutine.resume(tasks[1]))
    local s=a:observe(10)
    assert(#s.roster==1 and s.roster[1].id=='rukia_2' and s.roster[1].trait=='Unique')
    assert(calls.loaded==1 and calls.required==1 and calls.upvalues==1)
    assert(env.K_AA_CLIENT_CACHE_PENDING==nil)
    service.session.collection.collection_profile_data.equipped_units={}
    s=a:observe(20);assert(#s.roster==0 and calls.loaded==1)
end)
check('not-loaded Loader is never required or initialized',function()
    local a,_,_,calls,tasks=cacheFixture(true)
    assert(a:startClientCache());assert(coroutine.resume(tasks[1]))
    assert(calls.required==0 and a.cacheDone and not a.clientService)
end)
check('late client-cache completion cannot update a closed adapter',function()
    local a,env,_,_,tasks=cacheFixture()
    assert(a:startClientCache());a:close();assert(coroutine.resume(tasks[1]))
    assert(a.clientService==nil and env.K_AA_CLIENT_CACHE_PENDING==nil)
end)
check('cache timeout locks a pending operation and rejects late results',function()
    local a,env,_,_,tasks=cacheFixture()
    assert(a:startClientCache());env.K_AA_CLIENT_CACHE_PENDING.at=os.clock()-9
    assert(a:poll());assert(env.K_AA_CLIENT_CACHE_PENDING and a.cacheDone)
    assert(coroutine.resume(tasks[1]));assert(not a.clientService)
end)
check('cache capability failure reports unavailable without spawning a worker',function()
    local a,env=world({getloadedmodules=false,debug={}})
    assert(not a:startClientCache() and env.K_AA_CLIENT_CACHE_PENDING==nil)
end)
check('another instance pending cache read blocks replacement requests',function()
    local a,env,_,calls=cacheFixture();env.K_AA_CLIENT_CACHE_PENDING={at=os.clock()}
    assert(not a:startClientCache() and calls.loaded==0)
end)
check('synchronous cache deadline expiry still completes with an unavailable result',function()
    local clock=0;local loader=node('Loader','ModuleScript')
    local a,env,_,_,rs,_,_,tasks=world({os={clock=function() return clock end},
        getloadedmodules=function() clock=9;return {loader} end,
        debug={getupvalues=function() return {} end}})
    rs.kids={node('src','Folder',{}, {loader})}
    assert(a:startClientCache());assert(coroutine.resume(tasks[1]))
    assert(a.cacheDone and not a.clientService and env.K_AA_CLIENT_CACHE_PENDING==nil)
end)
check('removed cache registry entry clears observed units on refresh',function()
    local a,_,_,calls,tasks,_,registry=cacheFixture()
    assert(a:startClientCache());assert(coroutine.resume(tasks[1]))
    assert(#a:observe(10).roster==1)
    registry.StatsServiceClient=nil
    local s=a:observe(20)
    assert(#s.roster==0 and #s.owned==0 and s.rosterAt==nil and calls.loaded==1)
end)
check('native resource becomes combat cash only inside an observed match',function()
    local a,_,_,ws,_,_,player=world();player.attrs={}
    local resource=node('resource','NumberValue');resource.Value=425
    player.kids[#player.kids+1]=node('_stats','Folder',{}, {resource})
    local w=node('_wave_num','IntValue');w.Value=1
    ws.kids={node('_UNITS'),w}
    local s=a:observe(10)
    assert(s.cash==425 and s.cashSource=='player/_stats/resource (match only)')
    ws.kids={node('_UNITS'),w,node('_LOBBIES'),node('_EVOLVE')};w.Value=0
    assert(a:observe(11).cash==nil)
end)
local function combatFixture(skipUnits)
    local loader=node('Loader','ModuleScript');local units=node('Units','ModuleScript')
    local level={id='namek_level_1',name='Act 1',_gamemode='story'}
    local service={session={collection={collection_profile_data={owned_units={unitA={unit_id='bulma'}},
        equipped_units={[1]='unitA'}}}}}
    local registry={ItemInventoryServiceClient={module=service}}
    local init=function() error('must never initialize') end
    local export={init=init,LevelData=level}
    local defs={bulma={cost=500,upgrade={{cost=1000},{cost=2000}}}}
    local calls={loader=0,units=0}
    local loaded=skipUnits and {loader} or {loader,units}
    local a,env,cfg,ws,rs,gui,player,tasks=world({getloadedmodules=function() return loaded end,
        require=function(target)
            if target==loader then calls.loader+=1;return export end
            assert(target==units);calls.units+=1;return defs
        end,debug={getupvalues=function(fn) assert(fn==init);return {registry} end}})
    rs.kids={node('src','Folder',{}, {loader,node('Data','Folder',{}, {units})})}
    local w=node('_wave_num','IntValue');w.Value=1
    local scale=node('player_cost_scale','NumberValue');scale.Value=1.5
    ws.kids={node('_UNITS'),w,node('_DATA','Folder',{}, {node('LevelModifiers','Folder',{}, {scale})})}
    return a,env,cfg,ws,player,tasks,export,defs,calls,scale,loaded,units
end
check('manual cache read also observes loaded level data without calling load_data',function()
    local a,_,_,_,_,tasks= combatFixture()
    assert(a:startClientCache());assert(coroutine.resume(tasks[1]))
    local s=a:observe(10)
    assert(s.stage=='namek_level_1' and s.stageSource=='Loader.LevelData observed')
    assert(s.mode=='Story' and s.modeVerified)
end)
check('static unit data supplies current scaled placement and upgrade costs',function()
    local a,_,_,ws,_,tasks,_,_,calls= combatFixture()
    assert(a:startClientCache());assert(coroutine.resume(tasks[1]))
    local tower=node('tower','Model',{}, {node('_stats','Folder',{player_id=12,uuid='unitA',id='bulma',upgrade=0})})
    ws.kids[1].kids={tower}
    local s=a:observe(10)
    assert(calls.units==1 and s.roster[1].cost==750 and s.roster[1].baseCost==500)
    assert(s.units[1].nextCost==1500 and s.costScale==1.5)
end)
check('missing or invalid cost scale never certifies a definition as effective cost',function()
    local a,_,_,_,_,tasks,_,_,_,scale= combatFixture()
    assert(a:startClientCache());assert(coroutine.resume(tasks[1]))
    scale.Value=0/0
    local s=a:observe(10)
    assert(s.roster[1].cost==nil and s.roster[1].baseCost==500)
end)
check('wave reset rejects stale loader level data until a fresh level arrives',function()
    local a,_,_,ws,_,tasks,export= combatFixture()
    assert(a:startClientCache());assert(coroutine.resume(tasks[1]))
    assert(a:observe(10).stageVerified)
    ws.kids[2].Value=0
    assert(not a:observe(11).stageVerified)
    export.LevelData={id='namek_level_1',_gamemode='story'}
    assert(a:observe(12).stageVerified)
end)
check('absent map endpoint does not permanently consume the map read attempt',function()
    local a,_,_,ws,_,_,_,tasks=world();local w=node('_wave_num','IntValue');w.Value=1
    local config=node('_MAP_CONFIG');ws.kids={node('_UNITS'),w,config}
    a:observe(10);assert(#tasks==0)
    local remote=node('GetLevelData','RemoteFunction')
    function remote:InvokeServer() return {id='stage',_gamemode='story'} end
    config.kids={remote};a:observe(15)
    assert(#tasks==1);assert(coroutine.resume(tasks[1]))
    local s=a:observe(16);assert(s.stage=='stage' and s.modeVerified and s.mode=='Story')
end)
check('combat report shows exact identity matching and actionable missing fields without UUIDs',function()
    local a,_,_,_,_,tasks= combatFixture()
    assert(a:startClientCache());assert(coroutine.resume(tasks[1]))
    local s=a:observe(10)
    s.units={{uuid='unitA',id='bulma',level=1,pos={1,2,3},nextCost=3000},
        {uuid='private-uuid',id='bulma',level=0}}
    local text=a:combatReport(s)
    assert(text:find('exact equipped match=true',1,true) and text:find('exact equipped match=false',1,true))
    assert(text:find('next cost=3000',1,true) and text:find('position=false',1,true))
    assert(not text:find('unitA',1,true) and not text:find('private-uuid',1,true))
end)
check('paid dungeon flags override generic story mode in observed level data',function()
    local a,_,_,_,_,tasks,export= combatFixture();export.LevelData._dungeon=true
    assert(a:startClientCache());assert(coroutine.resume(tasks[1]))
    assert(a:observe(10).mode=='Dungeon')
end)
check('missing endpoint probes do not consume the three actual map requests',function()
    local a,_,_,ws,_,_,_,tasks=world();local w=node('_wave_num','IntValue');w.Value=1
    local config=node('_MAP_CONFIG');ws.kids={node('_UNITS'),w,config}
    a:observe(10);a:observe(15);a:observe(20)
    local remote=node('GetLevelData','RemoteFunction')
    function remote:InvokeServer() return {id='late-stage'} end
    config.kids={remote};a:observe(25)
    assert(#tasks==1);assert(coroutine.resume(tasks[1]));assert(a:observe(26).stage=='late-stage')
end)
check('completed invalid map replies retry at most three times',function()
    local a,_,_,ws,_,_,_,tasks=world();local w=node('_wave_num','IntValue');w.Value=1
    local remote=node('GetLevelData','RemoteFunction')
    function remote:InvokeServer() return {} end
    ws.kids={node('_UNITS'),w,node('_MAP_CONFIG','Folder',{}, {remote})}
    for i=1,3 do a:observe(10+i*4);assert(tasks[i]);assert(coroutine.resume(tasks[i])) end
    a:observe(26);assert(#tasks==3 and not a.stage)
end)
check('disappearing modifier clears effective prices without editing the cache',function()
    local a,_,_,_,_,tasks,_,defs,_,scale= combatFixture()
    assert(a:startClientCache());assert(coroutine.resume(tasks[1]))
    assert(a:observe(10).roster[1].cost==750)
    scale.Value=nil
    assert(a:observe(11).roster[1].cost==nil and defs.bulma.cost==500)
end)
check('a manual match read can obtain Units that loaded after the inventory connection',function()
    local a,_,_,_,_,tasks,_,_,calls,_,loaded,units= combatFixture(true)
    assert(a:startClientCache());assert(coroutine.resume(tasks[1]))
    assert(not a:observe(10).definitionsAvailable)
    loaded[#loaded+1]=units
    assert(a:startClientCache());assert(tasks[2]);assert(coroutine.resume(tasks[2]))
    assert(a:observe(11).roster[1].cost==750 and calls.loader==1 and calls.units==1)
end)
check('temporary nil level data does not erase the previous-run stale marker',function()
    local a,_,_,ws,_,tasks,export= combatFixture()
    assert(a:startClientCache());assert(coroutine.resume(tasks[1]))
    assert(a:observe(10).stageVerified)
    local old=export.LevelData;export.LevelData=nil;a:observe(11)
    ws.kids[2].Value=0;a:observe(12)
    export.LevelData=old
    assert(not a:observe(13).stageVerified)
end)
check('late map response is rejected even when the polling timer has not run',function()
    local clock=0
    local a,env,_,ws,_,_,_,tasks=world({os={clock=function() return clock end}})
    local w=node('_wave_num','IntValue');w.Value=1
    local remote=node('GetLevelData','RemoteFunction')
    function remote:InvokeServer() clock=10;return {id='expired-stage',_gamemode='story'} end
    ws.kids={node('_UNITS'),w,node('_MAP_CONFIG','Folder',{}, {remote})}
    a:observe(0);assert(coroutine.resume(tasks[1]))
    assert(not a.stage and env.K_AA_NETWORK_PENDING==nil)
end)
local function trialWorld()
    local a,env,cfg,ws,rs,_,player,tasks=world({CFrame={new=function(x,y,z) return {x,y,z} end},
        Vector3={new=function(x,y,z) return {X=x,Y=y,Z=z} end},RaycastParams={new=function() return {} end},
        Enum={RaycastFilterType={Include='Include'}}})
    player.attrs={}
    local money=node('resource','NumberValue');money.Value=2000
    player.kids[#player.kids+1]=node('_stats','Folder',{}, {money})
    player.kids[#player.kids+1]=node('owned_units','Folder',{}, {node('entry','Folder',
        {uuid='a',unit_id='bulma',equipped_slot=4,placement_cost=800})})
    local function tower()
        local part=node('_hitbox','BasePart');part.Position={X=1,Y=2,Z=3}
        return node('tower','Model',{}, {part,node('_stats','Folder',
            {uuid='a',id='bulma',player_id=12,upgrade=0,next_upgrade_cost=1500})})
    end
    local old=tower();local folder=node('_UNITS','Folder',{}, {old})
    local part=node('surface','BasePart')
    local terrain=node('_terrain','Folder',{}, {node('ground','Folder',{}, {part})})
    local wave=node('_wave_num','IntValue');wave.Value=1;ws.kids={folder,wave,terrain}
    function ws:Raycast() return {Position={X=1,Y=0,Z=3},Normal={Y=1},Instance=part} end
    a.definitions={bulma={cost=800}}
    a:observe(10);a.stage='namek_level_1';a.mode='Story'
    local s=a:observe(11);local p=a:record(s,'');assert(p)
    local t=makeTrial(C,cfg,C.logger())
    return a,env,rs,t,s,p,old,money,folder,tower,tasks
end
check('one upgrade trial dispatches the observed model once and confirms adapter readback',function()
    local a,env,rs,t,s,p,old,money,_,_,tasks=trialWorld();local calls=0
    local remote=node('upgrade_unit_ingame','RemoteFunction')
    function remote:InvokeServer(model)
        assert(model==old);calls+=1;model:FindFirstChild('_stats').attrs.upgrade=1;money.Value=500;return true
    end
    rs.kids={node('endpoints','Folder',{}, {node('client_to_server','Folder',{}, {remote})})}
    local q=t:quote('upgrade',s,p);assert(q and calls==0)
    local action=t:begin('upgrade',s,p,q);assert(a:dispatch(action) and env.K_AA_NETWORK_PENDING)
    assert(coroutine.resume(tasks[1]));t:tick(a:observe(12));t:tick(a:observe(13))
    assert(t.upgrades==1 and calls==1 and not t.pending and env.K_AA_NETWORK_PENDING==nil)
end)
check('one placement trial dispatches exact UUID and observed surface coordinates once',function()
    local a,env,rs,t,_,p,_,money,folder,tower,tasks=trialWorld();local calls=0
    folder.kids={};local s=a:observe(12)
    local remote=node('spawn_unit','RemoteFunction')
    function remote:InvokeServer(uuid,position)
        assert(uuid=='a' and position[1]==1 and position[2]==0 and position[3]==3)
        calls+=1;folder.kids={tower()};money.Value=1200;return true
    end
    rs.kids={node('endpoints','Folder',{}, {node('client_to_server','Folder',{}, {remote})})}
    local q=t:quote('place',s,p);assert(q and calls==0)
    assert(a:dispatch(t:begin('place',s,p,q)));assert(coroutine.resume(tasks[1]))
    t:tick(a:observe(13));t:tick(a:observe(14))
    assert(t.placements==1 and calls==1 and not t.pending and env.K_AA_NETWORK_PENDING==nil)
end)
check('one test target can be recorded while unrelated defenders remain placed',function()
    local a,_,_,_,s=trialWorld()
    s.units[#s.units+1]={uuid='defender',id='nagumo_evolved',key='defender',pos={20,2,20}}
    local p=a:recordTestTarget(s,4)
    assert(p and #p.entries==1 and p.entries[1].id=='bulma' and p.testSlot==4)
end)
check('multiple copies in a selected test slot cannot choose an arbitrary target',function()
    local a,_,_,_,s=trialWorld()
    local copy=table.clone(s.units[1]);copy.key='another';copy.pos={20,2,20};s.units[#s.units+1]=copy
    assert(not a:recordTestTarget(s,4))
end)
check('team capture merges compatible partial slots and replaces a captured group',function()
    local a,_,_,_,s=trialWorld();local first=a:recordTeam(s,nil)
    assert(first and first.kind=='team-v1' and #first.entries==1)
    s.roster[2]={uuid='defender',id='nagumo_evolved',slot=1,cost=1300}
    s.units={{uuid='defender',id='nagumo_evolved',key='defender',pos={20,2,20},role='combat'}}
    local merged=a:recordTeam(s,first);assert(merged and #merged.entries==2)
    s.units[1].pos={25,2,20};local replaced=a:recordTeam(s,merged)
    assert(replaced and #replaced.entries==2)
    for _,e in ipairs(replaced.entries) do assert(e.key==nil);if e.id=='nagumo_evolved' then assert(e.pos[1]==25) end end
end)
check('team capture ignores helper IDs and removes no-longer-equipped copies',function()
    local a,_,_,_,s=trialWorld();local first=a:recordTeam(s,nil);assert(first)
    s.roster={{uuid='d',id='defender',slot=1,cost=500}}
    s.units={{uuid='d',id='helper',key='helper',pos={1,2,3}},
        {uuid='d',id='defender',key='real',pos={20,2,20},damage=100,spa=2}}
    local p=a:recordTeam(s,first)
    assert(p and #p.entries==1 and p.entries[1].id=='defender' and p.ignoredOwn==1)
end)
check('team capture cannot merge across incompatible cost modifiers',function()
    local a,_,_,_,s=trialWorld();s.costScale=1;local first=a:recordTeam(s,nil);assert(first)
    s.costScale=2;assert(not a:recordTeam(s,first))
end)
check('role and maximum-upgrade metadata use explicit current data',function()
    local a,_,_,ws,_,tasks,_,defs= combatFixture()
    defs.bulma.farm_amount=200
    assert(a:startClientCache());assert(coroutine.resume(tasks[1]))
    ws.kids[1].kids={node('tower','Model',{}, {node('_stats','Folder',
        {player_id=12,uuid='unitA',id='bulma',upgrade=0})})}
    local s=a:observe(10)
    assert(s.roster[1].role=='farm' and s.units[1].role=='farm' and s.units[1].maxLevel==2)
    defs.bulma.upgrade[2]=nil;defs.bulma.upgrade[3]={cost=3000}
    assert(a:observe(11).units[1].maxLevel==nil)
end)
local function resultFixture()
    local clock=10
    local a,_,_,ws,rs=world({os={clock=function() return clock end}})
    local wave=node('_wave_num','IntValue');wave.Value=1
    local data=node('_DATA','Folder',{GameFinished=false})
    ws.kids={node('_UNITS'),wave,data};a:observe(10);a.stage='namek_level_1';a.mode='Story';a:observe(10)
    local sig={connections={}}
    function sig:Connect(fn)
        local c={active=true,fn=fn};function c:Disconnect() self.active=false end
        self.connections[#self.connections+1]=c;return c
    end
    function sig:fire(value) for _,c in ipairs(self.connections) do if c.active then c.fn(value) end end end
    function sig:count() local count=0;for _,c in ipairs(self.connections) do if c.active then count+=1 end end;return count end
    local event=node('game_finished','RemoteEvent');event.OnClientEvent=sig
    rs.kids={node('endpoints','Folder',{}, {node('server_to_client','Folder',{}, {event})})}
    local function setClock(value) clock=value end
    return a,ws,data,wave,sig,setClock
end
check('result event observation is explicit and uses only one connection',function()
    local a,_,_,_,sig=resultFixture();assert(sig:count()==0)
    assert(a:watchResults() and a:watchResults() and sig:count()==1)
    a:stopResultWatch();assert(sig:count()==0);sig:fire({victory=true});assert(a.resultEvent==nil)
end)
check('server victory requires the current finished marker before confirming an outcome',function()
    local a,_,data,_,sig,clock=resultFixture();assert(a:watchResults())
    sig:fire({victory=true});local s=a:observe(11);assert(s.outcome=='unknown' and not s.resultVisible)
    clock(12);data.attrs.GameFinished=true;s=a:observe(12)
    assert(s.resultVisible and s.outcome=='Victory' and s.outcomeSource=='game_finished.victory + GameFinished')
end)
check('unsupported or conflicting result payloads cannot become a victory',function()
    local a,_,data,_,sig=resultFixture();assert(a:watchResults());data.attrs.GameFinished=true
    sig:fire({victory='true'});assert(a:observe(11).outcome=='unknown')
    sig:fire({victory=true});sig:fire({victory=false});assert(a:observe(11).outcome=='unknown')
end)
check('result event data expires and is cleared on a round reset',function()
    local a,_,data,wave,sig,clock=resultFixture();assert(a:watchResults());sig:fire({victory=true})
    clock(30);data.attrs.GameFinished=true;assert(a:observe(30).outcome=='unknown')
    data.attrs.GameFinished=false;wave.Value=0;a:observe(31)
    assert(a.resultEvent==nil)
end)
check('close disconnects the optional result observer',function()
    local a,_,_,_,sig=resultFixture();assert(a:watchResults());a:close();assert(sig:count()==0)
end)
check('a non-table false event is not a confirmed defeat',function()
    local a,_,data,_,sig=resultFixture();assert(a:watchResults());data.attrs.GameFinished=true
    sig:fire(false);assert(a:observe(11).outcome=='unknown')
end)
check('invalid native maximum falls back to recognized definition data',function()
    local a,_,_,ws,_,tasks= combatFixture();assert(a:startClientCache());assert(coroutine.resume(tasks[1]))
    ws.kids[1].kids={node('tower','Model',{}, {node('_stats','Folder',
        {player_id=12,uuid='unitA',id='bulma',upgrade=0,max_upgrade=-1})})}
    assert(a:observe(10).units[1].maxLevel==2)
end)
check('native snapshots retain incomplete declared equipment instead of certifying parsed survivors',function()
    local a,_,_,_,_,tasks=combatFixture()
    assert(a:startClientCache());assert(coroutine.resume(tasks[1]))
    local s=a:observe(10);assert(s.rosterComplete and s.equippedDeclared==1)
    a.clientService.session.collection.collection_profile_data.equipped_units[2]='not-in-owned-cache'
    s=a:observe(15)
    assert(#s.roster==1 and s.equippedDeclared==2 and not s.rosterComplete)
end)
print('All '..n..' adapter tests passed')
