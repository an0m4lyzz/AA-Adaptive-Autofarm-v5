local makeSession=require('../src/session')
local count=0
local function test(name,fn)
    local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));count+=1;print('PASS '..name)
end
local function copy(t)
    if type(t)~='table' then return t end
    local v={};for k,x in pairs(t) do v[k]=copy(x) end;return v
end
local function setup(env,identity)
    local disk,queued=nil,{}
    local controls={now=1000,writeOK=true,queueOK=true}
    local io={read=function() return copy(disk) end,write=function(m)
        if not controls.writeOK then return false end;disk=copy(m);return true
    end,queue=function(code) if not controls.queueOK then return false end;queued[#queued+1]=code;return true end}
    local id=identity or {userId=42,universeId=77,jobId='job-a'}
    local globals=env or {}
    local function make(who,newenv) return makeSession({},io,newenv or globals,who or id,function() return controls.now end) end
    return make(),controls,queued,function() return disk end,function(v) disk=copy(v) end,make,globals
end
local function armed(s)
    assert(s:follow(true))
    assert(s:checkpoint({armed=true,mode='Story',stage='namek_1',expected={kind='replay',stage='namek_1',mode='Story',placeId=9},inFlight=false}))
end
local function snapshot()
    return {jobId='job-b',placeId=9,stage='namek_1',stageVerified=true,mode='Story',modeVerified=true}
end
local function ticket(env,m)
    env.K_AA_Rukia_v6_FollowTicket={nonce=m.nonce,userId=42,universeId=77,jobId='job-b'}
end
local function bootstrap(code,disk,opts)
    opts=opts or {};local fetched,ran=0,0;local time=0;local env={}
    local game={GameId=opts.universeId or 77,JobId='job-b'}
    function game:IsLoaded() return not opts.unloaded end
    function game:GetService(name)
        if name=='Players' then
            local p=nil;if not opts.noPlayer then p={UserId=opts.userId or 42} end
            return {LocalPlayer=p}
        end
        return {JSONDecode=function(_,_) if opts.badJson then error('bad') end;return copy(disk()) end}
    end
    function game:HttpGet(url)
        assert(url=='https://raw.githubusercontent.com/an0m4lyzz/AA-Adaptive-Autofarm-v5/main/main.lua');fetched+=1
        if opts.onFetch then opts.onFetch() end
        return 'return true'
    end
    local globals={game=game,os={time=function() return opts.now or 1000 end,clock=function() return time end},
        task={wait=function(dt) time+=dt end},getgenv=function() return env end,
        readfile=function(path) assert(path=='K_AA_Rukia_v6_Follow_42.json');return '{}' end,
        loadstring=function(_) return function() ran+=1 end end}
    setmetatable(globals,{__index=getfenv()});local fn=assert(loadstring(code));setfenv(fn,globals);fn()
    return fetched,ran,env,time
end

test('follow is explicit and queues the fixed entrypoint once across instances and generations',function()
    local s,c,q,get,_,make=setup();assert(s:load()==nil and #q==0)
    assert(s:follow(true));local first=get().nonce;assert(#q==1 and get().follow and not get().armed)
    assert(s:follow(true));assert(#q==1)
    assert(s:revoke('stop'));assert(not get().follow and not get().armed)
    assert(make():follow(true));assert(#q==1 and get().nonce~=first and not get().armed)
end)
test('revoke and close persist disarming and bootstrap observes revocation',function()
    local s,_,q,get=setup();armed(s);assert(s:revoke('stop'));assert(not get().armed and not get().follow)
    local fetch,ran=bootstrap(q[1],get);assert(fetch==0 and ran==0)
    assert(s:follow(true));assert(s:close());assert(not get().follow)
end)
test('failed durable writes fail closed locally and report durable revocation uncertainty',function()
    local s,c,q,get=setup();armed(s);c.writeOK=false
    local ok,why=s:revoke('stop');assert(not ok and string.find(why,'durable') and not s.armed)
    assert(get().armed and s.status=='revocation_failed');assert(not s:validateResume(snapshot()))
    assert(string.find(s:text(),'durable'))
    local _,can=s:load();assert(not can and not s.following and s.status=='revocation_failed')
    assert(string.find(s:text(),'durable'))
    assert(not s:checkpoint({armed=true,expected={kind='replay',stage='namek_1',mode='Story',placeId=9}}))
end)
test('queue failure revokes the previously written follow permission',function()
    local s,c,q,get=setup();c.queueOK=false;assert(not s:follow(true));assert(#q==0 and not get().follow)
end)
test('malformed identities expiry and marker fields are rejected without raising',function()
    local s,c,_,get,set=setup();armed(s);local good=copy(get())
    for _,change in ipairs({{userId=43},{universeId=78},{expires=1000},{expires=8201},{expires=0/0},{expires=math.huge},
        {schema=2},{nonce=''},{follow='true'},{armed='yes'},{originJob=''},{inFlight={kind='place'}},
        {expected={kind='anything',stage='namek_1',mode='Story',placeId=9}}}) do
        local m=copy(good);for k,v in pairs(change) do m[k]=v end;set(m);assert(s:load()==nil)
    end
    set(good);c.now=good.expires;assert(s:load()==nil)
end)
test('UI follow loads across changed stage without becoming armed',function()
    local s,_,q,get,_,make=setup();assert(s:follow(true));local fetch,ran,env=bootstrap(q[1],get)
    assert(fetch==1 and ran==1 and env.K_AA_Rukia_v6_FollowTicket)
    local m,can=make({userId=42,universeId=77,jobId='job-b'}):load();assert(m and not can and not m.armed)
end)
test('manual reload and same actual job cannot resume an armed session',function()
    local s,_,_,get,_,make,env=setup();armed(s)
    local m,can=make({userId=42,universeId=77,jobId='job-b'}):load();assert(m and not can)
    ticket(env,get());local same=make();same:load();assert(not same:validateResume(snapshot()))
end)
test('expected verified replay in a new actual job consumes the durable armed permission',function()
    local s,_,_,get,_,make,env=setup();armed(s);ticket(env,get())
    local nextSession=make({userId=42,universeId=77,jobId='job-b'});local m,can=nextSession:load();assert(m and can)
    assert(nextSession:validateResume(snapshot()));assert(not get().armed and get().follow)
    assert(not nextSession:validateResume(snapshot()))
end)
test('changed Story stage modes places or unverified observations never resume',function()
    local s,_,_,get,_,make,env=setup();armed(s);ticket(env,get())
    for _,change in ipairs({{stage='new_stage'},{mode='Dungeon'},{placeId=10},{stageVerified=false},{modeVerified=false},{jobId='forged'}}) do
        local nextSession=make({userId=42,universeId=77,jobId='job-b'});nextSession:load();local snap=snapshot()
        for k,v in pairs(change) do snap[k]=v end;assert(not nextSession:validateResume(snap))
    end
end)
test('unresolved mutations and unknown transitions never become continuations',function()
    for _,kind in ipairs({'place','upgrade','dungeon_buy_shop','dungeon_open_chest'}) do
        local s,_,_,get=setup();assert(s:follow(true))
        assert(s:checkpoint({armed=true,inFlight={kind=kind},mode='Story',expected={kind='replay',stage='namek_1',mode='Story',placeId=9}}))
        assert(get().inFlight and not get().armed)
    end
    local s=setup();assert(s:follow(true));assert(not s:checkpoint({armed=true,expected={kind='place'}}))
end)
test('Dungeon continuation requires exact expected depth choice and mode',function()
    local s,_,_,get,_,make,env=setup();assert(s:follow(true))
    assert(s:checkpoint({armed=true,mode='Dungeon',expected={kind='dungeon_enter_room',stage='dungeon_1',mode='Dungeon',placeId=9,depth=3,choice=2}}))
    ticket(env,get());local nextSession=make({userId=42,universeId=77,jobId='job-b'});assert(select(2,nextSession:load()))
    local snap=snapshot();snap.mode='Dungeon';snap.stage='dungeon_1';snap.dungeon={valid=true,depth=3,choice=1,level={active=true,depth=3,choice='1'}}
    assert(not nextSession:validateResume(snap));snap.dungeon.choice=2;snap.dungeon.level.choice='2';assert(nextSession:validateResume(snap))
end)
test('resume fails closed when consuming permission cannot be durably saved',function()
    local s,c,_,get,_,make,env=setup();armed(s);ticket(env,get());local nextSession=make({userId=42,universeId=77,jobId='job-b'})
    assert(select(2,nextSession:load()));c.writeOK=false;assert(not nextSession:validateResume(snapshot()));assert(not nextSession.armed)
end)
test('bootstrap rejects other account universe invalid expiry and malformed JSON',function()
    local s,_,q,get=setup();assert(s:follow(true))
    for _,opts in ipairs({{userId=43},{universeId=78},{now=9000},{badJson=true}}) do
        local fetch,ran=bootstrap(q[1],get,opts);assert(fetch==0 and ran==0)
    end
end)
test('bootstrap waits at most thirty seconds for Loaded and LocalPlayer',function()
    local s,_,q,get=setup();assert(s:follow(true));local fetch,ran,_,time=bootstrap(q[1],get,{unloaded=true})
    assert(fetch==0 and ran==0 and time<=30.25)
    fetch,ran,_,time=bootstrap(q[1],get,{noPlayer=true});assert(fetch==0 and ran==0 and time<=30.25)
end)
test('bootstrap rechecks durable nonce and follow after fetching before executing',function()
    local s,_,q,get,set=setup();assert(s:follow(true));local fetch,ran=bootstrap(q[1],get,{onFetch=function()
        local m=copy(get());m.follow=false;set(m)
    end});assert(fetch==1 and ran==0)
end)
test('valid saved opt-in registers following again once in each destination environment',function()
    local s,_,q,get,_,make=setup();armed(s);local destination={};ticket(destination,get())
    local nextSession=make({userId=42,universeId=77,jobId='job-b'},destination)
    assert(select(2,nextSession:load()));assert(#q==2)
    nextSession:load();assert(nextSession:follow(true));assert(#q==2)
end)
test('Dungeon next stage can be unknown but must be freshly verified with exact room identity',function()
    local s,_,_,get,_,make,env=setup();assert(s:follow(true))
    assert(s:checkpoint({armed=true,mode='Dungeon',expected={kind='dungeon_enter_room',mode='Dungeon',depth=3,choice=2}}))
    ticket(env,get());local nextSession=make({userId=42,universeId=77,jobId='job-b'});assert(select(2,nextSession:load()))
    local snap=snapshot();snap.mode='Dungeon';snap.stage='unknown_new_map';snap.dungeon={valid=true,depth=2,choice=2,level={active=true,depth=2,choice='2'}}
    assert(not nextSession:validateResume(snap));snap.dungeon.depth=3;snap.dungeon.level.depth=3;snap.stageVerified=false
    assert(not nextSession:validateResume(snap));snap.stageVerified=true;assert(nextSession:validateResume(snap))
end)
test('bootstrap nonce replacement after fetch rejects stale code even while follow remains enabled',function()
    local s,_,q,get,set=setup();assert(s:follow(true));local fetch,ran=bootstrap(q[1],get,{onFetch=function()
        local m=copy(get());m.nonce='new-generation';set(m)
    end});assert(fetch==1 and ran==0)
end)
test('saved marker cannot choose an external URL or executable source',function()
    local s,_,q,get,set=setup();assert(s:follow(true));local m=copy(get());m.url='https://evil.invalid/payload';m.code='error(1)';set(m)
    local loaded=s:load();assert(loaded and loaded.url==nil and loaded.code==nil)
    local fetch,ran=bootstrap(q[1],get);assert(fetch==1 and ran==1)
end)
test('invalid replacement checkpoint revokes the previously armed durable continuation',function()
    local s,_,_,get=setup();armed(s)
    assert(not s:checkpoint({armed=true,expected={kind='replay',mode='Story'}}))
    assert(not get().armed and not get().follow)
end)
test('missing or throwing persistence and queue adapters fail closed',function()
    local id={userId=42,universeId=77,jobId='job-a'}
    local s=makeSession({}, {},{},id,function() return 1000 end)
    assert(s:load()==nil and not s:follow(true) and not s:revoke('stop'))
    s=makeSession({}, {read=function() error('read') end,write=function() error('write') end},{},id,function() return 1000 end)
    assert(s:load()==nil and not s:follow(true) and not s:revoke('stop'))
    for _,identity in ipairs({{userId=0,universeId=77,jobId='job-a'},{userId=42.5,universeId=77,jobId='job-a'},
        {userId=42,universeId=0,jobId='job-a'},{userId=42,universeId=77,jobId=''}}) do
        local invalid=makeSession({}, {},{},identity,function() return 1000 end);assert(not invalid:follow(true))
    end
end)
test('continuation checkpoint preserves bounded spent caps run budgets and explicit permissions',function()
    local s,_,_,get,_,make,env=setup();assert(s:follow(true))
    local checkpoint={spent=12345,shopCap=1000000,runs=100,remainingRuns=0,openChests=false,replayFree=true,startWaves=false,unknown='discard'}
    assert(s:checkpoint({armed=true,expected={kind='replay',stage='namek_1',mode='Story',placeId=9},checkpoint=checkpoint}))
    ticket(env,get());local nextSession=make({userId=42,universeId=77,jobId='job-b'});local m,can=nextSession:load()
    assert(can and not nextSession.armed and m.checkpoint.spent==12345 and m.checkpoint.shopCap==1000000)
    assert(m.checkpoint.runs==100 and m.checkpoint.remainingRuns==0)
    assert(m.checkpoint.openChests==false and m.checkpoint.replayFree==true and m.checkpoint.startWaves==false and m.checkpoint.unknown==nil)
    assert(nextSession:validateResume(snapshot()));assert(get().checkpoint.spent==12345 and get().checkpoint.remainingRuns==0)
end)
test('invalid saved continuation budgets or permission types cannot silently reset',function()
    for _,change in ipairs({{spent=-1},{spent=1000001},{spent=0/0},{shopCap=math.huge},{shopCap=1000001},{runs=101},
        {runs=0.5},{remainingRuns=101},{remainingRuns=-1},{openChests=1},{replayFree='true'},{startWaves={}}}) do
        local s,_,_,get,set=setup();armed(s);local bad=copy(get());bad.checkpoint=change;set(bad)
        assert(s:load()==nil)
        local replacement=setup();armed(replacement)
        assert(not replacement:checkpoint({armed=true,expected={kind='replay',stage='namek_1',mode='Story',placeId=9},checkpoint=change}))
    end
end)
test('Dungeon native string choices and legacy integers normalize to canonical strings',function()
    for _,requested in ipairs({'1','2','3',1,2,3}) do
        local s,_,_,get,_,make,env=setup();assert(s:follow(true))
        assert(s:checkpoint({armed=true,expected={kind='dungeon_enter_room',mode='Dungeon',depth=3,choice=requested},checkpoint={choice=requested}}))
        assert(get().expected.choice==tostring(requested) and get().checkpoint.choice==tostring(requested))
        ticket(env,get());local nextSession=make({userId=42,universeId=77,jobId='job-b'});assert(select(2,nextSession:load()))
        local snap=snapshot();snap.mode='Dungeon';snap.dungeon={valid=true,depth=3,choice=tostring(requested),level={active=true,depth=3,choice=tostring(requested)}}
        assert(nextSession:validateResume(snap))
    end
    for _,bad in ipairs({'0','4','02',0,4,2.5}) do
        local s=setup();assert(s:follow(true))
        assert(not s:checkpoint({armed=true,expected={kind='dungeon_enter_room',mode='Dungeon',depth=3,choice=bad}}))
    end
end)
test('known next Story continuation requires exact fresh destination and preserves only explicit next consent',function()
    local s,_,q,get,_,make,env=setup();assert(s:follow(true))
    assert(s:checkpoint({armed=true,expected={kind='next_story',stage='namek_2',mode='Story',placeId=9},checkpoint={nextStory=true}}))
    ticket(env,get());local nextSession=make({userId=42,universeId=77,jobId='job-b'});local marker,can=nextSession:load()
    assert(can and not nextSession.armed and marker.checkpoint.nextStory==true)
    local snap=snapshot();assert(not nextSession:validateResume(snap));snap.stage='namek_2'
    snap.stageVerified=false;assert(not nextSession:validateResume(snap));snap.stageVerified=true
    assert(nextSession:validateResume(snap));assert(get().checkpoint.nextStory==true and not get().armed)
    local fetched,ran=bootstrap(q[1],get);assert(fetched==1 and ran==1)
end)
test('next Story transitions prohibit wildcard stages and nonboolean saved consent',function()
    for _,e in ipairs({{kind='next_story',mode='Story',placeId=9},{kind='next_story',stage='',mode='Story',placeId=9},
        {kind='next_story',stage='namek_2',mode='Dungeon',placeId=9},{kind='next_story',stage='namek_2',mode='Story'}}) do
        local s=setup();assert(s:follow(true));assert(not s:checkpoint({armed=true,expected=e}))
    end
    local s,_,_,get,set=setup();armed(s);local marker=copy(get());marker.checkpoint={nextStory='true'};set(marker)
    assert(s:load()==nil)
    s=setup();assert(s:follow(true));assert(s:checkpoint({checkpoint={nextStory=false}}));assert(select(1,s:load()).checkpoint.nextStory==false)
end)
test('consumed queue renews across A B C with retained globals and same-job reloads deduplicate',function()
    local a,_,q,get,_,make,env=setup();armed(a);assert(#q==1);table.remove(q,1)
    ticket(env,get());local b=make({userId=42,universeId=77,jobId='job-b'});assert(select(2,b:load()));assert(#q==1)
    assert(select(2,make({userId=42,universeId=77,jobId='job-b'}):load()));assert(#q==1)
    assert(b:validateResume(snapshot()));assert(b:revoke('stop'));assert(b:follow(true));assert(#q==1)
    assert(b:checkpoint({armed=true,expected={kind='replay',stage='namek_1',mode='Story',placeId=9}}));table.remove(q,1)
    env.K_AA_Rukia_v6_FollowTicket={nonce=get().nonce,userId=42,universeId=77,jobId='job-c'}
    local c=make({userId=42,universeId=77,jobId='job-c'});assert(select(2,c:load()));assert(#q==1)
    local snap=snapshot();snap.jobId='job-c';assert(c:validateResume(snap));assert(#q==1)
    assert(c:revoke('stop'));assert(c:follow(true));assert(#q==1)
end)
test('Dungeon continuation requires exact active native identity and rejects contradictory profile without consumption',function()
    local cases={
        {},{level={active=false,depth=3,choice='2'}},{level={active=true,depth=2,choice='2'}},
        {level={active=true,depth=0/0,choice='2'}},{level={active=true,depth=math.huge,choice='2'}},
        {level={active=true,depth=3.5,choice='2'}},{level={active=true,depth=3,choice='1'}},
        {level={active=true,depth=3}},{level={active=true,depth=3,choice=2}},
        {level={active=true,depth=3,choice='02'}},
        {level={active=true,depth=3,choice='2'},profileChoice='1'},
        {level={active=true,depth=3,choice='2'},profileDepth=2}
    }
    for _,case in ipairs(cases) do
        local s,_,_,get,_,make,env=setup();assert(s:follow(true))
        assert(s:checkpoint({armed=true,expected={kind='dungeon_enter_room',mode='Dungeon',depth=3,choice='2'}}))
        ticket(env,get());local nextSession=make({userId=42,universeId=77,jobId='job-b'});assert(select(2,nextSession:load()))
        local snap=snapshot();snap.mode='Dungeon';snap.dungeon={valid=true,depth=case.profileDepth or 3,choice=case.profileChoice or '2',level=copy(case.level)}
        assert(not nextSession:validateResume(snap));assert(get().armed)
        snap.dungeon={valid=true,depth=3,choice='2',level={active=true,depth=3,choice='2'}}
        assert(nextSession:validateResume(snap));assert(not get().armed)
    end
end)
test('exact active native room can resume without flattened profile identity',function()
    local s,_,_,get,_,make,env=setup();assert(s:follow(true))
    assert(s:checkpoint({armed=true,expected={kind='dungeon_enter_room',mode='Dungeon',depth=3,choice='2'}}))
    ticket(env,get());local nextSession=make({userId=42,universeId=77,jobId='job-b'});assert(select(2,nextSession:load()))
    local snap=snapshot();snap.mode='Dungeon';snap.dungeon={valid=true,level={active=true,depth=3,choice='2'}}
    assert(nextSession:validateResume(snap))
end)
print('session '..count..' tests passed')
