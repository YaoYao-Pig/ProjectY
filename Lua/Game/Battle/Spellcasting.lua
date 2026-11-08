local Life=require('Game.Battle.ActorLife')
-- Rules and projections only. Resource, selection and field lifetimes belong to C# Data.
local Hex=require('Game.Map.HexGrid')
local SkillShape=require('Game.Battle.SkillShape')
local L=require('Language')
local Rules={};Rules.__index=Rules
local function state()return CS.ProjectY.Data.SpellcastingState end
function Rules.New(config,stats)
    local self=setmetatable({stats=stats,rule=config:GetTable('SpellcastingRuleTable'):Get(1),recipes=config:GetTable('SpellRecipeTable'),
        bonuses=config:GetTable('SpellcastingBonusTable'),skills=config:GetTable('CombatSkillTable')},Rules)
    for _,row in ipairs(self.recipes:All())do
        local skill=self.skills:Get(row.id)
        assert(skill.catalystKind=='arcane','Spell recipes require an arcane catalyst')
        assert(row.fieldKind=='' or (row.fieldKind=='fire' or row.fieldKind=='mist' or row.fieldKind=='mud') and skill.target=='cell' and row.turns>0,'Invalid field recipe')
        for _,id in ipairs(row.ingredientIds)do assert(id~=row.id,'Recursive spell recipe');self.skills:Get(id)end
    end
    for _,row in ipairs(self.bonuses:All())do
        assert((row.talentNodeId>0)~=(row.itemId>0),'Spellcasting bonus must have exactly one source')
        if row.talentNodeId>0 then config:GetTable('TalentNodeTable'):Get(row.talentNodeId)
        else config:GetTable('EquipmentItemTable'):Get(row.itemId)end
    end
    return self
