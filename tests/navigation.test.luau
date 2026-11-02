local C=require('../src/core')
local loaded,factory=pcall(require,'../src/navigation')
assert(loaded,'Native observed-map planner is not implemented')
local n=0
local function check(name,fn) local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));n+=1;print('PASS '..name) end
local function node(name,class,kids)
    local a={Name=name,ClassName=class or 'Folder',kids=kids or {}}
    function a:FindFirstChild(key) for _,v in ipairs(self.kids) do if v.Name==key then return v end end end
    function a:GetChildren() return self.kids end
    function a:IsA(k) return k==self.ClassName or k=='BasePart' and self.ClassName=='Part' end
    for _,v in ipairs(a.kids) do v.Parent=a end
    return a
end
local function part(name,x,z) local p=node(name,'Part');p.Position={X=x,Y=0,Z=z};return p end
local function world()
    local surface=node('surface','Part');local ground=node('ground','Folder',{surface});local hillSurface=node('rock','Part');local hill=node('hill','Folder',{hillSurface})
    local terrain=node('_terrain','Folder',{ground,hill});local lane=node('1','Folder',{part('final',100,0),part('2',70,0),part('spawn',0,0),part('1',30,0)})
    local lanes=node('LANES','Folder',{lane});local bases=node('_BASES','Folder',{node('pve','Folder',{lanes})})
    local road=node('_road');local units=node('_UNITS');local ws=node('Workspace','Workspace',{bases,terrain,road,units});local rs=node('ReplicatedStorage')
    local w={ws=ws,rs=rs,lanes=lanes,lane=lane,surface=surface,hillSurface=hillSurface,terrain=terrain,road=road,units=units,rays=0,yields=0,overlaps=0,origins={}}
    w.hitPart=surface
    function ws:Raycast(o,d,p)
        w.rays+=1;w.origins[#w.origins+1]=o;w.rayParams=p
        if w.noHit then return nil end
        return {Position={X=o.X,Y=w.height or 0,Z=o.Z},Instance=w.hitPart,Normal={Y=1}}
    end
    function ws:GetPartBoundsInBox(cf,size,p)
        w.overlaps+=1;w.overlapParams=p;w.overlapSize=size;w.overlapCF=cf
        return w.blockers or {}
    end
    local api={Vector3={new=function(x,y,z) return {X=x,Y=y,Z=z} end},CFrame={new=function(x,y,z) return {X=x,Y=y,Z=z} end},
        RaycastParams={new=function() return {} end},OverlapParams={new=function() return {} end},Enum={RaycastFilterType={Include='Include'}},task={wait=function() w.yields+=1 end}}
    setfenv(factory,setmetatable(api,{__index=getfenv()}))
    w.planner=factory(C,ws,rs,C.logger())
    w.s={run='one',roundToken='round',stage='stage',stageVerified=true,inMatch=true,modeVerified=true,mode='Story',unitsComplete=true,rosterComplete=true,
        units={},roster={{uuid='a',id='attacker',slot=1,spawnCap=3,cost=100,range=20}}}
    w.definitions={attacker={range=20,override_hitbox_radius=2}}
    return w
end
check('reads native lanes and returns exact first surface positions',function()
    local w=world();local spots,why=w.planner:plan(w.s,w.definitions,{});assert(spots,why);assert(#spots.a==3)
    for _,v in ipairs(spots.a) do assert(v.pos[2]==0 and C.distance(v.pos,v.pos)==0) end
    assert(w.rayParams.FilterDescendantsInstances[1]==w.terrain and w.rayParams.FilterType=='Include')
    assert(w.overlapParams.MaxParts<=64 and w.overlapParams.FilterType=='Include')
end)
check('numeric path sorting and configured percent select longest native lane',function()
    local w=world();w.lanes.kids[2]=node('2','Folder',{part('spawn',0,100),part('10',100,100),part('2',20,100),part('final',200,100)})
    local spots,why=w.planner:plan(w.s,w.definitions,{autoDistance=25});assert(spots,why)
    -- Longest path has length200; the first candidate is centred on its observed25 percent point.
    assert(math.abs(w.origins[1].X-50)<0.001 and math.abs(w.origins[1].Z-100)<0.001)
end)
check('missing lanes never use fixed map coordinates or enemy samples',function()
    local w=world();w.ws.kids={w.terrain,w.road,w.units};w.s.path={{1,2,3}};local spots,why=w.planner:plan(w.s,w.definitions,{})
    assert(not spots and why:find('LANES') and w.rays==0)
end)
check('lane and node truncation stops before geometry queries',function()
    local w=world();for i=2,9 do w.lanes.kids[i]=node(tostring(i),'Folder',{}) end
    assert(not w.planner:plan(w.s,w.definitions,{}) and w.rays==0)
    w=world();for i=1,97 do w.lane.kids[i]=part(tostring(i),i,0) end
    assert(not w.planner:plan(w.s,w.definitions,{}) and w.rays==0)
end)
check('missing spawn final duplicate or invalid node coordinates stop safely',function()
    for _,which in ipairs({'spawn','final','duplicate','invalid'}) do
        local w=world()
        if which=='duplicate' then w.lane.kids[#w.lane.kids+1]=part('01',20,0)
        elseif which=='invalid' then w.lane.kids[1].Position.X=0/0
        else for i,v in ipairs(w.lane.kids) do if v.Name==which then table.remove(w.lane.kids,i);break end end end
        assert(not w.planner:plan(w.s,w.definitions,{}) and w.rays==0)
    end
end)
check('first unsupported surface never searches underneath or fabricates positions',function()
    local w=world();w.hitPart=node('decoration','Part');w.hitPart.Parent=w.terrain
    local spots,why=w.planner:plan(w.s,w.definitions,{});assert(not spots and why:find('surface'));assert(w.rays<=96 and w.overlaps==0 and w.yields>0)
end)
check('donotplace ancestry and loaded hill flags are enforced',function()
    local w=world();w.surface.Name='_donotplace';assert(not w.planner:plan(w.s,w.definitions,{}))
    w=world();w.definitions.attacker.hill_unit=true;assert(not w.planner:plan(w.s,w.definitions,{}));w.hitPart=w.hillSurface;assert(w.planner:plan(w.s,w.definitions,{}))
    w=world();w.hitPart=w.hillSurface;assert(not w.planner:plan(w.s,w.definitions,{}));w.definitions.attacker.hybrid_placement=true;assert(w.planner:plan(w.s,w.definitions,{}))
end)
check('actual unit road and loaded bounds overlaps reject candidates',function()
    local w=world();local blocker=node('_hitbox','Part');blocker.Parent=w.units;w.blockers={blocker}
    local spots,why=w.planner:plan(w.s,w.definitions,{});assert(not spots and why:find('overlap') and w.overlaps>0)
    w=world();w.blockers={part('road',50,0)};assert(not w.planner:plan(w.s,w.definitions,{}))
end)
check('replicated rotated bounds are inspected without cloning into the world',function()
    local w=world();local boundary=part('boundary',50,0);boundary.Size={X=1000,Y=1000,Z=1000}
    boundary.CFrame={PointToObjectSpace=function(_,v) return {X=v.X-50,Y=v.Y,Z=v.Z} end}
    function boundary:Clone() error('Cloning bounds is forbidden') end
    w.rs.kids={node('_bounds','Folder',{boundary})}
    local spots,why=w.planner:plan(w.s,w.definitions,{});assert(not spots and why:find('bounds overlap') and w.overlaps==0)
    boundary.Size={X=1,Y=1,Z=1};boundary.CFrame.PointToObjectSpace=function(_,v) return {X=v.X-10000,Y=v.Y,Z=v.Z} end
    assert(w.planner:plan(w.s,w.definitions,{}))
end)
check('cooperative yield observes close before performing another ray',function()
    local w=world();w.noHit=true
    local globals=getfenv(factory);globals.task.wait=function() w.yields+=1;w.planner:close() end
    local spots,why=w.planner:plan(w.s,w.definitions,{});assert(not spots and why:find('closed') and w.rays==12 and w.yields==1)
end)
check('native geometry API errors and invalid first heights return unsupported reasons',function()
    local w=world();function w.ws:GetPartBoundsInBox() error('query unavailable') end
    local spots,why=w.planner:plan(w.s,w.definitions,{});assert(not spots and why:find('unsupported'))
    w=world();w.height=0/0;spots,why=w.planner:plan(w.s,w.definitions,{});assert(not spots and why:find('invalid') and w.overlaps==0)
end)
check('planning range is source metadata and missing observation never gains a fallback',function()
    local w=world();w.s.roster[1].planningRange=30;w.definitions.attacker.range=nil;w.s.roster[1].range=nil
    assert(w.planner:plan(w.s,w.definitions,{}));w.s.roster[1].planningRange=nil
    local spots,why=w.planner:plan(w.s,w.definitions,{});assert(not spots and why:find('range unavailable'))
end)
check('incomplete snapshot unknown cap definition and unsupported flags stop',function()
    for _,key in ipairs({'unitsComplete','rosterComplete','stageVerified'}) do local w=world();w.s[key]=false;assert(not w.planner:plan(w.s,w.definitions,{})) end
    local w=world();w.s.roster[1].spawnCap=nil;assert(not w.planner:plan(w.s,w.definitions,{}));w=world();w.definitions={};assert(not w.planner:plan(w.s,w.definitions,{}))
    w=world();w.definitions.attacker.hill_unit='yes';assert(not w.planner:plan(w.s,w.definitions,{}))
end)
check('bounded per-slot rays total candidates and cooperative cancellation',function()
    local w=world();w.noHit=true
    for i=2,6 do local u=table.clone(w.s.roster[1]);u.uuid='slot'..i;u.slot=i;w.s.roster[i]=u end
    assert(not w.planner:plan(w.s,w.definitions,{}) and w.rays<=96*6 and w.yields>0)
    w=world();w.planner:close();local spots,why=w.planner:plan(w.s,w.definitions,{});assert(not spots and why:find('closed') and w.rays==0)
end)
check('six slots produce no more than twenty four separated candidates',function()
    local w=world();for i=1,6 do w.s.roster[i]={uuid='u'..i,id='attacker',slot=i,spawnCap=24,range=100} end
    w.definitions.attacker.range=100;local spots,why=w.planner:plan(w.s,w.definitions,{});assert(spots,why)
    local list={};for _,items in pairs(spots) do assert(#items>0);for _,v in ipairs(items) do list[#list+1]=v.pos end end
    assert(#list<=24);for i,p in ipairs(list) do for j=1,i-1 do assert(C.distance(p,list[j])>4) end end
end)
check('existing full caps require no new geometry and no fictitious success',function()
    local w=world();w.s.roster[1].trait='Unique';w.s.units={{key='old',uuid='a',id='attacker',pos={50,0,4}}}
    local spots,why=w.planner:plan(w.s,w.definitions,{});assert(spots,why);assert(#spots.a==0 and w.rays==0)
end)
check('fresh geometry checks respect standing towers on incremental replans',function()
    local w=world();local first=assert(w.planner:plan(w.s,w.definitions,{}));w.s.units={{key='old',uuid='a',id='attacker',pos=first.a[1].pos}}
    local second,why=w.planner:plan(w.s,w.definitions,{});assert(second,why);assert(#second.a==2)
    for _,v in ipairs(second.a) do assert(C.distance(v.pos,first.a[1].pos)>4) end
end)
check('nonattacking farms search the observed combat footprint rather than a tiny income-unit range',function()
    local w=world();w.s.roster[1].spawnCap=1;w.s.roster[1].role='combat';w.s.roster[1].planningRange=30
    w.s.roster[2]={uuid='farm',id='bulma',slot=2,spawnCap=1,role='farm',planningRange=4}
    w.definitions.bulma={range=4,farm_amount=100}
    function w.ws:GetPartBoundsInBox(cf) return math.abs(cf.Z)<5 and {w.road} or {} end
    local spots,why=w.planner:plan(w.s,w.definitions,{});assert(spots,why)
    assert(#spots.farm==1 and math.abs(spots.farm[1].pos[3])>=5)
    assert(w.s.roster[2].planningRange==4 and w.definitions.bulma.range==4)
end)
check('short-range support gets a reserved spot before attackers fill the centre',function()
    local w=world();w.s.roster[1].spawnCap=1;w.s.roster[1].role='combat';w.s.roster[1].planningRange=30
    w.s.roster[2]={uuid='support',id='idol',slot=2,spawnCap=1,role='buff',planningRange=10}
    w.definitions.idol={range=10,_show_as_buff_unit=true}
    local spots,why=w.planner:plan(w.s,w.definitions,{});assert(spots,why)
    assert(C.distance(spots.support[1].pos,{50,0,0})==0)
    assert(C.distance(spots.a[1].pos,spots.support[1].pos)>6)
end)
check('multiple legal copies distribute over observed lane anchors',function()
 local w=world();w.lanes.kids[2]=node('2','Folder',{part('spawn',0,100),part('final',200,100)})
 local spots,why=w.planner:plan(w.s,w.definitions,{});assert(spots,why)
 local nearFirst,nearSecond=false,false
 for _,e in ipairs(spots.a) do nearFirst=nearFirst or math.abs(e.pos[3])<30;nearSecond=nearSecond or math.abs(e.pos[3]-100)<30 end
 assert(nearFirst and nearSecond,'one lane was ignored')
end)
print('All '..n..' navigation tests passed')
