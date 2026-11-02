local C=require('../src/core')
local factory=require('../src/roblox')
local n=0
local function check(name,fn)
    local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));n+=1;print('PASS '..name)
end
local function node(name,class,kids)
    local x={Name=name,ClassName=class or 'Folder',kids=kids or {}}
    function x:FindFirstChild(k) for _,v in ipairs(self.kids) do if v.Name==k then return v end end end
    function x:GetChildren() return self.kids end
    function x:GetAttribute() return nil end
    function x:IsA(k) return self.ClassName==k or k=='ValueBase' and self.ClassName:find('Value')~=nil end
    function x:IsDescendantOf(parent)
        local at=self.Parent
        for _=1,16 do if at==parent then return true end;if not at then break end;at=at.Parent end
        return false
    end
    for _,v in ipairs(x.kids) do v.Parent=x end
    return x
end
local function signal()
    local s={listeners={}}
    function s:Connect(fn)
        local c={active=true,fn=fn}
        function c:Disconnect() self.active=false end
        self.listeners[#self.listeners+1]=c;return c
    end
    function s:fire(v) for _,c in ipairs(self.listeners) do if c.active then c.fn(v) end end end
    function s:count() local count=0;for _,c in ipairs(self.listeners) do if c.active then count+=1 end end;return count end
    return s
end
local function world(reply)
    local clock=0
    local part=node('surface','Part');local hillPart=node('hillSurface','Part')
    local ground=node('ground','Folder',{part});local hill=node('hill','Folder',{hillPart})
    local terrain=node('_terrain','Folder',{ground,hill})
    local ws=node('Workspace','Workspace',{terrain});local rs=node('ReplicatedStorage')
    local player={UserId=12,Name='test'}
    local g={PlaceId=9}
    function g:GetService(k) return ({Workspace=ws,ReplicatedStorage=rs,Players={LocalPlayer=player}})[k] end
    local w={ws=ws,rs=rs,terrain=terrain,ground=ground,hill=hill,part=part,hillPart=hillPart,
        rayCalls=0,rpcCalls=0,tasks={},event=signal(),uuid='01234567-abcd-1234-abcd-0123456789ab'}
    w.hit={Position={X=1,Y=0,Z=3},Normal={X=0,Y=1,Z=0},Instance=part}
    function ws:Raycast(origin,direction,params)
        w.rayCalls+=1;w.rayOrigin=origin;w.rayDirection=direction;w.rayParams=params;return w.hit
    end
    local remote=node('spawn_unit','RemoteFunction')
    function remote:InvokeServer(...)
        w.rpcCalls+=1;w.args={...}
        if reply then return reply(w,...) end
        return true
    end
    local message=node('show_message','RemoteEvent');message.OnClientEvent=w.event
    rs.kids={node('endpoints','Folder',{node('client_to_server','Folder',{remote}),
        node('server_to_client','Folder',{message})})}
    local apis={game=g,os={clock=function() return clock end},
        task={spawn=function(fn) local co=coroutine.create(fn);w.tasks[#w.tasks+1]=co;return co end},
        Vector3={new=function(x,y,z) return {X=x,Y=y,Z=z} end},
        CFrame={new=function(...) return {...} end},RaycastParams={new=function() return {} end},
        Enum={RaycastFilterType={Include='Include'}}}
    setfenv(factory,setmetatable(apis,{__index=getfenv()}))
    w.env={}
    function w:newAdapter()
        local a=factory(C,self.env,C.sanitize({}),C.logger());a.run=1;a.definitions={bulma={cost=800}}
        return a
    end
    w.a=w:newAdapter()
    w.a.definitions={bulma={cost=800},hill_unit={cost=1000,hill_unit=true},hybrid={cost=500,hybrid_placement=true}}
    function w:time(t) clock=t end
    function w:flush() assert(coroutine.resume(self.tasks[#self.tasks])) end
    function w:action(id) return {kind='place',uuid=self.uuid,id=id or 'bulma',pos={1,2,3}} end
    return w
end
check('placement sends the observed terrain height instead of the hitbox centre',function()
    local w=world();local action=w:action()
    assert(w.a:dispatch(action));w:flush()
    assert(w.rpcCalls==1 and w.args[1]==w.uuid and w.args[2][2]==0)
    assert(action.pos[2]==2 and w.rayCalls==1 and w.rayOrigin.X==1 and w.rayOrigin.Z==3)
    assert(w.rayParams.FilterType=='Include' and w.rayParams.FilterDescendantsInstances[1]==w.terrain)
end)
check('missing terrain blocks the request instead of reusing an unverified height',function()
    local w=world();w.ws.kids={}
    assert(not w.a:dispatch(w:action()) and w.rpcCalls==0 and #w.tasks==0)
end)
check('a non-placement first surface is not skipped to search underneath it',function()
    local w=world();local decor=node('decoration','Part');decor.Parent=w.terrain;w.hit.Instance=decor
    assert(not w.a:dispatch(w:action()) and w.rayCalls==1 and #w.tasks==0)
end)
check('donotplace surfaces block the request',function()
    local w=world();w.part.Name='_donotplace'
    assert(not w.a:dispatch(w:action()) and #w.tasks==0)
end)
check('observed ground and hill rules follow the loaded definition',function()
    local w=world();assert(not w.a:dispatch(w:action('hill_unit')))
    w.hit.Instance=w.hillPart
    assert(not w.a:dispatch(w:action('bulma')))
    assert(w.a:dispatch(w:action('hybrid')));w:flush();assert(w.rpcCalls==1)
end)
check('missing ray hits and invalid numeric results cannot dispatch',function()
    local w=world();w.hit=nil;assert(not w.a:dispatch(w:action()))
    w.hit={Instance=w.part,Position={X=1,Y=0/0,Z=3},Normal={Y=1}}
    assert(not w.a:dispatch(w:action()) and #w.tasks==0)
end)
check('nil replies retain the second message without claiming success',function()
    local w=world(function() return nil,'Cannot place unit here!' end)
    assert(w.a:dispatch(w:action()));w:flush()
    local report=w.a:actionReport()
    assert(report:find('nil',1,true) and report:find('Cannot place unit here!',1,true))
    assert(not report:find(w.uuid,1,true))
end)
check('table reply summaries use whitelisted scalar fields and redact UUIDs',function()
    local w=world(function(ctx) return {success=false,reason='Rejected '..ctx.uuid,private='do-not-copy'} end)
    assert(w.a:dispatch(w:action()));w:flush()
    local report=w.a:actionReport()
    assert(report:find('success=false',1,true) and report:find('Rejected',1,true))
    assert(not report:find(w.uuid,1,true) and not report:find('do-not-copy',1,true))
end)
check('server messages are observed only during a bounded action window',function()
    local w=world(function(ctx) ctx.event:fire('Cannot place unit here!');return nil end)
    assert(w.event:count()==0 and w.a:dispatch(w:action()) and w.event:count()==1)
    w:flush();assert(w.a:actionReport():find('Cannot place unit here!',1,true))
    w:time(9);w.event:fire('outside-window');w.a:poll()
    assert(w.event:count()==0 and not w.a:actionReport():find('outside-window',1,true))
end)
check('message output is bounded and closing disconnects the observer',function()
    local w=world();assert(w.a:dispatch(w:action()))
    for i=1,20 do w.event:fire('message-'..i..' '..w.uuid..string.rep('x',300)) end
    local report=w.a:actionReport();assert(#report<3000 and not report:find(w.uuid,1,true))
    w.a:close();assert(w.event:count()==0)
end)
check('replacing the scoped message observer does not duplicate listeners',function()
    local w=world();local sent,_,token=w.a:dispatch(w:action());assert(sent);w:flush()
    assert(w.a:confirmMutation(token))
    assert(w.a:dispatch(w:action()));assert(w.event:count()==1)
end)
check('late responses from a previous run do not reject a new run',function()
    local w=world(function() return false end);assert(w.a:dispatch(w:action()))
    w.a.run=2;w:flush();assert(not w.a:poll())
end)
check('truncated terrain ancestry cannot bypass a distant donotplace marker',function()
    local w=world();local at=node('_donotplace');at.Parent=w.ground
    for _=1,13 do local nested=node('nested');nested.Parent=at;at=nested end
    w.part.Parent=at
    assert(not w.a:dispatch(w:action()) and #w.tasks==0)
end)
check('upper decks and distant lower floors cannot relocate the saved target vertically',function()
    local w=world();w.hit.Position.Y=60
    assert(not w.a:dispatch(w:action()) and #w.tasks==0)
    w.hit.Position.Y=-100
    assert(not w.a:dispatch(w:action()) and #w.tasks==0)
end)
check('upgrade replies and messages redact an explicit noncanonical unit key',function()
    local w=world();local key='opaque-unit-key-X7z9Qv2c'
    local upgrade=node('upgrade_unit_ingame','RemoteFunction')
    function upgrade:InvokeServer() w.event:fire('Warning '..key);return nil,'Reason '..key end
    w.rs:FindFirstChild('endpoints'):FindFirstChild('client_to_server').kids={upgrade}
    local model=node('tower','Model');w.a.models[model]=model
    assert(w.a:dispatch({kind='upgrade',key=model,uuid=key}));w:flush()
    local report=w.a:actionReport()
    assert(report:find('Reason',1,true) and not report:find(key,1,true))
end)
check('a returned RPC without exact feedback stays fenced across close and reload',function()
    local w=world();assert(w.a:dispatch(w:action()));w:flush();w.a:close()
    local replacement=w:newAdapter()
    assert(not replacement:dispatch(w:action()) and w.rpcCalls==1)
end)
check('only the matching observed-feedback token releases the same-round fence',function()
    local w=world();local sent,_,token=w.a:dispatch(w:action());assert(sent);w:flush()
    assert(not w.a:confirmMutation({}));assert(w.a:confirmMutation(token))
    local replacement=w:newAdapter();local sent2,_,token2=replacement:dispatch(w:action());assert(sent2);w:flush()
    assert(not replacement:confirmMutation(token))
    assert(not replacement:dispatch(w:action()));assert(replacement:confirmMutation(token2))
end)
check('an observed native wave reset releases old uncertainty without trusting local run numbers',function()
    local w=world();local wave=node('_wave_num','IntValue');wave.Value=5
    local units=node('_UNITS');w.ws.kids[#w.ws.kids+1]=wave;w.ws.kids[#w.ws.kids+1]=units
    assert(w.a:dispatch(w:action()));w:flush();w.a:close();wave.Value=0
    local replacement=w:newAdapter();assert(replacement:dispatch(w:action()));w:flush();assert(w.rpcCalls==2)
end)
check('local run changes and newly arriving map metadata cannot release an unresolved native action',function()
    local w=world();local wave=node('_wave_num','IntValue');wave.Value=5
    w.ws.kids[#w.ws.kids+1]=wave;w.ws.kids[#w.ws.kids+1]=node('_UNITS')
    assert(w.a:dispatch(w:action()));w:flush()
    w.a.run=99;w.a.loaderExport={LevelData={id='new-wrapper'}}
    w.ws.kids[#w.ws.kids+1]=node('_map','Model')
    assert(not w.a:dispatch(w:action()) and w.rpcCalls==1)
end)
check('read-only stage requests remain available without clearing mutation uncertainty',function()
    local w=world();assert(w.a:dispatch(w:action()));w:flush()
    local remote=node('GetLevelData','RemoteFunction')
    function remote:InvokeServer() return {id='namek_level_1',_gamemode='story'} end
    w.ws.kids[#w.ws.kids+1]=node('_MAP_CONFIG','Folder',{remote})
    assert(w.a:issue('map',{}));w:flush()
    assert(w.a.stage=='namek_level_1' and w.a:mutationFenced())
    assert(not w.a:dispatch(w:action()) and w.rpcCalls==1)
end)
print('All '..n..' placement tests passed')
