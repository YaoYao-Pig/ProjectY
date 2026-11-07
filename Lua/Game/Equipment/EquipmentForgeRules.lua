local L=require('Language')
local Rules={};Rules.__index=Rules
local function contains(values,value)
    for _,entry in ipairs(values) do if entry==value then return true end end
    return false
end
function Rules.New(config)
    local self=setmetatable({byWeapon={},byKind={}},Rules)
    self.recipes=config:GetTable('EquipmentForgeTable');self.settings=self.recipes:Get(1)
    self.paths=config:GetTable('EquipmentLegacyPathTable');self.deeds=config:GetTable('EquipmentDeedTable')
    self.items=config:GetTable('EquipmentItemTable');self.units=config:GetTable('CombatUnitTable');self.missions=config:GetTable('MissionTable')
    for _,row in ipairs(self.recipes:All()) do
        config:GetTable('CampFacilityTable'):Get(row.facilityId)
        config:GetTable('DialogueCameraTable'):Get(row.spiritCameraId)
        assert(#row.weaponIds>0 and #row.itemIds==#row.itemCounts and row.damageBonus>=0,'Invalid forge recipe')
        local seen={}
        for i,id in ipairs(row.itemIds) do
            assert(self.items:Get(id).kind=='material' and row.itemCounts[i]>0 and not seen[id],'Invalid forge material')
            seen[id]=true
        end
        for _,id in ipairs(row.weaponIds) do
            assert(self.items:Get(id).kind=='weapon' and not self.byWeapon[id],'Duplicate forge weapon')
            config:GetTable('EquipmentWeaponTable'):Get(id);self.byWeapon[id]=row
        end
    end
    for _,row in ipairs(self.deeds:All()) do
        assert(not self.byKind[row.kind] and #row.targetIds>0,'Duplicate or empty equipment deed rule')
        assert(row.kind=='legendary_kill' or row.kind=='legendary_resolution' or row.kind=='mission','Unknown equipment deed kind')
        self.byKind[row.kind]=row;local seen={}
        for _,id in ipairs(row.targetIds) do
            assert(not seen[id],'Duplicate equipment deed target');seen[id]=true
            if row.kind=='mission' then self.missions:Get(id) else self.units:Get(id) end
        end
        if row.kind=='mission' then
            assert(#row.sourceTargetIds==#row.targetIds,'Mission deed sources differ')
            for _,id in ipairs(row.sourceTargetIds) do self.units:Get(id) end
        else assert(#row.sourceTargetIds==0,'Only mission deeds have source targets') end
    end
    for _,row in ipairs(self.paths:All()) do
        assert(#row.deedIds>0 and (row.kind=='hunter' or row.kind=='guardian'),'Invalid equipment legacy path')
        assert(row.damageBonus>=0 and row.guardValue>=0 and row.wishDamageBonus>=0,'Invalid equipment legacy benefit')
        for _,id in ipairs(row.deedIds) do self.deeds:Get(id) end
    end
    return self
end
function Rules:Recipe(itemId) return self.byWeapon[itemId] end
function Rules:CanAdvance(legacy,pathId)
    local path=self.paths:Find(pathId)
    if not path then return false,L.ForgePathUnavailable end
    if not legacy.Forged then return false,L.ForgeNeedsForging end
    if legacy.PathId~=0 then return false,L.ForgePathChosen end
    for i=0,legacy.DeedCount-1 do
        local deed=legacy:GetDeedAt(i)
        if contains(path.deedIds,deed.RuleId) then return true,'',deed.RuleId end
    end
    return false,L.ForgeNeedsDeed
end
function Rules:ValidateSaved(weapon)
    local legacy=CS.ProjectY.Data.EquipmentLegacyData.Of(weapon)
    if not legacy.Forged then return end
    assert(self:Recipe(weapon.ItemId),L.ForgeSaveInvalid)
    for i=0,legacy.DeedCount-1 do
        local deed=legacy:GetDeedAt(i);local row=assert(self.deeds:Find(deed.RuleId),L.ForgeSaveInvalid)
        assert(contains(row.targetIds,deed.TargetId),L.ForgeSaveInvalid)
    end
    if legacy.PathId>0 then
        local path=assert(self.paths:Find(legacy.PathId),L.ForgeSaveInvalid);local found=false
        for i=0,legacy.DeedCount-1 do if contains(path.deedIds,legacy:GetDeedAt(i).RuleId) then found=true end end
        assert(found,L.ForgeSaveInvalid)
    end
end
return Rules
