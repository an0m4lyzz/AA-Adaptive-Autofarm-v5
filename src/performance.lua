-- Bounded reversible local changes. No map deletion or shared-service patches.
return function()
    local P={changes={}}
    local function set(object,key,value)
        if not object then return false end
        local ok,old=pcall(function()return object[key] end)
        if not ok or type(old)~=type(value) then return false end
        for _,c in ipairs(P.changes) do if c.object==object and c.key==key then return true end end
        local changed=pcall(function()object[key]=value end)
        if changed then P.changes[#P.changes+1]={object=object,key=key,old=old,value=value} end
        return changed
    end
    function P.restore()
        for i=#P.changes,1,-1 do
            local c=P.changes[i]
            pcall(function() if c.object[c.key]==c.value then c.object[c.key]=c.old end end)
        end
        table.clear(P.changes)
    end
    function P.apply(profile,handles)
        P.restore();handles=handles or {};local count=0
        if profile=='Low' then
            if set(handles.light,'GlobalShadows',false) then count+=1 end
            for i,fx in ipairs(handles.effects or {}) do if i>64 then break end;if set(fx,'Enabled',false) then count+=1 end end
        end
        return {applied=count,reason=count>0 and 'Local changes; device performance still unmeasured' or 'No supported reversible changes'}
    end
    return P
end
