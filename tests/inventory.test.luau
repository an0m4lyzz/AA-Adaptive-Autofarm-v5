local C=require('../src/core')
local I=require('../src/inventory')(C)
local n=0
local function check(name,fn)
    local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));n+=1;print('PASS '..name)
end
local function service()
    return {session={profile_data={user_id=12,trait_reroll_tokens=5},collection={collection_profile_data={
        owned_units={a={unit_id='rukia_2',level=100,traits={{trait='unique'}},stat_damage=1.19},
            b={unit_id='other',uuid='b'}},equipped_units={[1]='a',['2']='b'}
    }},inventory={inventory_profile_data={normal_items={sacred_treasure=34,StarFruit=0,stat_cube={amount=3}}}}}}
end
check('cache parser maps keyed UUIDs to actual equipped slots',function()
    local s=I.read(service(),12)
    assert(s.valid and #s.owned==2 and #s.roster==2)
    assert(s.roster[1].uuid=='a' and s.roster[1].id=='rukia_2' and s.roster[2].slot==2)
end)
check('potential damage never masquerades as attack damage',function()
    local s=I.read(service(),12);local u=s.roster[1]
    assert(u.damage==nil and u.potential.stat_damage==1.19 and not C.statsMet(u,'SSS'))
end)
check('traits are read without mutating the exported source',function()
    local raw=service();local source=raw.session.collection.collection_profile_data.owned_units.a
    local s=I.read(raw,12)
    assert(s.roster[1].trait=='Unique' and source.uuid==nil and source.traits[1].trait=='unique')
end)
check('unknown counts remain nil while real zero remains zero',function()
    local s=I.read(service(),12)
    assert(s.resources.SacredTreasure==34 and s.resources.StarFruit==0 and s.resources.StarFruitBlue==nil)
    assert(s.resources.StatCube==3 and s.resources.RerollToken==5)
end)
check('explicit owner mismatch rejects the entire profile',function()
    local raw=service();raw.session.profile_data.user_id=99
    local s=I.read(raw,12);assert(not s.valid and #s.owned==0 and #s.roster==0)
end)
check('conflicting UUID record cannot become equipped',function()
    local raw=service();raw.session.collection.collection_profile_data.owned_units.a.uuid='different'
    local s=I.read(raw,12);assert(#s.roster==1 and s.roster[1].uuid=='b')
end)
check('malformed slots and missing equipment cannot be invented',function()
    local raw=service();raw.session.collection.collection_profile_data.equipped_units={['named']='a',[9]='b'}
    local s=I.read(raw,12);assert(s.valid and #s.roster==0)
end)
check('bounded parse prioritizes equipped records and flags omitted ownership',function()
    local raw=service();local col=raw.session.collection.collection_profile_data
    for i=1,900 do col.owned_units['x'..i]={unit_id='other'} end
    local s=I.read(raw,12);assert(s.valid and s.truncated and #s.owned<=408 and #s.roster==2)
end)
check('cache lookup finds named module wrappers without positional assumptions',function()
    local raw=service()
    local found=I.find({{value={random=true},source='first'},
        {value={CLIENT_SERVICE={StatsServiceClient={module=raw}}},source='observed upvalue 17'}},12)
    assert(found and found.service==raw and found.source:find('StatsServiceClient',1,true))
end)
check('cache lookup never invokes metamethod getters or functions',function()
    local calls=0
    local raw=setmetatable({},{__index=function() calls+=1;return service() end})
    assert(I.find({{value=raw,source='loader'}},12)==nil and calls==0)
end)
check('service schema disappearance invalidates previous observations',function()
    local raw=service();assert(I.read(raw,12).valid)
    raw.session.collection=nil
    local s=I.read(raw,12);assert(not s.valid and #s.roster==0)
end)
check('false owner marker cannot be ignored as if missing',function()
    local raw=service();raw.session.profile_data.user_id=false
    assert(not I.read(raw,12).valid)
end)
check('non-string explicit UUID conflicts with the dictionary identity',function()
    local raw=service();raw.session.collection.collection_profile_data.owned_units.a.uuid=42
    local s=I.read(raw,12);assert(#s.roster==1 and s.roster[1].uuid=='b')
end)
check('all present UUID aliases must agree with the dictionary key',function()
    local raw=service();local u=raw.session.collection.collection_profile_data.owned_units.a
    u.uuid='a';u.unique_id='different'
    local s=I.read(raw,12);assert(#s.roster==1 and s.roster[1].uuid=='b' and s.rejected>0)
end)
check('conflicting numeric and string slot mappings remain unverified',function()
    local raw=service();raw.session.collection.collection_profile_data.equipped_units={[1]='a',['1']='b'}
    local s=I.read(raw,12);assert(#s.roster==0 and s.rejected>0)
end)
check('bound registry replacement follows the current module export',function()
    local raw=service();local registry={StatsServiceClient={module=raw}}
    local found=I.find({{value=registry,source='cache'}},12)
    assert(found and I.current(found)==raw)
    local newer=service();registry.StatsServiceClient.module=newer
    assert(I.current(found)==newer)
    registry.StatsServiceClient=nil;assert(I.current(found)==nil)
end)
print('All '..n..' inventory tests passed')
