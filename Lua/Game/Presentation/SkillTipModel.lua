local LuaLanguage = require('Language')
-- Structured display of the resolved skill; never predicts damage against an invented target.
local Model={};Model.__index=Model
local targets=require('Config.LanguageProxy').Map(LuaLanguage,{enemy='UISkillTipEnemy',ally='UISkillTipAlly',self='UISkillTipSelf',cell='UISkillTipCell',any='UISkillTipAny'})
local function link(id,label) return '<link="term:'..id..'">'..label..'</link>' end
function Model.New(config)
    return setmetatable({catalog=require('Game.Presentation.SkillTipCatalog').New(config),
        synergies=require('Game.Equipment.SkillSynergies').New(config),skills=config:GetTable('CombatSkillTable'),
        effects=config:GetTable('CombatEffectTable')},Model)
end
function Model:Build(row,adventure)
    local skill=assert(row.skill,'Skill tooltip requires a resolved skill')
    local base=self.skills:Get(skill.id);local description=self.catalog:Description(skill.id)
    local result={title=row.name,body=description.body,tags=description.tags,stats={},synergies={},breadcrumb=LuaLanguage.UISkillTipBreadcrumb2}
    local function stat(label,value,color)
        result.stats[#result.stats+1]={label=self.catalog:Rich(label),value=tostring(value),color=color or '#E8DBC2'}
    end
    stat(LuaLanguage.UISkillTipText19,skill.cost..' AP','#F1D18A')
    stat(LuaLanguage.UISkillTipText18,skill.action=='main' and LuaLanguage.BattleMain or LuaLanguage.BattleSecondary)
    stat(LuaLanguage.UISkillTipText17,skill.range==0 and LuaLanguage.UISkillTipSelf or string.format(LuaLanguage.UIStartMenuSize3, (skill.range)),'#8CCBDD')
    if skill.minRange>0 then stat(LuaLanguage.UISkillTipText16,string.format(LuaLanguage.UIStartMenuSize3, (skill.minRange)),'#8CCBDD') end
    if skill.fixedRange then stat(LuaLanguage.UISkillTipText15,LuaLanguage.UISkillTipText14,'#8CCBDD') end
    stat(LuaLanguage.UISkillTipText13,(assert(targets[skill.target],'Unknown tooltip target')))
    local damage=false
    for _,id in ipairs(base.effectIds) do if self.effects:Get(id).kind=='damage' then damage=true;break end end
    if damage then stat(LuaLanguage.UISkillTipText12,string.format('× %.2f',skill.damageScale),'#F2AE8D') end
    if skill.target=='enemy' then stat(link('hit',LuaLanguage.UISkillTipText11),skill.hitChance..'%','#F1D18A') end
    if damage and skill.criticalChance>0 then
        stat(LuaLanguage.UISkillCriticalChance,string.format('%g%%',skill.criticalChance),'#F1D18A')
        stat(LuaLanguage.UISkillCriticalMultiplier,string.format('× %.2f',skill.criticalMultiplier),'#F2AE8D')
    end
    stat(LuaLanguage.UISkillTipText10,string.format(LuaLanguage.UISkillTipText9, (skill.cooldownTurns), (row.cooldown>0 and (string.format(LuaLanguage.UISkillTipText8, (row.cooldown))) or '')))
    if skill.target=='enemy' then stat(LuaLanguage.UISkillTipText7,string.format(LuaLanguage.UISkillTipText6, (skill.maxTargets))) end
    if skill.shots>1 then stat(LuaLanguage.UISkillTipText5,string.format(LuaLanguage.UISkillTipText4, (skill.shots))) end
    if skill.ammoPerShot>0 then stat(LuaLanguage.UISkillTipText3,string.format(LuaLanguage.UISkillTipText2, (skill.shots*skill.ammoPerShot))) end
    if skill.splashRadius>0 then stat(LuaLanguage.UISkillTipText,string.format(LuaLanguage.UIStartMenuSize3, (skill.splashRadius))) end
    local mechanics={}
    if skill.target=='enemy' then mechanics[#mechanics+1]=link('height',LuaLanguage.UISkillTipMechanicsMechanics15) end
    if skill.guided or skill.manualTargets then mechanics[#mechanics+1]=link('tracking',LuaLanguage.UISkillTipMechanicsMechanics14)
    elseif skill.trajectory~='sight' then mechanics[#mechanics+1]=link(skill.trajectory,skill.trajectory=='direct' and LuaLanguage.UISkillTipMechanicsMechanics13 or LuaLanguage.UISkillTipMechanicsMechanics12) end
    if skill.target=='any' and base.allowTransfer then mechanics[#mechanics+1]=link('transfer',LuaLanguage.UISkillTipMechanicsMechanics1) end
    if #mechanics>0 then result.body=string.format(LuaLanguage.UISkillTipBody3, (result.body), (self.catalog:Rich(table.concat(mechanics,'  ·  ')))) end
    if skill.manualTargets then result.body=string.format(LuaLanguage.UISkillTipBody2, (result.body), (skill.maxTargets)) end
    if not row.available then
        result.body=result.body..'\n\n<color=#F1A08C>'..self.catalog.Escape(row.reason)..'</color>'
    elseif skill.skillKind=='item' then result.body=string.format(LuaLanguage.UISkillTipBody, (result.body)) end
    for _,entry in ipairs(self.synergies:Rows(base,skill,adventure)) do
        if entry.known then entry.body=self.catalog:Rich(entry.body) end
        result.synergies[#result.synergies+1]=entry
    end
    if #result.synergies>0 then
        local discovered=0;for _,entry in ipairs(result.synergies) do if entry.known then discovered=discovered+1 end end
        result.breadcrumb=string.format(LuaLanguage.UISkillTipBreadcrumb, (discovered), (#result.synergies))
    end
    return result
end
return Model
