-- Observed normal casts only. Unknown toggles/stacking/meters are not guessed.
return function(C)
    local A={}
    function A.choose(s,cfg,lastById)
        if cfg.autoAbilities~=true or s.enemiesComplete~=true or type(s.enemyUnits)~='table' then return nil end
        local gap=math.max(1,C.finite(cfg.abilityGap) and cfg.abilityGap or 3)
        for _,u in ipairs(s.units or {}) do
            local equipped=false
            for _,r in ipairs(s.roster or {}) do if r.uuid==u.uuid and r.id==u.id then equipped=true;break end end
            local aa=u.activeAttack
            local known=type(aa)=='string' and aa~='' and aa~='nil' and not aa:find(':',1,true)
            if equipped and known and u.role~='buff' and u.castReady==true and C.finite(u.lastCast) and C.finite(u.cooldown)
                and u.cooldown>0 and C.finite(u.range) and u.range>0 and C.distance(u.pos,u.pos)==0
                and (not lastById[u.id] or s.now-lastById[u.id]>=gap) then
                for _,enemy in ipairs(s.enemyUnits) do
                    if C.finite(enemy.health) and enemy.health>0 and C.distance(u.pos,enemy.pos)<=u.range then return u end
                end
            end
        end
        return nil
    end
    function A.proof(p,u)
        return u.key==p.key and u.uuid==p.uuid and u.id==p.id and u.activeAttack==p.activeAttack
            and C.finite(u.lastCast) and C.finite(p.lastCast) and u.lastCast>p.lastCast
    end
    return A
end
