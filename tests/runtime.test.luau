local C=require('../src/core')
local makeAuto=require('../src/autoplay')
local makeDungeon=require('../src/dungeon')
local ok,makeRuntime=pcall(require,'../src/runtime')
assert(ok,'Native combat/Dungeon runtime is not implemented')
local n=0
local failures={}
local function check(name,f)
    local success,err=pcall(f);n+=1
    if success then print('PASS '..name) else failures[#failures+1]=name..': '..tostring(err);print('FAIL '..name) end
end
local function setup(options,dungeon)
    local cfg=C.sanitize({goal='Build',upgrade=false,maxSeconds=300,maxRuns=3})
    for k,v in options or {} do cfg[k]=v end
    local s={now=1,run='r1',roundToken='native1',stage='stage1',placeId=9,mode=dungeon and 'Dungeon' or 'Story',
        inMatch=true,stageVerified=true,modeVerified=true,started=true,voteStartFinished=false,wave=1,cash=1000,
        rosterComplete=true,rosterAt=1,unitsComplete=true,units={},owned={},resultVisible=false,
        roster={{slot=1,uuid='a',id='attacker',cost=100,role='combat',spawnCap=1}},
        autoSpots={a={{pos={10,0,10}},{pos={20,0,10}}}}}
    local data={_started=true,_resources={money=100,treasure=0,treasure_gold=0},_items={},
        next={['1']={_d=2,_t={['1']=true}}},current_shops={}}
    local service={session={profile_data={dungeon_data=data}}}
    local core={TYPES={SHOP=1,SHRINE=7,OPEN_CHEST=6},ITEMS={},NUM_ROOMS=20}
    local level={_dungeon={depth=1,choice_str='1',lives=3,finished=false}}
    local function refresh() s.dungeon=makeDungeon(C).snapshot(service,core,level);s.dungeonAt=s.now;s.rosterAt=s.now end
    refresh()
    return makeRuntime(C,makeAuto,makeDungeon,cfg,C.logger()),s,cfg,data,refresh,level
end
local function victory(s) s.resultVisible=true;s.outcome='Victory' end
local function tower(s) s.units={{key='tower1',uuid='a',id='attacker',pos={10,0,10},level=0,maxLevel=0}} end
check('Story delegates observed readiness and combat',function()
    local r,s=setup();assert(r:arm(s));assert(r:tick(s).kind=='place');assert(r.pending==r.auto.pending)
    r.pending.feedbackToken='native-token';assert(r.auto.pending.feedbackToken=='native-token')
    tower(s);s.now=2;r:tick(s);assert(r.placements==1 and r.pending==nil and r.armed)
end)
check('Story arm rejects unsupported spots and fences',function()
    for _,field in {'mutationFence','transportBlocked','externalControllerActive'} do local r,s=setup();s[field]=true;assert(not r:arm(s)) end
    local r,s=setup();s.autoSpots={};assert(not r:arm(s))
end)
check('Dungeon requires explicit consent and fresh started cache',function()
    local r,s=setup(nil,true);assert(not r:arm(s))
    for _,case in {'invalid','stale','notStarted'} do
        local r2,s2,c,d,refresh=setup({dungeonConsent=true},true)
        if case=='invalid' then s2.dungeon.valid=false elseif case=='stale' then s2.now=7 else d._started=false;refresh() end
        assert(not r2:arm(s2))
    end
end)
check('unfinished Dungeon runs combat while route remains idle',function()
    local r,s=setup({dungeonConsent=true},true);assert(r:arm(s));local a=r:tick(s)
    assert(a.kind=='place' and not r.route.pending and r.pending==r.auto.pending)
end)
check('Dungeon Victory stops combat then enters once',function()
    local r,s=setup({dungeonConsent=true},true);assert(r:arm(s));victory(s)
    local a=r:tick(s);assert(a.kind=='dungeon' and a.name=='dungeon_enter_room');assert(not r.auto.armed and r.pending==r.route.pending)
    assert(r:tick(s)==nil and r.confirmations==0)
end)
check('result with unconfirmed combat stops both children without route action',function()
    for _,dungeon in {true,false} do
        local r,s=setup({dungeonConsent=true},dungeon);assert(r:arm(s));r:tick(s);victory(s);assert(r:tick(s)==nil)
        assert(not r.armed and not r.auto.armed and not r.route.armed and r.placements==0 and r.confirmations==0)
    end
end)
check('explicit existing-run lobby route can enter without verified combat context',function()
    local r,s=setup({dungeonConsent=true,mode='Dungeon'},true);s.inMatch=false;s.modeVerified=false;s.stageVerified=false;s.autoSpots=nil
    assert(r:arm(s));assert(not r.auto.armed);assert(r:tick(s).name=='dungeon_enter_room')
end)
check('route pending verifies under fence before combat and waits for result clear',function()
    local r,s,c,d,refresh,level=setup({dungeonConsent=true},true);assert(r:arm(s));victory(s);r:tick(s)
    s.mutationFence=true;s.transportBlocked=true;level._dungeon.depth=2;s.run='r2';s.roundToken='native2';refresh()
    assert(r:tick(s)==nil and r.confirmations==1 and not r.pending and not r.auto.armed and r.armed)
    s.mutationFence=false;s.transportBlocked=false;assert(r:tick(s)==nil and not r.auto.armed and r.armed)
    s.resultVisible=false;s.started=true;s.now=2;refresh();assert(r:tick(s)==nil and r.auto.armed)
    assert(r:tick(s).kind=='place')
end)
check('unexpected round changes stop all outside confirmed enter',function()
    for _,dungeon in {true,false} do local r,s=setup({dungeonConsent=true},dungeon);assert(r:arm(s));s.roundToken='surprise';assert(r:tick(s)==nil and not r.armed) end
end)
check('route enter mismatched depth cannot authorize changed round',function()
    local r,s,c,d,refresh,level=setup({dungeonConsent=true},true);assert(r:arm(s));victory(s);r:tick(s)
    s.run='wrong';s.roundToken='wrong';level._dungeon.depth=9;refresh();assert(r:tick(s)==nil and r.confirmations==0 and not r.auto.armed)
    s.now=22;refresh();r:tick(s);assert(not r.armed)
end)
check('death defeat unknown result and stale Dungeon stop both',function()
    for _,key in {'dead','defeated','defeat','unknown','stale'} do
        local r,s=setup({dungeonConsent=true},true);assert(r:arm(s))
        if key=='defeat' then s.resultVisible=true;s.outcome='Defeat' elseif key=='unknown' then s.resultVisible=true;s.outcome='unknown'
        elseif key=='stale' then s.now=7 else s[key]=true end
        assert(r:tick(s)==nil and not r.armed and not r.auto.armed and not r.route.armed)
    end
end)
check('Dungeon permission revocation stops pending route',function()
    local r,s,c=setup({dungeonConsent=true},true);assert(r:arm(s));victory(s);r:tick(s);c.dungeonConsent=false
    assert(r:tick(s)==nil and not r.armed and not r.pending)
end)
check('global time limit survives Dungeon combat rearm',function()
    local r,s,c,d,refresh,level=setup({dungeonConsent=true,maxSeconds=30},true);assert(r:arm(s));victory(s);r:tick(s)
    s.now=20;level._dungeon.depth=2;s.run='r2';s.roundToken='native2';s.resultVisible=false;refresh();r:tick(s);r:tick(s)
    assert(r.auto.armed);s.now=31;refresh();assert(r:tick(s)==nil and not r.armed)
end)
check('start waves emits once and verifies native observation before combat',function()
    local r,s=setup({autoStartWaves=true});s.started=false;assert(r:arm(s));local a=r:tick(s);assert(a.kind=='start' and r.pending.kind=='start')
    s.mutationFence=true;s.transportBlocked=true;s.rpcResult=true;assert(r:tick(s)==nil and r.pending and r.placements==0)
    s.voteStartFinished=true;r:tick(s);assert(r.confirmations==1 and not r.pending and r.armed)
    s.mutationFence=false;s.transportBlocked=false;assert(r:tick(s)==nil)
    s.started=true;assert(r:tick(s).kind=='place')
end)
check('start timeout no retry and unknown native start state does not send',function()
    local r,s=setup({autoStartWaves=true});s.started=false;assert(r:arm(s));r:tick(s);s.now=10;r:tick(s);assert(not r.armed and not r:tick(s))
    r,s=setup({autoStartWaves=true});s.started=false;s.voteStartFinished=nil;assert(r:arm(s));assert(r:tick(s)==nil and not r.pending)
end)
check('Story result counts once and does not replay by default',function()
    local r,s=setup();assert(r:arm(s));victory(s);assert(r:tick(s)==nil and not r.armed and r.runs==1);r:tick(s);assert(r.runs==1)
end)
check('Story replay requires consent bound to current context and bounded runs',function()
    for _,which in {'off','unbound','limit','defeat'} do
        local r,s,c=setup({replay=true,replayFreeConfirmed=true,maxRuns=3});c.replayContext={stage=s.stage,mode=s.mode,placeId=s.placeId}
        if which=='off' then c.replayFreeConfirmed=false elseif which=='unbound' then c.replayContext.stage='other' elseif which=='limit' then c.maxRuns=1 end
        assert(r:arm(s));victory(s);if which=='defeat' then s.outcome='Defeat' end
        assert(r:tick(s)==nil and not r.armed)
    end
end)
check('Story replay expected context and exact new round reset',function()
    local r,s,c=setup({replay=true,replayFreeConfirmed=true});c.replayContext={stage=s.stage,mode=s.mode,placeId=s.placeId};assert(r:arm(s));victory(s)
    local a=r:tick(s);assert(a.kind=='replay' and a.expected.kind=='replay' and a.expected.stage==s.stage and a.expected.mode=='Story' and a.expected.placeId==9)
    assert(r.pending.kind=='replay' and r.runs==1);s.rpcResult=true;assert(r:tick(s)==nil and r.pending)
    s.run='r2';s.roundToken='native2';s.resultVisible=false;tower(s);assert(r:tick(s)==nil and r.pending)
    s.units={};s.mutationFence=true;s.transportBlocked=true;r:tick(s);assert(r.confirmations==1 and not r.pending and not r.auto.armed)
    s.mutationFence=false;s.transportBlocked=false;r:tick(s);assert(r.auto.armed and r.runs==1)
    local b=r:tick(s);assert(b.kind=='place')
end)
check('replay refuses same token only run change wrong context and timeout',function()
    local r,s,c=setup({replay=true,replayFreeConfirmed=true});c.replayContext={stage=s.stage,mode=s.mode,placeId=s.placeId};assert(r:arm(s));victory(s);r:tick(s)
    s.run='r2';s.resultVisible=false;r:tick(s);assert(r.pending and not r.auto.armed)
    s.now=22;r:tick(s);assert(not r.armed and r.confirmations==0)
end)
check('replay consent revocation stops before readback',function()
    local r,s,c=setup({replay=true,replayFreeConfirmed=true});c.replayContext={stage=s.stage,mode=s.mode,placeId=s.placeId};assert(r:arm(s));victory(s);r:tick(s)
    c.replayFreeConfirmed=false;assert(r:tick(s)==nil and not r.armed)
end)
check('optional Story lobby return verifies observed lobby and stops',function()
    local r,s=setup({autoReturnLobby=true});assert(r:arm(s));victory(s);local a=r:tick(s);assert(a.kind=='lobby')
    s.mutationFence=true;s.transportBlocked=true;assert(r:tick(s)==nil and r.pending)
    s.observedLobby=true;s.inMatch=false;r:tick(s);assert(not r.armed and r.confirmations==1 and r.state=='COMPLETE')
end)
check('reject and manual stop clear all pending state and expose text',function()
    local r,s=setup();assert(r:arm(s));r:tick(s);r:reject('native rejected');assert(not r.armed and not r.pending and r.reason:find('native rejected',1,true))
    s.mutationFence=true;assert(type(r:text(s))=='string' and #r:readiness(s,false)>0)
end)
check('combat pending exact feedback is permitted under own native fence',function()
    local r,s=setup();assert(r:arm(s));r:tick(s);s.mutationFence=true;s.transportBlocked=true;tower(s)
    assert(r:tick(s)==nil and r.armed and r.placements==1 and not r.pending)
end)
check('all counters survive internal rearm and reset only on explicit session arm',function()
    local r,s,c=setup({replay=true,replayFreeConfirmed=true});c.replayContext={stage=s.stage,mode=s.mode,placeId=s.placeId}
    assert(r:arm(s));r:tick(s);tower(s);r:tick(s);victory(s);r:tick(s)
    s.resultVisible=false;s.run='r2';s.roundToken='native2';s.units={};r:tick(s);r:tick(s)
    assert(r.placements==1 and r.runs==1 and r.confirmations==1)
    r:stop('User stopped','IDLE');assert(r:arm(s));assert(r.placements==0 and r.runs==0 and r.confirmations==0)
end)
check('terminal Dungeon completion stops whole runtime',function()
    local r,s,c,d,refresh=setup({dungeonConsent=true,dungeonOpenChests=true},true)
    assert(r:arm(s));victory(s);d._finished=true;d.current_shops={{_t=6,data={}}};refresh()
    assert(r:tick(s).name=='dungeon_continue_shop');d.current_shops={};d._started=false;refresh();r:tick(s)
    assert(r.armed and r.confirmations==1);r:tick(s);assert(not r.armed and not r.auto.armed and r.state=='COMPLETE')
end)
check('confirmed Story Defeat counts once and never retries',function()
    local r,s=setup({replay=true,replayFreeConfirmed=true,autoReturnLobby=true});assert(r:arm(s));s.resultVisible=true;s.outcome='Defeat'
    assert(r:tick(s)==nil and not r.armed and r.runs==1 and r.losses==1);r:tick(s);assert(r.runs==1)
end)
check('automatic wave-start may run once in each confirmed replay round',function()
    local r,s,c=setup({autoStartWaves=true,replay=true,replayFreeConfirmed=true});c.replayContext={stage=s.stage,mode=s.mode,placeId=s.placeId}
    s.started=false;assert(r:arm(s));assert(r:tick(s).kind=='start');s.started=true;r:tick(s);victory(s);assert(r:tick(s).kind=='replay')
    s.run='r2';s.roundToken='native2';s.resultVisible=false;s.started=false;r:tick(s);r:tick(s);assert(r:tick(s).kind=='start')
end)
check('confirmed Dungeon entry cannot rearm Story combat',function()
    local r,s,c,d,refresh,level=setup({dungeonConsent=true},true);assert(r:arm(s));victory(s);r:tick(s)
    level._dungeon.depth=2;s.run='r2';s.roundToken='native2';s.resultVisible=false;s.mode='Story';refresh();r:tick(s)
    assert(r:tick(s)==nil and not r.armed and not r.auto.armed)
end)
check('pending Dungeon chest permission is checked on every observation',function()
    local r,s,c,d,refresh=setup({dungeonConsent=true,dungeonOpenChests=true},true);assert(r:arm(s));victory(s)
    d._finished=true;d._resources.treasure=1;d.current_shops={{_t=6,data={}}};refresh();assert(r:tick(s).name=='dungeon_open_chest')
    c.dungeonOpenChests=false;d._resources.treasure=0;refresh();assert(r:tick(s)==nil and not r.armed and r.confirmations==0)
end)
check('pending Dungeon shop cannot confirm after budget permission reduced',function()
    local r,s,c,d,refresh=setup({dungeonConsent=true,dungeonShopCap=30},true);assert(r:arm(s));victory(s)
    d.current_shops={{_t=1,data={{id='tome',currentCost=20}}}};refresh();assert(r:tick(s).name=='dungeon_buy_shop')
    c.dungeonShopCap=0;d._resources.money=80;d._items={{id='tome'}};d.current_shops[1].data={};refresh()
    assert(r:tick(s)==nil and not r.armed and r.confirmations==0)
end)
check('native target-priority confirmation contributes to root feedback counter',function()
    local r,s=setup({autoTarget='first'});tower(s);s.units[1].priority='last';assert(r:arm(s))
    assert(r:tick(s).kind=='priority' and r.pending==r.auto.pending)
    s.mutationFence=true;s.transportBlocked=true;s.units[1].priority='first';r:tick(s)
    assert(r.armed and r.confirmations==1 and r.auto.confirmations==1 and r.placements==0 and r.upgrades==0 and not r.pending)
end)
check('late exact Dungeon entry feedback cannot confirm after its deadline',function()
    local r,s,c,d,refresh,level=setup({dungeonConsent=true},true);assert(r:arm(s));victory(s);r:tick(s)
    s.now=22;s.run='r2';s.roundToken='native2';level._dungeon.depth=2;s.resultVisible=false;refresh()
    assert(r:tick(s)==nil and not r.armed and r.confirmations==0 and not r.auto.armed)
end)
check('manual-entry known modes run observed combat without paid-entry actions',function()
    for _,mode in {'Infinite','Challenge','Raid','Legend','Portal'} do
        local r,s=setup();s.mode=mode;assert(r:arm(s));assert(r:tick(s).kind=='place');assert(not r.route.armed and not r.route.pending)
    end
end)
check('Portal and paid modes cannot replay even with bound Story replay settings',function()
    for _,mode in {'Infinite','Challenge','Raid','Legend','Portal'} do
        local r,s,c=setup({replay=true,replayFreeConfirmed=true});s.mode=mode;c.replayContext={stage=s.stage,mode=mode,placeId=s.placeId}
        assert(r:arm(s));victory(s);assert(r:tick(s)==nil and not r.armed and r.runs==1 and not r.pending and not r.route.pending)
        r:tick(s);assert(r.runs==1)
    end
end)
check('manual-entry modes can optionally return to verified lobby after Victory',function()
    for _,mode in {'Infinite','Challenge','Raid','Legend','Portal'} do
        local r,s=setup({autoReturnLobby=true});s.mode=mode;assert(r:arm(s));victory(s);assert(r:tick(s).kind=='lobby' and r.runs==1)
        s.inMatch=false;s.observedLobby=true;r:tick(s);assert(not r.armed and r.state=='COMPLETE')
    end
end)
check('Event unknown and unverified manual modes stay unsupported',function()
    for _,mode in {'Event','Unknown','Portal'} do local r,s=setup();s.mode=mode;if mode=='Portal' then s.modeVerified=false end;assert(not r:arm(s)) end
    local r,s=setup({mode='Portal'});s.mode='Portal';s.inMatch=false;assert(not r:arm(s))
end)
check('replay waits for verified map identity during asynchronous round reset',function()
    local r,s,c=setup({replay=true,replayFreeConfirmed=true});c.replayContext={stage=s.stage,mode=s.mode,placeId=s.placeId}
    assert(r:arm(s));victory(s);assert(r:tick(s).kind=='replay')
    s.run='r2';s.roundToken='native2';s.resultVisible=false;s.stage='unknown';s.mode='Unknown';s.stageVerified=false;s.modeVerified=false
    assert(r:tick(s)==nil and r.armed and r.pending and r.confirmations==0)
    s.stage='stage1';s.mode='Story';s.stageVerified=true;s.modeVerified=true;r:tick(s);assert(r.armed and r.confirmations==1)
end)
check('opt-in known next Story emits typed expectation before replay',function()
    local r,s,c=setup({autoNextStory=true,replay=true,replayFreeConfirmed=true});c.replayContext={stage=s.stage,mode=s.mode,placeId=s.placeId}
    s.nextStoryId='stage2';assert(r:arm(s));victory(s);local a=r:tick(s)
    assert(a.kind=='next' and a.expected.kind=='next_story' and a.expected.stage=='stage2' and a.expected.mode=='Story' and a.expected.placeId==9)
    assert(r.pending.kind=='next' and r.runs==1)
    assert(r:tick(s)==nil and r.pending)
    s.stage='unknown';s.stageVerified=false;s.modeVerified=false;s.run='r2';s.roundToken='native2';s.resultVisible=false
    assert(r:tick(s)==nil and r.armed and r.pending)
    s.stage='stage2';s.stageVerified=true;s.modeVerified=true;s.mutationFence=true;s.transportBlocked=true
    assert(r:tick(s)==nil and r.armed and r.confirmations==1 and not r.pending and not r.auto.armed)
    s.mutationFence=false;s.transportBlocked=false;r:tick(s);assert(r.auto.armed and r.stage=='stage2' and r.runs==1)
end)
check('next Story requires exact known next stage and bounded confirmed runs',function()
    for _,which in {'unknown','empty','cap'} do
        local r,s=setup({autoNextStory=true,maxRuns=which=='cap' and 1 or 3});s.nextStoryId=which=='empty' and '' or which=='cap' and 'stage2' or nil
        assert(r:arm(s));victory(s);assert(r:tick(s)==nil and not r.armed and r.runs==1)
    end
end)
check('next Story rejects verified wrong new context times out and respects revoked permission',function()
    for _,which in {'wrong','timeout','revoked'} do
        local r,s,c=setup({autoNextStory=true});s.nextStoryId='stage2';assert(r:arm(s));victory(s);assert(r:tick(s).kind=='next')
        if which=='wrong' then s.run='r2';s.roundToken='native2';s.stage='stage3';s.resultVisible=false
        elseif which=='timeout' then s.now=22 else c.autoNextStory=false end
        assert(r:tick(s)==nil and not r.armed and r.confirmations==0)
    end
end)
check('next Story never emits for nonStory manual modes',function()
    for _,mode in {'Infinite','Challenge','Raid','Legend','Portal'} do
        local r,s=setup({autoNextStory=true});s.mode=mode;s.nextStoryId='stage2';assert(r:arm(s));victory(s)
        assert(r:tick(s)==nil and not r.armed and not r.pending)
    end
end)
assert(#failures==0,table.concat(failures,'\n'))
print('Native runtime tests passed: '..n)
