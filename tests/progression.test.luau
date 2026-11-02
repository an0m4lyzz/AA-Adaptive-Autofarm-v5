local C=require('../src/core');local P=require('../src/progression')(C)
local n=0;local function test(name,f)local ok,e=pcall(f);assert(ok,name..': '..tostring(e));n+=1 end
local function view() return {now=1,ownedAt=1,owned={},resources={},wallet={},stage='s',mode='Story'} end
local function catalog()return {build='b',current={available=true,verified=true,build='b',route={stage='d',mode='Dungeon',verified=true},recipe={verified=true,items={Red=3},takedowns=100}},measured={}}end
test('old Rukia and partial absence never prove ownership',function()
 local v=view();v.owned={{id='rukia',statScope='collection',uuid='old'}}
 local p=P.plan(v,{}, {kind='Acquire'});assert(not p.stop and p.blocker and p.owned==nil)
end)
test('positive exact collection stops acquire even with stale selected copy',function()
 local v=view();v.owned={{id='rukia_2',statScope='collection',uuid='new'}}
 assert(P.plan(v,{}, {kind='Acquire',selectedUuid='old'}).stop)
 v.ownedAt=2;assert(not P.plan(v,{}, {kind='Acquire'}).stop)
end)
test('historical recipe cannot authorize material route',function()
 local v=view();v.owned={{id='rukia_2',statScope='collection',uuid='u'}}
 local c=catalog();c.current.verified=false;local p=P.plan(v,c,{kind='Evolution'});assert(p.blocker and not p.route)
end)
test('verified current recipe shows unknown versus exact missing rows',function()
 local v=view();v.build='b';v.owned={{id='rukia_2',statScope='collection',uuid='u',takedowns=90}};v.resources.Red=1
 local p=P.plan(v,catalog(),{kind='Evolution'});assert(p.deficits.Red==2 and p.takedownsMissing==10)
 v.resources.Red=nil;p=P.plan(v,catalog(),{kind='Evolution'});assert(p.deficits.Red==nil and p.unknown.Red)
end)
test('measured useful route beats unknown yield without invented rates',function()
 local v=view();local routes={{stage='unknown',useful=true},{stage='known',useful=true,wins=3,attempts=4,totalSeconds=120,rewardCount=6}}
 local best=P.rankRoutes(routes);assert(best.stage=='known')
end)
test('observed target trait stops without needing a historical price',function()
 local v=view();v.owned={{id='rukia_2',statScope='collection',uuid='u',trait='Unique'}}
 assert(P.plan(v,{}, {kind='Trait',trait='Unique'}).stop)
end)
print('All '..n..' progression tests passed')
