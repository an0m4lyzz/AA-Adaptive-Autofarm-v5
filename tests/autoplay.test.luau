local C=require('../src/core')
local loaded,makeAuto=pcall(require,'../src/autoplay')
assert(loaded,'Native automatic combat module is not implemented')
local n=0
local function check(name,fn) local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));n+=1;print('PASS '..name) end
local function unit(uuid,id,cost,role,cap)
    return {slot=1,uuid=uuid,id=id,cost=cost,role=role or 'combat',spawnCap=cap or 1,range=20}
end
local function snapshot()
    return {now=1,run='r1',roundToken='native1',stage='stage1',placeId=9,mode='Story',inMatch=true,
        stageVerified=true,modeVerified=true,started=true,wave=1,cash=10000,rosterComplete=true,
        rosterAt=1,unitsComplete=true,units={},owned={},roster={unit('a','attacker',100)},
        autoSpots={a={{pos={10,0,10}},{pos={20,0,10}},{pos={30,0,10}}}}}
end
local function engine(cfg) return makeAuto(C,C.sanitize(cfg or {}),C.logger()) end
local function tower(key,uuid,id,pos,level,cost)
    return {key=key,uuid=uuid,id=id,pos=pos,level=level or 0,nextCost=cost,maxLevel=3}
end
check('arms observed supported manual-entry modes without accepting Events or unverified modes',function()
    for _,mode in ipairs({'Story','Dungeon','Infinite','Challenge','Raid','Legend','Portal'}) do local s=snapshot();s.mode=mode;assert(engine():arm(s)) end
    for _,mode in ipairs({'Event','Story'}) do local s=snapshot();s.mode=mode;s.modeVerified=mode~='Story';assert(not engine():arm(s)) end
end)
check('requires fresh complete unique equipped identities and observed towers',function()
    for _,key in ipairs({'rosterComplete','unitsComplete','stageVerified'}) do
        local s=snapshot();s[key]=false;assert(not engine():arm(s))
    end
    local s=snapshot();s.now=20;assert(not engine():arm(s));s=snapshot();s.roster[2]=table.clone(s.roster[1]);assert(not engine():arm(s))
end)
check('missing native round identity and malformed roster rows block without crashing',function()
    for _,key in ipairs({'run','roundToken'}) do local s=snapshot();s[key]=nil;assert(not engine():arm(s)) end
    local s=snapshot();s.roster[1].uuid=nil;local ok,result=pcall(function() return engine():arm(s) end);assert(ok and result==false)
    s=snapshot();s.roster[1]='unsupported';ok,result=pcall(function() return engine():arm(s) end);assert(ok and result==false)
end)
check('requires known positive integral caps and deployment prices',function()
    for _,cap in ipairs({0,-1,1.5}) do local s=snapshot();s.roster[1].spawnCap=cap;assert(not engine():arm(s)) end
    local s=snapshot();s.roster[1].spawnCap=nil;assert(not engine():arm(s));s=snapshot();s.roster[1].cost=nil;assert(not engine():arm(s))
end)
check('requires one supported spot for every unfilled slot',function()
    local s=snapshot();s.roster[2]=unit('b','second',100);s.roster[2].slot=2;local e=engine();assert(not e:arm(s));assert(e.reason:find('b',1,true))
end)
check('external controller and unresolved native feedback block arming',function()
    for _,key in ipairs({'externalControllerActive','mutationFence','transportBlocked'}) do local s=snapshot();s[key]=true;assert(not engine():arm(s)) end
end)
check('placement dispatch waits for exact new key UUID ID and position',function()
    local e=engine({upgrade=false});local s=snapshot();assert(e:arm(s));local a=e:tick(s);assert(a.kind=='place' and a.uuid=='a' and a.id=='attacker')
    s.units={tower('wrong','a','other',a.pos)};s.now=2;assert(e:tick(s)==nil and e.placements==0)
    s.units={tower('new','a','attacker',{10,0,14})};s.now=3;assert(e:tick(s)==nil and e.placements==0)
    s.units={tower('new','a','attacker',a.pos)};s.now=4;assert(e:tick(s)==nil and e.placements==1 and not e.pending)
end)
check('reused keys and ambiguous new placements never confirm',function()
    local s=snapshot();s.units={tower('old','unrelated','other',{80,0,80})};local e=engine();assert(e:arm(s));local a=e:tick(s)
    s.units={tower('old','a','attacker',a.pos)};s.now=2;e:tick(s);assert(e.placements==0 and e.pending)
    s.units={tower('x','a','attacker',a.pos),tower('y','a','attacker',a.pos)};s.now=3;e:tick(s);assert(not e.armed and e.placements==0)
end)
check('feedback timeout fences rearm in the same round without blind retry',function()
    local s=snapshot();local e=engine();assert(e:arm(s));assert(e:tick(s));s.now=10.1;e:tick(s)
    assert(not e.armed and e.placements==0 and not e:arm(s));s.run='r2';s.roundToken='native2';s.rosterAt=s.now;assert(e:arm(s))
end)
check('late readback after eight seconds does not confirm',function()
    local s=snapshot();local e=engine();assert(e:arm(s));local a=e:tick(s);s.now=10;s.units={tower('x','a','attacker',a.pos)}
    e:tick(s);assert(not e.armed and e.placements==0)
end)
check('Unique caps are one even when the definition cap is larger',function()
    local s=snapshot();s.roster[1].spawnCap=6;s.roster[1].trait='Unique';s.units={tower('old','a','attacker',{40,0,10})}
    local e=engine({upgrade=false});assert(e:arm(s));assert(e:tick(s)==nil and e.state=='HOLDING')
end)
check('existing towers count caps without being counted as confirmed actions',function()
    local s=snapshot();s.units={tower('old','a','attacker',{40,0,10})};s.autoSpots={};local e=engine({upgrade=false});assert(e:arm(s));assert(e:tick(s)==nil and e.placements==0)
end)
check('incremental caps do not demand every future position before the first placement',function()
    local s=snapshot();s.roster[1].spawnCap=24;s.autoSpots.a={{pos={10,0,10}}};local e=engine({upgrade=false});assert(e:arm(s));assert(e:tick(s).kind=='place')
end)
check('twenty four live targets bound all automatic placements',function()
    local s=snapshot();s.roster[1].spawnCap=30
    for i=1,24 do s.units[i]=tower('k'..i,'a','attacker',{i*10,0,100}) end
    local e=engine({upgrade=false});assert(e:arm(s));assert(e:tick(s)==nil and e.state=='HOLDING')
end)
check('balanced opening permits one farm while saving for first combat',function()
    local s=snapshot();s.cash=100;s.roster={unit('a','attacker',500),unit('f','farm',50,'farm',3),unit('b','buff',25,'buff')};for i,u in ipairs(s.roster) do u.slot=i end
    s.autoSpots.f={{pos={40,0,10}},{pos={60,0,10}}};s.autoSpots.b={{pos={50,0,10}}};local e=engine();assert(e:arm(s));local a=e:tick(s);assert(a.uuid=='f')
    s.units={tower('farm1','f','farm',a.pos)};s.now=2;e:tick(s);s.now=4;assert(e:tick(s)==nil and e.reason:find('combat'))
end)
check('reserve prevents spending and cheapest selection is configurable',function()
    local s=snapshot();s.cash=100;local e=engine({reserve=50});assert(e:arm(s));assert(e:tick(s)==nil)
    s=snapshot();s.roster[2]=unit('b','cheap',50);s.roster[2].slot=2;s.autoSpots.b={{pos={50,0,10}}}
    local cfg=C.sanitize({});cfg.autoMethod='Cheapest';e=makeAuto(C,cfg,C.logger());assert(e:arm(s));assert(e:tick(s).uuid=='b')
end)
check('round robin fills distinct slots before placing second copies',function()
    local s=snapshot();s.roster[1].spawnCap=2;s.roster[2]=unit('b','second',150);s.roster[2].slot=2;s.autoSpots.b={{pos={50,0,10}}}
    local e=engine({upgrade=false});assert(e:arm(s));local a=e:tick(s);assert(a.uuid=='a');s.units={tower('x','a','attacker',a.pos)};s.now=2;e:tick(s);s.now=4;assert(e:tick(s).uuid=='b')
end)
check('missing later geometry blocks explicitly without declaring full deployment',function()
    local s=snapshot();s.roster[1].spawnCap=2;s.units={tower('x','a','attacker',{10,0,10})};s.autoSpots={};local e=engine();assert(not e:arm(s));assert(e.state=='BLOCKED' and e.reason:find('spot'))
end)
check('lowest level upgrades use exact identity key position and single increment',function()
    local s=snapshot();s.units={tower('x','a','attacker',{10,0,10},0,50)};local e=engine();assert(e:arm(s));local a=e:tick(s);assert(a.kind=='upgrade' and a.key=='x')
    s.units[1].level=1;s.units[1].id='other';s.now=2;e:tick(s);assert(e.upgrades==0)
    s.units[1].id='attacker';s.now=3;e:tick(s);assert(e.upgrades==1 and not e.pending)
end)
check('upgrade prices and known maximum remain distinct and cheapest upgrades are configurable',function()
    local s=snapshot();s.roster[1].spawnCap=2
    s.units={tower('x','a','attacker',{10,0,10},0,100),tower('y','a','attacker',{20,0,10},1,25)}
    local e=engine();assert(e:arm(s));assert(e:tick(s).key=='x')
    local cfg=C.sanitize({});cfg.autoUpgradeMethod='Cheapest';e=makeAuto(C,cfg,C.logger());assert(e:arm(s));assert(e:tick(s).key=='y')
    s=snapshot();s.units={tower('x','a','attacker',{10,0,10},3)};e=engine();assert(e:arm(s));assert(e:tick(s)==nil and not e.pending and not e.reason:find('unproven'))
end)
check('unexpected level jumps and moved towers never confirm upgrades',function()
    local s=snapshot();s.units={tower('x','a','attacker',{10,0,10},0,100)};local e=engine();assert(e:arm(s));assert(e:tick(s))
    s.units[1].level=1;s.units[1].pos={100,0,100};s.now=2;e:tick(s);assert(e.upgrades==0 and e.pending)
    s.units[1].pos={10,0,10};s.units[1].level=2;s.now=3;e:tick(s);assert(e.upgrades==0 and not e.armed)
end)
check('same native round cannot be rearmed by changing only local run wrappers',function()
    local s=snapshot();local e=engine();assert(e:arm(s));assert(e:tick(s));e:stop('user')
    s.run='other-wrapper';assert(not e:arm(s))
end)
check('unknown upgrade cost is not treated as maximum',function()
    local s=snapshot();s.units={tower('x','a','attacker',{10,0,10})};local e=engine();assert(e:arm(s));e:tick(s);assert(e.armed and e.reason:find('price'))
    s.now=17;s.rosterAt=17;e:tick(s);assert(not e.armed and e.reason:find('price'))
end)
check('unexpected native round stage or external controller stops mutation',function()
    for _,key in ipairs({'roundToken','run','stage','mode','placeId'}) do local s=snapshot();local e=engine();assert(e:arm(s));s[key]='changed';assert(e:tick(s)==nil and not e.armed) end
    local s=snapshot();local e=engine();assert(e:arm(s));s.externalControllerActive=true;assert(e:tick(s)==nil and not e.armed)
end)
check('result defeat time limit and exact collection acquisition stop',function()
    for _,field in ipairs({'resultVisible','defeated'}) do local s=snapshot();local e=engine();assert(e:arm(s));s[field]=true;assert(e:tick(s)==nil and not e.armed) end
    local s=snapshot();local e=engine({maxSeconds=30});assert(e:arm(s));s.now=31;assert(e:tick(s)==nil and not e.armed)
    s=snapshot();e=engine();assert(e:arm(s));s.owned={{id='rukia_2',uuid='owned',statScope='collection'}};s.ownedAt=1;assert(e:tick(s)==nil and e.state=='GOAL_MET')
    s=snapshot();e=engine({goal='Trait'});assert(e:arm(s));s.owned={{id='rukia_2',uuid='owned',statScope='collection'}};s.ownedAt=1;assert(e:tick(s).kind=='place')
end)
check('Acquire observes any exact fresh collection Rukia and rejects aliases or future snapshots',function()
    local cfg=C.sanitize({selectedUuid='previous-selection'});local s=snapshot();local e=makeAuto(C,cfg,C.logger());assert(e:arm(s))
    s.owned={{id='rukia_2',uuid='new-rukia',statScope='collection'}};s.ownedAt=1;assert(e:tick(s)==nil and e.state=='GOAL_MET')
    for _,kind in ipairs({'alias','equipped','future','stale'}) do
        s=snapshot();e=engine();assert(e:arm(s));s.owned={{id=kind=='alias' and 'rukia' or 'rukia_2',uuid='r',statScope=kind=='equipped' and 'equipped' or 'collection'}}
        s.ownedAt=kind=='future' and 2 or kind=='stale' and -20 or 1;assert(e:tick(s).kind=='place')
    end
end)
check('reject stop and text expose honest confirmed counters',function()
    local s=snapshot();local e=engine();assert(e:arm(s));e:reject('server refusal');assert(not e.armed and e.reason:find('server refusal'));assert(e:text(s):find('placements=0',1,true));e:stop('user','IDLE');assert(e.state=='IDLE')
end)
local function priorityEngine(options)
    local cfg=C.sanitize(options or {});cfg.autoTarget=options and options.autoTarget or 'first'
    return makeAuto(C,cfg,C.logger())
