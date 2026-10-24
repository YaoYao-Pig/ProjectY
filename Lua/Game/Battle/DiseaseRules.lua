-- Diseases reuse persistent Buff state, attribute modifiers and save validation.
local Rules={};Rules.__index=Rules
local LuaLanguage=require('Language')
function Rules.New(config)
    local self=setmetatable({definitions=config:GetTable('DiseaseTable'),buffs=config:GetTable('BuffTable'),
        effects=config:GetTable('CombatEffectTable'),items=config:GetTable('EquipmentItemTable'),attributes={}},Rules)
    for _,row in ipairs(config:GetTable('GrowthAttributeTable'):All())do self.attributes[row.code]=row.name end
    for _,row in ipairs(self.definitions:All())do
        local buff=self.buffs:Get(row.buffId);local effect=self.effects:Get(row.effectId)
        assert(buff.scope=='persistent' and not buff.removeOnDeath,'Diseases must persist until treated')
        assert(effect.kind=='apply_buff' and effect.buffId==row.buffId and effect.chance==100,'Disease proc owns the single probability check')
        assert(self.items:Get(row.itemId).kind=='consumable','Disease treatment needs medicine')
    end
    return self
end
function Rules:OnTrauma(effects,source,target)
    for _,row in ipairs(self.definitions:All())do
        if not target.Effects:Find(row.buffId) and effects.roll()<row.chance then effects:Apply(row.effectId,source,target)end
    end
end
function Rules:Rows(actor)
    local result={}
    for _,row in ipairs(self.definitions:All())do
        local instance=actor.Effects:Find(row.buffId)
        if instance then
            local buff=self.buffs:Get(row.buffId);local modifiers={}
            for _,id in ipairs(buff.modifierEffectIds)do
                local effect=self.effects:Get(id)
                modifiers[#modifiers+1]={name=assert(self.attributes[effect.attribute]),value=CS.ProjectY.Data.GameBuffState.Amount(instance,id)*instance.Stacks,percent=false}
            end
            result[#result+1]={id=row.id,name=buff.name,description=buff.description,modifiers=modifiers}
        end
    end
    return result
end
function Rules:Treat(actor,id,equipment,effects)
    local row=self.definitions:Find(id);if not row then return false,LuaLanguage.BodyInvalidTreatment end
    local instance=actor.Effects:Find(row.buffId);if not instance then return false,LuaLanguage.BodyNoDisease end
    if equipment:CountItem(row.itemId)<row.count then return false,LuaLanguage.BodyMissingMedicine end
    -- Resolve/validate the existing persistent effect before inventory is committed.
    effects:Definition(instance.EffectId)
    equipment:ConsumeStack(row.itemId,row.count);effects:Remove(actor,instance.Id)
    return true,LuaLanguage.BodyDiseaseCured
end
return Rules
