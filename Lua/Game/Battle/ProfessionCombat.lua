-- Configuration-driven profession actions. Mutable encounter counters live in ProfessionCombatState.
local Hex=require('Game.Map.HexGrid')
local L=require('Language')
local Rules={};Rules.__index=Rules
local function state()return CS.ProjectY.Data.ProfessionCombatState end
local function copy(value)local result={};for k,v in pairs(value)do result[k]=v end;return result end
local function exists(actor,id)
    for i=0,actor.Effects.Count-1 do if actor.Effects:GetAt(i).Id==id then return true end end
    return false
end
function Rules.New(config,battle)
    local self=setmetatable({battle=battle,rows=config:GetTable('ProfessionCombatTable'),statuses=config:GetTable('ProfessionStatusTable'),byMechanic={}},Rules)
    for _,row in ipairs(self.statuses:All())do
        assert(not self.byMechanic[row.mechanic],'Duplicate profession status mechanic')
        self.byMechanic[row.mechanic]=row
        local effect=battle.effects:Get(row.applyEffectId)
        assert(effect.kind=='apply_buff' and effect.buffId==row.id,'Profession status needs its application action')
    end
    for _,row in ipairs(self.rows:All())do
        battle.skills:Get(row.id)
        assert(row.materialId==0 and row.materialCount==0 or row.materialId>0 and row.materialCount>0,'Invalid profession material transaction')
        if row.materialId>0 then battle.stats.equipment.items:Get(row.materialId)end
        if row.applyEffectId>0 then battle.effects:Get(row.applyEffectId)end
        if row.baseSkillId>0 then battle.skills:Get(row.baseSkillId)end
    end
    return self
end
function Rules:HasPassive(actor,kind)
    local growth=self.battle.stats.growth
    for i=0,actor.Growth.TalentCount-1 do
        local node=growth.nodes:Get(actor.Growth:GetTalentAt(i))
        if actor.Growth:GetRank(node.id)>0 and growth.passives:Get(node.passiveId).triggerKind==kind then return true end
    end
    return false
end
function Rules:Status(actor,mechanic)
    local row=self.byMechanic[mechanic]
    return row and actor.Effects:Find(row.id),row
