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
local function world()
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
    setfenv(factory,setmetatable({game=gameMock,task=taskMock},{__index=getfenv()}))
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
print('All '..n..' adapter tests passed')
