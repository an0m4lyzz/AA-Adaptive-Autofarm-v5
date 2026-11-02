-- One writer for domain intents. Transport success alone never confirms an action.
return function(K,evidence,budget,io)
    local A={current=nil,halted=false,reason=''}
    local function decision(kind,reason,intent) return {kind=kind,reason=reason,intent=intent} end
    function A.submit(intent,view,run)
        if A.current then return decision('wait','Action awaits exact feedback') end
        if A.halted then return decision('stop',A.reason) end
        if not K.intent(intent) or not K.same(intent.context,view.context) or not K.finite(view.now) or view.now>=intent.deadline then
            return decision('stop','Invalid, expired or changed-context intent')
        end
        local observed=evidence.inspect(intent.capabilityId,view,view.now)
        if not observed.ready then return decision('stop',observed.reason) end
        local reserved,why=budget.reserve(intent)
        if not reserved then return decision('stop',why or 'Budget checkpoint failed') end
        -- The sent flag is durable before dispatch; a crash between these steps
        -- may conservatively fence an unsent action, never duplicate a paid one.
        if not budget.sent(intent.id) then budget.cancel(intent.id);return decision('stop','Sent checkpoint failed') end
        A.current=K.copy(intent)
        local ok,sent,reason=pcall(io.send,intent,run)
        if not ok or sent~=true then
            A.halted=true;A.reason='Dispatch unconfirmed: '..tostring(ok and reason or sent)
            return decision('stop',A.reason)
        end
        return decision('action','Sent; waiting for operation-specific receipt',intent)
    end
    function A.observe(view)
        local p=A.current;if not p then return nil end
        local ok,r=pcall(io.verify or function()end,p,view)
        if ok and type(r)=='table' and r.intentId==p.id and r.status=='confirmed' and r.proof==true
            and K.same(p.context,r.context,p.expected.scope) then
            r.debits=r.debits or {}
            if budget.settle(r) then A.current=nil;return r end
        end
        if K.finite(view.now) and view.now>=p.deadline and not p.timedOut then
            p.timedOut=true;A.halted=true;A.reason='Action deadline exceeded; no automatic resend'
            return {intentId=p.id,status='uncertain',context=K.copy(p.context),observedAt=view.now}
        end
        return nil
    end
    function A.stop(reason) A.halted=true;A.reason=tostring(reason or 'Stopped') end
    function A.pending() return A.current end
    return A
end
