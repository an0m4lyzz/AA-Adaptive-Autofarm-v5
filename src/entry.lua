local C=require('./core')
local makeAdapter=require('./roblox')
local makeUI=require('./ui')
local env=(type(getgenv)=='function' and getgenv()) or _G
local deadline=os.clock()+30
while not game:IsLoaded() and os.clock()<deadline do task.wait(.1) end
if not game:IsLoaded() then warn('[K] AA: game load timeout');return end
local LP=game:GetService('Players').LocalPlayer
if not LP then warn('[K] AA: local player unavailable');return end
for _,key in ipairs({'K_AA_V2','K_AA_V3','K_AA_V4','K_AA_V5','K_AA_RUKIA_V6'}) do
    local old=env[key]
    if type(old)=='table' and type(old.stop)=='function' then pcall(function() old.stop() end) end
end
local HTTP=game:GetService('HttpService')
local filename='K_AA_Rukia_v6_'..LP.UserId..'.json'
local reportFile='K_AA_Rukia_v6_Report_'..LP.UserId..'.txt'
local markerFile='K_AA_Rukia_v6_Session_'..LP.UserId..'.json'
local function readJSON(name)
    if type(readfile)~='function' then return nil end
    local ok,raw=pcall(readfile,name)
    if not ok or type(raw)~='string' or #raw>262144 then return nil end
    local valid,data=pcall(function() return HTTP:JSONDecode(raw) end)
    return valid and type(data)=='table' and data or nil
end
local saved=readJSON(filename) or {}
local cfg=C.sanitize(saved.cfg)
local log=C.logger(240)
local app={alive=true,cfg=cfg,log=log,profile=type(saved.profile)=='table' and saved.profile or nil,
    status='Observer only; live compatibility unverified',diskSaved=false,observedWins=0,observedLosses=0,
    reportRun=nil,reportOutcome=nil,lastWave=-1,lastRoster='',lastRefresh=0,lastCheckpoint=0}
app.engine=C.engine(cfg,log)
app.recorder=C.recorder(log)
app.adapter=makeAdapter(C,env,cfg,log)
local function fmt(x) return x==nil and '?' or tostring(x) end
function app:notice(message)
    self.status=tostring(message):sub(1,400);self.log:add('STATUS',self.status)
end
function app:error(err)
    self.engine:stop('Runtime error; automation stopped')
    self:notice(tostring(err):sub(1,300))
end
function app:unit() return C.chooseRukia((self.snapshot or {}).owned,self.cfg.selectedUuid) end
function app:ownershipText()
    local u=self:unit()
    if not u then return 'RUKIA OWNERSHIP: UNKNOWN\nThe exposed inventory scan does not prove absence.' end
    return 'OWNED OBSERVED: '..(u.id=='rukia_2_evo' and 'Snow Reaper (Final)' or 'Snow Reaper (War)')..
        '\nData: '..fmt(u.statScope)..' | level/upgrade='..fmt(u.level)
end
function app:objectiveText()
    if not self.snapshot then return 'Waiting for observation' end
    local title,detail=C.plan(self.snapshot,self.cfg)
    return title..'\n'..detail..'\nStop goal: '..self.cfg.goal
end
function app:traitText()
    local u=self:unit();local r=(self.snapshot or {}).resources or {}
    return 'Current trait: '..fmt(u and u.trait)..'\nReroll Tokens: '..fmt(r.RerollToken)..
        ' | Star Remnants: '..fmt(r.StarRemnant)..'\nHistorical Unique rate: 0.1%, not a guarantee. Current odds/cost unverified.'
end
function app:statsText()
    local u=self:unit() or {}
    return 'DMG '..fmt(u.damage)..' ['..fmt(u.damageGrade)..']\nSPA '..fmt(u.spa)..' ['..fmt(u.spaGrade)..
        ']\nRANGE '..fmt(u.range)..' ['..fmt(u.rangeGrade)..']\nScope: '..fmt(u.statScope)..
        '\nWorthiness: '..fmt(u.worthiness)..' | Stat Cubes: '..fmt(((self.snapshot or {}).resources or {}).StatCube)
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
    return 'Stage: '..fmt(s.stageName)..' / '..fmt(s.stage)..'\nSource: '..fmt(s.stageSource)..
        '\nMode: '..fmt(s.mode)..(s.modeVerified and ' (observed)' or ' (user-selected; unverified)')..
        '\nWave '..fmt(s.wave)..' | Yen '..fmt(s.cash)..'\nEquipped '..#(s.roster or {})..
        ' | own towers '..#(s.units or {})..' | path samples '..fmt(s.pathSamples)..
        '\nProfile: '..(self.profile and fmt(self.profile.stage) or 'none')..
        '\nEngine: '..self.engine.state..'\n'..self.engine.reason
