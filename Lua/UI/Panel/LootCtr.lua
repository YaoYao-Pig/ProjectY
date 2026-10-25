local LuaLanguage = require('Language')
local Class=require('Core.Class')
local Panel=require('UI.UIPanelCtrl')
local BagModel=require('Game.Equipment.InventoryModel')
local LootModel=require('Game.Loot.LootModel')
local Text=require('Game.Equipment.EquipmentPresentation')
local Loot=Class('LootCtr',Panel)
function Loot:Bind()
    self.adventure=self.context.systems:Get('Adventure');self.equipment=self.adventure.equipment
    self.terms=require('UI.EquipmentTermPresenter').New(self.view,self.equipment.config)
    self.worldLoot=self.equipment.worldLoot;self.session=self.worldLoot.session
    self.bagModel=BagModel.New(self.equipment,self.adventure.battle.stats);self.lootModel=LootModel.New(self.worldLoot)
    local function command(action)
        local ok,err=xpcall(function() self:Command(action) end,debug.traceback)
        if not ok then self.context.log(err) end
    end
    self.view.Inventory.Command:AddListener(command)
    self.lifetime:Add(function() self.view.Inventory.Command:RemoveListener(command) end)
    self:Listen(self.view.Close,function() self:Close() end)
    local function selectSource(index)
        if self.updatingSources then return end
        self.view.Loot:CancelDrag();self.session:SelectContainer(assert(self.sourceIds[index+1]))
        self.selected='';self.message=LuaLanguage.UILootMessage
        self.view.Loot:Prepare();self:RefreshLoot();self:Details()
    end
    self.view.Sources.onValueChanged:AddListener(selectSource)
    self.lifetime:Add(function() self.view.Sources.onValueChanged:RemoveListener(selectSource) end)
