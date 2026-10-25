local LuaLanguage = require('Language')
local Class=require('Core.Class')
local Panel=require('UI.UIPanelCtrl')
local Model=require('Game.Equipment.InventoryModel')
local Text=require('Game.Equipment.EquipmentPresentation')
local Inventory=Class('InventoryCtr',Panel)
function Inventory:Bind()
    self.system=self.context.systems:Get('Equipment');self.stats=self.context.systems:Get('Battle').stats
    self.terms=require('UI.EquipmentTermPresenter').New(self.view,self.system.config)
    self.model=Model.New(self.system,self.stats);self.view.Inventory:Prepare()
    self.appearance=require('Game.Adventure.PawnAppearance').New(self.system.config)
    self.health=require('UI.BodyHealthPresenter').New(self)
    local function onCommand(command)
        local ok,err=xpcall(function()
            local input=self.view.Inventory
            if command=='select' then self.selected=input.ActionKey;self:Refresh()
            elseif command=='cancel' then self.message=LuaLanguage.UIInventoryMessage;self:Refresh()
            else self:Command(command,input.ActionKey,input.ActionX,input.ActionY,input.ActionRotated) end
        end,debug.traceback)
        if not ok then self.context.log(err) end
    end
    self.view.Inventory.Command:AddListener(onCommand)
    self.lifetime:Add(function() self.view.Inventory.Command:RemoveListener(onCommand) end)
    self:Listen(self.view.Close,function() self:Close() end)
    self:Listen(self.view.Workbench,function()
        local demo=self.demo;self:Close();self.context.systems:Get('UI'):Open('EquipmentWorkbench',{demo=demo})
    end)
    for i=1,4 do local index=i
        self:Listen(self.view['Actor'..i],function()
            self.actorId=self.system.adventure:GetPartyAt(index-1).Id;self.selected='';self:Refresh()
        end)
    end
    for _,slot in ipairs(Model.slots) do local key=slot
        self:Listen(self.view['Slot_'..slot],function()
            if self.selected~='' then self:Command('equip:'..key,self.selected) end
        end)
    end
    self:Listen(self.view.Equip,function()
        local row=self:Selected();if not row then return end
        local slot=row.compatible
        if slot=='ring' then slot=self.system.data:Worn(self.actorId,'leftRing') and 'rightRing' or 'leftRing' end
        self:Command('equip:'..slot,row.key)
    end)
    self:Listen(self.view.Unequip,function() self:Command('unequip',self.selected) end)
    self:Listen(self.view.Repair,function() self:Command('repair',self.selected) end)
    self:Listen(self.view.Rotate,function()
        local row=self:Selected();if row then self:Command('move',row.key,row.x,row.y,not row.rotated) end
    end)
end
function Inventory:OnShow(args)
    self.demo=assert(args.demo);self.demo:SetEquipmentOpen(true)
    self.actorId=self.system.adventure:GetPartyAt(0).Id;self.selected=''
    self.message=LuaLanguage.UIInventoryMessage2
    self.view.Inventory:Prepare();self:Refresh();self.terms:Reset()
end
function Inventory:Selected()
    for _,row in ipairs(self.rows) do if row.key==self.selected then return row end end
end
function Inventory:Command(command,key,x,y,rotated)
    local ok,reason=self.model:Command(command,self.actorId,key,x or 0,y or 0,rotated==true)
    self.message=ok and (command=='repair' and reason or LuaLanguage.UIInventoryMessage3) or reason
    self.selected=key
    if ok then self.demo:SendCommand('snapshot') end
    self:Refresh()
