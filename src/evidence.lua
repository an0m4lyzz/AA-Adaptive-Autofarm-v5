-- Each instance owns its capability registry. Observed age is not server freshness.
return function(K)
    local E={capabilities={}}
    function E.register(c)
        assert(type(c)=='table' and type(c.id)=='string' and type(c.requiredFields)=='table','Invalid capability')
        E.capabilities[c.id]=K.copy(c)
    end
    function E.inspect(id,view,now)
        local cap=E.capabilities[id]
        local function no(reason) return {ready=false,reason=reason,evidence=cap} end
        if not cap or cap.status=='missing' then return no('Capability unavailable: '..tostring(id)) end
        if type(view)~='table' or not K.context(view.context) or not K.finite(now) then return no('Lifecycle identity unavailable') end
        for _,key in ipairs(cap.requiredFields) do
            local ev=type(view.evidence)=='table' and view.evidence[key]
            if view[key]==nil or type(ev)~='table' or ev.complete~=true then return no('Incomplete '..key) end
            if ev.schema~=cap.schema then return no('Unsupported '..key..' schema') end
            if not K.same(ev.context,view.context,ev.scope) then return no('Changed '..key..' context') end
            if type(ev.source)~='string' or ev.source=='' then return no('Missing '..key..' source') end
            if ev.scope~='static' then
                local maxAge=ev.scope=='offer' and 2 or 5
                if not K.finite(ev.observedAt) or now<ev.observedAt or now-ev.observedAt>maxAge then return no('Stale '..key) end
            end
        end
        return {ready=true,reason='Observed; server freshness not established',evidence=cap}
    end
    function E.capture(view,limits)
        limits=limits or {};local maxBytes=math.clamp(tonumber(limits.bytes) or 65536,256,65536)
        local maxNodes=math.clamp(tonumber(limits.nodes) or 2000,10,2000)
        local bytes,nodes,truncated=0,0,false
        local function safe(v,depth)
            nodes+=1;if nodes>maxNodes or depth>10 then truncated=true;return nil end
            local typ=type(v)
            if typ=='string' then
                local s=v:sub(1,300);if bytes+#s+8>maxBytes then truncated=true;return nil end
                bytes+=#s+8;return s
            elseif typ=='number' and K.finite(v) then bytes+=24;return v
            elseif typ=='boolean' then bytes+=8;return v
            elseif typ=='table' then
                local out={};local count=0
                for key,value in pairs(v) do
                    count+=1;if count>400 or bytes+40>maxBytes then truncated=true;break end
                    local lower=type(key)=='string' and key:lower() or ''
                    local private=lower:find('uuid',1,true) or lower:find('token',1,true) or lower:find('webhook',1,true)
                        or lower:find('secret',1,true) or lower:find('password',1,true) or lower=='accountid' or lower=='userid' or lower=='jobid'
                    if not private and (type(key)=='number' or (type(key)=='string' and #key<=100)) then
                        bytes+=type(key)=='string' and #key+4 or 12
                        local valueCopy=safe(value,depth+1);if valueCopy~=nil then out[key]=valueCopy end
                    end
                end
                return out
            end
            return nil
        end
        local allowed={'now','context','evidence','roster','towers','battlefield','threats','flow','dungeon','account','goals'}
        local out={}
        for _,key in ipairs(allowed) do if type(view)=='table' and view[key]~=nil then out[key]=safe(view[key],0) end end
        out.bytes=math.min(bytes,maxBytes);out.truncated=truncated;out.schema=K.schema
        return out
    end
    return E
end