end
function Loot:OnShow(args)
    assert(self.session.Active,'Loot UI requires an active container session')
    self.demo=assert(args.demo);self.demo:SetEquipmentOpen(true)
    self.selected=''
    self.message=self.session.SelectedContainerId==0 and self.session.ContainerCount>1 and LuaLanguage.UILootMessage3 or LuaLanguage.UILootMessage2
    self.actorId=self.adventure.data:GetPartyAt(0).Id
    self.view.Loot:Prepare();self.view.Title.text=self.session.Title;self.view.Summary.text=self.session.Summary
    self.updatingSources=true;self.sourceIds={};self.view.Sources:ClearOptions();local selected=0
    local function add(id,name)
        self.sourceIds[#self.sourceIds+1]=id
        self.view.Sources.options:Add(CS.UnityEngine.UI.Dropdown.OptionData(name))
        if id==self.session.SelectedContainerId then selected=#self.sourceIds-1 end
    end
    if self.session.ContainerCount~=1 then add(0,LuaLanguage.UILootText) end
    for i=0,self.session.ContainerCount-1 do local container=self.session:GetContainerAt(i);add(container.Id,container.Name) end
    self.view.Sources:SetValueWithoutNotify(selected);self.view.Sources:RefreshShownValue()
    self.view.Sources.interactable=self.session.ContainerCount>1;self.updatingSources=false
    self:RefreshBag();self:RefreshLoot();self:Details();self.terms:Reset()
end
function Loot:RefreshBag()
    local rows={}
    for _,row in ipairs(self.bagModel:Rows(self.actorId)) do if row.slot=='' then rows[#rows+1]=row end end
    self.bagRows=rows;local data=self.equipment.data
    self.view.Inventory:Render({width=data.Grid.Width,height=data.Grid.Height,selected=self.selected,items=rows})
    local used=0;for i=0,data.Grid.Count-1 do local place=data.Grid:GetAt(i);used=used+place.Width*place.Height end
    self.view.Capacity.text=string.format(LuaLanguage.UILootCapacityText,data.Grid.Width,data.Grid.Height,used,data.Grid.Width*data.Grid.Height-used)
    self.bagRevision=data.Revision
end
function Loot:RefreshLoot()
    local rows,width,height=self.lootModel:Rows();self.lootRows=rows
    self.view.Loot:Render({width=width,height=height,selected=self.selected,items=rows,canEdit=self.session.SelectedContainerId~=0})
    local remaining,unknown=0,0
    for _,row in ipairs(rows) do if row.count>0 then remaining=remaining+1;if not row.revealed then unknown=unknown+1 end end end
    self.view.SearchStatus.text=unknown>0 and string.format(LuaLanguage.UILootSearchStatusText2,remaining,unknown) or string.format(LuaLanguage.UILootSearchStatusText,remaining)
    self.view.Empty.text=remaining==0 and (self.session.SelectedContainerId~=0 and LuaLanguage.UILootEmptyText2 or LuaLanguage.UILootEmptyText) or ''
    self.lootRevision=self.session.Revision
end
function Loot:Details()
    local selected
    for _,rows in ipairs({self.bagRows,self.lootRows}) do
        for _,row in ipairs(rows) do if row.key==self.selected and row.count>0 then selected=row end end
    end
    self.view.ItemName.text=selected and selected.displayName or LuaLanguage.UILootItemNameText
    self.view.DetailsRarityFrame:Configure(selected~=nil and selected.legendary,selected and selected.rarityColor or '',true)
    self.view.ItemDetail.text=selected and (selected.revealed==false and Text.Note(selected.detail) or selected.detail..'\n\n'..Text.Note(string.format(LuaLanguage.UIInventoryItemDetailText6,selected.width,selected.height,selected.count))) or Text.Note(LuaLanguage.UILootItemDetailText)
    if self.detailsKey~=self.selected then self.view.ItemDetail.rectTransform.anchoredPosition=CS.UnityEngine.Vector2.zero;self.detailsKey=self.selected end
    self.view.Status.text=self.message
end
function Loot:Command(action)
    local input=self.view.Inventory;local key=input.ActionKey
    if action=='select' then self.selected=key;self:RefreshLoot();self:Details();return end
    if action=='cancel' then self.message=LuaLanguage.UIInventoryMessage;self:Details();return end
    assert(action=='move' or action=='move_source','Unexpected loot action: '..tostring(action))
    local entry=self.session:Find(key);local ok,reason
    if action=='move_source' then
        if entry then ok,reason=self.worldLoot:Move(self.adventure.areas,key,input.ActionX,input.ActionY,input.ActionRotated)
        else ok,reason=self.worldLoot:Put(self.adventure.areas,key,input.ActionX,input.ActionY,input.ActionRotated) end
    elseif entry then
        ok,reason=self.adventure:TakeLoot(key,input.ActionX,input.ActionY,input.ActionRotated)
        if ok then reason=string.format(LuaLanguage.UILootReason2, (reason)) end
    else
        ok,reason=self.bagModel:Command('move',self.actorId,key,input.ActionX,input.ActionY,input.ActionRotated)
        if ok then reason=LuaLanguage.UILootReason end
    end
    self.message=reason;self.selected=key
    self:RefreshBag();self:RefreshLoot();self:Details()
    if ok then self.demo:SendCommand('snapshot') end
end
function Loot:Tick(_,unscaledDt)
    require('UI.EquipmentRarity').Tick()
    if not self.session.Active then self:Close();return end
    local searching=self.lootModel:Searching()
    if searching then
        self.session:Advance(searching.Key,unscaledDt,1.1)
        if self.lootRevision~=self.session.Revision then self:RefreshLoot();self:Details() end
        if not searching.Revealed then self.view.Loot:SearchProgress(searching.Key,searching.Progress) end
    end
    if self.bagRevision~=self.equipment.data.Revision then self:RefreshBag();self:Details() end
    self.terms:Tick()
end
function Loot:OnHide()
    self.terms:Reset()
    self.view.Loot:CancelDrag()
    self.adventure:CloseLoot()
    local demo=self.demo;self.demo=nil
    if demo then demo:SetEquipmentOpen(false) end
end
return Loot
