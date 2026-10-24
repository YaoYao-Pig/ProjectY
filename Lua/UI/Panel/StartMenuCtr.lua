local LuaLanguage = require('Language')
local Class=require('Core.Class')
local Base=require('UI.UIPanelCtrl')
local Rich=require('UI.RichText')
local Starts=require('Game.Adventure.CampaignStarts')
local Menu=Class('StartMenuCtr',Base)
local sizes={2500,10000,30000,100000}
local function seedValid(text)
    if type(text)~='string' or not text:match('^%d+$') then return false end
    local value=tonumber(text)
    return value~=nil and value>=0 and value<=4294967295 and value==math.floor(value)
end
function Menu:Bind()
    self.rows={};self.startRows={};self.itemRows={};self.bridge=CS.ProjectY.Samples.CampaignMenu
    self.config=self.context.systems:Get('Config');self.starts=Starts.List(self.config);self.selectedStart=1
    self:Listen(self.view.Start,function()self:Page('new')end)
    self:Listen(self.view.Load,function()self:Page('load')end)
    self:Listen(self.view.Back,function()self:Page('home')end)
    self:Listen(self.view.Resume,function()
        if self.bridge.HasSession(self.demo) then self.context.systems:Get('UI'):Close(self.panelName) end
    end)
    self:Listen(self.view.RandomSeed,function()self.view.Seed.text=self.bridge.RandomSeed();self:ValidateSeed()end)
    self:Listen(self.view.Create,function()
        if not self:ValidateSeed() then return end
        self:Complete(self.bridge.NewGame(self.demo,self.view.Seed.text,assert(sizes[self.view.Size.value+1],'Unknown world size'),self.selectedStart))
    end)
    local changed=function()if self.mode=='new' then self:ValidateSeed()end end
    self.view.Seed.onValueChanged:AddListener(changed)
    self.lifetime:Add(function()self.view.Seed.onValueChanged:RemoveListener(changed)end)
end
function Menu:OnShow(args)
    self.demo=assert(args.demo);self.font=self.bridge.Font(self.demo)
    self.view.Style:Prepare(self.font,820);self.bridge.OnOpen(self.demo)
    self:Page(args.mode or 'home')
    if args.errorMessage then self.view.Hint.text=args.errorMessage end
end
function Menu:ValidateSeed()
    local valid=seedValid(self.view.Seed.text)
    self.view.Create.interactable=valid
    self.view.Hint.text=valid and '' or LuaLanguage.UIStartMenuHintText
    return valid
end
function Menu:Page(mode)
    assert(mode=='home' or mode=='new' or mode=='load','Unknown campaign menu page')
    self.mode=mode;self.view.Hint.text=''
    self.view.Style:Prepare(self.font,mode=='new' and 1100 or 820)
    self.view.HomePage.gameObject:SetActive(mode=='home')
    self.view.NewPage.gameObject:SetActive(mode=='new')
    self.view.LoadPage.gameObject:SetActive(mode=='load')
    self.view.Back.gameObject:SetActive(mode~='home')
    self.view.Resume.gameObject:SetActive(mode~='new' and self.bridge.HasSession(self.demo))
    if mode=='home' then
        self.view.Title.text=LuaLanguage.UIStartMenuTitleText3;self.view.Caption.text=LuaLanguage.UIStartMenuCaptionText3
    elseif mode=='new' then
        self.view.Title.text=LuaLanguage.UIStartMenuTitleText2;self.view.Caption.text=LuaLanguage.StartOriginCaption
        self:SelectStart(self.selectedStart)
        if self.view.Seed.text=='' then self.view.Seed.text=self.bridge.RandomSeed() end
        self:ValidateSeed()
    else
        self.view.Title.text=LuaLanguage.UIStartMenuTitleText;self.view.Caption.text=LuaLanguage.UIStartMenuCaptionText
        self:RefreshSaves();self.view.SaveScroll.verticalNormalizedPosition=1
    end
