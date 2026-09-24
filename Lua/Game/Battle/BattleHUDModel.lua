-- A disposable presentation snapshot. The battle and party actors remain authoritative C# Data.
local L = require('Language')
local Model = {}
function Model.Build(battle, adventure)
    local data, actor = battle.data, battle:Active()
    local template = battle.stats:Template(actor)
    local player = actor.Team == 1 and data.Winner == ''
    local result = { actorId = actor.Id, name = template.name, hp = actor.HP, maxHP = actor.MaxHP,
        ap = actor.AP, maxAP = template.actionPoints, defense = battle.stats:Get(actor, 'defense'), guard = actor.Guard,
        moved = actor.Moved, mainUsed = actor.MainUsed, player = player, round = data.Round,
        maxRounds = data.MaxRounds, encounter = battle.encounters:Get(data.EncounterId).name,
        moveAvailable = player and #battle:Reachable() > 0, skills = {}, party = {}, turns = {}, logs = {} }
    local units = battle:Units()
    local weapon=battle.stats.equipment:Weapon(actor)
    local magazine=battle.stats.equipment:Loaded(weapon)
    result.ammo=magazine and ('弹匣 '..magazine.Rounds..'/'..magazine.Capacity) or (weapon and battle.stats.equipment.weapons:Get(weapon.ItemId).kind=='gun' and '未装弹匣' or '')
    for _, id in ipairs(battle:SkillIds(actor)) do
        local skill = battle:Skill(actor,id)
        local reason, available = '', false
        local budget,budgetReason=battle:SkillBudget(id)
        if not player then reason = L.BattleEnemyTurn
        elseif not budget then reason=budgetReason
        else
            for _, target in ipairs(units) do
                if battle:CanUseSkill(id, target.Id) then available = true; break end
            end
            if not available then reason = L.BattleNoTarget end
        end
        local detail=string.format('\n命中 %d%% · 伤害倍率 %.2f · 最多 %d 目标 · CD %d（剩余 %d）',skill.hitChance,skill.damageScale,skill.maxTargets,skill.cooldownTurns,actor:GetCooldown(id))
        if skill.ammoPerShot>0 then detail=detail..' · 耗弹 '..skill.shots*skill.ammoPerShot end
        result.skills[#result.skills + 1] = { id = id, iconId = skill.iconId, name = skill.name, description = skill.description..detail,
            action = skill.action, cost = skill.cost, range = skill.range, target = skill.target,
            available = available, reason = reason }
    end
    local function unitView(unit)
        return { id = unit.Id, name = battle.stats:Template(unit).name, hp = unit.HP, maxHP = unit.MaxHP,
            active = unit.Id == actor.Id, team = unit.Team, speed = battle.stats:Get(unit, 'speed') }
    end
    for i = 0, adventure.PartyCount - 1 do result.party[#result.party + 1] = unitView(adventure:GetPartyAt(i)) end
    for i = 0, data.TurnCount - 1 do
        local unit = assert(battle:FindUnit(data:GetTurnAt(i)))
        if unit.HP > 0 then
            local row = unitView(unit); row.acted = i < data.TurnIndex
            result.turns[#result.turns + 1] = row
        end
    end
    for i = math.max(0, data.LogCount - 5), data.LogCount - 1 do result.logs[#result.logs + 1] = data:GetLogAt(i) end
    return result
end
return Model
