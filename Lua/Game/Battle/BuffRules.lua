local Rules={};Rules.__index=Rules
function Rules.New(config)
    local self=setmetatable({rows={},effects=config:GetTable('CombatEffectTable')},Rules)
    for _,source in ipairs(config:GetTable('BuffTable'):All()) do
        assert(not self.effects:Find(source.id),'Buff IDs and effect IDs must be distinct: '..source.id)
        local row={};for key,value in pairs(source)do row[key]=value end
        row.kind='buff';row.color=require('Config.Color').Normalize(row.color)
        row.duration=row.clock=='turns' and 'duration' or 'infinite';row.removeOnBattleEnd=row.scope=='battle'
        assert(row.name~='' and row.description~='','Buff needs display metadata')
        assert(row.clock~='turns' or row.durationTurns>0,'Turn buff needs a duration')
        assert(row.clock~='minutes' or row.durationMinutes>=1,'Minute buff needs at least one game minute')
        assert(row.clock~='minutes' or row.scope=='persistent','Combat time is measured in turns, not world minutes')
        assert(row.stacking~='stack' or row.maxStacks>1,'Stacking buff needs a limit')
        local seen={};row.componentIds={}
        for _,id in ipairs(row.periodicEffectIds)do
            local effect=self.effects:Get(id)
            assert(effect.duration=='instant' and (effect.kind=='damage' or effect.kind=='heal'),'Buff periodic components must be instant damage/heal')
            assert(effect.recipient=='target' and #effect.requiredTags==0 and #effect.forbiddenTags==0,'Periodic components must apply unconditionally to their buff owner')
            assert(not seen[id],'Duplicate buff component');seen[id]=true;row.componentIds[#row.componentIds+1]=id
        end
        for _,id in ipairs(row.modifierEffectIds)do
            local effect=self.effects:Get(id)
            assert(effect.kind=='modifier' and effect.recipient=='target' and #effect.requiredTags==0 and #effect.forbiddenTags==0,'Buff stat components must be unconditional owner modifiers')
            assert(not seen[id],'Duplicate buff component');seen[id]=true;row.componentIds[#row.componentIds+1]=id
        end
        for _,id in ipairs(row.onApplyEffectIds)do
            local effect=self.effects:Get(id)
            assert(effect.duration=='instant' and (effect.kind=='damage' or effect.kind=='heal' or effect.kind=='guard'),'Buff entry actions must be instant, non-recursive effects')
        end
        assert(#row.componentIds<=64,'Too many buff components')
        if #row.periodicEffectIds>0 then
            local turnPeriod=row.periodTurns>0;local minutePeriod=row.periodMinutes>=1
            assert(turnPeriod~=minutePeriod,'Periodic buffs need exactly one turn/minute period')
            assert(turnPeriod and row.periodMinutes==0 or minutePeriod and row.periodTurns==0,'Unused buff period must be zero')
            assert(row.clock=='infinite' or row.clock=='turns' and turnPeriod or row.clock=='minutes' and minutePeriod,'Buff duration and period clocks differ')
            assert(not minutePeriod or row.scope=='persistent','Minute periods require a persistent buff')
        else assert(row.periodTurns==0 and row.periodMinutes==0,'Non-periodic buff cannot have a period') end
        for _,field in ipairs({'tags','blockedByTags','removeTags'})do
            local unique={};for _,tag in ipairs(row[field])do assert(tag~='' and not unique[tag],'Invalid/duplicate buff tag');unique[tag]=true end
        end
        for _,tag in ipairs(row.tags)do for _,removed in ipairs(row.removeTags)do assert(tag~=removed,'A buff cannot remove its own tags')end end
        local groups={weapon=true,spell=true,support=true,slash=true,animal=true,construction=true}
        local selected={}
        for _,group in ipairs(row.skillGroups)do
            assert(groups[group] and not selected[group],'Unknown/duplicate buff skill group: '..tostring(group));selected[group]=true
        end
        assert(not (row.manualEnemyTargets or row.ignoreProjectileBlockers) or #row.skillGroups>0,'Skill-modifying buff needs explicit skill groups')
        self.rows[row.id]=row
    end
    return self
end
function Rules:Find(id)return self.rows[id]end
function Rules:Get(id)return assert(self.rows[id],'Unknown buff: '..id)end
function Rules:Tagged(row,tags)
    if not row then return false end
    for _,tag in ipairs(row.tags)do for _,wanted in ipairs(tags)do if tag==wanted then return true end end end
    return false
end
function Rules:Blocked(target,row)
    for i=0,target.Effects.Count-1 do
        local blocker=self:Find(target.Effects:GetAt(i).EffectId)
        if self:Tagged(blocker,row.blockedByTags)then return true,blocker end
    end
    return false
end
function Rules:Skipping(target)
    for i=0,target.Effects.Count-1 do local row=self:Find(target.Effects:GetAt(i).EffectId);if row and row.skipTurn then return row end end
end
function Rules:ApplySkillModifiers(actor,skill)
    skill.guided=false;skill.manualTargets=false
    if skill.target~='enemy' or skill.range<=1 then return skill end
    local projectile=skill.trajectory=='direct' or skill.trajectory=='lobbed'
    for i=0,actor.Effects.Count-1 do
        local row=self:Find(actor.Effects:GetAt(i).EffectId)
        if row then
            for _,group in ipairs(row.skillGroups)do if group==skill.skillGroup then
                skill.guided=skill.guided or (row.ignoreProjectileBlockers and projectile)
                skill.manualTargets=skill.manualTargets or (row.manualEnemyTargets and skill.maxTargets>1)
                break
            end end
        end
    end
    return skill
end
function Rules:Bonus(instance,name)
    local row=self:Get(instance.EffectId);local total=0
    for _,id in ipairs(row.modifierEffectIds)do if self.effects:Get(id).attribute==name then total=total+CS.ProjectY.Data.GameBuffState.Amount(instance,id)*instance.Stacks end end
    return total
end
function Rules:PendingBonus(pending,name)
    local total=0
    for _,id in ipairs(pending.buff.modifierEffectIds)do if self.effects:Get(id).attribute==name then total=total+assert(pending.amounts[id])*pending.stacks end end
    return total
end
return Rules
