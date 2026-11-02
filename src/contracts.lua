-- Shared plain-table contracts. No game calls or imported execution.
local K={schema=1}
function K.finite(x) return type(x)=='number' and x==x and math.abs(x)<1e12 end
function K.context(c)
    if type(c)~='table' then return false end
    for _,k in ipairs({'accountId','universeId','epoch'}) do if not K.finite(c[k]) or c[k]<0 then return false end end
    for _,k in ipairs({'jobId','roundId','stageId','mode'}) do if type(c[k])~='string' or #c[k]<1 or #c[k]>200 then return false end end
    return true
end
function K.same(a,b,scope)
    if not K.context(a) or not K.context(b) then return false end
    for _,k in ipairs({'accountId','universeId','jobId','epoch'}) do if a[k]~=b[k] then return false end end
    if scope=='account' or scope=='static' then return true end
    return a.roundId==b.roundId and a.stageId==b.stageId and a.mode==b.mode
end
function K.cost(cost)
    if type(cost)~='table' then return false end
    local n=0
    for id,amount in pairs(cost) do
        n+=1
        if n>16 or type(id)~='string' or #id<1 or #id>100 or not K.finite(amount) or amount<0 then return false end
    end
    return true
end
function K.intent(x)
    return type(x)=='table' and type(x.id)=='string' and #x.id>0 and #x.id<=200
        and type(x.capabilityId)=='string' and type(x.kind)=='string' and K.context(x.context)
        and K.cost(x.cost) and K.finite(x.deadline) and type(x.expected)=='table'
end
function K.copy(t,depth)
    if type(t)~='table' then return t end
    depth=depth or 0;if depth>12 then return nil end
    local out={};local n=0
    for k,v in pairs(t) do
        n+=1;if n>2000 then break end
        if type(k)=='string' or type(k)=='number' then
            if type(v)=='table' then out[k]=K.copy(v,depth+1)
            elseif type(v)=='string' or type(v)=='boolean' or (K.finite(v)) then out[k]=v end
        end
    end
    return out
end
return K
