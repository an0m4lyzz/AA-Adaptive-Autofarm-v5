-- Read-only, bounded placement proposals from the currently loaded native map.
-- No map coordinates, cloned models, global scans, or server calls live here.
return function(C,WS,RS,log)
    local N={closed=false,planning=false}
    local function child(parent,name) return parent and parent:FindFirstChild(name) end
    local function position(p)
        return p and C.finite(p.X) and C.finite(p.Y) and C.finite(p.Z) and {p.X,p.Y,p.Z} or nil
    end
    local function children(parent,limit,label)
        if not parent then return nil,label..' unavailable' end
        local list=parent:GetChildren()
        if type(list)~='table' or #list>limit then return nil,label..' observation exceeds bounded limit' end
        return list
    end
    local function lanePoint(percent)
        local bases=child(WS,'_BASES');local pve=child(bases,'pve');local root=child(pve,'LANES')
        local lanes,why=children(root,8,'_BASES.pve.LANES')
        if not lanes then return nil,why end
        if #lanes==0 then return nil,'Native LANES empty' end
        table.sort(lanes,function(a,b) return tostring(a.Name)<tostring(b.Name) end)
        local longest,length=nil,0
        local observedPaths={}
        for _,lane in ipairs(lanes) do
            local nodes;nodes,why=children(lane,96,'Native lane nodes')
            if not nodes then return nil,why end
            local first,last,numbered,seen=nil,nil,{},{}
            for _,node in ipairs(nodes) do
                local name=node.Name;local index=tonumber(name)
                if name=='spawn' or name=='final' or index then
                    if not node:IsA('BasePart') then return nil,'Native lane endpoint/node is not a BasePart' end
                    local pos=position(node.Position)
                    if not pos then return nil,'Native lane position invalid' end
                    if name=='spawn' then
                        if first then return nil,'Duplicate native spawn node' end;first=pos
                    elseif name=='final' then
                        if last then return nil,'Duplicate native final node' end;last=pos
                    else
                        if not C.finite(index) or index<1 or index%1~=0 or seen[index] then return nil,'Duplicate/invalid numeric native lane node' end
                        seen[index]=true;numbered[#numbered+1]={index=index,pos=pos}
                    end
                end
            end
            if not first or not last then return nil,'Native lane requires observed spawn and final parts' end
            table.sort(numbered,function(a,b) return a.index<b.index end)
            local points={first};for _,v in ipairs(numbered) do points[#points+1]=v.pos end;points[#points+1]=last
            local total=0;for i=2,#points do total+=C.distance(points[i-1],points[i]) end
            if total>0 then observedPaths[#observedPaths+1]={points=points,length=total} end
            if total>length then longest=points;length=total end
        end
        if not longest or length<=0 then return nil,'Native lane has no positive observed length' end
        local function at(points,total)
            local remaining=total*percent/100
            for i=2,#points do
                local a,b=points[i-1],points[i];local segment=C.distance(a,b)
                if segment>0 and remaining<=segment then
                    local t=remaining/segment
                    return {a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t,a[3]+(b[3]-a[3])*t}
                end
                remaining-=segment
            end
            return table.clone(points[#points])
        end
        table.sort(observedPaths,function(a,b) return a.length>b.length end)
        local anchors={};for _,p in ipairs(observedPaths) do anchors[#anchors+1]=at(p.points,p.length) end
        return at(longest,length),nil,anchors
    end
    local function within(part,root)
        if not root then return false end
        local at=part
        for _=1,12 do if at==root then return true end;if not at then break end;at=at.Parent end
        return false
    end
    local function surface(hit,terrain,ground,hill,def,x,z)
        if not hit or not hit.Instance then return nil,'No observed terrain surface' end
        local at=hit.Instance;local reached=false
        for _=1,12 do
            if not at then break end
            if at.Name=='_donotplace' then return nil,'First surface is _donotplace' end
            if at==terrain then reached=true;break end
            at=at.Parent
        end
        if not reached then return nil,'First surface terrain ancestry incomplete' end
        local class=within(hit.Instance,ground) and 'ground' or within(hit.Instance,hill) and 'hill'
        if not class then return nil,'First surface is not loaded ground/hill' end
        if (class=='hill' and not def.hill_unit and not def.hybrid_placement) or (class=='ground' and def.hill_unit) then
            return nil,'First surface conflicts with loaded ground/hill rule'
        end
        local p=position(hit.Position)
        if not p or not hit.Normal or not C.finite(hit.Normal.Y) or hit.Normal.Y<=0 then return nil,'First surface position/normal invalid' end
        if math.abs(p[1]-x)>0.05 or math.abs(p[3]-z)>0.05 then return nil,'First surface ray changed candidate X/Z' end
        return p,class
    end
    -- Replicated bounds are inspected in place; no workspace clone is created.
    local function boundsParts(root)
        if not root then return {} end
        local stack={root};local parts={};local count=0
        while #stack>0 do
            local at=table.remove(stack);count+=1
            if count>128 then return nil,'Loaded bounds observation exceeds128 nodes' end
            if at:IsA('BasePart') then
                if #parts>=64 then return nil,'Loaded bounds observation exceeds64 parts' end
                if not position(at.Size) or not at.CFrame then return nil,'Loaded bounds geometry incomplete' end
                parts[#parts+1]=at
            else
                local list,why=children(at,128,'Loaded bounds nodes');if not list then return nil,why end
                for _,v in ipairs(list) do stack[#stack+1]=v end
            end
        end
        return parts
    end
    local function overlapsBounds(parts,pos,radius)
        -- A sphere enclosing the proposed query box is conservative for rotated bounds.
        local reach=math.sqrt(radius*radius*2+9)
        for _,part in ipairs(parts) do
            local localPos=part.CFrame:PointToObjectSpace(Vector3.new(pos[1],pos[2]+3,pos[3]))
            if not position(localPos) then return true end
            local half=part.Size
            if math.abs(localPos.X)<=half.X/2+reach and math.abs(localPos.Y)<=half.Y/2+reach
                and math.abs(localPos.Z)<=half.Z/2+reach then return true end
        end
        return false
    end
    function N:close() self.closed=true end
    function N:plan(s,definitions,cfg)
        if self.closed then return nil,'Native planner closed' end
        if self.planning then return nil,'Native geometry plan already in progress' end
        self.planning=true;cfg=cfg or {}
        local function compute()
            if s.inMatch~=true or s.stageVerified~=true or s.modeVerified~=true
                or not table.find({'Story','Dungeon','Infinite','Challenge','Raid','Legend','Portal'},s.mode)
                or s.unitsComplete~=true or s.rosterComplete~=true then return nil,'Native map/roster/tower observation incomplete or unsupported' end
            if s.externalControllerActive then return nil,'External controller active' end
            if type(s.roster)~='table' or #s.roster==0 or #s.roster>6 or type(s.units)~='table' or #s.units>24 then
                return nil,'Native planner supports1–6 observed slots and at most24 own towers'
            end
            local percent=cfg.autoDistance==nil and 50 or cfg.autoDistance
            local groundPercent=cfg.autoGround==nil and 60 or cfg.autoGround;local hillPercent=cfg.autoHill==nil and 80 or cfg.autoHill
            for _,v in ipairs({percent,groundPercent,hillPercent}) do if not C.finite(v) or v<0 or v>100 then return nil,'Native placement percentage invalid' end end
            local anchor,why,anchors=lanePoint(percent);if not anchor then return nil,why end
            local terrain=child(WS,'_terrain');local ground,hill=child(terrain,'ground'),child(terrain,'hill')
            if not terrain or (not ground and not hill) then return nil,'Loaded _terrain ground/hill unavailable' end
            local road,units=child(WS,'_road'),child(WS,'_UNITS')
            if not road or not units then return nil,'Actual _road/_UNITS geometry unavailable' end
            if not Vector3 or not CFrame or not RaycastParams or not OverlapParams or not Enum or not Enum.RaycastFilterType
                or not task or type(task.wait)~='function' then return nil,'Native ray/overlap/yield capabilities unavailable' end
            local rp=RaycastParams.new();rp.FilterType=Enum.RaycastFilterType.Include;rp.FilterDescendantsInstances={terrain}
            local op=OverlapParams.new();op.FilterType=Enum.RaycastFilterType.Include;op.FilterDescendantsInstances={road,units};op.MaxParts=64
            local nativeBounds=child(WS,'_bounds');if nativeBounds then op.FilterDescendantsInstances[#op.FilterDescendantsInstances+1]=nativeBounds end
            local bounds;bounds,why=boundsParts(child(RS,'_bounds'));if not bounds then return nil,why end
            local standing,reserved={},{}
            for _,u in ipairs(s.units) do
                if C.distance(u.pos,u.pos)~=0 then return nil,'Observed own tower position unavailable' end
                standing[#standing+1]=u.pos
            end
            local slots,seen,missing={}, {},0
            local teamSearchRange=0
            for _,u in ipairs(s.roster) do
                local def=type(definitions)=='table' and definitions[u.id]
                local range=u.planningRange or (type(def)=='table' and def.range)
                local farm=u.role=='farm' or (type(def)=='table' and C.finite(def.farm_amount) and def.farm_amount>0)
                if not farm and C.finite(range) and range>0 then teamSearchRange=math.max(teamSearchRange,range) end
            end
            for _,u in ipairs(s.roster) do
                if type(u.uuid)~='string' or u.uuid=='' or seen[u.uuid] or type(u.id)~='string' or u.id=='' then return nil,'Equipped UUID/ID missing or duplicated' end
                if not C.finite(u.slot) or u.slot%1~=0 or u.slot<1 or u.slot>6 then return nil,'Supported hotbar slot1–6 required' end
                seen[u.uuid]=true
                if not C.finite(u.spawnCap) or u.spawnCap<1 or u.spawnCap%1~=0 then return nil,'Known positive integer spawn cap required: '..u.id end
                local nativeLimit=C.hasTrait(u,'Unique') and 1 or math.min(24,u.spawnCap)
                local limit=math.min(nativeLimit,C.slotPolicy(cfg,u).placeCap);local count=0
                for _,v in ipairs(s.units) do if v.uuid==u.uuid and v.id==u.id then count+=1 end end
                if count>nativeLimit then return nil,'Observed copies exceed loaded cap: '..u.id end
                local def=type(definitions)=='table' and definitions[u.id]
                if type(def)~='table' then return nil,'Loaded unit placement definition unavailable: '..u.id end
                for _,key in ipairs({'hill_unit','hybrid_placement'}) do
                    if def[key]~=nil and type(def[key])~='boolean' then return nil,'Unsupported loaded placement flag: '..key end
                end
                local range=u.planningRange or def.range or u.range
                if u.role=='farm' or (C.finite(def.farm_amount) and def.farm_amount>0) then
                    -- Search footprint only: an income unit's range is not a
                    -- combat reach requirement. Never overwrite its real stats.
                    range=math.max(C.finite(range) and range or 0,teamSearchRange)
                end
                if not C.finite(range) or range<=0 then return nil,'Loaded planning range unavailable: '..u.id end
                local radius=def.override_hitbox_radius
                if radius~=nil and (not C.finite(radius) or radius<=0 or radius>30) then return nil,'Loaded hitbox radius unsupported: '..u.id end
                radius=math.max(3,radius or 3) -- conservative query footprint, never a claimed game hitbox
                local need=math.max(0,limit-count)
                if #s.units>=24 then need=0 end
                if need>0 then missing+=1 end
                slots[#slots+1]={unit=u,def=def,need=need,range=range,radius=radius}
            end
            table.sort(slots,function(a,b)
                local function rank(s)
                    if s.unit.role=='buff' or s.def._show_as_buff_unit==true then return 1 end
                    if s.unit.role=='farm' or (C.finite(s.def.farm_amount) and s.def.farm_amount>0) then return 3 end
                    return 2
                end
                local ar,br=rank(a),rank(b)
                return ar==br and (a.unit.slot or 0)<(b.unit.slot or 0) or ar<br
            end)
            local budget=24-#standing
            if missing>budget then return nil,'Remaining24-target budget cannot cover every missing equipped slot' end
            local out={};local pendingSlots=missing;local rays=0
            for _,slot in ipairs(slots) do
                local u=slot.unit;local found={};out[u.uuid]=found
                if slot.need>0 then
                    local wanted=math.min(4,slot.need,budget-pendingSlots+1)
                    local gRadius=math.min(120,slot.range*groundPercent/100);local hRadius=math.min(120,slot.range*hillPercent/100)
                    local searchRadius=math.max(gRadius,hRadius);local blocker='No supported surface observed';local blockerRank=-1
                    local function blocked(reason,rank) if rank>=blockerRank then blocker=reason;blockerRank=rank end end
                    for attempt=1,96 do
                        if self.closed then return nil,'Native planner closed during geometry search' end
                        -- An original bounded radial sequence, anchored only to the observed path.
                        local laneAnchor=anchors[(attempt-1)%#anchors+1]
                        local step=math.floor((attempt-1)/#anchors)
                        local radius=step==0 and 0 or searchRadius*math.sqrt(step/math.max(1,math.floor(95/#anchors)))
                        local angle=(step-1)*2.399963229728653
                        local x,z=laneAnchor[1]+math.cos(angle)*radius,laneAnchor[3]+math.sin(angle)*radius
                        local hit=WS:Raycast(Vector3.new(x,laneAnchor[2]+80,z),Vector3.new(0,-400,0),rp);rays+=1
                        local pos,class=surface(hit,terrain,ground,hill,slot.def,x,z)
                        if not pos then blocked(class,1)
                        elseif radius>(class=='hill' and hRadius or gRadius) then blocked('Observed surface outside configured planning range',0)
                        else
                            local clear=true
                            for _,p in ipairs(standing) do if C.distance(p,pos)<=slot.radius*2 then clear=false;break end end
                            for _,p in ipairs(reserved) do if C.distance(p.pos,pos)<=slot.radius+p.radius then clear=false;break end end
                            if not clear then blocked('Observed/planned tower overlap',2)
                            elseif overlapsBounds(bounds,pos,slot.radius) then blocked('Loaded bounds overlap',2)
                            else
                                local hits=WS:GetPartBoundsInBox(CFrame.new(pos[1],pos[2]+3,pos[3]),Vector3.new(slot.radius*2,6,slot.radius*2),op)
                                if type(hits)~='table' or #hits>=64 then blocked('Native geometry overlap observation truncated',3)
                                elseif #hits>0 then blocked('Actual unit/road/bounds overlap',2)
                                else
                                    found[#found+1]={pos=pos,surface=class,source='native-lanes-terrain'}
                                    reserved[#reserved+1]={pos=pos,radius=slot.radius}
                                end
                            end
                        end
                        if rays%12==0 then task.wait();if self.closed then return nil,'Native planner closed during geometry search' end end
                        if #found>=wanted then break end
                    end
                    if #found==0 then return nil,'Native slot '..tostring(u.slot or '?')..' '..u.id..' unsupported: '..blocker end
                    budget-=#found;pendingSlots-=1
                end
            end
            return out
        end
        local ok,result,why=pcall(compute);self.planning=false
        if not ok then return nil,'Native geometry capability/schema unsupported: '..tostring(result):sub(1,160) end
        return result,why
    end
    return N
end
