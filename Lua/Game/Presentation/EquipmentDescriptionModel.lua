-- Equipment prose uses the same explicit term catalog as battle skill cards.
-- No keyword matching or gameplay decisions are derived from translated text.
local L=require('Language')
local Model={};Model.__index=Model
local instances=setmetatable({},{__mode='k'})
local function paint(text,color,size)
    return '<size='..size..'><color='..color..'>'..text..'</color></size>'
end
local function link(id,label)return '<link="term:'..id..'">'..label..'</link>'end
function Model.New(config)
    local self=setmetatable({catalog=require('Game.Presentation.SkillTipCatalog').New(config),
        descriptions=config:GetTable('EquipmentDescriptionTable'),weapons=config:GetTable('EquipmentWeaponTable'),
        skills=config:GetTable('CombatSkillTable'),effects=config:GetTable('CombatEffectTable')},Model)
    for _,row in ipairs(self.descriptions:All())do
        for _,field in ipairs({'trigger','effect','limit','usage'})do self.catalog:Rich(row[field])end
        for _,id in ipairs(row.skillIds)do self.catalog:Description(id)end
    end
    return self
end
function Model.For(config)
    if not instances[config]then instances[config]=Model.New(config)end
    return instances[config]
end
function Model:GrantedSkills(itemId)
    local row=self.descriptions:Find(itemId)
    if row then return row.skillIds end
    local weapon=self.weapons:Find(itemId)
    return weapon and weapon.skillIds or {}
end
function Model:Skill(skill)
    local description=self.catalog:Description(skill.id)
    local tags={}
    for _,tag in ipairs(description.tags)do tags[#tags+1]=paint(self.catalog.Escape(tag.name),tag.textColor,12)end
    local action=link(skill.action=='main'and 'main_action'or 'secondary_action',skill.action=='main'and L.BattleMain or L.BattleSecondary)
    local params=string.format(L.EquipmentSkillCostAction,skill.cost,action)
    local distance=skill.range==0 and L.UISkillTipSelf or skill.minRange>0
        and string.format(L.EquipmentSkillRangeBand,skill.minRange,skill.range)
        or string.format(L.EquipmentSkillRange,skill.range)
    params=params..'\n'..string.format(L.EquipmentSkillRangeCooldown,link('range',distance),skill.cooldownTurns)
    local lines={paint('<b>'..self.catalog.Escape(skill.name)..'</b>','#E9C580',17),table.concat(tags,'  ·  '),
        paint(self.catalog:Rich(params),'#C6D2DD',13),paint(description.body,'#E3E9ED',14)}
    local damage=false
    for _,id in ipairs(skill.effectIds)do if self.effects:Get(id).kind=='damage'then damage=true;break end end
    if damage then
        lines[#lines+1]=paint(self.catalog:Rich(string.format(L.EquipmentSkillDamageHit,skill.damageScale,link('hit',skill.hitChance..'%'))),'#D5DEE4',13)
    end
    if skill.maxTargets>1 then
        lines[#lines+1]=paint(self.catalog.Escape(L.UISkillTipText7),'#A5B5C5',12)..'  '..paint(self.catalog.Escape(string.format(L.UISkillTipText6,skill.maxTargets)),'#F1D18A',13)
    end
    if skill.shots>1 then
        lines[#lines+1]=paint(self.catalog.Escape(L.UISkillTipText5),'#A5B5C5',12)..'  '..paint(self.catalog.Escape(string.format(L.UISkillTipText4,skill.shots)),'#F1D18A',13)
    end
    if skill.ammoPerShot>0 then lines[#lines+1]=paint(self.catalog.Escape(string.format(L.UIEquipmentWorkbenchEffectsEffects1,skill.shots*skill.ammoPerShot)),'#A4B2BF',12)end
    if skill.equipmentDescriptionReason then lines[#lines+1]=paint(self.catalog.Escape(skill.equipmentDescriptionReason),'#F19A96',13)end
    return table.concat(lines,'\n')
end
function Model:Equipment(itemId,resolve)
    local row=self.descriptions:Find(itemId);local lines={}
    if row then
        lines[#lines+1]=paint(self.catalog.Escape(L.EquipmentPassiveEffect),'#A4B2BF',12)
        lines[#lines+1]=paint('<b>'..self.catalog.Escape(row.passiveName)..'</b>','#E9C580',17)
        for _,field in ipairs({'trigger','effect','limit'})do
            if row[field]~=''then
                local label=field=='trigger'and L.EquipmentEffectTrigger or field=='effect'and L.EquipmentEffectBenefit or L.EquipmentEffectLimit
                lines[#lines+1]=paint(self.catalog.Escape(label),'#A5B5C5',12)..'  '..paint(self.catalog:Rich(row[field]),'#E3E9ED',14)
            end
        end
        if row.usage~=''then lines[#lines+1]=paint(self.catalog.Escape(L.EquipmentUsageRule),'#A5B5C5',12)..'  '..paint(self.catalog:Rich(row.usage),'#D5DEE4',14)end
    else
        local weapon=self.weapons:Find(itemId)
        if weapon and weapon.description~=''then lines[#lines+1]=paint(self.catalog.Escape(weapon.description),'#E3E9ED',14)end
    end
    local ids=self:GrantedSkills(itemId)
    if #ids>0 then
        lines[#lines+1]='\n'..paint(self.catalog.Escape(L.EquipmentGrantedSkills),'#A4B2BF',12)
        for _,id in ipairs(ids)do lines[#lines+1]=self:Skill(resolve and resolve(id)or self.skills:Get(id))..'\n'end
    end
    if #lines>0 then table.insert(lines,1,paint(self.catalog.Escape(L.EquipmentTermHint),'#879BAB',11)..'\n')end
    return table.concat(lines,'\n')
end
return Model
