-- 由 Project Y/远征/验证战斗与事件 运行；使用真实 C# Data 和导出配置，无场景/Play 操作。
local Registry = require('Core.SystemRegistry')
local registry = Registry(Services)
registry:Register('Config', require('Config.ConfigSystem'))
registry:Register('PlayerModel', require('Game.PlayerModelSystem'), {'Config'})
registry:Register('Map', require('Game.Map.MapSystem'), {'Config'})
registry:Register('MapArea', require('Game.MapArea.MapAreaSystem'), {'Config'})
registry:Register('Battle', require('Game.Battle.BattleSystem'), {'Config'})
registry:Register('AdventureEvents', require('Game.Adventure.EventSystem'), {'Battle', 'PlayerModel'})
registry:Register('Equipment',require('Game.Equipment.EquipmentSystem'),{'Config'})
registry:Register('Adventure', require('Game.Adventure.AdventureSystem'), {'Map', 'MapArea', 'AdventureEvents', 'Equipment'})
local count, messages = 0, {}
local function test(name, run)
    run(); count = count + 1; messages[#messages + 1] = 'PASS ' .. name
end
local function throws(run)
    local ok = pcall(run); assert(not ok, 'Expected contract rejection')
end
local ok, err = xpcall(function()
    registry:Start()
    local adventure, battle, events = registry:Get('Adventure'), registry:Get('Battle'), registry:Get('AdventureEvents')
    local data, player = Services.Adventure, Services.Player
    test('C# actor rejects overspending without mutation; healing cannot resurrect', function()
        local actor = CS.ProjectY.Data.CombatActorData(99, 1)
        actor:SetMaxHP(40); actor:Restore(); actor:BeginTurn(4)
        throws(function() actor:SpendAction('main', 5) end); assert(actor.AP == 4 and not actor.MainUsed)
        actor:SpendAction('main', 2)
        throws(function() actor:SpendAction('main', 1) end); assert(actor.AP == 2)
        actor:Damage(100); assert(actor.HP == 0 and actor:Heal(5) == 0)
        actor:Restore(); assert(actor.HP == 40)
        actor:AddTrait(1); actor:AddTrait(1); assert(actor.TraitCount == 1)
    end)
    test('adventure sites refer to the actual generated map; unavailable choice leaves state intact', function()
        adventure:Start()
        assert(data.PartyCount == 4 and #adventure.sites >= 3)
        for _, site in ipairs(adventure.sites) do
            local cell = adventure.map:GetCell(site.q, site.r)
            assert(not cell.waterLevel)
        end
        -- 独立补给事件夹具复用真实选项条件，不依赖生成时是否出现集会厅。
        assert(events:Begin({id = 999, eventId = 4}))
        assert(not adventure:Choose(5)); assert(player.Coins == 0 and data.Phase == 'event')
        assert(not adventure:Choose(1)) -- 不属于当前事件的选项
        assert(adventure:Choose(3)); assert(adventure:ReturnToMap())
    end)
    test('event rewards apply once and trait state is shared with battle', function()
        assert(adventure:Visit(3)); assert(adventure:Choose(2))
        assert(player.Coins == 12 and data:GetPartyAt(0).TraitCount == 1)
        assert(not adventure:Choose(2)); assert(player.Coins == 12)
        assert(adventure:ReturnToMap()); assert(not adventure:Visit(3))
        assert(adventure:Visit(1)); assert(adventure:Choose(4)); assert(adventure:ReturnToMap())
        assert(data:GetPartyAt(0).TraitCount == 2)
    end)
    test('move, range, ownership and action budgets use the same C# battle state', function()
        assert(adventure:Visit(2)); assert(adventure:Choose(1))
        local actor = battle:Active(); assert(actor.Team == 1 and actor.TemplateId == 2)
        local before = actor.AP
        assert(not adventure:BattleCommand('skill', 1, 101)); assert(actor.AP == before) -- 不拥有斩击
        assert(not adventure:BattleCommand('skill', 2, 101)); assert(actor.AP == before) -- 距离过远
        assert(not adventure:BattleCommand('skill', 2, actor.Id)) -- 不能攻击友军
        assert(not adventure:BattleCommand('move', 99, 99)); assert(actor.AP == before)
        local reachable = battle:Reachable(); assert(#reachable > 0)
        assert(adventure:BattleCommand('move', reachable[1].q, reachable[1].r))
        assert(actor.Moved and actor.AP == before - 1)
        assert(not adventure:BattleCommand('move', reachable[2].q, reachable[2].r))
        assert(adventure:BattleCommand('skill', 4, actor.Id)); assert(actor.Guard == 3)
        assert(adventure:BattleCommand('end_turn'))
        if battle:Active().Team == 2 then
            local enemyAP = battle:Active().AP
            assert(not adventure:BattleCommand('end_turn')); assert(battle:Active().AP == enemyAP)
        end
    end)
    test('player commands and enemy AI finish a battle and settle rewards only once', function()
        local Hex = require('Game.Map.HexGrid')
        local function tryAttack()
            for _, skillId in ipairs(battle.stats:Template(battle:Active()).skillIds) do
                if battle.skills:Get(skillId).target == 'enemy' then
                    for _, target in ipairs(battle:Units()) do
                        if battle:CanUseSkill(skillId, target.Id) then return adventure:BattleCommand('skill', skillId, target.Id) end
                    end
                end
            end
            return false
        end
        local steps = 0
        while data.Phase == 'battle' and steps < 180 do
            steps = steps + 1
            local actor = battle:Active()
            if actor.Team == 2 then assert(adventure:BattleCommand('ai'))
            else
                if not tryAttack() then
                    local best, score
                    for _, cell in ipairs(battle:Reachable()) do
                        for _, target in ipairs(battle:Units()) do
                            if target.HP > 0 and target.Team == 2 then
                                local distance = Hex.Distance(cell.q, cell.r, target.Q, target.R)
                                if not score or distance < score then best, score = cell, distance end
                            end
                        end
                    end
                    if best then assert(adventure:BattleCommand('move', best.q, best.r)) end
                    tryAttack()
                end
                if data.Phase == 'battle' then
                    if battle:CanUseSkill(4, actor.Id) then assert(adventure:BattleCommand('skill', 4, actor.Id)) end
                    assert(adventure:BattleCommand('end_turn'))
                end
            end
        end
        assert(data.Phase == 'result' and data.Battle.Winner == 'victory', 'Demo strategy failed: ' .. data.Battle.Winner)
        assert(player.Coins == 47)
        assert(not adventure:BattleCommand('ai')); assert(not adventure:Choose(1)); assert(player.Coins == 47)
        assert(#adventure:Snapshot().units == data.PartyCount + 3)
        assert(adventure:ReturnToMap()); assert(data.Battle.UnitCount == 0 and not adventure:Visit(2))
    end)
    test('camp restores defeated characters; guard expires at next turn; dead turns are skipped', function()
        local actor = data:GetPartyAt(0); actor:Damage(actor.HP)
        assert(adventure:Visit(1)); assert(adventure:Choose(4)); assert(actor.HP == actor.MaxHP); assert(adventure:ReturnToMap())
        local party = events:LivingParty(); battle:Start(1, party, 47)
        local current = battle:Active(); current:SetGuard(3); current:BeginTurn(4); assert(current.Guard == 0)
        local nextId = data.Battle:GetTurnAt(1); battle:FindUnit(nextId):Damage(1000000)
        assert(battle:EndTurn()); assert(data.Battle.ActiveId ~= nextId)
    end)
    test('defeat and round limit produce no victory rewards', function()
        for _, actor in ipairs(battle:Units()) do if actor.Team == 1 then actor:Damage(1000000) end end
        assert(battle:CheckWinner()); assert(data.Battle.Winner == 'defeat' and player.Coins == 47)
        for i = 0, data.PartyCount - 1 do data:GetPartyAt(i):Restore() end
        battle:Start(1, events:LivingParty(), 1)
        while data.Battle.Round < data.Battle.MaxRounds do battle:NewRound() end
        battle:NewRound(); assert(data.Battle.Winner == 'draw' and player.Coins == 47)
    end)
end, debug.traceback)
registry:Shutdown()
if not ok then error(err, 0) end
return 'Adventure integration: ' .. count .. ' checks passed\n' .. table.concat(messages, '\n')
