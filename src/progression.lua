return function(C)
    local P={}
    function P.rankRoutes(routes)
        local best,score
        for i,r in ipairs(routes or {}) do
            if i>100 then break end
            if r.useful==true and C.finite(r.totalSeconds) and r.totalSeconds>0 and C.finite(r.rewardCount)
                and r.rewardCount>=0 and C.finite(r.attempts) and r.attempts>0 and C.finite(r.wins) and r.wins>0 then
                -- Reward total includes failed attempts' measured time; do not
                -- multiply by win rate a second time or invent unknown yields.
                local value=r.rewardCount/r.totalSeconds
                if not best or value>score then best=r;score=value end
            end
        end
        return best
    end
    function P.plan(view,catalog,goal)
        goal=goal or {};local kind=goal.kind or 'Acquire'
        local p={objective=kind,stop=false,deficits={},unknown={}}
        local fresh=C.finite(view.now) and C.finite(view.ownedAt) and view.now>=view.ownedAt and view.now-view.ownedAt<=15
        local selected;if kind~='Acquire' then selected=goal.selectedUuid end
        local unit=fresh and C.chooseRukia(view.owned,selected)
        if unit and unit.statScope~='collection' then unit=nil end
        p.owned=unit and true or nil
        if kind=='Acquire' and unit then p.stop=true;p.objective='Rukia ownership observed';return p end
        if not unit and kind~='Acquire' then p.blocker='Selected permanent Rukia copy is not observed';return p end
        if unit then
            local trait=C.hasTrait(unit,goal.trait or 'Unique');local stats=C.statsMet(unit,goal.grade or 'SSS')
            local evolved=unit.id=='rukia_2_evo'
            if (kind=='Trait' and trait) or (kind=='Stats' and stats) or (kind=='Evolution' and evolved)
                or (kind=='Build' and trait and stats and evolved) then
                p.stop=true;p.objective='Selected '..kind..' goal observed';return p
            end
        end
        local current=type(catalog)=='table' and catalog.current
        if type(current)~='table' or current.verified~=true or not catalog.build or view.build~=catalog.build then
            p.blocker=type(current)=='table' and current.reason or 'Current Rukia route/build schema is unverified'
            p.blocker=p.blocker or 'Current catalog/build identity mismatch';return p
        end
        if kind=='Acquire' then
            if current.available~=true then p.blocker='Current Rukia availability unverified';return p end
            if not current.route or current.route.verified~=true then p.blocker='Current acquisition route unverified';return p end
            p.route=current.route;p.objective='Acquire secret Rukia from verified current route';return p
        end
        if kind=='Trait' or kind=='Build' then
            if not C.hasTrait(unit,goal.trait or 'Unique') then p.objective='Reach selected trait';p.blocker='Current trait quote/pool and spending grant required';return p end
            if kind=='Trait' then p.stop=true;p.objective='Selected trait observed';return p end
        end
        if kind=='Stats' or kind=='Build' then
            if not C.statsMet(unit,goal.grade or 'SSS') then p.objective='Reach selected raw stats/grades';p.blocker='Current stat/evolution rules and spending grant required';return p end
            if kind=='Stats' then p.stop=true;p.objective='Selected raw stats and grades observed';return p end
        end
        if unit.id=='rukia_2_evo' then p.stop=true;p.objective='Evolved Rukia observed';return p end
        local recipe=current.recipe
        if type(recipe)~='table' or recipe.verified~=true or type(recipe.items)~='table' then p.blocker='Current evolution recipe unverified';return p end
        for id,need in pairs(recipe.items) do
            if not C.finite(need) or need<0 then p.blocker='Invalid current recipe';return p end
            local have=(view.resources or {})[id]
            if C.finite(have) and have>=0 then p.deficits[id]=math.max(0,need-have) else p.unknown[id]=true end
        end
        p.takedownsMissing=C.finite(unit.takedowns) and C.finite(recipe.takedowns) and math.max(0,recipe.takedowns-unit.takedowns) or nil
        p.route=P.rankRoutes(catalog.measured);p.objective='Collect current evolution requirements'
        p.blocker=next(p.unknown) and 'Some required inventory counts are unknown' or 'Evolution needs a separate selected-copy confirmation'
        return p
    end
    return P
end
