-- 快照契约回归：真实 Battle 查询和 Adventure.Snapshot；配置与 Data 使用只读夹具。
-- 对应 AdventureViewData.Read 的必需值类型，防止 Lua nil 进入 C# bool/int 字段。
package.path = 'Lua/?.lua;' .. package.path
local Battle = require('Game.Battle.BattleSystem')
local Events = require('Game.Adventure.EventSystem')
local Adventure = require('Game.Adventure.AdventureSystem')
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local appearances=require('Game.Adventure.PawnAppearance').New(config)
local function rows(values)
    return {Get = function(_, id) return assert(values[id], 'Missing snapshot fixture row') end}
end
local templates = rows({
    [1] = {name = '剑士', skillIds = {1, 4}, moveCost = 1, moveRange = 3},
    [4] = {name = '守卫', skillIds = {1}, moveCost = 1, moveRange = 3},
})
local skills = rows({
    [1] = {name = '斩击', description = '近身攻击', cost = 2, action = 'main', range = 1, target = 'enemy'},
    [4] = {name = '防御', description = '保护自身', cost = 1, action = 'secondary', range = 0, target = 'self'},
})
local function fixture()
    local hero = {Id = 1, TemplateId = 1, Team = 1, HP = 46, MaxHP = 46, AP = 4,
        Q = -4, R = 0, Guard = 0, Moved = false, MainUsed = false, TraitCount = 0}
    local enemy = {Id = 101, TemplateId = 4, Team = 2, HP = 34, MaxHP = 34, AP = 0,
        Q = 4, R = 0, Guard = 0, Moved = false, MainUsed = false, TraitCount = 0}
    local units = {hero, enemy}
    local battleData = {UnitCount = 2, Round = 1, EncounterId = 1, ActiveId = 1, Winner = '', LogCount = 1,
        GetUnitAt = function(_, index) return assert(units[index + 1]) end,
        GetLogAt = function(_, index) assert(index == 0); return '战斗开始' end}
    local data = {Phase = 'battle', PartyCount = 1, ResultText = '', EventId = 1, AreaEncounterId = 0, Battle = battleData,
        GetPartyAt = function(_, index) assert(index == 0); return hero end,
        HasVisited = function() return false end}
    local battle = Battle()
    battle.data = battleData
    battle.board = require('Game.Battle.BattleBoard').Create(4, 20260922, .2)
    battle.stats = {Template = function(_, actor) return templates:Get(actor.TemplateId) end,
        Get = function(_, actor, name) assert(name == 'scouting'); return 2 end}
    battle.stats.equipment=require('Game.Equipment.EquipmentRules').New(config)
    battle.skills = skills
    battle.encounters = rows({[1] = {name = '废墟守卫'}})
    local events = Events()
    events.data, events.player, events.stats = data, {Coins = 0}, battle.stats
    events.events = rows({[1] = {name = '废墟', description = '守卫仍在巡逻。', repeatable = false, choiceIds = {1, 2}}})
    events.choices = rows({
        [1] = {label = '迎战', costCoins = 0, minScouting = 0, encounterIds = {1}, traitIds = {}, healParty = false},
        [2] = {label = '侦察', costCoins = 0, minScouting = 4, encounterIds = {}, traitIds = {}, healParty = false},
    })
    local adventure = Adventure()
    adventure.data, adventure.player, adventure.battle, adventure.events = data, events.player, battle, events
    adventure.appearances=appearances
    adventure.sites = {{id = 1, eventId = 1, name = '废墟', x = 1, y = 2, z = 3}}
    return adventure, hero
end
local actorFields = {id = 'number', team = 'number', hp = 'number', maxHP = 'number', ap = 'number',
    q = 'number', r = 'number', guard = 'number', name = 'string', traits = 'string', moved = 'boolean', mainUsed = 'boolean'}
