local Life=require('Game.Battle.ActorLife')
local LuaLanguage = require('Language')
-- A disposable presentation snapshot. The battle and party actors remain authoritative C# Data.
local L = require('Language')
local Identity=require('Game.Presentation.CharacterIdentity')
local Model = {}
function Model.Build(battle, adventure)
    local data, actor = battle.data, battle:Active()
    battle.stats.spellcasting:Sync(actor)
    local casting=CS.ProjectY.Data.SpellcastingState
    local template = battle.stats:Template(actor)
    local player = actor.Team == 1 and data.Winner == ''
    local result = { actorId = actor.Id, name = template.name, hp = actor.HP, maxHP = actor.MaxHP,
        ap = actor.AP, maxAP = template.actionPoints, defense = battle.stats:Get(actor, 'defense'), guard = actor.Guard,
        castingPoints=casting.Current(actor),castingPointMax=casting.Maximum(actor),castingPointRegen=casting.Regen(actor),
        castingKnown=not battle.stats.inspection or battle.stats.inspection:Known(actor,'casting'),
        moved = actor.Moved, mainUsed = actor.MainUsed, player = player, round = data.Round, phase=data.Phase,
        moveRemaining=CS.ProjectY.Data.BattleMovement.Remaining(actor,battle.stats:MoveRange(actor,template)),
        maxRounds = data.MaxRounds, encounter = battle.encounters:Get(data.EncounterId).name,
        moveAvailable = player and #battle:Reachable() > 0, skills = {}, items={}, party = {}, turns = {}, logs = {} }
    if battle.board.protectedActorId then
        local ally=assert(battle:FindUnit(battle.board.protectedActorId),'Protected battle actor is missing')
        local health=(not battle.stats.inspection or battle.stats.inspection:Known(ally,'health')) and (ally.HP..'/'..ally.MaxHP)or LuaLanguage.InspectionUnknown
        result.encounter=result.encounter..' · '..battle.stats:Template(ally).name..' '..health
    end
    if actor.MountedAnimal then
        local mount=actor.MountedAnimal
        result.name=result.name..' · '..battle.stats:Template(mount).name
        result.hp=mount.HP;result.maxHP=mount.MaxHP
    end
    local units = battle:Units()
    local weapon=battle.stats.equipment:Weapon(actor)
    local magazine=battle.stats.equipment:Loaded(weapon)
    result.ammo=magazine and string.format(LuaLanguage.BattleAmmoSummary,battle.stats.equipment.ammunition:Get(magazine.AmmoItemId).name,magazine.Rounds,magazine.Capacity)
        or (weapon and battle.stats.equipment.weapons:Get(weapon.ItemId).kind=='gun' and LuaLanguage.UIBattleHUDAmmo or '')
    for _, id in ipairs(battle:SkillIds(actor)) do
        local known=not battle.stats.inspection or battle.stats.inspection:Known(actor,'skill:'..id)
        if known then
        local skill = battle:Skill(actor,id)
        if skill.skillKind~='item' and require('Game.Battle.SkillContext')(skill,data.Phase=='deployment' and 'preparation' or 'battle') then
        local reason, available = '', false
        local budget,budgetReason=battle:SkillBudget(id)
        if not player then reason = L.BattleEnemyTurn
        elseif not budget then reason=budgetReason
        else
            if skill.target=='cell' then available=#battle:SkillCells(id)>0 end
            for _, target in ipairs(units) do
                if battle:CanUseSkill(id, target.Id) then available = true; break end
            end
            if not available and battle.containerCombat then available=#battle.containerCombat:Targets(actor,id,battle)>0 end
            if not available then reason = L.BattleNoTarget end
        end
        result.skills[#result.skills + 1] = { id = id, iconId = skill.iconId, name = skill.name, description = skill.description,
            skill=skill,cooldown=actor:GetCooldown(id),
            action = skill.action, cost = skill.cost, range = skill.range, target = skill.target,
            available = available, reason = reason }
        end
        end
    end
    assert(#battle.consumables:All()<=4,'Battle HUD supports four configured consumable types')
    for _,definition in ipairs(battle.consumables:All()) do
        local skill=battle:Skill(actor,definition.skillId)
        local count=battle.stats.equipment.data:CountItem(definition.id)
        local available,reason=battle:CanUseItem(definition.id)
        result.items[#result.items+1]={id=definition.id,iconId=skill.iconId,name=battle.stats.equipment.items:Get(definition.id).name..' ×'..count,
            description=skill.description,skill=skill,cooldown=0,action=skill.action,cost=skill.cost,range=0,target='self',count=count,
            available=player and available,reason=not player and L.BattleEnemyTurn or reason}
    end
    local function unitView(unit)
        return { id = unit.Id, name = battle.stats:Template(unit).name, identity=Identity.Read(battle.stats,unit), hp = unit.HP, maxHP = unit.MaxHP,
            healthKnown=not battle.stats.inspection or battle.stats.inspection:Known(unit,'health'),
            speedKnown=not battle.stats.inspection or battle.stats.inspection:Known(unit,'attribute:speed'),
            alive=Life.Alive(unit),deathDoor=Life.Entered(unit),dead=Life.Dead(unit),
            active = unit.Id == actor.Id, team = battle:PresentationTeam(unit), speed = battle.stats:Get(unit, 'speed') }
    end
    for i = 0, adventure.PartyCount - 1 do result.party[#result.party + 1] = unitView(adventure:GetPartyAt(i)) end
    for offset = 0, data.TurnCount - 1 do
        local i=(data.TurnIndex+offset)%data.TurnCount
        local unit = assert(battle:FindUnit(data:GetTurnAt(i)))
        if Life.Alive(unit) and unit.AnimalOwnerId==0 and (data.Phase~='deployment' or i>=data.TurnIndex) then
            local row = unitView(unit); row.acted = false;row.nextRound=i<data.TurnIndex
            result.turns[#result.turns + 1] = row
        end
    end
    for i = 0, data.LogCount - 1 do result.logs[#result.logs + 1] = data:GetLogAt(i) end
    return result
end
return Model
