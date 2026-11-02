local C = require('../src/core')
local n = 0
local function check(name, fn)
    local ok, err = pcall(fn)
    assert(ok, name .. ': ' .. tostring(err))
    n += 1
    print('PASS ' .. name)
end
local function snap()
    return {now=1, run='r1', inMatch=true, started=true, stage='test', mode='Story',
        stageVerified=true, modeVerified=true, placeId=9, wave=1, cash=100, resultVisible=false,
        roster={{uuid='a',id='rukia_2',slot=1,cost=50}}, rosterAt=1,
        units={}, unitsComplete=true, enemies=0, resources={}, owned={}, ownedAt=1}
end
local function profile()
    return {stage='test',mode='Story',placeId=9,source='user-recorded',
        entries={{uuid='a',id='rukia_2',pos={1,2,3},cost=50,wave=0}}}
end
local function config()
    return {routeConfirmed=true, protocolConfirmed=true, maxRuns=1, maxSeconds=120, reserve=0,
        replay=false, upgrade=true, targetTrait='Unique',goal='Acquire',
        routeContext={stage='test',mode='Story',placeId=9},
        protocolContext={stage='test',mode='Story',placeId=9},replayContext={stage='test',mode='Story',placeId=9}}
end
check('old rare Rukia is not the secret', function()
    assert(not C.isRukia('rukia'))
    assert(C.isRukia('rukia_2') and C.isRukia('rukia_2_evo'))
end)
check('unknown resource is not zero', function()
    assert(C.deficit(nil,200)==nil and C.deficit(190,200)==10)
end)
check('target trait is protected', function()
    assert(not C.spendAllowed({enabled=true,cap=20,spent=0,cost=1,balance=10,
        current='Unique',target='Unique',fresh=true,verified=true}))
end)
check('budget cannot overshoot', function()
    assert(not C.spendAllowed({enabled=true,cap=5,spent=5,cost=1,balance=20,
        current='Nimble',target='Unique',fresh=true,verified=true}))
end)
check('no target success from rounded percentages', function()
    assert(not C.statsMet({damageGrade='SS',spaGrade='SSS',rangeGrade='SSS'}, 'SSS'))
end)
check('run readiness checks fresh exact roster', function()
    local s=snap(); s.rosterAt=-100
    assert(#C.readiness(s,profile(),config())>0)
end)
check('unrelated tower never verifies placement', function()
    local s=snap()
    s.units={{key='other',uuid='b',id='other',pos={1,2,3}}}
    assert(not C.placementVerified({uuid='a',id='rukia_2',pos={1,2,3},before={}},s.units))
end)
check('existing tower never verifies a new placement', function()
    local u={key='old',uuid='a',id='rukia_2',pos={1,2,3}}
    assert(not C.placementVerified({uuid='a',id='rukia_2',pos={1,2,3},before={old=true}},{u}))
end)
check('exact new identity and position verifies', function()
    assert(C.placementVerified({uuid='a',id='rukia_2',pos={1,2,3},before={}},
        {{key='new',uuid='a',id='rukia_2',pos={1,2,3}}}))
end)
check('ambiguous result remains unknown', function()
    assert(C.outcome({'Victory','Defeat'})=='unknown')
    assert(C.outcome({'Victory'})=='Victory')
    assert(C.outcome({'Total Damage','Rewards'})=='unknown')
end)
check('no money means no command', function()
    local e=C.engine(config());local s=snap()
    assert(e:arm(s,profile()))
    s.cash=nil
    assert(e:tick(s,profile())==nil and e.state=='BLOCKED')
end)
check('single pending placement, then timeout stops', function()
    local e=C.engine(config());local s=snap();local p=profile()
    assert(e:arm(s,p));assert(e:tick(s,p).kind=='place')
    s.now=2;assert(e:tick(s,p)==nil)
    s.now=12;assert(e:tick(s,p)==nil and not e.armed and e.state=='BLOCKED')
end)
check('confirmed acquisition stops grinding', function()
    local e=C.engine(config());local s=snap();local p=profile()
    assert(e:arm(s,p));s.owned={{id='rukia_2',uuid='owned',statScope='collection'}}
    assert(e:tick(s,p)==nil and e.state=='GOAL_MET')
end)
check('unknown result is not a completed victory', function()
    local e=C.engine(config());local s=snap();local p=profile()
    assert(e:arm(s,p));s.resultVisible=true;s.outcome='unknown'
    e:tick(s,p);assert(e.wins==0 and e.losses==0 and not e.armed)
end)
check('Dungeon replay never emits', function()
    local cfg=config();cfg.replay=true;cfg.replayFreeConfirmed=true;cfg.maxRuns=4
    local e=C.engine(cfg);local s=snap();local p=profile()
    s.mode='Dungeon';p.mode='Dungeon'
    C.bindConsent(cfg,'routeConfirmed',s);C.bindConsent(cfg,'protocolConfirmed',s);C.bindConsent(cfg,'replayFreeConfirmed',s)
    assert(e:arm(s,p));s.resultVisible=true;s.outcome='Victory'
    assert(e:tick(s,p)==nil and not e.armed)
end)
check('run change invalidates a pending command', function()
    local e=C.engine(config());local s=snap();local p=profile()
    assert(e:arm(s,p));e:tick(s,p);s.run='r2';s.now=2
    assert(e:tick(s,p)==nil and not e.armed)
end)
check('logger remains bounded and counts dropped lines', function()
    local log=C.logger(10)
    for i=1,100 do log:add('test',tostring(i)) end
    assert(#log.lines==10 and log.dropped==90)
end)
check('historical recipe stays explicitly unverified',function()
    assert(C.recipe.status=='historical' and C.recipe.items.SacredTreasure==200)
end)
check('battle stats cannot prove optimized base stats',function()
    assert(not C.statsMet({damage=100,spa=2,range=30,damageGrade='SSS',spaGrade='SSS',rangeGrade='SSS',statScope='battle'},'SSS'))
end)
check('persisted permission and mode values are sanitized',function()
    local cfg=C.sanitize({maxRuns=math.huge,maxSeconds=-20,traitCap=5,routeConfirmed=true,
        protocolConfirmed=true,replayFreeConfirmed=true,mode='made-up',cashPath='player/yen'})
    assert(cfg.maxRuns==1 and cfg.maxSeconds==30 and cfg.mode=='Dungeon')
    assert(not cfg.protocolConfirmed and not cfg.routeConfirmed and not cfg.replayFreeConfirmed)
    assert(cfg.cashPath=='player/yen')
end)
check('unverified selected mode cannot authorize free replay',function()
    local cfg=config();cfg.replay=true;cfg.replayFreeConfirmed=true;cfg.maxRuns=4
    local e=C.engine(cfg);local s=snap();local p=profile();s.modeVerified=false
    assert(e:arm(s,p));s.resultVisible=true;s.outcome='Victory'
    assert(e:tick(s,p)==nil and not e.armed)
end)
check('upgrade waits for exact level feedback',function()
    local e=C.engine(config());local s=snap();local p=profile()
    s.units={{key='x',uuid='a',id='rukia_2',pos={1,2,3},level=0,nextCost=50,damage=100,spa=5}}
    assert(e:arm(s,p));e:tick(s,p)
    local request=e:tick(s,p);assert(request and request.kind=='upgrade')
    s.now=2;e:tick(s,p);assert(e.upgrades==0)
    s.units[1].level=1;s.now=3;e:tick(s,p);assert(e.upgrades==1)
end)
check('max runs stops a free confirmed win without a replay request',function()
    local cfg=config();cfg.replay=true;cfg.replayFreeConfirmed=true
    local e=C.engine(cfg);local s=snap();local p=profile()
    assert(e:arm(s,p));s.resultVisible=true;s.outcome='Victory'
    assert(e:tick(s,p)==nil and e.wins==1 and not e.armed)
end)
check('free replay requires a real run transition',function()
    local cfg=config();cfg.replay=true;cfg.replayFreeConfirmed=true;cfg.maxRuns=2
    local e=C.engine(cfg);local s=snap();local p=profile()
    assert(e:arm(s,p));s.resultVisible=true;s.outcome='Victory'
    assert(e:tick(s,p).kind=='replay');s.now=18
    assert(e:tick(s,p)==nil and not e.armed)
end)
check('replay waits for asynchronous map identity before continuing',function()
    local cfg=config();cfg.replay=true;cfg.replayFreeConfirmed=true;cfg.maxRuns=2
    local e=C.engine(cfg);local s=snap();local p=profile()
    assert(e:arm(s,p));s.resultVisible=true;s.outcome='Victory';e:tick(s,p)
    s.now=2;s.run='r2';s.resultVisible=false;s.stageVerified=false;s.stage='unknown'
    assert(e:tick(s,p)==nil and e.armed)
    s.now=3;s.stageVerified=true;s.stage='test'
    local command=e:tick(s,p);assert(e.armed and command and command.kind=='place')
end)
check('replay blocks a different newly observed stage',function()
    local cfg=config();cfg.replay=true;cfg.replayFreeConfirmed=true;cfg.maxRuns=2
    local e=C.engine(cfg);local s=snap();local p=profile()
    assert(e:arm(s,p));s.resultVisible=true;s.outcome='Victory';e:tick(s,p)
    s.now=2;s.run='r2';s.resultVisible=false;s.stage='other'
    assert(e:tick(s,p)==nil and not e.armed)
end)
check('passive recorder counts one result despite a visible-label flicker',function()
    local r=C.recorder(C.logger());local s=snap()
    s.resultVisible=true;s.outcome='Victory';r:observe(s)
    s.outcome='unknown';r:observe(s);s.outcome='Victory';r:observe(s)
    assert(r.wins==1 and r.losses==0)
end)
check('passive recorder reports material deltas without assuming drops',function()
    local log=C.logger();local r=C.recorder(log);local s=snap()
    s.resources={SacredTreasure=1};r:observe(s)
    s.resources={SacredTreasure=3};r:observe(s)
    assert(log:text():find('RESOURCE DELTA',1,true))
end)
check('truncated tower observation blocks all mutation',function()
    local s=snap();s.unitsComplete=false
    assert(#C.readiness(s,profile(),config())>0)
end)
check('selected unit disappearance cannot complete another copy goal',function()
    local s=snap();s.owned={{uuid='other',id='rukia_2',trait='Unique'}}
    local cfg=config();cfg.goal='Trait';cfg.selectedUuid='chosen'
    assert(not C.goalMet(s,cfg))
end)
check('route and spending consent belong to the observed stage',function()
    local s=snap();local cfg=config()
    cfg.routeContext={stage='other',mode='Story',placeId=9}
    assert(#C.readiness(s,profile(),cfg)>0)
end)
check('chosen identity is preserved but consents are not restored',function()
    local cfg=C.sanitize({selectedUuid='chosen',routeContext={stage='test',mode='Story',placeId=9}})
    assert(cfg.selectedUuid=='chosen' and cfg.routeContext==nil)
end)
check('a target among two observed traits satisfies the trait goal',function()
    local s=snap();s.owned={{uuid='a',id='rukia_2',trait='Unique + Nimble',traits={'Unique','Nimble'},statScope='collection'}}
    local cfg=config();cfg.goal='Trait'
    assert(C.goalMet(s,cfg))
end)
check('spending guard protects an achieved target among multiple traits',function()
    assert(not C.spendAllowed({enabled=true,cap=5,spent=0,cost=1,balance=5,fresh=true,verified=true,
        target='Unique',current='Unique + Nimble',currentTraits={'Unique','Nimble'}}))
end)
check('a placed event tower cannot prove permanent Rukia acquisition',function()
    local s=snap();s.owned={{uuid='borrowed',id='rukia_2',statScope='battle'}}
    assert(not C.goalMet(s,config()))
end)
check('recorded costs stop when the current cost modifier disappears or changes',function()
    local s=snap();local p=profile();p.costScale=1.5;s.costScale=1.5
    assert(#C.readiness(s,p,config())==0)
    s.costScale=2;assert(#C.readiness(s,p,config())>0)
    s.costScale=nil;assert(#C.readiness(s,p,config())>0)
end)
check('current equipped deployment price invalidates a different recorded price',function()
    local s=snap();local p=profile();s.roster[1].cost=p.entries[1].cost+1
    assert(#C.readiness(s,p,config())>0)
end)
check('manually verified fallback prices survive settings reload',function()
    assert(C.sanitize({recordCosts='100,,300'}).recordCosts=='100,,300')
end)
check('ambiguous new placement models cannot verify a placement',function()
    local match,ambiguous=C.placementVerified({uuid='a',id='rukia_2',pos={1,2,3},before={}},
        {{key='new1',uuid='a',id='rukia_2',pos={1,2,3}},
        {key='new2',uuid='a',id='rukia_2',pos={2,2,3}}})
    assert(not match and ambiguous)
end)
check('ambiguous placement feedback stops recorded combat immediately',function()
    local e=C.engine(config());local s=snap();local p=profile()
    assert(e:arm(s,p));assert(e:tick(s,p).kind=='place')
    s.now=2;s.units={{key='new1',uuid='a',id='rukia_2',pos={1,2,3}},
        {key='new2',uuid='a',id='rukia_2',pos={2,2,3}}}
    e:tick(s,p);assert(not e.armed and e.placements==0)
end)
check('test target slot is preserved and bounded in settings',function()
    assert(C.sanitize({trialSlot=4}).trialSlot==4)
    assert(C.sanitize({trialSlot=0}).trialSlot==1)
    assert(C.sanitize({trialSlot=100}).trialSlot==8)
end)
print('All '..n..' tests passed')
