-- Buff composition uses the existing effect executor; counters/snapshots stay on the actor's C# instances.
local Buffs={};Buffs.__index=Buffs
function Buffs.New(owner)return setmetatable({owner=owner,rules=owner.stats.buffs},Buffs)end
local function find(target,id)
    for i=0,target.Effects.Count-1 do local item=target.Effects:GetAt(i);if item.Id==id then return item end end
end
function Buffs:Prepare(effect,source,target,skill,distance)
    local row=self.rules:Get(effect.buffId);local ids,amounts,byId={},{},{}
    local values=require('Game.Battle.EffectInstructions').Values(self.owner.stats,source,target,skill,distance)
    for _,id in ipairs(row.componentIds)do
        local amount=self.owner:Magnitude(self.rules.effects:Get(id),values,skill)
        ids[#ids+1]=id;amounts[#amounts+1]=amount;byId[id]=amount
    end
    local actions={}
    for _,id in ipairs(row.onApplyEffectIds)do actions[#actions+1]=self.owner:Prepare(id,source,target,skill,distance)end
    local plan={definition=effect,buff=row,source=source,sourceId=source.Id,sourceName=self.owner.stats:Template(source).name,
        target=target,amount=0,ids=ids,amounts=amounts,byId=byId,actions=actions}
    self:Pending(plan);return plan
end
function Buffs:Pending(plan)
    local row,target=plan.buff,plan.target
    local removed={};local old=row.stacking~='independent' and target.Effects:Find(row.id)
    for i=0,target.Effects.Count-1 do local instance=target.Effects:GetAt(i)
        if self.rules:Tagged(self.rules:Find(instance.EffectId),row.removeTags)then removed[instance.Id]=true end
    end
    if old then removed[old.Id]=true end
    local stacks=old and row.stacking=='stack' and math.min(row.maxStacks,old.Stacks+1) or 1
    self.owner.stats:MaximumHP(target,{buff=row,amounts=plan.byId,stacks=stacks,removedIds=removed})
    return old,removed
end
function Buffs:Apply(plan,impact)
    local row,target=plan.buff,plan.target
    if self.rules:Blocked(target,row) then return true end
    -- Preparation validates the program; the persistent snapshot belongs to the successful application.
    local values=require('Game.Battle.EffectInstructions').Values(self.owner.stats,plan.source,target,plan.skill,plan.distance)
    for i,id in ipairs(row.componentIds)do
        local amount=self.owner:Magnitude(self.rules.effects:Get(id),values,plan.skill)
        plan.amounts[i]=amount;plan.byId[id]=amount
    end
    local old,removed=self:Pending(plan)
    for id in pairs(removed)do if not old or id~=old.Id then self.owner:Remove(target,id)end end
    local duration=row.clock=='turns' and row.durationTurns or -1
    local instance
    if old then target.Effects:Refresh(old.Id,plan.sourceId,plan.sourceName,0,duration,row.maxStacks,row.stacking=='stack');instance=old
    else instance=target.Effects:Add(row.id,plan.sourceId,plan.sourceName,0,duration)end
    local worldClock=row.clock=='minutes' or row.periodMinutes>0
    local now=worldClock and assert(self.owner.minutes,'Minute buffs need the world clock')() or 0
    CS.ProjectY.Data.GameBuffState.Configure(instance,plan.ids,plan.amounts,row.clock=='minutes' and now+row.durationMinutes or 0,
        worldClock and row.periodMinutes>0 and now+row.periodMinutes or 0)
    if #row.modifierEffectIds>0 then target:SetMaxHP(self.owner.stats:MaximumHP(target))end
    self.owner:Added(row,target,plan.sourceId,0,impact,instance.Stacks)
    for _,action in ipairs(plan.actions)do self.owner:ApplyPrepared(action,impact)end
    return true
end
function Buffs:Periodic(row,instance,target)
    for _,id in ipairs(row.periodicEffectIds)do
        if not find(target,instance.Id) or target.HP<=0 then return end
        self.owner:ApplyPrepared({definition=self.rules.effects:Get(id),target=target,amount=CS.ProjectY.Data.GameBuffState.Amount(instance,id)*instance.Stacks,
            sourceId=instance.SourceId,sourceName=instance.SourceName,label=row.name,attackHit=false},{damageColor=row.color},true)
    end
end
function Buffs:Tick(instance,target,phase)
    local row=self.rules:Get(instance.EffectId)
    if not (row.clock=='turns' or row.clock=='infinite' and row.periodTurns>0) or row.tickPhase~=phase then return end
    target.Effects:Advance(instance.Id,row.periodTurns)
    if row.periodTurns>0 and instance.Elapsed==0 then self:Periodic(row,instance,target)end
    if find(target,instance.Id) and instance.Remaining==0 then self.owner:Remove(target,instance.Id)end
end
function Buffs:TickWorld(target,now)
    if target.Effects.Count==0 then return false end
    local beforeHP,beforeRevision=target.HP,target.Effects.Revision
    local state=CS.ProjectY.Data.GameBuffState
    -- Catch up all statuses in chronological order; do not process a whole heal buff before a poison buff.
    while true do
        local selected,definition,when,isTick
        for i=0,target.Effects.Count-1 do local instance=target.Effects:GetAt(i);local row=self.rules:Find(instance.EffectId)
            if row and (row.clock=='minutes' or row.clock=='infinite' and row.periodMinutes>0) then
                local expiry=row.clock=='minutes' and state.ExpiresAt(instance) or math.huge;local tick=row.periodMinutes>0 and state.NextTickAt(instance)<=expiry
                local time=tick and state.NextTickAt(instance) or expiry
                if time<=now and (not selected or time<when or time==when and (tick and not isTick or tick==isTick and instance.Id<selected.Id)) then
                    selected,definition,when,isTick=instance,row,time,tick
                end
            end
        end
        if not selected then break end
        if isTick then state.AdvanceTick(selected,definition.periodMinutes);self:Periodic(definition,selected,target)
        else self.owner:Remove(target,selected.Id)end
    end
    return target.HP~=beforeHP or target.Effects.Revision~=beforeRevision
end
function Buffs:ValidateSaved(instance)
    local row=self.rules:Get(instance.EffectId);local state=CS.ProjectY.Data.GameBuffState
    assert(instance.Stacks<=row.maxStacks and instance.Stacks>=1,'Saved buff stacks differ from config')
    assert(state.Count(instance)==#row.componentIds,'Saved buff components differ from config')
    for i,id in ipairs(row.componentIds)do assert(state.EffectAt(instance,i-1)==id,'Saved buff component order differs from config')end
    if row.clock=='turns' or row.clock=='infinite' and row.periodTurns>0 then
        assert((row.clock=='infinite' and instance.Remaining==-1 or instance.Remaining>0 and instance.Remaining<=row.durationTurns) and state.ExpiresAt(instance)==0 and state.NextTickAt(instance)==0,'Invalid saved turn buff')
        assert(row.periodTurns==0 and instance.Elapsed==0 or row.periodTurns>0 and instance.Elapsed<row.periodTurns,'Invalid saved buff period')
    else
        assert(instance.Remaining==-1 and instance.Elapsed==0,'Invalid saved infinite/minute buff')
        if row.clock=='minutes' or row.periodMinutes>0 then
            assert(row.clock=='minutes' and state.ExpiresAt(instance)>0 or row.clock=='infinite' and state.ExpiresAt(instance)==0,'Invalid buff expiry')
            assert(row.periodMinutes==0 and state.NextTickAt(instance)==0 or row.periodMinutes>0 and state.NextTickAt(instance)>0 and (row.clock=='infinite' or state.NextTickAt(instance)<=state.ExpiresAt(instance)+row.periodMinutes),'Invalid buff minute period')
        else assert(state.ExpiresAt(instance)==0 and state.NextTickAt(instance)==0,'Infinite buff has a timer')end
    end
end
return Buffs
