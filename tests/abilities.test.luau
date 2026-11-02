local C=require('../src/core');local A=require('../src/abilities')(C)
local function u(k) return {key=k,uuid=k,id='attacker',role='combat',activeAttack='blast',castReady=true,lastCast=20,cooldown=30,pos={0,0,0},range=20} end
local s={roster={{uuid='a',id='attacker'},{uuid='b',id='attacker'}},now=1,units={u('a'),u('b')},enemyUnits={{health=10,pos={5,0,0}}},enemiesComplete=true}
assert(not A.choose(s,{autoAbilities=false},{}))
local a=A.choose(s,{autoAbilities=true,abilityGap=3},{});assert(a and a.key=='a')
assert(not A.choose(s,{autoAbilities=true,abilityGap=3},{attacker=0}))
s.units[1].castReady=false;assert(A.choose(s,{autoAbilities=true},{}).key=='b')
s.units[2].activeAttack='meter:off';assert(not A.choose(s,{autoAbilities=true},{}))
s.units[2].activeAttack='blast';s.enemiesComplete=false;assert(not A.choose(s,{autoAbilities=true},{}))
local p={key='a',uuid='a',id='attacker',lastCast=20,activeAttack='blast'};local v=u('a');assert(not A.proof(p,v));v.lastCast=21;assert(A.proof(p,v));v.key='b';assert(not A.proof(p,v))
s.enemiesComplete=true;s.units[1]=u('helper');s.units[2].castReady=false;assert(not A.choose(s,{autoAbilities=true},{}),'helper cannot cast')
print('All 8 ability cases passed')