end
function Rules:Tagged(actor,tag)
    local found={}
    for i=0,actor.Effects.Count-1 do
        local item=actor.Effects:GetAt(i);local row=self.battle.gameEffects:Definition(item.EffectId)
        if self.battle.stats.buffs:Tagged(self.battle.stats.buffs:Find(item.EffectId),{tag}) or tag=='weakness' and row.kind=='modifier' and row.attribute=='strength' and item.Amount<0 then found[#found+1]=item end
    end
    return found
end
function Rules:HasDebuff(actor)
    for i=0,actor.Effects.Count-1 do
        local item=actor.Effects:GetAt(i);local row=self.battle.gameEffects:Definition(item.EffectId)
        if row.category=='debuff' or row.category=='control' or row.kind=='modifier' and item.Amount<0 or row.kind=='damage' then return true end
    end
    return false
end
function Rules:ApplyStatus(source,target,mechanic,nextEnd)
    local row=assert(self.byMechanic[mechanic],'Missing profession status: '..mechanic)
    self.battle.gameEffects:Apply(row.applyEffectId,source,target)
    local instance=target.Effects:Find(row.id)
    if instance and nextEnd then
        local duration=self.battle.data.Phase=='combat' and self.battle.data.ActiveId==target.Id and 2 or 1
        state().SetLifetime(instance,duration)
    end
    return instance
end
function Rules:RemoveInstances(actor,instances)
    local count=0
    for _,item in ipairs(instances)do if exists(actor,item.Id)then self.battle.gameEffects:Remove(actor,item.Id);count=count+1 end end
    return count
end
function Rules:AddSkills(actor,ids)
    local known={};for _,id in ipairs(ids)do known[id]=true end
    for _,row in ipairs(self.rows:All())do
        if row.baseSkillId>0 and known[row.baseSkillId] and not known[row.id]then ids[#ids+1]=row.id;known[row.id]=true end
    end
    return ids
end
function Rules:Skill(actor,skill)
    if skill.skillKind=='item' then return skill end
    local row=self.rows:Find(skill.id);local discount=0;skill.professionDiscounts={}
    if row and (skill.skillGroup=='weapon' or skill.skillGroup=='slash')then
        local kind=row.requiredEquipment=='shield' and 'weapon' or row.requiredEquipment
        local weapon=self:RequiredWeapon(actor,kind,skill)
        if weapon then
            local equipment=self.battle.stats.equipment;local definition=equipment.weapons:Get(weapon.ItemId)
            local main=equipment:Weapon(actor)
            if not main or main.Id~=weapon.Id then
                skill=self.battle.stats.buffs:ApplySkillModifiers(actor,equipment:PreviewWeapon(weapon):Skill(actor,skill.id,self.battle.stats))
                skill.professionDiscounts={}
                local motion=equipment:MotionModule(actor);if motion.offActionId>0 then skill.actionTemplate=motion.offActionId end
            end
            skill.professionWeaponId=weapon.Id
            local granted=false;for _,id in ipairs(definition.skillIds)do if id==skill.id then granted=true end end
            if not granted then
                local requirements=equipment:Requirements(actor,weapon,self.battle.stats)
                skill.damageScale=skill.damageScale*definition.damageMultiplier*requirements.damageScale*equipment:Condition(weapon).Efficiency
                skill.hitChance=math.max(0,skill.hitChance-requirements.hitLoss)
            end
            equipment:ApplyArmorProfile(skill,weapon)
        end
    end
    for _,kind in ipairs({'encore_discount','draw_discount','recycle_discount'})do
        local instance,status=self:Status(actor,kind)
        local applies=kind=='encore_discount' or row and (kind=='draw_discount' and row.family=='curse' or kind=='recycle_discount' and row.family=='potion')
        if instance and applies then discount=discount+status.amount;skill.professionDiscounts[#skill.professionDiscounts+1]=instance.Id end
    end
    if discount>0 then skill.cost=math.max(1,skill.cost-discount)end
    return skill
end
function Rules:Budget(source,skill)
    local row=self.rows:Find(skill.id)
    if row and row.requiredEquipment and row.requiredEquipment~='' then
        local allowed
        if row.requiredEquipment=='shield' then
            local shield=self.battle.stats.equipment.data:Worn(source.Id,'offhand')
            allowed=shield~=nil and CS.ProjectY.Data.EquipmentConditionData.Of(shield).Current>0
        else allowed=self:RequiredWeapon(source,row.requiredEquipment,skill)~=nil end
        if not allowed then return false,L.ProfessionEquipmentRequired end
    end
    if row and row.materialId>0 and (source.Team~=1 or self.battle.stats.equipment.data:CountItem(row.materialId)<row.materialCount) then
        return false,string.format(L.ProfessionNeedMaterial,self.battle.stats.equipment.items:Get(row.materialId).name,row.materialCount)
    end
    return true
end
function Rules:RequiredWeapon(actor,kind,skill)
    local equipment=self.battle.stats.equipment
    for _,hand in ipairs({'Weapon','Offhand'})do
        local weapon=equipment[hand](equipment,actor)
        if equipment:Usable(weapon)then
            local definition=equipment.weapons:Get(weapon.ItemId)
            local eligible=kind=='weapon' or definition.kind==kind or kind=='melee' and (definition.kind=='spear' or definition.kind=='staff')
            if eligible and definition.kind=='spear' and equipment.skills:Get(skill.id).range<=1 then
                local minimum=0
                for _,id in ipairs(definition.skillIds)do local granted=equipment.skills:Get(id)
                    if granted.target=='enemy' and (granted.skillGroup=='weapon' or granted.skillGroup=='slash')then minimum=math.max(minimum,granted.minRange)end
                end
                eligible=minimum<=1
            end
            if eligible then return weapon end
        end
    end
end
function Rules:ConsumeEquipment(source,skill)
    local equipment=self.battle.stats.equipment
    local main=equipment:Weapon(source)
    if skill.professionWeaponId and (not main or main.Id~=skill.professionWeaponId)then
        local action=copy(skill);action.weaponWear=0;equipment:Consume(source,action)
        if skill.weaponWear>0 then CS.ProjectY.Data.EquipmentCombatState.DamageWeapon(equipment.data,skill.professionWeaponId,skill.weaponWear*skill.shots)end
    else equipment:Consume(source,skill)end
end
function Rules:Commit(source,skill)
    local row=self.rows:Find(skill.id)
    if row and row.materialId>0 then self.battle.stats.equipment.data:ConsumeStack(row.materialId,row.materialCount)end
    for _,id in ipairs(skill.professionDiscounts or {})do if exists(source,id)then self.battle.gameEffects:Remove(source,id)end end
end
function Rules:BlockedTransfer(target,instance)
    local row=self.battle.gameEffects:Definition(instance.EffectId)
    if row.kind=='buff' then
        if self.battle.stats.buffs:Blocked(target,row)then return true end
        for _,tag in ipairs(row.tags)do if self.battle.stats.growth:Immunity(target,tag)then return true end end
    elseif row.kind=='modifier' and row.attribute=='strength' and instance.Amount<0 then
        return self.battle.stats.growth:Immunity(target,'weakness')~=nil
    end
    return false
end
function Rules:CanUse(source,skill,target)
    local row=self.rows:Find(skill.id);if not row then return true end
    if row.mechanic=='encore' then
        if not self:Status(target,'resonance')then return false,L.ProfessionNeedsResonance end
        if state().Mark(target,'encore_round')==self.battle.data.Round then return false,L.ProfessionEncoreUsed end
    elseif row.mechanic=='transfer' then
        local item=self:Tagged(source,row.statusTag)[1]
        if not item then return false,L.ProfessionMissingStatus end
        if self:BlockedTransfer(target,item)then return false,L.ProfessionTransferImmune end
        assert(target.Effects.Count<256 or target.Effects:Find(item.EffectId),'Target has reached the effect capacity')
    elseif row.mechanic=='swap' then
        if source==target or self.battle.stats.buffs:Skipping(target) or not self:CanSwap(source,target)then return false,L.ProfessionCannotSwap end
    elseif row.mechanic=='interpose' and source==target then return false,L.ProfessionChooseOtherAlly end
    if row.mechanic=='retreat' and #self:LandingCells(source,skill,target)==0 then return false,L.ProfessionNoLanding end
    return true
end
function Rules:PrepareProgram(source,skill,target,program)
    if #program==0 and self.rows:Find(skill.id)then
        program[1]={definition={kind='profession',duration='instant'},source=source,target=target,hitTarget=target,skill=skill}
    end
end
function Rules:BeginTurn(actor)
    if self.battle.data.Phase~='combat' then return end
    self:ClearInterpose(actor)
    local guard,row=self:Status(actor,'guard_floor');if guard then actor:SetGuard(row.amount)end
    if self:HasPassive(actor,'suffering') and (#self:Tagged(actor,'poison')>0 or #self:Tagged(actor,'bleeding')>0 or #self:Tagged(actor,'weakness')>0)then
        local instance=self:ApplyStatus(actor,actor,'suffering');if instance then state().SetLifetime(instance,1)end
    end
end
function Rules:ClearInterpose(actor)
    for _,target in ipairs(self.battle:Units())do
        local oath=self:Status(target,'interpose')
        if oath and oath.SourceId==actor.Id then self.battle.gameEffects:Remove(target,oath.Id)end
    end
end
function Rules:OnDefeated(actor)self:ClearInterpose(actor)end
function Rules:OnCleansed(source,target,count)
    if source==target and count>0 and self.battle.data.Phase=='combat' and self:HasPassive(source,'grace') and state().Once(source,'grace_round',self.battle.data.Round)then source:SetGuard(4)end
end
function Rules:Redirect(source,skill,target)
    if skill.maxTargets~=1 or skill.target~='enemy' then return target end
    local direct=false;for _,id in ipairs(skill.effectIds)do local row=self.battle.effects:Get(id);if row.kind=='damage' and row.duration=='instant' then direct=true end end
    if not direct then return target end
    local oath=self:Status(target,'interpose');if not oath then return target end
    local guardian=self.battle:FindUnit(oath.SourceId)
    if guardian and guardian.HP>0 and guardian~=source and self.battle:IsAllied(guardian,target) and self.battle.stats.animals:Distance(guardian,target,self.battle.board)==1 then
        self.battle.gameEffects:Remove(target,oath.Id)
        self.battle:Emit('profession',string.format(L.ProfessionInterpose,self.battle.stats:Template(guardian).name,self.battle.stats:Template(target).name),guardian.Id,target.Id)
        return guardian
    end
    return target
end
function Rules:BeforeHit(source,skill,target)
    local row=self.rows:Find(skill.id)
    local context={source=source,target=target,skill=skill,row=row,hadDebuff=self:HasDebuff(target),bonus=0,consume={},sourceConsume={}}
    local direct=false;for _,id in ipairs(skill.effectIds)do local effect=self.battle.effects:Get(id);if effect.kind=='damage' and effect.recipient=='target' and effect.duration=='instant' then direct=true end end
    context.weapon=direct and (skill.skillGroup=='weapon' or skill.skillGroup=='slash')
    context.exposed=self:Status(target,'exposed')
    if context.weapon then
        local opening=self:Status(source,'opening')
        if opening then
            self:ApplyStatus(source,target,'exposed');context.exposed=self:Status(target,'exposed')
            context.opening=opening
        end
        context.preserveArmor=context.exposed~=nil and self:HasPassive(source,'mercy')
        if context.exposed then context.defenseReduction=assert(self.byMechanic.exposed).amount end
        for _,kind in ipairs({'coating_water','coating_poison','enchant_fire','enchant_water'})do
            local item,status=self:Status(source,kind)
            local melee=skill.range<=1 or self.battle.stats.animals:Distance(source,target,self.battle.board)==1 and skill.proficiency~='bow' and skill.proficiency~='firearm'
            if item and (kind:sub(1,7)=='coating' or melee)then
                context.coatings=context.coatings or {};context.coatings[#context.coatings+1]={instance=item,status=status}
                if kind=='enchant_fire' then context.damageType='fire' elseif kind=='enchant_water' then context.damageType='water' end
            end
        end
    end
    context.curse=self:Status(target,'curse_mark')
    if row then
        if row.mechanic=='distill' or row.mechanic=='consume_damage' then
            context.consume=self:Tagged(target,row.statusTag)
            if #context.consume>0 then
                context.bonus=row.bonusDamage
                if row.mechanic=='distill' and row.statusTag=='poison' then
                    local stacks=0;for _,item in ipairs(context.consume)do stacks=stacks+item.Stacks end
                    context.bonus=math.min(9,stacks*row.bonusDamage)
                end
            end
        elseif row.mechanic=='judgement' then
            context.sourceConsume=self:Tagged(source,row.statusTag)
            if #context.sourceConsume>0 then context.bonus=row.bonusDamage end
        elseif row.mechanic=='finisher' and context.exposed then context.bonus=row.bonusDamage end
    end
    return context
end
function Rules:Damage(context,plan,amount,values)
    local damageType=context.damageType or plan.definition.damageType or 'physical'
    local immune=self.battle.stats.growth:Immunity(context.target,'damage_'..damageType)
    if context.damageResolved then return immune and 0 or amount end
    context.damageResolved=true
    local base=amount;local improved=amount
    if context.defenseReduction then
        local adjusted=setmetatable(copy(values),{__index=values});adjusted.defense=math.max(0,values.defense-context.defenseReduction)
        improved=self.battle.gameEffects:Magnitude(plan.definition,adjusted,plan.skill)
    end
    local fixed=math.max(0,context.bonus-math.max(0,values.defense-(context.defenseReduction or 0))-values.guard)
    local extra=fixed+math.max(0,improved-base)
    if context.curse then extra=extra+math.min(math.floor(base*self.byMechanic.curse_mark.amount/100),math.floor(context.target.MaxHP*.1))end
    amount=base+math.min(math.floor(base*.5),extra)
    if immune then amount=0 end
    return amount
end
function Rules:Mitigate(target,amount,impact)
    local ward,status=self:Status(target,'ward')
    if ward then amount=math.max(0,amount-status.amount);self.battle.gameEffects:Remove(target,ward.Id)end
    return amount
end
function Rules:AfterHit(context)
    local source,target,skill,row=context.source,context.target,context.skill,context.row
    if context.damageResolved then
        if context.weapon then
            if context.exposed then self:RemoveInstances(target,{context.exposed})end
            if context.opening then self:RemoveInstances(source,{context.opening})end
            for _,coating in ipairs(context.coatings or {})do
                self:RemoveInstances(source,{coating.instance})
                if source.HP>0 and target.HP>0 then self.battle.gameEffects:Apply(coating.status.amount,source,target)end
            end
        end
        if context.curse then self:RemoveInstances(target,{context.curse})end
        self:RemoveInstances(target,context.consume)
        local cleared=self:RemoveInstances(source,context.sourceConsume);self:OnCleansed(source,source,cleared)
        if source.HP>0 and row and row.mechanic=='distill' and #context.consume>0 and self.battle:IsHostile(source,target) and self.battle.data.Phase=='combat'
            and self:HasPassive(source,'recycle') and state().Once(source,'recycle_encounter',1)then self:ApplyStatus(source,source,'recycle_discount')end
    end
    if row and source.HP>0 then
        local mechanic=row.mechanic
        if mechanic=='coat' or mechanic=='opening' or mechanic=='draw_mark' then
            if mechanic=='coat' then self:RemoveInstances(source,self:Tagged(source,'coating'))end
            self.battle.gameEffects:Apply(row.applyEffectId,source,source)
        elseif mechanic=='enchant' then
            self:RemoveInstances(source,self:Tagged(source,'enchantment'))
            self.battle.gameEffects:Apply(row.applyEffectId,source,source)
            local buff=self.battle.effects:Get(row.applyEffectId).buffId
            local item=source.Effects:Find(buff);if item then state().SetLifetime(item,2)end
        elseif mechanic=='beat' then
            if row.statusTag=='' then local item=self:ApplyStatus(source,target,'resonance');if item then state().SetLifetime(item,1)end
            else
                local resonance=self:Status(source,'resonance')
                if resonance then self:RemoveInstances(source,{resonance});if target.HP>0 then self.battle.gameEffects:Apply(row.applyEffectId,source,target)end end
            end
        elseif mechanic=='ward' then self:ApplyStatus(source,target,'ward',true)
        elseif mechanic=='encore' then
            self:RemoveInstances(target,{assert(self:Status(target,'resonance'))})
            self:ApplyStatus(source,target,'encore_discount',true);state().SetMark(target,'encore_round',self.battle.data.Round)
        elseif mechanic=='cleanse_guard' then
            local cleared=self:RemoveInstances(source,self:Tagged(source,'poison'))+self:RemoveInstances(source,self:Tagged(source,'bleeding'))
            self:ApplyStatus(source,source,'guard_floor');source:SetGuard(self.byMechanic.guard_floor.amount);self:OnCleansed(source,source,cleared)
        elseif mechanic=='curse_mark' or mechanic=='feint' or mechanic=='splash' then
            if target.HP>0 and row.applyEffectId>0 then self.battle.gameEffects:Apply(row.applyEffectId,source,target)end
        elseif mechanic=='discord' then
            local resonance=self:Status(source,'resonance')
            if resonance then self:RemoveInstances(source,{resonance});if target.HP>0 then self:ApplyStatus(source,target,'exposed')end end
        elseif mechanic=='transfer' and target.HP>0 then
            local instance=self:Tagged(source,row.statusTag)[1]
            if instance and not self:BlockedTransfer(target,instance)then
                local definition=self.battle.gameEffects:Definition(instance.EffectId)
                local transferred=state().Transfer(source.Effects,target.Effects,instance.Id,definition.maxStacks)
                source:SetMaxHP(self.battle.stats:MaximumHP(source));target:SetMaxHP(self.battle.stats:MaximumHP(target))
                self.battle.gameEffects:Added(definition,target,source.Id,0,nil,transferred.Stacks)
                self:OnCleansed(source,source,1)
            end
        elseif mechanic=='push' or mechanic=='pull' then
            local cell=target.HP>0 and self:ForcedLanding(source,target,mechanic)
            if cell then self:Move(target,cell)end
        elseif mechanic=='swap' then
            local q,r=source.Q,source.R
            state().Move(source,target.Q,target.R);state().Move(target,q,r)
            self:OnMoved(source);self:OnMoved(target)
        elseif mechanic=='interpose' then self:ApplyStatus(source,target,'interpose')end
    end
    if source.HP>0 and skill.action=='main' and not skill.professionReaction and context.hadDebuff and self.battle:IsHostile(source,target) and self.battle.data.Phase=='combat'
        and self:HasPassive(source,'reply') and state().Once(source,'reply_round',self.battle.data.Round)then self:ApplyStatus(source,source,'resonance',true)end
end
function Rules:CanStep(actor,cell,occupied,forced)
    if not cell or not forced and self.battle.stats.buffs:Skipping(actor)then return false end
    local origin=assert(self.battle.board:Find(actor.Q,actor.R));local connected=false
    for _,neighbor in ipairs(self.battle.board:Neighbors(origin))do if neighbor==cell then connected=true end end
    return connected and self.battle.stats.animals:CanPlace(actor,self.battle.board,cell.q,cell.r,occupied,actor.Team==1 and self.battle.board.allowed or nil)
end
function Rules:LandingCells(source,skill,target)
    local result={};local occupied=self.battle:Occupied(source.Id);local original=self.battle.stats.animals:Distance(source,target,self.battle.board)
    local targetCells=assert(self.battle.stats.animals:Cells(target,self.battle.board))
    for _,cell in ipairs(self.battle.board:Neighbors(assert(self.battle.board:Find(source.Q,source.R))))do
        if self:CanStep(source,cell,occupied)then
            local distance=math.huge
            for _,part in ipairs(assert(self.battle.stats.animals:Cells(source,self.battle.board,cell.q,cell.r)))do
                for _,other in ipairs(targetCells)do distance=math.min(distance,Hex.Distance(part.q,part.r,other.q,other.r))end
            end
            if distance>original then result[#result+1]=cell end
        end
    end
    return result
end
function Rules:ForcedLanding(source,target,kind)
    local sourceCells=self.battle.stats.animals:Cells(source,self.battle.board)
    local targetCells=self.battle.stats.animals:Cells(target,self.battle.board)
    if #targetCells>#sourceCells then return nil end
    local original=Hex.Distance(source.Q,source.R,target.Q,target.R);local occupied=self.battle:Occupied(target.Id)
    local candidates={}
    for _,cell in ipairs(self.battle.board:Neighbors(assert(self.battle.board:Find(target.Q,target.R))))do
        local distance=Hex.Distance(source.Q,source.R,cell.q,cell.r)
        if (kind=='push' and distance>original or kind=='pull' and distance<original) and self:CanStep(target,cell,occupied,true)then candidates[#candidates+1]=cell end
    end
    table.sort(candidates,function(a,b)
        local aq,ar=a.q-target.Q,a.r-target.R;local bq,br=b.q-target.Q,b.r-target.R
        local dq,dr=target.Q-source.Q,target.R-source.R
        local ad=aq*dq+ar*dr+(aq+ar)*(dq+dr);local bd=bq*dq+br*dr+(bq+br)*(dq+dr)
        if ad==bd then return a.q==b.q and a.r<b.r or a.q<b.q end
        return kind=='push' and ad>bd or kind=='pull' and ad<bd
    end)
    return candidates[1]
end
function Rules:CanSwap(source,target)
    local occupied=self.battle:Occupied(source.Id)
    for key,actor in pairs(occupied)do if actor==target then occupied[key]=nil end end
    if not self:CanStep(source,self.battle.board:Find(target.Q,target.R),occupied) or not self:CanStep(target,self.battle.board:Find(source.Q,source.R),occupied)then return false end
    local used={}
    for _,cell in ipairs(self.battle.stats.animals:Cells(source,self.battle.board,target.Q,target.R))do used[Hex.Key(cell.q,cell.r)]=true end
    for _,cell in ipairs(self.battle.stats.animals:Cells(target,self.battle.board,source.Q,source.R))do if used[Hex.Key(cell.q,cell.r)]then return false end end
    return true
end
function Rules:Move(actor,cell)
    state().Move(actor,cell.q,cell.r);self:OnMoved(actor)
    self.battle:Emit('moved',string.format(L.ProfessionSkillMove,self.battle.stats:Template(actor).name),actor.Id)
end
function Rules:OnMoved(actor)
    for _,cell in ipairs(self.battle.stats.animals:Cells(actor,self.battle.board))do
        local trap=state().Trap(self.battle.data,cell.q,cell.r)
        if trap then
            state().RemoveTrap(self.battle.data,cell.q,cell.r);state().StopMovement(actor)
            local source=assert(self.battle:FindUnit(trap.SourceId),'Trap owner missing from encounter')
            self.battle.gameEffects:Apply(trap.EffectId,source,actor)
            self.battle:Emit('profession',string.format(L.ProfessionTrapTriggered,self.battle.stats:Template(actor).name),source.Id,actor.Id)
            return true
        end
    end
    return false
end
function Rules:TrapOnPath(actor,cell,previous,distance)
    local path={};local step=cell
    while previous[step]do table.insert(path,1,step);step=previous[step]end
    for _,point in ipairs(path)do
        for _,part in ipairs(self.battle.stats.animals:Cells(actor,self.battle.board,point.q,point.r))do
            if state().Trap(self.battle.data,part.q,part.r)then return point,distance[point]end
        end
    end
    return cell,distance[cell]
end
function Rules:CanUseAt(source,skill,cell)
    local row=self.rows:Find(skill.id)
    if not row or row.mechanic~='trap' and row.mechanic~='salvage' then return nil end
    if Hex.Distance(source.Q,source.R,cell.q,cell.r)>skill.range then return false,L.ProfessionOutsideRange end
    local visible=(not self.battle.board.allowed or source.Team~=1 or self.battle.board.allowed(cell))
        and require('Game.Battle.SkillTrajectory').CanReach(self.battle.board,self.battle.board:Find(source.Q,source.R),cell,'sight')
    if not visible then return false,row.mechanic=='salvage' and L.ProfessionInvalidSalvage or L.ProfessionInvalidTrapCell end
    if row.mechanic=='salvage' then return self:CanSalvage(source,cell)end
    if cell.blocked or (cell.layer or 0)~=0 or self.battle:Occupied()[Hex.Key(cell.q,cell.r)] or state().Trap(self.battle.data,cell.q,cell.r)then return false,L.ProfessionInvalidTrapCell end
    if cell.kind and cell.kind~='floor' and cell.kind~='grass' and cell.kind~='dirt'then return false,L.ProfessionInvalidTrapCell end
    return true
end
function Rules:UseAt(source,skill,cell)
    local row=self.rows:Get(skill.id)
    self:Commit(source,skill);source:SpendAction(skill.action,skill.cost);source:SetCooldown(skill.id,skill.cooldownTurns)
    source:RecordAction(skill.actionTemplate,1,cell.q,cell.r)
    if row.mechanic=='trap' then state().PlaceTrap(self.battle.data,cell.q,cell.r,source.Id,row.applyEffectId)
    else self:Salvage(source,cell)end
    self.battle:Emit('profession',string.format(L.ProfessionSkillUsed,self.battle.stats:Template(source).name,skill.name),source.Id)
    return true
end
function Rules:TrapRows()
    local result={}
    for i=0,state().TrapCount(self.battle.data)-1 do local row=state().TrapAt(self.battle.data,i);result[#result+1]={q=row.Q,r=row.R,name=L.ProfessionTripwireName,sourceId=row.SourceId}end
    return result
end
function Rules:Finish()
    while state().TrapCount(self.battle.data)>0 do
        local trap=state().TrapAt(self.battle.data,0);state().RemoveTrap(self.battle.data,trap.Q,trap.R)
    end
    for _,actor in ipairs(self.battle:Units())do state().Clear(actor)end
end
function Rules:CanSalvage(source,cell)
    local construction=self.battle.construction;local area=self.battle.board.area
    local record=construction and area and area.constructionSite and construction:Record(area.constructionSite,cell.index)
    if not record or record.MaxHP<=0 or state().ConstructionOwner(record)~=source.Team or source.Team~=1 then return false,L.ProfessionInvalidSalvage end
    if self.battle:Occupied()[Hex.Key(cell.q,cell.r)]then return false,L.ProfessionOccupiedConstruction end
    local row
    for _,item in ipairs(self.rows:All())do if item.mechanic=='salvage' then row=item;break end end
    local itemId=assert(row).refundItemId;local count=state().ConstructionRefund(record,itemId)
    if count>0 and not self.battle.stats.equipment.data:CanGrant({itemId},{count},{'material'})then return false,L.ProfessionNoRefundSpace end
    return true
end
function Rules:Salvage(source,cell)
    local construction=self.battle.construction;local record=assert(construction:Record(self.battle.board.area.constructionSite,cell.index))
    local itemId
    for _,row in ipairs(self.rows:All())do if row.mechanic=='salvage' then itemId=row.refundItemId;break end end
    state().Salvage(construction.data,record,self.battle.stats.equipment.data,assert(itemId))
end
return Rules
