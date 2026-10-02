local Class=require('Core.Class')
local Panel=require('UI.UIPanelCtrl')
local BagModel=require('Game.Equipment.InventoryModel')
local LootModel=require('Game.Loot.LootModel')
local Loot=Class('LootCtr',Panel)
function Loot:Bind()
    self.adventure=self.context.systems:Get('Adventure');self.equipment=self.adventure.equipment
    self.worldLoot=self.equipment.worldLoot;self.session=self.worldLoot.session
    self.bagModel=BagModel.New(self.equipment,self.adventure.battle.stats);self.lootModel=LootModel.New(self.worldLoot)
    local function command(action)
        local ok,err=xpcall(function() self:Command(action) end,debug.traceback)
        if not ok then self.context.log(err) end
    end
    self.view.Inventory.Command:AddListener(command)
    self.lifetime:Add(function() self.view.Inventory.Command:RemoveListener(command) end)
    self:Listen(self.view.Close,function() self:Close() end)
end
function Loot:OnShow(args)
    assert(self.session.Active,'Loot UI requires an active container session')
    self.demo=assert(args.demo);self.demo:SetEquipmentOpen(true)
    self.selected='';self.message='搜索自动进行，已揭示的物品可立即拖入左侧。'
    self.actorId=self.adventure.data:GetPartyAt(0).Id
    self.view.Loot:Prepare();self.view.Title.text=self.session.Title;self.view.Summary.text=self.session.Summary
    self:RefreshBag();self:RefreshLoot();self:Details()
end
function Loot:RefreshBag()
    local rows={}
    for _,row in ipairs(self.bagModel:Rows(self.actorId)) do if row.slot=='' then rows[#rows+1]=row end end
    self.bagRows=rows;local data=self.equipment.data
    self.view.Inventory:Render({width=data.Grid.Width,height=data.Grid.Height,selected=self.selected,items=rows})
    local used=0;for i=0,data.Grid.Count-1 do local place=data.Grid:GetAt(i);used=used+place.Width*place.Height end
    self.view.Capacity.text=string.format('%d × %d  ·  已用 %d 格 / 剩余 %d 格',data.Grid.Width,data.Grid.Height,used,data.Grid.Width*data.Grid.Height-used)
    self.bagRevision=data.Revision
end
function Loot:RefreshLoot()
    local rows,width,height=self.lootModel:Rows();self.lootRows=rows
    self.view.Loot:Render({width=width,height=height,selected=self.selected,items=rows})
    local remaining,unknown=0,0
    for _,row in ipairs(rows) do if row.count>0 then remaining=remaining+1;if not row.revealed then unknown=unknown+1 end end end
    self.view.SearchStatus.text=unknown>0 and string.format('剩余 %d 件  ·  %d 件等待揭示  ·  滚轮浏览',remaining,unknown) or string.format('搜索完成  ·  剩余 %d 件  ·  拖入左侧领取',remaining)
    self.view.Empty.text=remaining==0 and (self.session.Count==0 and '这里没有可搜刮的物品' or '战利品已取完\n可以继续探索') or ''
    self.lootRevision=self.session.Revision
end
function Loot:Details()
    local selected
    for _,rows in ipairs({self.bagRows,self.lootRows}) do
        for _,row in ipairs(rows) do if row.key==self.selected and row.count>0 then selected=row end end
    end
    self.view.ItemName.text=selected and selected.name or '选择物品查看详情'
    self.view.ItemDetail.text=selected and (selected.revealed==false and selected.detail or string.format('%d × %d 格  ·  数量 %d  ·  %s',selected.width,selected.height,selected.count,selected.detail)) or '先整理左侧空间，再把需要的战利品拖入背包。'
    self.view.Status.text=self.message
end
function Loot:Command(action)
    local input=self.view.Inventory;local key=input.ActionKey
    if action=='select' then self.selected=key;self:RefreshLoot();self:Details();return end
    if action=='cancel' then self.message='已取消移动，物品保留原位';self:Details();return end
    assert(action=='move','Unexpected loot action: '..tostring(action))
    local entry=self.session:Find(key);local ok,reason
    if entry then
        ok,reason=self.adventure:TakeLoot(key,input.ActionX,input.ActionY,input.ActionRotated)
        if ok then reason='已收入背包：'..reason end
    else
        ok,reason=self.bagModel:Command('move',self.actorId,key,input.ActionX,input.ActionY,input.ActionRotated)
        if ok then reason='已整理背包' end
    end
    self.message=reason;self.selected=key
    self:RefreshBag();self:RefreshLoot();self:Details()
    if ok then self.demo:SendCommand('snapshot') end
end
function Loot:Tick(_,unscaledDt)
    if not self.session.Active then self:Close();return end
    local searching=self.lootModel:Searching()
    if searching then
        self.session:Advance(searching.Key,unscaledDt,1.1)
        if self.lootRevision~=self.session.Revision then self:RefreshLoot();self:Details() end
        if not searching.Revealed then self.view.Loot:SearchProgress(searching.Key,searching.Progress) end
    end
    if self.bagRevision~=self.equipment.data.Revision then self:RefreshBag();self:Details() end
end
function Loot:OnHide()
    self.view.Loot:CancelDrag()
    self.adventure:CloseLoot()
    local demo=self.demo;self.demo=nil
    if demo then demo:SetEquipmentOpen(false) end
end
return Loot
