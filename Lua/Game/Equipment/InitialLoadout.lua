-- Stateless initial grants: caller preflights the combined batch before any mutation.
local Loadout={};Loadout.__index=Loadout
function Loadout.New(config,rules,getStats)
    local self=setmetatable({byUnit={},weapons=config:GetTable('EquipmentWeaponTable'),wearables=config:GetTable('EquipmentWearableTable'),
        rules=assert(rules),getStats=assert(getStats)},Loadout)
    for _,row in ipairs(config:GetTable('CharacterLoadoutTable'):All()) do
        assert(not self.byUnit[row.unitId],'Duplicate initial loadout for unit '..row.unitId)
        self.byUnit[row.unitId]=row
        local slots={}
        for _,id in ipairs(row.wearableIds) do local slot=self.wearables:Get(id).slot;assert(not slots[slot],'Duplicate initial wearable slot');slots[slot]=true end
        local main=row.weaponId~=0 and self.weapons:Get(row.weaponId)
        local off=row.offhandWeaponId~=0 and self.weapons:Get(row.offhandWeaponId)
        assert(not off or off.hands==1,'Initial offhand must be one-handed')
        assert(not off or not slots.offhand,'Initial offhand conflicts with shield')
        assert(not main or main.hands~=2 or not off and not slots.offhand,'Initial two-handed weapon conflicts with offhand')
    end
    return self
end
function Loadout:Items(unitId)
    local ids,counts={},{};local row=self.byUnit[unitId]
    if row then
        if row.weaponId~=0 then ids[#ids+1]=row.weaponId end
        if row.offhandWeaponId~=0 then ids[#ids+1]=row.offhandWeaponId end
        for _,id in ipairs(row.wearableIds) do ids[#ids+1]=id end
    end
    for i=1,#ids do counts[i]=1 end
    return ids,counts
end
function Loadout:Validate(actor)
    local ids=self:Items(actor.TemplateId)
    for _,id in ipairs(ids) do
        local allowed,reason=self.rules:CanEquip(actor,id,self.getStats())
        if not allowed then return false,'初始装备不满足条件：'..reason end
    end
    return true
end
function Loadout:Apply(data,actor)
    local row=self.byUnit[actor.TemplateId];if not row then return end
    assert(self:Validate(actor))
    if row.weaponId~=0 then local weapon=data:AddWeapon(row.weaponId);assert(data:Equip(actor.Id,weapon.Id)) end
    if row.offhandWeaponId~=0 then local weapon=data:AddWeapon(row.offhandWeaponId);assert(data:EquipOffhand(actor.Id,weapon.Id)) end
    for _,id in ipairs(row.wearableIds) do local item=data:AddWearable(id);assert(data:Wear(actor.Id,self.wearables:Get(id).slot,item.Id)) end
end
function Loadout:ApplyEnemy(data,actor)
    local state=CS.ProjectY.Data.EquipmentCombatState
    if state.IsInitialized(data,actor.Id) then return end
    local row=self.byUnit[actor.TemplateId]
    local main,off=0,0;local items,slots={},{}
    if row then
        assert(self:Validate(actor));main=row.weaponId;off=row.offhandWeaponId
        for _,id in ipairs(row.wearableIds) do items[#items+1]=id;slots[#slots+1]=self.wearables:Get(id).slot end
    elseif actor.AnimalSpeciesId==0 then
        main,off=self.rules:TemplateLoadout(actor.TemplateId)
        if off~=0 and self.rules.items:Get(off).kind=='wearable' then items[1]=off;slots[1]='offhand';off=0 end
    end
    state.Initialize(data,actor.Id,main,off,items,slots)
end
return Loadout
