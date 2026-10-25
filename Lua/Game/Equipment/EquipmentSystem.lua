local Class=require('Core.Class')
local System=require('Core.LuaSystem')
local Equipment=Class('EquipmentSystem',System)
function Equipment:OnInit(context)
    System.OnInit(self,context)
    self.adventure=context.services.Adventure;self.data=self.adventure.Equipment
    self.config=context.systems:Get('Config');self.rules=require('Game.Equipment.EquipmentRules').New(self.config,self.data)
    self.synergies=require('Game.Equipment.SkillSynergies').New(self.config)
    self.rules.affixes:Define(self.data)
    self.rules.ammunition:Define(self.data)
    self.initialLoadouts=require('Game.Equipment.InitialLoadout').New(self.config,self.rules)
    self.acquisition=require('Game.Equipment.LegendaryAcquisition').New(self.config,self)
    self.recipe=self.config:GetTable('EquipmentDemoTable'):Get(1)
    -- The start menu can load a save before Start grants a new campaign's items.
    self.data.Grid:Configure(self.recipe.bagWidth,self.recipe.bagHeight)
    self.loot=self.config:GetTable('EquipmentLootTable')
    self.worldLoot=require('Game.Loot.MapLoot').New(self.config,self)
    for _,item in ipairs(self.rules.items:All()) do self.data.Grid:Define(item.id,item.width,item.height) end
end
function Equipment:CanGrant(ids,counts)
    local allowed,reason=self.acquisition:CanGrant(ids,counts)
    if not allowed then return false,reason end
    local kinds,items,amounts={},{},{}
    for i,id in ipairs(ids) do kinds[i]=self.rules.items:Get(id).kind;items[i]=id;amounts[i]=counts[i] end
    return self.data:CanGrant(items,amounts,kinds)
end
function Equipment:Grant(itemId,count)
    local allowed,reason=self.acquisition:CanGrant({itemId},{count})
    if not allowed then return false,reason end
    if not self:CanGrant({itemId},{count}) then return false,'背包空间不足，请先整理背包' end
    local item=self.rules.items:Get(itemId)
    if item.kind=='weapon' then for i=1,count do self.data:AddWeapon(itemId) end
    elseif item.kind=='magazine' then
        local row=self.rules.magazines:Get(itemId)
        for i=1,count do self.data:AddMagazine(itemId,row.ammoItemId,row.capacity,row.spawnRounds) end
    elseif item.kind=='wearable' then for i=1,count do self.data:AddWearable(itemId) end
    else self.data:AddStack(itemId,count) end
    self.acquisition:Record({itemId})
    return true
end
function Equipment:Start(recipeId)
    self.recipe=self.config:GetTable('EquipmentDemoTable'):Get(recipeId or 1)
    self.data.Grid:Configure(self.recipe.bagWidth,self.recipe.bagHeight)
    assert(self:CanGrant(self.recipe.starterItemIds,self.recipe.starterCounts),'Starter items exceed backpack capacity')
    for i,id in ipairs(self.recipe.starterItemIds) do assert(self:Grant(id,self.recipe.starterCounts[i])) end
