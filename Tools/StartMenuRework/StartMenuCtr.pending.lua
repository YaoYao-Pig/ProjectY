local LuaLanguage = require('Language')
local Class=require('Core.Class')
local Base=require('UI.UIPanelCtrl')
local Rich=require('UI.RichText')
local Starts=require('Game.Adventure.CampaignStarts')
local Menu=Class('StartMenuCtr',Base)
local sizes={2500,10000,30000,100000}
local sizeKeys={'CampaignSizeSmall','CampaignSizeMedium','CampaignSizeLarge','CampaignSizeHuge'}
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
    self:Listen(self.view.Back,function()self:Back()end)
    self:Listen(self.view.Settings,function()self:Dialog('settings')end)
    self:Listen(self.view.About,function()self:Dialog('about')end)
    self:Listen(self.view.Quit,function()self:Dialog('quit')end)
    self:Listen(self.view.DialogCancel,function()self:CloseDialog()end)
    self:Listen(self.view.DialogConfirm,function()self:ConfirmDialog()end)
    self:Listen(self.view.LoadSelected,function()
        if not self.view.Style.IsTransitioning and self.selectedSave and self.selectedSave.CanLoad then
            self:Complete(self.bridge.Load(self.demo,self.selectedSave.Id))
        end
    end)
    local back=function()self:Back()end
    self.view.Style.BackRequested:AddListener(back)
    self.lifetime:Add(function()self.view.Style.BackRequested:RemoveListener(back)end)
    self:Listen(self.view.Resume,function()
        if not self.view.Style.IsTransitioning and self.bridge.HasSession(self.demo) then self.context.systems:Get('UI'):Close(self.panelName) end
    end)
    self:Listen(self.view.RandomSeed,function()self.view.Seed.text=self.bridge.RandomSeed();self:ValidateSeed()end)
    self:Listen(self.view.Create,function()
        if self.view.Style.IsTransitioning or not self:ValidateSeed() then return end
        self:Complete(self.bridge.NewGame(self.demo,self.view.Seed.text,assert(sizes[self.view.Size.value+1],'Unknown world size'),self.selectedStart,self.view.WorldName.text))
    end)
    local changed=function()if self.mode=='new' then self:ValidateSeed()end end
    self.view.Seed.onValueChanged:AddListener(changed)
    self.lifetime:Add(function()self.view.Seed.onValueChanged:RemoveListener(changed)end)
end
function Menu:OnShow(args)
    self.demo=assert(args.demo);self.font=self.bridge.Font(self.demo)
    for i,key in ipairs(sizeKeys) do self.view.Size.options[i-1].text=LuaLanguage[key] end
    self.view.Size:RefreshShownValue()
    self.view.Style:Prepare(self.font,820);self.bridge.OnOpen(self.demo)
    self.view.Style:Begin(self.bridge.Preview(self.demo))
    self:CloseDialog();self:Page(args.mode or 'home',false)
    if args.errorMessage then self.view.Hint.text=args.errorMessage end
end
function Menu:ValidateSeed()
    local valid=seedValid(self.view.Seed.text)
    self.view.Create.interactable=valid
    self.view.Hint.text=valid and '' or LuaLanguage.UIStartMenuHintText
    return valid
