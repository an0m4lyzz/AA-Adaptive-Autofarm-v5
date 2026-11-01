return function(app)
    local UIS=game:GetService('UserInputService')
    local LP=game:GetService('Players').LocalPlayer
    local colors={bg=Color3.fromRGB(13,17,25),card=Color3.fromRGB(24,31,43),
        line=Color3.fromRGB(48,61,78),text=Color3.fromRGB(235,241,251),muted=Color3.fromRGB(157,174,196),
        accent=Color3.fromRGB(102,209,224),active=Color3.fromRGB(29,83,99)}
    local gui=Instance.new('ScreenGui')
    gui.Name='K_AA_Rukia_V6';gui.ResetOnSpawn=false;gui.DisplayOrder=80
    gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    gui.Parent=LP:FindFirstChildOfClass('PlayerGui')
    local U={gui=gui,connections={},labels={},buttons={},page='RUKIA',alive=true}
    local function bind(signal,fn)
        local c=signal:Connect(fn);U.connections[#U.connections+1]=c;return c
    end
    local function mk(class,props,parent)
        local x=Instance.new(class)
        for k,v in pairs(props) do x[k]=v end
        x.Parent=parent;return x
    end
    local function round(x,r) mk('UICorner',{CornerRadius=UDim.new(0,r or 8)},x) end
    local root=mk('Frame',{Size=UDim2.fromOffset(360,520),Position=UDim2.new(.5,-180,.5,-260),
        BackgroundColor3=colors.bg,BorderSizePixel=0,Active=true},gui)
    round(root,14)
    mk('UIStroke',{Color=colors.line,Thickness=1},root)
    local scale=mk('UIScale',{Scale=1},root)
    local header=mk('TextLabel',{Size=UDim2.new(1,-90,0,45),Position=UDim2.fromOffset(14,0),
        Text='[K]  RUKIA / PROGRESSION',TextColor3=colors.text,BackgroundTransparency=1,
        TextSize=15,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,Active=true},root)
    local function top(text,x)
        local b=mk('TextButton',{Text=text,Size=UDim2.fromOffset(40,40),Position=UDim2.new(1,x,0,3),
            BackgroundColor3=colors.card,TextColor3=colors.text,TextSize=18,Font=Enum.Font.GothamBold},root)
        round(b);return b
    end
    local minimize=top('−',-86);local close=top('×',-43)
    local bubble=mk('TextButton',{Text='[K]',Size=UDim2.fromOffset(48,48),Position=UDim2.fromOffset(12,100),
        Visible=false,BackgroundColor3=colors.active,TextColor3=colors.text,TextSize=16,Font=Enum.Font.GothamBold},gui)
    round(bubble,14)
    bind(minimize.Activated,function() root.Visible=false;bubble.Visible=true end)
    bind(bubble.Activated,function() root.Visible=true;bubble.Visible=false end)
    bind(close.Activated,function() app:stop() end)
    local pages,tabs={},{}
    for i,name in ipairs({'RUKIA','TRAITS','STATS','EVOLUTION','FARM','REPORTS','SETTINGS'}) do
        local tab=mk('TextButton',{Text=name,Size=UDim2.fromOffset(82,38),
            Position=UDim2.fromOffset(12+((i-1)%4)*85,49+math.floor((i-1)/4)*42),
            BackgroundColor3=colors.card,TextColor3=colors.text,TextSize=10,Font=Enum.Font.GothamBold,
            BorderSizePixel=0},root)
        round(tab);tabs[name]=tab
        local page=mk('ScrollingFrame',{Size=UDim2.new(1,-20,1,-183),Position=UDim2.fromOffset(10,137),
            BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=colors.accent,
            CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,Visible=name==U.page},root)
        mk('UIListLayout',{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},page)
        mk('UIPadding',{PaddingBottom=UDim.new(0,8),PaddingLeft=UDim.new(0,3),PaddingRight=UDim.new(0,3)},page)
        pages[name]=page
        bind(tab.Activated,function()
            U.page=name
            for key,p in pairs(pages) do p.Visible=key==name end
            for key,b in pairs(tabs) do b.BackgroundColor3=key==name and colors.active or colors.card end
        end)
    end
    tabs.RUKIA.BackgroundColor3=colors.active
    local footer=mk('TextLabel',{Position=UDim2.new(0,14,1,-40),Size=UDim2.new(1,-28,0,34),
        BackgroundTransparency=1,TextWrapped=true,TextSize=11,TextColor3=colors.accent,
        Font=Enum.Font.Gotham,Text='Observer starting',TextXAlignment=Enum.TextXAlignment.Left},root)
    local order=0
    local function label(page,fn,color)
        order+=1
        local x=mk('TextLabel',{LayoutOrder=order,Size=UDim2.new(1,-6,0,0),AutomaticSize=Enum.AutomaticSize.Y,
            BackgroundTransparency=1,TextWrapped=true,TextSize=12,TextColor3=color or colors.muted,
            TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
            Font=Enum.Font.Gotham,Text=''},pages[page])
        U.labels[#U.labels+1]={x=x,fn=type(fn)=='function' and fn or function() return fn end}
    end
    local function button(page,title,fn)
        order+=1
        local x=mk('TextButton',{LayoutOrder=order,Size=UDim2.new(1,-6,0,44),BackgroundColor3=colors.card,
            TextColor3=colors.text,TextSize=12,TextWrapped=true,Font=Enum.Font.GothamSemibold,BorderSizePixel=0,
            Text=type(title)=='string' and title or ''},pages[page]);round(x)
        if type(title)=='function' then U.buttons[#U.buttons+1]={x=x,fn=title} end
        bind(x.Activated,function()
            if U.alive then
                local ok,err=pcall(fn);if not ok then app:error(err) end
                U:refresh()
            end
        end)
    end
    local function field(page,title,key,numeric)
        label(page,title)
        order+=1
        local x=mk('TextBox',{LayoutOrder=order,Size=UDim2.new(1,-6,0,44),BackgroundColor3=colors.card,
            TextColor3=colors.text,TextSize=12,Font=Enum.Font.Gotham,Text=tostring(app.cfg[key] or ''),
            PlaceholderText='unknown / unset',ClearTextOnFocus=false,BorderSizePixel=0},pages[page]);round(x)
        bind(x.FocusLost,function()
            app:set(key,numeric and tonumber(x.Text) or x.Text)
            x.Text=tostring(app.cfg[key] or '')
        end)
    end
    label('RUKIA','UPDATE 21 • LIVE ADAPTER UNVERIFIED',colors.accent)
    label('RUKIA',function() return app:ownershipText() end,colors.text)
    label('RUKIA',function() return app:objectiveText() end)
    label('RUKIA',function() return app:walletText() end)
    button('RUKIA','REFRESH EXPOSED INVENTORY',function() app:refreshInventory() end)
    button('RUKIA','READ CLIENT CACHE + COPY REPORT',function() app:readClientCache() end)
    label('RUKIA','Experimental manual cache reader. Open the game’s Collection first. It reads existing service tables through the reported-loaded Loader. Delta cache isolation is unverified: native require may execute Loader code. The reader makes no explicit service initializer/getter calls.')
    button('RUKIA','SELECT NEXT OWNED RUKIA',function() app:nextRukia() end)
    button('RUKIA',function() return 'STOP GOAL: '..app.cfg.goal end,function()
        app:cycle('goal',{'Acquire','Trait','Stats','Evolution','Build'})
    end)
    label('RUKIA','No verified Update 21 pity, banner, drop rate or key price. Absence from a partial scan means ownership is unknown.')
    label('TRAITS','HISTORICAL BUILD ADVICE',colors.accent)
    label('TRAITS','Unique is the damage/cost candidate for a three-placement unit. Divine preserves multiple placements and adds range; compare control coverage. Current-patch mechanics need verification.')
    label('TRAITS',function() return app:traitText() end,colors.text)
    button('TRAITS',function() return 'TARGET: '..app.cfg.targetTrait end,function()
        app:cycle('targetTrait',{'Unique','Divine','Celestial','Reaper','Godspeed','Sniper'})
    end)
    field('TRAITS','Maximum reroll resource budget (planning only)','traitCap',true)
    label('TRAITS','AUTO REROLL: UNAVAILABLE\nNo current signature, price or inventory readback verified. No reroll request is sent. Stop immediately on target during manual rolls.')
    label('STATS',function() return app:statsText() end,colors.text)
    button('STATS',function() return 'TARGET GRADES: '..app.cfg.targetGrade end,function()
        app:cycle('targetGrade',{'S','S+','SS','SSS'})
    end)
    field('STATS','Maximum cube budget (planning only)','statCap',true)
    label('STATS','AUTO STAT REROLL: UNAVAILABLE\nHistorical: ordinary cubes reroll all stats; perfect cubes select one. Build worthiness first and inspect exact grades. Rounded values cannot prove SSS or an absolute maximum.')
    label('EVOLUTION','HISTORICAL RECIPE • VERIFY IN EVOLVE MENU',colors.accent)
    label('EVOLUTION',function() return app:evolutionText() end,colors.text)
    label('EVOLUTION','Reported sources: Sacred Treasure from Shibuya Portals; fruit from current fruit challenges. Current eligibility, quantities, prices and recipes need live verification. Evolution and material purchases stay manual.')
    label('FARM',function() return app:farmText() end,colors.text)
    button('FARM',function() return app.engine.armed and 'STOP FULL AUTO' or 'FULL AUTO: OFF • EXPERIMENTAL COMBAT' end,function() app:toggleFarm() end)
    button('FARM','CHECK READINESS',function() app:checkReady() end)
    button('FARM','RECORD CURRENT OWN PLACEMENTS',function() app:record() end)
    field('FARM','Fallback deployment costs by equipped slot (comma separated)','recordCosts',false)
    button('FARM',function() return 'SELECTED MODE: '..app.cfg.mode end,function()
        app:cycle('mode',{'Dungeon','Story','Infinite','Challenge','Portal','Raid','Event','Legend'})
    end)
    button('FARM',function() return 'CURRENT RUKIA FARM ROUTE CONFIRMED: '..tostring(app.cfg.routeConfirmed) end,function() app:toggle('routeConfirmed') end)
    button('FARM',function() return 'COMBAT SIGNATURE CONFIRMED: '..tostring(app.cfg.protocolConfirmed) end,function() app:toggle('protocolConfirmed') end)
    button('FARM',function() return 'UPGRADE RECORDED TOWERS: '..tostring(app.cfg.upgrade) end,function() app:toggle('upgrade') end)
    button('FARM',function() return 'FREE REPLAY: '..tostring(app.cfg.replay) end,function() app:toggle('replay') end)
    button('FARM',function() return 'CURRENT REPLAY HAS NO ITEM COST: '..tostring(app.cfg.replayFreeConfirmed) end,function() app:toggle('replayFreeConfirmed') end)
    label('FARM','Automatic dungeon room choices, chests, keys, target priority, skills and queueing: UNAVAILABLE. Random tower event modes need their own adapter. Recorded positions are user data, not a map datamine.')
    button('REPORTS','COPY COMPLETE REPORT',function() app:copyReport() end)
    button('REPORTS','SCAN DATA PATHS + COPY REPORT',function() app:scanPathsAndCopy() end)
    button('REPORTS','SAVE BOUNDED REPORT LOCALLY',function() app:saveReport() end)
    label('REPORTS',function() return app:reportStatus() end,colors.text)
    label('REPORTS',function() return app:recentLogs() end)
    label('SETTINGS','MOBILE / RESOURCE PROTECTION',colors.accent)
    field('SETTINGS','Yen reserve','reserve',true)
    field('SETTINGS','Maximum confirmed runs per armed session','maxRuns',true)
    field('SETTINGS','Session timeout (seconds)','maxSeconds',true)
    field('SETTINGS','Player inventory path (e.g. player/owned_units)','inventoryPath',false)
    field('SETTINGS','Player item count path (e.g. player/_data/items)','resourcePath',false)
    field('SETTINGS','Optional match Yen Value path (verify it belongs to you)','cashPath',false)
    button('SETTINGS','SAVE SETTINGS / RECORDED PROFILE',function() app:saveSettings() end)
    button('SETTINGS','COPY CONFIGURATION (contains unit UUIDs)',function() app:copyConfig() end)
    button('SETTINGS','STOP + CLOSE',function() app:stop() end)
    label('SETTINGS','No hooks or GC scans. One remote request at a time. Auto is never armed after loading settings. Close disconnects all input listeners; minimize preserves the observer. Old v5 settings remain untouched.')
    local dragging=false;local begin,origin,dragTouch
    bind(header.InputBegan,function(input)
        if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then
            dragging=true;begin=input.Position;origin=root.Position;dragTouch=input
        end
    end)
    bind(UIS.InputEnded,function(input) if input==dragTouch then dragging=false;dragTouch=nil end end)
    bind(UIS.InputChanged,function(input)
        if dragging and (input==dragTouch or input.UserInputType==Enum.UserInputType.MouseMovement) then
            local d=input.Position-begin
            root.Position=UDim2.new(origin.X.Scale,origin.X.Offset+d.X,origin.Y.Scale,origin.Y.Offset+d.Y)
        end
    end)
    function U:refresh()
        if not self.alive then return end
        for _,row in ipairs(self.labels) do row.x.Text=tostring(row.fn()) end
        for _,row in ipairs(self.buttons) do row.x.Text=tostring(row.fn()) end
        footer.Text=app.engine.state..' • '..tostring(app.status):sub(1,140)
        local cam=workspace.CurrentCamera
        if cam then
            scale.Scale=math.clamp(math.min(cam.ViewportSize.X/380,cam.ViewportSize.Y/550),.5,1)
        end
    end
    function U:close()
        self.alive=false
        for _,c in ipairs(self.connections) do c:Disconnect() end
        table.clear(self.connections);self.gui:Destroy()
    end
    U:refresh()
    return U
end
