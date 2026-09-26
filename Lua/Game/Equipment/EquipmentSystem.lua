local Class=require('Core.Class')
local System=require('Core.LuaSystem')
local Hex=require('Game.Map.HexGrid')
local Equipment=Class('EquipmentSystem',System)
function Equipment:OnInit(context)
    System.OnInit(self,context)
    self.adventure=context.services.Adventure;self.data=self.adventure.Equipment
    self.config=context.systems:Get('Config');self.rules=require('Game.Equipment.EquipmentRules').New(self.config,self.data)
    self.recipe=self.config:GetTable('EquipmentDemoTable'):Get(1)
    self.loot=self.config:GetTable('EquipmentLootTable')
end
function Equipment:Grant(itemId,count)
    local item=self.rules.items:Get(itemId)
    if item.kind=='weapon' then for i=1,count do self.data:AddWeapon(itemId) end
    elseif item.kind=='magazine' then
        local row=self.rules.magazines:Get(itemId)
        for i=1,count do self.data:AddMagazine(itemId,row.ammoItemId,row.capacity,row.spawnRounds) end
    else self.data:AddStack(itemId,count) end
end
function Equipment:Start()
    for i,id in ipairs(self.recipe.starterItemIds) do self:Grant(id,self.recipe.starterCounts[i]) end
end
function Equipment:Actor(id)
    for i=0,self.adventure.PartyCount-1 do local actor=self.adventure:GetPartyAt(i);if actor.Id==id then return actor end end
end
function Equipment:Command(command,actorId,weaponId,socketId,value)
    if self.adventure.Phase~='map' and self.adventure.Phase~='area' then return false,'只能在探索期间整理装备' end
    local actor=self:Actor(actorId)
    if not actor then return false,'无效队员' end
    if command=='unequip' then self.data:Equip(actorId,0);return true end
    local weapon
    for i=0,self.data.WeaponCount-1 do local row=self.data:GetWeaponAt(i);if row.Id==weaponId then weapon=row;break end end
    if not weapon then return false,'请选择背包中的武器' end
    local definition=self.rules.weapons:Get(weapon.ItemId)
    if command=='equip' then self.data:Equip(actorId,weaponId);return true end
    local socket
    for _,id in ipairs(definition.socketIds) do if id==socketId then socket=self.rules.sockets:Get(id) end end
    if command=='attach' then
        if not socket then return false,'请选择改装挂点' end
        if socket.kind=='magazine' then
            local mag
            for i=0,self.data.MagazineCount-1 do local row=self.data:GetMagazineAt(i);if row.Id==value then mag=row end end
            if value~=0 and (not mag or mag.ItemId~=definition.magazineItemId) then return false,'弹匣不兼容' end
            if value~=0 and self.data:MagazineWeapon(value)~=0 and self.data:MagazineWeapon(value)~=weaponId then return false,'弹匣已装在其他武器上' end
            self.data:AttachMagazine(weaponId,value)
        else
            local rune=value~=0 and self.rules.runes:Find(value) or nil
            if value~=0 and (not rune or rune.slotKind~=socket.kind) then return false,'组件与挂点不兼容' end
            if value~=0 and self.data:CountItem(value)<1 and weapon:GetRune(socketId)~=value then return false,'背包中没有这个组件' end
            self.data:SetRune(weaponId,socketId,value)
        end
        return true
    elseif command=='fill' then
        local mag
        for i=0,self.data.MagazineCount-1 do local row=self.data:GetMagazineAt(i);if row.Id==value then mag=row end end
        if not mag then return false,'请选择弹匣' end
        if mag.Rounds==mag.Capacity then return false,'弹匣已满' end
        if self.data:CountItem(mag.AmmoItemId)==0 then return false,'没有可装填的散装弹药' end
        self.data:FillMagazine(value);return true
    end
    error('Unknown equipment command: '..tostring(command))
end
function Equipment:InitializeLoot(areas)
    local area,state=areas:ActiveLayout(),areas.data.Active
    if state.LootInitialized then return end
    if area.configId==self.recipe.areaId then
        local queue,dist,head={area.entryIndex},{[area.entryIndex]=0},1
        while head<=#queue do local index=queue[head];head=head+1
            for _,cell in ipairs(area:Neighbors(area.cells[index])) do
                if not dist[cell.index] then dist[cell.index]=dist[index]+1;queue[#queue+1]=cell.index end
            end
        end
        local used=areas:EnemyOccupancy(area,state)
        for i=0,state.MemberCount-1 do used[state:GetMemberCellAt(i)]=true end
        for i,id in ipairs(self.recipe.lootTableIds) do
            local selected,score
            for _,index in ipairs(queue) do if not used[index] and not state:IsNpcOccupied(index) then
                local delta=math.abs(dist[index]-self.recipe.lootDistances[i])
                if not score or delta<score then selected,score=index,delta end
            end end
            assert(selected,'No reachable loot cell');used[selected]=true;state:AddLoot(selected,id)
        end
    end
    state:CompleteLootInitialization()
end
function Equipment:Loot(areas,id)
    if self.adventure.Phase~='area' then return false,'只能在探索时搜刮' end
    local state,area=areas.data.Active,areas:ActiveLayout()
    local loot
    for i=0,state.LootCount-1 do local row=state:GetLootAt(i);if row.Id==id then loot=row end end
    if not loot or loot.Looted then return false,'这里已经搜刮过了' end
    local cell=area.cells[loot.CellIndex];local near=false
    for i=0,state.MemberCount-1 do
        local member=area.cells[state:GetMemberCellAt(i)]
        if Hex.Distance(cell.q,cell.r,member.q,member.r)<=self.recipe.interactionRadius and area:CanSee(member,cell) then near=true end
    end
    if not near then return false,'先靠近宝箱或掉落物（相邻一格）' end
    local row=self.loot:Get(loot.TableId)
    for i,itemId in ipairs(row.itemIds) do self:Grant(itemId,row.counts[i]) end
    state:Loot(id);return true,'已搜刮：'..row.name
end
function Equipment:LootSnapshot(areas)
    local state=areas.data.Active;local visible={};local result={}
    for i=0,state.VisibleCount-1 do visible[state:GetVisibleAt(i)]=true end
    for i=0,state.LootCount-1 do local loot=state:GetLootAt(i);local row=self.loot:Get(loot.TableId)
        if visible[loot.CellIndex] and (not loot.Looted or row.kind=='chest') then
            result[#result+1]={id=loot.Id,cellIndex=loot.CellIndex,name=row.name,looted=loot.Looted,
                asset=self.rules:Asset(loot.Looted and row.openedAssetId or row.assetId)}
        end
    end
    return result
end
return Equipment
