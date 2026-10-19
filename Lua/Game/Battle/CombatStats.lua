local Class = require('Core.Class')
local Stats = Class('CombatStats')
local primary = { 'vitality', 'endurance', 'intellect', 'strength', 'speed', 'defense' }
function Stats:ctor(config, equipmentData)
    self.equipment = require('Game.Equipment.EquipmentRules').New(config,equipmentData)
    self.units = config:GetTable('CombatUnitTable')
    self.traits = config:GetTable('CombatTraitTable')
    self.effects = config:GetTable('CombatEffectTable')
    self.buffs = require('Game.Battle.BuffRules').New(config)
    self.growth = require('Game.Progression.GrowthRules').New(config)
    self.animals = require('Game.Animals.AnimalRules').New(config)
    self.heightAdvantage=require('Game.Battle.HeightAdvantage').New(config)
    self.projectileCover=config:GetTable('ProjectileCoverTable'):Get(1)
    self.attributes = {}
    for _, row in ipairs(self.units:All()) do
        assert(#row.attributeNames == #row.attributeValues, 'Unit attribute arrays differ: ' .. row.id)
        local values = {}
        for _, name in ipairs(primary) do values[name] = row[name] end
        for i, name in ipairs(row.attributeNames) do
            assert(not values[name] and name ~= '', 'Duplicate/empty attribute: ' .. name)
            assert(row.attributeValues[i] >= 0, 'Negative base attribute')
            values[name] = row.attributeValues[i]
        end
        self.attributes[row.id] = values
    end
end
function Stats:Template(unit) return self.units:Get(unit.TemplateId) end
function Stats:Get(unit, name, excludeEquipment, pendingEffect)
    -- 未训练的二级属性允许缺失，其基础值按契约为 0。
    local value = assert(self.attributes[unit.TemplateId])[name] or 0
    for i = 0, unit.TraitCount - 1 do
        local trait = self.traits:Get(unit:GetTraitAt(i))
        if trait.attribute == name then value = value + trait.amount end
    end
    for i=0,unit.Effects.Count-1 do
        local instance=unit.Effects:GetAt(i)
        local removed=pendingEffect and (instance.Id==pendingEffect.oldId or pendingEffect.removedIds and pendingEffect.removedIds[instance.Id])
        if not removed then
            if self.buffs:Find(instance.EffectId) then value=value+self.buffs:Bonus(instance,name)
            else local effect=self.effects:Get(instance.EffectId)
                if effect.kind=='modifier' and effect.attribute==name then value=value+instance.Amount*instance.Stacks end
            end
        end
    end
    if pendingEffect and pendingEffect.attribute==name then value=value+pendingEffect.amount*pendingEffect.stacks end
    if pendingEffect and pendingEffect.buff then value=value+self.buffs:PendingBonus(pendingEffect,name) end
    return math.max(0, value + self.growth:Bonus(unit,name) + (excludeEquipment and 0 or self.equipment:AttributeBonus(unit,name)))
end
function Stats:MaximumHP(unit,pendingEffect)
    local hp = self:Template(unit).maxHealth:Evaluate({vitality = self:Get(unit, 'vitality',false,pendingEffect), endurance = self:Get(unit, 'endurance',false,pendingEffect)})
    assert(hp >= 1 and hp <= 1000000 and hp == math.floor(hp), 'Invalid maximum HP')
    return hp
end
function Stats:EffectVariables(source, target, skill)
    local values = {}
    for _, name in ipairs(primary) do values[name] = self:Get(source, name) end
    values.defense = self:Get(target, 'defense')
    values.guard = target.Guard
    values.proficiency = skill and self:Get(source, skill.proficiency) or 0
    values.distance = 0
    return values
end
return Stats