end
function Menu:Page(mode,animate)
    assert(mode=='home' or mode=='new' or mode=='load','Unknown campaign menu page')
    if self.view.Style.IsTransitioning or self.dialog then return end
    self.mode=mode;self.view.Hint.text=''
    self.view.Style:Prepare(self.font,mode=='new' and 1100 or 820)
    self.view.Back.gameObject:SetActive(mode~='home')
    self.view.Resume.gameObject:SetActive(mode~='new' and self.bridge.HasSession(self.demo))
    if mode=='home' then
        self.view.Title.text=LuaLanguage.UIStartMenuTitleText3;self.view.Caption.text=LuaLanguage.UIStartMenuCaptionText3
        self.view.Style:UpdateHome(self.bridge.Preview(self.demo))
    elseif mode=='new' then
        self.view.Title.text=LuaLanguage.UIStartMenuTitleText2;self.view.Caption.text=LuaLanguage.StartOriginCaption
        self:SelectStart(self.selectedStart)
        if self.view.Seed.text=='' then self.view.Seed.text=self.bridge.RandomSeed() end
        self:ValidateSeed()
    else
        self.view.Title.text=LuaLanguage.UIStartMenuTitleText;self.view.Caption.text=LuaLanguage.UIStartMenuCaptionText
        self:RefreshSaves();self.view.SaveScroll.verticalNormalizedPosition=1
    end
    self.view.Style:ShowPage(mode=='home' and 0 or mode=='new' and 1 or 2,animate~=false)
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
    self.selectedSave=nil;self.view.LoadSelected.interactable=false
    self.view.SelectedTitle.text=LuaLanguage.MenuSelectWorld;self.view.SelectedInfo.text=''
    self.view.SelectedMap.gameObject:SetActive(false)
    self.view.SelectedTitle.gameObject:SetActive(false);self.view.SelectedInfo.gameObject:SetActive(false)
    self.view.LoadSelected.gameObject:SetActive(false)
    local ok,saves=pcall(function()return self.bridge.Saves(self.demo)end)
    if not ok then
        for _,row in ipairs(self.rows)do row:SetData(nil)end
        self.view.Empty.text=LuaLanguage.UIStartMenuEmptyText2;self.view.Empty.gameObject:SetActive(true)
        self.view.Hint.text=tostring(saves);return
    end
    local count=saves.Length
    self.view.SelectedTitle.gameObject:SetActive(count>0);self.view.SelectedInfo.gameObject:SetActive(count>0)
    self.view.LoadSelected.gameObject:SetActive(count>0)
    self.view.Empty.text=LuaLanguage.UIStartMenuEmptyText
    self.view.Empty.gameObject:SetActive(count==0)
    for i=1,count do
        local saved=saves[i-1];local id=saved.Id
        if not self.rows[i] then self.rows[i]=self:CreateWidget('CampaignSaveEntry',self.view.SaveContent) end
        local title=saved.WorldName~='' and string.format(LuaLanguage.CampaignNamedSave,saved.WorldName,saved.SavedAt)
            or string.format(saved.Legacy and LuaLanguage.CampaignLegacySave or LuaLanguage.CampaignUnnamedSave,saved.SavedAt)
        local size=saved.HasWorld and (saved.TargetCells>0 and (string.format(LuaLanguage.UIStartMenuSize3, (saved.TargetCells))) or LuaLanguage.UIStartMenuSize2) or LuaLanguage.UIStartMenuSize
        local body=string.format(LuaLanguage.UIStartMenuBody, (tostring(saved.Seed)), (size), (saved.PartySummary))
        if not saved.CanLoad then body=body..'\n'..saved.Error end
        self.rows[i]:SetData({title=Rich.Escape(title),body=Rich.Escape(body),available=saved.CanLoad,
            canDelete=self.bridge.CanDelete(self.demo,id)},self.font,function()
            if not self.view.Style.IsTransitioning and saved.CanLoad then self:SelectSave(saved,i) end
        end,function()if not self.view.Style.IsTransitioning then self.pendingDelete=saved;self:Dialog('delete') end end)
    end
    for i=count+1,#self.rows do self.rows[i]:SetData(nil) end
    for i=1,count do if saves[i-1].CanLoad then self:SelectSave(saves[i-1],i);break end end
