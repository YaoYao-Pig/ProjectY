-- Commands share the owner's action budget; the animal remains a real C# actor.
local Hex=require('Game.Map.HexGrid')
local Language=require('Language')
local Opportunity=require('Game.Battle.OpportunityAttacks')
local Trajectory=require('Game.Battle.SkillTrajectory')
local Beasts={};Beasts.__index=Beasts
local function state()return CS.ProjectY.Data.AnimalCompanionState end
local function connected(board,origin,target)
    if not origin or not target then return false end
    for _,cell in ipairs(board:Neighbors(origin))do if cell.index==target.index then return true end end
    return false
end
function Beasts.New(config,battle)
    local self=setmetatable({battle=battle,definitions=config:GetTable('ProfessionBeastTable'),byKind={}},Beasts)
    for _,row in ipairs(self.definitions:All())do
        assert(not self.byKind[row.kind],'Duplicate companion command kind')
        self.byKind[row.kind]=row;config:GetTable('CombatSkillTable'):Get(row.id)
        config:GetTable('CombatSkillTable'):Get(row.biteSkillId)
        config:GetTable('CombatEffectTable'):Get(row.bleedEffectId)
        config:GetTable('CombatEffectTable'):Get(row.bonusEffectId)
    end
    return self
end
function Beasts:Handles(id)return self.definitions:Find(id)~=nil end
function Beasts:NeedsLanding(id)local row=self.definitions:Find(id);return row and row.kind=='rescue' or false end
function Beasts:AddSkills(actor,ids)
    local trained=false;local found=false;local mode=self.byKind.mode.id
    for _,id in ipairs(ids)do
        if id==mode then found=true end
        local row=self.definitions:Find(id);if row and row.kind~='mode' then trained=true end
    end
    if not found and state().Bound(actor) then ids[#ids+1]=mode end
    return ids
end
function Beasts:Occupied(exclude)
    local battle=self.battle;local result={}
    for key,value in pairs(battle.board.externalOccupied or {})do result[key]=value end
    for _,actor in ipairs(battle:Units())do
        if actor.HP>0 and not (exclude and exclude[actor.Id])then battle.stats.animals:Occupy(actor,battle.board,result)end
    end
    return result
end
function Beasts:Partner(owner,row)
    local pet=state().Partner(owner)
    if not pet or pet.HP<=0 or not self.battle:FindUnit(pet.Id)then return nil,Language.ProfessionCompanionRequired end
    if self.battle.stats.buffs:Skipping(pet)then return nil,Language.ProfessionCompanionDisabled end
    local range=self.battle.legendary and self.battle.legendary:CommandRange(owner,row)or row.commandRange
    if self.battle.stats.animals:Distance(owner,pet,self.battle.board)>range then return nil,Language.ProfessionCompanionTooFar end
    return pet
end
function Beasts:Deploy()
    local battle=self.battle
    local adventure=battle.context.services.Adventure
    if CS.ProjectY.Data.ProfessionDuelState.Active(adventure)then return end
    local owners=battle:Units()
    for _,owner in ipairs(owners)do if owner.AnimalOwnerId==0 then
        state().ResetBattle(owner)
        local pet=state().Partner(owner)
        if pet and pet.HP>0 then
            local occupied=self:Occupied();local candidates={}
            for _,cell in ipairs(battle.board.cells)do
                local distance=Hex.Distance(owner.Q,owner.R,cell.q,cell.r)
                if distance>0 and distance<=self.byKind.move.commandRange and battle.stats.animals:CanPlace(pet,battle.board,cell.q,cell.r,occupied)then
                    candidates[#candidates+1]={cell=cell,distance=distance}
                end
            end
            table.sort(candidates,function(a,b)return a.distance==b.distance and a.cell.index<b.cell.index or a.distance<b.distance end)
            if candidates[1]then
                local cell=candidates[1].cell
                state().Follow(pet,cell.q,cell.r,0)
                CS.ProjectY.Data.ProfessionCombatState.AddUnit(battle.data,pet,owner.Team,cell.q,cell.r)
            else battle:Emit('companion',Language.ProfessionCompanionNoSpace,owner.Id)end
        end
    end end
end
function Beasts:BeginTurn(owner)
    local pet=state().Partner(owner);local battle=self.battle
    if pet and pet.HP>0 and battle:FindUnit(pet.Id)and battle.data.Phase=='combat'then
        pet:BeginTurn(1);battle.gameEffects:TickActor(pet,'turn_start')
    end
end
function Beasts:EndTurn(owner)
    local pet=state().Partner(owner);local battle=self.battle
    if pet and pet.HP>0 and battle:FindUnit(pet.Id)and battle.data.Phase=='combat'then battle.gameEffects:TickActor(pet,'turn_end')end
    state().ReleaseDefeated(owner)
end
function Beasts:Finish()
    for i=0,self.battle.data.UnitCount-1 do local actor=self.battle.data:GetUnitAt(i)
        if actor.AnimalOwnerId==0 then
            local pet=state().Partner(actor);if pet then self.battle.gameEffects:Clear(pet,'battle_end')end
            state().ReleaseDefeated(actor)
        end
    end
end
function Beasts:CanUse(source,skill,target)
    local row=self.definitions:Get(skill.id);local battle=self.battle
    if not target or target.HP<=0 then return false,Language.ProfessionCompanionInvalidTarget end
    if row.kind=='scent'then
        local bound=state().Bound(source)
        if not bound or bound.HP<=0 then return false,Language.ProfessionCompanionRequired end
        if not battle:IsHostile(source,target)or battle.stats.animals:Distance(source,target,battle.board)>skill.range then return false,Language.ProfessionCompanionInvalidTarget end
        if not Trajectory.CanReach(battle.board,battle.board:Find(source.Q,source.R),battle.board:Find(target.Q,target.R),'sight')then return false,Language.ProfessionCompanionInvalidTarget end
        return true
    end
    local pet,reason=self:Partner(source,row);if not pet then return false,reason end
    if row.kind=='attack'then
        if not state().CanAttack(source,battle.data.Round)then return false,Language.ProfessionCompanionCommandSpent end
        if not battle:IsHostile(source,target)or battle.stats.animals:Distance(pet,target,battle.board)~=1 then return false,Language.ProfessionCompanionInvalidTarget end
        return true
    elseif row.kind=='rescue'then
        if target==pet or not battle:IsAllied(source,target)or battle.stats.animals:Distance(pet,target,battle.board)~=1 then return false,Language.ProfessionCompanionInvalidTarget end
        if #assert(battle.stats.animals:Cells(target,battle.board))>1 or target.MountedAnimal then return false,Language.ProfessionCompanionTooLarge end
        return #self:LandingCells(source,skill,target)>0,Language.ProfessionCompanionNoLanding
    end
    return false,Language.ProfessionCompanionChooseCell
end
function Beasts:Spend(owner,skill,target)
    self.battle.professions:Commit(owner,skill)
    owner:SpendAction(skill.action,skill.cost);owner:SetCooldown(skill.id,skill.cooldownTurns)
    owner:RecordAction(skill.actionTemplate,1,target.Q,target.R)
end
function Beasts:Use(source,skill,target,selectedLanding)
    local ok,reason=self:CanUse(source,skill,target);if not ok then return false,reason end
    local row=self.definitions:Get(skill.id);local battle=self.battle
    if row.kind=='scent'then self:Spend(source,skill,target);state().SetScent(source,target.Id);return true end
    if row.kind=='rescue'then
        if selectedLanding then return self:UseWithLanding(source,skill,target,selectedLanding.q,selectedLanding.r)end
        return false,Language.ProfessionCompanionChooseCell
    end
    local pet=assert(self:Partner(source,row));local bite=battle:Skill(pet,row.biteSkillId)
    bite.name=skill.name;bite.effectIds={}
    if source.Growth:GetRank(row.passiveNodeId)>0 then bite.effectIds[#bite.effectIds+1]=row.bonusEffectId end
    for _,id in ipairs(battle.skills:Get(row.biteSkillId).effectIds)do bite.effectIds[#bite.effectIds+1]=id end
    if battle.stats.animals:Distance(source,target,battle.board)==1 then bite.effectIds[#bite.effectIds+1]=row.bleedEffectId end
    local program={}
    for _,id in ipairs(bite.effectIds)do program[#program+1]=battle.gameEffects:Prepare(id,pet,target,bite)end
    require('Game.Battle.ProjectileCombat').PrepareProgram(battle,pet,bite,program)
    self:Spend(source,skill,target);state().Attacked(source,battle.data.Round)
    pet:RecordAction(bite.actionTemplate,1,target.Q,target.R)
    battle:ApplyEffectProgram(pet,bite,program,1);battle:CheckWinner()
    return true
end
function Beasts:OnHit(source,target,skill)
    local owner
    if state().Independent(source)then owner=self.battle:FindUnit(source.AnimalOwnerId)
    elseif source.MountedAnimal and self.battle.stats.animals.bySkill[skill.id]then owner=source end
    if not owner or state().Scent(owner)~=target.Id then return end
    state().SetScent(owner,0)
    if target.HP>0 then self.battle.gameEffects:Apply(self.byKind.scent.bleedEffectId,source,target)end
end
function Beasts:CanUseAt(source,skill,q,r)
    local row=self.definitions:Get(skill.id);if row.kind~='move'then return false,Language.ProfessionCompanionInvalidTarget end
    local battle=self.battle;local pet,reason=self:Partner(source,row);if not pet then return false,reason end
    if not state().CanMove(source,battle.data.Round)then return false,Language.ProfessionCompanionCommandSpent end
    if Hex.Distance(pet.Q,pet.R,q,r)~=1 then return false,Language.ProfessionCompanionNoLanding end
    local cell=battle.board:Find(q,r);local origin=battle.board:Find(pet.Q,pet.R)
    if not connected(battle.board,origin,cell)or not battle.stats.animals:CanPlace(pet,battle.board,q,r,self:Occupied({[pet.Id]=true}),battle.board.allowed)then
        return false,Language.ProfessionCompanionNoLanding
    end
    return true
end
function Beasts:Cells(source,skill)
    local row=self.definitions:Get(skill.id);if row.kind~='move'then return {}end
    local pet=self:Partner(source,row);if not pet then return {}end
    local result={}
    for _,cell in ipairs(self.battle.board:Neighbors(self.battle.board:Find(pet.Q,pet.R)))do
        if self:CanUseAt(source,skill,cell.q,cell.r)then result[#result+1]=cell end
    end
    return result
end
function Beasts:UseAt(source,skill,q,r)
    local ok,reason=self:CanUseAt(source,skill,q,r);if not ok then return false,reason end
    local battle=self.battle;local pet=assert(self:Partner(source,self.definitions:Get(skill.id)))
    self:Spend(source,skill,pet);state().Moved(source,battle.data.Round)
    Opportunity.Resolve(battle,pet)
    if pet.HP<=0 or battle.data.Winner~=''or battle.stats.buffs:Skipping(pet)then state().ReleaseDefeated(source);return true end
    if battle.stats.animals:CanPlace(pet,battle.board,q,r,self:Occupied({[pet.Id]=true}))then
        CS.ProjectY.Data.ProfessionCombatState.Move(pet,q,r);battle.professions:OnMoved(pet)
    end
    battle:Emit('moved',skill.name,pet.Id);return true
end
function Beasts:LandingCells(source,skill,target)
    local row=self.definitions:Get(skill.id);if row.kind~='rescue'then return {}end
    local pet=self:Partner(source,row);if not pet or not target or target.HP<=0 or target.MountedAnimal then return {}end
    local battle=self.battle;local result={};local origin=battle.board:Find(target.Q,target.R)
    if #assert(battle.stats.animals:Cells(target,battle.board))>1 then return result end
    for _,cell in ipairs(battle.board:Neighbors(origin))do
        if Hex.Distance(pet.Q,pet.R,cell.q,cell.r)==1 and connected(battle.board,origin,cell)
            and battle.stats.animals:CanPlace(target,battle.board,cell.q,cell.r,self:Occupied({[target.Id]=true}),battle.board.allowed)then
            result[#result+1]=cell
        end
    end
    return result
end
function Beasts:UseWithLanding(source,skill,target,q,r)
    local ok,reason=self:CanUse(source,skill,target);if not ok then return false,reason end
    local legal=false;for _,cell in ipairs(self:LandingCells(source,skill,target))do if cell.q==q and cell.r==r then legal=true;break end end
    if not legal then return false,Language.ProfessionCompanionNoLanding end
    self:Spend(source,skill,target);state().Rescued(source,self.battle.data.Round)
    CS.ProjectY.Data.ProfessionCombatState.Move(target,q,r);self.battle.professions:OnMoved(target)
    self.battle:Emit('moved',skill.name,source.Id,target.Id)
    return true
end
function Beasts:AreaOrigin(adventure,actor)
    local area,active=adventure.areas:ActiveLayout(),adventure.data.Areas.Active
    for i=0,active.MemberCount-1 do if active:GetMemberIdAt(i)==actor.Id then return area.cells[active:GetMemberCellAt(i)]end end
end
function Beasts:AreaOccupied(adventure,exclude,layer)
    local area,active=adventure.areas:ActiveLayout(),adventure.data.Areas.Active;local occupied={}
    local function add(actor,cell)
        if actor.HP>0 and not exclude[actor.Id]and cell and cell.layer==(layer or 0)then
            for _,part in ipairs(assert(self.battle.stats.animals:Cells(actor,area,cell.q,cell.r,cell.layer)))do occupied[Hex.Key(part.q,part.r)]=true end
        end
    end
    for i=0,adventure.data.PartyCount-1 do local actor=adventure.data:GetPartyAt(i)
        add(actor,self:AreaOrigin(adventure,actor));local pet=state().Partner(actor)
        if pet then add(pet,area:Find(pet.Q,pet.R,state().Layer(pet)))end
    end
    for i=0,active.EncounterCount-1 do local group=active:GetEncounterAt(i)
        for j=0,group.EnemyCount-1 do local actor=group:GetEnemyAt(j)
            if actor.AnimalOwnerId==0 then add(actor,area:Find(actor.Q,actor.R))end
        end
    end
    for i=0,active.NpcCount-1 do local npc=active:GetNpcAt(i)
        if npc.Present then local cell=area.cells[npc.CellIndex];if cell.layer==(layer or 0)then occupied[Hex.Key(cell.q,cell.r)]=true end end
    end
    return occupied
end
function Beasts:ModePlan(adventure,actor)
    local pet=state().Bound(actor);local origin=self:AreaOrigin(adventure,actor)
    if not pet or pet.HP<=0 or actor.HP<=0 or not origin then return nil,Language.ProfessionCompanionRequired end
    local area=adventure.areas:ActiveLayout();local occupied=self:AreaOccupied(adventure,{[actor.Id]=true,[pet.Id]=true},origin.layer)
    if state().Partner(actor)then
        local species=self.battle.stats.animals.species:Get(pet.AnimalSpeciesId)
        if not species.rideable then return nil,Language.ProfessionCompanionNotRideable end
        if not self.battle.stats.animals:CanPlace(pet,area,origin.q,origin.r,occupied,nil,origin.layer)then return nil,Language.ProfessionCompanionNoLanding end
        return {pet=pet,independent=false,cell=origin}
    end
    occupied[Hex.Key(origin.q,origin.r)]=true
    for _,cell in ipairs(area:Neighbors(origin))do
        if self.battle.stats.animals:CanPlace(pet,area,cell.q,cell.r,occupied,nil,cell.layer)then return {pet=pet,independent=true,cell=cell}end
    end
    return nil,Language.ProfessionCompanionNoLanding
end
function Beasts:RegisterLife(skills,adventure)
    local mode=self.byKind.mode
    skills:Register(adventure.config:GetTable('CombatSkillTable'):Get(mode.id).skillGroup,{
        CanUse=function(actor,id)
            if id~=actor.Id then return false,Language.ProfessionCompanionInvalidTarget end
            local plan,reason=self:ModePlan(adventure,actor);return plan~=nil,reason
        end,
        Use=function(actor)
            local plan,reason=self:ModePlan(adventure,actor);if not plan then return false,reason end
            adventure.data.Areas.Active:Stop()
            state().SetMode(actor,plan.independent,plan.cell.q,plan.cell.r,plan.cell.layer)
            state().Touch(adventure.data.Areas.Active)
            return true,plan.independent and Language.ProfessionCompanionFollowing or Language.ProfessionCompanionMounted
        end,
        Targets=function(actor)return {actor.Id}end,
    })
end
function Beasts:FollowArea(adventure)
    if adventure.data.Phase~='area'then return end
    local area=adventure.areas:ActiveLayout()
    for i=0,adventure.data.PartyCount-1 do local owner=adventure.data:GetPartyAt(i);local pet=state().Partner(owner)
        if pet and pet.HP<=0 then state().ReleaseDefeated(owner)
        elseif pet and owner.HP>0 then
            local origin=self:AreaOrigin(adventure,owner)
            if origin then
                local occupied=self:AreaOccupied(adventure,{[pet.Id]=true},origin.layer)
                local current=area:Find(pet.Q,pet.R,state().Layer(pet))
                local near=current and current.layer==origin.layer and Hex.Distance(origin.q,origin.r,pet.Q,pet.R)<=2
                if not near or not self.battle.stats.animals:CanPlace(pet,area,pet.Q,pet.R,occupied,nil,origin.layer)then
                    for _,cell in ipairs(area:Neighbors(origin))do
                        if cell.layer==origin.layer and self.battle.stats.animals:CanPlace(pet,area,cell.q,cell.r,occupied,nil,cell.layer)then
                            state().Follow(pet,cell.q,cell.r,cell.layer);state().Touch(adventure.data.Areas.Active);break
                        end
                    end
                end
            end
        end
    end
end
return Beasts
