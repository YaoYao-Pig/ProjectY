local Life=require('Game.Battle.ActorLife')
local Class = require('Core.Class')
local System = require('Core.LuaSystem')
local Signal = require('Core.Signal')
local Hex = require('Game.Map.HexGrid')
local SkillShape = require('Game.Battle.SkillShape')
local Board = require('Game.Battle.BattleBoard')
local Trajectory = require('Game.Battle.SkillTrajectory')
local Projectiles = require('Game.Battle.ProjectileCombat')
local OpportunityAttacks = require('Game.Battle.OpportunityAttacks')
local AllySelfPreservation = require('Game.Battle.AllySelfPreservation')
local BattleLog = require('Game.Battle.BattleLog')
local LuaLanguage = require('Language')
local VisualEffects = require('Game.Presentation.VisualEffects')
local Battle = Class('BattleSystem', System)
function Battle:OnInit(context)
    System.OnInit(self, context)
    local config = context.systems:Get('Config')
    self.appearances=require('Game.Adventure.CharacterAppearance').New(config,context.services.Appearances)
    local adventure = assert(context.services.Adventure,
        'FrameworkServices.Adventure is unavailable; exit Play, compile C# and run XLua/Generate Code before restarting')
    self.data = assert(adventure.Battle, 'FrameworkServices.Adventure.Battle is unavailable')
    self.stats = require('Game.Battle.CombatStats')(config,assert(adventure.Equipment,'Equipment data requires regenerated xLua bindings'))
    self.skills = config:GetTable('CombatSkillTable')
    self.effects = config:GetTable('CombatEffectTable')
    self.encounters = config:GetTable('CombatEncounterTable')
    self.preparationRules = config:GetTable('BattlePreparationTable'):Get(1)
    self.consumables = config:GetTable('ConsumableTable')
    self.Changed = Signal(context.log)
    self.gameEffects=require('Game.Battle.GameEffects').New(self.stats,self.effects,function(...) self:Emit(...) end,
        {battle=self,roll=function()return self.data:RollPercent()end,minutes=function()return adventure.Narrative.Minutes end,
         report=function(kind,plan,details)
            self:Emit(kind,details.reason or details.checkName or kind,plan.sourceId,plan.target.Id,0,plan.target,false,details)
         end})
    self.checks=function(...)self:ChanceLog(...)end
    self.professions=require('Game.Battle.ProfessionCombat').New(config,self)
    self.spellcasting=self.stats.spellcasting
    self.morale=self.stats.morale
    self.titleCombat=require('Game.Battle.TitleCombat').New(self)
    self.beasts=require('Game.Battle.ProfessionBeasts').New(config,self)
    self.legendary=require('Game.Battle.LegendaryEquipment').New(config,self)
    self.gameEffects.professions=self.professions
    self.gameEffects.legendary=self.legendary
    self.gameEffects.titleCombat=self.titleCombat
    self.gameEffects.damageLimit=function(target,amount)return CS.ProjectY.Data.ProfessionDuelState.Limit(adventure,target,amount)end
    self.gameEffects:Validate()
    local construction=config:GetTable('ConstructionTable')
    local animalSpeechSkill=config:GetTable('AnimalSpeechRuleTable'):Get(1).skillId
    for _, row in ipairs(self.skills:All()) do
        assert(row.minRange<=row.range,'Minimum skill range exceeds maximum: '..row.id)
        SkillShape.Validate(row.rangeShape)
        SkillShape.Validate(row.splashShape)
        assert(#row.effectIds > 0 or self.spellcasting.recipes:Find(row.id) or construction:Find(row.id) or self.professions.rows:Find(row.id) or self.beasts:Handles(row.id) or self.legendary.bySkill[row.id]
            or config:GetTable('ProfessionExplorationTable'):Find(row.id) or row.id==animalSpeechSkill or row.id==501 or row.id==503, 'Skill needs effects: ' .. row.id)
        Trajectory.Description(row.trajectory)
        assert(row.trajectory=='sight' or row.target=='enemy' or row.target=='ally','Projectile skill needs an actor target: '..row.id)
        if row.selectBodyPart then
            assert(row.target=='enemy' and row.maxTargets==1 and row.shots==1 and not row.affectsContainers,
                'Body-target skills require one enemy recipient and no container damage: '..row.id)
        end
        OpportunityAttacks.Validate(self,row)
    end
    for _,row in ipairs(self.consumables:All()) do
        local skill=self.skills:Get(row.skillId)
        assert(self.stats.equipment.items:Get(row.id).kind=='consumable','Consumable needs a consumable inventory item: '..row.id)
        assert(skill.skillKind=='item' and skill.target=='self' and skill.shots==1 and skill.ammoPerShot==0 and skill.cooldownTurns==0,
            'Consumable skills must be self effects without ammo or cooldown: '..row.id)
        for _,id in ipairs(skill.effectIds) do
            local effect=self.effects:Get(id)
            assert(effect.kind=='heal' or effect.kind=='modifier' or effect.kind=='apply_buff','Consumable must heal, modify attributes or apply a buff: '..row.id)
        end
    end
