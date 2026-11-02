-- Actual UI factory with a small Roblox surface seam; no game or network calls.
local C=require('../src/core');local factory=require('../src/ui');local n=0;local failures={}
local function check(name,fn)local ok,e=pcall(fn);if not ok then failures[#failures+1]=name..': '..tostring(e);print('FAIL '..name..': '..tostring(e))else n+=1 end end
local function signal() return {Connect=function(self,fn)self.fn=fn;return {Disconnect=function()end}end}end
local function world(width,height,scale)
 local made={};local player={FindFirstChildOfClass=function()return {}end}
 local function dim(a,b)return {Scale=a,Offset=b}end
 local mt={};mt.__add=function(a,b)return setmetatable({X=dim(a.X.Scale+b.X.Scale,a.X.Offset+b.X.Offset),Y=dim(a.Y.Scale+b.Y.Scale,a.Y.Offset+b.Y.Offset)},mt)end
 local ud={new=function(xs,xo,ys,yo)return setmetatable({X=dim(xs,xo),Y=dim(ys,yo)},mt)end}
 ud.fromOffset=function(x,y)return ud.new(0,x,0,y)end;ud.fromScale=function(x,y)return ud.new(x,0,y,0)end
 local input={InputBegan=signal(),InputEnded=signal(),InputChanged=signal()}
 local ws={CurrentCamera={ViewportSize={X=width,Y=height}}}
 local game={GetService=function(_,name)return ({Players={LocalPlayer=player},UserInputService=input})[name]end}
 local instance={new=function(class)
  local x={ClassName=class,Activated=signal(),FocusLost=signal(),InputBegan=signal(),InputEnded=signal(),InputChanged=signal(),AbsolutePosition={X=10,Y=10},AbsoluteSize={X=360,Y=520}}
  function x:GetPropertyChangedSignal()return signal()end;function x:IsFocused()return self.focused==true end;function x:Destroy()self.destroyed=true end
  made[#made+1]=x;return x
 end}
 local enum={};for _,key in ipairs({'AutomaticSize','Font','SortOrder','TextXAlignment','TextYAlignment','UserInputType','ZIndexBehavior'})do enum[key]=setmetatable({},{__index=function(_,k)return k end})end
 local app=setmetatable({cfg=C.sanitize({}),snapshot={roster={}},native={state='IDLE',reason='',armed=false},team={armed=false,text=function()return ''end},engine={state='IDLE',armed=false},
  trial={text=function()return ''end},macro={data=nil,text=function()return ''end},session={following=false,text=function()return ''end},reports={notificationState='OFF',render=function()return ''end},status='test'},
  {__index=function()return function()return 'test'end end})
 app.cfg.uiScale=scale or 1
 setfenv(factory,setmetatable({game=game,workspace=ws,Instance=instance,Enum=enum,Color3={fromRGB=function(r,g,b)return {r,g,b}end},UDim2=ud,UDim={new=dim}},{__index=getfenv()}))
 local ui=factory(app);return ui,app,made
end
check('unfocused fields track loaded settings while active edits are protected',function()
 local ui,app=world(1024,768,1);assert(type(ui.fields)=='table','Editable fields are not registered')
 local field;for _,f in ipairs(ui.fields)do if f.key=='reserve' then field=f.x end end;assert(field)
 app.cfg.reserve=77;ui:refresh();assert(field.Text=='77')
 field.focused=true;field.Text='typing';app.cfg.reserve=88;ui:refresh();assert(field.Text=='typing')
 field.focused=false;ui:refresh();assert(field.Text=='88');ui:close()
end)
check('landscape and portrait fit at both requested scale extremes',function()
 for _,size in ipairs({{1024,600},{600,1024},{360,640},{640,360}})do for _,wanted in ipairs({.75,1.25})do
  local ui,_,made=world(size[1],size[2],wanted);local fit;for _,x in ipairs(made)do if x.ClassName=='UIScale'then fit=x.Scale end end
  assert(fit and 360*fit<=size[1]-8 and 520*fit<=size[2]-8,'Window exceeds available viewport');ui:close()
 end end
end)
assert(#failures==0,table.concat(failures,'\n'))
print('All '..n..' actual UI tests passed')
