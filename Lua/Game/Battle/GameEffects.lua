-- Skills and external gameplay both use Prepare/Apply. All mutable instances live on C# actors.
local Effects={};Effects.__index=Effects
local Instructions=require('Game.Battle.EffectInstructions')
function Effects.New(stats,definitions,emit,options)
    local self=setmetatable({stats=stats,definitions=definitions,emit=emit,roll=options and options.roll,minutes=options and options.minutes},Effects)
    self.buffEffects=require('Game.Battle.BuffEffects').New(self);return self
end
function Effects:Definition(id)return self.stats.buffs:Find(id) or self.definitions:Get(id)end
function Effects:Validate()
    for _,row in ipairs(self.definitions:All()) do
        assert(row.recipient=='target' or row.recipient=='source','Unknown effect recipient: '..row.id)
        for _,field in ipairs({'requiredTags','forbiddenTags','removeTags','removeCategories'})do
            local seen={};for _,value in ipairs(row[field])do assert(value~='' and not seen[value],'Empty/duplicate effect filter: '..row.id);seen[value]=true end
        end
        if row.kind=='remove_buffs' then assert(row.duration=='instant' and (#row.removeTags>0 or #row.removeCategories>0),'Dispel requires an instant filtered removal')
        else assert(#row.removeTags==0 and #row.removeCategories==0,'Only remove_buffs may specify removal filters')end
        if row.damageColor~='' then require('Config.Color').Normalize(row.damageColor) end
        if row.kind=='apply_buff' then assert(row.duration=='instant','Buff application must be an instant action');self.stats.buffs:Get(row.buffId)
        else assert(row.buffId==0,'Only apply_buff can reference a buff')end
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
function Effects:Magnitude(row,values,skill)
    local amount=row.amount:Evaluate(values)
    assert(amount==math.floor(amount) and math.abs(amount)<=1000000 and (row.kind=='modifier' or amount>=0),'Invalid effect magnitude: '..row.id)
    if row.kind=='damage' and amount>0 and skill then amount=math.max(1,math.floor(amount*skill.damageScale)) end
    assert(math.abs(amount)<=1000000,'Scaled effect magnitude exceeds bounds: '..row.id)
    return amount
end
function Effects:Prepare(id,source,target,skill,distance)
    local row=self.definitions:Get(id)
    local selected=target;target=row.recipient=='source' and source or target
    if row.kind=='apply_buff' then
        local plan=self.buffEffects:Prepare(row,source,target,skill,distance)
        plan.hitTarget=selected;plan.skill=skill;plan.distance=distance;return plan
    end
    assert(row.kind=='damage' or row.kind=='heal' or row.kind=='guard' or row.kind=='reload' or row.kind=='modifier' or row.kind=='remove_buffs','Effect requires a movement/taming ability context: '..id)
    assert(row.kind~='reload' or skill~=nil,'Reload requires the equipment ability transaction')
    local values=Instructions.Values(self.stats,source,selected,skill,distance)
    local amount=self:Magnitude(row,values,skill)
    if row.kind=='modifier' then
        local old=row.stacking~='independent' and target.Effects:Find(row.id)
        self.stats:MaximumHP(target,{oldId=old and old.Id,attribute=row.attribute,amount=amount,stacks=old and row.stacking=='stack' and math.min(row.maxStacks,old.Stacks+1) or 1})
    end
    return {definition=row,source=source,sourceId=source.Id,sourceName=self.stats:Template(source).name,target=target,hitTarget=selected,skill=skill,distance=distance,amount=amount,label=skill and skill.name or row.name,attackHit=skill~=nil and row.kind=='damage'}
end
function Effects:Notify(kind,message,sourceId,target,amount,attackHit,impact)
    self.emit(kind,message,sourceId,target.Id,amount,target,attackHit,impact)
end
function Effects:Execute(row,target,amount,sourceId,sourceName,label,source,attackHit,impact,periodic)
    local alive=target.HP>0
    if not alive then return end
    local incoming=impact;impact={}
    if incoming then for key,value in pairs(incoming) do impact[key]=value end end
    impact.hpBefore=target.HP;impact.periodic=periodic==true
    if row.kind=='damage' then
        local color=impact.damageColor or (row.damageColor~='' and row.damageColor) or (periodic and row.color) or ''
        impact.damageColor=color~='' and require('Config.Color').Normalize(color) or ''
        local mount=target.MountedAnimal;amount=target:Damage(amount)
        impact.shot=impact.shot or 1;impact.critical=impact.critical==true
        impact.defeated=target.HP==0 or (mount~=nil and target.MountedAnimal==nil)
        if not mount and amount>0 and row.equipmentDamage>0 then
            local wear=row.equipmentDamage+(target.HP==0 and row.killEquipmentDamage or 0)
            impact.equipmentDamage=CS.ProjectY.Data.EquipmentCombatState.DamageArmor(self.stats.equipment.data,target.Id,wear)
            CS.ProjectY.Data.EquipmentCombatState.RefreshMaximum(target,self.stats:MaximumHP(target))
        end
        if mount and not target.MountedAnimal then
            self:Clear(mount,'death');self:Notify('mount_defeated',self.stats:Template(mount).name..' 死亡，骑手下马',target.Id,mount,0)
        end
    elseif row.kind=='heal' then amount=target:Heal(amount)
    elseif row.kind=='guard' then target:SetGuard(amount)
    elseif row.kind=='remove_buffs' then amount=Instructions.Remove(self,target,row)
    elseif row.kind=='reload' then
        amount=assert(self.stats.equipment:Loaded(self.stats.equipment:Weapon(assert(source))),'Reload has no loaded magazine').Rounds
    else error('Unsupported periodic execution: '..row.kind) end
    impact.hpAfter=target.HP
    local verb=({damage='伤害',heal='治疗',guard='防御',reload='装入子弹',remove_buffs='清除状态'})[row.kind]
    self:Notify(row.kind,sourceName..' · '..(label~='' and label or verb)..' → '..self.stats:Template(target).name..'（'..verb..' '..amount..'）',sourceId,target,amount,attackHit,impact)
    if target.HP==0 then
        self:Notify('defeated',self.stats:Template(target).name..' 倒地',sourceId,target,0)
        self:Clear(target,'death')
    end
end
function Effects:ApplyPrepared(plan,impact,periodic)
    local row,target=plan.definition,plan.target
    if target.HP<=0 then return false,'目标已倒地' end
    if not Instructions.Allowed(self.stats.buffs,plan.hitTarget or target,row)then return true end
    if row.chance<100 then
        if row.chance<=0 or assert(self.roll,'Probabilistic effects need an explicit random stream')()>=row.chance then return true end
    end
    if row.kind=='apply_buff' then return self.buffEffects:Apply(plan,impact)end
    if row.duration=='instant' then
        local amount=plan.amount
        if not periodic and plan.source then amount=self:Magnitude(row,Instructions.Values(self.stats,plan.source,plan.hitTarget or target,plan.skill,plan.distance),plan.skill)end
        self:Execute(row,target,amount,plan.sourceId,plan.sourceName,plan.label,plan.source,plan.attackHit,impact,periodic);return true
    end
    local duration=row.duration=='infinite' and -1 or row.durationTurns
    local old=row.stacking~='independent' and target.Effects:Find(row.id)
    local instance
    if old then target.Effects:Refresh(old.Id,plan.sourceId,plan.sourceName,plan.amount,duration,row.maxStacks,row.stacking=='stack');instance=old
    else instance=target.Effects:Add(row.id,plan.sourceId,plan.sourceName,plan.amount,duration) end
    if row.kind=='modifier' then target:SetMaxHP(self.stats:MaximumHP(target)) end
    self:Added(row,target,plan.sourceId,plan.amount,impact,instance.Stacks)
    return true
end
function Effects:Added(row,target,sourceId,amount,impact,stacks)
    local details={effectId=row.id,statusName=row.name,color=require('Config.Color').Normalize(row.color),stacks=stacks,shot=impact and impact.shot or 1}
    self:Notify('effect_added',self.stats:Template(target).name..' 获得 '..row.name,sourceId,target,amount,false,details)
end
function Effects:Apply(id,source,target)
    return self:ApplyPrepared(self:Prepare(id,source,target))
end
function Effects:Remove(target,id)
    local instance
    for i=0,target.Effects.Count-1 do if target.Effects:GetAt(i).Id==id then instance=target.Effects:GetAt(i);break end end
    assert(instance,'Unknown active effect instance: '..id)
    local row=self:Definition(instance.EffectId)
    target.Effects:Remove(id)
    if row.kind=='modifier' or row.kind=='buff' and #row.modifierEffectIds>0 then target:SetMaxHP(self.stats:MaximumHP(target)) end
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
            local row=self:Definition(instance.EffectId)
            if row.kind=='buff' then self.buffEffects:Tick(instance,target,phase)
            elseif row.tickPhase==phase then
                target.Effects:Advance(id,row.periodTurns)
                if row.periodTurns>0 and instance.Elapsed==0 then
                    self:Execute(row,target,instance.Amount*instance.Stacks,instance.SourceId,instance.SourceName,row.name,nil,false,nil,true)
                end
                local present=false;for i=0,target.Effects.Count-1 do if target.Effects:GetAt(i).Id==id then present=true;break end end
                if present and instance.Remaining==0 then self:Remove(target,id) end
            end
        end
    end
end
function Effects:TickWorldActor(target,now)
    local mount=target.MountedAnimal;local changed=false
    if mount then
        changed=self.buffEffects:TickWorld(mount,now)
        if mount.HP==0 then target:DetachDefeatedMount();self:Notify('mount_defeated',self.stats:Template(mount).name..' 死亡，骑手下马',target.Id,mount,0)end
    end
    return self.buffEffects:TickWorld(target,now) or changed
end
function Effects:Clear(target,reason)
    assert(reason=='battle_end' or reason=='death','Unknown effect cleanup reason')
    for i=target.Effects.Count-1,0,-1 do
        local instance=target.Effects:GetAt(i);local row=self:Definition(instance.EffectId)
        if reason=='battle_end' and row.removeOnBattleEnd or reason=='death' and row.removeOnDeath then self:Remove(target,instance.Id) end
    end
end
function Effects:Rows(target)
    local rows={}
    for i=0,target.Effects.Count-1 do
        local instance=target.Effects:GetAt(i);local row=self:Definition(instance.EffectId)
        local remaining=instance.Remaining;local unit='回合';local timer=remaining<0 and '∞' or tostring(remaining)
        if row.clock=='minutes' then remaining=math.max(0,math.ceil(CS.ProjectY.Data.GameBuffState.ExpiresAt(instance)-assert(self.minutes)()));unit='分钟';timer=remaining..'m' end
        rows[#rows+1]={id=instance.Id,name=row.name,description=row.description,iconId=row.iconId,color=row.color,stacks=instance.Stacks,remaining=remaining,timerText=timer,
            body=row.description..'\n来源：'..instance.SourceName..' · '..instance.Stacks..' 层 · '..(remaining<0 and '持续生效' or ('剩余 '..remaining..' '..unit))}
    end
    return rows
end
function Effects:ValidateSaved(target)
    for i=0,target.Effects.Count-1 do
        local instance=target.Effects:GetAt(i);local row=self:Definition(instance.EffectId)
        if row.kind=='buff' then self.buffEffects:ValidateSaved(instance)
        else
        local snapshot=CS.ProjectY.Data.GameBuffState
        assert(snapshot.Count(instance)==0 and snapshot.ExpiresAt(instance)==0 and snapshot.NextTickAt(instance)==0,'Legacy effects cannot contain composite buff state')
        assert(row.duration~='instant' and instance.Stacks<=row.maxStacks,'Saved effect differs from config')
        assert(row.duration=='infinite' and instance.Remaining==-1 or row.duration=='duration' and instance.Remaining>0 and instance.Remaining<=row.durationTurns,'Saved effect lifetime differs from config')
        assert(row.periodTurns==0 and instance.Elapsed==0 or row.periodTurns>0 and instance.Elapsed<row.periodTurns,'Saved effect period differs from config')
        end
    end
end
return Effects
