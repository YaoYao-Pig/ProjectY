-- 无 Editor 的最小检查：真实配表、战场连通、阻挡与属性公式。
package.path = 'Lua/?.lua;' .. package.path
local Board = require('Game.Battle.BattleBoard')
local Hex = require('Game.Map.HexGrid')
local Config = require('Config.ConfigSystem')
local config = Config()
config:OnInit({services = {ReadConfig = function(_, name)
    local file = assert(io.open('Assets/GameFramework/Resources/_Gen/Config/' .. name .. '.bytes', 'rb'))
    local bytes = file:read('*a'); file:close(); return bytes
end}})
local count = 0
local function test(name, run) run(); count = count + 1; print('PASS ' .. name) end
test('battle generation is deterministic and does not advance the global RNG', function()
    local function signature(board)
        local result = {}; for _, cell in ipairs(board.cells) do result[#result + 1] = Hex.Key(cell.q, cell.r) .. tostring(cell.blocked) end
        return table.concat(result, '|')
    end
    math.randomseed(17); local first, second = math.random(), math.random()
    math.randomseed(17); assert(math.random() == first)
    local a = signature(Board.Create(4, 20260922, .2))
    assert(math.random() == second)
    assert(a == signature(Board.Create(4, 20260922, .2)))
    assert(a ~= signature(Board.Create(4, 20260923, .2)))
end)
test('generated boards preserve all deployment slots and connected walkable cells', function()
    for _, radius in ipairs({3, 4, 7}) do
        local board = Board.Create(radius, 89, .4)
        assert(#board.cells == 1 + 3 * radius * (radius + 1))
        local _, distances = board:Search(-radius, 0, {}, #board.cells)
        for _, cell in ipairs(board.cells) do assert(cell.blocked or distances[cell], 'Disconnected floor') end
        for i = 0, 3 do assert(not board:Find(-radius, i).blocked and not board:Find(radius, -i).blocked) end
    end
end)
test('path search respects blockers, occupied cells and movement budget', function()
    local board = Board.Create(3, 1, 0)
    local occupied = {}
    for r = -3, 3 do occupied[Hex.Key(0, r)] = true end
    local _, distance = board:Search(-2, 0, occupied, 20)
    assert(distance[board:Find(-1, 0)] == 1 and distance[board:Find(1, 0)] == nil)
    local _, limited = board:Search(-2, 0, {}, 1)
    assert(limited[board:Find(-1, 0)] == 1 and limited[board:Find(0, 0)] == nil)
end)
test('real unit, skill, effect and event tables agree and trait modifiers affect formulas', function()
    local stats = require('Game.Battle.CombatStats')(config)
    local source = {TemplateId = 1, TraitCount = 0, Guard = 0}
    local target = {TemplateId = 4, TraitCount = 0, Guard = 0}
    local skill = config:GetTable('CombatSkillTable'):Get(1)
    local effect = config:GetTable('CombatEffectTable'):Get(skill.effectIds[1])
    local original = effect.amount:Evaluate(stats:EffectVariables(source, target, skill))
    assert(stats:MaximumHP(source) == 46 and original == 15)
    source.TraitCount = 1; function source:GetTraitAt() return 1 end
    assert(effect.amount:Evaluate(stats:EffectVariables(source, target, skill)) == original + 2)
    target.Guard = 3
    assert(effect.amount:Evaluate(stats:EffectVariables(source, target, skill)) == original - 1)
    assert(stats:Get(source, 'cooking') == 0)
    for _, row in ipairs(config:GetTable('CombatUnitTable'):All()) do
        assert(row.moveCost <= row.actionPoints and #row.skillIds > 0)
        for _, id in ipairs(row.skillIds) do config:GetTable('CombatSkillTable'):Get(id) end
    end
    for _, event in ipairs(config:GetTable('AdventureEventTable'):All()) do
        for _, id in ipairs(event.choiceIds) do config:GetTable('AdventureChoiceTable'):Get(id) end
    end
end)
test('demo recipe generates real dry sites and a renderable map snapshot', function()
    local system = require('Game.Map.MapSystem')()
    system:OnInit({systems = {Get = function(_, name) assert(name == 'Config'); return config end}})
    local recipe = config:GetTable('AdventureDemoTable'):Get(1)
    local map = system:Generate(recipe.seed, recipe.regionIds)
    local dry = 0
    for _, cell in ipairs(map:GetCells()) do if not cell.waterLevel and not cell.buildingId then dry = dry + 1 end end
    assert(dry > #recipe.wildEventIds, 'Demo needs enough real dry sites')
    local snapshot = require('Game.Map.MapRenderSnapshot')(map)
    assert(#snapshot.cells == #map:GetCells() and #snapshot.assets > 0)
    system:OnShutdown()
end)
config:OnShutdown()
print('Adventure core: ' .. count .. ' checks passed')
