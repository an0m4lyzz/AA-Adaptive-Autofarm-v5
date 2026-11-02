-- Durable reservation ledger. It never sends gameplay requests.
return function(K,io,identity,clock)
    local B={state={schema=1,identity=K.copy(identity),caps={},spent={},reservations={},closed={}}}
    local function persist(nextState,allowVolatile)
        -- Free round actions never rewrite the account ledger. Their same-job
        -- uncertainty fence is retained by the native transport, not disk IO.
        if allowVolatile then B.state=nextState;B.volatile=true;return true end
        local ok,result=false,false
        if type(io.write)=='function' then ok,result=pcall(io.write,K.copy(nextState)) end
        if not ok or result~=true then
            if allowVolatile then B.state=nextState;B.volatile=true;return true end
            return false,'Budget checkpoint write/read failed'
        end
        B.state=nextState;return true
    end
    local function sameIdentity(a,b) return type(a)=='table' and type(b)=='table' and a.accountId==b.accountId and a.universeId==b.universeId end
    function B.review(policy,view)
        if type(policy)~='table' or not K.cost(policy.caps) or type(policy.allowedOps)~='table'
            or type(policy.id)~='string' or not K.finite(policy.expires) or policy.expires<=clock()
            or policy.expires>clock()+7200 or not K.context(view.context) or not sameIdentity(identity,view.context) then return nil end
        return {id=policy.id,caps=K.copy(policy.caps),allowedOps=K.copy(policy.allowedOps),expires=policy.expires,
            identity=K.copy(identity),context=K.copy(view.context),reviewedAt=clock()}
    end
    function B.grant(preview,ack)
        if B.frozen or (type(io.canPay)=='function' and io.canPay()~=true) then return nil,'Account storage unavailable or needs reconciliation' end
        if ack~=true or type(preview)~='table' or not sameIdentity(preview.identity,identity)
            or not K.finite(preview.reviewedAt) or clock()-preview.reviewedAt>30 or preview.expires<=clock() then return nil end
        for _,r in pairs(B.state.reservations) do if r.sent and next(r.cost)~=nil then return nil,'Outstanding debit unresolved' end end
        -- Reusing an ID retains all original debits and caps; START cannot reset it.
        if B.state.grant and B.state.grant.id==preview.id then return K.copy(B.state.grant) end
        local nextState={schema=1,identity=K.copy(identity),caps=K.copy(preview.caps),spent={},reservations={},closed={},grant=K.copy(preview)}
        if not persist(nextState) then return nil end
        return K.copy(B.state.grant)
    end
    function B.remaining(resource)
        local n=(B.state.caps[resource] or 0)-(B.state.spent[resource] or 0)
        for _,r in pairs(B.state.reservations) do n-=r.cost[resource] or 0 end
        return math.max(0,n)
    end
    function B.reserve(intent)
        if not K.intent(intent) or B.state.reservations[intent.id] or B.state.closed[intent.id] then return false,'Invalid/duplicate intent' end
        local paid=false;for _,n in pairs(intent.cost) do if n>0 then paid=true end end
        local grant=B.state.grant
        if paid then
            if not grant or intent.permissionId~=grant.id or grant.expires<=clock()
                or grant.allowedOps[intent.capabilityId]~=true or not sameIdentity(intent.context,identity) then return false,'Spending grant unavailable' end
            for _,r in pairs(B.state.reservations) do if r.sent and next(r.cost)~=nil then return false,'Outstanding account action' end end
            for id,n in pairs(intent.cost) do if n>B.remaining(id) or n<=0 or (B.state.caps[id] or 0)<=0 then return false,'Resource cap reached: '..id end end
        end
        local state=K.copy(B.state);state.reservations[intent.id]={cost=K.copy(intent.cost),context=K.copy(intent.context),sent=false}
        return persist(state,not paid)
    end
    function B.sent(id)
        if not B.state.reservations[id] then return false end
        local state=K.copy(B.state);state.reservations[id].sent=true
        return persist(state,next(state.reservations[id].cost)==nil)
    end
    function B.cancel(id)
        local r=B.state.reservations[id];if not r or r.sent then return false end
        local state=K.copy(B.state);state.reservations[id]=nil;return persist(state,next(r.cost)==nil)
    end
    function B.settle(receipt)
        local r=type(receipt)=='table' and B.state.reservations[receipt.intentId]
        if not r or not r.sent then return false end
        if receipt.status~='confirmed' or receipt.proof~=true or not K.cost(receipt.debits or {}) then return false end
        for id,n in pairs(r.cost) do if (receipt.debits or {})[id]~=n then return false end end
        for id,n in pairs(receipt.debits or {}) do if r.cost[id]~=n then return false end end
        local state=K.copy(B.state)
        for id,n in pairs(r.cost) do state.spent[id]=(state.spent[id] or 0)+n end
        state.reservations[receipt.intentId]=nil;state.closed[receipt.intentId]=true
        local count=0;for _ in pairs(state.closed) do count+=1 end
        if count>2000 then return false,'Ledger full; review a new budget' end
        return persist(state,next(r.cost)==nil)
    end
    function B.checkpoint() return K.copy(B.state) end
    function B.invalidateRound(context)
        local state=K.copy(B.state)
        for id,r in pairs(state.reservations) do
            if next(r.cost)==nil and not K.same(r.context,context) then state.reservations[id]=nil end
        end
        return persist(state,true)
    end
    function B.restore(data,currentIdentity)
        if type(data)~='table' or data.schema~=1 or not sameIdentity(data.identity,identity)
            or not sameIdentity(identity,currentIdentity) or not K.cost(data.caps) or not K.cost(data.spent)
            or type(data.reservations)~='table' or type(data.closed)~='table' then return false end
        local count=0
        for id,r in pairs(data.reservations) do
            count+=1
            if count>32 or type(id)~='string' or type(r)~='table' or not K.cost(r.cost) or not K.context(r.context) or type(r.sent)~='boolean' then return false end
        end
        B.state=K.copy(data);return true
    end
    return B
end
