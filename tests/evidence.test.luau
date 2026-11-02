local K=require('../src/contracts')
local E=require('../src/evidence')(K)
local n=0
local function test(name,f) local ok,err=pcall(f);assert(ok,name..': '..tostring(err));n+=1 end
local ctx={accountId=1,universeId=2,jobId='job',roundId='r',stageId='s',mode='Story',epoch=1}
local function view(at) return {now=at or 0,context=table.clone(ctx),evidence={roster={source='cache',schema='v1',observedAt=0,context=table.clone(ctx),scope='round',complete=true}},roster={{id='bulma'}}} end
E.register({id='place',schema='v1',requiredFields={'roster'},status='offline'})
E.register({id='ability',schema='v1',requiredFields={'abilities'},status='missing'})
test('missing is not an empty ownership list',function() local v=view();assert(v.account==nil);assert(not E.inspect('ability',v,0).ready);assert(E.inspect('place',v,0).ready) end)
test('quote stale at 2.1 seconds future and epoch change reject',function()
 local v=view(2.1);v.evidence.roster.scope='offer';assert(not E.inspect('place',v,2.1).ready)
 v=view();v.evidence.roster.observedAt=1;assert(not E.inspect('place',v,0).ready)
 v=view();v.context.epoch=2;assert(not E.inspect('place',v,0).ready)
end)
test('incomplete missing schema and context deny',function()
 local v=view();v.evidence.roster.complete=false;assert(not E.inspect('place',v,0).ready)
 v=view();v.evidence.roster.schema='other';assert(not E.inspect('place',v,0).ready)
 v=view();v.context.jobId='';assert(not E.inspect('place',v,0).ready)
end)
test('capture removes identities secrets functions and stops oversized data',function()
 local v=view();v.roster[1].uuid='SECRET';v.account={token='SECRET',webhook='SECRET',balance=10};v.account.bad=function()end
 local c=E.capture(v,{bytes=1024,nodes=50});assert(c.truncated~=nil);assert(c.roster[1].uuid==nil and c.account.token==nil and c.account.balance==10 and c.account.bad==nil)
 local huge={};for i=1,1000 do huge[i]=string.rep('x',100) end
 v.roster=huge;c=E.capture(v,{bytes=1024,nodes=50});assert(c.truncated and c.bytes<=1024)
end)
test('account scope ignores round but never job or epoch mismatch',function()
 local v=view();v.evidence.roster.scope='account';v.context.roundId='new';assert(E.inspect('place',v,0).ready)
 v.context.jobId='new';assert(not E.inspect('place',v,0).ready)
end)
print('All '..n..' evidence tests passed')
