-- Opt-in, durable teleport continuation. This module never performs a game action.
return function(C,io,env,identity,clock)
    io=io or {};env=env or {};identity=identity or {};clock=clock or os.time
    local TTL=7200
    local TICKET='K_AA_Rukia_v6_FollowTicket'
    local function integer(v,min) return type(v)=='number' and v==v and v<math.huge and v>=min and v%1==0 and v<=9007199254740991 end
    local function text(v,max) return type(v)=='string' and #v>0 and #v<=(max or 160) and not string.find(v,'%c') end
    local identityOK=integer(identity.userId,1) and integer(identity.universeId,1) and text(identity.jobId,128)
    local uid=identity.userId;local universe=identity.universeId;local job=identity.jobId
    local key='K_AA_Rukia_v6_FollowRegistry_'..tostring(uid)..'_'..tostring(universe)
    if type(env[key])~='table' then env[key]={counter=0,blocked=false} end
    local registry=env[key]
    local S={status='off',armed=false,following=false}
    local current,candidate,closed=nil,false,false
    local function now()
        local ok,value=pcall(clock);if ok and integer(value,0) then return value end
        return nil
    end
    local function choice(v)
        if v=='1' or v=='2' or v=='3' then return v end
        if integer(v,1) and v<=3 then return tostring(v) end
        return nil
    end
    local function expected(v)
        if type(v)~='table' or (v.kind~='replay' and v.kind~='next_story' and v.kind~='dungeon_enter_room') then return nil end
        if not text(v.mode,40) then return nil end
        if (v.kind=='replay' or v.kind=='next_story') and (not text(v.stage) or not integer(v.placeId,1)) then return nil end
        if v.stage~=nil and not text(v.stage) then return nil end
        if v.placeId~=nil and not integer(v.placeId,1) then return nil end
        local e={kind=v.kind,stage=v.stage,mode=v.mode,placeId=v.placeId}
        if v.kind=='dungeon_enter_room' then
            if v.mode~='Dungeon' or not integer(v.depth,0) or not choice(v.choice) then return nil end
            e.depth=v.depth;e.choice=choice(v.choice)
        elseif v.mode~='Story' then return nil end
        return e
    end
    local function checkpointData(v)
        if type(v)~='table' then return nil end
        local d={}
        for _,k in ipairs({'stage','mode'}) do if text(v[k]) then d[k]=v[k] end end
        for _,k in ipairs({'placeId','depth','wave'}) do if integer(v[k],0) then d[k]=v[k] end end
        if v.choice~=nil then
            d.choice=choice(v.choice);if not d.choice then return nil,'invalid checkpoint choice' end
        end
        for k,max in pairs({spent=1000000,shopCap=1000000,runs=100,remainingRuns=100}) do
            if v[k]~=nil then
                if not integer(v[k],0) or v[k]>max then return nil,'invalid checkpoint '..k end
                d[k]=v[k]
            end
        end
        for _,k in ipairs({'openChests','replayFree','startWaves','nextStory','shrines'}) do
            if v[k]~=nil then
                if type(v[k])~='boolean' then return nil,'invalid checkpoint '..k end
                d[k]=v[k]
            end
        end
        for _,k in ipairs({'shrineItems','budgetId','macroName','macroSignature'}) do
            if v[k]~=nil then
                if type(v[k])~='string' or #v[k]>200 or v[k]:find('%c') then return nil,'invalid checkpoint '..k end
                d[k]=v[k]
            end
        end
        if v.macroRoster~=nil then
            if type(v.macroRoster)~='table' or #v.macroRoster<1 or #v.macroRoster>6 then return nil,'invalid macro roster approval' end
            d.macroRoster={};local seen={};local count=0
            for k,r in pairs(v.macroRoster) do
                count+=1
                if not integer(k,1) or k>#v.macroRoster or type(r)~='table' or not integer(r.slot,1) or r.slot>6 or seen[r.slot]
                    or not text(r.id,100) or not text(r.uuid,128) then return nil,'invalid macro roster approval' end
                seen[r.slot]=true;d.macroRoster[k]={slot=r.slot,id=r.id,uuid=r.uuid}
            end
            if count~=#v.macroRoster then return nil,'sparse macro roster approval' end
        end
        return d
    end
    local function sanitize(m)
        local t=now()
        if not identityOK or not t or type(m)~='table' or m.schema~=1 or m.userId~=uid or m.universeId~=universe then return nil,'identity or schema' end
        if not integer(m.expires,0) or m.expires<=t or m.expires>t+TTL or not text(m.nonce,200) or not text(m.originJob,128) then return nil,'expiry or nonce' end
        if type(m.follow)~='boolean' or type(m.armed)~='boolean' or type(m.inFlight)~='boolean' then return nil,'permission schema' end
        if type(m.mode)~='string' or #m.mode>40 then return nil,'mode schema' end
        local e=nil
        if m.expected~=nil then e=expected(m.expected);if not e then return nil,'expected transition schema' end end
        if m.armed and (not m.follow or not e) then return nil,'missing explicit transition' end
        if m.deadline~=nil and (not integer(m.deadline,0) or m.deadline>m.expires) then return nil,'deadline schema' end
        local checkpoint,why=checkpointData(m.checkpoint)
        if m.checkpoint~=nil and not checkpoint then return nil,why or 'checkpoint schema' end
        return {schema=1,userId=uid,universeId=universe,expires=m.expires,nonce=m.nonce,follow=m.follow,armed=m.armed,
            expected=e,inFlight=m.inFlight,originJob=m.originJob,mode=m.mode,deadline=m.deadline,checkpoint=checkpoint}
    end
    local function read()
        if type(io.read)~='function' then return nil,'durable read unavailable' end
        local ok,m=pcall(io.read);if not ok then return nil,'durable read failed' end
        if m==nil then return nil,'no saved follow permission' end
        return sanitize(m)
    end
    local function write(m)
        if type(io.write)~='function' then return false end
        local ok,result=pcall(io.write,m);return ok and result==true
    end
    local function fail(why,status)
        if registry.blocked and not status then why=S.reason or 'durable revocation failed';status='revocation_failed' end
        S.armed=false;candidate=false;S.status=status or 'blocked';S.reason=why
        return false,why
    end
    local function bootstrap()
        -- Fixed entrypoint and path. JSON can grant/revoke permission, never supply executable code.
        return 'local UID='..tostring(uid)..';local UNIVERSE='..tostring(universe)..'\n'..[=[
local function run()
    local function int(v) return type(v)=='number' and v==v and v>=0 and v<math.huge and v%1==0 and v<=9007199254740991 end
    local function good(m)
        local t=os.time()
        return type(m)=='table' and m.schema==1 and m.userId==UID and m.universeId==UNIVERSE
            and m.follow==true and type(m.armed)=='boolean' and type(m.inFlight)=='boolean'
            and int(m.expires) and m.expires>t and m.expires<=t+7200
            and type(m.nonce)=='string' and #m.nonce>0 and #m.nonce<=200 and not string.find(m.nonce,'%c')
            and type(m.originJob)=='string' and #m.originJob>0 and #m.originJob<=128
    end
    local player
    for _=1,120 do
        if game:IsLoaded() then player=game:GetService('Players').LocalPlayer;if player then break end end
        task.wait(0.25)
    end
    if not player or player.UserId~=UID or game.GameId~=UNIVERSE then return end
    local globals=type(getgenv)=='function' and getgenv() or _G
    local reg=globals['K_AA_Rukia_v6_FollowRegistry_'..tostring(UID)..'_'..tostring(UNIVERSE)]
    if type(reg)=='table' and reg.blocked then return end
    local function read()
        local ok,m=pcall(function()
            return game:GetService('HttpService'):JSONDecode(readfile('K_AA_Rukia_v6_Follow_'..tostring(UID)..'.json'))
        end)
        if ok and good(m) then return m end
    end
    local m=read();if not m then return end
    local previous=globals.K_AA_Rukia_v6_FollowTicket
    if type(previous)=='table' and previous.nonce==m.nonce and previous.jobId==game.JobId then return end
    local source=game:HttpGet('https://raw.githubusercontent.com/an0m4lyzz/AA-Adaptive-Autofarm-v5/main/main.lua')
    local latest=read();if not latest or latest.nonce~=m.nonce then return end
    if type(reg)=='table' and reg.blocked then return end
    local loader=loadstring(source);if type(loader)~='function' then return end
    globals.K_AA_Rukia_v6_FollowTicket={nonce=latest.nonce,userId=UID,universeId=UNIVERSE,jobId=game.JobId}
    loader()
end
pcall(run)
]=]
    end
    local function registerQueue()
        if registry.queuedJob==job then return true end
        local ok,result=false,false
        if type(io.queue)=='function' then ok,result=pcall(io.queue,bootstrap()) end
        if not ok or result~=true then return false end
        registry.queuedJob=job;return true
    end
    function S:load()
        candidate=false;self.armed=false
        local m,why=read();current=m
        if registry.blocked then
            self.following=false
            local _,reason=fail('durable revocation failed; saved marker may remain armed','revocation_failed')
            return m and sanitize(m) or nil,false,reason
        end
        if not m then self.following=false;self.status='off';self.reason=why;return nil,false,why end
        self.following=m.follow
        if m.follow and not closed and not registry.blocked and not registerQueue() then
            local revoked,reason=self:revoke('teleport queue unavailable')
            return nil,false,revoked and 'teleport queue unavailable' or reason
        end
        local ticket=env[TICKET]
        candidate=not closed and not registry.blocked and m.follow and m.armed and not m.inFlight and job~=m.originJob
            and type(ticket)=='table' and ticket.nonce==m.nonce and ticket.userId==uid and ticket.universeId==universe and ticket.jobId==job
        if m.deadline and now()>=m.deadline then candidate=false end
        self.status=candidate and 'resume_pending' or (m.follow and 'following' or 'off')
        self.reason=candidate and 'verify expected transition before arming' or 'GUI follow only; explicit arm required'
        -- Caller gets a fresh sanitized copy, never our mutable internal record.
        return sanitize(m),candidate,self.reason
    end
    function S:follow(enabled)
        if enabled~=true then return self:revoke('follow disabled') end
        if closed then return fail('session closed') end
        local t=now();if not identityOK or not t then return fail('valid user, universe, actual job and clock required') end
        if registry.blocked then return fail('durable revocation failed; retry stop before enabling','revocation_failed') end
        if current and current.follow and current.expires>t and self.following then return true end
        registry.counter=(integer(registry.counter,0) and registry.counter or 0)+1
        local nonce=tostring(uid)..':'..tostring(universe)..':'..tostring(t)..':'..tostring(registry.counter)..':'..job
        local m={schema=1,userId=uid,universeId=universe,expires=t+TTL,nonce=nonce,follow=true,armed=false,inFlight=false,originJob=job,mode=''}
        if not write(m) then
            registry.blocked=true;self.following=false
            return fail('durable follow save failed; previous saved permission may remain','revocation_failed')
        end
        current=m;self.following=true;self.armed=false;candidate=false
        if not registerQueue() then
            local revoked,why=self:revoke('teleport queue unavailable')
            return false,revoked and 'teleport queue unavailable' or why
        end
        self.status='following';self.reason='GUI follow enabled; automatic play requires explicit arm'
        return true
    end
    function S:checkpoint(state)
        local function reject(why)
            local revoked,reason=self:revoke(why)
            return false,revoked and why or reason
        end
        if closed or registry.blocked then return fail('session closed or durable revocation failed') end
        if not current or not self.following then return fail('enable follow before checkpoint') end
        if type(state)~='table' then return reject('checkpoint state required') end
        local m=select(1,sanitize(current));if not m or not m.follow then return reject('follow permission expired') end
        local e=nil;if state.expected~=nil then e=expected(state.expected);if not e then return reject('invalid expected transition') end end
        if state.armed==true and not e then return reject('armed continuation requires an expected transition') end
        local flight=state.inFlight~=nil and state.inFlight~=false
        m.armed=state.armed==true and not flight;m.inFlight=flight;m.expected=e;m.originJob=job
        m.mode=text(state.mode,40) and state.mode or (e and e.mode or '')
        local data,why=checkpointData(state.checkpoint or state)
        if not data then return reject(why or 'checkpoint schema') end
        m.checkpoint=data
        if state.deadline~=nil then
            if not integer(state.deadline,0) or state.deadline<=now() or state.deadline>m.expires then return reject('invalid continuation deadline') end
            m.deadline=state.deadline
        else m.deadline=nil end
        if not write(m) then
            registry.blocked=true;self.following=false
            return fail('durable checkpoint save failed; previous marker may remain armed','revocation_failed')
        end
        current=m;candidate=false;self.armed=m.armed;self.status=m.armed and 'armed' or 'following';self.reason=flight and 'in-flight action blocks continuation' or nil
        return true
    end
    function S:revoke(reason)
        candidate=false;self.armed=false;self.following=false;env[TICKET]=nil
        if not identityOK or not now() then return fail('durable revocation unavailable: invalid identity or clock','revocation_failed') end
        local m=select(1,read()) or current
        if type(m)~='table' then
            m={schema=1,userId=uid,universeId=universe,expires=now()+TTL,nonce='revoked:'..tostring(now()),originJob=job,mode=''}
        end
        m.follow=false;m.armed=false;m.inFlight=false;m.expected=nil;m.deadline=nil
        if not write(m) then
            registry.blocked=true;return fail('durable revocation failed; queued reload may remain possible','revocation_failed')
        end
        registry.blocked=false;current=m;self.status='off';self.reason=reason or 'revoked';return true
    end
    function S:validateResume(snapshot)
        if closed or registry.blocked or not candidate or not current then return fail('no armed teleport continuation') end
        local m,why=read();if not m or m.nonce~=current.nonce or not m.follow or not m.armed or m.inFlight then return fail(why or 'saved continuation changed') end
        if m.deadline and now()>=m.deadline then return fail('continuation deadline expired') end
        local e=m.expected;local s=snapshot
        if type(s)~='table' or job==m.originJob or s.jobId~=job then return false,'different actual destination job required' end
        if s.stageVerified~=true or s.modeVerified~=true or not text(s.stage) or not integer(s.placeId,1) or s.mode~=e.mode
            or (e.stage~=nil and s.stage~=e.stage) or (e.placeId~=nil and s.placeId~=e.placeId) then
            return false,'expected stage, mode and place not observed'
        end
        if e.kind=='dungeon_enter_room' then
            local d=s.dungeon
            local level=type(d)=='table' and d.level or nil
            if type(d)~='table' or d.valid~=true or type(level)~='table' or level.active~=true
                or not integer(level.depth,1) or type(level.choice)~='string' or not choice(level.choice)
                or level.depth~=e.depth or level.choice~=e.choice then
                return false,'expected active native Dungeon room not observed'
            end
            -- Profile replication may lag the actual level. Never manufacture a room
            -- identity by combining the profile's choice with the native level's depth.
            if (d.depth~=nil and d.depth~=level.depth) or (d.choice~=nil and choice(d.choice)~=level.choice) then
                return false,'Dungeon profile and native room identity disagree'
            end
        end
        -- Consume first: a failed save must not start a controller with reusable permission.
        m.armed=false;m.expected=nil;m.inFlight=false;m.deadline=nil
        if not write(m) then
            registry.blocked=true;self.following=false
            return fail('durable continuation consumption failed; automatic resume blocked','revocation_failed')
        end
        current=m;candidate=false;self.armed=false;env[TICKET]=nil;self.status='following';self.reason='expected transition verified; saved permission consumed'
        return true
    end
    function S:close()
        local ok,why=self:revoke('closed');closed=true;return ok,why
    end
    function S:text()
        return 'Follow: '..self.status..(self.reason and (' — '..self.reason) or '')
    end
    return S
end
