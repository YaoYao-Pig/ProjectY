local Class=require('Core.Class')
local System=require('Core.LuaSystem')
local Equipment=Class('EquipmentSystem',System)
function Equipment:OnInit(context)
    System.OnInit(self,context)
    self.adventure=context.services.Adventure;self.data=self.adventure.Equipment
    self.config=context.systems:Get('Config');self.rules=require('Game.Equipment.EquipmentRules').New(self.config,self.data)
    self.initialLoadouts=require('Game.Equipment.InitialLoadout').New(self.config)
    self.recipe=self.config:GetTable('EquipmentDemoTable'):Get(1)
    self.loot=self.config:GetTable('EquipmentLootTable')
    self.worldLoot=require('Game.Loot.MapLoot').New(self.config,self)
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
function Equipment:StartPartyLoadouts()
    local ids,counts={},{}
    for i=0,self.adventure.PartyCount-1 do
        local items=self.initialLoadouts:Items(self.adventure:GetPartyAt(i).TemplateId)
        for _,id in ipairs(items) do ids[#ids+1]=id;counts[#counts+1]=1 end
    end
    assert(self:CanGrant(ids,counts),'Initial character equipment exceeds backpack capacity')
    for i=0,self.adventure.PartyCount-1 do self.initialLoadouts:Apply(self.data,self.adventure:GetPartyAt(i)) end
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
function Equipment:InitializeLoot(areas) return self.worldLoot:Initialize(areas) end
function Equipment:Loot(areas,id) return self.worldLoot:Collect(areas,id) end
function Equipment:LootSnapshot(areas) return self.worldLoot:Snapshot(areas) end
function Equipment:GenerateEnemyDrops(areas,battle) return self.worldLoot:EnemyDrops(areas,battle) end
function Equipment:GenerateActorDrops(areas,actors,stats) return self.worldLoot:ActorDrops(areas,actors,stats) end
function Equipment:LootContents(container) return self.worldLoot:Contents(container) end
return Equipment
