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
    for _,item in ipairs(self.rules.items:All()) do self.data.Grid:Define(item.id,item.width,item.height) end
end
function Equipment:CanGrant(ids,counts)
    local kinds,items,amounts={},{},{}
    for i,id in ipairs(ids) do kinds[i]=self.rules.items:Get(id).kind;items[i]=id;amounts[i]=counts[i] end
    return self.data:CanGrant(items,amounts,kinds)
end
function Equipment:Grant(itemId,count)
    if not self:CanGrant({itemId},{count}) then return false,'背包空间不足，请先整理背包' end
    local item=self.rules.items:Get(itemId)
    if item.kind=='weapon' then for i=1,count do self.data:AddWeapon(itemId) end
    elseif item.kind=='magazine' then
        local row=self.rules.magazines:Get(itemId)
        for i=1,count do self.data:AddMagazine(itemId,row.ammoItemId,row.capacity,row.spawnRounds) end
    elseif item.kind=='wearable' then for i=1,count do self.data:AddWearable(itemId) end
    else self.data:AddStack(itemId,count) end
    return true
end
function Equipment:Start()
    self.data.Grid:Configure(self.recipe.bagWidth,self.recipe.bagHeight)
    assert(self:CanGrant(self.recipe.starterItemIds,self.recipe.starterCounts),'Starter items exceed backpack capacity')
    for i,id in ipairs(self.recipe.starterItemIds) do assert(self:Grant(id,self.recipe.starterCounts[i])) end
end
function Equipment:Actor(id)
    for i=0,self.adventure.PartyCount-1 do local actor=self.adventure:GetPartyAt(i);if actor.Id==id then return actor end end
end
function Equipment:HandAllowed(actorId,weapon,slot)
    local main=self.data:Equipped(actorId)
    if slot=='offhand' then
        if weapon and self.rules.weapons:Get(weapon.ItemId).hands~=1 then return false,'副手只接受单手武器或盾牌' end
        if main and main~=weapon and self.rules.weapons:Get(main.ItemId).hands==2 then return false,'请先卸下双手武器' end
    elseif weapon and self.rules.weapons:Get(weapon.ItemId).hands==2 then
        local off=self.data:Offhand(actorId)
        if (off and off~=weapon) or self.data:Worn(actorId,'offhand') then return false,'双手武器需要空副手，请先卸下副手装备' end
    end
    return true
end
function Equipment:Command(command,actorId,weaponId,socketId,value)
    if self.adventure.Phase~='map' and self.adventure.Phase~='area' then return false,'只能在探索期间整理装备' end
    local actor=self:Actor(actorId)
    if not actor then return false,'无效队员' end
    if command=='unequip' then return self.data:Equip(actorId,0),'背包空间不足，无法卸下武器' end
    if command=='unequip_offhand' then return self.data:EquipOffhand(actorId,0),'背包空间不足，无法卸下副手' end
    local weapon
    for i=0,self.data.WeaponCount-1 do local row=self.data:GetWeaponAt(i);if row.Id==weaponId then weapon=row;break end end
    if not weapon then return false,'请选择背包中的武器' end
    local definition=self.rules.weapons:Get(weapon.ItemId)
    if command=='equip' or command=='equip_offhand' then
        local allowed,reason=self:HandAllowed(actorId,weapon,command=='equip' and 'weapon' or 'offhand')
        if not allowed then return false,reason end
        return command=='equip' and self.data:Equip(actorId,weaponId) or command=='equip_offhand' and self.data:EquipOffhand(actorId,weaponId),'背包空间不足，无法放回原装备'
    end
    local socket
    for _,id in ipairs(definition.socketIds) do if id==socketId then socket=self.rules.sockets:Get(id) end end
    if command=='attach' then
        if not socket then return false,'请选择改装挂点' end
        if socket.kind=='magazine' then
            local mag
            for i=0,self.data.MagazineCount-1 do local row=self.data:GetMagazineAt(i);if row.Id==value then mag=row end end
            if value~=0 and (not mag or mag.ItemId~=definition.magazineItemId) then return false,'弹匣不兼容' end
            if value~=0 and self.data:MagazineWeapon(value)~=0 and self.data:MagazineWeapon(value)~=weaponId then return false,'弹匣已装在其他武器上' end
            if not self.data:AttachMagazine(weaponId,value) then return false,'背包空间不足，无法放回原弹匣' end
        else
            local rune=value~=0 and self.rules.runes:Find(value) or nil
            if value~=0 and (not rune or rune.slotKind~=socket.kind) then return false,'组件与挂点不兼容' end
            if value~=0 and self.data:CountItem(value)<1 and weapon:GetRune(socketId)~=value then return false,'背包中没有这个组件' end
            if not self.data:SetRune(weaponId,socketId,value) then return false,'背包空间不足，无法放回原组件' end
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
    if not self:CanGrant(row.itemIds,row.counts) then return false,'背包空间不足；掉落物保留，请整理后再搜刮' end
    for i,itemId in ipairs(row.itemIds) do assert(self:Grant(itemId,row.counts[i])) end
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
