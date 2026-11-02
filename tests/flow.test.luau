local C=require('../src/core');local make=require('../src/flow');local n=0
local function test(name,f)local ok,e=pcall(f);assert(ok,name..': '..tostring(e));n+=1 end
local function state()return {run='r',roundToken='t',stage='s',now=0,inMatch=true,stageVerified=true,modeVerified=true,wave=5,unitsComplete=true,units={},started=true,skipOffer={token='one',wave=5},skipFinished=false}end
test('wave skip once per offer with observed phase progress',function()
 local f=make(C,{autoSkip=true,skipStopWave=10});local s=state();f:arm(s);assert(f:tick(s).kind=='skip');assert(not f:tick(s))
 s.wave=6;s.now=1;f:tick(s);assert(f.confirmations==1);assert(not f:tick(s))
 s.skipOffer={token='two',wave=6};assert(f:tick(s).kind=='skip')
end)
test('skip stop wave timeout and stage change never resend',function()
 local f=make(C,{autoSkip=true,skipStopWave=5});local s=state();f:arm(s);assert(not f:tick(s))
 f=make(C,{autoSkip=true});f:arm(s);f:tick(s);s.now=9;f:tick(s);assert(not f.armed and not f:tick(s))
end)
test('sale requires sellable owned identity and removal, never sells Bulma',function()
 local f=make(C,{sellFarmWave=5});local s=state();s.units={{key='b',uuid='b',id='bulma',role='farm',sellable=false},{key='s',uuid='s',id='speedwagon',role='farm',sellable=true}}
 f:arm(s);assert(f:tick(s).key=='s');s.units[2]=nil;f:tick(s);assert(f.confirmations==1 and f.soldRoles.farm);assert(not f:tick(s))
end)
test('all capped card offers stop with no infinite rank winner',function()
 local f=make(C,{});local choice,reason=f:chooseCard({{slot=1,title='Yen'},{slot=2,title='Attack'}},{Yen=1,Attack=2},{Yen=1,Attack=1},{Yen=1,Attack=1})
 assert(not choice and reason:find('cap'));choice=f:chooseCard({{slot=1,title='Yen'},{slot=2,title='Attack'}},{Yen=1,Attack=2},{Yen=1,Attack=2},{Yen=1,Attack=1});assert(choice.slot==2)
end)
print('All '..n..' flow tests passed')
