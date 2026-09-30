-- Skills and external gameplay both use Prepare/Apply. All mutable instances live on C# actors.
local Effects={};Effects.__index=Effects
function Effects.New(stats,definitions,emit)
    return setmetatable({stats=stats,definitions=definitions,emit=emit},Effects)
end
function Effects:Validate()
    for _,row in ipairs(self.definitions:All()) do
        if row.duration~='instant' then
            assert(row.kind=='damage' or row.kind=='heal' or row.kind=='modifier','Only damage/heal/modifier can persist: '..row.id)
            assert(row.name~='' and row.description~='','Persistent effect needs display metadata: '..row.id)
            assert(row.duration=='infinite' or row.durationTurns>0,'Timed effect needs a duration: '..row.id)
            assert(row.kind=='modifier' and row.periodTurns==0 or row.kind~='modifier' and row.periodTurns>0,'Invalid effect period: '..row.id)
            assert(row.stacking~='stack' or row.maxStacks>1,'Stacking effect needs a stack limit: '..row.id)
        else assert(row.kind~='modifier','Attribute modifiers require duration or infinite lifetime: '..row.id) end
        if row.kind=='modifier' then
            local known=self.stats.growth.attributeByCode[row.attribute]~=nil
            for _,attributes in pairs(self.stats.attributes) do if attributes[row.attribute]~=nil then known=true;break end end
            assert(known,'Unknown effect attribute: '..row.attribute)
        end
    end
end
function Effects:Prepare(id,source,target,skill,distance)
    local row=self.definitions:Get(id)
    assert(row.kind=='damage' or row.kind=='heal' or row.kind=='guard' or row.kind=='reload' or row.kind=='modifier','Effect requires a movement/taming ability context: '..id)
    assert(row.kind~='reload' or skill~=nil,'Reload requires the equipment ability transaction')
    local values=self.stats:EffectVariables(source,target,skill)
    values.distance=distance or 0
    local amount=row.amount:Evaluate(values)
    assert(amount==math.floor(amount) and math.abs(amount)<=1000000 and (row.kind=='modifier' or amount>=0),'Invalid effect magnitude: '..id)
    if row.kind=='damage' and amount>0 and skill then amount=math.max(1,math.floor(amount*skill.damageScale)) end
    assert(math.abs(amount)<=1000000,'Scaled effect magnitude exceeds bounds: '..id)
    if row.kind=='modifier' then
        local old=row.stacking~='independent' and target.Effects:Find(row.id)
        self.stats:MaximumHP(target,{oldId=old and old.Id,attribute=row.attribute,amount=amount,stacks=old and row.stacking=='stack' and math.min(row.maxStacks,old.Stacks+1) or 1})
    end
    return {definition=row,source=source,sourceId=source.Id,sourceName=self.stats:Template(source).name,target=target,amount=amount,label=skill and skill.name or row.name,attackHit=skill~=nil and row.kind=='damage'}
end
function Effects:Notify(kind,message,sourceId,target,amount,attackHit,impact)
    self.emit(kind,message,sourceId,target.Id,amount,target,attackHit,impact)
end
function Effects:Execute(row,target,amount,sourceId,sourceName,label,source,attackHit,impact)
    local alive=target.HP>0
    if not alive then return end
    if row.kind=='damage' then
        local mount=target.MountedAnimal;amount=target:Damage(amount)
        impact={shot=impact and impact.shot or 1,critical=impact and impact.critical==true,
            defeated=target.HP==0 or (mount~=nil and target.MountedAnimal==nil)}
        if mount and not target.MountedAnimal then
            self:Clear(mount,'death');self:Notify('mount_defeated',self.stats:Template(mount).name..' 死亡，骑手下马',target.Id,mount,0)
        end
    elseif row.kind=='heal' then amount=target:Heal(amount)
    elseif row.kind=='guard' then target:SetGuard(amount)
    elseif row.kind=='reload' then
        amount=assert(self.stats.equipment:Loaded(self.stats.equipment:Weapon(assert(source))),'Reload has no loaded magazine').Rounds
    else error('Unsupported periodic execution: '..row.kind) end
    local verb=({damage='伤害',heal='治疗',guard='防御',reload='装入子弹'})[row.kind]
    self:Notify(row.kind,sourceName..' · '..(label~='' and label or verb)..' → '..self.stats:Template(target).name..'（'..verb..' '..amount..'）',sourceId,target,amount,attackHit,impact)
    if target.HP==0 then
        self:Notify('defeated',self.stats:Template(target).name..' 倒地',sourceId,target,0)
        self:Clear(target,'death')
    end
