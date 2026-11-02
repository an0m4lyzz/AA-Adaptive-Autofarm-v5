local C=require('./core')
local makeAdapter=require('./roblox')
local makeUI=require('./ui')
local makeTrial=require('./trial')
local makeTeam=require('./team')
local makeAuto=require('./autoplay')
local makeDungeon=require('./dungeon')
local makeNavigation=require('./navigation')
local makeSession=require('./session')
local makeRuntime=require('./runtime')
local env=(type(getgenv)=='function' and getgenv()) or _G
local deadline=os.clock()+30
while not game:IsLoaded() and os.clock()<deadline do task.wait(.1) end
if not game:IsLoaded() then warn('[K] AA: game load timeout');return end
local LP=game:GetService('Players').LocalPlayer
if not LP then warn('[K] AA: local player unavailable');return end
for _,key in ipairs({'K_AA_V2','K_AA_V3','K_AA_V4','K_AA_V5','K_AA_RUKIA_V6'}) do
    local old=env[key]
    if type(old)=='table' and type(old.stop)=='function' then
        local following=C.teleportReplacement(old,env.K_AA_Rukia_v6_FollowTicket,LP.UserId,game.GameId,game.JobId)
        pcall(function() old.stop(following and 'teleport-replace' or nil) end)
    end
end
local HTTP=game:GetService('HttpService')
local filename='K_AA_Rukia_v6_'..LP.UserId..'.json'
local reportFile='K_AA_Rukia_v6_Report_'..LP.UserId..'.txt'
local markerFile='K_AA_Rukia_v6_Session_'..LP.UserId..'.json'
local followFile='K_AA_Rukia_v6_Follow_'..LP.UserId..'.json'
local function readJSON(name)
    if type(readfile)~='function' then return nil end
    local ok,raw=pcall(readfile,name)
    if not ok or type(raw)~='string' or #raw>262144 then return nil end
    local valid,data=pcall(function() return HTTP:JSONDecode(raw) end)
    return valid and type(data)=='table' and data or nil
end
local function writeJSONVerified(name,value)
    if type(writefile)~='function' or type(readfile)~='function' then return false end
    return pcall(function()
        local raw=HTTP:JSONEncode(value)
        writefile(name,raw)
        assert(readfile(name)==raw,'Local write could not be verified')
    end)
end
local saved=readJSON(filename) or {}
local cfg=C.sanitize(saved.cfg)
local log=C.logger(240)
local app={alive=true,cfg=cfg,log=log,instanceJob=game.JobId,profile=type(saved.profile)=='table' and saved.profile or nil,
    trialProfile=type(saved.trialProfile)=='table' and saved.trialProfile or nil,
    teamProfile=type(saved.teamProfile)=='table' and saved.teamProfile or nil,
    status='Observer only; live compatibility unverified',diskSaved=false,observedWins=0,observedLosses=0,
    reportRun=nil,reportOutcome=nil,lastWave=-1,lastRoster='',lastRefresh=0,lastCheckpoint=0}
app.engine=C.engine(cfg,log)
app.trial=makeTrial(C,cfg,log);app.trialQuotes={}
app.team=makeTeam(C,cfg,log)
app.recorder=C.recorder(log)
app.adapter=makeAdapter(C,env,cfg,log)
app.native=makeRuntime(C,makeAuto,makeDungeon,cfg,log)
app.navigation=makeNavigation(C,game:GetService('Workspace'),game:GetService('ReplicatedStorage'),log)
app.session=makeSession(C,{
    read=function() return readJSON(followFile) end,
    write=function(value) return writeJSONVerified(followFile,value) end,
    queue=function(code)
        local q=queue_on_teleport or (type(syn)=='table' and syn.queue_on_teleport)
        if type(q)~='function' then return false end
        local ok=pcall(q,code);return ok
    end,
},env,{userId=LP.UserId,universeId=game.GameId,jobId=game.JobId},os.time)
app.followMarker,app.resumeCandidate=app.session:load()
cfg.autoFollow=app.session.following
app.resumeEarliest=os.clock()+10;app.resumeDeadline=os.clock()+40;app.resumePlans=0
local function fmt(x) return x==nil and '?' or tostring(x) end
function app:notice(message)
    self.status=tostring(message):sub(1,400);self.log:add('STATUS',self.status)
end
function app:error(err)
    self:stopNative('Runtime error; native automation stopped')
    self.engine:stop('Runtime error; automation stopped')
    self.trial:cancel('Runtime error; single-action result unconfirmed')
    self:stopTeam('Runtime error; Team stopped')
    self:notice(tostring(err):sub(1,300))
end
function app:unit() return C.chooseRukia((self.snapshot or {}).owned,self.cfg.selectedUuid) end
function app:ownershipText()
    local u=self:unit()
    if not u then return 'RUKIA OWNERSHIP: UNKNOWN\nThe exposed inventory scan does not prove absence.' end
    if u.statScope~='collection' then return 'RUKIA SEEN IN MATCH\nPermanent collection ownership remains unknown.' end
    return 'OWNED OBSERVED: '..(u.id=='rukia_2_evo' and 'Snow Reaper (Final)' or 'Snow Reaper (War)')..
        '\nData: '..fmt(u.statScope)..' | level/upgrade='..fmt(u.level)
