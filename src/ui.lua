local addAdvanced=require('./uiadvanced')
local viewMath=require('./uiview')
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
    local U={gui=gui,connections={},labels={},buttons={},fields={},page='RUKIA',alive=true}
    local function bind(signal,fn)
        local c=signal:Connect(fn);U.connections[#U.connections+1]=c;return c
    end
    local styles={}
    local function mk(class,props,parent)
        local x=Instance.new(class)
        for k,v in pairs(props) do x[k]=v end
        for prop,value in pairs(props) do for role,color in pairs(colors) do
            if value==color then styles[#styles+1]={x=x,prop=prop,role=role};break end
        end end
        x.Parent=parent;return x
    end
    local function round(x,r) mk('UICorner',{CornerRadius=UDim.new(0,r or 8)},x) end
    local root=mk('Frame',{Size=UDim2.fromOffset(360,520),Position=UDim2.new(.5,-180,.5,-260),
        BackgroundColor3=colors.bg,BorderSizePixel=0,Active=true},gui)
    root.ZIndex=2
    local overlay=mk('Frame',{Size=UDim2.fromScale(1,1),Position=UDim2.fromOffset(0,0),
        BackgroundColor3=Color3.fromRGB(0,0,0),BorderSizePixel=0,ZIndex=1,Visible=false,Active=false},gui)
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
    local farmAdvanced=false;U.advancedFarm={};U.searchMetadata={};U.showAdvanced=false
    function U:filterAdvanced()
        local query=self.search and self.search.Text:lower():sub(1,100) or ''
        for _,row in ipairs(self.advancedFarm) do row.Visible=self.showAdvanced and (query=='' or (self.searchMetadata[row] or row.Text):lower():find(query,1,true)~=nil) end
        if self.search then self.search.Visible=self.showAdvanced end
    end
    local function advanced(page,row,title)
        if page=='FARM' and farmAdvanced then U.advancedFarm[#U.advancedFarm+1]=row;row.Visible=U.showAdvanced end
        if title then U.searchMetadata[row]=title end
    end
    local function label(page,fn,color)
        order+=1
        local x=mk('TextLabel',{LayoutOrder=order,Size=UDim2.new(1,-6,0,0),AutomaticSize=Enum.AutomaticSize.Y,
            BackgroundTransparency=1,TextWrapped=true,TextSize=12,TextColor3=color or colors.muted,
            TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
            Font=Enum.Font.Gotham,Text=''},pages[page])
        U.labels[#U.labels+1]={x=x,fn=type(fn)=='function' and fn or function() return fn end}
        advanced(page,x)
    end
    local function button(page,title,fn)
        order+=1
        local x=mk('TextButton',{LayoutOrder=order,Size=UDim2.new(1,-6,0,44),BackgroundColor3=colors.card,
            TextColor3=colors.text,TextSize=12,TextWrapped=true,Font=Enum.Font.GothamSemibold,BorderSizePixel=0,
            Text=type(title)=='string' and title or ''},pages[page]);round(x)
        if type(title)=='function' then U.buttons[#U.buttons+1]={x=x,fn=title} end
        advanced(page,x)
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
        advanced(page,x,title)
        U.fields[#U.fields+1]={x=x,key=key}
        bind(x.FocusLost,function()
            app:set(key,numeric and tonumber(x.Text) or x.Text)
            x.Text=tostring(app.cfg[key] or '')
        end)
    end
    label('RUKIA','UPDATE 21 • LIVE ADAPTER UNVERIFIED',colors.accent)
    button('REPORTS','CAPTURE GAME DATA ONCE + COPY',function() app:captureGameData() end)
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
    label('FARM',function()
        local s=app.snapshot or {}
        return 'SMART AUTO / '..app.native.state..'\n'..app.native.reason..
            '\nObserved: '..tostring(s.mode or '?')..' | wave '..tostring(s.wave or '?')..
            ' | equipped '..#(s.roster or {})..'\n'..app.session:text()
    end,colors.text)
    button('FARM','READ GAME DATA + COPY REPORT',function() app:readSmartData() end)
    button('FARM','APPLY CLEAR-FIRST SETUP',function() app:applyClearFirst() end)
    button('FARM',function() return app.native.armed and 'STOP SMART AUTO' or 'START SMART AUTO • EXPERIMENTAL' end,function() app:toggleNative() end)
    button('FARM',function() return 'KEEP UI + AUTHORIZED AUTO AFTER TELEPORT: '..tostring(app.session.following) end,function() app:toggleFollow() end)
    label('FARM','Story / existing Dungeon run. Start new key-consuming Dungeons manually. Automatic spots use observed lanes and terrain; a missing legal spot stops with a blocker. Supervise the first clear.')
    button('FARM',function() return 'DUNGEON STRATEGY: '..app.cfg.dungeonPreset end,function() app:cycle('dungeonPreset',{'Safe','Rewards'}) end)
    button('FARM',function() return 'ALLOW OPENING FINAL DUNGEON CHESTS: '..tostring(app.cfg.dungeonOpenChests) end,function() app:toggle('dungeonOpenChests') end)
    field('FARM','Maximum Dungeon coins spent in this armed run (0 = skip shop)','dungeonShopCap',true)
    label('FARM',function() return app:dungeonBudgetText() end)
    button('FARM',function() return 'AUTHORIZE NEW DUNGEON COIN ALLOWANCE: '..app.cfg.dungeonShopCap end,function() app:reviewDungeonBudget() end)
    field('FARM','Optional shop priority: current item IDs separated by commas','dungeonBuyOrder',false)
    button('FARM',function() return 'SHRINES: EXACT ITEM WHITELIST ONLY / '..tostring(app.cfg.dungeonShrines) end,function() app:toggle('dungeonShrines') end)
    field('FARM','Every offered shrine item/curse must be listed by exact ID','dungeonShrineItems',false)
    label('FARM',function() return app:dungeonInfo() end)
    button('FARM',function() return 'AUTOMATIC WAVE START: '..tostring(app.cfg.autoStartWaves) end,function() app:toggle('autoStartWaves') end)
    button('FARM',function() return 'RETURN TO LOBBY AFTER STORY: '..tostring(app.cfg.autoReturnLobby) end,function() app:toggle('autoReturnLobby') end)
    button('FARM',function() return 'NEXT STORY AFTER VICTORY: '..tostring(app.cfg.autoNextStory) end,function() app:toggle('autoNextStory') end)
    button('FARM','COPY SMART AUTO REPORT',function() app:copyReport() end)
    button('FARM',function() return (U.showAdvanced and 'HIDE' or 'SHOW')..' ADVANCED / OLD TEST CONTROLS' end,function()
        U.showAdvanced=not U.showAdvanced
        U:filterAdvanced()
    end)
    order+=1
    U.search=mk('TextBox',{LayoutOrder=order,Size=UDim2.new(1,-6,0,44),BackgroundColor3=colors.card,
        TextColor3=colors.text,TextSize=12,Font=Enum.Font.Gotham,Text='',PlaceholderText='Search advanced controls',
        ClearTextOnFocus=false,BorderSizePixel=0,Visible=false},pages.FARM)
    round(U.search);bind(U.search:GetPropertyChangedSignal('Text'),function() U:filterAdvanced() end)
    farmAdvanced=true
    field('FARM','Macro name (letters/numbers/underscore; separate local files)','macroName',false)
    label('FARM',function() return app.macro:text()..' | recorded steps '..tostring(app.macro.data and #app.macro.data.steps or 0) end)
    button('FARM','START RECORDING OUR VERIFIED ACTIONS',function() app:startMacroRecording() end)
    button('FARM','STOP RECORDING + SAVE MACRO',function() app:finishMacroRecording() end)
    button('FARM','LOAD NAMED MACRO',function() app:loadMacro() end)
    button('FARM','START / STOP MACRO THROUGH NATIVE RUNTIME',function() app:toggleMacro() end)
    button('FARM','COPY DATA-ONLY MACRO',function() app:copyMacro() end)
    button('FARM','IMPORT VALIDATED MACRO FROM CLIPBOARD',function() app:importMacro() end)
    button('FARM','RENAME LOADED MACRO TO FIELD NAME',function() app:renameMacro() end)
    button('FARM','DELETE NAMED MACRO • BACKUP FIRST',function() app:deleteMacro() end)
    button('FARM',function() return 'MANUAL CAPTURE ACTION: '..app.cfg.manualMacroKind end,function() app:cycle('manualMacroKind',{'place','upgrade','priority','ability','sell'}) end)
    button('FARM','MANUAL CAPTURE: SAVE BEFORE STATE',function() app:beginManualMacro() end)
    button('FARM','MANUAL CAPTURE: RECORD ONE AFTER CHANGE',function() app:endManualMacro() end)
    button('FARM',function() return 'MACRO IGNORE WAVE TIMING: '..tostring(app.cfg.macroIgnoreTiming) end,function() app:toggle('macroIgnoreTiming') end)
    button('FARM',function() return 'PLACEMENT ORDER: '..app.cfg.autoMethod end,function() app:cycle('autoMethod',{'RoundRobin','Cheapest','Custom'}) end)
    button('FARM',function() return 'UPGRADE PRIORITY: '..app.cfg.autoUpgradeMethod end,function() app:cycle('autoUpgradeMethod',{'LowestLevel','Cheapest','SlotOrder','Custom'}) end)
    field('FARM','Custom slot order (1–6, comma separated)','slotOrder',false)
    field('FARM','Placement caps by slot: 0 = game cap; -1 = disabled','placeCaps',false)
    field('FARM','Upgrade caps by slot: 0 = max; -1 = no upgrades','upgradeCaps',false)
    field('FARM','Earliest placement waves for slots 1–6','placeWaves',false)
    field('FARM','Earliest upgrade waves for slots 1–6','upgradeWaves',false)
    button('FARM',function() return 'VOTE ON OBSERVED WAVE SKIP OFFERS: '..tostring(app.cfg.autoSkip) end,function() app:toggle('autoSkip') end)
    field('FARM','Stop skip voting at wave (0 = no wave limit)','skipStopWave',true)
    field('FARM','Sell known sellable farms at wave (0 = disabled; Bulma excluded)','sellFarmWave',true)
    field('FARM','Sell known sellable towers at wave (0 = disabled)','sellAllWave',true)
    field('FARM','Delay after confirmed Story victory (seconds)','finishDelay',true)
    button('FARM',function() return 'UPGRADE WHILE SAVING AFTER FIRST DEFENDER: '..tostring(app.cfg.upgradeBetweenPlacements) end,function() app:toggle('upgradeBetweenPlacements') end)
    button('FARM',function() return 'AFFORDABLE FARM UPGRADES FIRST: '..tostring(app.cfg.focusFarm) end,function() app:toggle('focusFarm') end)
    button('FARM',function() return 'OBSERVED NORMAL ABILITIES: '..tostring(app.cfg.autoAbilities) end,function() app:toggle('autoAbilities') end)
    field('FARM','Minimum gap between same-unit normal abilities (seconds)','abilityGap',true)
    label('FARM','Abilities need exact cooldown/cast and enemy range data. Buff chains and meter/toggle semantics remain blocked until observed.')
    button('FARM',function() return 'NATIVE TARGET PRIORITY: '..app.cfg.autoTarget end,function() app:cycle('autoTarget',{'GameDefault','first','last','strongest','weakest','closest','farthest'}) end)
    button('FARM',function() return 'OBSERVED BOSS TARGET: '..app.cfg.autoBossTarget end,function() app:cycle('autoBossTarget',{'GameDefault','first','last','strongest','weakest','closest','farthest'}) end)
    label('FARM',function() return app:farmText() end,colors.text)
    button('FARM','READ MATCH DATA + COPY COMBAT REPORT',function() app:readMatchData() end)
    label('FARM',function() return app.team:text(app.snapshot,app.teamProfile) end,colors.text)
    label('FARM','RECORDED STORY TEAM\nPlace each equipped unit manually once, then record. Partial captures save automatically; repeat as more slots are placed. Team Auto requires every equipped slot and uses those spots in the same stage. Other units/replay still need supervised live testing.')
    button('FARM','RECORD + SAVE TEAM POSITIONS',function() app:recordTeam() end)
    button('FARM','CHECK TEAM READINESS',function() app:checkTeam() end)
    button('FARM',function() return app.team.armed and 'STOP TEAM AUTO' or 'START TEAM AUTO • EXPERIMENTAL STORY' end,function() app:toggleTeam() end)
    button('FARM','COPY TEAM REPORT',function() app:copyTeamReport() end)
    label('FARM','First combat test: enter a free Story stage, start waves and place one equipped unit manually. Then read match data here. Compare cash/costs with the game. This action stops combat and sends no placement or upgrade.')
    button('FARM',function() return app.engine.armed and 'STOP RUKIA ROUTE AUTO' or 'RUKIA ROUTE AUTO: OFF • UNVERIFIED' end,function() app:toggleFarm() end)
    button('FARM','CHECK READINESS',function() app:checkReady() end)
    button('FARM','RECORD CURRENT OWN PLACEMENTS',function() app:record() end)
    label('FARM','SINGLE-ACTION STORY TESTS\nRecord one tower from the selected slot; other defenders may stay placed. These buttons spend the displayed match Yen once and stop. Keep Full Auto OFF; leave the game controls alone during the 8-second readback. The report copies automatically. A successful test does not confirm a Rukia farming route.')
    button('FARM',function() return 'TEST TARGET: EQUIPPED SLOT '..app.cfg.trialSlot end,function()
        app:cycle('trialSlot',{1,2,3,4,5,6,7,8})
    end)
    button('FARM','RECORD ONE TEST TARGET',function() app:recordTrialTarget() end)
    label('FARM','For an unsellable target: save settings after recording, enter the same Story stage fresh, load this script, read match data and start waves. Use TEST ONE PLACEMENT with the saved target position.')
    button('FARM',function() return app:trialButton('upgrade') end,function() app:runTrial('upgrade') end)
    button('FARM',function() return app:trialButton('place') end,function() app:runTrial('place') end)
    button('FARM','STOP SINGLE-ACTION TEST',function() app:stopTrial() end)
    label('FARM',function() return app.trial:text() end,colors.text)
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
    button('REPORTS','COPY COMBAT REPORT',function() app:copyCombatReport() end)
    button('REPORTS','COPY TEAM REPORT',function() app:copyTeamReport() end)
    button('REPORTS','SCAN DATA PATHS + COPY REPORT',function() app:scanPathsAndCopy() end)
    button('REPORTS','SAVE BOUNDED REPORT LOCALLY',function() app:saveReport() end)
    farmAdvanced=false
    label('REPORTS',function() return app:reportStatus() end,colors.text)
    label('REPORTS',function() return app:recentLogs() end)
    label('SETTINGS','MOBILE / RESOURCE PROTECTION',colors.accent)
    field('SETTINGS','Yen reserve','reserve',true)
    field('SETTINGS','Maximum confirmed runs per armed session','maxRuns',true)
    field('SETTINGS','Session timeout (seconds)','maxSeconds',true)
    field('SETTINGS','Placement anchor along observed path (0 spawn / 100 base)','autoDistance',true)
    field('SETTINGS','Ground search radius (% of planning range)','autoGround',true)
    field('SETTINGS','Hill search radius (% of planning range)','autoHill',true)
    field('SETTINGS','Player inventory path (e.g. player/owned_units)','inventoryPath',false)
    field('SETTINGS','Player item count path (e.g. player/_data/items)','resourcePath',false)
    field('SETTINGS','Optional match Yen Value path (verify it belongs to you)','cashPath',false)
    button('SETTINGS','SAVE SETTINGS / RECORDED PROFILE',function() app:saveSettings() end)
    button('SETTINGS','COPY CONFIGURATION (contains unit UUIDs)',function() app:copyConfig() end)
    button('SETTINGS','STOP + CLOSE',function() app:stop() end)
    label('SETTINGS','No hooks or GC scans. One mutation at a time. Ordinary loads stay unarmed; explicit teleport continuation must verify its destination and original limits. Close revokes following; minimize keeps this observer. Zeno must be closed.')
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
    local function secretField(page,title,callback)
        label(page,title);order+=1
        local x=mk('TextBox',{LayoutOrder=order,Size=UDim2.new(1,-6,0,44),BackgroundColor3=colors.card,TextColor3=colors.text,
            Text='',PlaceholderText='Paste, submit, then cleared from view',TextSize=12,Font=Enum.Font.Gotham,ClearTextOnFocus=false},pages[page])
        round(x);bind(x.FocusLost,function() local value=x.Text;x.Text='';if value~='' then callback(value) end end)
    end
    addAdvanced(app,label,button,field,secretField)
    function U:refresh()
        if not self.alive then return end
        for _,field in ipairs(self.fields) do
            if not field.x:IsFocused() then
                local value=tostring(app.cfg[field.key] or '')
                if field.x.Text~=value then field.x.Text=value end
            end
        end
        for _,row in ipairs(self.labels) do local text=tostring(row.fn());if row.x.Text~=text then row.x.Text=text end end
        for _,row in ipairs(self.buttons) do local text=tostring(row.fn());if row.x.Text~=text then row.x.Text=text end end
        self:filterAdvanced();overlay.Visible=app.cfg.blackScreen==true
        if self.lastTheme~=app.cfg.uiTheme then
            self.lastTheme=app.cfg.uiTheme
            local bg=app.cfg.uiTheme=='OLED' and Color3.fromRGB(0,0,0) or app.cfg.uiTheme=='Midnight' and Color3.fromRGB(8,12,32) or Color3.fromRGB(13,17,25)
            root.BackgroundColor3=bg
            if app.cfg.uiTheme=='Midnight' then colors.card=Color3.fromRGB(24,28,56);colors.active=Color3.fromRGB(55,49,109)
            else colors.card=Color3.fromRGB(24,31,43);colors.active=Color3.fromRGB(29,83,99) end
            for _,item in ipairs(styles) do if item.role~='bg' then pcall(function() item.x[item.prop]=colors[item.role] end) end end
            for name,tab in pairs(tabs) do tab.BackgroundColor3=name==self.page and colors.active or colors.card end
        end
        local active=app.native.armed and app.native or (app.team.armed and app.team or app.engine)
        footer.Text=active.state..' • '..tostring(app.status):sub(1,140)
        local cam=workspace.CurrentCamera
        if cam then
            local insets={}
            pcall(function()
                local a,b=game:GetService('GuiService'):GetGuiInset()
                insets={left=a.X,top=a.Y,right=b.X,bottom=b.Y}
            end)
            local fit=viewMath.fit(cam.ViewportSize.X,cam.ViewportSize.Y,app.cfg.uiScale,insets)
            if fit then
                scale.Scale=fit.scale
                local p,size=root.AbsolutePosition,root.AbsoluteSize
                local dx=math.clamp(p.X,fit.minX,math.max(fit.minX,fit.maxRight-size.X))-p.X
                local dy=math.clamp(p.Y,fit.minY,math.max(fit.minY,fit.maxBottom-size.Y))-p.Y
                if math.abs(dx)>1 or math.abs(dy)>1 then root.Position=root.Position+UDim2.fromOffset(dx,dy) end
            end
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
