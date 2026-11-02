-- Executes the actual entry source through a generated import/environment seam.
-- scripts/check.py creates and removes _entry_snapshot.luau around this suite.
local boot=require('./_entry_snapshot')
local C=require('../src/core')
local Auto=require('../src/autoplay')
local Dungeon=require('../src/dungeon')
local Runtime=require('../src/runtime')
local Session=require('../src/session')
local Trial=require('../src/trial')
local Team=require('../src/team')
local n=0
local function check(name,fn) local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));n+=1;print('PASS '..name) end
local function copy(t)
    if type(t)~='table' then return t end
    local out={};for k,v in pairs(t) do out[k]=copy(v) end;return out
end
local function world(shared)
    local w=shared or {files={},json={},env={},serial=0,clock=100,wall=1000,queued={},tasks={}}
    w.game={PlaceId=9,GameId=99,JobId=w.job or 'job1'}
    local player={UserId=12,Name='test'}
    local http={}
    function http:JSONEncode(value) w.serial+=1;local key='json'..w.serial;w.json[key]=copy(value);return key end
    function http:JSONDecode(key) assert(w.json[key],'unknown JSON');return copy(w.json[key]) end
    function w.game:IsLoaded() return true end
    function w.game:GetService(name) return ({Players={LocalPlayer=player},HttpService=http,Workspace={},ReplicatedStorage={}})[name] end
    w.s={now=w.clock,jobId=w.game.JobId,placeId=9,run='run1',roundToken={},stage='stage1',stageName='Stage1',stageVerified=true,
        mode='Story',modeVerified=true,inMatch=true,context='Match objects observed',started=true,wave=1,cash=1000,
        roster={{uuid='u1',id='attacker',slot=1,cost=100,spawnCap=1,role='combat',planningRange=20}},rosterAt=w.clock,
        rosterComplete=true,equippedDeclared=1,units={},unitsComplete=true,owned={},ownedAt=w.clock,resources={},
        resultVisible=false,outcome='unknown',pathSamples=0,dungeon={valid=false,reason='not Dungeon'}}
    local function adapter()
        local a={definitions={attacker={range=20,cost=100,spawn_cap=1}},cacheDone=false,requests={},confirmed=0}
        function a:observe() w.s.now=w.clock;w.s.rosterAt=w.clock;w.s.ownedAt=w.clock;return table.clone(w.s) end
        function a:busy() return false end
        function a:poll() return nil end
        function a:mutationFenced() return w.s.mutationFence==true end
        function a:dispatch(action)
            self.requests[#self.requests+1]=copy(action);local token={};self.feedback=token;w.s.mutationFence=true
            return true,nil,token
        end
        function a:confirmMutation(token) assert(token==self.feedback);w.s.mutationFence=false;self.confirmed+=1;return true end
        function a:startClientCache() self.cacheDone=true;return true end
        function a:refreshInventory() end
        function a:watchResults() self.watching=true end
        function a:stopResultWatch() self.watching=false end
        function a:combatReport() return 'mock combat report' end
        function a:close() self.closed=true end
        function a:remote() return {} end
        return a
    end
    local function navigation()
        return {plan=function(_,s) local spots={};for _,u in ipairs(s.roster) do spots[u.uuid]={{pos={10,0,10}}} end;return spots end,
            close=function() end}
    end
    local globals={game=w.game,workspace={GetChildren=function() return {} end},_G=w.env,getgenv=function() return w.env end,
        os={clock=function() return w.clock end,time=function() return w.wall end},
        readfile=function(name) if w.failLedgerProbe and name:find('Budget_',1,true) then error('transient read error') end;assert(w.files[name],'missing');return w.files[name] end,
        isfile=function(name) if w.failLedgerProbe and name:find('Budget_',1,true) then error('transient existence error') end;return w.files[name]~=nil end,
        delfile=function(name) w.files[name]=nil end,
        writefile=function(name,value) if not w.failWrites then w.files[name]=value end end,
        queue_on_teleport=function(code) w.queued[#w.queued+1]=code end,
        setclipboard=function(value) w.clipboard=value end,
        warn=function(value) w.warning=value end,
        task={wait=function() return coroutine.yield() end,spawn=function(fn) local co=coroutine.create(fn);w.tasks[#w.tasks+1]=co;return co end}}
    local imports={core=C,contracts=require('../src/contracts'),evidence=require('../src/evidence'),budget=require('../src/budget'),actions=require('../src/actions'),threats=require('../src/threats'),catalog=require('../src/catalog'),progression=require('../src/progression'),macro=require('../src/macro'),settings=require('../src/settings'),performance=require('../src/performance'),features=require('../src/features'),reports=require('../src/reports'),autoplay=Auto,dungeon=Dungeon,runtime=Runtime,session=Session,trial=Trial,team=Team,roblox=adapter,
        navigation=navigation,ui=function() return {refresh=function() end,close=function() end} end}
    boot(imports,setmetatable(globals,{__index=getfenv()}));w.app=w.env.K_AA_RUKIA_V6
    assert(w.app and w.app.alive)
    function w:step()
        self.clock+=.8;self.wall+=1
        local ok,why=coroutine.resume(self.tasks[#self.tasks]);assert(ok,why)
    end
    function w:marker() return http:JSONDecode(self.files['K_AA_Rukia_v6_Follow_12.json']) end
    return w
end
check('ordinary injection is unarmed and creates exactly one observer loop',function()
    local w=world();assert(not w.app.native.armed and #w.tasks==1 and #w.app.adapter.requests==0)
    w:step();assert(#w.app.adapter.requests==0)
end)
check('a native request is checkpointed in flight before dispatch and exact feedback clears it',function()
    local w=world();w.app:toggleFollow();w.app:toggleNative();assert(w.app.native.armed)
    w:step();assert(#w.app.adapter.requests==1 and w:marker().inFlight and not w:marker().armed)
    w.s.units={{uuid='u1',id='attacker',key='model',pos={10,0,10},level=2,maxLevel=2,priority='first'}}
    w:step();assert(w.app.native.placements==1 and w.app.adapter.confirmed==1)
    assert(not w:marker().inFlight and not w:marker().armed and not w.s.mutationFence)
end)
check('settings changes pause native control and never leave armed follow permission',function()
    local w=world();w.app:toggleFollow();w.app:toggleNative();w.app:set('reserve',500)
    assert(not w.app.native.armed and not w:marker().armed and w.app.cfg.reserve==500)
    w:step();assert(#w.app.adapter.requests==0)
end)
check('explicit close revokes the queued loader and stops native control',function()
    local w=world();w.app:toggleFollow();w.app:toggleNative();w.app:stop()
    assert(not w.app.alive and not w:marker().follow and not w:marker().armed and w.app.adapter.closed)
end)
check('verified next Story saves exact continuation and original caps before the vote',function()
    local w=world();w.app:toggleFollow();w.app.cfg.autoNextStory=true;w.app.cfg.maxRuns=2;w.s.nextStoryId='stage2'
    w.app:toggleNative();w.s.resultVisible=true;w.s.outcome='Victory';w:step()
    assert(w.app.adapter.requests[1].kind=='next')
    local m=w:marker();assert(m.armed and not m.inFlight and m.expected.kind=='next_story' and m.expected.stage=='stage2')
    assert(m.checkpoint.runs==1 and m.checkpoint.remainingRuns==1 and m.deadline==2200)
end)
check('a new-job queued replacement preserves the marker but manual replacement revokes it',function()
    local w=world();w.app:toggleFollow();w.app.cfg.autoNextStory=true;w.app.cfg.maxRuns=2;w.s.nextStoryId='stage2'
    w.app:toggleNative();w.s.resultVisible=true;w.s.outcome='Victory';w:step()
    local m=w:marker();w.job='job2';w.env.K_AA_Rukia_v6_FollowTicket={nonce=m.nonce,userId=12,universeId=99,jobId='job2'}
    world(w);assert(w:marker().follow and w.app.resumeCandidate and not w.app.native.armed)
    world(w);assert(not w:marker().follow and not w.app.resumeCandidate)
end)
check('an exact queued Story transition resumes within the original run and time budgets',function()
    local w=world();w.app:toggleFollow();w.app.cfg.autoNextStory=true;w.app.cfg.maxRuns=2;w.s.nextStoryId='stage2'
    w.app:toggleNative();w.s.resultVisible=true;w.s.outcome='Victory';w:step()
    local m=w:marker();w.job='job2';w.env.K_AA_Rukia_v6_FollowTicket={nonce=m.nonce,userId=12,universeId=99,jobId='job2'}
    world(w);w.s.stage='stage2';w.s.stageName='Stage2';w.clock+=11
    w:step();w:step()
    assert(w.app.native.armed and w.app.native.runs==1 and w.app.cfg.maxRuns==2 and w.app.nativeDeadline==2200)
    assert(#w.app.adapter.requests==1 and w.app.adapter.requests[1].kind=='place')
    assert(w:marker().inFlight and not w:marker().armed)
end)
check('a mismatched manual destination reloads the GUI but cannot resume spending',function()
    local w=world();w.app:toggleFollow();w.app.cfg.autoNextStory=true;w.app.cfg.maxRuns=2;w.s.nextStoryId='stage2'
    w.app:toggleNative();w.s.resultVisible=true;w.s.outcome='Victory';w:step()
    local m=w:marker();w.job='job2';w.env.K_AA_Rukia_v6_FollowTicket={nonce=m.nonce,userId=12,universeId=99,jobId='job2'}
    world(w);w.s.stage='wrong-stage';w.clock+=11;w:step();w:step()
    assert(w.app.alive and not w.app.native.armed and #w.app.adapter.requests==0)
    w.clock+=41;w:step();assert(not w:marker().armed and #w.app.adapter.requests==0)
end)
check('a silently failed file write cannot enable teleport following or queue a loader',function()
    local w=world();w.failWrites=true;w.app:toggleFollow()
    assert(not w.app.session.following and #w.queued==0 and not w.app.native.armed)
end)
check('a later maximum-duration arm is bounded by the remaining follow permission window',function()
    local w=world();w.app:toggleFollow();w.app.cfg.maxSeconds=7200;w.wall+=10;w.app:toggleNative();w:step()
    assert(w.app.native.armed and #w.app.adapter.requests==1)
    assert(w.app.nativeDeadline==w:marker().expires and w.app.nativeDeadline==8200)
end)
check('batched data capture never arms or invokes a game action',function()
    local w=world();w.app:captureGameData();assert(not w.app.native.armed and #w.app.adapter.requests==0)
    assert(w.clipboard and w.app.lastCapture.schema==1 and w.app.lastCapture.roster[1].uuid==nil)
end)
check('all gameplay dispatches cross the shared gate and unsupported spending is denied',function()
 local w=world();local sent=w.app:sendAction({kind='dungeon',name='dungeon_start',args={}});assert(not sent and #w.app.adapter.requests==0)
 w.app:toggleNative();w:step();assert(w.app.actions.pending() and w.app.budget.checkpoint().reservations)
end)
check('authorized follow carries shrine consent and unresolved debit survives replacement',function()
 local w=world();w.app.cfg.dungeonShrines=true;w.app.cfg.dungeonShrineItems='tome';w.app:toggleFollow();w.app.cfg.autoNextStory=true;w.app.cfg.maxRuns=2;w.s.nextStoryId='stage2'
 w.app:toggleNative();w.s.resultVisible=true;w.s.outcome='Victory';w:step();assert(w:marker().checkpoint.shrines==true)
 local v=w.app:observation();local b=w.app.budget;local g=b.grant(b.review({id='paid',caps={DungeonCoins=100},allowedOps={dungeon=true},expires=w.wall+100},v),true)
 assert(g);local a={id='pending-paid',capabilityId='dungeon',kind='dungeon',context=v.context,cost={DungeonCoins=30},expected={kind='buy'},deadline=w.clock+10,permissionId=g.id}
 assert(b.reserve(a));assert(b.sent(a.id));world(w);assert(w.app.budget.checkpoint().reservations['pending-paid'].sent)
end)
check('recorded native receipt creates a portable macro that plays through runtime',function()
 local w=world();assert(w.app:startMacroRecording());w.app:toggleNative();w:step()
 w.s.units={{uuid='u1',id='attacker',key='model',pos={10,0,10},level=2,maxLevel=2,priority='first'}};w:step()
 assert(#w.app.macro.data.steps==1 and w.app.macro.data.steps[1].target.slot==1);assert(w.app:finishMacroRecording())
 w.app:stopNative('test');world(w);assert(w.app:loadMacro());w.app:toggleMacro();w:step()
 assert(w.app.native.auto==w.app.macro and #w.app.adapter.requests==1 and w.app.adapter.requests[1].kind=='place')
end)
check('portable settings import stops automation and cannot restore grants',function()
 local w=world();w.app:toggleNative();assert(w.app.native.armed)
 local ok=w.app:applyPortableSettings({schema=1,settings={reserve=77,autoFollow=true,routeConfirmed=true,selectedUuid='secret'}})
 assert(ok and not w.app.native.armed and w.app.cfg.reserve==77 and not w.app.cfg.routeConfirmed and w.app.cfg.selectedUuid=='')
end)
check('new advanced text fields actually update validated settings',function()
 local w=world();w.app:set('placeCaps','1,2,-1');w.app:set('macroName','my_run');w.app:set('dungeonBuyOrder','tome,boots')
 assert(w.app.cfg.placeCaps=='1,2,-1' and w.app.cfg.macroName=='my_run' and w.app.cfg.dungeonBuyOrder=='tome,boots')
end)
check('indeterminate ledger initialization cannot replace a previous uncertain debit',function()
 local w=world();local b=w.app.budget;local v=w.app:observation();local g=b.grant(b.review({id='old',caps={DungeonCoins=100},allowedOps={dungeon=true},expires=w.wall+100},v),true);assert(g)
 local a={id='unknown',capabilityId='dungeon',kind='dungeon',context=v.context,cost={DungeonCoins=30},expected={kind='buy'},deadline=w.clock+8,permissionId=g.id}
 assert(b.reserve(a) and b.sent(a.id));local original=w.files['K_AA_Rukia_v7_Budget_12.json']
 w.failLedgerProbe=true;world(w);w.failLedgerProbe=false;b=w.app.budget
 local grant=b.grant(b.review({id='new',caps={DungeonCoins=100},allowedOps={dungeon=true},expires=w.wall+100},w.app:observation()),true)
 assert(not grant and w.files['K_AA_Rukia_v7_Budget_12.json']==original and #w.app.adapter.requests==0)
end)
check('macro rename refuses an occupied destination and failed writes retain source',function()
 local w=world();local function d(name)return {schema=1,name=name,stage='stage1',placeId=9,mode='Story',steps={{kind='place',wave=1,target={slot=1,id='attacker',actor=1},pos={1,0,1},timeout=30}}}end
 w.app.macro.data=d('A');assert(w.app:finishMacroRecording());w.app.macro.data=d('B');assert(w.app:finishMacroRecording())
 local a=w.files['K_AA_v8_Macro_12_A.json'];local b=w.files['K_AA_v8_Macro_12_B.json']
 w.app.macro.data=d('A');w.app.cfg.macroName='B';assert(not w.app:renameMacro());assert(w.files['K_AA_v8_Macro_12_A.json']==a and w.files['K_AA_v8_Macro_12_B.json']==b)
 w.app.cfg.macroName='C';w.failWrites=true;assert(not w.app:renameMacro());assert(w.files['K_AA_v8_Macro_12_A.json']==a and not w.files['K_AA_v8_Macro_12_C.json'])
end)
check('recording survives confirmed wave-start orchestration before placement',function()
 local w=world();w.s.started=false;w.s.voteStartFinished=false;w.app.cfg.autoStartWaves=true;assert(w.app:startMacroRecording());w.app:toggleNative();w:step()
 assert(w.app.adapter.requests[1].kind=='start');w.s.started=true;w.s.voteStartFinished=true;w:step();assert(w.app.macro.recording)
 w:step();assert(w.app.adapter.requests[2].kind=='place');w.s.units={{uuid='u1',id='attacker',key='tower',pos={10,0,10},level=2,maxLevel=2,priority='first'}};w:step()
 assert(w.app.macro.recording and #w.app.macro.data.steps==1 and w.app.macro.data.steps[1].kind=='place')
end)
print('All '..n..' entry integration tests passed')