local cellFields = {q = 'number', r = 'number', blocked = 'boolean'}
local rowContracts = {
    party = actorFields, units = actorFields, cells = cellFields, reachable = cellFields,
    sites = {id = 'number', name = 'string', x = 'number', y = 'number', z = 'number', available = 'boolean', visited = 'boolean'},
    choices = {id = 'number', label = 'string', reason = 'string', available = 'boolean'},
    skills = {id = 'number', cost = 'number', name = 'string', description = 'string', action = 'string', targets = 'table'},
}
local function check(snapshot)
    for _,actor in ipairs(snapshot.party) do
        assert(type(actor.appearance.templateId)=='number' and #actor.appearance.parts>=2)
        for _,part in ipairs(actor.appearance.parts) do assert(type(part.id)=='number' and type(part.path)=='string' and type(part.slot)=='string') end
    end
    for name, fields in pairs(rowContracts) do
        assert(type(snapshot[name]) == 'table', 'Missing snapshot array: ' .. name)
        for index, row in ipairs(snapshot[name]) do
            for field, kind in pairs(fields) do
                assert(type(row[field]) == kind, name .. '[' .. index .. '].' .. field .. ' must be ' .. kind .. ', got ' .. type(row[field]))
            end
        end
    end
    for _, key in ipairs({'phase', 'result', 'eventTitle', 'eventText', 'encounter'}) do assert(type(snapshot[key]) == 'string', key) end
    for _, key in ipairs({'coins', 'round', 'activeId', 'radius'}) do assert(type(snapshot[key]) == 'number', key) end
    for _, line in ipairs(snapshot.logs) do assert(type(line) == 'string') end
    for _, skill in ipairs(snapshot.skills) do for _, id in ipairs(skill.targets) do assert(type(id) == 'number') end end
end
local count = 0
local function test(name, run) run(); count = count + 1; print('PASS ' .. name) end
test('entering battle exports complete cell values for nonempty reachable tiles', function()
    local adventure = fixture()
    local snapshot = adventure:Snapshot()
    assert(#snapshot.reachable > 0 and #snapshot.units == 2 and #snapshot.skills > 0)
    check(snapshot)
    local hasBlocked = false
    for _, cell in ipairs(snapshot.cells) do if cell.blocked then hasBlocked = true end end
    assert(hasBlocked, 'Fixture must cover blocked=true as well as false')
    for _, cell in ipairs(snapshot.reachable) do assert(cell.blocked == false, 'Reachable tiles cannot be blocked') end
end)
test('snapshot cells are independent display copies of the battle board', function()
    local adventure = fixture()
    local snapshot = adventure:Snapshot(); check(snapshot)
    local cell = snapshot.reachable[1]
    local original = adventure.battle.board:Find(cell.q, cell.r)
    cell.blocked = true
    assert(original.blocked == false)
    check(adventure:Snapshot())
end)
test('spent movement and AP export an empty reachable array with intact actor booleans', function()
    local adventure, hero = fixture()
    hero.Moved = true; hero.MainUsed = true
    local snapshot = adventure:Snapshot(); check(snapshot)
    assert(#snapshot.reachable == 0 and snapshot.party[1].moved == true and snapshot.party[1].mainUsed == true)
    hero.Moved = false; hero.AP = 0
    snapshot = adventure:Snapshot(); check(snapshot); assert(#snapshot.reachable == 0)
end)
test('battle result exports cells but no skills or reachable moves', function()
    local adventure = fixture()
    adventure.data.Phase = 'result'; adventure.data.Battle.Winner = 'victory'
    local snapshot = adventure:Snapshot(); check(snapshot)
    assert(#snapshot.cells > 0 and #snapshot.skills == 0 and #snapshot.reachable == 0)
end)
test('map and event snapshots preserve boolean contracts when the battle is absent', function()
    local adventure = fixture()
    adventure.data.Battle.UnitCount = 0; adventure.data.Phase = 'map'
    local snapshot = adventure:Snapshot(); check(snapshot)
    assert(#snapshot.cells == 0 and #snapshot.reachable == 0 and snapshot.sites[1].available == true)
    adventure.data.Phase = 'event'
    snapshot = adventure:Snapshot(); check(snapshot)
    assert(#snapshot.choices > 0 and snapshot.sites[1].available == false)
    local enabled, disabled = false, false
    for _, choice in ipairs(snapshot.choices) do
        if choice.available then enabled = true else disabled = true; assert(choice.reason ~= '') end
    end
    assert(enabled and disabled, 'Fixture must cover both available values')
end)
print('Adventure snapshot: ' .. count .. ' checks passed')