end
function app:objectiveText()
    if not self.snapshot then return 'Waiting for observation' end
    local title,detail=C.plan(self.snapshot,self.cfg)
    return title..'\n'..detail..'\nStop goal: '..self.cfg.goal
end
function app:walletText()
    local s=self.snapshot or {};local w=s.wallet or {}
    return 'Observed account balances\nGold: '..fmt(w.Gold)..' | Gems: '..fmt(w.Gems)..
        '\nSummerPearls: '..fmt(w.SummerPearls)..
        '\nMatch cash: '..fmt(s.cash)..' | source: '..fmt(s.cashSource)
end
function app:traitText()
    local u=self:unit();local r=(self.snapshot or {}).resources or {}
    return 'Current trait: '..fmt(u and u.trait)..'\nReroll Tokens: '..fmt(r.RerollToken)..
        ' | Star Remnants: '..fmt(r.StarRemnant)..'\nHistorical Unique rate: 0.1%, not a guarantee. Current odds/cost unverified.'
end
function app:statsText()
    local u=self:unit() or {}
    local potential={}
    for _,key in ipairs({'stat_damage','stat_attack_cooldown','stat_range'}) do
        if type(u.potential)=='table' and u.potential[key]~=nil then
            potential[#potential+1]=key..'='..fmt(u.potential[key])
        end
    end
    return 'DMG '..fmt(u.damage)..' ['..fmt(u.damageGrade)..']\nSPA '..fmt(u.spa)..' ['..fmt(u.spaGrade)..
        ']\nRANGE '..fmt(u.range)..' ['..fmt(u.rangeGrade)..']\nScope: '..fmt(u.statScope)..
        '\nWorthiness: '..fmt(u.worthiness)..' | Stat Cubes: '..fmt(((self.snapshot or {}).resources or {}).StatCube)..
        (#potential>0 and '\nUnclassified potential fields: '..table.concat(potential,', ') or '')
end
function app:evolutionText()
    local s=self.snapshot or {};local r=s.resources or {};local u=self:unit()
    local out={'Snow Reaper (War) → Final','Not revalidated after Update 21.'}
    for _,k in ipairs(C.itemOrder) do
        local need=C.recipe.items[k];local left=C.deficit(r[k],need)
        out[#out+1]=C.itemLabels[k]..': '..fmt(r[k])..' / '..need..' | missing '..fmt(left)
    end
    out[#out+1]='Takedowns: '..fmt(u and u.takedowns)..' / 7500 (historical)'
    out[#out+1]='These are Star Fruits; they are not a confirmed new star-up system.'
    return table.concat(out,'\n')
end
function app:farmText()
    local s=self.snapshot or {}
    return 'Context: '..fmt(s.context)..'\nStage: '..fmt(s.stageName)..' / '..fmt(s.stage)..'\nSource: '..fmt(s.stageSource)..
        '\nMode: '..fmt(s.mode)..(s.modeVerified and ' (observed)' or ' (user-selected; unverified)')..
        '\nWave '..fmt(s.wave)..' | Yen '..fmt(s.cash)..'\nEquipped '..#(s.roster or {})..
        ' | own towers '..#(s.units or {})..' | path samples '..fmt(s.pathSamples)..
        '\nProfile: '..(self.profile and fmt(self.profile.stage) or 'none')..
        '\nEngine: '..self.engine.state..'\n'..self.engine.reason
end
function app:reportStatus()
    return 'Observed wins '..self.observedWins..' | losses '..self.observedLosses..
        '\nRukia-route placements '..self.engine.placements..' | upgrades '..self.engine.upgrades..
        '\nTeam placements '..self.team.placements..' | upgrades '..self.team.upgrades..
        '\nSaved report: '..tostring(self.diskSaved)..' | retained log lines '..#self.log.lines..
        '\nStage, reward schemas and Android stability require live testing.'
end
function app:smartText()
    local s=self.snapshot or {};local d=s.dungeon or {}
    return 'SMART AUTO '..C.version..' • EXPERIMENTAL\n'..self.native:text(s)..
        '\n'..self.session:text()..'\nDungeon depth='..fmt(d.depth)..' | coins='..fmt(d.money)..
        ' | normal chests='..fmt(d.normalChests)..' rare='..fmt(d.rareChests)..
        '\nNew Dungeon keys: MANUAL ONLY | current-run shop cap='..cfg.dungeonShopCap..
        '\nMap planner: '..fmt(self.planStatus)
end
function app:stopNative(reason)
    self.planEpoch=(self.planEpoch or 0)+1
    local unresolved=self.native.pending~=nil or self.adapter:mutationFenced()
    self.native:stop(reason or 'Stopped by user','IDLE');cfg.dungeonConsent=false
    self.resumeCandidate=false;self.nativeDeadline=nil
    self.adapter:stopResultWatch()
    if self.session.following then
        local ok,why=self.session:checkpoint({armed=false,inFlight=unresolved,mode=''})
        if not ok then self:notice('Follow cancellation failed: '..tostring(why)) end
    end
end
function app:toggleFollow()
    self:stopNative('Teleport following changed')
    local ok,why=self.session:follow(not self.session.following)
    cfg.autoFollow=self.session.following
    self:notice(ok and self.session:text() or tostring(why))
end
function app:prepareNative(s)
    if not s.inMatch or s.resultVisible then return s end
    if not s.stageVerified or not s.modeVerified then return nil,'Current stage/mode not observed' end
    local signature={}
    for _,u in ipairs(s.roster or {}) do signature[#signature+1]=tostring(u.uuid)..':'..tostring(u.id) end
    signature=table.concat(signature,'|')
    if self.planRound~=s.roundToken or self.planCount~=#s.units or self.planRoster~=signature
        or not self.planUntil or os.clock()>=self.planUntil then
        local epoch=self.planEpoch or 0
        local spots,why=self.navigation:plan(s,self.adapter.definitions,cfg)
        local fresh=self.adapter:observe(os.clock())
        if not self.alive or epoch~=(self.planEpoch or 0) or fresh.roundToken~=s.roundToken
            or fresh.run~=s.run or fresh.stage~=s.stage or fresh.mode~=s.mode or fresh.unitsComplete~=true
            or #fresh.units~=#s.units then return nil,'Map observation changed during planning; refresh first' end
        if not spots then self.planStatus=why;return nil,why end
        self.planRound=s.roundToken;self.planCount=#s.units;self.planRoster=signature
        self.planUntil=os.clock()+5;self.planSpots=spots;self.planStatus='Observed native lanes + supported terrain'
        s=fresh
    end
    s.autoSpots=self.planSpots;return s
end
function app:readSmartData()
    self:readClientCache('smart')
end
function app:applyClearFirst()
    self:stopNative('Clear-first profile applied');self:stopTeam('Clear-first profile applied')
    self.engine:stop('Clear-first profile applied','IDLE');self.trial:cancel('Clear-first profile applied')
    cfg.autoMethod='RoundRobin';cfg.autoUpgradeMethod='LowestLevel';cfg.autoTarget='first'
    cfg.upgrade=true;cfg.autoStartWaves=true;cfg.autoReturnLobby=false
    cfg.dungeonPreset='Safe';cfg.dungeonShopCap=0;cfg.dungeonOpenChests=false
    cfg.replay=false;cfg.replayFreeConfirmed=false;cfg.autoNextStory=false;cfg.maxRuns=1
    cfg.autoDistance=50;cfg.autoGround=60;cfg.autoHill=80
    self.planUntil=nil
    local savedOK=self:saveSettings()
    self:notice('Clear-first setup applied'..(savedOK and ' and saved' or ' for this session; saving failed')..
        '. Follow, shop spending and final chests need separate permission.')
end
function app:toggleNative()
    if self.native.armed then self:stopNative('Stopped by user');self:notice('Smart Auto stopped');return end
    self:stopTeam('Smart Auto requested');self.engine:stop('Smart Auto requested','IDLE')
    self.trial:cancel('Smart Auto requested')
    self.snapshot=self.adapter:observe(os.clock())
    if self.engine.uncertainRun==self.snapshot.run or self.team.uncertainRun==self.snapshot.run
        or (self.trial.state=='UNCONFIRMED' and self.trial.attemptRun==self.snapshot.run) then
        self:notice('Earlier action unconfirmed; enter a fresh match before Smart Auto');return
    end
    local s,why=self:prepareNative(self.snapshot)
    if not s then self:notice(why);return end
    self.snapshot=s
    cfg.dungeonConsent=s.mode=='Dungeon' or (not s.inMatch and s.dungeon and s.dungeon.valid and s.dungeon.started)
    if self.native:arm(s) then
        self.nativeDeadline=os.time()+cfg.maxSeconds
        local permission=self.session.following and readJSON(followFile)
        if type(permission)=='table' and C.finite(permission.expires) then self.nativeDeadline=math.min(self.nativeDeadline,permission.expires) end
        self.native.startedAt=s.now-(cfg.maxSeconds-(self.nativeDeadline-os.time()))
        self:saveSettings();self.adapter:watchResults()
        self:notice('Experimental Smart Auto armed; supervise this run')
    else cfg.dungeonConsent=false;self:notice(self.native.reason) end
end
function app:checkpointNative(action)
    if not self.session.following then return true end
    local expected
    if action and (action.kind=='replay' or action.kind=='next') then expected=action.expected
    elseif action and action.kind=='dungeon' and action.name=='dungeon_enter_room' then
        expected={kind='dungeon_enter_room',mode='Dungeon',depth=action.expected.depth,choice=action.expected.choice}
    end
    return self.session:checkpoint({armed=expected~=nil,inFlight=action~=nil and expected==nil,expected=expected,
        mode=self.native.mode or '',deadline=self.nativeDeadline,
        checkpoint={spent=self.native.route.spent,shopCap=cfg.dungeonShopCap,runs=self.native.runs,
            remainingRuns=math.max(0,cfg.maxRuns-self.native.runs),openChests=cfg.dungeonOpenChests,
            replayFree=cfg.replayFreeConfirmed,startWaves=cfg.autoStartWaves,nextStory=cfg.autoNextStory}})
end
function app:resumeNative(s)
    if not self.resumeCandidate then return end
    if os.clock()>self.resumeDeadline then
        self:stopNative('Teleport continuation readiness timed out');self:notice('UI restored; auto resume could not verify the new round');return
    end
    if os.clock()<self.resumeEarliest then return end
    if not self.resumeRead then self.resumeRead=true;self.adapter:startClientCache(true);return end
    if not self.adapter.cacheDone or not s.stageVerified or not s.modeVerified or s.rosterComplete~=true then return end
    if self.resumeNext and os.clock()<self.resumeNext then return end
    self.resumePlans+=1;self.resumeNext=os.clock()+4
    local ready,why=self:prepareNative(s)
    if not ready then
        if self.resumePlans>=3 then self:stopNative('Resume map unsupported: '..tostring(why)) end
        return
    end
    local marker=self.followMarker;local allowed,reason=self.session:validateResume(ready)
    if not allowed then self.planStatus='Resume: '..tostring(reason);return end
    self.resumeCandidate=false
    local checkpoint=marker.checkpoint or {};local remaining=marker.deadline and marker.deadline-os.time()
    if not remaining or remaining<=0 then self:stopNative('Original session deadline expired');return end
    cfg.dungeonShopCap=checkpoint.shopCap or 0;cfg.dungeonOpenChests=checkpoint.openChests==true
    cfg.autoStartWaves=checkpoint.startWaves==true;cfg.dungeonConsent=ready.mode=='Dungeon'
    cfg.autoNextStory=checkpoint.nextStory==true
    if marker.expected.kind=='replay' or marker.expected.kind=='next_story' then
        cfg.replayFreeConfirmed=checkpoint.replayFree==true;cfg.replayContext={stage=ready.stage,mode=ready.mode,placeId=ready.placeId}
        if not C.finite(checkpoint.remainingRuns) or checkpoint.remainingRuns<1 then self:stopNative('Original run cap reached');return end
        cfg.maxRuns=math.min(100,(checkpoint.runs or 0)+checkpoint.remainingRuns)
    end
    if self.native:arm(ready) then
        self.native.startedAt=ready.now-(cfg.maxSeconds-remaining)
        self.native.runs=checkpoint.runs or 0;self.native.route.spent=checkpoint.spent or 0
        self.nativeDeadline=marker.deadline;self.snapshot=ready;self.adapter:watchResults()
        self:notice('Expected teleport verified; Smart Auto resumed within original limits')
    else self:stopNative(self.native.reason);self:notice(self.native.reason) end
end
function app:recentLogs()
    local rows={}
    for i=math.max(1,#self.log.lines-9),#self.log.lines do rows[#rows+1]=self.log.lines[i] end
    return table.concat(rows,'\n')
end
function app:refreshInventory()
    self.adapter:refreshInventory(os.clock());self.snapshot=self.adapter:observe(os.clock())
    self:notice('Refreshed '..#self.snapshot.owned..' exposed unit records; partial inventory only')
end
function app:readClientCache(reportKind)
    self:stopNative('Client data read requested')
    self:stopTeam('Manual cache read requested')
    self.engine:stop('Manual experimental client-cache read','IDLE')
    self.trial:cancel('Client-cache read requested; test cancelled')
    self:notice('Attempting one loaded-client cache read; spending remains unavailable')
    local started,why=self.adapter:startClientCache(reportKind=='smart')
    self.awaitCacheCopy=started and (reportKind or 'complete') or false
    if not started then
        self:notice(why)
        if reportKind=='combat' then self:copyCombatReport() else self:copyReport() end
    end
end
function app:readMatchData()
    self.snapshot=self.adapter:observe(os.clock())
    if not self.snapshot.inMatch then
        self:notice('Enter a free Story match, start waves and place one equipped unit manually first');return
    end
    self:readClientCache('combat')
end
function app:nextRukia()
    self:stopNative('Selected objective changed')
    self:stopTeam('Selected objective changed')
    local list={}
    for _,u in ipairs((self.snapshot or {}).owned or {}) do
        if C.isRukia(u.id) and u.statScope=='collection' then list[#list+1]=u end
    end
    if #list==0 then self:notice('No exact secret Rukia ID observed');return end
    local idx=0;for i,u in ipairs(list) do if u.uuid==cfg.selectedUuid then idx=i end end
    cfg.selectedUuid=list[idx%#list+1].uuid
    self.engine:stop('Selected unit changed','IDLE');self:notice('Selected observed Rukia '..(idx%#list+1))
end
function app:set(key,v)
    self:stopNative('Settings changed')
    self:stopTeam('Settings changed')
    self.trial:cancel('Settings changed; test cancelled')
    if self.engine.armed then self.engine:stop('Settings changed; review before rearming','IDLE') end
    local limits={reserve={0,1000000},maxRuns={1,100},maxSeconds={30,7200},traitCap={0,1000},statCap={0,1000},
        autoDistance={0,100},autoGround={0,100},autoHill={0,100},dungeonShopCap={0,100000}}
    if limits[key] then
        if not C.finite(v) then self:notice('Enter a finite number');return end
        cfg[key]=math.clamp(math.floor(v),limits[key][1],limits[key][2])
    elseif table.find({'inventoryPath','resourcePath','cashPath','recordCosts'},key) and type(v)=='string' then
        cfg[key]=v:sub(1,200);self.adapter.nextInventory=0
    end
    self:saveSettings()
end
function app:cycle(key,values)
    self:stopNative('Objective or strategy changed')
    self:stopTeam('Target/mode changed')
    self.trial:cancel('Target/mode changed; test cancelled')
    self.engine:stop('Target/mode changed; review before rearming','IDLE')
    cfg[key]=values[(table.find(values,cfg[key]) or 0)%#values+1]
    if key=='trialSlot' then self.trialProfile=nil;self.trialQuotes={} end
    cfg.routeConfirmed=false;cfg.protocolConfirmed=false;cfg.replayFreeConfirmed=false
    self:saveSettings()
end
function app:toggle(key)
    self:stopNative('Settings changed')
    self:stopTeam('Settings changed')
    self.trial:cancel('Settings changed; test cancelled')
    self.engine:stop('Settings changed; review before rearming','IDLE')
    if table.find({'routeConfirmed','protocolConfirmed','replayFreeConfirmed'},key) and not cfg[key] then
        if not self.snapshot.stageVerified then self:notice('Observe the actual stage before confirming it');return end
        C.bindConsent(cfg,key,self.snapshot)
    end
    cfg[key]=not cfg[key]
    self:saveSettings()
end
function app:checkReady()
    local blockers=C.readiness(self.snapshot,self.profile,cfg)
    if #blockers==0 then self:notice('Prerequisites present; current transport still requires supervised live testing')
    else self:notice(table.concat(blockers,'; ')) end
end
function app:toggleFarm()
    if self.native.armed then self:notice('Stop Smart Auto before using a legacy controller');return end
    if self.engine.armed then self.engine:stop('Stopped by user','IDLE');return end
    self.snapshot=self.adapter:observe(os.clock())
    if self.team.armed or self.team.pending or self.team.uncertainRun==self.snapshot.run then
        self:notice('Team controller active/unconfirmed; inspect its report before Rukia-route automation');return
    end
    if self.trial.pending or (self.trial.state=='UNCONFIRMED' and self.trial.attemptRun==self.snapshot.run) then
        self:notice('Single-action test pending or unconfirmed; inspect its report before farming');return
    end
    if not self.adapter:remote('spawn_unit') then self:notice('No spawn_unit endpoint; combat unavailable');return end
    if cfg.upgrade and not self.adapter:remote('upgrade_unit_ingame') then
        self:notice('Upgrade endpoint missing; disable upgrades or leave combat off');return
    end
    if self.engine:arm(self.snapshot,self.profile) then self:notice('Experimental recorded combat armed')
    else self:notice(self.engine.reason) end
end
function app:record()
    self:stopNative('Recording requested')
    self:stopTeam('Rukia profile recording requested')
    self.engine:stop('Recording requested','IDLE')
    self.trial:cancel('Recording changed; test cancelled')
    self.snapshot=self.adapter:observe(os.clock())
    local p,err=self.adapter:record(self.snapshot,cfg.recordCosts)
    if not p then self:notice(err);return end
    self.profile=p;cfg.protocolConfirmed=false;cfg.routeConfirmed=false;cfg.replayFreeConfirmed=false
    self:notice('Recorded '..#p.entries..' placements; costs/ordering need supervised verification')
end
function app:trialButton(kind)
    local quote,why=self.trial:quote(kind,self.snapshot or {},self.trialProfile)
    self.trialQuotes[kind]=quote
    local title=kind=='upgrade' and 'TEST ONE UPGRADE' or 'TEST ONE PLACEMENT'
    if not quote then return title..' • '..tostring(why) end
    return title..'\n'..quote.id..' [slot '..fmt(quote.slot)..'] '..
        (kind=='upgrade' and (quote.level..'→'..(quote.level+1)..' | ') or '| ')..quote.cost..' YEN'
end
function app:recordTrialTarget()
    self:stopNative('Manual test target requested')
    self:stopTeam('Single-action target recording requested')
    self.engine:stop('Recording single-action test target','IDLE')
    self.trial:cancel('Test target changed; pending result unconfirmed')
    self.snapshot=self.adapter:observe(os.clock())
    local p,why=self.adapter:recordTestTarget(self.snapshot,cfg.trialSlot)
    if not p then self:notice(why);return end
    self.trialProfile=p;self.trialQuotes={}
    self:notice('Recorded test target '..p.entries[1].id..' from equipped slot '..cfg.trialSlot)
end
function app:runTrial(kind)
    if self.native.armed then self:notice('Stop Smart Auto before a single-action test');return end
    if self.engine.armed or self.engine.pending or self.team.armed or self.team.pending then
        self:notice('Keep automatic controllers OFF for a single-action test');return
    end
    self.snapshot=self.adapter:observe(os.clock())
    if self.team.uncertainRun==self.snapshot.run or self.engine.uncertainRun==self.snapshot.run then
        self:notice('Prior automatic action unconfirmed; enter a fresh match');return
    end
    local action,why=self.trial:begin(kind,self.snapshot,self.trialProfile,self.trialQuotes[kind])
    if not action then self:notice(why);return end
    self.awaitTrialCopy=true
    local sent,err,token=self.adapter:dispatch(action)
    if sent and self.trial.pending then self.trial.pending.feedbackToken=token end
    if not sent then self.trial:cancel('Test request not sent: '..tostring(err));self:notice(err)
    else self:notice('One test request sent; wait up to 8 seconds without manual placement/upgrades. Report copies automatically.') end
end
function app:stopTrial()
    self.trial:cancel('Stopped by user; result unconfirmed')
end
function app:tickController(controller,s,p)
    local pending=controller.pending;local placements=controller.placements or 0;local upgrades=controller.upgrades or 0
    local confirmations=controller.confirmations or 0
    local action=controller:tick(s,p)
    if pending and pending.feedbackToken and pending~=controller.pending
        and ((controller.placements or 0)>placements or (controller.upgrades or 0)>upgrades
            or (controller.confirmations or 0)>confirmations) then
        self.adapter:confirmMutation(pending.feedbackToken)
        if controller==self.native then
            local ok,why=self:checkpointNative(nil)
            if not ok then self:stopNative('Checkpoint confirmation failed: '..tostring(why)) end
        end
    end
    return action
end
function app:stopTeam(reason)
    if self.team.armed or self.team.pending then self.team:stop(reason or 'Stopped by user','IDLE') end
    self.adapter:stopResultWatch()
end
function app:recordTeam()
    self:stopNative('Manual team recording requested')
    self:stopTeam('Team recording requested')
    self.engine:stop('Team recording requested','IDLE');self.trial:cancel('Team recording requested')
    self.snapshot=self.adapter:observe(os.clock())
    local p,why=self.adapter:recordTeam(self.snapshot,self.teamProfile)
    if not p then self:notice(why);return end
    self.teamProfile=p
    local count,total=self.team:coverage(self.snapshot,p)
    local savedOK=self:saveSettings()
    self:notice('Recorded team slots '..count..'/'..total..' | '..#p.entries..' positions | '..
        (savedOK and 'saved; Auto remains OFF' or 'local saving failed; profile is only in this session'))
end
function app:checkTeam()
    self.snapshot=self.adapter:observe(os.clock())
    local b=self.team:readiness(self.snapshot,self.teamProfile)
    self:notice(#b==0 and 'Team prerequisites present; supervise the first run' or table.concat(b,'; '))
end
function app:toggleTeam()
    if self.native.armed then self:notice('Stop Smart Auto before recorded-team control');return end
    if self.team.armed then self:stopTeam('Stopped by user');return end
    self.snapshot=self.adapter:observe(os.clock());local s=self.snapshot
    if self.engine.armed or self.engine.pending or self.trial.pending or self.engine.uncertainRun==s.run
        or (self.trial.state=='UNCONFIRMED' and self.trial.attemptRun==s.run) then
        self:notice('Another controller is active/unconfirmed; stop it and inspect the report');return
    end
    local b=self.team:readiness(s,self.teamProfile)
    if #b>0 then self:notice(table.concat(b,'; '));return end
    if not self.adapter:remote('spawn_unit') or (cfg.upgrade and not self.adapter:remote('upgrade_unit_ingame')) then
        self:notice('Team action endpoint missing');return
    end
    local geometryOK,why=self.adapter:checkTeamSurface(self.teamProfile,s)
    if not geometryOK then self:notice(why);self:copyTeamReport();return end
    if self.team:arm(s,self.teamProfile) then
        self.adapter:watchResults();self:notice('Experimental Story Team Auto armed; supervise this run')
    else self:notice(self.team.reason) end
end
function app:saveSettings()
    if type(writefile)~='function' then self:notice('Local file saving unavailable');return false end
    local ok=writeJSONVerified(filename,{cfg=cfg,profile=self.profile,
        trialProfile=self.trialProfile,teamProfile=self.teamProfile,version=C.version})
    self:notice(ok and 'Settings saved; Auto remains OFF on reload' or 'Settings save failed')
    return ok
end
function app:completeReport()
    local s=self.snapshot or {}
    local out={'[K] AA RUKIA '..C.version,'OFFLINE VERIFIED; LIVE GAME / DELTA UNVERIFIED',
        self:ownershipText(),self:objectiveText(),self:walletText(),self:traitText(),self:statsText(),self:evolutionText(),
        self:farmText(),self:reportStatus(),
        self.trial:text(),
        self.team:text(s,self.teamProfile),
        self:smartText(),
        'Place ID: '..fmt(s.placeId),'Inventory source: '..fmt(s.inventorySource),'Currency source: '..fmt(s.cashSource),
        self.adapter:combatReport(s),
        self.adapter.cacheReport or 'CLIENT CACHE READER: not attempted; use RUKIA → READ CLIENT CACHE + COPY REPORT',
        'Premium mutation endpoints and new Dungeon key spending: unavailable. Native current-run Dungeon flow: experimental.',
        'Profile positions/costs: user-recorded. Path samples: observed enemy motion only.',
        'Legacy import: '..fmt(self.legacySummary),'EXPOSED EQUIPPED RECORDS (UUIDs omitted):'}
    for label,source in pairs(s.walletSources or {}) do out[#out+1]='Balance source '..label..': '..source end
    for _,u in ipairs(s.roster or {}) do
        out[#out+1]='slot='..fmt(u.slot)..' id='..fmt(u.id)..' cost='..fmt(u.cost)..' trait='..fmt(u.trait)
    end
    local names={}
    for i,v in ipairs(workspace:GetChildren()) do
        if i>60 then break end
        if v:IsA('Folder') or v:IsA('Model') then names[#names+1]=v.Name:sub(1,40) end
    end
    out[#out+1]='Workspace containers (bounded): '..table.concat(names,', ')
    local diagnostic=self.adapter.pathDiagnostic
    out[#out+1]=diagnostic and diagnostic.text or 'DATA PATH DIAGNOSTIC: optional metadata scan not run'
    out[#out+1]=self.log:text()
    return table.concat(out,'\n'):sub(1,65536)
end
function app:scanPathsAndCopy()
    self:stopNative('Manual data-path diagnostic requested')
    self:stopTeam('Manual metadata diagnostic requested')
    self.engine:stop('Manual data-path diagnostic','IDLE')
    self:notice('Collecting bounded metadata; inventory values stay protected')
    local result,err=self.adapter:probePaths()
    if not result then self:notice(err);return end
    if self.alive then self:copyReport() end
end
function app:copyReport()
    local txt=self:completeReport()
    if type(setclipboard)=='function' then
        local ok=pcall(setclipboard,txt);self:notice(ok and 'Complete report copied' or 'Clipboard failed')
    else print(txt);self:notice('Clipboard unavailable; report printed') end
end
function app:copyCombatReport()
    self.snapshot=self.adapter:observe(os.clock())
    self.adapter:inspectPlacement(self.trialProfile,self.snapshot)
    local blockers=C.readiness(self.snapshot,self.profile,cfg)
    local text='[K] AA RUKIA '..C.version..' | LIVE COMBAT UNVERIFIED\n'..
        self.adapter:combatReport(self.snapshot)..'\n'..
        self.trial:text()..'\n'..
        (self.adapter.cacheReport or 'Client cache not connected')..'\n'..
        'READINESS: '..(#blockers==0 and 'prerequisites present; supervise testing' or table.concat(blockers,'; '))..
        '\n'..self.log:text()
    if type(setclipboard)=='function' then
        local ok=pcall(setclipboard,text);self:notice(ok and 'Combat report copied' or 'Clipboard failed')
    else print(text);self:notice('Clipboard unavailable; combat report printed') end
end
function app:copyTeamReport()
    self.snapshot=self.adapter:observe(os.clock());local s=self.snapshot
    local b=self.team:readiness(s,self.teamProfile)
    local out={'[K] AA TEAM '..C.version..' | EXPERIMENTAL STORY CONTROL',
        self.team:text(s,self.teamProfile),self.adapter:combatReport(s),
        self.adapter.cacheReport or 'Client cache not connected',
        'TEAM READINESS: '..(#b==0 and 'physical/profile prerequisites present' or table.concat(b,'; ')),
        'Team control does not verify a Rukia reward route. Premium mutations and dungeon navigation remain unavailable.'}
    for i,e in ipairs(type(self.teamProfile)=='table' and type(self.teamProfile.entries)=='table' and self.teamProfile.entries or {}) do
        if i>24 then break end
        if type(e)~='table' then out[#out+1]='Invalid recorded target';break end
        out[#out+1]='Target '..i..' slot='..fmt(e.slot)..' id='..fmt(e.id)..' role='..fmt(e.role)..' deployment quote='..fmt(e.cost)
    end
    out[#out+1]=self.log:text();local text=table.concat(out,'\n'):sub(1,65536)
    if type(setclipboard)=='function' then
        local ok=pcall(setclipboard,text);self:notice(ok and 'Team report copied' or 'Clipboard failed')
    else print(text);self:notice('Clipboard unavailable; Team report printed') end
end
function app:copyConfig()
    local txt=HTTP:JSONEncode({cfg=cfg,profile=self.profile,trialProfile=self.trialProfile,teamProfile=self.teamProfile})
    if type(setclipboard)=='function' then pcall(setclipboard,txt);self:notice('Configuration copied; includes unit UUIDs')
    else self:notice('Clipboard unavailable') end
end
function app:saveReport()
    if type(writefile)~='function' then self.diskSaved=false;self:notice('Report remains in memory');return end
    self.diskSaved=pcall(writefile,reportFile,self:completeReport())
    self:notice(self.diskSaved and 'Bounded report saved locally' or 'Report save failed')
end
function app.stop(replacement)
    if not app.alive then return end
    app.engine:stop('Closed by user or replaced by new instance','IDLE')
    app.trial:cancel('Closed or replaced; result unconfirmed')
    app.team:stop('Closed or replaced','IDLE')
    app.native:stop('Closed or replaced','IDLE');app.navigation:close()
    if replacement~='teleport-replace' then
        local revoked,why=app.session:close()
        if not revoked then warn('[K] Follow revocation failed: '..tostring(why)) end
    end
    app.alive=false;app.adapter:close()
    if app.ui then app.ui:close() end
    if type(writefile)=='function' then
        pcall(writefile,reportFile,app:completeReport())
        pcall(writefile,markerFile,HTTP:JSONEncode({open=false}))
    end
    if env.K_AA_RUKIA_V6==app then env.K_AA_RUKIA_V6=nil end
end
env.K_AA_RUKIA_V6=app
local marker=readJSON(markerFile)
if marker and marker.open==true then
    log:add('UNCLEAN SESSION','Previous session did not close; crash, teleport or process exit cannot be distinguished')
end
if type(writefile)=='function' then pcall(writefile,markerFile,HTTP:JSONEncode({open=true})) end
local legacy=readJSON('K_AA_Smart_v5_'..LP.UserId..'.json')
if legacy then
    local count=0;for _ in pairs(type(legacy.maps)=='table' and legacy.maps or {}) do count+=1 end
    app.legacySummary='v5 settings retained; '..count..' old profiles are unverified'
    if not saved.cfg and type(legacy.options)=='table' and type(legacy.options.upgrade)=='boolean' then cfg.upgrade=legacy.options.upgrade end
else app.legacySummary='No readable v5 settings' end
log:add('BOOT','v7 native adaptation; no GC/hook/global GUI scan; auto OFF unless verified opted-in continuation')
local bootOK,bootErr=pcall(function()
    app.snapshot=app.adapter:observe(os.clock());app.ui=makeUI(app)
end)
if not bootOK then app:error(bootErr);app.stop();warn('[K] AA initialization failed: '..tostring(bootErr));return end
task.spawn(function()
    while app.alive do
        local ok,err=pcall(function()
            local now=os.clock();local s=app.adapter:observe(now);app.snapshot=s
            local failure=app.adapter:poll()
            if failure then app:stopNative(failure);app.engine:reject(failure);app.team:reject(failure);app.adapter:stopResultWatch();app.trial:cancel(failure);app:notice(failure) end
            if app.awaitCacheCopy and app.adapter.cacheDone then
                local kind=app.awaitCacheCopy;app.awaitCacheCopy=false
                if kind=='combat' then app:copyCombatReport() else app:copyReport() end
            end
            app.recorder:observe(s)
            app.observedWins=app.recorder.wins;app.observedLosses=app.recorder.losses
            local roster={}
            for _,u in ipairs(s.roster) do roster[#roster+1]=fmt(u.slot)..':'..u.id end
            local signature=table.concat(roster,',')
            if signature~=app.lastRoster then app.lastRoster=signature;log:add('EQUIPPED OBSERVED',signature) end
            app:tickController(app.trial,s)
            if app.awaitTrialCopy and not app.trial.pending then
                app.awaitTrialCopy=false;app:copyCombatReport()
            end
            app:resumeNative(s)
            if app.native.armed then s=app.snapshot or s end
            local wasNative=app.native.armed
            if wasNative and not app.native.pending then
                local prepared,why=app:prepareNative(s)
                if prepared then s=prepared;app.snapshot=s
                else app:stopNative('Map planning stopped: '..tostring(why));app:notice(why) end
            end
            local controller=app.native.armed and app.native or (app.team.armed and app.team or app.engine)
            local request
            if controller==app.native then request=app:tickController(app.native,s)
            elseif controller==app.team then request=app:tickController(app.team,s,app.teamProfile)
            else request=app:tickController(app.engine,s,app.profile) end
            if request then
                local checkpointOK,checkpointWhy=true,nil
                if controller==app.native then checkpointOK,checkpointWhy=app:checkpointNative(request) end
                local sent,why,token
                if checkpointOK then sent,why,token=app.adapter:dispatch(request)
                else sent=false;why='Durable action checkpoint failed: '..tostring(checkpointWhy) end
                if sent and controller.pending then controller.pending.feedbackToken=token end
                if not sent then
                    controller:reject(why)
                    if controller==app.native then app:stopNative(why) end
                else log:add('ATTEMPT',request.kind..' | awaiting live feedback') end
            end
            if wasNative and not app.native.armed then
                local state,reason=app.native.state,app.native.reason
                app:stopNative(reason);app.native.state=state;app:notice(reason);app:copyReport()
            end
            if not app.team.armed and not app.native.armed then app.adapter:stopResultWatch() end
            if app.team.reportDue then app.team.reportDue=false;app:copyTeamReport() end
            if now-app.lastRefresh>=2 then app.lastRefresh=now;app.ui:refresh() end
        end)
        if not ok then app:error(err) end
        task.wait(.8)
    end
end)