end
function Inventory:Refresh()
    local data=self.system.data;self.rows=self.model:Rows(self.actorId);local selected=self:Selected()
    if not selected then self.selected='' end
    self.view.Inventory:Render({width=data.Grid.Width,height=data.Grid.Height,selected=self.selected,items=self.rows})
    for i=1,4 do
        local active=i<=self.system.adventure.PartyCount;self.view['Actor'..i].gameObject:SetActive(active)
        if active then
            local actor=self.system.adventure:GetPartyAt(i-1)
            self.view['ActorText'..i].text=(actor.Id==self.actorId and '◆ ' or '')..self.stats:Template(actor).name
        end
    end
    local actor=self.system:Actor(self.actorId);local lines={}
    if not self.health.open then self.view.Character:Show(self.appearance:Template(actor.TemplateId,self.system.rules:ActorVisual(actor),actor.CustomizationJson)) end
    self.health:Refresh()
    for _,attribute in ipairs(self.system.rules.attributes:All()) do lines[#lines+1]=attribute.name..'  '..self.stats:Get(actor,attribute.code) end
    self.view.ActorStats.text=string.format(LuaLanguage.UIInventoryActorStatsText,actor.HP,actor.MaxHP)..table.concat(lines,'    ')
    local occupied=0;for i=0,data.Grid.Count-1 do local p=data.Grid:GetAt(i);occupied=occupied+p.Width*p.Height end
    self.view.Capacity.text=string.format(LuaLanguage.UIInventoryCapacityText,data.Grid.Width,data.Grid.Height,occupied,data.Grid.Width*data.Grid.Height-occupied)
    self.view.ItemName.text=selected and selected.displayName or LuaLanguage.UIInventoryItemNameText
    self.view.DetailsRarityFrame:Configure(selected~=nil and selected.legendary,selected and selected.rarityColor or '',true)
    self.view.ItemDetail.text=selected and (selected.detail..'\n\n'..Text.Note(string.format(LuaLanguage.UIInventoryItemDetailText6,selected.width,selected.height,selected.count))..'\n'..
        Text.Note(selected.slot~='' and (string.format(LuaLanguage.UIInventoryItemDetailText5, (Model.slotNames[selected.slot]))) or selected.compatible~='' and LuaLanguage.UIInventoryItemDetailText4 or LuaLanguage.UIInventoryItemDetailText3)) or
        Text.Heading(LuaLanguage.UIInventoryItemDetailText2)..'\n\n'..Text.Note(LuaLanguage.UIInventoryItemDetailText)
    if self.detailsKey~=self.selected then self.view.ItemDetail.rectTransform.anchoredPosition=CS.UnityEngine.Vector2.zero;self.detailsKey=self.selected end
    self.view.Equip.interactable=selected~=nil and selected.compatible~='' and selected.slot==''
    self.view.Unequip.interactable=selected~=nil and selected.slot~=''
    self.view.Rotate.interactable=selected~=nil and selected.slot=='' and selected.width~=selected.height
    local quote=selected and self.system:RepairQuote(selected.key)
    self.view.Repair.interactable=quote~=nil and quote.materials>0
    self.view.RepairText.text=quote and quote.materials>0 and string.format(LuaLanguage.UIInventoryRepairTextText2,quote.materials,quote.coins) or LuaLanguage.UIInventoryRepairTextText
    local hasWeapon=false
    for i=0,data.WeaponCount-1 do if self.system:IsCarriedWeapon(data:GetWeaponAt(i)) then hasWeapon=true;break end end
    self.view.Workbench.interactable=hasWeapon
    self.view.Status.text=self.message;self.revision=data.Revision
end
function Inventory:Tick()
    require('UI.EquipmentRarity').Tick()
    local actor=assert(self.system:Actor(self.actorId))
    if self.revision~=self.system.data.Revision or self.health.revision~=CS.ProjectY.Data.BodyHealth.Revision(actor) or self.health.effectRevision~=actor.Effects.Revision then self:Refresh() end
    self.terms:Tick()
end
function Inventory:OnHide()
    self.terms:Reset()
    self.health:Hide()
    self.view.Inventory:CancelDrag()
    self.view.Character:ReleasePreview()
    if self.demo then self.demo:SetEquipmentOpen(false);self.demo=nil end
end
return Inventory
