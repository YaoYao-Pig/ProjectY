local Class = require('Core.Class')
local Stats = Class('CombatStats')
local primary = { 'vitality', 'endurance', 'intellect', 'strength', 'speed', 'defense' }
function Stats:ctor(config, equipmentData)
    self.equipment = require('Game.Equipment.EquipmentRules').New(config,equipmentData)
    self.units = config:GetTable('CombatUnitTable')
    self.traits = config:GetTable('CombatTraitTable')
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
function Stats:Get(unit, name)
    -- 未训练的二级属性允许缺失，其基础值按契约为 0。
    local value = assert(self.attributes[unit.TemplateId])[name] or 0
    for i = 0, unit.TraitCount - 1 do
        local trait = self.traits:Get(unit:GetTraitAt(i))
        if trait.attribute == name then value = value + trait.amount end
    end
    return math.max(0, value)
end
function Stats:MaximumHP(unit)
    local hp = self:Template(unit).maxHealth:Evaluate({vitality = self:Get(unit, 'vitality'), endurance = self:Get(unit, 'endurance')})
    assert(hp >= 1 and hp <= 1000000 and hp == math.floor(hp), 'Invalid maximum HP')
    return hp
end
function Stats:EffectVariables(source, target, skill)
    local values = {}
    for _, name in ipairs(primary) do values[name] = self:Get(source, name) end
    values.defense = self:Get(target, 'defense')
    values.guard = target.Guard
    values.proficiency = self:Get(source, skill.proficiency)
    return values
end
return Stats
