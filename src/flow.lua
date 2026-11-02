-- Optional wave actions share the same runtime/transport as combat.
return function(C,cfg)
    local F={armed=false,pending=nil,confirmations=0,soldRoles={},seen={}}
    function F:arm(s) self.armed=true;self.run=s.run;self.round=s.roundToken;self.stage=s.stage;self.pending=nil;self.seen={};self.soldRoles={} end
    function F:stop(reason) self.armed=false;self.reason=reason;self.pending=nil end
    function F:chooseCard(offers,ranks,caps,counts)
        local best,rank
        for i,v in ipairs(offers or {}) do
            if i>12 then return nil,'Card offer exceeds bound' end
            local cap=caps[v.title]
            if type(v.title)=='string' and C.finite(ranks[v.title]) and C.finite(cap) and cap>=0
                and (cap==0 or (counts[v.title] or 0)<cap) then
                if not best or ranks[v.title]<rank then best=v;rank=ranks[v.title] end
            end
        end
        return best,best and 'Ranked current offer; applied-state receipt still required' or 'Every card is capped or unsupported'
    end
    function F:tick(s)
        if not self.armed then return nil end
        if self.stage~=s.stage or self.run~=s.run or self.round~=s.roundToken then self:stop('Wave policy context changed');return nil end
        if self.pending then
            local p=self.pending;local done=false
            if p.kind=='skip' then done=(s.wave>p.wave) or (s.wave==p.wave and s.skipFinished==true)
            elseif p.kind=='sell' and s.unitsComplete==true then
                done=true;for _,u in ipairs(s.units or {}) do if u.key==p.key then done=false;break end end
            end
            if done then
                self.confirmations+=1;self.pending=nil
                if p.kind=='sell' then self.soldRoles[p.role]=true end
            elseif s.now-p.at>8 then self:stop(p.kind..' feedback unconfirmed; no retry') end
            return nil
        end
        if s.resultVisible or not s.started then return nil end
        local sellWave=tonumber(cfg.sellAllWave) or 0;local farmWave=tonumber(cfg.sellFarmWave) or 0
        local all=sellWave>0 and s.wave>=sellWave;local farm=farmWave>0 and s.wave>=farmWave
        if (all or farm) and s.unitsComplete==true then
            for _,u in ipairs(s.units or {}) do
                if u.id~='bulma' and u.sellable==true and u.key and u.uuid and (all or u.role=='farm') then
                    self.pending={kind='sell',key=u.key,uuid=u.uuid,id=u.id,role=u.role or 'combat',at=s.now}
                    return {kind='sell',key=u.key,uuid=u.uuid,id=u.id}
                end
            end
            if all then self.soldRoles.all=true elseif farm then self.soldRoles.farm=true end
        end
        local offer=s.skipOffer
        if cfg.autoSkip==true and type(offer)=='table' and type(offer.token)=='string' and offer.wave==s.wave
            and s.skipFinished==false and not self.seen[offer.token]
            and ((tonumber(cfg.skipStopWave) or 0)==0 or s.wave<cfg.skipStopWave) then
            self.seen[offer.token]=true
            self.pending={kind='skip',token=offer.token,wave=s.wave,at=s.now}
            return {kind='skip',offerToken=offer.token,wave=s.wave}
        end
        return nil
    end
    return F
end
