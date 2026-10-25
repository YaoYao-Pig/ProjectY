-- Weapon damage is split once; armor condition remains owned by the equipped C# item.
local Armor={}
local function finite(value) return type(value)=='number' and value==value and math.abs(value)<math.huge end
function Armor.Applies(skill,source,target,attackHit,periodic,damageType)
    if not skill or (skill.armorPenetration==nil and skill.armorDamageMultiplier==nil and skill.fleshDamageMultiplier==nil) then return false end
    if periodic or not attackHit or source==target or (skill.skillGroup~='weapon' and skill.skillGroup~='slash') then return false end
    return damageType=='physical'
end
function Armor.Split(damage,current,skill,preserve)
    assert(finite(damage) and damage>=0 and damage%1==0,'Armor damage requires a nonnegative integer magnitude')
    assert(finite(current) and current>=0 and current%1==0,'Armor condition must be a nonnegative integer')
    local penetration,armorScale,fleshScale=skill.armorPenetration,skill.armorDamageMultiplier,skill.fleshDamageMultiplier
    assert(finite(penetration) and penetration>=0 and penetration<=100,'Invalid weapon armor penetration')
    assert(finite(armorScale) and armorScale>=0 and finite(fleshScale) and fleshScale>=0,'Invalid weapon damage multipliers')
    -- Allocate whole damage points before splitting so a one-point hit cannot damage both pools.
    local penetrating=damage>0 and penetration>0 and math.max(1,math.floor(damage*penetration/100+0.000000001)) or 0
    local protected=damage-penetrating
    local absorbed,wear=0,0
    if not preserve and current>0 then
        if armorScale==0 then absorbed=protected
        else
            absorbed=math.min(protected,current/armorScale)
            if protected>0 then wear=math.min(current,math.max(1,math.floor(protected*armorScale))) end
        end
    end
    local overflow=protected-absorbed
    local flesh=(penetrating+overflow)*fleshScale
    local health=flesh>0 and math.max(1,math.floor(flesh+0.000000001)) or 0
    assert(health<=1000000,'Armor-adjusted health damage exceeds bounds')
    return health,{before=current,after=current-wear,damage=wear,absorbed=absorbed,penetrating=penetrating,
        overflow=overflow,preserved=preserve==true}
end
function Armor.Apply(equipment,target,damage,skill,hit,preserve)
    -- Mounts and actors without body health have no head/body armor recipient.
    local slot=hit and (hit.part.index==0 and 'head' or 'body') or nil
    local item=slot and equipment:Worn(target.Id,slot) or nil
    local current=item and CS.ProjectY.Data.EquipmentConditionData.Of(item).Current or 0
    local health,details=Armor.Split(damage,current,skill,preserve)
    details.slot=slot;details.itemId=item and item.ItemId or nil;details.instanceId=item and item.Id or nil
    if details.damage>0 then
        local actual=CS.ProjectY.Data.EquipmentCombatState.DamageArmorAt(equipment,target.Id,slot,details.damage)
        assert(actual==details.damage,'Armor condition changed during damage settlement')
    end
    return health,details
end
return Armor
