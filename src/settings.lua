-- Portable preferences only; all execution/spending permissions remain local.
return function(C)
    local S={}
    function S.name(name) return type(name)=='string' and #name>0 and #name<=40 and name:match('^[%w_%-]+$')~=nil end
    function S.migrate(raw)
        raw=type(raw)=='table' and (raw.settings or raw.cfg or raw) or {}
        local cfg=C.sanitize(raw)
        cfg.selectedUuid='';cfg.inventoryPath='';cfg.resourcePath='';cfg.cashPath=''
        return cfg
    end
    function S.validate(data,bytes)
        if bytes and bytes>65536 then return {valid=false,errors='Settings exceed64 KiB'} end
        if type(data)~='table' or data.schema~=1 or type(data.settings)~='table' then return {valid=false,errors='Unsupported settings schema'} end
        for key in pairs(data) do if key~='schema' and key~='settings' then return {valid=false,errors='Unexpected portable settings field'} end end
        for key,value in pairs(data.settings) do
            if C.defaults[key]==nil or type(value)~=type(C.defaults[key]) then return {valid=false,errors='Unknown/invalid setting '..tostring(key):sub(1,80)} end
        end
        return {valid=true,settings=S.migrate(data)}
    end
    function S.export(cfg) return {schema=1,settings=S.migrate(cfg)} end
    return S
end