end
function Rules:IsSpell(skill)return skill.skillGroup=='spell' and skill.catalystKind=='arcane' or (skill.craftCastingCost or 0)>0 end
function Rules:BaseIds(actor)return self.stats.equipment:SkillIds(actor,self.stats:Template(actor))end
function Rules:AddSkills(actor,ids)
    local known={};for _,id in ipairs(ids)do known[id]=true end
    local changed=true
    while changed do
        changed=false
        for _,row in ipairs(self.recipes:All())do if #row.ingredientIds>0 and not known[row.id]then
            local ready=true;for _,id in ipairs(row.ingredientIds)do if not known[id]then ready=false;break end end
            if ready then ids[#ids+1]=row.id;known[row.id]=true;changed=true end
        end end
    end
    return ids
end
function Rules:Sync(actor)
    local eligible=false
    for _,id in ipairs(self:BaseIds(actor))do if self:IsSpell(self.skills:Get(id))then eligible=true;break end end
    local capacity,regen=0,0
    if eligible then
        capacity,regen=self.rule.baseCapacity,self.rule.baseRegen
        local equipment=self.stats.equipment
        local function equippedCount(itemId)
            local count=0
            for _,hand in ipairs({'Weapon','Offhand'})do local item=equipment[hand](equipment,actor)
                if item and item.ItemId==itemId and equipment:Usable(item)then count=count+1 end
            end
            if equipment.data then for i=0,equipment.data.WearableCount-1 do local item=equipment.data:GetWearableAt(i)
                if item.OwnerActorId==actor.Id and item.ItemId==itemId and equipment:Condition(item).Current>0 then count=count+1 end
            end end
            return count
        end
        for _,bonus in ipairs(self.bonuses:All())do
            local rank=bonus.talentNodeId>0 and actor.Growth:GetRank(bonus.talentNodeId) or equippedCount(bonus.itemId)
            capacity=capacity+rank*bonus.capacity;regen=regen+rank*bonus.regeneration
        end
    end
    assert(capacity<=256 and regen<=256,'Casting configuration exceeds resource bounds')
    state().Configure(actor,capacity,regen)
    return state().Current(actor),capacity,regen
end
function Rules:Resolve(actor,skill)
    if not self:IsSpell(skill)then return skill end
    if skill.crafted then
        local recipe=self.recipes:Find(skill.sourceSkillId)
        local baseCost=skill.skillGroup=='spell' and skill.catalystKind=='arcane' and (recipe and recipe.cost or self.rule.defaultCost) or 0
        skill.castingBoostLimit=0;skill.castingBoost=0;skill.castingCost=baseCost+skill.craftCastingCost;skill.castingRecipe={}
        return skill
    end
    local row=self.recipes:Find(skill.id)
    local damage=false
    for _,id in ipairs(skill.effectIds)do if self.stats.effects:Get(id).kind=='damage' then damage=true;break end end
    local limit=damage and (row and row.boostLimit or self.rule.defaultBoostLimit) or 0
    local boost=math.min(state().Boost(actor,skill.id),limit)
    skill.castingBoostLimit=limit;skill.castingBoost=boost;skill.castingCost=(row and row.cost or self.rule.defaultCost)+boost
    skill.castingRecipe=row and row.ingredientIds or {}
    skill.damageScale=skill.damageScale*(1+boost*self.rule.damagePerPoint)
    return skill
end
function Rules:Budget(actor,skill)
    if not self:IsSpell(skill)then return true end
    local current=self:Sync(actor)
    if current<skill.castingCost then return false,string.format(L.SpellcastingInsufficient,skill.castingCost,current)end
    local recipe=self.recipes:Find(skill.id)
    if recipe and #recipe.ingredientIds>0 then
        local known={};for _,id in ipairs(self:AddSkills(actor,self:BaseIds(actor)))do known[id]=true end
        for _,id in ipairs(recipe.ingredientIds)do if not known[id]then return false,L.SpellcastingMissingRecipe end end
    end
    if recipe and recipe.recover>0 and current==state().Maximum(actor)then return false,L.SpellcastingAlreadyFull end
    return true
end
function Rules:Commit(actor,skill)
    if not self:IsSpell(skill)then return end
    local ok,reason=self:Budget(actor,skill);assert(ok,reason)
    state().Spend(actor,skill.castingCost)
    state().SetBoost(actor,skill.id,0)
end
function Rules:AdvanceWorld(actor,now,outsideBattle)
    self:Sync(actor)
    return state().Advance(actor,now,self.rule.minutesPerPoint,outsideBattle)>0
end
function Rules:BeginTurn(actor,battle)
    self:Sync(actor);state().Recover(actor,state().Regen(actor));self:TouchFields(battle,actor)
end
function Rules:BindBoard(battle)
    battle.board.spellcasting=self;battle.board.spellBattle=battle
end
function Rules:FieldContains(field,q,r)
    return SkillShape.Contains(self.skills:Get(field.SkillId).splashShape,field.Q,field.R,q,r,field.Radius,0)
end
function Rules:BlocksSight(battle,origin,target)
    if (origin.layer or 0)~=0 or (target.layer or 0)~=0 then return false end
    local distance=Hex.Distance(origin.q,origin.r,target.q,target.r)
    if distance<=1 then return false end
    local ax,_,az=Hex.ToWorld(origin.q,origin.r,0,1);local bx,_,bz=Hex.ToWorld(target.q,target.r,0,1)
    for i=0,state().FieldCount(battle.data)-1 do local field=state().FieldAt(battle.data,i)
        if field.Kind=='mist' then for step=0,distance do
            local t=step/distance
            for _,epsilon in ipairs({-.000001,.000001})do
                local q,r=Hex.FromWorld(ax+(bx-ax)*t+epsilon,az+(bz-az)*t+epsilon,1)
                if self:FieldContains(field,q,r)then return true end
            end
        end end
    end
    return false
end
function Rules:MoveCost(battle,cell)
    if (cell.layer or 0)~=0 then return 0 end
    for i=0,state().FieldCount(battle.data)-1 do local field=state().FieldAt(battle.data,i)
        if (field.Kind=='mud' or field.Kind=='fire') and self:FieldContains(field,cell.q,cell.r)then return 1 end
    end
    return 0
end
function Rules:TouchFields(battle,actor,q,r)
    if not Life.Alive(actor) then return end
    for i=0,state().FieldCount(battle.data)-1 do local field=state().FieldAt(battle.data,i)
        local touches=false
        for _,cell in ipairs(assert(self.stats.animals:Cells(actor,battle.board,q,r)))do
            if (cell.layer or 0)==0 and self:FieldContains(field,cell.q,cell.r)then touches=true;break end
        end
        if touches and state().Touch(field,actor.Id,battle.data.Round)then
            local row=self.recipes:Get(field.SkillId)
            if row.pulseEffectId>0 then
                local source=assert(battle:FindUnit(field.SourceId),'Spell field owner absent')
                battle.gameEffects:Apply(row.pulseEffectId,source,actor)
            end
        end
    end
end
function Rules:OnPath(battle,actor,path)
    for i=2,#path do self:TouchFields(battle,actor,path[i].q,path[i].r);if not Life.Alive(actor) then break end end
end
function Rules:CanUseAt(battle,source,skill,cell)
    local row=self.recipes:Find(skill.id)
    if not row or row.fieldKind==''then return nil end
    if cell.blocked or (cell.layer or 0)~=0 then return false,L.SpellcastingInvalidCell end
    local distance=Hex.Distance(source.Q,source.R,cell.q,cell.r)
    if distance<skill.minRange or distance>battle:SkillRange(source,cell,skill)then return false,L.SpellcastingOutOfRange end
    if source.Team==1 and battle.board.allowed and not battle.board.allowed(cell)then return false,L.SpellcastingObscured end
    if not require('Game.Battle.SkillTrajectory').CanReach(battle.board,battle.board:Find(source.Q,source.R),cell,skill.trajectory,nil,skill.guided)then return false,L.SpellcastingObscured end
    if state().FieldCount(battle.data)>=64 then return false,L.SpellcastingFieldLimit end
    return true
end
function Rules:UseAt(battle,source,skill,cell)
    local row=self.recipes:Get(skill.id);local prepared={}
    for _,actor in ipairs(battle:Units())do if Life.Alive(actor) then
        local inArea=false
        for _,part in ipairs(assert(self.stats.animals:Cells(actor,battle.board)))do
            if (part.layer or 0)==(cell.layer or 0) and SkillShape.Contains(skill.splashShape,cell.q,cell.r,part.q,part.r,skill.splashRadius,0)then inArea=true;break end
        end
        if inArea then
            local program={};for _,id in ipairs(skill.effectIds)do program[#program+1]=battle.gameEffects:Prepare(id,source,actor,skill)end
            prepared[#prepared+1]={actor=actor,program=program}
        end
    end end
    battle.professions:Commit(source,skill)
    source:SpendAction(skill.action,skill.cost);source:SetCooldown(skill.id,skill.cooldownTurns)
    battle.professions:ConsumeEquipment(source,skill);source:RecordAction(skill.actionTemplate,1,cell.q,cell.r)
    -- Steam quenches complete overlapping burning zones, before creating its own cover.
    if row.fieldKind=='mist' then for i=state().FieldCount(battle.data)-1,0,-1 do local field=state().FieldAt(battle.data,i)
        if field.Kind=='fire' then
            for _,part in ipairs(SkillShape.Cells(battle.board,cell,skill.splashShape,skill.splashRadius))do
                if self:FieldContains(field,part.q,part.r)then state().RemoveField(battle.data,field.Id);break end
            end
        end
    end end
    state().AddField(battle.data,skill.id,source.Id,cell.q,cell.r,skill.splashRadius,row.turns,row.fieldKind,skill.damageScale)
    for _,entry in ipairs(prepared)do
        require('Game.Battle.ProjectileCombat').ApplyActor(battle,source,entry.program,{shot=1,committedArea=true})
    end
    if battle.legendary then battle.legendary:AfterAction(source,skill)end
    require('Game.Presentation.VisualEffects').Skill(battle,source,skill,nil,1,'cast',cell)
    battle:Emit('spell_field',string.format(L.SpellcastingFieldCreated,skill.name,row.turns),source.Id)
    battle:CheckWinner();return true
end
function Rules:UseRecovery(battle,source,skill)
    local row=self.recipes:Find(skill.id)
    if not row or row.recover==0 then return nil end
    battle.professions:Commit(source,skill);source:SpendAction(skill.action,skill.cost);source:SetCooldown(skill.id,skill.cooldownTurns)
    source:RecordAction(skill.actionTemplate,1,source.Q,source.R)
    local amount=state().Recover(source,row.recover)
    require('Game.Presentation.VisualEffects').Skill(battle,source,skill,source,1,'cast')
    battle:Emit('casting_recovered',string.format(L.SpellcastingRecovered,skill.name,amount),source.Id)
    return true
end
function Rules:FieldRows(battle)
    local rows={}
    for i=0,state().FieldCount(battle.data)-1 do local field=state().FieldAt(battle.data,i)
        local cells={}
        for _,cell in ipairs(SkillShape.Cells(battle.board,assert(battle.board:Find(field.Q,field.R)),self.skills:Get(field.SkillId).splashShape,field.Radius))do cells[#cells+1]=cell.index end
        rows[#rows+1]={id=field.Id,kind=field.Kind,q=field.Q,r=field.R,layer=0,radius=field.Radius,remaining=field.Remaining,visualEffectId=field.SkillId,cells=cells}
    end
    return rows
end
return Rules