end
function app:reportStatus()
    return 'Observed wins '..self.observedWins..' | losses '..self.observedLosses..
        '\nAuto-confirmed placements '..self.engine.placements..' | upgrades '..self.engine.upgrades..
        '\nSaved report: '..tostring(self.diskSaved)..' | retained log lines '..#self.log.lines..
        '\nStage, reward schemas and Android stability require live testing.'
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
function app:nextRukia()
    local list={}
    for _,u in ipairs((self.snapshot or {}).owned or {}) do if C.isRukia(u.id) then list[#list+1]=u end end
    if #list==0 then self:notice('No exact secret Rukia ID observed');return end
    local idx=0;for i,u in ipairs(list) do if u.uuid==cfg.selectedUuid then idx=i end end
    cfg.selectedUuid=list[idx%#list+1].uuid
    self.engine:stop('Selected unit changed','IDLE');self:notice('Selected observed Rukia '..(idx%#list+1))
end
function app:set(key,v)
    if self.engine.armed then self.engine:stop('Settings changed; review before rearming','IDLE') end
    local limits={reserve={0,1000000},maxRuns={1,100},maxSeconds={30,7200},traitCap={0,1000},statCap={0,1000}}
    if limits[key] then
        if not C.finite(v) then self:notice('Enter a finite number');return end
        cfg[key]=math.clamp(math.floor(v),limits[key][1],limits[key][2])
    elseif table.find({'inventoryPath','resourcePath','cashPath','recordCosts'},key) and type(v)=='string' then
        cfg[key]=v:sub(1,200);self.adapter.nextInventory=0
    end
end
function app:cycle(key,values)
    self.engine:stop('Target/mode changed; review before rearming','IDLE')
    cfg[key]=values[(table.find(values,cfg[key]) or 0)%#values+1]
    cfg.routeConfirmed=false;cfg.protocolConfirmed=false;cfg.replayFreeConfirmed=false
end
function app:toggle(key)
    self.engine:stop('Settings changed; review before rearming','IDLE')
    if table.find({'routeConfirmed','protocolConfirmed','replayFreeConfirmed'},key) and not cfg[key] then
        if not self.snapshot.stageVerified then self:notice('Observe the actual stage before confirming it');return end
        C.bindConsent(cfg,key,self.snapshot)
    end
    cfg[key]=not cfg[key]
end
function app:checkReady()
    local blockers=C.readiness(self.snapshot,self.profile,cfg)
    if #blockers==0 then self:notice('Prerequisites present; current transport still requires supervised live testing')
    else self:notice(table.concat(blockers,'; ')) end
end
function app:toggleFarm()
    if self.engine.armed then self.engine:stop('Stopped by user','IDLE');return end
    self.snapshot=self.adapter:observe(os.clock())
    if not self.adapter:remote('spawn_unit') then self:notice('No spawn_unit endpoint; combat unavailable');return end
    if cfg.upgrade and not self.adapter:remote('upgrade_unit_ingame') then
        self:notice('Upgrade endpoint missing; disable upgrades or leave combat off');return
    end
    if self.engine:arm(self.snapshot,self.profile) then self:notice('Experimental recorded combat armed')
    else self:notice(self.engine.reason) end
end
function app:record()
    self.engine:stop('Recording requested','IDLE')
    local p,err=self.adapter:record(self.snapshot,cfg.recordCosts)
    if not p then self:notice(err);return end
    self.profile=p;cfg.protocolConfirmed=false;cfg.routeConfirmed=false;cfg.replayFreeConfirmed=false
    self:notice('Recorded '..#p.entries..' placements; costs/ordering need supervised verification')
end
function app:saveSettings()
    if type(writefile)~='function' then self:notice('Local file saving unavailable');return false end
    local ok=pcall(function() writefile(filename,HTTP:JSONEncode({cfg=cfg,profile=self.profile,version=C.version})) end)
    self:notice(ok and 'Settings saved; Auto remains OFF on reload' or 'Settings save failed')
    return ok
end
function app:completeReport()
    local s=self.snapshot or {}
    local out={'[K] AA RUKIA '..C.version,'OFFLINE VERIFIED; LIVE GAME / DELTA UNVERIFIED',
        self:ownershipText(),self:objectiveText(),self:traitText(),self:statsText(),self:evolutionText(),
        self:farmText(),self:reportStatus(),
        'Inventory source: '..fmt(s.inventorySource),'Currency source: '..fmt(s.cashSource),
        'Premium mutation endpoints: none. Dungeon navigation/chest automation: unavailable.',
        'Profile positions/costs: user-recorded. Path samples: observed enemy motion only.',
        'Legacy import: '..fmt(self.legacySummary),'EXPOSED EQUIPPED RECORDS (UUIDs omitted):'}
    for _,u in ipairs(s.roster or {}) do
        out[#out+1]='slot='..fmt(u.slot)..' id='..fmt(u.id)..' cost='..fmt(u.cost)..' trait='..fmt(u.trait)
    end
    local names={}
    for i,v in ipairs(workspace:GetChildren()) do
        if i>60 then break end
        if v:IsA('Folder') or v:IsA('Model') then names[#names+1]=v.Name:sub(1,40) end
    end
    out[#out+1]='Workspace containers (bounded): '..table.concat(names,', ')
    out[#out+1]=self.log:text()
    return table.concat(out,'\n'):sub(1,65536)
end
function app:copyReport()
    local txt=self:completeReport()
    if type(setclipboard)=='function' then
        local ok=pcall(setclipboard,txt);self:notice(ok and 'Complete report copied' or 'Clipboard failed')
    else print(txt);self:notice('Clipboard unavailable; report printed') end
end
function app:copyConfig()
    local txt=HTTP:JSONEncode({cfg=cfg,profile=self.profile})
    if type(setclipboard)=='function' then pcall(setclipboard,txt);self:notice('Configuration copied; includes unit UUIDs')
    else self:notice('Clipboard unavailable') end
end
function app:saveReport()
    if type(writefile)~='function' then self.diskSaved=false;self:notice('Report remains in memory');return end
    self.diskSaved=pcall(writefile,reportFile,self:completeReport())
    self:notice(self.diskSaved and 'Bounded report saved locally' or 'Report save failed')
end
function app.stop()
    if not app.alive then return end
    app.engine:stop('Closed by user or replaced by new instance','IDLE')
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
log:add('BOOT','v6 observer; no GC/hook/global GUI scan; full auto OFF')
local bootOK,bootErr=pcall(function()
    app.snapshot=app.adapter:observe(os.clock());app.ui=makeUI(app)
end)
if not bootOK then app:error(bootErr);app.stop();warn('[K] AA initialization failed: '..tostring(bootErr));return end
task.spawn(function()
    while app.alive do
        local ok,err=pcall(function()
            local now=os.clock();local s=app.adapter:observe(now);app.snapshot=s
            local failure=app.adapter:poll()
            if failure then app.engine:reject(failure);app:notice(failure) end
            app.recorder:observe(s)
            app.observedWins=app.recorder.wins;app.observedLosses=app.recorder.losses
            local roster={}
            for _,u in ipairs(s.roster) do roster[#roster+1]=fmt(u.slot)..':'..u.id end
            local signature=table.concat(roster,',')
            if signature~=app.lastRoster then app.lastRoster=signature;log:add('EQUIPPED OBSERVED',signature) end
            local request=app.engine:tick(s,app.profile)
            if request then
                local sent,why=app.adapter:dispatch(request)
                if not sent then app.engine:reject(why) else log:add('ATTEMPT',request.kind..' | awaiting live feedback') end
            end
            if now-app.lastRefresh>=2 then app.lastRefresh=now;app.ui:refresh() end
        end)
        if not ok then app:error(err) end
        task.wait(.8)
    end
end)