end
function Battle:Units()
    local units = {}
    for i = 0, self.data.UnitCount - 1 do
        local actor=self.data:GetUnitAt(i)
        if actor.AnimalOwnerId==0 or CS.ProjectY.Data.AnimalCompanionState.Independent(actor) then units[#units + 1] = actor end
    end
    return units
end
function Battle:FindUnit(id)
    for i = 0, self.data.UnitCount - 1 do
        local unit = self.data:GetUnitAt(i)
        if unit.Id == id then return unit end
    end
end
function Battle:Active() return assert(self:FindUnit(self.data.ActiveId), 'No active battle unit') end
local function side(value) return type(value)=='number' and value or value.Team end
function Battle:Relation(source,target)
    local a,b=side(source),side(target)
    if a==b then return 'allied' end
    if a==0 or b==0 then return 'neutral' end
    local relations=self.board and self.board.sideRelations
    if not relations then return 'hostile' end
    local relation=relations[a] and relations[a][b] or 'neutral'
    assert(relation=='hostile' or relation=='allied' or relation=='neutral','Invalid battle side relation')
    return relation
end
function Battle:IsHostile(source,target) return self:Relation(source,target)=='hostile' end
function Battle:IsAllied(source,target) return self:Relation(source,target)=='allied' end
function Battle:PresentationTeam(actor)
    if actor.Team==1 then return 1 end
    if actor.Team==0 then return 0 end
    if self:IsAllied(1,actor) then return 4 end
    if actor.Team==((self.board and self.board.primaryEnemyTeam) or 2) then return 2 end
    return 3
end
function Battle:Emit(kind, message, sourceId, targetId, amount, target, attackHit, impact)
    local source=sourceId and self:FindUnit(sourceId)
    target=target or (targetId and self:FindUnit(targetId))
    local sourceView=source and {name=self.stats:Template(source).name,team=self:PresentationTeam(source)}
        or impact and impact.sourceName and {name=impact.sourceName,team=0}
    local targetView=target and {name=self.stats:Template(target).name,team=self:PresentationTeam(target)}
    if targetView and self.stats.inspection then
        targetView.healthKnown=self.stats.inspection:Known(target,'health')
        targetView.defenseKnown=self.stats.inspection:Known(target,'attribute:defense')
        targetView.guardKnown=self.stats.inspection:Known(target,'guard')
    end
    self.data:AddLog(BattleLog.Format(kind,message,sourceView,targetView,amount,impact))
    local event={kind = kind, sourceId = sourceId, targetId = targetId, amount = amount,target=target,attackHit=attackHit==true,impact=impact,
        hpBefore=impact and impact.hpBefore,hpAfter=impact and impact.hpAfter,periodic=impact and impact.periodic==true}
    require('Game.Presentation.AudioEvents').Record(self,event)
    self.Changed:Emit(event)
    self.morale:OnEvent(self,event)
end
function Battle:ChanceLog(source,target,skill,label,chance,roll,passed,details)
    details=details or {};details.actionName=skill.name;details.checkName=label;details.chance=chance;details.roll=roll;details.passed=passed
    if label=='命中' or label=='缴械' then details.baseChance=skill.baseHitChance end
    self:Emit('check',label,source.Id,target and target.Id,0,target,false,details)
end
function Battle:Start(encounterId, party, seed)
    local encounter = self.encounters:Get(encounterId)
    assert(#party > 0 and #party <= 4, 'Battle needs 1..4 living party members')
    assert(#encounter.enemyIds > 0 and #encounter.enemyIds <= 4, 'Encounter needs 1..4 enemies')
    local board = Board.Create(encounter.radius, seed, encounter.obstacleChance)
    for _, unit in ipairs(party) do assert(Life.Alive(unit), 'Cannot deploy a defeated unit') end
    self.data:Reset(encounterId, encounter.maxRounds)
    VisualEffects.Clear(self)
    self.data:SetRandomSeed(seed)
    self.board = board
    for i, unit in ipairs(party) do self.data:AddUnit(unit, 1, -board.radius, i - 1) end
    local appearanceGroup=self.appearances:Group(encounter.appearancePoolId,(seed ~ (encounterId*65537)) & 0xffffffff)
    local deployment=require('Game.Battle.BodyFootprints').Deploy(board,encounter,self.stats.animals)
    for i, templateId in ipairs(encounter.enemyIds) do
        CS.ProjectY.Data.EquipmentCombatState.RemoveActor(self.stats.equipment.data,100+i)
        local unit = self.data:AddEnemy(100 + i, templateId, deployment[i].q, deployment[i].r)
        self.stats.birth:InitializeEnemy(unit,seed)
        local species=self.stats.animals.byUnit[templateId]
        if species then unit:InitializeAnimal(species.id,(seed ~ unit.Id) & 0xffffffff)
        elseif not self.stats.animals:IsStaticBody(unit) then self.appearances:Assign(unit,appearanceGroup) end
        self.context.systems:Get('Equipment'):InitializeEnemy(unit)
        unit:SetMaxHP(self.stats:MaximumHP(unit)); unit:Restore()
    end
    self.titleCombat:Begin()
    self:Emit('battle_started', encounter.name)
    self:BeginDeployment()
end
-- 地牢保持双方真实位置与角色实例；首版只接单层地牢，不折叠桥上/桥下坐标。
function Battle:StartArea(encounterId, board, party, enemies)
    local encounter = self.encounters:Get(encounterId)
    assert(board.area and #party > 0 and #party <= 4 and #enemies > 0 and #enemies <= 16, 'Invalid area battle deployment')
    for _, cell in ipairs(board.cells) do assert(cell.layer == 0, 'Layered area combat is not supported') end
    local occupied, ids = {}, {}
    local function check(actor, q, r)
        local cell = assert(board:Find(q, r), 'Actor outside area battle window')
        local key = Hex.Key(q, r)
        assert(Life.Alive(actor) and self.stats.animals:CanPlace(actor,board,q,r,occupied) and not ids[actor.Id], 'Invalid area combat position')
        for _,part in ipairs(assert(self.stats.animals:Cells(actor,board,q,r))) do occupied[Hex.Key(part.q,part.r)]=true end
        ids[actor.Id] = true
    end
    for _, row in ipairs(party) do check(row.actor, row.q, row.r) end
    for _, actor in ipairs(enemies) do
        assert(not board.sideRelations or actor.Team>=2 and actor.Team<=64,'AI participants require an independent battle side')
        check(actor, actor.Q, actor.R)
    end
    self.data:Reset(encounterId, encounter.maxRounds); self.board = board
    VisualEffects.Clear(self)
    self.data:SetRandomSeed((board.area.seed + enemies[1].Id * 1009)%4294967296)
    for _, row in ipairs(party) do self.data:AddUnit(row.actor, 1, row.q, row.r) end
    for _, actor in ipairs(enemies) do self.data:AddUnit(actor, board.sideRelations and actor.Team or 2, actor.Q, actor.R) end
    self.titleCombat:Begin()
    self:Emit('battle_started', encounter.name); self:BeginDeployment()
end
function Battle:TurnOrder(playersOnly)
    local order={}
    for _,unit in ipairs(self:Units()) do
        if Life.Alive(unit) and unit.AnimalOwnerId==0 and (not playersOnly or unit.Team==1) then order[#order+1]=unit end
    end
    table.sort(order,function(a,b)
        local sa,sb=self.stats:Get(a,'speed'),self.stats:Get(b,'speed')
        if sa==sb then return a.Id<b.Id end
        return sa>sb
    end)
    return order
end
function Battle:BeginDeployment()
    self.spellcasting:BindBoard(self)
    for _,actor in ipairs(self:Units())do
        self.spellcasting:AdvanceWorld(actor,self.context.services.Adventure.Narrative.Minutes,false)
    end
    self.beasts:Deploy()
    self.board.deploymentOrigins={}
    local order=self:TurnOrder(true)
    self.data:BeginDeployment()
    for _,unit in ipairs(self:Units())do self:DropInjuredEquipment(unit)end
    for _,unit in ipairs(order) do
        self.board.deploymentOrigins[unit.Id]={q=unit.Q,r=unit.R}
        self.data:AddTurn(unit.Id)
    end
    self:Emit('deployment_started','战前部署：调整站位，使用职业准备技能或道具。')
    self:BeginTurn(0)
end
function Battle:DropInjuredEquipment(actor)
    if self.data.Phase~='combat' and self.data.Phase~='deployment' then return end
    if not self.stats.equipment:HasDisabledHandEquipment(actor) then return end
    local names=self.context.systems:Get('Equipment').worldLoot:DropInjuredHands(self.context.systems:Get('MapArea'),actor,self.stats)
    if #names>0 then
        self:Emit('injury_equipment_dropped',string.format(LuaLanguage.BodyEquipmentDropped,self.stats:Template(actor).name,
            table.concat(names,LuaLanguage.BodyEquipmentSeparator)),nil,actor.Id,0,actor)
    end
end
function Battle:NewRound()
    if self.data.Round>0 then
        CS.ProjectY.Data.SpellcastingState.AdvanceFields(self.data)
        if self.board.onRoundCompleted then self.board.onRoundCompleted()
        else for _,actor in ipairs(self:Units()) do if Life.Alive(actor) then actor:AdvanceTamingRound() end end end
    end
    if self.data.Round >= self.data.MaxRounds then
        self.data:Finish('draw'); self:ClearBattleEffects();self:Emit('battle_ended', '战斗时间耗尽，队伍撤回。'); return
    end
    local order = self:TurnOrder(false)
    self.data:BeginRound()
    for _, unit in ipairs(order) do self.data:AddTurn(unit.Id) end
    self:BeginTurn(0)
end
function Battle:BeginTurn(index)
    self.data:SelectTurn(index)
    local unit = self:Active()
    local skipped=self.data.Phase=='combat' and self.stats.buffs:Skipping(unit)
    if self.data.Phase=='deployment' then unit:BeginDeploymentTurn(self.stats:Template(unit).actionPoints)
    else
        unit:BeginTurn(self.stats:Template(unit).actionPoints)
        self.titleCombat:BeginTurn(unit)
        self.gameEffects:TickActor(unit,'turn_start')
        self.spellcasting:BeginTurn(unit,self)
        self.professions:BeginTurn(unit)
        self.beasts:BeginTurn(unit)
        if self.legendary then self.legendary:BeginTurn(unit)end
        if self.legacyCombat then self.legacyCombat:BeginTurn(unit)end
    end
    if self:CheckWinner() then return end
    if not Life.Alive(unit) then self:AdvanceTurn();return end
    if self.data.Phase=='combat' then
        self.morale:BeginTurn(self,unit)
        if self.morale:Fleeing(unit) then self:Emit('turn_started',LuaLanguage.MoraleFleeing,unit.Id);self.morale:Flee(self,unit);return end
    end
    if skipped then self:Emit('turn_skipped',self.stats:Template(unit).name..' 因「'..skipped.name..'」跳过行动',unit.Id);self:EndTurn();return end
    self:Emit('turn_started', self.stats:Template(unit).name .. (self.data.Phase=='deployment' and ' 部署' or ' 行动'), unit.Id)
end
function Battle:CheckWinner()
    if self.data.Winner~='' then return true end
    local duel=CS.ProjectY.Data.ProfessionDuelState.Result(self.context.services.Adventure)
    if duel~='' then
        self.data:Finish(duel);self:ClearBattleEffects();self:Emit('battle_ended',require('Language').ProfessionDuelEnded);return true
    end
    local players,hostiles=0,0
    for _,unit in ipairs(self:Units()) do if Life.Alive(unit) then
        if unit.Team==1 and unit.AnimalOwnerId==0 then players=players+1
        elseif self:IsHostile(1,unit) then hostiles=hostiles+1 end
    end end
    if players>0 and hostiles>0 then return false end
    local result = players>0 and 'victory' or 'defeat'
    self.data:Finish(result)
    self:ClearBattleEffects()
    self:Emit('battle_ended', result == 'victory' and '敌人已被击退。' or '队伍失去战斗能力。')
    return true
end
function Battle:ClearBattleEffects()
    self.titleCombat:Finish()
    self.morale:End(self)
    self.beasts:Finish()
    self.professions:Finish()
    for i=0,self.data.UnitCount-1 do
        local unit=self.data:GetUnitAt(i)
        CS.ProjectY.Data.SpellcastingState.ClearBoosts(unit)
        self.spellcasting:AdvanceWorld(unit,self.context.services.Adventure.Narrative.Minutes,false)
        self.gameEffects:Clear(unit,'battle_end')
        if unit.MountedAnimal then self.gameEffects:Clear(unit.MountedAnimal,'battle_end') end
    end
    CS.ProjectY.Data.SpellcastingState.ClearFields(self.data)
end
function Battle:ApplyEffect(effectId,source,target)
    local ok,reason=self.gameEffects:Apply(effectId,source,target)
    if ok and self.data.Phase~='idle' and self.data.Winner=='' then
        if not self:CheckWinner() then
            if not Life.Alive(self:Active()) then self:AdvanceTurn()
            elseif self.data.Phase=='combat' and self.stats.buffs:Skipping(self:Active()) then self:EndTurn() end
        end
    end
    return ok,reason
end
function Battle:EndTurn()
    if self.data.Winner ~= '' then return false, '战斗已经结束' end
    local unit = self:Active()
    if self.data.Phase=='combat' then
        self.beasts:EndTurn(unit);if self.legendary then self.legendary:EndTurn(unit)end
        self.gameEffects:TickActor(unit,'turn_end');self.titleCombat:EndTurn(unit)
    end
    self:Emit('turn_ended', self.stats:Template(unit).name .. ' 结束行动', unit.Id)
    if self:CheckWinner() then return true end
    self:AdvanceTurn();return true
end
function Battle:AdvanceTurn()
    for i = self.data.TurnIndex + 1, self.data.TurnCount - 1 do
        local nextUnit=self:FindUnit(self.data:GetTurnAt(i))
        if Life.Alive(nextUnit) and nextUnit.AnimalOwnerId==0 then self:BeginTurn(i); return true end
    end
    self:NewRound()
end
function Battle:Occupied(exceptId)
    local occupied = {}
    if self.board.externalOccupied then
        for key in pairs(self.board.externalOccupied) do occupied[key] = true end
    end
    for _, unit in ipairs(self:Units()) do
        if Life.Alive(unit) and unit.Id ~= exceptId then self.stats.animals:Occupy(unit,self.board,occupied) end
    end
    return occupied
end
function Battle:ShotOccupancy(source,target)
    if self.board.shotOccupancy then return self.board.shotOccupancy(source.Id,target and target.Id) end
    local occupied=self:Occupied(source.Id)
    if target then for key,value in pairs(occupied) do if value==target then occupied[key]=nil end end end
    return occupied
end
function Battle:Reachable()
    if self.data.Winner ~= '' then return {} end
    local unit = self:Active(); local template = self.stats:Template(unit)
    if self.data.Phase=='combat' and self.stats.buffs:Skipping(unit) then return {} end
    local movement=CS.ProjectY.Data.BattleMovement
    local remaining=movement.Remaining(unit,self.stats:MoveRange(unit,template))
    if remaining==0 or movement.Spent(unit)==0 and unit.AP<template.moveCost then return {} end
    local occupied=self:Occupied(unit.Id)
    local origin=self.data.Phase=='deployment' and assert(self.board.deploymentOrigins[unit.Id],'Missing deployment origin')
    local cells,distance,previous = self.board:Search(unit.Q, unit.R, occupied, remaining,function(cell)
        if origin and Hex.Distance(origin.q,origin.r,cell.q,cell.r)>self.preparationRules.deploymentRadius then return false end
        return self.stats.animals:CanPlace(unit,self.board,cell.q,cell.r,occupied,unit.Team==1 and self.board.allowed or nil)
    end)
    local result = {}
    for _, cell in ipairs(cells) do if cell.q ~= unit.Q or cell.r ~= unit.R then result[#result + 1] = cell end end
    return result,distance,previous
end
function Battle:OpportunityAttackers(actor)
    return OpportunityAttacks.Candidates(self,actor)
end
function Battle:TryMove(q, r,retreat)
    if self.morale:Fleeing(self:Active()) and not retreat then return false,LuaLanguage.MoraleCannotAct end
    Hex.CheckCoordinate(q, r)
    local cells,distance,previous=self:Reachable()
    for _, cell in ipairs(cells) do
        if cell.q == q and cell.r == r then
            local unit = self:Active()
            local template=self.stats:Template(unit)
            if OpportunityAttacks.Resolve(self,unit)>0 then
                -- 命令已经产生攻击结算；中断仍返回 true，保证上层处理真实伤亡和战斗结束。
                if self.data.Winner~='' then return true,'借机攻击结束了战斗，移动已中断' end
                if not Life.Alive(unit) then self:AdvanceTurn();return true,'角色在借机攻击中倒地，移动已中断' end
                if self.morale:Fleeing(unit) and not retreat then return true,LuaLanguage.MoraleCannotAct end
                if self.stats.buffs:Skipping(unit) then self:EndTurn();return true,'角色无法继续行动，移动已中断' end
                -- 坐骑死亡可能缩小移动距离或改变占地，使用结算后的真实状态重查路线。
                local remaining,newDistance,newPrevious=self:Reachable();local reachable=false
                for _,destination in ipairs(remaining) do if destination==cell then reachable=true;break end end
                if not reachable and retreat then
                    cell=self.morale:FleeDestination(self,unit,remaining);reachable=cell~=nil
                end
                if not reachable then return true,'借机攻击后无法到达目标，移动已中断' end
                distance=newDistance;previous=newPrevious
            end
            local destination,cost=self.professions:TrapOnPath(unit,cell,previous,distance)
            local path={destination};local step=destination
            while previous[step]do step=previous[step];table.insert(path,1,step)end
            CS.ProjectY.Data.BattleMovement.Move(unit,destination.q,destination.r,template.moveCost,cost,self.stats:MoveRange(unit,template))
            if self.legendary then self.legendary:Moved(unit,path,true)end
            self.spellcasting:OnPath(self,unit,path)
            self.professions:OnMoved(unit,true)
            self:Emit('moved', self.stats:Template(unit).name .. ' 移动', unit.Id)
            if not self:CheckWinner() and not Life.Alive(unit) then self:AdvanceTurn()end
            return true
        end
    end
    return false, '无法移动到这里：检查剩余移动距离、占格、行动点及是否已施放技能'
end
function Battle:SkillIds(actor)
    local ids=self.stats.animals:AddSkills(actor,self.stats.equipment:SkillIds(actor,self.stats:Template(actor)))
    if self.construction then
        local found=false;for _,id in ipairs(ids) do if id==self.construction.demolitionId then found=true end end
        if not found then ids[#ids+1]=self.construction.demolitionId end
    end
    ids=self.beasts:AddSkills(actor,self.professions:AddSkills(actor,ids))
    ids=self.legendary and self.legendary:AddSkills(actor,ids)or ids
    ids=self.spellcasting:AddSkills(actor,ids)
    return self.stats.skillCraft and self.stats.skillCraft:AddSkills(actor,ids) or ids
end
function Battle:Skill(actor,skillId)
    local skill=self.professions:Skill(actor,self.stats.buffs:ApplySkillModifiers(actor,self.stats.equipment:Skill(actor,skillId,self.stats)))
    skill=self.legendary and self.legendary:Skill(actor,skill)or skill
    skill=self.morale:Skill(actor,self.spellcasting:Resolve(actor,skill))
    if skill.crafted and not skill.craftWide and (skill.maxTargets>1 or skill.splashRadius>0)then
        skill.cost=skill.cost+1;skill.damageScale=skill.damageScale*.8;skill.craftWide=true
    end
    if skill.selectBodyPart then
        -- A body selection belongs to exactly one recipient, even with multi-target weapon modifiers.
        skill.maxTargets=1;skill.splashRadius=0;skill.manualTargets=false
    end
    return skill
end
function Battle:CastingBoost(skillId)return CS.ProjectY.Data.SpellcastingState.Boost(self:Active(),skillId)end
function Battle:SetCastingBoost(skillId,extra)
    if self.data.Winner~='' or self.data.Phase~='combat' and self.data.Phase~='deployment' then return false,LuaLanguage.SpellcastingNotActive end
    local actor=self:Active()
    if actor.Team~=1 or not Life.Alive(actor) then return false,LuaLanguage.SpellcastingNotActive end
    if type(extra)~='number' or not math.tointeger(extra)then return false,LuaLanguage.SpellcastingInvalidBoost end
    local known=false;for _,id in ipairs(self:SkillIds(actor))do if id==skillId then known=true;break end end
    if not known then return false,LuaLanguage.SpellcastingMissingRecipe end
    local skill=self:Skill(actor,skillId)
    if not skill.castingBoostLimit or extra<0 or extra>skill.castingBoostLimit then return false,LuaLanguage.SpellcastingInvalidBoost end
    CS.ProjectY.Data.SpellcastingState.SetBoost(actor,skillId,extra)
    self.Changed:Emit({kind='casting_boost',sourceId=actor.Id})
    return true
end
function Battle:DisarmChance(source,target,skill)
    local height=self.stats.heightAdvantage
    local heightBonus=height:Levels(assert(self.board:Find(source.Q,source.R)),assert(self.board:Find(target.Q,target.R)))*height.rule.hitPerLevel
    local speedBonus=2*(self.stats:Get(source,'speed')-self.stats:Get(target,'speed'))
    return math.max(0,math.min(100,skill.hitChance+heightBonus+speedBonus))
end
function Battle:ShotPreview(source,target,skill)
    local preview=Projectiles.Profile(self,source,skill,assert(self.board:Find(target.Q,target.R)),nil,target)
    if skill.id==self.stats.animals.rule.tameSkillId then
        local chance,values=self.stats.animals:TameChance(source,target,self.stats,self:IsHostile(source,target))
        preview.hitChance=chance;preview.interceptChance=0;preview.blockerCount=0;preview.friendlyRisk=false
        preview.advantageSources=values.advantageSources
        preview.description=string.format(values.advantageSources and #values.advantageSources>0 and
            LuaLanguage.AnimalTameAdvantagePreview or LuaLanguage.AnimalTamePreview,chance)
    elseif skill.id==501 then
        preview.hitChance=preview.reachable and self:DisarmChance(source,target,skill) or 0
        preview.description=string.format('缴械成功率 %.1f%%',preview.hitChance)
    end
    return {id=target.Id,hitChance=preview.hitChance,interceptChance=preview.interceptChance,blockerCount=preview.blockerCount,
        friendlyRisk=preview.friendlyRisk,description=preview.description,advantageSources=preview.advantageSources}
end
function Battle:ActionBudget(skill)
    if self.data.Winner ~= '' then return false, '战斗已经结束' end
    local source=self:Active()
    if self.morale:Fleeing(source) then return false,LuaLanguage.MoraleCannotAct end
    local blocked=self.data.Phase=='combat' and self.stats.buffs:Skipping(source)
    if blocked then return false,'受到「'..blocked.name..'」影响，无法行动' end
    local context=self.data.Phase=='deployment' and 'preparation' or 'battle'
    if not require('Game.Battle.SkillContext')(skill,context) then
        return false,self.data.Phase=='deployment' and '部署回合只能使用准备技能和道具' or '此技能不能在正式战斗中使用'
    end
    if skill.action == 'main' and source.MainUsed then return false, '本回合主要行动已使用' end
    if source.AP < skill.cost then return false, '行动点不足' end
    if skill.cooldownTurns>0 and source:GetCooldown(skill.id)>0 then return false,'技能冷却中：'..source:GetCooldown(skill.id) end
    local equipmentSkill=skill
    if skill.professionWeaponId then
        equipmentSkill={};for key,value in pairs(skill)do equipmentSkill[key]=value end
        equipmentSkill.skillGroup='support' -- The profession rule already selected and validates the actual weapon hand.
    end
    local allowed,reason=self.stats.equipment:CheckSkillEquipment(source,equipmentSkill,self.stats)
    if not allowed then return false,reason end
    local ready,why=self.stats.equipment:CheckAmmo(source,skill);if not ready then return false,why end
    local professionReady,professionReason=self.professions:Budget(source,skill)
    if not professionReady then return false,professionReason end
    local castingReady,castingReason=self.spellcasting:Budget(source,skill)
    if not castingReady then return false,castingReason end
    if self.legendary then return self.legendary:Budget(source,skill)end
    return true
end
function Battle:SkillBudget(skillId)
    if self.data.Winner ~= '' then return false, '战斗已经结束' end
    if require('Game.Progression.SkillCraft').IsCustom(skillId)then
        local valid,reason=self.stats.skillCraft:FindDefinition(self:Active(),skillId);if not valid then return false,reason end
    end
    local source=self:Active();local skill=self:Skill(source,skillId)
    if skill.skillKind=='item' then return false,'请从道具栏使用消耗品' end
    local owns = false
    for _, id in ipairs(self:SkillIds(source)) do if id == skillId then owns = true; break end end
    if not owns then return false, '角色没有这个技能' end
    local cavalry=self.stats.animals.bySkill[skillId]
    if cavalry and (not source.MountedAnimal or source.MountedAnimal.AnimalSpeciesId~=cavalry.speciesId) then
        return false,'需要骑乘'..self.stats.animals.species:Get(cavalry.speciesId).name
    end
    local allowed,reason=self:ActionBudget(skill)
    if not allowed then return false,reason end
    if self.construction and self.construction.definitions:Find(skillId) then return self.construction:Budget(source,skillId) end
    return true
end
function Battle:CanUseItem(itemId)
    local definition=self.consumables:Find(itemId)
    if not definition then return false,'这不是可使用的消耗品' end
    if self:Active().Team~=1 then return false,'等待己方行动' end
    local skill=self:Skill(self:Active(),definition.skillId)
    local allowed,reason=self:ActionBudget(skill)
    if not allowed then return false,reason end
    if self.stats.equipment.data:CountItem(itemId)<definition.count then return false,'背包中的道具数量不足' end
    local canBenefit=false
    for _,id in ipairs(skill.effectIds) do
        local effect=self.effects:Get(id)
        if effect.kind~='heal' or self:Active().HP<CS.ProjectY.Data.BodyHealth.RecoverableHP(self:Active()) then canBenefit=true end
    end
    if not canBenefit then return false,require('Language').BodyNoRecoverableHealth end
    return true
end
function Battle:TryItem(itemId)
    local allowed,reason=self:CanUseItem(itemId)
    if not allowed then return false,reason end
    local source=self:Active();local definition=self.consumables:Get(itemId)
    local skill=self:Skill(source,definition.skillId);local program={}
    for _,id in ipairs(skill.effectIds) do program[#program+1]=self.gameEffects:Prepare(id,source,source,skill,0) end
    source:SpendAction(skill.action,skill.cost)
    self.stats.equipment.data:ConsumeStack(itemId,definition.count)
    source:RecordAction(skill.actionTemplate,skill.shots,source.Q,source.R)
    for _,plan in ipairs(program) do assert(self.gameEffects:ApplyPrepared(plan)) end
    VisualEffects.Skill(self,source,skill,source,1,'cast')
    self:Emit('item_used',self.stats:Template(source).name..' 使用 '..self.stats.equipment.items:Get(itemId).name,source.Id)
    return true
end
function Battle:SkillRange(source,targetCell,skill)
    local bonus=self.construction and self.construction:RangeBonusAt(self.board,source,targetCell,skill) or 0
    if self.board.area then
        bonus=math.max(bonus,self.stats.heightAdvantage:RangeBonus(self.board:Find(source.Q,source.R),targetCell,skill))
    end
    return skill.range+bonus
end
function Battle:SkillInShape(source,skill,targetCell,targetParts)
    local origins=assert(self.stats.animals:Cells(source,self.board))
    return SkillShape.Footprints(skill.rangeShape,origins,targetParts or {targetCell},self:SkillRange(source,targetCell,skill),skill.minRange)
end
function Battle:SkillImpactCells(skill,center)
    if skill.manualTargets or skill.splashRadius==0 then return {} end
    local recipe=self.spellcasting.recipes:Find(skill.id)
    if skill.maxTargets<=1 and (not recipe or recipe.fieldKind=='')then return {} end
    return SkillShape.Cells(self.board,center,skill.splashShape,skill.splashRadius)
end
-- Spatial coverage only. Target allegiance, action budget and occupancy are checked on submission.
function Battle:SkillRangeCells(skillId)
    local source=self:Active();local skill=self:Skill(source,skillId)
    if skill.target=='cell' then return self:SkillCells(skillId) end
    local origins=assert(self.stats.animals:Cells(source,self.board))
    if skill.target=='self' then return origins end
    local origin=assert(self.board:Find(source.Q,source.R));local result={}
    for _,cell in ipairs(self.board.cells) do
        if not cell.blocked and (cell.layer or 0)==(origin.layer or 0) then
            if SkillShape.Footprints(skill.rangeShape,origins,{cell},self:SkillRange(source,cell,skill),skill.minRange)
                and Trajectory.CanReach(self.board,origin,cell,skill.trajectory,nil,skill.guided) then
                result[#result+1]=cell
            end
        end
    end
    return result
end
function Battle:CanUseSkill(skillId, targetId)
    local ok,reason=self:SkillBudget(skillId)
    if not ok then return false,reason end
    local source=self:Active();local skill=self:Skill(source,skillId)
    if skill.target=='cell' then return false,'请选择技能落点' end
    local target = self:FindUnit(targetId)
    if not target or not Life.Alive(target) then return false, '请选择存活的目标' end
    if skill.selectBodyPart and not self.stats:Template(target).bodyInjuries then return false,LuaLanguage.AnatomyCoreUnsupportedTarget end
    if skill.selectBodyPart and target.MountedAnimal then return false,LuaLanguage.AnatomyCoreMountedTarget end
    if skill.rangeShape~='hex' and not self:SkillInShape(source,skill,assert(self.board:Find(target.Q,target.R)),assert(self.stats.animals:Cells(target,self.board)))then
        return false,LuaLanguage.BattleOutsideSkillShape
    end
    if self.beasts:Handles(skillId)then return self.beasts:CanUse(source,skill,target)end
    if skill.legendaryKind=='beast'or skill.legendaryKind=='lance'then return self.legendary:CanUseMovement(source,skill,target)end
    if skillId==501 then
        if not self.board.area then return false,'缴械需要现场地图战斗' end
        if not self.stats.equipment:Weapon(target) and not self.stats.equipment:Offhand(target) then return false,'目标没有可缴获的武器' end
        local immunity=self.stats.growth:Immunity(target,'disarm')
        if immunity then
            local reason=self.stats:Template(target).name..' 拥有「'..immunity.name..'」，免疫缴械'
            return false,reason,{actionName=skill.name,statusName='缴械',reason=immunity.name..' · 免疫缴械，未消耗行动点',target=target}
        end
    elseif skillId==503 then
        local container,why=self:RecoverableWeapon(source)
        if not container then return false,why end
    end
    if skill.target == 'self' and target.Id ~= source.Id then return false, '只能对自己使用' end
    if skill.target == 'enemy' and not self:IsHostile(source,target) then return false, '请选择敌人' end
    if skill.target == 'ally' and not self:IsAllied(source,target) then return false, '请选择友军' end
    local distance=self.stats.animals:Distance(source,target,self.board)
    if self.animalSpeech and skillId==self.animalSpeech.rule.skillId then
        if self.animalSpeech.story.data.DialogueOpen then return false,require('Language').AnimalSpeechBusy end
        local can,why=self.animalSpeech:ValidTarget(target);if not can then return false,why end
        if target.AnimalOwnerId~=0 then return false,require('Language').AnimalSpeechBattleWildOnly end
    end
    if distance<skill.minRange then return false,'目标距离过近（至少 '..skill.minRange..' 格）' end
    if distance>self:SkillRange(source,assert(self.board:Find(target.Q,target.R)),skill) then return false,'目标超出射程' end
    if skillId==self.stats.animals.rule.tameSkillId then
        local tame,why=self.stats.animals:CanTame(source,target);if not tame then return false,why end
        local occupied=self:Occupied(source.Id)
        for key,value in pairs(occupied) do if value==target then occupied[key]=nil end end
        if not self.stats.animals:CanPlace(target,self.board,target.Q,target.R,occupied,self.board.allowed) then return false,'动物的占地不足以骑乘' end
    end
    if self.stats.animals.bySkill[skillId] then
        local landing,why=self.stats.animals:Landing(source,self.board:Find(target.Q,target.R),self.board,skillId,self:Occupied(source.Id),self.board.allowed)
        if not landing then return false,why end
    end
    local occupied=skill.trajectory~='sight' and self:ShotOccupancy(source,target) or nil
    if not Trajectory.CanReach(self.board,assert(self.board:Find(source.Q,source.R)),assert(self.board:Find(target.Q,target.R)),skill.trajectory,occupied,skill.guided) then
        return false, skill.trajectory=='sight' and '墙壁或陈设遮挡了目标' or '物体或角色遮挡了弹道'
    end
    local professionReady,professionReason=self.professions:CanUse(source,skill,target)
    if not professionReady then return false,professionReason end
    if self.legendary then return self.legendary:CanUse(source,skill,target)end
    return true
end
function Battle:TrySkillTargets(skillId,ids)
    local skill=self:Skill(self:Active(),skillId)
    if not skill.manualTargets then return false,'此技能当前不能手动选择多个目标' end
    if type(ids)~='table' or #ids<1 or #ids>skill.maxTargets then return false,'请选择 1 至 '..skill.maxTargets..' 名不同敌人' end
    local seen={}
    for _,id in ipairs(ids)do
        if type(id)~='number' or not math.tointeger(id) or seen[id]then return false,'目标无效或重复' end
        seen[id]=true;local ok,reason=self:CanUseSkill(skillId,id);if not ok then return false,reason end
    end
    return self:TrySkill(skillId,ids[1],ids)
end
function Battle:BodyPartOptions(skillId,targetId)
    local allowed=self:CanUseSkill(skillId,targetId)
    if not allowed or not self:Skill(self:Active(),skillId).selectBodyPart then return {} end
    local target=assert(self:FindUnit(targetId));local result={}
    for _,part in ipairs(self.stats.injuries.parts)do
        if CS.ProjectY.Data.BodyHealth.MaximumHP(target,part.index)>0 then result[#result+1]={id=part.index,name=part.name}end
    end
    return result
end
function Battle:TrySkillBodyPart(skillId,targetId,partIndex)
    if type(partIndex)~='number' or not math.tointeger(partIndex) or partIndex<0 or partIndex>5 then return false,LuaLanguage.AnatomyCoreInvalidPart end
    if not self:Skill(self:Active(),skillId).selectBodyPart then return false,LuaLanguage.AnatomyCoreNotTargetedSkill end
    return self:TrySkill(skillId,targetId,nil,nil,partIndex)
end
function Battle:TrySkill(skillId, targetId, selectedIds,selectedLanding,selectedBodyPart)
    return self:ObserveSkillUse(self:FindUnit(self.data.ActiveId),skillId,self.TrySkillInternal,skillId,targetId,selectedIds,selectedLanding,selectedBodyPart)
end
-- Capture sight and learning chance before effects move actors or clear battle fields.
-- Failed commands discard the snapshot; one successful action emits once even for multiple shots/targets.
function Battle:ObserveSkillUse(source,skillId,execute,...)
    local observer=self.specialSkillObserver
    local observation=observer and source and observer:CaptureUse(source,skillId)
    local inspection=self.stats.inspection
    local custom=require('Game.Progression.SkillCraft').IsCustom(skillId)
    local discovery=inspection and source and not custom and inspection:CaptureUse(source,skillId)
    local practice=self.stats.skillCraft and self.stats.skillCraft:CaptureUse(source,skillId,self.data.Phase)
    local ok,reason=execute(self,...)
    if ok then
        if inspection then inspection:CommitUse(discovery)end
        if observer then observer:CommitUse(observation)end
        if self.stats.skillCraft then self.stats.skillCraft:CommitUse(practice)end
        self.Changed:Emit({kind='skill_used',sourceId=assert(source).Id,skillId=skillId})
    end
    return ok,reason
end
function Battle:TrySkillInternal(skillId, targetId, selectedIds,selectedLanding,selectedBodyPart)
    local ok, reason,blocked = self:CanUseSkill(skillId, targetId)
    if not ok then
        if blocked then self:Emit('immune',reason,self:Active().Id,blocked.target.Id,0,blocked.target,false,blocked)end
        return false, reason
    end
    local source, target = self:Active(), self:FindUnit(targetId)
    local skill = self:Skill(source,skillId)
    if skill.selectBodyPart then
        if selectedIds then return false,LuaLanguage.AnatomyCoreInvalidPart end
        local options=self:BodyPartOptions(skillId,targetId)
        if #options==0 then return false,LuaLanguage.AnatomyCoreNoSelectablePart end
        if selectedBodyPart==nil and source.Team~=1 then
            selectedBodyPart=options[1].id
            for _,part in ipairs(options)do if part.id==3 then selectedBodyPart=part.id;break end end
        end
        if selectedBodyPart==nil then return false,LuaLanguage.AnatomyCoreSelectPart end
        local valid=false;for _,part in ipairs(options)do if part.id==selectedBodyPart then valid=true;break end end
        if not valid then return false,LuaLanguage.AnatomyCoreInvalidPart end
        skill.targetBodyPartIndex=selectedBodyPart
    elseif selectedBodyPart~=nil then return false,LuaLanguage.AnatomyCoreNotTargetedSkill end
    local recovered=self.spellcasting:UseRecovery(self,source,skill)
    if recovered~=nil then return recovered end
    if self.animalSpeech and skillId==self.animalSpeech.rule.skillId then
        self.professions:Commit(source,skill)
        source:SpendAction(skill.action,skill.cost);source:SetCooldown(skillId,skill.cooldownTurns)
        source:RecordAction(skill.actionTemplate,1,target.Q,target.R)
        VisualEffects.Skill(self,source,skill,target,1,'cast')
        local opened,why=self.animalSpeech:Open(source,target,'battle',true);assert(opened,why)
        self:Emit('animal_speech',require('Language').AnimalSpeechOpened,source.Id,target.Id)
        return true
    end
    if self.beasts:Handles(skillId)then return self.beasts:Use(source,skill,target,selectedLanding)end
    if self.legendary then
        local handled,legendaryReason=self.legendary:UseMovement(source,skill,target,selectedLanding)
        if handled~=nil then return handled,legendaryReason end
    end
    local legendaryPath
    if skill.legendaryKind=='hunt'then
        legendaryPath=self.legendary:SelectedPath(source,skill,target,selectedLanding)
        if not legendaryPath then return false,require('Language').ProfessionSelectLanding end
    end
    local profession=self.professions.rows:Find(skillId)
    if profession and profession.mechanic=='retreat' then
        local choices=self.professions:LandingCells(source,skill,target)
        if not selectedLanding and source.Team~=1 then selectedLanding=choices[1]end
        local valid=false;for _,cell in ipairs(choices)do if selectedLanding and cell.q==selectedLanding.q and cell.r==selectedLanding.r then valid=true;break end end
        if not valid then return false,require('Language').ProfessionSelectLanding end
    end
    if skillId==501 then
        local weapon=self.stats.equipment:Weapon(target) or self.stats.equipment:Offhand(target)
        local hitChance=self:DisarmChance(source,target,skill)
        self.professions:Commit(source,skill)
        source:SpendAction(skill.action,skill.cost);source:SetCooldown(skillId,skill.cooldownTurns);source:RecordAction(skill.actionTemplate,1,target.Q,target.R)
        self.stats.equipment:Consume(source,skill)
        local roll=self.data:RollPercent();local hit=roll<hitChance
        if self.checks then self.checks(source,target,skill,'缴械',hitChance,roll,hit,{successLabel='成功',failureLabel='失败'})end
        if hit then
            self.context.systems:Get('Equipment').worldLoot:Disarm(self.context.systems:Get('MapArea'),target,assert(weapon))
            self:Emit('disarmed',self.stats:Template(target).name..' 的武器落在脚下，可用拾取武器收回',source.Id,target.Id,0,target,false,{actionName=skill.name})
        else self:Emit('miss',self.stats:Template(source).name..' · 缴械未命中',source.Id,target.Id,0,target,false,{actionName=skill.name}) end
        VisualEffects.Skill(self,source,skill,target,1,hit and 'hit' or 'miss')
        return true
    elseif skillId==503 then
        local success,name=self.context.systems:Get('Equipment').worldLoot:Recover(self.context.systems:Get('MapArea'),source,self.stats)
        assert(success,name);self.professions:Commit(source,skill);source:SpendAction(skill.action,skill.cost)
        VisualEffects.Skill(self,source,skill,source,1,'cast')
        self:Emit('weapon_recovered',self.stats:Template(source).name..' 拾起并装备 '..name,source.Id);return true
    end
    if skillId==self.stats.animals.rule.tameSkillId then
        local visualSource=VisualEffects.Source(source)
        self.professions:Commit(source,skill)
        source:SpendAction(skill.action,skill.cost);source:SetCooldown(skillId,skill.cooldownTurns)
        local success,chance,roll,values,check=self.stats.animals:Tame(source,target,self.stats,self:IsHostile(source,target))
        if success and self.animalSpeech then self.animalSpeech:OnTamed(target)end
        if self.checks then self.checks(source,target,skill,'驯服',math.floor(chance*100)/100,roll,success,
            {check=check,successLabel=LuaLanguage.DiceSuccess,failureLabel=LuaLanguage.DiceFailure,comparison={{name='亲和',value=values.affinity},{name='魅力',value=values.charisma},{name='难度',value=values.difficulty}}})end
        self:Emit('tame',self.stats:Template(source).name..(success and ' 驯服并骑上了 ' or ' 未能驯服 ')..self.stats:Template(target).name..
            string.format('（成功率 %.0f%%）',chance),source.Id,target.Id)
        VisualEffects.Skill(self,visualSource,skill,target,1,success and 'hit' or 'miss')
        self:CheckWinner();return true
    end
    local landing,travel
    if self.stats.animals.bySkill[skillId] then
        landing,travel=self.stats.animals:Landing(source,self.board:Find(target.Q,target.R),self.board,skillId,self:Occupied(source.Id),self.board.allowed)
        assert(landing,'Cavalry landing changed after validation')
    end
    local targets={target}
    if not skill.manualTargets and skill.maxTargets>1
        and not SkillShape.Contains(skill.splashShape,target.Q,target.R,target.Q,target.R,skill.splashRadius,0)then targets={}end
    if selectedIds then
        targets={};for _,id in ipairs(selectedIds)do targets[#targets+1]=assert(self:FindUnit(id)) end
    elseif skill.maxTargets>1 and (not skill.manualTargets or source.Team~=1) then
        local others={}
        for _,unit in ipairs(self:Units()) do
            if unit.Id~=target.Id and (skill.manualTargets or SkillShape.Contains(skill.splashShape,target.Q,target.R,unit.Q,unit.R,skill.splashRadius,0))
                and self:CanUseSkill(skillId,unit.Id) then others[#others+1]=unit end
        end
        table.sort(others,function(a,b)
            local da,db=Hex.Distance(target.Q,target.R,a.Q,a.R),Hex.Distance(target.Q,target.R,b.Q,b.R)
            return da==db and a.Id<b.Id or da<db
        end)
        for i=1,math.min(#others,skill.maxTargets-#targets) do targets[#targets+1]=others[i] end
    end
    local containerPlans={}
    if not skill.manualTargets and self.containerCombat and skill.affectsContainers and self.board.area then
        containerPlans=self.containerCombat:Splash(source,skill,self.board:Find(target.Q,target.R),0,skill.maxTargets-#targets,self)
    end
    local program={}
    -- 先完整校验效果，配置错误不会在扣除行动点后才暴露。
    for _,victim in ipairs(targets) do
      for _, id in ipairs(skill.effectIds) do
        program[#program + 1] = self.gameEffects:Prepare(id,source,victim,skill,travel)
      end
    end
    self.professions:PrepareProgram(source,skill,target,program)
    if self.legendary then
        local legendaryReady,legendaryWhy=self.legendary:PrepareAction(source,skill,targets,program)
        if not legendaryReady then return false,legendaryWhy end
    end
    Projectiles.PrepareProgram(self,source,skill,program)
    if self.containerCombat then self.containerCombat:PrepareShots(containerPlans,source,skill,self) end
    self.professions:Commit(source,skill)
    source:SpendAction(skill.action, skill.cost)
    if landing then source:RelocateWithSkill(landing.q,landing.r,self.stats.animals.bySkill[skillId].movement);self.professions:OnMoved(source);self:Emit('moved','坐骑移动',source.Id) end
    self.professions:ConsumeEquipment(source,skill)
    source:SetCooldown(skillId,skill.cooldownTurns)
    source:RecordAction(skill.actionTemplate,skill.shots,target.Q,target.R)
    for shot=1,skill.shots do
    if self.containerCombat then self.containerCombat:Apply(containerPlans,source,skill,function()return self.data:RollPercent()end,self,shot) end
    self:ApplyEffectProgram(source,skill,program,shot)
    end
    if self.legendary then self.legendary:AfterAction(source,skill)end
    if legendaryPath and Life.Alive(source) then self.legendary:Walk(source,legendaryPath,false)
    elseif selectedLanding and Life.Alive(source) and self.professions:CanStep(source,selectedLanding,self:Occupied(source.Id)) then
        self.professions:Move(source,selectedLanding)
    end
    self:CheckWinner(); return true
end
function Battle:ApplyEffectProgram(source,skill,program,shot)
    Projectiles.ApplyProgram(self,source,skill,program,shot)
end
function Battle:RecoverableWeapon(actor)
    if not self.board.area then return nil,'拾取武器需要现场地图战斗' end
    return self.context.systems:Get('Equipment').worldLoot:Recoverable(self.context.systems:Get('MapArea'),actor,self.stats)
end
function Battle:CanRecoverWeapon(actor) return self:RecoverableWeapon(actor)~=nil end
function Battle:TryRecoverWeapon() return self:TrySkill(503,self:Active().Id) end
function Battle:CanUseSkillAt(skillId,q,r)
    local ok,reason=self:SkillBudget(skillId);if not ok then return false,reason end
    local source=self:Active();local skill=self:Skill(source,skillId)
    if skill.target~='cell' then return false,'此技能需要角色目标' end
    local cell=self.board:Find(q,r);if not cell then return false,'落点在战场之外' end
    if skill.rangeShape~='hex' and not self:SkillInShape(source,skill,cell)then return false,LuaLanguage.BattleOutsideSkillShape end
    local casting,castingWhy=self.spellcasting:CanUseAt(self,source,skill,cell);if casting~=nil then return casting,castingWhy end
    if self.beasts:Handles(skillId)then return self.beasts:CanUseAt(source,skill,q,r)end
    if self.legendary then
        local legendary,legendaryWhy=self.legendary:CanUseAt(source,skill,cell);if legendary~=nil then return legendary,legendaryWhy end
    end
    local profession,why=self.professions:CanUseAt(source,skill,cell);if profession~=nil then return profession,why end
    if self.construction and self.construction.definitions:Find(skillId) then return self.construction:CanUse(self,skill,cell) end
    local landing,why=self.stats.animals:Landing(source,cell,self.board,skillId,self:Occupied(source.Id),self.board.allowed)
    return landing~=nil,why
end
function Battle:SkillCells(skillId)
    local cells={}
    if self:Skill(self:Active(),skillId).target~='cell' then return cells end
    for _,cell in ipairs(self.board.cells) do if self:CanUseSkillAt(skillId,cell.q,cell.r) then cells[#cells+1]=cell end end
    return cells
end
function Battle:TrySkillAt(skillId,q,r)
    return self:ObserveSkillUse(self:FindUnit(self.data.ActiveId),skillId,self.TrySkillAtInternal,skillId,q,r)
end
function Battle:TrySkillAtInternal(skillId,q,r)
    Hex.CheckCoordinate(q,r)
    local ok,reason=self:CanUseSkillAt(skillId,q,r);if not ok then return false,reason end
    local source=self:Active();local skill=self:Skill(source,skillId)
    local recipe=self.spellcasting.recipes:Find(skillId)
    if recipe and recipe.fieldKind~='' then return self.spellcasting:UseAt(self,source,skill,assert(self.board:Find(q,r)))end
    if self.beasts:Handles(skillId)then return self.beasts:UseAt(source,skill,q,r)end
    if self.legendary and self.legendary:NeedsCellLanding(skillId)then
        if source.Team==1 then return false,require('Language').ProfessionSelectLanding end
        local origin=self.board:Find(q,r);local landing=self.legendary:ConstructionLandings(source,skill,origin)[1]
        return self.legendary:UseAtWithLanding(source,skill,origin,landing)
    end
    local row=self.professions.rows:Find(skillId)
    if row and (row.mechanic=='trap' or row.mechanic=='salvage')then return self.professions:UseAt(source,skill,assert(self.board:Find(q,r)))end
    local visualSource=VisualEffects.Source(source)
    if self.construction and self.construction.definitions:Find(skillId) then
        self.construction:Apply(self,skill,assert(self.board:Find(q,r)))
        self.professions:Commit(source,skill)
        source:SpendAction(skill.action,skill.cost);source:SetCooldown(skillId,skill.cooldownTurns)
        source:RecordAction(skill.actionTemplate,skill.shots,q,r)
        VisualEffects.Skill(self,visualSource,skill,nil,1,'cast',{q=q,r=r})
        return true
    end
    self.professions:Commit(source,skill)
    source:SpendAction(skill.action,skill.cost);source:SetCooldown(skillId,skill.cooldownTurns)
    source:RelocateWithSkill(q,r,self.stats.animals.bySkill[skillId].movement);source:RecordAction(skill.actionTemplate,skill.shots,q,r)
    self.professions:OnMoved(source)
    self:Emit('moved',self.stats:Template(source).name..' · '..skill.name,source.Id)
    VisualEffects.Skill(self,visualSource,skill,nil,1,'cast',{q=q,r=r})
    return true
end
function Battle:NeedsSkillLanding(skillId)
    local row=self.professions.rows:Find(skillId)
    return row and row.mechanic=='retreat' or self.beasts:NeedsLanding(skillId)or self.legendary and self.legendary:NeedsLanding(skillId)
end
function Battle:SkillLandingCells(skillId,targetId)
    local ok=self:CanUseSkill(skillId,targetId);if not ok then return {}end
    local source,skill,target=self:Active(),self:Skill(self:Active(),skillId),self:FindUnit(targetId)
    if self.beasts:Handles(skillId)then return self.beasts:LandingCells(source,skill,target)end
    if self.legendary and self.legendary:NeedsLanding(skillId)then return self.legendary:LandingCells(source,skill,target)end
    return self.professions:LandingCells(source,skill,target)
end
function Battle:TrySkillWithLanding(skillId,targetId,q,r)
    Hex.CheckCoordinate(q,r)
    if not self:NeedsSkillLanding(skillId)then return false,require('Language').ProfessionNoLandingAction end
    local cell=self.board:Find(q,r);if not cell then return false,require('Language').ProfessionNoLanding end
    return self:TrySkill(skillId,targetId,nil,cell)
end
function Battle:NeedsCellLanding(skillId)return self.legendary:NeedsCellLanding(skillId)end
function Battle:CellLandingCells(skillId,q,r)
    if not self:NeedsCellLanding(skillId)or not self:CanUseSkillAt(skillId,q,r)then return {}end
    return self.legendary:ConstructionLandings(self:Active(),self:Skill(self:Active(),skillId),self.board:Find(q,r))
end
function Battle:TrySkillAtWithLanding(skillId,fromQ,fromR,toQ,toR)
    return self:ObserveSkillUse(self:FindUnit(self.data.ActiveId),skillId,self.TrySkillAtWithLandingInternal,skillId,fromQ,fromR,toQ,toR)
end
function Battle:TrySkillAtWithLandingInternal(skillId,fromQ,fromR,toQ,toR)
    Hex.CheckCoordinate(fromQ,fromR);Hex.CheckCoordinate(toQ,toR)
    local ok,why=self:CanUseSkillAt(skillId,fromQ,fromR);if not ok then return false,why end
    if not self:NeedsCellLanding(skillId)then return false,require('Language').ProfessionNoLandingAction end
    local landing=self.board:Find(toQ,toR);if not landing then return false,require('Language').ProfessionNoLanding end
    return self.legendary:UseAtWithLanding(self:Active(),self:Skill(self:Active(),skillId),self.board:Find(fromQ,fromR),landing)
end
-- AI 通过同一套移动/技能命令执行；盟军保持独立队伍，绝不获得玩家控制权。
function Battle:ApproachCells(actor,target)
    local attacks={};local needsSpacing=false
    for _,id in ipairs(self:SkillIds(actor)) do
        local skill=self:Skill(actor,id)
        if skill.target=='enemy' and self:SkillBudget(id) then
            attacks[#attacks+1]=skill;needsSpacing=needsSpacing or skill.minRange>1 or skill.rangeShape~='hex'
        end
    end
    if not needsSpacing then return self.board:Neighbors(assert(self.board:Find(target.Q,target.R))) end
    local result={};local targetCell=assert(self.board:Find(target.Q,target.R))
    local targetParts=assert(self.stats.animals:Cells(target,self.board))
    for _,cell in ipairs(self.board.cells) do
        local parts=self.stats.animals:Cells(actor,self.board,cell.q,cell.r,cell.layer)
        if parts then
            for _,skill in ipairs(attacks) do
                local bonus=self.board.area and self.stats.heightAdvantage:RangeBonus(cell,targetCell,skill) or 0
                if self.construction then bonus=math.max(bonus,self.construction:RangeBonusAt(self.board,{Q=cell.q,R=cell.r},targetCell,skill))end
                if SkillShape.Footprints(skill.rangeShape,parts,targetParts,skill.range+bonus,skill.minRange) and Trajectory.CanReach(self.board,cell,targetCell,skill.trajectory,nil,skill.guided) then
                    result[#result+1]=cell;break
                end
            end
        end
    end
    return result
end
function Battle:StepAI()
    if self.data.Winner ~= '' then return false, '战斗已经结束' end
    if self.data.Phase=='deployment' then return false,'部署期间敌人不会行动' end
    local actor = self:Active()
    local round = self.data.Round
    if actor.Team == 1 then return false, '等待玩家行动' end
    local enemies={}
    for _,target in ipairs(self:Units()) do
        if Life.Alive(target) and self:IsHostile(actor,target) then enemies[#enemies+1]=target end
    end
    if #enemies==0 then return self:EndTurn() end
    if AllySelfPreservation.Step(self,actor,enemies) then return true end
    table.sort(enemies,function(a,b)
        local da,db=self.stats.animals:Distance(actor,a,self.board),self.stats.animals:Distance(actor,b,self.board)
        if da~=db then return da<db end
        if a.HP~=b.HP then return a.HP<b.HP end
        return a.Id<b.Id
    end)
    if self:CanUseSkill(503,actor.Id) then self:TryRecoverWeapon() end
    local function attack()
        for _,target in ipairs(enemies) do
            if self.stats.equipment:Weapon(target) and self:CanUseSkill(501,target.Id) then return self:TrySkill(501,target.Id) end
        end
        for _, skillId in ipairs(self:SkillIds(actor)) do
            if self:Skill(actor,skillId).target == 'enemy' then
                for _, target in ipairs(enemies) do
                    if self:CanUseSkill(skillId, target.Id) then return self:TrySkill(skillId, target.Id) end
                end
            end
        end
        return false
    end
    if not attack() then
        local occupied = self:Occupied(actor.Id)
        local _, distance, previous = self.board:Search(actor.Q, actor.R, occupied, #self.board.cells*4,function(cell)
            return self.stats.animals:CanPlace(actor,self.board,cell.q,cell.r,occupied)
        end)
        local bestPath
        for _, target in ipairs(enemies) do
            if Life.Alive(target) then
                for _, cell in ipairs(self:ApproachCells(actor,target)) do
                    if previous[cell] then
                        local path, cursor = {}, cell
                        while previous[cursor] do table.insert(path, 1, cursor); cursor = previous[cursor] end
                        if not bestPath or distance[cell] < distance[bestPath[#bestPath]] then bestPath = path end
                    end
                end
            end
        end
        if bestPath then
            local destination;local range=CS.ProjectY.Data.BattleMovement.Remaining(actor,self.stats:MoveRange(actor,self.stats:Template(actor)))
            for _,cell in ipairs(bestPath) do if distance[cell]<=range then destination=cell end end
            if destination then
                self:TryMove(destination.q, destination.r)
                if self.data.Winner~='' or self.data.ActiveId~=actor.Id or self.data.Round~=round then return true end
            end
        elseif self.construction and self.board.area then
            -- 通路被施工封死时，接近可达的工事边缘并破坏；不会绕过正常行动预算。
            local best,approach,score
            for _,cell in ipairs(self.board.cells) do
                local record=self.construction:Record(self.board.area.constructionSite,cell.index)
                if record and record.MaxHP>0 then
                    for _,neighbor in ipairs(self.board:Neighbors(cell)) do
                        local cost=distance[neighbor]
                        if cost and (not score or cost<score) then best,approach,score=cell,neighbor,cost end
                    end
                end
            end
            if best then
                local cursor=approach;local range=CS.ProjectY.Data.BattleMovement.Remaining(actor,self.stats:MoveRange(actor,self.stats:Template(actor)))
                while previous[cursor] and distance[cursor]>range do cursor=previous[cursor] end
                if cursor.q~=actor.Q or cursor.r~=actor.R then
                    self:TryMove(cursor.q,cursor.r)
                    if self.data.Winner~='' or self.data.ActiveId~=actor.Id or self.data.Round~=round then return true end
                end
                self:TrySkillAt(self.construction.demolitionId,best.q,best.r)
            end
        end
        attack()
    end
    if self.data.Winner ~= '' then return true end
    for _, skillId in ipairs(self:SkillIds(actor)) do
        local target=self:Skill(actor,skillId).target
        if (target=='self' or target=='any') and self:CanUseSkill(skillId, actor.Id) then self:TrySkill(skillId, actor.Id); break end
    end
    return self:EndTurn()
end
function Battle:OnShutdown()
    VisualEffects.Clear(self)
    -- 注册器也会回收 OnInit 尚未完成的实例；只释放已经取得的资源。
    if self.Changed then self.Changed:Clear(); self.Changed = nil end
    self.board = nil
    if self.data then self.data:Clear(); self.data = nil end
end
return Battle
