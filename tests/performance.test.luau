local P=require('../src/performance')()
local light={GlobalShadows=true};local fx={Enabled=true}
local status=P.apply('Low',{light=light,effects={fx}});assert(status.applied==2 and light.GlobalShadows==false and fx.Enabled==false)
P.apply('Low',{light=light,effects={fx}});P.restore();assert(light.GlobalShadows==true and fx.Enabled==true)
P.apply('Low',{light=light,effects={fx}});light.GlobalShadows='manual';P.restore();assert(light.GlobalShadows=='manual' and fx.Enabled==true)
assert(P.apply('Unknown',{}).applied==0);P.restore();P.restore()
print('All 4 performance cases passed')
