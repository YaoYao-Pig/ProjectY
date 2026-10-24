-- Discovery is an explicit equipment-command side effect; tooltip queries stay read-only.
local Synergies={};Synergies.__index=Synergies
function Synergies.New(config)
    return setmetatable({definitions=config:GetTable('SkillSynergyTable'),runes=config:GetTable('EquipmentRuneTable'),
        weapons=config:GetTable('EquipmentWeaponTable'),effects=config:GetTable('CombatEffectTable')},Synergies)
end
local function contains(values,value)
    for _,entry in ipairs(values) do if entry==value then return true end end
    return false
end
function Synergies:Assembled(row,weapon)
    local present={}
    for _,socketId in ipairs(self.weapons:Get(weapon.ItemId).socketIds) do
        local id=weapon:GetRune(socketId);if id~=0 then present[id]=true end
    end
    for _,id in ipairs(row.runeIds) do if not present[id] then return false end end
    return true
end
function Synergies:Discover(adventure,weapon)
    local discovery=CS.ProjectY.Data.SkillSynergyDiscovery
    for _,row in ipairs(self.definitions:All()) do
        if self:Assembled(row,weapon) then discovery.Discover(adventure,row.id) end
    end
end
function Synergies:Applies(row,skill)
    if #row.skillIds>0 and not contains(row.skillIds,skill.id) then return false end
    local damage=false
    for _,id in ipairs(skill.effectIds) do if self.effects:Get(id).kind=='damage' then damage=true;break end end
    for _,id in ipairs(row.runeIds) do
        local rune=self.runes:Get(id)
        if rune.skillGroup~=skill.skillGroup and not (rune.skillGroup=='physical' and (skill.skillGroup=='weapon' or skill.skillGroup=='slash')) then return false end
        local rangeChanged=not skill.fixedRange and skill.target~='self' and math.max(skill.target=='enemy' and 1 or 0,skill.range+rune.rangeBonus)~=skill.range
        local changes=(damage and rune.damageMultiplier~=1) or rangeChanged
            or (damage and skill.target=='enemy' and math.max(0,math.min(100,skill.criticalChance+rune.criticalBonus))~=skill.criticalChance)
            or (skill.target=='enemy' and math.max(0,math.min(100,skill.hitChance+rune.hitBonus))~=skill.hitChance)
            or math.max(0,skill.cooldownTurns+rune.cooldownBonus)~=skill.cooldownTurns
            or (rune.catalystKind~='none' and rune.catalystKind==skill.catalystKind)
            or (rune.transferSelf and skill.allowTransfer and skill.target=='self')
            or (skill.target=='enemy' and (rune.maxTargets>skill.maxTargets or rune.splashRadius>skill.splashRadius or damage and #rune.onHitEffectIds>0))
        if not changes then return false end
    end
    return true
end
function Synergies:Rows(base,resolved,adventure)
    local result={}
    for _,row in ipairs(self.definitions:All()) do if self:Applies(row,base) then
        local known=CS.ProjectY.Data.SkillSynergyDiscovery.Has(adventure,row.id)
        local active=true
        for _,runeId in ipairs(row.runeIds) do if not contains(resolved.appliedRuneIds,runeId) then active=false;break end end
        -- No hidden name, link or explanation enters the UI projection.
        result[#result+1]={id=row.id,known=known,active=known and active,
            name=known and row.name or '',body=known and row.body or ''}
    end end
    table.sort(result,function(a,b)
        if a.active~=b.active then return a.active end
        if a.known~=b.known then return a.known end
        return a.id<b.id
    end)
    return result
end
return Synergies
