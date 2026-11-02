-- Bounded, redacted diagnostics and an independent explicit outbound queue.
return function(C,io)
    io=io or {};local R={events={},dropped=0,outcomes={},order={},wins=0,losses=0,unknown=0,
        queue={},notified={},notificationOrder={},notificationState='OFF'}
    local function redact(text)
        text=tostring(text):gsub('[\r\n]',' ')
        text=text:gsub('https?://[^%s]*[Ww][Ee][Bb][Hh][Oo][Oo][Kk][Ss]/[^%s]+','<webhook>')
        text=text:gsub('%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x','<unit>')
        return text:gsub(string.rep('%x',32),'<unit>')
    end
    function R:record(event)
        if type(event)~='table' then return end
        self.events[#self.events+1]={kind=redact(event.kind or 'event'):sub(1,40),detail=redact(event.detail or ''):sub(1,200)}
        if #self.events>500 then table.remove(self.events,1);self.dropped+=1 end
    end
    local function change(self,result,delta)
        local k=result=='Victory' and 'wins' or result=='Defeat' and 'losses' or 'unknown';self[k]=math.max(0,self[k]+delta)
    end
    function R:outcome(round,result)
        if type(round)~='string' or #round>200 then return false end
        if result~='Victory' and result~='Defeat' then result='unknown' end
        local before=self.outcomes[round]
        if before==result then return false end
        if before then
            if before~='unknown' and result~='unknown' then result='unknown';self.conflicted=self.conflicted or {};self.conflicted[round]=true end
            if self.conflicted and self.conflicted[round] then result='unknown' end
            change(self,before,-1)
        else self.order[#self.order+1]=round end
        self.outcomes[round]=result;change(self,result,1)
        if #self.order>100 then local old=table.remove(self.order,1);self.outcomes[old]=nil;if self.conflicted then self.conflicted[old]=nil end end
        self:record({kind='RESULT',detail=result..' | genuine observed outcome; rewards not inferred'})
        return true
    end
    function R:checkpoint()
        local out={wins=self.wins,losses=self.losses,unknown=self.unknown,order={},outcomes={},conflicted={}}
        for _,id in ipairs(self.order) do out.order[#out.order+1]=id;out.outcomes[id]=self.outcomes[id];out.conflicted[id]=self.conflicted and self.conflicted[id] or nil end
        return out
    end
    function R:restore(data)
        if type(data)~='table' or type(data.order)~='table' or #data.order>100 or type(data.outcomes)~='table' then return false end
        for _,k in ipairs({'wins','losses','unknown'}) do if not C.finite(data[k]) or data[k]<0 or data[k]%1~=0 or data[k]>1e9 then return false end end
        local order,outcomes,conflicted={},{},{}
        for _,id in ipairs(data.order) do
            local value=data.outcomes[id]
            if type(id)~='string' or #id>200 or outcomes[id] or not table.find({'Victory','Defeat','unknown'},value) then return false end
            order[#order+1]=id;outcomes[id]=value
            if type(data.conflicted)=='table' and data.conflicted[id]==true then conflicted[id]=true end
        end
        self.order=order;self.outcomes=outcomes;self.conflicted=conflicted
        self.wins=data.wins;self.losses=data.losses;self.unknown=data.unknown;return true
    end
    function R:render(limit)
        limit=math.clamp(C.finite(limit) and limit or 64000,500,64000)
        local head='RETAINED RUN SUMMARY | wins='..self.wins..' losses='..self.losses..' unknown='..self.unknown..
            '\nCurrency changes are observations, not attributed rewards. Retained events='..#self.events..' dropped='..self.dropped
        local out={head};local size=#head
        for i=#self.events,1,-1 do
            local e=self.events[i];local line=e.kind..' | '..e.detail
            if size+#line+1>limit then break end
            out[#out+1]=line;size+=#line+1
        end
        return table.concat(out,'\n')
    end
    function R:queueNotification(event,consent)
        if type(consent)~='table' or consent.enabled~=true or type(consent.url)~='string'
            or not consent.url:match('^https://discord%.com/api/webhooks/[%w_%-]+/[%w_%-]+$') then return false end
        if type(event)~='table' or type(event.id)~='string' or #event.id>200 or self.notified[event.id] or #self.queue>=20 then return false end
        self.notified[event.id]=true;self.notificationOrder[#self.notificationOrder+1]=event.id
        if #self.notificationOrder>100 then self.notified[table.remove(self.notificationOrder,1)]=nil end
        self.queue[#self.queue+1]={text=redact(event.text or ''):sub(1,1500),url=consent.url,attempts=0,due=0}
        self.notificationState='Queued with explicit send permission';return true
    end
    function R:tick(now)
        if self.worker then
            if now-self.worker.at>8 and not self.worker.expired then
                self.worker.expired=true;self.notificationState='Delivery unknown; no retry while worker outstanding'
            end
            return
        end
        local event=self.queue[1];if not event or now<event.due then return end
        if type(io.start)~='function' then self.notificationState='HTTP capability unavailable';return end
        event.attempts+=1
        local mark={at=now};self.worker=mark
        local function done(code)
            if self.worker~=mark then return end
            self.worker=nil
            if self.queue[1]~=event then self.notificationState='Previous request finished after permission changed';return end
            if mark.expired then table.remove(self.queue,1);self.notificationState='Late HTTP result; previous delivery unconfirmed';return end
            if code==429 and event.attempts<3 then event.due=now+30;self.notificationState='Rate limited; bounded retry pending'
            else table.remove(self.queue,1);self.notificationState=type(code)=='number' and code>=200 and code<300 and 'Delivered' or 'HTTP failed/unconfirmed; event dropped' end
        end
        local ok=pcall(io.start,event.url,event.text,done)
        if not ok then done(nil) end
    end
    function R:revokeNotifications()
        self.queue={};self.notified={};self.notificationOrder={};self.notificationState=self.worker and 'Permission revoked; already-sent HTTP cannot be undone' or 'OFF'
    end
    return R
end
