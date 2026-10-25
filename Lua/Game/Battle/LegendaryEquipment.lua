-- Named equipment rules. Persistent inventory and encounter counters remain in C#.
local Hex=require('Game.Map.HexGrid')
local L=require('Language')
local Trajectory=require('Game.Battle.SkillTrajectory')
local Legendary={};Legendary.__index=Legendary
local function state()return CS.ProjectY.Data.ProfessionCombatState end
local function mark(actor,key)return state().Mark(actor,'legendary_'..key)end
local function put(actor,key,value)state().SetMark(actor,'legendary_'..key,value)end
local function once(actor,key,stamp)return state().Once(actor,'legendary_'..key,stamp)end
local function copy(row)local result={};for k,v in pairs(row)do result[k]=v end;return result end
local function physical(skill)return skill.skillGroup=='weapon' or skill.skillGroup=='slash'end
local function main(skill)return skill.action=='main' and not skill.professionReaction end
local function same(a,b)return a and b and a.q==b.q and a.r==b.r end
local function contains(items,value)for _,v in ipairs(items)do if v==value then return true end end;return false end
function Legendary.New(config,battle)
    local self=setmetatable({battle=battle,rows=config:GetTable('LegendaryEquipmentTable'),byKind={},bySkill={},elements={}},Legendary)
    local damageTypes={}
    for _,effect in ipairs(battle.effects:All())do if effect.kind=='damage'then damageTypes[effect.damageType]=true end end
    local names={};for name in pairs(damageTypes)do names[#names+1]=name end;table.sort(names)
    for i,name in ipairs(names)do self.elements[name]=i end
    for _,row in ipairs(self.rows:All())do
        assert(not self.byKind[row.kind],'Duplicate legendary mechanism: '..row.kind)
        self.byKind[row.kind]=row;battle.stats.equipment.items:Get(row.id)
        for _,id in ipairs(row.skillIds)do assert(not self.bySkill[id],'Duplicate legendary skill');self.bySkill[id]=row;battle.skills:Get(id)end
        for _,id in ipairs(row.effectIds)do battle.effects:Get(id)end
    end
    return self
end
function Legendary:Equipped(actor,kind)
    local equipment=self.battle.stats.equipment
    local item=kind=='homecoming' and equipment.data:Worn(actor.Id,'offhand') or equipment:Weapon(actor)
    return item and equipment:Usable(item) and self.rows:Find(item.ItemId) and self.rows:Get(item.ItemId).kind==kind and item or nil
end
function Legendary:Status(actor,kind,index)
    local row=assert(self.byKind[kind]);local effect=self.battle.effects:Get(assert(row.effectIds[index or 1]))
    assert(effect.kind=='apply_buff','Legendary state requires an application effect')
    return actor.Effects:Find(effect.buffId)
end
function Legendary:Remove(actor,kind,index)
    local instance=self:Status(actor,kind,index);if instance then self.battle.gameEffects:Remove(actor,instance.Id)end
end
function Legendary:Apply(source,target,kind,index,nextEnd)
    local row=assert(self.byKind[kind]);self.battle.gameEffects:Apply(assert(row.effectIds[index or 1]),source,target)
    local instance=self:Status(target,kind,index)
    if instance and nextEnd then state().SetLifetime(instance,self.battle.data.ActiveId==target.Id and 2 or 1)end
    return instance
end
function Legendary:ClearLink(actor)
    local otherId=mark(actor,'debt_partner');put(actor,'debt_partner',0)
    put(actor,'debt_owner',0);put(actor,'debt_deadline',0)
    self:Remove(actor,'debt')
    if otherId>0 then
        local other=self.battle:FindUnit(otherId)
        if other and mark(other,'debt_partner')==actor.Id then
            put(other,'debt_partner',0);put(other,'debt_owner',0);put(other,'debt_deadline',0);self:Remove(other,'debt')
        end
    end
end
function Legendary:Sync(actor)
    local equipment=self.battle.stats.equipment
    for _,slot in ipairs({'main','shield'})do
        local item=slot=='main' and equipment:Weapon(actor) or equipment.data:Worn(actor.Id,'offhand')
        local row=item and equipment:Usable(item) and self.rows:Find(item.ItemId)
        if row and ((slot=='shield')~=(row.kind=='homecoming'))then row=nil end
        local identity=row and item.Id or 0
        if mark(actor,slot..'_instance')~=identity then
            local old=self.rows:Find(mark(actor,slot..'_item'))
            if old then
                for _,id in ipairs(old.effectIds)do
                    local effect=self.battle.effects:Get(id)
                    if effect.kind=='apply_buff' then
                        local active=actor.Effects:Find(effect.buffId);if active and active.SourceId==actor.Id then self.battle.gameEffects:Remove(actor,active.Id)end
                    end
                end
                if old.kind=='debt' then
                    for _,target in ipairs(self.battle:Units())do local debt=self:Status(target,'debt')
                        if debt and debt.SourceId==actor.Id then self:ClearLink(target)end
                    end
                end
            end
            put(actor,slot..'_instance',identity);put(actor,slot..'_item',row and row.id or 0)
            if slot=='main' then put(actor,'last_element',0);put(actor,'momentum_direction',0)end
        end
    end
end
function Legendary:AddSkills(actor,ids)
    self:Sync(actor)
    local result,seen={},{}
    for _,id in ipairs(ids)do local row=self.bySkill[id]
        if not row or self:Equipped(actor,row.kind)then result[#result+1]=id;seen[id]=true end
    end
    for _,row in ipairs(self.rows:All())do if self:Equipped(actor,row.kind)then
        for _,id in ipairs(row.skillIds)do if not seen[id]then result[#result+1]=id;seen[id]=true end end
    end end
    return result
end
function Legendary:Nearby(actor,hostile)
    local count=0
    for _,other in ipairs(self.battle:Units())do
        if other~=actor and other.HP>0 and (hostile and self.battle:IsHostile(actor,other) or not hostile and self.battle:IsAllied(actor,other))
            and self.battle.stats.animals:Distance(actor,other,self.battle.board)==1 then count=count+1 end
    end
    return count
end
function Legendary:PrimaryAttack(actor,skill)
    if not physical(skill)then return false end
    local equipment=self.battle.stats.equipment;local weapon=equipment:Weapon(actor);local off=equipment:Offhand(actor)
    if skill.professionWeaponId then return weapon~=nil and weapon.Id==skill.professionWeaponId end
    return weapon~=nil and not(off and equipment.weapons:Get(off.ItemId).offhandSkillId==skill.id)
end
function Legendary:DealsDamage(skill)
    for _,id in ipairs(skill.effectIds)do local effect=self.battle.effects:Get(id)
        if effect.kind=='damage'and effect.duration=='instant'and effect.recipient=='target'then return true end
    end
    return false
end
function Legendary:Skill(actor,skill)
    self:Sync(actor);local row=self.bySkill[skill.id]
    if row then
        skill.legendaryKind=row.kind
        if row.kind=='chorus' or row.kind=='dawn' or row.kind=='debt' or row.kind=='harvest' or row.kind=='banner'then skill.manualTargets=true end
        if row.kind=='debt' and (#self.battle.professions:Tagged(actor,'poison')>0 or #self.battle.professions:Tagged(actor,'bleeding')>0 or #self.battle.professions:Tagged(actor,'weakness')>0)then skill.range=skill.range+row.values[3]end
    end
    if main(skill) and self:PrimaryAttack(actor,skill)then
        if self:Equipped(actor,'hunt') and mark(actor,'ordinary_steps')>=self.byKind.hunt.values[1]
            and mark(actor,'hunt_attack_round')~=self.battle.data.Round then skill.hitChance=math.min(100,skill.hitChance+self.byKind.hunt.values[2]);skill.legendaryHunt=true end
        if self:Equipped(actor,'banner') and self:Nearby(actor,false)>0 then skill.hitChance=math.min(100,skill.hitChance+self.byKind.banner.values[1])end
        local momentum=self:Equipped(actor,'lance') and self:Status(actor,'lance')
        if momentum then skill.legendaryMomentum=momentum.Stacks*self.byKind.lance.values[2]end
    end
    if main(skill)and self:DealsDamage(skill)then
        local aim=self:Status(actor,'banner');if aim then skill.hitChance=math.min(100,skill.hitChance+self.byKind.banner.values[2]);skill.legendaryAim=true end
    end
    if row and row.kind=='theorem' then local refraction=self:Status(actor,'theorem');skill.legendaryRefraction=(refraction and refraction.Stacks or 0)*row.values[2]end
    return skill
end
function Legendary:Budget(actor,skill)
    local row=self.bySkill[skill.id];if not row then return true end
    self:Sync(actor)
    if not self:Equipped(actor,row.kind)then return false,L.LegendaryEquipmentRequired end
    if row.kind=='oath' then
        local shield=self.battle.stats.equipment.data:Worn(actor.Id,'offhand')
        if not shield or not self.battle.stats.equipment:Usable(shield)then return false,L.ProfessionEquipmentRequired end
    elseif row.kind=='distill' then
        local index=skill.id==row.skillIds[1] and 1 or 2
        if not self:Status(actor,'distill',index)then return false,L.LegendarySampleRequired end
    elseif row.kind=='chorus' then
        local encore=self:Status(actor,'chorus');if not encore or encore.Stacks<row.values[1]then return false,L.LegendaryRepriseRequired end
    elseif row.kind=='dawn' and #self.battle.professions:Tagged(actor,'weakness')==0 then return false,L.LegendaryWeaknessRequired
    elseif row.kind=='lance' and not actor.MountedAnimal then return false,L.LegendaryMountedRequired
    elseif row.kind=='beast' then
        local pet,why=self:Companion(actor);if not pet then return false,why end
        local animals=CS.ProjectY.Data.AnimalCompanionState
        if not animals.CanMove(actor,self.battle.data.Round)or not animals.CanAttack(actor,self.battle.data.Round)then return false,L.ProfessionCompanionCommandSpent end
    end
    return true
end
function Legendary:Companion(actor)
    return self.battle.beasts:Partner(actor,{commandRange=self.byKind.beast.values[2],legendaryExactRange=true})
end
function Legendary:CommandRange(actor,row)
    return row.commandRange+(not row.legendaryExactRange and self:Equipped(actor,'beast')and self.byKind.beast.values[1]or 0)
end
function Legendary:CanUse(source,skill,target)
    local row=self.bySkill[skill.id];if not row then return true end
    if (row.kind=='oath'or row.kind=='homecoming'or row.kind=='banner')and source==target then return false,L.ProfessionChooseOtherAlly end
    if row.kind=='dawn' and target.HP>=CS.ProjectY.Data.BodyHealth.RecoverableHP(target)then return false,L.BodyNoRecoverableHealth end
    if row.kind=='debt' then
        local buff=self.battle.stats.buffs:Get(self.battle.effects:Get(row.effectIds[1]).buffId)
        if self.battle.stats.buffs:Blocked(target,buff)then return false,L.ProfessionTransferImmune end
        for _,tag in ipairs(buff.tags)do if self.battle.stats.growth:Immunity(target,tag)then return false,L.ProfessionTransferImmune end end
    end
    if self:NeedsLanding(skill.id)and #self:LandingCells(source,skill,target)==0 then return false,L.ProfessionNoLanding end
    if row.kind=='banner' and not self:BannerPlan(source,{target})then return false,L.ProfessionNoLanding end
    return true
end
function Legendary:Commit(source,skill)
    self:Sync(source)
    if skill.legendaryHunt then put(source,'hunt_attack_round',self.battle.data.Round)end
    if skill.legendaryAim then self:Remove(source,'banner')end
    if skill.legendaryMomentum and skill.legendaryKind~='lance'then self:Remove(source,'lance');put(source,'momentum_direction',0)end
    local row=self.bySkill[skill.id];if not row then return end
    for _,id in ipairs(row.skillIds)do source:SetCooldown(id,skill.cooldownTurns)end
    if row.kind=='theorem'then self:Remove(source,'theorem')
    elseif row.kind=='distill'then self:Remove(source,'distill',skill.id==row.skillIds[1]and 1 or 2)
    elseif row.kind=='chorus'then self:Remove(source,'chorus')
    elseif row.kind=='debt'then for _,target in ipairs(assert(skill.legendaryTargets))do self:ClearLink(target)end
    elseif row.kind=='dawn'then
        local count=self.battle.professions:RemoveInstances(source,self.battle.professions:Tagged(source,'weakness'))
        self.battle.professions:OnCleansed(source,source,count)
    end
end
function Legendary:BeginTurn(actor)
    self:Sync(actor);put(actor,'ordinary_steps',0);put(actor,'momentum_direction',0);self:Remove(actor,'lance');self:Remove(actor,'duel')
    put(actor,'turn',mark(actor,'turn')+1)
end
function Legendary:EndTurn(actor)
    self:Remove(actor,'lance');put(actor,'momentum_direction',0)
    for _,target in ipairs(self.battle:Units())do
        if mark(target,'debt_owner')==actor.Id then
            if mark(target,'debt_deadline')<=mark(actor,'turn')then self:ClearLink(target)end
        end
    end
end
function Legendary:OnDefeated(actor)
    self:ClearLink(actor)
    for _,target in ipairs(self.battle:Units())do if mark(target,'debt_owner')==actor.Id then self:ClearLink(target)end end
end
function Legendary:OnStatusRemoved(actor,instance)
    if instance.EffectId==self.battle.effects:Get(self.byKind.debt.effectIds[1]).buffId then self:ClearLink(actor)end
end
function Legendary:UntrackedMovement(actor)
    self:Remove(actor,'lance');put(actor,'momentum_direction',0)
end
function Legendary:Moved(actor,path,ordinary)
    if self.battle.data.ActiveId~=actor.Id or self.battle.data.Phase~='combat'then return end
    if ordinary then put(actor,'ordinary_steps',mark(actor,'ordinary_steps')+#path-1)end
    if not self:Equipped(actor,'lance')then return end
    for i=2,#path do
        local direction=0
        for d=1,6 do local q,r=Hex.Neighbor(path[i-1].q,path[i-1].r,d);if q==path[i].q and r==path[i].r then direction=d;break end end
        assert(direction>0,'Legendary movement must contain every adjacent step')
        if mark(actor,'momentum_direction')~=direction then self:Remove(actor,'lance')end
        put(actor,'momentum_direction',direction);self:Apply(actor,actor,'lance')
    end
end
function Legendary:BeforeHit(context)
    local source,target,skill=context.source,context.target,context.skill
    self:Sync(source);self:Sync(target)
    context.legendaryBonus=skill.legendaryMomentum or 0
    if main(skill)and self:Equipped(source,'theorem')then context.legendaryBonus=context.legendaryBonus+(skill.legendaryRefraction or 0)end
    if context.weapon and self:PrimaryAttack(source,skill)then
        if self:Equipped(source,'duel')and context.hadExposure then context.preserveArmor=true end
        if main(skill)then
            if self:Equipped(source,'harvest')and self.battle:IsHostile(source,target)and mark(source,'harvest_round')~=self.battle.data.Round then
                context.legendaryHarvestHit=true
                if target.MaxHP>source.MaxHP then context.legendaryBonus=context.legendaryBonus+self.byKind.harvest.values[1]end
            end
            local oath=self:Equipped(source,'oath')and self:Status(source,'oath')
            if oath then context.legendaryBonus=context.legendaryBonus+self.byKind.oath.values[1];context.legendaryOath=oath end
        end
    end
    context.legendaryResonance=context.row and (context.row.mechanic=='encore'and self.battle.professions:Status(target,'resonance')
        or (context.row.mechanic=='discord'or context.row.mechanic=='beat'and context.row.statusTag=='resonance')and self.battle.professions:Status(source,'resonance'))
    local debt=self:Status(target,'debt');local partner=debt and self.battle:FindUnit(mark(target,'debt_partner'))
    if partner and partner.HP>0 and self:Status(partner,'debt')then context.legendaryDebt={partner=partner,owner=debt.SourceId}end
end
function Legendary:Mitigate(target,amount,impact,existingWard)
    self:Sync(target)
    local ward=self:Status(target,'homecoming');local reduction=existingWard or 0
    if ward then reduction=math.max(reduction,self.byKind.homecoming.values[1]);self:Remove(target,'homecoming')end
    local context=impact.professionContext;local stance=self:Equipped(target,'duel')and self:Status(target,'duel')
    if stance and context and context.weapon and self.battle:IsHostile(context.source,target)
        and self.battle.stats.animals:Distance(context.source,target,self.battle.board)==1 then
        self:Remove(target,'duel');amount=math.floor(amount*(100-self.byKind.duel.values[1])/100)
        if context.source.HP>0 then self.battle.professions:ApplyStatus(target,context.source,'exposed',true)end
    end
    return math.max(0,amount-reduction)
end
function Legendary:Resolved(source,target,row,amount,impact,skill,periodic)
    if periodic or not source or not skill then return end
    if row.kind=='damage' and impact.professionContext then
        local context=impact.professionContext;context.legendaryLost=(context.legendaryLost or 0)+amount
        context.legendaryCritical=impact.critical and skill.criticalMultiplier or 1
        context.legendaryDamageType=context.legendaryDamageType or impact.damageType or context.damageType or row.damageType
    elseif row.kind=='heal'and target~=source and self.battle:IsAllied(source,target)and amount>0 then
        skill.legendaryHealing=(skill.legendaryHealing or 0)+amount
    end
end
function Legendary:AfterHit(context)
    local source,target,skill=context.source,context.target,context.skill;local row=self.bySkill[skill.id]
    if context.damageResolved then
        if context.legendaryHarvestHit then put(source,'harvest_round',self.battle.data.Round)end
        if context.legendaryOath then self:Remove(source,'oath')end
        if main(skill)and context.weapon and self:PrimaryAttack(source,skill)and source.HP>0 and self:Equipped(source,'bulwark')
            and self:Nearby(source,true)>=self.byKind.bulwark.values[1]and once(source,'bulwark_round',self.battle.data.Round)then source:SetGuard(self.byKind.bulwark.values[2])end
        if main(skill)and skill.skillGroup=='spell'and source.HP>0 and self:Equipped(source,'theorem')and not(row and row.kind=='theorem')and not skill.legendaryElementRecorded then
            for _,id in ipairs(skill.effectIds)do local effect=self.battle.effects:Get(id)
                if effect.kind=='damage'then
                    local code=assert(self.elements[effect.damageType],'Unregistered legendary damage type')
                    local previous=mark(source,'last_element');if previous>0 and previous~=code then self:Apply(source,source,'theorem')end
                    put(source,'last_element',code);skill.legendaryElementRecorded=true;break
                end
            end
        end
        local consumed=(context.legendaryConsumed or 0)>0 or target.HP==0 and #context.consume>0
        if source.HP>0 and self:Equipped(source,'distill')and consumed and context.row
            and (context.row.statusTag=='burning'or context.row.statusTag=='poison')and self.battle:IsHostile(source,target)
            and mark(source,'samples')<self.byKind.distill.values[1]and not self:Status(source,'distill',1)and not self:Status(source,'distill',2)then
            put(source,'samples',mark(source,'samples')+1);self:Apply(source,source,'distill',context.row.statusTag=='burning'and 1 or 2,true)
        end
        if context.legendaryProtected and (context.legendaryLost or 0)>0 then
            if target.HP>0 and self:Equipped(target,'oath')and once(target,'oath_round',self.battle.data.Round)then self:Apply(target,target,'oath',1,true)end
            if self:Equipped(target,'homecoming')and context.legendaryProtected.HP>0 and once(target,'homecoming_round',self.battle.data.Round)then self:Apply(target,context.legendaryProtected,'homecoming',1,true)end
        end
        if context.legendaryDebt and (context.legendaryLost or 0)>0 then self:DebtDamage(context)end
    end
    if source.HP>0 and context.legendaryResonance and self:Equipped(source,'chorus')and once(source,'chorus_round',self.battle.data.Round)then self:Apply(source,source,'chorus')end
    if not row or source.HP<=0 then return end
    if row.kind=='bulwark'or row.kind=='lance'then
        local cell=target.HP>0 and self.battle.professions:ForcedLanding(source,target,'push');if cell then self.battle.professions:Move(target,cell)end
    elseif row.kind=='oath'or row.kind=='homecoming'then
        self.battle.professions:ApplyStatus(source,target,'interpose');source:SetGuard(row.values[2])
    elseif row.kind=='chorus'then self.battle.professions:ApplyStatus(source,target,'resonance',true)
    elseif row.kind=='duel'then self:Apply(source,source,'duel')
    elseif row.kind=='harvest'and target.HP>0 then self:Apply(source,target,'harvest',1,true)
    elseif row.kind=='debt'then skill.legendaryLinked=skill.legendaryLinked or {};if self:Apply(source,target,'debt')then skill.legendaryLinked[#skill.legendaryLinked+1]=target end
    elseif row.kind=='banner'then self:Apply(source,target,'banner',1,true)end
end
function Legendary:DebtDamage(context)
    local link=context.legendaryDebt;local target=link.partner;self:ClearLink(context.target)
    if target.HP<=0 then return end
    local row=self.byKind.debt;local owner=self.battle:FindUnit(link.owner)
    if not owner or owner.HP<=0 or not self:Equipped(owner,'debt')then return end
    local budget=(context.conditionalBudget or 0)*(context.legendaryCritical or 1)
    local amount=math.min(math.floor(context.legendaryLost*row.values[1]/100),math.floor(target.MaxHP*row.values[2]/100),math.floor(budget))
    local effect=copy(self.battle.effects:Get(row.effectIds[2]))
    effect.damageType=context.legendaryDamageType or context.damageType or effect.damageType
    amount=math.max(0,amount-self.battle.stats:Get(target,'defense')-target.Guard)
    if self.battle.stats.growth:Immunity(target,'damage_'..effect.damageType)then amount=0 end
    -- No hit context means no copied critical, curse consumption, injury or recursive debt trigger.
    self.battle.gameEffects:Execute(effect,target,amount,owner.Id,self.battle.stats:Template(owner).name,self.battle.skills:Get(row.skillIds[1]).name,owner,true,{legendaryDebt=true,damageType=effect.damageType},false,nil)
end
function Legendary:AfterAction(source,skill)
    if source.HP>0 and (skill.legendaryHealing or 0)>0 and self:Equipped(source,'dawn')and once(source,'dawn_round',self.battle.data.Round)then
        source:SetGuard(math.min(self.byKind.dawn.values[2],math.floor(skill.legendaryHealing*self.byKind.dawn.values[1]/100)))
    end
    if skill.legendaryLinked and #skill.legendaryLinked==2 then
        local a,b=skill.legendaryLinked[1],skill.legendaryLinked[2];put(a,'debt_partner',b.Id);put(b,'debt_partner',a.Id)
        for _,target in ipairs({a,b})do put(target,'debt_owner',source.Id);put(target,'debt_deadline',mark(source,'turn')+1)end
    elseif skill.legendaryLinked then for _,target in ipairs(skill.legendaryLinked)do self:ClearLink(target)end end
    for _,entry in ipairs(skill.legendaryBannerMoves or {})do
        if entry.actor.HP>0 and self.battle.professions:CanStep(entry.actor,entry.cell,self.battle:Occupied(entry.actor.Id))then self.battle.professions:Move(entry.actor,entry.cell)end
    end
end
function Legendary:StructureDamage(source,amount)
    if self:Equipped(source,'carpenter')then return math.floor(amount*(100+self.byKind.carpenter.values[1])/100)end
    return amount
end
function Legendary:NeedsLanding(id)
    local row=self.bySkill[id];return row and (row.kind=='hunt'or row.kind=='beast'or row.kind=='lance')or false
end
function Legendary:StepAt(actor,origin,cell,occupied)
    if not cell or self.battle.stats.buffs:Skipping(actor)then return false end
    local neighbor=false;for _,nextCell in ipairs(self.battle.board:Neighbors(origin))do if same(cell,nextCell)then neighbor=true;break end end
    return neighbor and self.battle.stats.animals:CanPlace(actor,self.battle.board,cell.q,cell.r,occupied,actor.Team==1 and self.battle.board.allowed or nil)
end
function Legendary:DistanceAt(actor,cell,target)
    local distance=math.huge
    for _,part in ipairs(assert(self.battle.stats.animals:Cells(actor,self.battle.board,cell.q,cell.r)))do
        for _,other in ipairs(assert(self.battle.stats.animals:Cells(target,self.battle.board)))do distance=math.min(distance,Hex.Distance(part.q,part.r,other.q,other.r))end
    end
    return distance
end
function Legendary:Paths(source,skill,target)
    local row=assert(self.bySkill[skill.id]);local actor=source
    if row.kind=='beast'then actor=self:Companion(source);if not actor then return {}end end
    local origin=assert(self.battle.board:Find(actor.Q,actor.R));local occupied=self.battle:Occupied(actor.Id)
    local paths={};local original=self.battle.stats.animals:Distance(actor,target,self.battle.board)
    if row.kind=='lance'then
        for direction=1,6 do
            local path={origin};local previous=origin
            for step=1,row.values[4]do
                local q,r=Hex.Neighbor(previous.q,previous.r,direction);local cell=self.battle.board:Find(q,r)
                if not self:StepAt(actor,previous,cell,occupied)then break end
                path[#path+1]=cell
                if step>=row.values[3]and self:DistanceAt(actor,cell,target)==row.values[5]
                    and Trajectory.CanReach(self.battle.board,cell,self.battle.board:Find(target.Q,target.R),'direct')then paths[#paths+1]=copy(path)end
                previous=cell
            end
        end
    else
        local limit=row.kind=='hunt'and row.values[3]or row.values[3]
        local queue={{origin}};local seen={[origin.index]=true};local head=1
        while head<=#queue do
            local path=queue[head];head=head+1;local cell=path[#path]
            local distance=self:DistanceAt(actor,cell,target)
            if row.kind=='beast'and distance==1 or row.kind=='hunt'and #path>1 and distance>original then paths[#paths+1]=path end
            if #path<=limit then
                for _,nextCell in ipairs(self.battle.board:Neighbors(cell))do
                    if not seen[nextCell.index]and self:StepAt(actor,cell,nextCell,occupied)then
                        seen[nextCell.index]=true;local nextPath=copy(path);nextPath[#nextPath+1]=nextCell;queue[#queue+1]=nextPath
                    end
                end
            end
        end
    end
    return paths
end
function Legendary:LandingCells(source,skill,target)
    local cells={};for _,path in ipairs(self:Paths(source,skill,target))do cells[#cells+1]=path[#path]end;return cells
end
function Legendary:SelectedPath(source,skill,target,landing)
    local paths=self:Paths(source,skill,target)
    if not landing and source.Team~=1 then return paths[1]end
    for _,path in ipairs(paths)do if same(landing,path[#path])then return path end end
end
function Legendary:CanUseMovement(source,skill,target)
    if not self.battle:IsHostile(source,target)then return false,L.LegendaryEnemyRequired end
    return self:CanUse(source,skill,target)
end
function Legendary:Walk(actor,path,opportunity,requiresMount)
    local actual={path[1]}
    for i=2,#path do
        if opportunity=='each_step'or opportunity=='start'and i==2 then require('Game.Battle.OpportunityAttacks').Resolve(self.battle,actor)end
        if actor.HP<=0 or self.battle.data.Winner~=''or self.battle.stats.buffs:Skipping(actor)or requiresMount and not actor.MountedAnimal then return false,actual end
        if not self:StepAt(actor,self.battle.board:Find(actor.Q,actor.R),path[i],self.battle:Occupied(actor.Id))then return false,actual end
        state().Move(actor,path[i].q,path[i].r);actual[#actual+1]=path[i]
        if self.battle.professions:OnMoved(actor,true)then self:Moved(actor,actual,false);return false,actual end
    end
    self:Moved(actor,actual,false)
    if #actual>1 then self.battle:Emit('moved',L.LegendarySkillMovement,actor.Id)end
    return true,actual
end
function Legendary:UseMovement(source,skill,target,landing)
    local row=self.bySkill[skill.id];if not row or row.kind~='beast'and row.kind~='lance'then return nil end
    local path=self:SelectedPath(source,skill,target,landing);if not path then return false,L.ProfessionSelectLanding end
    local actor=row.kind=='beast'and assert(self:Companion(source))or source
    self.battle.professions:Commit(source,skill);source:SpendAction(skill.action,skill.cost);source:SetCooldown(skill.id,skill.cooldownTurns)
    source:RecordAction(skill.actionTemplate,1,target.Q,target.R)
    if row.kind=='beast'then
        CS.ProjectY.Data.AnimalCompanionState.Moved(source,self.battle.data.Round)
        CS.ProjectY.Data.AnimalCompanionState.Attacked(source,self.battle.data.Round)
    end
    local arrived=self:Walk(actor,path,row.kind=='beast'and 'each_step'or 'start',row.kind=='lance')
    if not arrived or target.HP<=0 or row.kind=='lance'and not source.MountedAnimal then
        if row.kind=='beast'then CS.ProjectY.Data.AnimalCompanionState.ReleaseDefeated(source)end
        if source.HP>0 then self:Remove(source,'lance')end
        self.battle:CheckWinner();return true
    end
    local attack=skill
    if row.kind=='beast'then
        attack=self.battle:Skill(actor,self.battle.beasts.byKind.attack.biteSkillId)
        attack.damageScale=attack.damageScale*row.values[4]/100;attack.name=skill.name
    else
        local momentum=self:Status(source,'lance');attack.legendaryMomentum=momentum and momentum.Stacks*row.values[2]or 0
        self:Remove(source,'lance');put(source,'momentum_direction',0)
        attack.minRange=row.values[5];attack.range=row.values[5]
        self.battle.professions:ConsumeEquipment(source,skill)
    end
    local program={};for _,id in ipairs(attack.effectIds)do program[#program+1]=self.battle.gameEffects:Prepare(id,actor,target,attack)end
    require('Game.Battle.ProjectileCombat').PrepareProgram(self.battle,actor,attack,program)
    actor:RecordAction(attack.actionTemplate,1,target.Q,target.R)
    self.battle:ApplyEffectProgram(actor,attack,program,1);self:AfterAction(actor,attack);self.battle:CheckWinner();return true
end
function Legendary:BannerPlan(source,targets)
    local occupied=self.battle:Occupied();local plans={}
    for _,target in ipairs(targets)do
        local own={};for _,cell in ipairs(assert(self.battle.stats.animals:Cells(target,self.battle.board)))do own[Hex.Key(cell.q,cell.r)]=true end
        local blocked={};for key,value in pairs(occupied)do if not own[key]then blocked[key]=value end end
        local origin=self.battle.board:Find(target.Q,target.R);local original=self.battle.stats.animals:Distance(source,target,self.battle.board)
        local best
        for _,cell in ipairs(self.battle.board:Neighbors(origin))do
            if self:StepAt(target,origin,cell,blocked)and self:DistanceAt(target,cell,source)<original and (not best or cell.index<best.index)then best=cell end
        end
        if not best then return nil end
        for key in pairs(own)do occupied[key]=nil end
        for _,cell in ipairs(assert(self.battle.stats.animals:Cells(target,self.battle.board,best.q,best.r)))do occupied[Hex.Key(cell.q,cell.r)]=target end
        plans[#plans+1]={actor=target,cell=best}
    end
    return plans
end
function Legendary:PrepareAction(source,skill,targets,program)
    local row=self.bySkill[skill.id];if not row then return true end
    if row.kind=='debt'and #targets~=2 then return false,L.LegendaryTwoEnemiesRequired end
    skill.legendaryTargets=targets
    if row.kind=='banner'then skill.legendaryBannerMoves=self:BannerPlan(source,targets);if not skill.legendaryBannerMoves then return false,L.ProfessionNoLanding end end
    if #program==0 then
        for _,target in ipairs(targets)do program[#program+1]={definition={kind='legendary',duration='instant'},source=source,target=target,hitTarget=target,skill=skill}end
    end
    -- Clear old links only after validating the complete replacement action.
    return true
end
function Legendary:NeedsCellLanding(id)local row=self.bySkill[id];return row and row.kind=='carpenter'or false end
function Legendary:ConstructionAt(source,skill,cell)
    local construction=self.battle.construction;local area=self.battle.board.area
    if not construction or not area or not area.constructionSite then return nil,L.LegendaryConstructionRequired end
    local record=construction:Record(area.constructionSite,cell.index)
    if not record or record.MaxHP<=0 or CS.ProjectY.Data.LegendaryEquipmentState.ConstructionAuthor(record)~=source.Id then return nil,L.LegendaryOwnConstructionRequired end
    local kind=construction.definitions:Get(record.SkillId).kind
    if kind~='fence'and kind~='wall'then return nil,L.LegendaryOwnConstructionRequired end
    if Hex.Distance(source.Q,source.R,cell.q,cell.r)>skill.range or not area:CanSee(self.battle.board:Find(source.Q,source.R),cell)then return nil,L.ProfessionOutsideRange end
    return record
end
function Legendary:ConstructionLandings(source,skill,origin)
    local record=self:ConstructionAt(source,skill,origin);if not record then return {}end
    local result={};local board=self.battle.board;local area=board.area;local occupied=self.battle:Occupied()
    local active=self.battle.construction.adventure.data.Areas.Active
    local lootCells={};for _,loot in ipairs(self.battle.construction.adventure.equipment:LootSnapshot(self.battle.construction.adventure.areas))do if not loot.looted then lootCells[loot.cellIndex]=true end end
    for d=1,6 do local q,r=Hex.Neighbor(origin.q,origin.r,d);local cell=board:Find(q,r)
        if cell and cell.layer==0 and not cell.blocked and not occupied[Hex.Key(q,r)]and not active:IsNpcOccupied(cell.index)and not lootCells[cell.index]
            and (cell.obstacleId or 0)==0 and cell.index~=area.entryIndex and cell.index~=area.goalIndex
            and (cell.kind=='floor'or cell.kind=='grass'or cell.kind=='dirt')and (source.Team~=1 or not board.allowed or board.allowed(cell))
            and not self.battle.construction:Record(area.constructionSite,cell.index)and math.abs(cell.height-origin.height)<.1 then result[#result+1]=cell end
    end
    return result
end
function Legendary:CanUseAt(source,skill,cell)
    if not self:NeedsCellLanding(skill.id)then return nil end
    local record,why=self:ConstructionAt(source,skill,cell);if not record then return false,why end
    return #self:ConstructionLandings(source,skill,cell)>0,L.ProfessionNoLanding
end
function Legendary:UseAtWithLanding(source,skill,origin,landing)
    local record,why=self:ConstructionAt(source,skill,origin);if not record then return false,why end
    local found=false;for _,cell in ipairs(self:ConstructionLandings(source,skill,origin))do if same(cell,landing)then found=true;break end end
    if not found then return false,L.ProfessionSelectLanding end
    self.battle.professions:Commit(source,skill);source:SpendAction(skill.action,skill.cost);source:SetCooldown(skill.id,skill.cooldownTurns)
    CS.ProjectY.Data.LegendaryEquipmentState.MoveConstruction(self.battle.construction.data,record,landing.index,source.Id)
    source:RecordAction(skill.actionTemplate,1,landing.q,landing.r);self.battle:Emit('construction',skill.name,source.Id);return true
end
return Legendary
