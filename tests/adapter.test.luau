local C=require('../src/core')
local factory=require('../src/roblox')
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
print('All '..n..' adapter tests passed')
