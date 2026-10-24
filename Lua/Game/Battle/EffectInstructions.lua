-- Shared instruction semantics: conditions use the selected victim, recipients may be the source.
local Instructions={}
local health={
    sourceMissingHealth=function(source)return math.max(0,source.MaxHP-source.HP)end,
    targetMissingHealth=function(_,target)return math.max(0,target.MaxHP-target.HP)end,
    sourceHealthPercent=function(source)return 100*source.HP/source.MaxHP end,
    targetHealthPercent=function(_,target)return 100*target.HP/target.MaxHP end,
}
function Instructions.Values(stats,source,target,skill,distance)
    local values=stats:EffectVariables(source,target,skill);values.distance=distance or 0
    -- Only formulas which request health need live actor health; existing read-only queries remain valid.
    return setmetatable(values,{__index=function(_,name)
        local read=health[name];if read then return read(source,target) end
    end})
end
local function tagged(rules,target,tags)
    if #tags==0 then return false end
    for i=0,target.Effects.Count-1 do
        if rules:Tagged(rules:Find(target.Effects:GetAt(i).EffectId),tags)then return true end
    end
    return false
end
function Instructions.Allowed(rules,target,row,source)
    local sourceRequired=row.sourceRequiredTags;local sourceForbidden=row.sourceForbiddenTags
    return (#row.requiredTags==0 or tagged(rules,target,row.requiredTags)) and not tagged(rules,target,row.forbiddenTags)
        and (not sourceRequired or #sourceRequired==0 or source and tagged(rules,source,sourceRequired))
        and (not sourceForbidden or #sourceForbidden==0 or source and not tagged(rules,source,sourceForbidden))
end
function Instructions.ContainerDamage(row)
    return row.kind=='damage' and row.duration=='instant' and row.recipient=='target' and row.affectsContainers
        and #row.requiredTags==0 and #row.forbiddenTags==0
        and (not row.sourceRequiredTags or #row.sourceRequiredTags==0) and (not row.sourceForbiddenTags or #row.sourceForbiddenTags==0)
end
local function category(row,instance)
    if row.kind=='buff' then return row.category end
    if row.kind=='modifier' then return instance.Amount>=0 and 'buff' or 'debuff' end
    if row.kind=='heal' then return 'buff' end
    if row.kind=='damage' then return 'debuff' end
end
function Instructions.Remove(owner,target,row)
    local removed={};local debuffs=0
    for i=0,target.Effects.Count-1 do
        local instance=target.Effects:GetAt(i);local definition=owner:Definition(instance.EffectId)
        local match=owner.stats.buffs:Tagged(owner.stats.buffs:Find(instance.EffectId),row.removeTags)
        for _,kind in ipairs(row.removeCategories)do if category(definition,instance)==kind then match=true end end
        if match then
            removed[#removed+1]=instance.Id
            local kind=category(definition,instance);if kind=='debuff' or kind=='control' then debuffs=debuffs+1 end
        end
    end
    for _,id in ipairs(removed)do owner:Remove(target,id)end
    return #removed,debuffs
end
return Instructions
