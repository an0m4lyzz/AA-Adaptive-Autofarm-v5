-- Pure fit calculation for the owned 360x520 window and native safe insets.
local V={}
local function finite(x) return type(x)=='number' and x==x and math.abs(x)<1e9 end
function V.fit(width,height,requested,insets)
    if not finite(width) or not finite(height) or width<=8 or height<=8 then return nil end
    insets=insets or {}
    local function edge(k) local n=insets[k];return finite(n) and math.max(0,n) or 0 end
    local left,top,right,bottom=edge('left'),edge('top'),edge('right'),edge('bottom')
    local availableW,availableH=width-left-right-8,height-top-bottom-8
    if availableW<=0 or availableH<=0 then return nil end
    local scale=math.min(math.clamp(finite(requested) and requested or 1,.75,1.25),availableW/360,availableH/520)
    return {scale=scale,minX=left+4,minY=top+4,maxRight=width-right-4,maxBottom=height-bottom-4}
end
return V
