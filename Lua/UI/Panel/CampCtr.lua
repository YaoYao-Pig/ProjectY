local LuaLanguage=require('Language')
local Class=require('Core.Class')
local Base=require('UI.UIPanelCtrl')
local Presentation=require('Game.Camp.CampPresentation')
local BagModel=require('Game.Equipment.InventoryModel')
local Camp=Class('CampCtr',Base)
function Camp:Bind()
    self.adventure=self.context.systems:Get('Adventure');self.model=self.adventure.camp
    self.bag=BagModel.New(self.adventure.equipment,self.adventure.battle.stats)
    self.view.Camp:Prepare()
    local roster=function() self:Action('roster') end
    self.view.Roster.onClick:AddListener(roster);self.lifetime:Add(function() self.view.Roster.onClick:RemoveListener(roster) end)
    local loadout=function() self:Action('loadout') end
    self.view.Loadout.onClick:AddListener(loadout);self.lifetime:Add(function() self.view.Loadout.onClick:RemoveListener(loadout) end)
    local action=function(command) self:Action(command) end
    self.view.Camp.Command:AddListener(action);self.lifetime:Add(function() self.view.Camp.Command:RemoveListener(action) end)
    local inventory=function(command) self:InventoryAction(command) end
    self.view.Inventory.Command:AddListener(inventory);self.lifetime:Add(function() self.view.Inventory.Command:RemoveListener(inventory) end)
end
function Camp:OnShow(args)
    self.demo=assert(args.demo);self.demo:SetStoryOpen(true)
    self.state={page='scene',facility=1,selected='',message=LuaLanguage.CampSceneHint};self.storageSelected=''
    CS.ProjectY.Data.CampWarehouseBridge.Prepare(self.model.data,self.adventure.equipment.data)
    self.view.Camp:Prepare();self.view.Scene:Begin(self.demo.WorldCamera,Presentation.Party(self.adventure));self:Refresh()
end
function Camp:Action(command)
    local state=self.state
    if command=='close' or command=='back' and state.page=='scene' then self.demo:SendCommand('camp_close',0,0);return end
    if command=='back' then state.page='scene';state.message=LuaLanguage.CampSceneHint
    elseif command=='roster' then state.page='roster';state.selected='';state.swapActiveId=nil;state.message=LuaLanguage.RosterHint
    elseif command=='secondary' and state.page=='roster' then
        state.swapActiveId=not state.swapActiveId and assert(tonumber(state.selected)) or nil;state.selected=''
    elseif command=='loadout' then state.page='loadout';state.selected='';state.loadoutSlot=1;state.message=LuaLanguage.CampLoadoutHint
    elseif command=='secondary' and state.page=='loadout' then state.loadoutSlot=self.view.Camp.ActionId;state.selected=''
    elseif command=='facility' then
        local id=self.view.Camp.ActionId;state.facility=id==4 and 1 or id;state.selected=''
        state.page=id==3 and 'storage' or id==4 and 'forge' or 'production';state.message=id==3 and LuaLanguage.CampWarehouseHint or LuaLanguage.CampMaterialsPriority
        if id~=3 and self.model.data:GetLevel(state.facility)==0 then state.page='upgrade' end
    elseif command=='upgrade' then state.page='upgrade';state.selected='';state.message=LuaLanguage.CampUpgradeHint
    elseif command=='select' then
        if state.page=='upgrade' then state.facility=assert(tonumber(self.view.Camp.ActionKey)) else state.selected=self.view.Camp.ActionKey end
    elseif command=='wait' then self.demo:SendCommand('camp_wait',self.view.Camp.ActionId,self.revision);self.view.Scene:RefreshBackground()
    elseif command=='claim' then self.demo:SendCommand('camp_claim',state.facility,self.revision)
    elseif command=='primary' or command=='secondary' then
        local op=command=='primary' and self.snapshot.operation or self.snapshot.secondary[self.view.Camp.ActionId]
        assert(op,'Camp action has no operation');self.demo:SendCommand(op.command,op.id,self.revision,op.count)
        if not self.model.data.IsOpen then return end
        if state.page=='roster' and self.demo.LastError=='' then
            state.swapActiveId=nil;state.message=LuaLanguage.RosterUpdated
            self.view.Scene:Begin(self.demo.WorldCamera,Presentation.Party(self.adventure))
        end
    else error('Unknown camp action: '..tostring(command)) end
    if self.demo.LastError~='' then state.message=self.demo.LastError end
    self:Refresh()
