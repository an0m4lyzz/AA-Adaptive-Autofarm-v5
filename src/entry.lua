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
local K=require('./contracts')
local makeEvidence=require('./evidence')
local makeBudget=require('./budget')
local makeActions=require('./actions')
local makeThreats=require('./threats')
local catalog=require('./catalog')
local makeProgression=require('./progression')
local makeMacro=require('./macro')
local makeSettings=require('./settings')
local makePerformance=require('./performance')
local makeReports=require('./reports')
local features=require('./features')
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
local budgetFile='K_AA_Rukia_v7_Budget_'..LP.UserId..'.json'
local runStateFile='K_AA_v8_Runs_'..LP.UserId..'.json'
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
        assert(#raw<=262144,'Local JSON exceeds256 KiB')
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
app.evidence=makeEvidence(K)
app.evidence.register({id='combat',schema='native-v1',requiredFields={'roster','towers'},status='offline'})
app.evidence.register({id='dungeon',schema='native-v1',requiredFields={'dungeon'},status='offline'})
app.evidence.register({id='flow',schema='native-v1',requiredFields={'flow'},status='offline'})
local budgetStorageKnown=false
app.budget=makeBudget(K,{write=function(value) return writeJSONVerified(budgetFile,value) end,
    canPay=function() return budgetStorageKnown and type(readfile)=='function' and type(writefile)=='function' end},
    {accountId=LP.UserId,universeId=game.GameId},os.time)
local previousBudget=readJSON(budgetFile)
if previousBudget then
    budgetStorageKnown=app.budget.restore(previousBudget,{accountId=LP.UserId,universeId=game.GameId})==true
    app.budget.frozen=not budgetStorageKnown
elseif type(readfile)=='function' then
    local ok,raw=pcall(readfile,budgetFile)
    local existsOK,exists=false,false
    if type(isfile)=='function' then existsOK,exists=pcall(isfile,budgetFile) end
    budgetStorageKnown=not (ok and raw~=nil) and existsOK and exists==false
    app.budget.frozen=not budgetStorageKnown
else app.budget.frozen=true
end
app.actionSerial=0;app.actionPrefix=tostring({});app.actionReceipts={}
app.threats=makeThreats(C)
app.progression=makeProgression(C);app.catalog=catalog
app.macro=makeMacro(C,cfg,log)
app.settings=makeSettings(C);app.performance=makePerformance()
app.reports=makeReports(C,{start=function(url,message,done)
    task.spawn(function()
        local requestFn=request or http_request or (type(syn)=='table' and syn.request)
        if type(requestFn)~='function' then done(nil);return end
        local ok,response=pcall(requestFn,{Url=url,Method='POST',Headers={['Content-Type']='application/json'},Body=HTTP:JSONEncode({content=message})})
        done(ok and type(response)=='table' and tonumber(response.StatusCode or response.Status) or nil)
    end)
end})
local oldRuns=readJSON(runStateFile)
if oldRuns and oldRuns.userId==LP.UserId and oldRuns.universeId==game.GameId then app.reports:restore(oldRuns.stats) end
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
function app:observation(s)
    s=s or self.snapshot or {}
    local context={accountId=LP.UserId,universeId=game.GameId,jobId=game.JobId,
        roundId=tostring(s.run or 'unknown'),stageId=s.stage or 'unknown',mode=s.mode or 'unknown',epoch=0}
    local v={now=s.now,context=context,evidence={},roster=s.roster,towers=s.units,dungeon=s.dungeon,
        account={wallet=s.wallet,resources=s.resources,owned=s.owned,ownershipComplete=false},
        flow={wave=s.wave,outcome=s.outcome,started=s.started},battlefield={pathSamples=s.pathSamples},
        threats=self.threats.summarize({enemies=s.enemyUnits,enemiesComplete=s.enemiesComplete})}
    v.evidence.flow={source='native round observer',schema='native-v1',observedAt=s.now,
        context=K.copy(context),scope='round',complete=s.stageVerified==true and s.modeVerified==true}
    for key,info in pairs({roster={s.rosterAt,s.rosterComplete},towers={s.now,s.unitsComplete},
        dungeon={s.dungeonAt,s.dungeon and s.dungeon.valid},account={s.ownedAt,false}}) do
        v.evidence[key]={source='existing native observer',schema='native-v1',observedAt=info[1],
            context=K.copy(context),scope=key=='account' and 'account' or 'round',complete=info[2]==true}
    end
    return v
end
function app:makeActions()
    self.actions=makeActions(K,self.evidence,self.budget,{
        send=function(intent)
            local sent,why,token=self.adapter:dispatch(intent.native)
            self.actionFeedbackToken=token;return sent,why
        end,
        verify=function(intent) return self.actionReceipts[intent.id] end})
end
function app:featureStatusText()
    local counts={offline=0,partial=0,blocked=0};local out={}
    for _,f in ipairs(features) do counts[f.status]+=1;out[#out+1]=f.id..' / '..f.status..' / '..f.label end
    return 'FEATURE EVIDENCE / '..#features..' groups\nOffline tested '..counts.offline..' | partial '..counts.partial..' | blocked '..counts.blocked..
        '\nLive passed: 0 in this update. Offline status does not certify live play.\n'..table.concat(out,'\n')
end
function app:resetReportTotals()
    if self.native.armed then self:notice('Stop Auto before resetting report totals');return end
    self.reports:restore({wins=0,losses=0,unknown=0,outcomes={},order={}})
    writeJSONVerified(runStateFile,{userId=LP.UserId,universeId=game.GameId,stats=self.reports:checkpoint()})
    self:notice('Retained report totals reset; spending and run limits are unchanged')
end
function app:dungeonBudgetText()
    local pending=0;for _,r in pairs(self.budget.state.reservations) do if r.sent and next(r.cost)~=nil then pending+=1 end end
    return 'Shared Dungeon coin ledger: spent '..tostring(self.budget.state.spent.DungeonCoins or 0)..
        ' / cap '..tostring(self.budget.state.caps.DungeonCoins or 0)..' | remaining '..self.budget.remaining('DungeonCoins')..
        '\nOutstanding account debits: '..pending..
        (self.budget.frozen and '\nStored ledger unverified/unavailable: spending blocked until reconciled' or '')
end
function app:reviewDungeonBudget()
    if self.native.armed then self:notice('Stop Auto before reviewing a new spending allowance');return false end
    local view=self:observation();self.actionSerial+=1
    local preview=self.budget.review({id=self.actionPrefix..':review:'..self.actionSerial,caps={DungeonCoins=cfg.dungeonShopCap},
        allowedOps={dungeon=true},expires=os.time()+cfg.maxSeconds},view)
    local grant,why=self.budget.grant(preview,true)
    self:notice(grant and 'New explicit Dungeon coin allowance recorded; Auto remains OFF' or tostring(why or 'Budget grant failed'))
    return grant~=nil
end
function app:configureWebhook(url)
    if type(url)~='string' or #url>300 or not url:match('^https://discord%.com/api/webhooks/[%w_%-]+/[%w_%-]+$') then
        self:notice('Enter a valid Discord webhook URL; it is retained only in this session');return false
    end
    self.reports:revokeNotifications();self.notificationEnabled=false;self.notificationURL=url
    self:notice('Destination held in memory; sending remains OFF');return true
end
function app:toggleNotifications()
    if self.notificationEnabled then
        self.notificationEnabled=false;self.reports:revokeNotifications();self:notice('Notifications disabled; already-sent HTTP cannot be cancelled');return
    end
    if not self.notificationURL then self:notice('Set a destination first');return end
    self.notificationEnabled=true;self:notice('Match/chest notifications explicitly enabled for this session')
end
function app:testNotification()
    if not self.notificationURL then self:notice('Set a destination first');return end
    self.reports:queueNotification({id='test:'..tostring(os.clock()),text='[K] AA notification test; no inventory or account identifiers included'},
        {enabled=true,url=self.notificationURL})
    self:notice('One explicit test queued')
end
function app:applyPortableSettings(data)
    local result=self.settings.validate(data)
    if not result.valid then self:notice(result.errors);return false end
    self:stopNative('Portable settings applied');self:stopTeam('Portable settings applied')
    self.engine:stop('Portable settings applied','IDLE');self.trial:cancel('Portable settings applied')
    for key in pairs(C.defaults) do cfg[key]=result.settings[key] end
    self:applyLocalOptions();self:saveSettings();self:notice('Validated preferences applied; grants and automation remain OFF');return true
end
function app:importSettings()
    if type(getclipboard)~='function' then self:notice('Clipboard read unavailable; use named local profiles');return false end
    local ok,raw=pcall(getclipboard)
    if not ok or type(raw)~='string' or #raw>65536 then self:notice('Settings clipboard missing or oversized');return false end
    local parsed,data=pcall(function() return HTTP:JSONDecode(raw) end)
    if not parsed then self:notice('Settings JSON is invalid');return false end
    return self:applyPortableSettings(data)
end
function app:saveProfile()
    if not self.settings.name(cfg.profileName) then self:notice('Invalid profile name');return false end
    local path='K_AA_v8_Profile_'..LP.UserId..'_'..cfg.profileName..'.json'
    local old=readJSON(path)
    if old and not writeJSONVerified(path..'.bak',old) then self:notice('Profile backup failed; original retained');return false end
    local ok=writeJSONVerified(path,self.settings.export(cfg));self:notice(ok and 'Named profile saved' or 'Profile write failed');return ok
end
function app:loadProfile()
    if not self.settings.name(cfg.profileName) then return false end
    local data=readJSON('K_AA_v8_Profile_'..LP.UserId..'_'..cfg.profileName..'.json')
    return self:applyPortableSettings(data)
end
function app:applyLocalOptions()
    local effects={};local light
    pcall(function()
        light=game:GetService('Lighting')
        if light then
            for i,x in ipairs(light:GetChildren()) do
                if i>64 then break end
                if x:IsA('BloomEffect') or x:IsA('DepthOfFieldEffect') or x:IsA('SunRaysEffect') or x:IsA('BlurEffect') then effects[#effects+1]=x end
            end
        end
    end)
    local result=self.performance.apply(cfg.qualityProfile,{light=light,effects=effects})
    self.localStatus=result.reason
    if self.idleConnection then self.idleConnection:Disconnect();self.idleConnection=nil end
    if cfg.antiAfk==true and LP.Idled then
        local ok,connection=pcall(function() return LP.Idled:Connect(function()
            if not self.alive or cfg.antiAfk~=true or not self.native.armed or self.native.pending or self.adapter:busy() then return end
            local success=pcall(function()
                local input=game:GetService('VirtualUser');input:CaptureController();input:ClickButton2(Vector2.new())
            end)
            if not success then cfg.antiAfk=false;self:notice('Anti-AFK input unsupported; disabled') end
        end) end)
        if ok then self.idleConnection=connection else self.localStatus=self.localStatus..'; anti-AFK unavailable' end
    end
    if cfg.cameraZoom>0 and C.finite(LP.CameraMaxZoomDistance) then
        if not self.zoomOriginal then self.zoomOriginal=LP.CameraMaxZoomDistance end
        local ok=pcall(function() LP.CameraMaxZoomDistance=cfg.cameraZoom end);if ok then self.zoomApplied=cfg.cameraZoom end
    elseif self.zoomApplied then
        pcall(function()if LP.CameraMaxZoomDistance==self.zoomApplied then LP.CameraMaxZoomDistance=self.zoomOriginal end end)
        self.zoomApplied=nil;self.zoomOriginal=nil
    end
end
function app:openNativeScreen()
    local gui=LP:FindFirstChildOfClass('PlayerGui');local screen=gui and gui:FindFirstChild(cfg.nativeScreen)
    if not screen or not screen:IsA('ScreenGui') then self:notice('Native screen unavailable; open it with the game button');return end
    local ok=pcall(function() screen.Enabled=true end)
    self:notice(ok and 'Native screen opened; no account action sent' or 'Native screen could not be opened')
end
local function macroFile(name)
    if type(name)=='string' and #name<=40 and name:match('^[%w_%-]+$') then return 'K_AA_v8_Macro_'..LP.UserId..'_'..name..'.json' end
end
function app:startMacroRecording()
    local ok,why=self.macro:startRecording(self.snapshot or {},cfg.macroName)
    self:notice(ok and 'Recording exact native actions; manual game clicks are not intercepted' or why);return ok
end
function app:finishMacroRecording()
    self.macro.recording=false
    local d=self.macro.data;local v=self.macro:validate(d)
    local ok=v.valid and macroFile(d.name) and writeJSONVerified(macroFile(d.name),d)
    self:notice(ok and 'Portable macro saved: '..d.name or 'Macro save failed: '..tostring(v.errors));return ok==true
end
function app:loadMacro(name)
    name=name or cfg.macroName
    if self.native.armed or self.macro.recording then self:notice('Stop playback/recording before loading another macro');return false end
    local path=macroFile(name);local d=path and readJSON(path)
    local result=self.macro:validate(d)
    if not result.valid then self:notice(result.errors);return false end
    self.macro.data=d;self:notice('Validated macro loaded: '..name);return true
end
function app:copyMacro()
    local v=self.macro:validate(self.macro.data)
    if not v.valid then self:notice(v.errors);return end
    if type(setclipboard)=='function' then pcall(setclipboard,HTTP:JSONEncode(self.macro.data));self:notice('Data-only macro copied') end
end
function app:beginManualMacro()
    if self.native.armed or not self.macro.recording then self:notice('Start macro recording with Auto OFF first');return end
    local s=self.adapter:observe(os.clock());self.manualMacroBefore=table.clone(s);self.manualMacroBefore.units={}
    for i,u in ipairs(s.units or {}) do
        local copy=table.clone(u);if type(u.pos)=='table' then copy.pos=table.clone(u.pos) end;self.manualMacroBefore.units[i]=copy
    end
    self:notice('Before-state saved; make exactly one manual '..cfg.manualMacroKind..', then capture after')
end
function app:endManualMacro()
    if self.native.armed or not self.macro.recording or not self.manualMacroBefore then self:notice('Record a before-state with Auto OFF first');return end
    local s=self.adapter:observe(os.clock());local p,why=self.macro:captureManual(self.manualMacroBefore,s,cfg.manualMacroKind)
    self.manualMacroBefore=nil
    if p then local ok,reason=self.macro:record(p,s);self:notice(ok and 'One observed manual change recorded' or reason)
    else self:notice(why) end
end
function app:renameMacro()
    if self.native.armed or self.macro.recording or not self.macro:validate(self.macro.data).valid then self:notice('Load a valid stopped macro first');return false end
    local old=macroFile(self.macro.data.name);local new=macroFile(cfg.macroName)
    if not new or old==new then self:notice('Set a different valid macro name first');return false end
    if type(isfile)~='function' then self:notice('Rename needs an existence check; save a named copy instead');return false end
    local checked,occupied=pcall(isfile,new)
    if not checked or type(occupied)~='boolean' then self:notice('Destination existence unknown; rename stopped');return false end
    if occupied then self:notice('Destination macro already exists; choose an unused name');return false end
    local data=K.copy(self.macro.data);data.name=cfg.macroName
    if not writeJSONVerified(new,data) then self:notice('New macro write failed; old macro retained');return false end
    self.macro.data=data
    if type(delfile)=='function' then pcall(delfile,old);self:notice('Macro saved under the new name; verify old-file deletion if needed')
    else self:notice('New named copy saved; executor cannot delete the old file') end
    return true
end
function app:deleteMacro()
    if self.native.armed or self.macro.recording then self:notice('Stop macro playback/recording before delete');return false end
    local path=macroFile(cfg.macroName);local data=path and readJSON(path)
    if not data or type(delfile)~='function' then self:notice('Named macro or delete capability unavailable');return false end
    if not writeJSONVerified(path..'.bak',data) then self:notice('Backup failed; macro retained');return false end
    local ok=pcall(delfile,path)
    if ok and readJSON(path)==nil then self.macro.data=nil;self:notice('Named macro deleted; .bak backup retained');return true end
    self:notice('Deletion unconfirmed; inspect local file');return false
end
function app:importMacro()
    if self.native.armed or self.macro.recording then self:notice('Stop playback/recording before import');return false end
    if type(getclipboard)~='function' then self:notice('Clipboard read unavailable; put validated JSON in the named local macro file');return false end
    local ok,raw=pcall(getclipboard)
    if not ok or type(raw)~='string' or #raw>262144 then self:notice('Macro clipboard data unavailable/oversized');return false end
    local parsed,d=pcall(function() return HTTP:JSONDecode(raw) end)
    local valid=parsed and self.macro:validate(d,#raw)
    if not valid or not valid.valid then self:notice('Macro rejected; no code or unknown format accepted');return false end
    self.macro.data=d;cfg.macroName=d.name;return self:finishMacroRecording()
end
function app:toggleMacro()
    if self.native.armed then self:stopNative('Stopped before macro policy change');return end
    if not self.macro:validate(self.macro.data).valid and not self:loadMacro() then return end
    self.macro.rosterBindings=nil;self.macro.resumeBindings=nil -- this button is a new explicit playback approval
    self.startingMacro=true;cfg.macroSession=true
    self.native=makeRuntime(C,function() return self.macro end,makeDungeon,cfg,log)
    self:toggleNative();self.startingMacro=false
end
function app:sendAction(action)
    local s=self.snapshot or {};local view=self:observation(s)
    if self.actions and self.actions.pending() then
        local p=self.actions.pending()
        if next(p.cost)==nil and not K.same(p.context,view.context) and s.mutationFence~=true and s.transportBlocked~=true then
            if not self.budget.invalidateRound(view.context) then return false,'Round ledger invalidation failed' end
            self:makeActions()
        end
    end
    if not self.actions then self:makeActions() end
    action.macro=cfg.macroSession==true and self.native.armed and self.native.auto==self.macro
    local paid=action.kind=='dungeon' and action.name=='dungeon_buy_shop'
    local supported=table.find({'place','upgrade','priority','ability','skip','sell','start','lobby','next','replay'},action.kind)~=nil
        or (action.kind=='dungeon' and table.find({'dungeon_enter_room','dungeon_continue_shop','dungeon_open_chest','dungeon_buy_shop','dungeon_shrine_accept'},action.name)~=nil)
    if not supported then return false,'Action has no verified native receipt adapter' end
    local cost={}
    if paid then
        local price=action.expected and action.expected.price
        if not K.finite(price) or price<0 then return false,'Dungeon effective price unavailable' end
        cost.DungeonCoins=price
        if not self.budget.state.grant then
            local preview=self.budget.review({id=self.actionPrefix,caps={DungeonCoins=cfg.dungeonShopCap},
                allowedOps={dungeon=true},expires=os.time()+math.min(7200,cfg.maxSeconds)},view)
            if not self.budget.grant(preview,true) then return false,'Dungeon budget needs reconciliation' end
        end
    end
    self.actionSerial+=1
    local intent={id=self.actionPrefix..':'..self.actionSerial,capabilityId=action.kind=='dungeon' and 'dungeon'
        or (table.find({'place','upgrade','priority','ability','sell'},action.kind) and 'combat' or 'flow'),kind=action.kind,
        context=K.copy(view.context),cost=cost,deadline=(s.now or os.clock())+20,expected={kind=action.kind},
        permissionId=self.budget.state.grant and self.budget.state.grant.id,native=action}
    local result=self.actions.submit(intent,view,{})
    if result.kind~='action' then return false,result.reason end
    self.lastIntentId=intent.id;return true,nil,self.actionFeedbackToken
end
function app:captureGameData()
    self.snapshot=self.adapter:observe(os.clock())
    self.lastCapture=self.evidence.capture(self:observation(),{bytes=60000,nodes=1800})
    local raw=HTTP:JSONEncode(self.lastCapture)
    if #raw>65536 then self:notice('Capture too large; no oversized export');return end
    if type(setclipboard)=='function' then pcall(setclipboard,raw) end
    self:notice('One bounded data capture copied; no actions sent. Missing fields stay unknown.')
end
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
    local p=self.progression.plan(self.snapshot,self.catalog,{kind=cfg.goal,selectedUuid=cfg.selectedUuid,
        trait=cfg.targetTrait,grade=cfg.targetGrade})
    return p.objective..'\n'..tostring(p.stop and 'GOAL OBSERVED: no further farming needed' or p.blocker or 'Current route ready')..
        '\nStop goal: '..cfg.goal..'\nCurrent stage combat does not itself verify a Rukia reward route.'
end
function app:walletText()
    local s=self.snapshot or {};local w=s.wallet or {}
    return 'Observed account balances\nGold: '..fmt(w.Gold)..' | Gems: '..fmt(w.Gems)..
        '\nSummerPearls: '..fmt(w.SummerPearls)..
        '\nMatch cash: '..fmt(s.cash)..' | source: '..fmt(s.cashSource)
end
function app:dungeonInfo()
    local d=(self.snapshot or {}).dungeon
    if not d or not d.valid then return 'DUNGEON INFO: '..tostring(d and d.reason or 'Current schema unavailable') end
    local out={'DUNGEON / '..d.phase.kind..' | depth '..fmt(d.depth)..' / '..fmt(d.maxRooms),
        'Coins '..fmt(d.money)..' | normal chests '..fmt(d.normalChests)..' | rare '..fmt(d.rareChests)}
    for _,choice in ipairs({'1','2','3'}) do
        local room=d.rooms[choice]
        if room then
            local names={};for id,name in pairs({['0']='Curse',['1']='Shop',['2']='Hoard',['3']='Rare chest',['4']='Chest',['5']='Boss',['6']='Open chest',['7']='Shrine'}) do
                if room.flags[id] then names[#names+1]=name end
            end
            table.sort(names);out[#out+1]='Choice '..choice..' / depth '..room.depth..': '..table.concat(names,', ')
        end
    end
    for _,offer in ipairs(d.phase.offers or {}) do
        out[#out+1]=tostring(offer.id)..' / '..tostring(offer.name or '?')..' / coins '..fmt(offer.price)..'\n'..tostring(offer.description or 'Effect not exposed')
    end
    return table.concat(out,'\n'):sub(1,5000)
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
    cfg.macroSession=false
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
    if self.native.auto==self.macro then return s end
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
    cfg.placeCaps='';cfg.upgradeCaps='';cfg.placeWaves='';cfg.upgradeWaves='';cfg.slotOrder='1,2,3,4,5,6'
    cfg.autoSkip=false;cfg.sellAllWave=0;cfg.sellFarmWave=0;cfg.autoAbilities=false;cfg.autoBossTarget='GameDefault'
    cfg.upgradeBetweenPlacements=false;cfg.focusFarm=false;cfg.dungeonShrines=false;cfg.finishDelay=0
    self.planUntil=nil
    local savedOK=self:saveSettings()
    self:notice('Clear-first setup applied'..(savedOK and ' and saved' or ' for this session; saving failed')..
        '. Follow, shop spending and final chests need separate permission.')
end
function app:toggleNative()
    if self.native.armed then self:stopNative('Stopped by user');self:notice('Smart Auto stopped');return end
    if self.native.auto==self.macro and not self.startingMacro then
        cfg.macroSession=false;self.native=makeRuntime(C,makeAuto,makeDungeon,cfg,log)
    end
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
            replayFree=cfg.replayFreeConfirmed,startWaves=cfg.autoStartWaves,nextStory=cfg.autoNextStory,
            shrines=cfg.dungeonShrines,shrineItems=cfg.dungeonShrineItems,
            budgetId=self.budget.state.grant and self.budget.state.grant.id,
            macroName=self.native.auto==self.macro and self.macro.data and self.macro.data.name or nil,
            macroSignature=self.native.auto==self.macro and self.macro:signature(self.macro.data) or nil,
            macroRoster=self.native.auto==self.macro and self.macro:rosterCheckpoint() or nil}})
end
function app:resumeNative(s)
    if not self.resumeCandidate then return end
    if os.clock()>self.resumeDeadline then
        self:stopNative('Teleport continuation readiness timed out');self:notice('UI restored; auto resume could not verify the new round');return
    end
    if os.clock()<self.resumeEarliest then return end
    local policy=(self.followMarker or {}).checkpoint or {}
    if policy.macroName and not self.resumePolicyPrepared then
        self.resumePolicyPrepared=true
        if not self:loadMacro(policy.macroName) or self.macro:signature(self.macro.data)~=policy.macroSignature then
            self:stopNative('Original macro missing/changed after teleport');return
        end
        if type(policy.macroRoster)~='table' then self:stopNative('Original macro roster approval missing; re-arm manually');return end
        self.macro.resumeBindings=policy.macroRoster
        cfg.macroSession=true;self.native=makeRuntime(C,function() return self.macro end,makeDungeon,cfg,log)
    end
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
    if checkpoint.budgetId and (not self.budget.state.grant or self.budget.state.grant.id~=checkpoint.budgetId) then
        self:stopNative('Original spending ledger missing or mismatched after teleport');return
    end
    cfg.dungeonShopCap=checkpoint.shopCap or 0;cfg.dungeonOpenChests=checkpoint.openChests==true
    cfg.dungeonShrines=checkpoint.shrines==true;cfg.dungeonShrineItems=checkpoint.shrineItems or ''
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
    if C.defaults[key]==nil or type(v)~=type(C.defaults[key]) or (type(v)=='number' and not C.finite(v)) then
        self:notice('Enter a valid setting value');return
    end
    local cosmetic=table.find({'qualityProfile','blackScreen','antiAfk','uiTheme','uiScale','cameraZoom','nativeScreen'},key)
    if not cosmetic then
        self:stopNative('Settings changed');self:stopTeam('Settings changed');self.trial:cancel('Settings changed; test cancelled')
        if self.engine.armed then self.engine:stop('Settings changed; review before rearming','IDLE') end
    end
    local proposed=table.clone(cfg);proposed[key]=v;local safe=C.sanitize(proposed)
    if key=='antiAfk' then cfg[key]=v else cfg[key]=safe[key] end
    if key=='inventoryPath' or key=='resourcePath' or key=='cashPath' then self.adapter.nextInventory=0 end
    if cosmetic then self:applyLocalOptions() end
    self:saveSettings()
end
function app:cycle(key,values)
    if table.find({'qualityProfile','uiTheme','nativeScreen'},key) then
        local index=table.find(values,cfg[key]) or 0;self:set(key,values[index%#values+1]);return
    end
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
    if key=='blackScreen' or key=='antiAfk' then self:set(key,not cfg[key]);return end
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
    local sent,err,token=self:sendAction(action)
    if sent and self.trial.pending then self.trial.pending.intentId=self.lastIntentId end
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
        self.reports:record({kind='ACTION OBSERVED',detail=pending.kind or pending.name or 'native action'})
        if pending.expected and pending.expected.kind=='chest' then
            self.reports:queueNotification({id='chest:'..tostring(pending.intentId),text='[K] Dungeon chest count change observed. Contents are unverified unless separately inspected.'},
                {enabled=self.notificationEnabled==true,url=self.notificationURL})
        end
        if self.macro.recording and self.macro:recordable(pending.kind) then
            local recorded,why=self.macro:record(pending,s)
            if not recorded then self.macro.recording=false;self:notice('Macro recording stopped: '..tostring(why)) end
        end
        if pending.intentId and self.actions and self.actions.pending() then
            local intent=self.actions.pending()
            self.actionReceipts[pending.intentId]={intentId=pending.intentId,status='confirmed',proof=true,
                context=K.copy(intent.context),debits=K.copy(intent.cost),observedAt=s.now}
            self.actions.observe(self:observation(s));self.actionReceipts[pending.intentId]=nil
        end
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
        self.reports:render(),self:featureStatusText(),
        'Pending shared intent: '..tostring(self.actions and self.actions.pending() and self.actions.pending().kind or 'none')..
            ' | notification transport: '..self.reports.notificationState,
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
    if type(setclipboard)=='function' then pcall(setclipboard,HTTP:JSONEncode(self.settings.export(cfg)));self:notice('Portable preferences copied; unit identities and grants omitted')
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
    app.alive=false;app.adapter:close();app.performance.restore();app.reports:revokeNotifications();app.notificationURL=nil
    if app.idleConnection then pcall(function()app.idleConnection:Disconnect()end);app.idleConnection=nil end
    if app.zoomApplied then pcall(function()if LP.CameraMaxZoomDistance==app.zoomApplied then LP.CameraMaxZoomDistance=app.zoomOriginal end end) end
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
log:add('BOOT','v8 native expansion; no GC/hook/global GUI scan; auto OFF unless verified opted-in continuation')
local bootOK,bootErr=pcall(function()
    app.snapshot=app.adapter:observe(os.clock());app.ui=makeUI(app);app:applyLocalOptions()
end)
if not bootOK then app:error(bootErr);app.stop();warn('[K] AA initialization failed: '..tostring(bootErr));return end
task.spawn(function()
    while app.alive do
        local ok,err=pcall(function()
            local now=os.clock();local s=app.adapter:observe(now);app.snapshot=s
            app.reports:tick(now)
            if s.resultVisible then
                local round=game.JobId..'/'..tostring(s.roundToken)..'/'..s.stage
                if app.reports:outcome(round,s.outcome) then
                    local savedRun=writeJSONVerified(runStateFile,{userId=LP.UserId,universeId=game.GameId,stats=app.reports:checkpoint()})
                    if not savedRun then app.reports:record({kind='REPORT',detail='Aggregate persistence failed; current-injection counts remain in memory'}) end
                    app.reports:queueNotification({id=round..'/'..tostring(s.outcome),text='[K] '..s.mode..' / '..s.stage..' / observed '..tostring(s.outcome)..'. No rewards inferred.'},
                        {enabled=app.notificationEnabled==true,url=app.notificationURL})
                end
            end
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
            if app.native.armed and not app.native.pending then
                local goal=app.progression.plan(s,app.catalog,{kind=cfg.goal,selectedUuid=cfg.selectedUuid,trait=cfg.targetTrait,grade=cfg.targetGrade})
                if goal.stop then app:stopNative(goal.objective);app:notice(goal.objective) end
            end
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
                if checkpointOK then sent,why,token=app:sendAction(request)
                else sent=false;why='Durable action checkpoint failed: '..tostring(checkpointWhy) end
                if sent and controller.pending then controller.pending.feedbackToken=token;controller.pending.intentId=app.lastIntentId;controller.pending.macroWave=s.wave end
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
