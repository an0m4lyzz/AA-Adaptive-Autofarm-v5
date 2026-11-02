local C=require('../src/core')
local makeTeam=require('../src/team')
local n=0
local function check(name,fn)
    local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));n+=1;print('PASS '..name)
end
local function setup()
    local cfg=C.sanitize({})
    local s={now=1,run='r1',inMatch=true,started=true,stage='namek_level_1',stageVerified=true,
        mode='Story',modeVerified=true,placeId=9,wave=1,cash=900,rosterAt=1,
        units={},unitsComplete=true,costScale=1,resultVisible=false,roster={},rosterComplete=true,roundToken={}}
    local p={kind='team-v1',source='user-recorded',stage=s.stage,mode=s.mode,placeId=s.placeId,costScale=1,entries={}}
    local ids={'nagumo_evolved','sasuke_3_evolved','hoshino_2_evolved','bulma','feitan_evolved','speedwagon'}
    local prices={1300,1300,1000,800,1300,550};local roles={'combat','combat','buff','farm','combat','farm'}
    for i=1,6 do
        s.roster[i]={uuid='u'..i,id=ids[i],slot=i,cost=prices[i],role=roles[i]}
        p.entries[i]={uuid='u'..i,id=ids[i],slot=i,cost=prices[i],role=roles[i],pos={i*10,2,10},wave=0}
    end
    return makeTeam(C,cfg,C.logger()),s,p,cfg