end
function Camp:Refresh()
    local s=Presentation.Build(self.model,self.state);local prior=self.renderedPage
    self.snapshot=s;self.view.Camp:Render(s);self.renderedPage=self.state.page
    self.view.Header.gameObject:SetActive(s.page=='scene')
    local data=self.model.data
    self.view.Scene:SetLevels(data:GetLevel(1),data:GetLevel(2),data:GetLevel(3))
    if s.page=='storage' then
        if prior~='storage' then self.view.Warehouse:Prepare() end
        self:RefreshStorage()
    elseif s.previewPawn then self.view.ItemPreview:ShowPawn(s.previewPawn)
    elseif s.previewWeapon then self.view.ItemPreview:ShowWeapon(s.previewWeapon)
    elseif s.previewAsset then self.view.ItemPreview:ShowAsset(s.previewAsset)
    elseif s.previewFacility then self.view.ItemPreview:ShowFacility(s.previewFacility,s.previewLevel)
    else self.view.ItemPreview:Release() end
    self.revision=data.Revision;self.equipmentRevision=self.adventure.equipment.data.Revision
    self.coins=self.adventure.player.Coins;self.minutes=math.floor(self.adventure.narrative.data.Minutes)
end
function Camp:RefreshStorage()
    local a=self.adventure;local equipment=a.equipment.data;self.actorId=a.data:GetPartyAt(0).Id
    local bagRows={};for _,row in ipairs(self.bag:Rows(self.actorId)) do if row.slot=='' then bagRows[#bagRows+1]=row end end
    self.bagRows=bagRows;self.warehouseSnapshot=Presentation.Warehouse(self.model,self.storageSelected)
    self.view.Inventory:Render({width=equipment.Grid.Width,height=equipment.Grid.Height,items=bagRows,selected=self.storageSelected})
    self.view.Warehouse:Render(self.warehouseSnapshot)
    local selected;for _,rows in ipairs({bagRows,self.warehouseSnapshot.items}) do for _,row in ipairs(rows) do if row.key==self.storageSelected then selected=row end end end
    local used=0;for i=0,equipment.Grid.Count-1 do local p=equipment.Grid:GetAt(i);used=used+p.Width*p.Height end
    self.view.Camp:StorageDetails(selected and selected.displayName or LuaLanguage.CampWarehouseChoose,
        selected and Presentation.StorageDetail(self.model,selected) or LuaLanguage.CampWarehouseAllowed,
        string.format(LuaLanguage.CampBagCapacity,used,equipment.Grid.Width*equipment.Grid.Height),
        string.format(LuaLanguage.CampWarehouseStatus,self.model.data.StoredTotal,self.model.rules:Capacity(self.model.data)),self.state.message)
end
function Camp:InventoryAction(command)
    local input=self.view.Inventory;local key=input.ActionKey
    if command=='select' then self.storageSelected=key;self:RefreshStorage();return end
    if command=='cancel' then self.state.message=LuaLanguage.CampWarehouseInvalidDrop;self:RefreshStorage();return end
    assert(command=='move' or command=='move_source','Unexpected camp inventory action')
    local ok,reason=self.model:Session(self.revision)
    if not ok then self.state.message=reason;self:Refresh();return end
    local bridge=CS.ProjectY.Data.CampWarehouseBridge;local data=self.model.data;local equipment=self.adventure.equipment.data
    local stored=bridge.Find(data,key);local x,y,rotated=input.ActionX,input.ActionY,input.ActionRotated
    if command=='move_source' then
        if stored then reason=bridge.Move(data,key,x,y,rotated,self.revision)
        else
            local row;for _,r in ipairs(self.bagRows) do if r.key==key then row=r;break end end
            assert(row,'Selected bag pile is missing')
            reason=bridge.Deposit(data,key,x,y,rotated,self.model.rules:Capacity(data),self.revision,self.equipmentRevision,row.kind,equipment)
        end
    elseif stored then reason=bridge.Withdraw(data,key,x,y,rotated,self.revision,self.equipmentRevision,self.model.rules.items:Get(stored.ItemId).kind,equipment)
    else
        if equipment.Revision~=self.equipmentRevision then reason='UICampText5'
        else
            ok,reason=self.bag:Command('move',self.actorId,key,x,y,rotated)
            self.state.message=ok and LuaLanguage.CampWarehouseMoved or reason;self:Refresh();return
        end
    end
    self.state.message=reason=='' and LuaLanguage.CampWarehouseMoved or assert(LuaLanguage[reason],'Unknown camp transfer failure: '..reason)
    self.storageSelected='';self.demo:SendCommand('snapshot');self:Refresh()
end
function Camp:Tick()
    if not self.model.data.IsOpen then return end
    local a=self.adventure
    if self.revision~=self.model.data.Revision or self.equipmentRevision~=a.equipment.data.Revision or self.coins~=a.player.Coins or self.minutes~=math.floor(a.narrative.data.Minutes) then self:Refresh() end
end
function Camp:OnHide()
    self.view.Warehouse:CancelDrag();self.view.Scene:Release();self.view.ItemPreview:Release()
    if self.model.data.IsOpen then self.model:Close() end
    if self.demo then self.demo:SetStoryOpen(false);self.demo=nil end
    self.renderedPage=nil
end
return Camp