end
function Menu:SelectStart(id)
    local preview=Starts.Preview(self.config,id);self.selectedStart=preview.id
    for i,start in ipairs(self.starts) do
        if not self.startRows[i] then self.startRows[i]=self:CreateWidget('NarrativeEntry',self.view.Origins) end
        local startId=start.id
        self.startRows[i]:SetData({title=Rich.Escape(start.name),body='',selected=startId==id},self.font,function()self:SelectStart(startId)end)
    end
    self.view.StartName.DefaultText=Rich.Escape(preview.name)
    self.view.StartDescription.DefaultText=Rich.Escape(preview.description)
    local companions={};for i=2,#preview.partyNames do companions[#companions+1]=preview.partyNames[i] end
    self.view.StartParty.DefaultText=Rich.Escape(string.format(LuaLanguage.StartOriginParty,preview.partyNames[1],table.concat(companions,LuaLanguage.StartOriginSeparator)))
    self.view.StartKitTitle.DefaultText=LuaLanguage.StartOriginKit
    self.view.OriginsTitle.text=string.format(LuaLanguage.StartOriginCount,#self.starts)
    self.view.CreateText.text=string.format(LuaLanguage.StartOriginCreate,preview.name)
    local items={{kind='coins',name=LuaLanguage.MissionRewardCoins,amount=preview.coins,note=LuaLanguage.StartOriginCoins}}
    for _,row in ipairs(preview.equipmentRows) do
        items[#items+1]={kind='item',itemId=row.itemId,name=row.name,amount=row.count,iconPath=row.iconPath,
            note=#row.equippedBy>0 and LuaLanguage.StartOriginEquipped or LuaLanguage.MissionRewardToInventory}
    end
    for i,row in ipairs(items) do
        if not self.itemRows[i] then self.itemRows[i]=self:CreateWidget('MissionReward',self.view.StartItems) end
        self.itemRows[i]:SetData(row,self.font)
    end
    for i=#items+1,#self.itemRows do self.itemRows[i]:SetData(nil) end
    self.view.StartDetailScroll.verticalNormalizedPosition=1
end
function Menu:Complete(success)
    if success then self.context.systems:Get('UI'):Close(self.panelName)
    else self.view.Hint.text=self.bridge.LastError(self.demo) end
end
function Menu:RefreshSaves()
    local ok,saves=pcall(function()return self.bridge.Saves(self.demo)end)
    if not ok then
        for _,row in ipairs(self.rows)do row:SetData(nil)end
        self.view.Empty.text=LuaLanguage.UIStartMenuEmptyText2;self.view.Empty.gameObject:SetActive(true)
        self.view.Hint.text=tostring(saves);return
    end
    local count=saves.Length
    self.view.Empty.text=LuaLanguage.UIStartMenuEmptyText
    self.view.Empty.gameObject:SetActive(count==0)
    for i=1,count do
        local saved=saves[i-1];local id=saved.Id
        if not self.rows[i] then self.rows[i]=self:CreateWidget('NarrativeEntry',self.view.SaveContent) end
        local title=(saved.Legacy and LuaLanguage.UIStartMenuTitle2 or LuaLanguage.UIStartMenuTitle)..saved.SavedAt
        local size=saved.HasWorld and (saved.TargetCells>0 and (string.format(LuaLanguage.UIStartMenuSize3, (saved.TargetCells))) or LuaLanguage.UIStartMenuSize2) or LuaLanguage.UIStartMenuSize
        local body=string.format(LuaLanguage.UIStartMenuBody, (tostring(saved.Seed)), (size), (saved.PartySummary))
        if not saved.CanLoad then body=body..'\n'..saved.Error end
        self.rows[i]:SetData({title=Rich.Escape(title),body=Rich.Escape(body),available=saved.CanLoad},self.font,function()
            if saved.CanLoad then self:Complete(self.bridge.Load(self.demo,id)) end
        end)
    end
    for i=count+1,#self.rows do self.rows[i]:SetData(nil) end
end
function Menu:OnHide()
    if self.demo then self.bridge.OnClose(self.demo);self.demo=nil end
    self.font=nil;self.mode=nil
end
return Menu