end
local function placed(s,p,i,level,nextCost)
    local e=p.entries[i]
    local u={uuid=e.uuid,id=e.id,key='model'..i,pos=table.clone(e.pos),level=level or 0,nextCost=nextCost,maxLevel=3}
    s.units[#s.units+1]=u;return u
end
check('team readiness requires every current equipped slot without faking Rukia consent',function()
    local t,s,p,cfg=setup();assert(#t:readiness(s,p)==0 and #C.readiness(s,p,cfg)>0)
    table.remove(p.entries,6);assert(#t:readiness(s,p)>0)
end)
check('Story-only observed context and fresh complete data are required',function()
    local t,s,p=setup();s.modeVerified=false;assert(not t:arm(s,p))
    s.modeVerified=true;s.mode='Dungeon';p.mode='Dungeon';assert(not t:arm(s,p))
    s.mode='Story';p.mode='Story';s.unitsComplete=false;assert(not t:arm(s,p))
end)
check('changed roster identity and prices invalidate a saved team',function()
    local t,s,p=setup();s.roster[1].uuid='changed';assert(not t:arm(s,p))
    s.roster[1].uuid='u1';s.roster[1].cost=1400;assert(not t:arm(s,p))
end)
check('balanced opening places one affordable farm while saving for combat',function()
    local t,s,p=setup();assert(t:arm(s,p))
    local a=t:tick(s,p);assert(a and a.kind=='place' and a.id=='speedwagon')
    assert(t:tick(s,p)==nil)
    s.now=2;s.cash=350;placed(s,p,6,0,500);t:tick(s,p)
    s.now=4;s.rosterAt=4;s.cash=850;assert(t:tick(s,p)==nil)
    s.now=5;s.cash=1400;assert(t:tick(s,p).id=='nagumo_evolved')
end)
check('an affordable combat unit is preferred over additional opening farms',function()
    local t,s,p=setup();s.cash=1500;assert(t:arm(s,p))
    assert(t:tick(s,p).id=='nagumo_evolved')
end)
check('existing placements are matched without counting automated actions',function()
    local t,s,p=setup();for i=1,6 do placed(s,p,i,3,nil) end
    assert(t:arm(s,p));assert(t:tick(s,p)==nil and t.placements==0 and t.upgrades==0)
end)
check('all missing recorded placements are filled before upgrades',function()
    local t,s,p=setup();s.cash=10000;placed(s,p,1,0,100)
    assert(t:arm(s,p));local a=t:tick(s,p)
    assert(a and a.kind=='place')
end)
check('upgrade selection uses lowest level then cheapest affordable price',function()
    local t,s,p=setup();s.cash=5000
    for i=1,6 do placed(s,p,i,0,1000+i*100) end
    s.units[1].level=1;s.units[2].nextCost=600
    assert(t:arm(s,p));local a=t:tick(s,p)
    assert(a and a.kind=='upgrade' and a.key=='model2')
end)
check('Yen reserve blocks an otherwise affordable action',function()
    local t,s,p,cfg=setup();cfg.reserve=500;assert(t:arm(s,p))
    assert(t:tick(s,p)==nil and not t.pending)
end)
check('only one exact new placement can confirm the pending action',function()
    local t,s,p=setup();assert(t:arm(s,p));t:tick(s,p)
    s.now=2;placed(s,p,6,0,500);t:tick(s,p)
    assert(t.placements==1 and not t.pending)
end)
check('an unrelated tower cannot confirm placement and no retry occurs',function()
    local t,s,p=setup();assert(t:arm(s,p));t:tick(s,p)
    s.now=2;placed(s,p,4,0,1500);assert(t:tick(s,p)==nil and t.pending)
    s.now=10;t:tick(s,p);assert(not t.armed and t.placements==0)
end)
check('a late matching model does not confirm after the deadline',function()
    local t,s,p=setup();assert(t:arm(s,p));t:tick(s,p)
    s.now=10;placed(s,p,6,0,500);t:tick(s,p);assert(t.placements==0 and not t.armed)
end)
check('ambiguous matching models stop instead of counting success',function()
    local t,s,p=setup();assert(t:arm(s,p));t:tick(s,p)
    s.now=2;placed(s,p,6,0,500);local extra=table.clone(s.units[1]);extra.key='other';s.units[2]=extra
    t:tick(s,p);assert(not t.armed and t.placements==0)
end)
check('one model cannot satisfy two nearby recorded targets',function()
    local t,s,p=setup();local copy=table.clone(p.entries[1]);copy.pos={11,2,10};p.entries[7]=copy
    placed(s,p,1,0,500);assert(not t:arm(s,p))
end)
check('unexpected upgrade jumps stop without confirming a chain',function()
    local t,s,p=setup();s.cash=10000
    for i=1,6 do placed(s,p,i,0,500) end
    assert(t:arm(s,p));local a=t:tick(s,p)
    s.now=2;for _,u in ipairs(s.units) do if u.key==a.key then u.level=2 end end
    t:tick(s,p);assert(not t.armed and t.upgrades==0)
end)
check('stopping with an unresolved action prevents same-run rearming',function()
    local t,s,p=setup();assert(t:arm(s,p));t:tick(s,p);t:stop('user stop')
    assert(not t:arm(s,p));s.run='r2';assert(t:arm(s,p))
end)
check('missing upgrade data is not reported as maximum',function()
    local t,s,p=setup()
    for i=1,6 do local u=placed(s,p,i,0,nil);u.maxLevel=nil end
    assert(t:arm(s,p));assert(t:tick(s,p)==nil and t.armed)
    s.now=18;s.rosterAt=18;t:tick(s,p);assert(not t.armed and t.upgrades==0)
end)
check('duration limit ends a session',function()
    local t,s,p,cfg=setup();cfg.maxSeconds=30;assert(t:arm(s,p))
    s.now=32;s.rosterAt=32;t:tick(s,p);assert(not t.armed)
end)
check('unknown outcomes never count as a win or trigger replay',function()
    local t,s,p=setup();assert(t:arm(s,p));s.resultVisible=true;s.outcome='unknown'
    assert(t:tick(s,p)==nil and not t.armed and t.wins==0)
end)
check('replay is disabled by default even after an observed victory',function()
    local t,s,p=setup();assert(t:arm(s,p));s.resultVisible=true;s.outcome='Victory'
    assert(t:tick(s,p)==nil and not t.armed and t.wins==1)
end)
check('scoped opt-in replay obeys the run cap and waits for a reset',function()
    local t,s,p,cfg=setup();cfg.replay=true;cfg.maxRuns=2;cfg.replayFreeConfirmed=true
    C.bindConsent(cfg,'replayFreeConfirmed',s);assert(t:arm(s,p))
    s.resultVisible=true;s.outcome='Victory';assert(t:tick(s,p).kind=='replay')
    assert(t:tick(s,p)==nil)
    s.run='r2';s.roundToken={};s.now=2;s.resultVisible=false;s.stageVerified=false;assert(t:tick(s,p)==nil)
    s.now=3;s.stageVerified=true;assert(t:tick(s,p).kind=='place')
end)
check('finish during an unresolved action never overlaps it with replay',function()
    local t,s,p,cfg=setup();cfg.replay=true;cfg.maxRuns=2;cfg.replayFreeConfirmed=true
    C.bindConsent(cfg,'replayFreeConfirmed',s);assert(t:arm(s,p));t:tick(s,p)
    s.resultVisible=true;s.outcome='Victory';s.transportBlocked=true
    assert(t:tick(s,p)==nil and not t.armed)
end)
check('replay cannot continue into a different stage',function()
    local t,s,p,cfg=setup();cfg.replay=true;cfg.maxRuns=2;cfg.replayFreeConfirmed=true
    C.bindConsent(cfg,'replayFreeConfirmed',s);assert(t:arm(s,p));s.resultVisible=true;s.outcome='Victory';t:tick(s,p)
    s.run='r2';s.roundToken={};s.now=2;s.stage='other';s.resultVisible=false
    assert(t:tick(s,p)==nil and not t.armed)
end)
check('unknown current placement prices block Team Auto',function()
    local t,s,p=setup();s.roster[1].cost=nil;assert(not t:arm(s,p))
end)
check('unlocated current recorded towers block a new placement session',function()
    local t,s,p=setup();local u=placed(s,p,1,0,500);u.pos=nil
    assert(not t:arm(s,p))
end)
check('fractional upgrade levels are unsupported rather than actionable',function()
    local t,s,p=setup();s.cash=10000
    for i=1,6 do placed(s,p,i,0.5,500) end
    assert(t:arm(s,p));assert(t:tick(s,p)==nil and not t.pending)
end)
check('malformed saved target arrays cannot crash team status or arm it',function()
    local t,s,p=setup();p.entries=42
    assert(type(t:text(s,p))=='string' and not t:arm(s,p))
end)
check('a partial parsed roster cannot arm as if all equipment was observed',function()
    local t,s,p=setup();s.roster={s.roster[1]};p.entries={p.entries[1]};s.rosterComplete=false
    assert(not t:arm(s,p))
end)
check('replay waits for old visible results to clear without recounting them',function()
    local t,s,p,cfg=setup();cfg.replay=true;cfg.maxRuns=3;cfg.replayFreeConfirmed=true
    C.bindConsent(cfg,'replayFreeConfirmed',s);assert(t:arm(s,p));s.resultVisible=true;s.outcome='Victory';t:tick(s,p)
    s.run='r2';s.roundToken={};s.now=2
    assert(t:tick(s,p)==nil and t.wins==1 and t.armed and t.pending.kind=='replay')
    s.outcome='unknown';assert(t:tick(s,p)==nil and t.armed and t.wins==1)
    s.resultVisible=false;s.now=3;assert(t:tick(s,p).kind=='place')
end)
check('a local run-counter change alone cannot release a replay into the same round',function()
    local t,s,p,cfg=setup();cfg.replay=true;cfg.maxRuns=2;cfg.replayFreeConfirmed=true
    C.bindConsent(cfg,'replayFreeConfirmed',s);assert(t:arm(s,p));s.resultVisible=true;s.outcome='Victory';t:tick(s,p)
    s.run='r2';s.resultVisible=false;s.now=2
    assert(t:tick(s,p)==nil and t.pending.kind=='replay')
    s.roundToken={};s.now=3;assert(t:tick(s,p).kind=='place')
end)
print('All '..n..' team tests passed')
