-- Rules and projections only. BodyHealth owns all mutable injury state on C# actors.
local Rules={};Rules.__index=Rules
local LuaLanguage=require('Language')
function Rules.New(config)
    local self=setmetatable({parts=config:GetTable('BodyPartTable'):All(),stages=config:GetTable('InjuryStageTable'),
        types=config:GetTable('InjuryTypeTable'),settings=config:GetTable('InjurySettingsTable'):Get(1),
        treatments=config:GetTable('InjuryTreatmentTable'),units=config:GetTable('CombatUnitTable'),
        items=config:GetTable('EquipmentItemTable'),attributes={},orderedStages={},penaltyCache=setmetatable({},{__mode='k'})},Rules)
    for _,row in ipairs(config:GetTable('GrowthAttributeTable'):All())do self.attributes[row.code]=row.name end
    local weight,seen=0,{}
    assert(#self.parts==6,'Injuries require six stable body parts')
    for _,part in ipairs(self.parts)do
        assert(not seen[part.index] and #part.attributes==#part.penalties,'Invalid body part definition')
        seen[part.index]=true;weight=weight+part.weight
        for i,name in ipairs(part.attributes)do
            assert(self.attributes[name] and name~='vitality' and name~='endurance','Injury penalties must not alter maximum HP')
            assert(part.penalties[i]>=0 and part.penalties[i]<=1,'Invalid injury penalty')
        end
    end
    assert(weight==100,'Body part hit weights must total 100')
    for _,stage in ipairs(self.stages:All())do self.orderedStages[#self.orderedStages+1]=stage;require('Config.Color').Normalize(stage.color)end
    table.sort(self.orderedStages,function(a,b)return a.minimumDamage<b.minimumDamage end)
    assert(#self.orderedStages==4 and self.orderedStages[1].minimumDamage==0 and self.orderedStages[2].minimumDamage==1
        and self.orderedStages[4].minimumDamage==100 and self.orderedStages[1].penaltyScale==0,'Invalid injury stages')
    for i=2,4 do assert(self.orderedStages[i].minimumDamage>self.orderedStages[i-1].minimumDamage,'Overlapping injury stages')end
    assert(self.settings.minimumDamage<=self.settings.maximumDamage and self.settings.baseChance<=self.settings.maximumChance,'Invalid injury accumulation settings')
    for _,treatment in ipairs(self.treatments:All())do assert(self.items:Get(treatment.itemId).kind=='consumable','Treatment requires consumable supplies')end
    return self
end
function Rules:Stage(damage,permanent)
    if permanent then return self.orderedStages[4] end
    damage=math.min(99,damage)
    for i=3,1,-1 do local stage=self.orderedStages[i];if damage>=stage.minimumDamage then return stage end end
    error('Negative body damage')
end
function Rules:Severity(actor,index)
    local state=CS.ProjectY.Data.BodyHealth;local maximum=state.MaximumHP(actor,index)
    local missing=maximum>0 and (1-state.HP(actor,index)/maximum)*100 or 0
    return math.max(state.Damage(actor,index),missing)
end
function Rules:Penalty(actor,attribute)
    local state=CS.ProjectY.Data.BodyHealth;local revision=state.Revision(actor)
    local cached=self.penaltyCache[actor]
    if not cached or cached.revision~=revision then
        cached={revision=revision,values={}};self.penaltyCache[actor]=cached
        for _,part in ipairs(self.parts)do
            local scale=self:Stage(self:Severity(actor,part.index),state.Permanent(actor,part.index)).penaltyScale
            cached.values.moveRange=(cached.values.moveRange or 0)+part.movementPenalty*scale
            for i,name in ipairs(part.attributes)do cached.values[name]=(cached.values[name] or 0)+part.penalties[i]*scale end
        end
    end
    return math.min(self.settings.maximumPenalty,cached.values[attribute] or 0)
end
function Rules:ApplyAttribute(actor,name,value)
    local penalty=self:Penalty(actor,name)
    return penalty==0 and value or math.max(0,math.floor(value*(1-penalty)))
end
function Rules:MoveRange(actor,range)
    return math.max(1,self:ApplyAttribute(actor,'moveRange',range))
end
function Rules:Chance(health,maximum,amount,effect)
    local settings=self.settings
    return math.min(settings.maximumChance,math.floor(settings.baseChance+(1-health/maximum)*100*settings.missingHealthChanceScale
        +math.min(100,amount/maximum*100)*settings.damageChanceScale+effect.injuryChanceBonus))
end
function Rules:SelectHit(target,roll)
    assert(target.HP>0 and not target.MountedAnimal,'Body hit needs live unmounted recipient')
    local state=CS.ProjectY.Data.BodyHealth;local total=0
    for _,part in ipairs(self.parts)do if state.MaximumHP(target,part.index)>0 then total=total+part.weight end end
    local locationRoll=assert(roll,'Body hits require the combat random stream')();local pick=locationRoll/100*total;local selected
    for _,part in ipairs(self.parts)do if state.MaximumHP(target,part.index)>0 then pick=pick-part.weight;if pick<0 then selected=part;break end end end
    assert(selected,'Invalid body hit roll')
    return {part=selected,locationRoll=locationRoll}
end
function Rules:DamageHit(source,target,effect,amount,roll,hit)
    assert(amount>0 and target.HP>0 and not target.MountedAnimal,'Body hit needs live unmounted recipient')
    hit=hit or self:SelectHit(target,roll)
    local selected,index=hit.part,hit.part.index
    local state=CS.ProjectY.Data.BodyHealth
    local before,maximum=state.HP(target,index),state.MaximumHP(target,index)
    local wasPermanent=state.Permanent(target,index)
    local actual=state.Hit(target,index,amount,effect.injuryTypeId>0 and effect.injuryTypeId or self.settings.defaultInjuryTypeId)
    local disabled=not wasPermanent and state.Permanent(target,index)
    local trauma=false;local chance,rolled
    if effect.injuryTypeId>0 and not state.Permanent(target,index) then
        local kind=self.types:Get(effect.injuryTypeId);local settings=self.settings
        chance=self:Chance(before,maximum,amount,effect);rolled=roll()
        if rolled<chance then
            local damage=math.max(settings.minimumDamage,math.min(settings.maximumDamage,math.floor(actual/maximum*100*settings.damageScale*kind.damageScale)))
            trauma=state.Injure(target,index,kind.id,damage)
        end
    end
    if not trauma and not disabled then return actual end
    local stage=self:Stage(self:Severity(target,index),state.Permanent(target,index))
    return actual,{part=index,partName=selected.name,injuryName=self.types:Get(state.Kind(target,index)).name,
        damage=state.Damage(target,index),health=state.HP(target,index),maximum=maximum,stage=stage.name,color=stage.color,
        permanent=state.Permanent(target,index),trauma=trauma,chance=chance,roll=rolled,locationRoll=hit.locationRoll}
end
function Rules:Rows(actor)
    local rows={};local state=CS.ProjectY.Data.BodyHealth
    for _,part in ipairs(self.parts)do
        local damage=state.Damage(actor,part.index);local stage=self:Stage(self:Severity(actor,part.index),state.Permanent(actor,part.index))
        local kind=damage>0 and self.types:Get(state.Kind(actor,part.index))
        local modifiers={}
        for i,attribute in ipairs(part.attributes)do
            if part.penalties[i]*stage.penaltyScale~=0 then modifiers[#modifiers+1]={name=self.attributes[attribute],value=-part.penalties[i]*stage.penaltyScale*100,percent=true} end
        end
        if part.movementPenalty*stage.penaltyScale~=0 then modifiers[#modifiers+1]={name=LuaLanguage.BodyMovement,value=-part.movementPenalty*stage.penaltyScale*100,percent=true}end
        rows[#rows+1]={index=part.index,name=part.name,health=state.HP(actor,part.index),maximum=state.MaximumHP(actor,part.index),damage=damage,color=stage.color,stage=stage.name,
            injury=kind and kind.name or LuaLanguage.BodyNoInjury,description=kind and kind.description or LuaLanguage.BodyNoTraumaDescription,
            permanent=state.Permanent(actor,part.index),modifiers=modifiers}
    end
    return rows
end
function Rules:Treatment(actor,partIndex,treatmentId,equipment)
    local treatment=self.treatments:Find(treatmentId)
    if type(partIndex)~='number' or partIndex%1~=0 or partIndex<0 or partIndex>5 or not treatment then return false,LuaLanguage.BodyInvalidTreatment end
    local state=CS.ProjectY.Data.BodyHealth
    if state.Permanent(actor,partIndex)then return false,LuaLanguage.BodyPermanentDescription end
    if state.Damage(actor,partIndex)==0 then return false,LuaLanguage.BodyHealthyDescription end
    if equipment:CountItem(treatment.itemId)<treatment.count then return false,LuaLanguage.BodyMissingSupplies end
    return true,treatment
end
function Rules:ValidateSaved(actor)
    local state=CS.ProjectY.Data.BodyHealth
    for _,part in ipairs(self.parts)do
        local damage=state.Damage(actor,part.index)
        if damage>0 then assert(self.units:Get(actor.TemplateId).bodyInjuries,'Non-humanoid actor has human injuries');self.types:Get(state.Kind(actor,part.index))end
        assert(not state.Permanent(actor,part.index) or state.HP(actor,part.index)==0 and damage==100,'Permanent injury requires empty body HP')
    end
end
return Rules