end
function Effects:ApplyPrepared(plan,impact)
    local row,target=plan.definition,plan.target
    if target.HP<=0 then return false,'目标已倒地' end
    if row.duration=='instant' then
        self:Execute(row,target,plan.amount,plan.sourceId,plan.sourceName,plan.label,plan.source,plan.attackHit,impact);return true
    end
    local duration=row.duration=='infinite' and -1 or row.durationTurns
    local old=row.stacking~='independent' and target.Effects:Find(row.id)
    if old then target.Effects:Refresh(old.Id,plan.sourceId,plan.sourceName,plan.amount,duration,row.maxStacks,row.stacking=='stack')
    else target.Effects:Add(row.id,plan.sourceId,plan.sourceName,plan.amount,duration) end
    if row.kind=='modifier' then target:SetMaxHP(self.stats:MaximumHP(target)) end
    self:Notify('effect_added',self.stats:Template(target).name..' 获得 '..row.name,plan.sourceId,target,plan.amount)
    return true
end
function Effects:Apply(id,source,target)
    return self:ApplyPrepared(self:Prepare(id,source,target))
end
function Effects:Remove(target,id)
    local instance
    for i=0,target.Effects.Count-1 do if target.Effects:GetAt(i).Id==id then instance=target.Effects:GetAt(i);break end end
    assert(instance,'Unknown active effect instance: '..id)
    local row=self.definitions:Get(instance.EffectId)
    target.Effects:Remove(id)
    if row.kind=='modifier' then target:SetMaxHP(self.stats:MaximumHP(target)) end
    self:Notify('effect_removed',self.stats:Template(target).name..' · '..row.name..' 结束',instance.SourceId,target,0)
end
function Effects:TickActor(target,phase)
    local mount=target.MountedAnimal
    if mount then
        self:Tick(mount,phase)
        if mount.HP==0 then target:DetachDefeatedMount();self:Notify('mount_defeated',self.stats:Template(mount).name..' 死亡，骑手下马',target.Id,mount,0) end
    end
    self:Tick(target,phase)
end
function Effects:Tick(target,phase)
    assert(phase=='turn_start' or phase=='turn_end','Unknown effect tick phase')
    -- Execute may remove several effects when the target dies. Iterate stable instance identities.
    local ids={};for i=0,target.Effects.Count-1 do ids[#ids+1]=target.Effects:GetAt(i).Id end
    for _,id in ipairs(ids) do
        local instance
        for i=0,target.Effects.Count-1 do if target.Effects:GetAt(i).Id==id then instance=target.Effects:GetAt(i);break end end
        if instance then
            local row=self.definitions:Get(instance.EffectId)
            if row.tickPhase==phase then
                target.Effects:Advance(id,row.periodTurns)
                if row.periodTurns>0 and instance.Elapsed==0 then
                    self:Execute(row,target,instance.Amount*instance.Stacks,instance.SourceId,instance.SourceName,row.name)
                end
                local present=false;for i=0,target.Effects.Count-1 do if target.Effects:GetAt(i).Id==id then present=true;break end end
                if present and instance.Remaining==0 then self:Remove(target,id) end
            end
        end
    end
end
function Effects:Clear(target,reason)
    assert(reason=='battle_end' or reason=='death','Unknown effect cleanup reason')
    for i=target.Effects.Count-1,0,-1 do
        local instance=target.Effects:GetAt(i);local row=self.definitions:Get(instance.EffectId)
        if reason=='battle_end' and row.removeOnBattleEnd or reason=='death' and row.removeOnDeath then self:Remove(target,instance.Id) end
    end
end
function Effects:Rows(target)
    local rows={}
    for i=0,target.Effects.Count-1 do
        local instance=target.Effects:GetAt(i);local row=self.definitions:Get(instance.EffectId)
        rows[#rows+1]={id=instance.Id,name=row.name,description=row.description,iconId=row.iconId,stacks=instance.Stacks,remaining=instance.Remaining,
            body=row.description..'\n来源：'..instance.SourceName..' · '..instance.Stacks..' 层 · '..(instance.Remaining<0 and '持续生效' or ('剩余 '..instance.Remaining..' 回合'))}
    end
    return rows
end
function Effects:ValidateSaved(target)
    for i=0,target.Effects.Count-1 do
        local instance=target.Effects:GetAt(i);local row=self.definitions:Get(instance.EffectId)
        assert(row.duration~='instant' and instance.Stacks<=row.maxStacks,'Saved effect differs from config')
        assert(row.duration=='infinite' and instance.Remaining==-1 or row.duration=='duration' and instance.Remaining>0 and instance.Remaining<=row.durationTurns,'Saved effect lifetime differs from config')
        assert(row.periodTurns==0 and instance.Elapsed==0 or row.periodTurns>0 and instance.Elapsed<row.periodTurns,'Saved effect period differs from config')
    end
end
return Effects
