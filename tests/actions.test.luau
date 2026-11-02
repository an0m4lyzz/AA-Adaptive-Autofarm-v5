local K=require('../src/contracts');local make=require('../src/actions');local n=0
local function test(name,f) local ok,err=pcall(f);assert(ok,name..': '..tostring(err));n+=1 end
local ctx={accountId=1,universeId=2,jobId='j',roundId='r',stageId='s',mode='Story',epoch=0}
local function action(id) return {id=id or 'a',capabilityId='place',kind='place',context=ctx,cost={},expected={kind='place'},deadline=8} end
local function setup()
 local count=0;local live={context=ctx,now=0};local b={reserve=function()return true end,sent=function()return true end,cancel=function()end,settle=function()return true end}
 local e={inspect=function()return {ready=true}end};local a=make(K,e,b,{send=function()count+=1;return true end,verify=function(_,v)return v.receipt end})
 return a,live,function()return count end
end
test('all domains serialize and timeout never resends',function()
 local a,v,count=setup();assert(a.submit(action(),v,{}).kind=='action');assert(a.submit(action('b'),v,{}).kind=='wait');assert(count()==1)
 v.now=9;assert(a.observe(v).status=='uncertain');assert(a.pending());assert(a.submit(action('c'),v,{}).kind=='wait' and count()==1)
end)
test('exact proof settles once late after stop never rearms',function()
 local a,v,count=setup();a.submit(action(),v,{});a.stop('stop')
 v.receipt={intentId='a',status='confirmed',proof=true,context=ctx};assert(a.observe(v).status=='confirmed');assert(not a.pending());assert(count()==1)
 assert(a.submit(action('b'),v,{}).kind=='stop')
end)
test('wrong context unrelated receipt and missing proof cannot acknowledge',function()
 local a,v=setup();a.submit(action(),v,{})
 v.receipt={intentId='other',status='confirmed',proof=true,context=ctx};assert(not a.observe(v) and a.pending())
 v.receipt={intentId='a',status='confirmed',context=ctx};assert(not a.observe(v) and a.pending())
 v.receipt={intentId='a',status='confirmed',proof=true,context=table.clone(ctx)};v.receipt.context.epoch=1
 assert(not a.observe(v) and a.pending())
end)
test('failed durable checkpoint prevents actual send',function()
 local calls=0;local a=make(K,{inspect=function()return {ready=true}end},{reserve=function()return false end},{send=function()calls+=1;return true end})
 assert(a.submit(action(),{now=0,context=ctx},{}).kind=='stop');assert(calls==0)
end)
print('All '..n..' actions tests passed')
