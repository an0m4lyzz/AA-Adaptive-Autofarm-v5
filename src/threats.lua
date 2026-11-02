-- Pure summaries of explicitly observed enemies; missing mechanics stay unknown.
return function(C)
    local T={}
    function T.summarize(view)
        local out={complete=view.enemiesComplete==true,alive=0,positions={},bossAlive=nil,air=nil,shields=nil}
        if type(view.enemies)~='table' or #view.enemies>120 then out.complete=false;return out end
        local knownAir,knownShield,bossKnown=true,true,true
        local air,shields,boss=0,0,false
        for _,u in ipairs(view.enemies) do
            if type(u)~='table' or not C.finite(u.health) or C.distance(u.pos,u.pos)~=0 then out.complete=false
            elseif u.health>0 then
                out.alive+=1;out.positions[#out.positions+1]=u.pos
                if type(u.air)=='boolean' then if u.air then air+=1 end else knownAir=false end
                if C.finite(u.shield) and u.shield>=0 then shields+=u.shield else knownShield=false end
                if type(u.boss)=='boolean' then boss=boss or u.boss else bossKnown=false end
            end
        end
        if out.complete then
            if knownAir then out.air=air end;if knownShield then out.shields=shields end
            if bossKnown then out.bossAlive=boss end
        end
        return out
    end
    function T.near(summary,pos,range)
        if type(summary)~='table' or not summary.complete or C.distance(pos,pos)~=0 or not C.finite(range) or range<=0 then return nil end
        for _,p in ipairs(summary.positions) do if C.distance(p,pos)<=range then return true end end
        return false
    end
    return T
end