end
function Menu:SelectSave(saved,index)
    self.selectedSave=saved
    for i,row in ipairs(self.rows) do if row.row then
        row.row.selected=i==index
        row:SetData(row.row,self.font,row.action,row.deleteAction)
    end end
    local preview=self.bridge.PreviewSave(self.demo,saved.Id)
    self.view.Style:PreviewSelected(preview);self.view.SelectedMap.gameObject:SetActive(true)
    self.view.SelectedTitle.text=saved.WorldName~='' and saved.WorldName or LuaLanguage.MenuUnnamedWorld
    local status=preview.Status==1 and LuaLanguage.MenuSnapshotReady or preview.Status==3 and LuaLanguage.MenuPreviewUnreadable or LuaLanguage.MenuPreviewMissing
    self.view.SelectedInfo.text=string.format(LuaLanguage.MenuSelectedInfo,tostring(saved.Seed),saved.TargetCells,saved.PartySummary,status)
    self.view.LoadSelected.interactable=saved.CanLoad
end
function Menu:Back()
    if self.view.Style.IsTransitioning then return end
    if self.dialog then self:CloseDialog() elseif self.mode~='home' then self:Page('home') end
end
function Menu:CloseDialog()
    self.dialog=nil;self.pendingDelete=nil;self.view.Dialog.gameObject:SetActive(false)
end
function Menu:Dialog(kind)
    if self.view.Style.IsTransitioning then return end
    self.dialog=kind;self.view.Dialog.gameObject:SetActive(true)
    self.view.SettingsContent.gameObject:SetActive(kind=='settings')
    self.view.DialogText.gameObject:SetActive(kind~='settings')
    self.view.DialogConfirm.gameObject:SetActive(kind~='about')
    self.view.DialogConfirmText.text=LuaLanguage.MenuConfirm
    if kind=='settings' then
        self.view.DialogTitle.text=LuaLanguage.MenuSettings
        local values=self.bridge.Volumes(self.demo)
        self.view.MasterVolume.value=values[0];self.view.MusicVolume.value=values[1];self.view.EffectsVolume.value=values[2]
        self.view.ReducedMotion.isOn=self.view.Style.ReducedMotion
        self.view.DialogConfirmText.text=LuaLanguage.MenuApply
    elseif kind=='about' then
        self.view.DialogTitle.text=LuaLanguage.MenuAbout
        self.view.DialogText.text=string.format(LuaLanguage.MenuAboutVersion,CS.UnityEngine.Application.productName,CS.UnityEngine.Application.version)
    elseif kind=='delete' then
        local saved=assert(self.pendingDelete,'Missing save deletion selection')
        self.view.DialogTitle.text=LuaLanguage.MenuDeleteTitle
        self.view.DialogText.text=string.format(LuaLanguage.MenuDeletePrompt,saved.WorldName~='' and saved.WorldName or LuaLanguage.MenuUnnamedWorld)
        self.view.DialogConfirmText.text=LuaLanguage.MenuDelete
    else
        assert(kind=='quit','Unknown menu dialog')
        self.view.DialogTitle.text=LuaLanguage.MenuQuit;self.view.DialogText.text=LuaLanguage.MenuQuitPrompt
    end
end
function Menu:ConfirmDialog()
    if self.dialog=='settings' then
        self.bridge.SetOptions(self.demo,self.view.MasterVolume.value,self.view.MusicVolume.value,self.view.EffectsVolume.value,self.view.ReducedMotion.isOn)
        self:CloseDialog()
    elseif self.dialog=='delete' then
        local saved=assert(self.pendingDelete)
        local success=self.bridge.Delete(self.demo,saved.Id)
        self:CloseDialog();self:RefreshSaves();self.view.Style:UpdateHome(self.bridge.Preview(self.demo))
        self.view.Hint.text=success and LuaLanguage.MenuDeleted or self.bridge.LastError(self.demo)
    elseif self.dialog=='quit' then self.bridge.Quit() end
end
function Menu:OnHide()
    self:CloseDialog();self.view.Style:Release();self.selectedSave=nil
    if self.demo then self.bridge.OnClose(self.demo);self.demo=nil end
    self.font=nil;self.mode=nil
end
return Menu