end
check('GameDefault targeting emits no priority request',function()
    local s=snapshot();s.units={tower('x','a','attacker',{10,0,10},0,100)};s.units[1].priority='last'
    local e=engine();assert(e:arm(s));assert(e:tick(s).kind=='upgrade' and e.confirmations==0)
end)
check('first targeting runs only after placements and before upgrades',function()
    local s=snapshot();local e=priorityEngine();assert(e:arm(s));assert(e:tick(s).kind=='place')
    s=snapshot();s.units={tower('x','a','attacker',{10,0,10},0,100)};s.units[1].priority='last';e=priorityEngine();assert(e:arm(s))
    local a=e:tick(s);assert(a.kind=='priority' and a.key=='x' and a.uuid=='a' and a.id=='attacker' and a.target=='first')
    assert(e.pending.target=='first' and C.distance(e.pending.pos,s.units[1].pos)==0 and e.confirmations==0)
end)
check('target priority confirms only exact same key UUID ID and position',function()
    local s=snapshot();s.units={tower('x','a','attacker',{10,0,10},0,100)};s.units[1].priority='last';local e=priorityEngine();assert(e:arm(s));assert(e:tick(s).kind=='priority')
    for _,kind in ipairs({'key','uuid','id','position','priority'}) do
        local u=tower('x','a','attacker',{10,0,10},0,100);u.priority='first'
        if kind=='key' then u.key='unrelated' elseif kind=='uuid' then u.uuid='other' elseif kind=='id' then u.id='other'
        elseif kind=='position' then u.pos={30,0,10} else u.priority='last' end
        s.units={u};s.now+=1;assert(e:tick(s)==nil and e.confirmations==0 and e.pending)
    end
    s.units={tower('x','a','attacker',{10,0,10},0,100)};s.units[1].priority='first';s.now+=1;e:tick(s)
    assert(e.confirmations==1 and not e.pending and e.placements==0 and e.upgrades==0)
end)
check('unknown priority skips unsupported models and reports availability',function()
    local s=snapshot();s.roster[1].spawnCap=2;s.units={tower('unknown','a','attacker',{10,0,10},0,100),tower('supported','a','attacker',{20,0,10},0,100)}
    s.units[2].priority='last';local e=priorityEngine({upgrade=false});assert(e:arm(s));assert(e:tick(s).key=='supported');assert(e:text(s):find('priority unavailable',1,true))
    s=snapshot();s.units={tower('unknown','a','attacker',{10,0,10},0,100)};e=priorityEngine();assert(e:arm(s));assert(e:tick(s).kind=='upgrade');assert(e:text(s):find('priority unavailable',1,true))
end)
check('targeting skips farm buff unrelated and already first towers',function()
    local s=snapshot();s.roster={unit('a','attacker',100),unit('f','farm',50,'farm'),unit('b','buff',50,'buff')};for i,u in ipairs(s.roster) do u.slot=i end
    s.units={tower('attack','a','attacker',{10,0,10}),tower('farm','f','farm',{20,0,10}),tower('buff','b','buff',{30,0,10}),tower('other','z','unrelated',{40,0,10})}
    for _,u in ipairs(s.units) do u.priority='last' end;s.units[1].priority='first'
    local e=priorityEngine({upgrade=false});assert(e:arm(s));assert(e:tick(s)==nil and not e.pending and e.confirmations==0)
end)
check('priority feedback timeout blocks repeat mutations in the native round',function()
    local s=snapshot();s.units={tower('x','a','attacker',{10,0,10})};s.units[1].priority='last';local e=priorityEngine({upgrade=false});assert(e:arm(s));assert(e:tick(s).kind=='priority')
    s.now=2;assert(e:tick(s)==nil and e.pending and e.confirmations==0);s.now=10.1;assert(e:tick(s)==nil and not e.armed and e.confirmations==0 and not e:arm(s))
end)
check('confirmed priority observes normal action spacing before the next upgrade',function()
    local s=snapshot();s.units={tower('x','a','attacker',{10,0,10},0,100)};s.units[1].priority='last';local e=priorityEngine();assert(e:arm(s));assert(e:tick(s).kind=='priority')
    s.now=2;s.units[1].priority='first';e:tick(s);assert(e.confirmations==1)
    s.now=3;assert(e:tick(s)==nil and not e.pending);s.now=3.5;assert(e:tick(s).kind=='upgrade')
end)
check('missing-spot diagnostics never include equipped UUID record names',function()
    local s=snapshot();s.autoSpots={};s.roster[1].uuid='private-unit-record'
    local a=engine();assert(not a:arm(s));assert(not a:text(s):find('private-unit-record',1,true))
end)
check('per slot caps and waves prevent early placement and extra copies',function()
 local s=snapshot();local cfg=C.sanitize({placeCaps='-1',placeWaves='3'});local e=makeAuto(C,cfg,C.logger());assert(not e:arm(s))
 cfg=C.sanitize({placeCaps='1',placeWaves='3'});e=makeAuto(C,cfg,C.logger());assert(e:arm(s));assert(not e:tick(s))
 s.wave=3;assert(e:tick(s).kind=='place')
end)
check('full target priorities preserve exact readback',function()
 local s=snapshot();s.units={tower('x','a','attacker',{10,0,10},3)};s.units[1].priority='first'
 local cfg=C.sanitize({autoTarget='strongest'});local e=makeAuto(C,cfg,C.logger());assert(e:arm(s));local a=e:tick(s);assert(a.kind=='priority' and a.target=='strongest')
 s.units[1].priority='strongest';s.now=2;e:tick(s);assert(e.confirmations==1)
end)
check('upgrade cap and wave gate preserve attained levels',function()
 local s=snapshot();s.units={tower('x','a','attacker',{10,0,10},1,50)}
 local cfg=C.sanitize({upgradeCaps='1'});local e=makeAuto(C,cfg,C.logger());assert(e:arm(s));assert(not e:tick(s))
 cfg=C.sanitize({upgradeWaves='4'});e=makeAuto(C,cfg,C.logger());assert(e:arm(s));assert(not e:tick(s));s.wave=4;assert(e:tick(s).kind=='upgrade')
end)
check('unsupported hotbar slot never aliases a supported slot policy',function()
 local s=snapshot();s.roster[1].slot=7;local e=engine();assert(not e:arm(s))
end)
print('All '..n..' autoplay tests passed')