end
function Equipment:StartPartyLoadouts()
    local starters=require('Game.Equipment.StarterWeapons')
    local plan=starters.Plan(self.recipe,self.data,self.adventure,self.rules,self.context.systems:Get('Battle').stats,self.initialLoadouts)
    local ids,counts={},{}
    for i=0,self.adventure.PartyCount-1 do
        local actor=self.adventure:GetPartyAt(i)
        local items=self.initialLoadouts:Items(actor.TemplateId)
        for _,id in ipairs(items) do ids[#ids+1]=id;counts[#counts+1]=1 end
    end
    assert(self:CanGrant(ids,counts),'Initial character equipment exceeds backpack capacity')
    for i=0,self.adventure.PartyCount-1 do self.initialLoadouts:Apply(self.data,self.adventure:GetPartyAt(i)) end
    starters.Apply(self.data,plan)
    for i=0,self.adventure.PartyCount-1 do
        local actor=self.adventure:GetPartyAt(i)
        local main,off=self.rules:Weapon(actor),self.rules:Offhand(actor)
        if main then self.synergies:Discover(self.adventure,main) end
        if off then self.synergies:Discover(self.adventure,off) end
    end
end
function Equipment:Actor(id)
    for i=0,self.adventure.PartyCount-1 do local actor=self.adventure:GetPartyAt(i);if actor.Id==id then return actor end end
end
function Equipment:IsCarriedWeapon(weapon)
    return weapon.OwnerActorId==0 and self.data.Grid:Find('w'..weapon.Id)~=nil or self:Actor(weapon.OwnerActorId)~=nil
end
function Equipment:IsCarriedMagazine(magazine)
    local owner=self.data:MagazineWeapon(magazine.Id)
    return owner==0 and self.data.Grid:Find('m'..magazine.Id)~=nil or owner~=0 and self:IsCarriedWeapon(self.data:GetWeapon(owner))
end
function Equipment:InitializeEnemy(actor)
    for _,id in ipairs(self.rules.units:Get(actor.TemplateId).traitIds) do actor:AddTrait(id) end
    self.initialLoadouts:ApplyEnemy(self.data,actor,self.acquisition)
end
function Equipment:TreatDisease(actorId,diseaseId)
    local Language=require('Language')
    if self.adventure.Phase~='map' and self.adventure.Phase~='area' then return false,Language.BodyExplorationOnly end
    local actor=self:Actor(actorId);if not actor then return false,Language.BodyInvalidTreatment end
    local battle=self.context.systems:Get('Battle')
    return battle.stats.diseases:Treat(actor,diseaseId,self.data,battle.gameEffects)
end
function Equipment:TreatInjury(actorId,partIndex,treatmentId)
    local Language=require('Language')
    if self.adventure.Phase~='map' and self.adventure.Phase~='area' then return false,Language.BodyExplorationOnly end
    local actor=self:Actor(actorId);if not actor then return false,Language.BodyInvalidTreatment end
    local injuries=self.context.systems:Get('Battle').stats.injuries
    local allowed,treatment=injuries:Treatment(actor,partIndex,treatmentId,self.data)
    if not allowed then return false,treatment end
    assert(CS.ProjectY.Data.BodyHealth.Treat(actor,self.data,partIndex,treatment.itemId,treatment.count,treatment.recovery),'Treatment changed after validation')
    return true,Language.BodyTreated
end
function Equipment:RepairQuote(key)
    if type(key)~='string' or not key:match('^[wg]%d+$') then return nil end
    local id=tonumber(key:sub(2));local item=key:sub(1,1)=='w' and self.data:GetWeapon(id) or self.data:GetWearable(id)
    local condition=self.rules:Condition(item)
    local service=CS.ProjectY.Data.EquipmentCombatState
    return {condition=condition,materials=service.RepairMaterials(condition),coins=service.RepairCoins(condition),item=item}
end
function Equipment:Repair(actorId,key)
    if self.adventure.Phase~='map' and self.adventure.Phase~='area' then return false,'只能在探索期间维修装备' end
    if not self:Actor(actorId) then return false,'无效队员' end
    local quote=self:RepairQuote(key)
    if not quote or (not self.data.Grid:Find(key) and not self:Actor(quote.item.OwnerActorId)) then return false,'只能维修共享背包或队员身上的装备' end
    if quote.materials==0 then return false,'装备耐久已满' end
    local player=self.context.services.Player
    if self.data:CountItem(83)<quote.materials or player.Coins<quote.coins then return false,string.format('维修需要铁件 %d 与金币 %d',quote.materials,quote.coins) end
    assert(CS.ProjectY.Data.EquipmentCombatState.Repair(self.data,player,key,83),'Repair budget changed after validation')
    local owner=self:Actor(quote.item.OwnerActorId)
    if owner then self:RefreshEquipmentHP(owner,self.context.systems:Get('Battle').stats) end
    return true,string.format('维修完成：耐久 %d / %d，永久损伤保留',quote.condition.Current,quote.condition.Maximum)
end
function Equipment:RefreshEquipmentHP(actor,stats)
    CS.ProjectY.Data.EquipmentCombatState.RefreshMaximum(actor,stats:MaximumHP(actor))
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
function Equipment:Command(command,actorId,weaponId,socketId,value,ammoItemId)
    if self.adventure.Phase~='map' and self.adventure.Phase~='area' then return false,'只能在探索期间整理装备' end
    local actor=self:Actor(actorId)
    if not actor then return false,'无效队员' end
    if command=='unequip' or command=='unequip_offhand' then
        local ok
        if command=='unequip' then ok=self.data:Equip(actorId,0) else ok=self.data:EquipOffhand(actorId,0) end
        if ok then actor:SetMaxHP(self.context.systems:Get('Battle').stats:MaximumHP(actor)) end
        return ok,'背包空间不足，无法卸下装备'
    end
    local weapon
    for i=0,self.data.WeaponCount-1 do local row=self.data:GetWeaponAt(i);if row.Id==weaponId then weapon=row;break end end
    if not weapon or not self:IsCarriedWeapon(weapon) then return false,'请选择共享背包或队员身上的武器' end
    local definition=self.rules.weapons:Get(weapon.ItemId)
    if command=='equip' or command=='equip_offhand' then
        local allowed,reason=self:HandAllowed(actorId,weapon,command=='equip' and 'weapon' or 'offhand')
        if not allowed then return false,reason end
        allowed,reason=self.rules:CanEquip(actor,weapon.ItemId,self.context.systems:Get('Battle').stats)
        if not allowed then return false,reason end
        local previous=self:Actor(weapon.OwnerActorId);local ok
        if command=='equip' then ok=self.data:Equip(actorId,weaponId) else ok=self.data:EquipOffhand(actorId,weaponId) end
        if ok then
            local stats=self.context.systems:Get('Battle').stats;actor:SetMaxHP(stats:MaximumHP(actor))
            if previous and previous~=actor then previous:SetMaxHP(stats:MaximumHP(previous)) end
            self.synergies:Discover(self.adventure,weapon)
            self.context.systems:Get('Adventure').professionExploration:OnEquip(actor,weapon)
        end
        return ok,'背包空间不足，无法放回原装备'
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
            if value~=0 then self.synergies:Discover(self.adventure,weapon) end
        end
        return true
    elseif command=='fill' then
        local Language=require('Language')
        local mag
        for i=0,self.data.MagazineCount-1 do local row=self.data:GetMagazineAt(i);if row.Id==value then mag=row end end
        if not mag or not self:IsCarriedMagazine(mag) then return false,Language.AmmoSelectMagazine end
        ammoItemId=ammoItemId or mag.AmmoItemId
        if not self.rules.ammunition:Compatible(mag.ItemId,ammoItemId) then return false,Language.AmmoIncompatible end
        local reason=CS.ProjectY.Data.EquipmentAmmunition.Refill(self.data,value,ammoItemId)
        if reason~='' then return false,assert(Language[reason],'Unknown ammunition failure key: '..reason) end
        return true
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
