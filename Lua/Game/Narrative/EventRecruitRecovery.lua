-- Initial wounds belong to BodyHealth. Recruitment only starts recovery of their remaining damage.
local Recovery={}
function Recovery.Prepare(adventure,npcId,actor)
    local row=assert(adventure.specialEvents.byNpc[npcId],'Event recruit has no special-event definition')
    assert(#row.initialInjuryPartIds==#row.initialInjuryTypeIds and #row.initialInjuryPartIds==#row.initialInjuryDamage and
        #row.initialInjuryPartIds==#row.injuryRecoveryMinutes,'Initial injury arrays differ')
    local state=CS.ProjectY.Data.BodyHealth
    local plans,seen={},{}
    for i,id in ipairs(row.initialInjuryPartIds) do
        local part=adventure.config:GetTable('BodyPartTable'):Get(id).index
        adventure.config:GetTable('InjuryTypeTable'):Get(row.initialInjuryTypeIds[i])
        local damage,minutes=row.initialInjuryDamage[i],row.injuryRecoveryMinutes[i]
        assert(not seen[part] and damage>=1 and damage<100 and minutes>=1,'Invalid initial injury recovery');seen[part]=true
        assert(state.RecoveryAmount(actor,part)==0,'Initial injury recovery is already scheduled')
        local amount=math.min(damage,state.Damage(actor,part))
        if amount>0 and not state.Permanent(actor,part) then plans[#plans+1]={part=part,amount=amount,minutes=minutes} end
    end
    return plans
end
function Recovery.Apply(adventure,actor,plans)
    assert(actor.Team==1 and actor.Growth.Initialized,'Injury recovery requires a joined party actor')
    local now=adventure.data.Narrative.Minutes
    for _,plan in ipairs(plans) do
        CS.ProjectY.Data.BodyHealth.ScheduleRecovery(actor,plan.part,plan.amount,now+plan.minutes)
    end
end
return Recovery
