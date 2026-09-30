package.path = 'Lua/?.lua;' .. package.path
local Evaluator = require('Game.Condition.ConditionEvaluator')
local function definitions(rows)
    local byId = {}
    for _, row in ipairs(rows) do byId[row.id] = row end
    return { All = function() return rows end, Get = function(_, id) return assert(byId[id], 'Missing condition: ' .. tostring(id)) end }
end
local function row(id, kind, children, targetId, value)
    return { id = id, kind = kind, conditionIds = children or {}, targetId = targetId or 0, value = value or 0, reason = 'condition ' .. id }
end
local function expectError(callback, message)
    local ok, err = pcall(callback)
    assert(not ok and tostring(err):find(message, 1, true), 'Expected error: ' .. message .. ', got ' .. tostring(err))
end
local function engine(rows)
    local result = Evaluator.New(definitions(rows))
    result:Register('count', function(condition, context)
        context.reads = context.reads + 1
        return assert(context.counts[condition.targetId], 'Missing count') >= condition.value
    end, function(condition)
        assert(condition.targetId > 0 and condition.value > 0, 'Invalid count parameters')
    end)
    return result
end

local conditions = engine({
    row(1, 'count', nil, 7, 3), row(2, 'count', nil, 8, 2),
    row(3, 'all', {1, 2}), row(4, 'any', {1, 2}), row(5, 'not', {1}),
    row(6, 'all', {3, 4}),
})
local facts = { counts = {[7] = 2, [8] = 2}, reads = 0 }
expectError(function() conditions:Check(1, facts) end, 'Validate conditions')
conditions:Validate()
local passed, reason = conditions:Check(3, facts)
assert(not passed and reason == 'condition 1' and facts.reads == 1, 'ALL short circuit and failure reason')
assert(conditions:Check(4, facts) and conditions:Check(5, facts), 'ANY and NOT')
facts.counts[7], facts.reads = 3, 0
assert(conditions:Check(6, facts) and facts.reads == 2, 'Shared DAG leaves evaluated once per query')
facts.counts[7] = 0
assert(not conditions:Check(6, facts), 'No stale results after state changes')
facts.counts[8] = 0
passed, reason = conditions:Check(4, facts)
assert(not passed and reason == 'condition 4', 'Failed ANY uses its aggregate reason')
expectError(function() conditions:Check(99, facts) end, 'Missing condition')
expectError(function() conditions:Register('count', function() end, function() end) end, 'Duplicate/reserved')
expectError(function() conditions:Register('all', function() end, function() end) end, 'Duplicate/reserved')

local invalid = {
    {{row(1, 'all', {2}), row(2, 'not', {1})}, 'reference cycle'},
    {{row(1, 'all', {})}, 'needs children'},
    {{row(1, 'not', {2, 3}), row(2, 'count', nil, 7, 1), row(3, 'count', nil, 8, 1)}, 'exactly one'},
    {{row(1, 'all', {2, 2}), row(2, 'count', nil, 7, 1)}, 'Duplicate condition child'},
    {{row(1, 'count', {2}, 7, 1), row(2, 'count', nil, 8, 1)}, 'Leaf condition'},
    {{row(1, 'all', {99})}, 'Missing condition'},
    {{row(1, 'unknown')}, 'Unknown condition kind'},
    {{row(1, 'count')}, 'Invalid count parameters'},
}
for _, case in ipairs(invalid) do expectError(function() engine(case[1]):Validate() end, case[2]) end
local deep = {row(1, 'count', nil, 7, 1)}
for id = 2, 65 do deep[id] = row(id, 'not', {id - 1}) end
expectError(function() engine(deep):Validate() end, 'nesting exceeds 64')
local bad = engine({row(1, 'bad')})
bad:Register('bad', function() return nil end, function() end)
bad:Validate()
expectError(function() bad:Check(1, {}) end, 'must return boolean')
local broken = engine({row(1, 'broken')})
broken:Register('broken', function() error('adapter failure') end, function() end)
broken:Validate()
expectError(function() broken:Check(1, {}) end, 'adapter failure')
conditions:Register('extra', function() return true end, function() end)
expectError(function() conditions:Check(1, facts) end, 'Validate conditions')
conditions:Validate()

-- 真实导表二进制与系统生命周期，不启动 Unity。
local config = require('Config.ConfigSystem')()
config:OnInit({services = {ReadConfig = function(_, name)
    local file = assert(io.open('Assets/GameFramework/Resources/_Gen/Config/' .. name .. '.bytes', 'rb'))
    local bytes = file:read('*a'); file:close(); return bytes
end}})
local system = require('Game.Condition.ConditionSystem')()
system:OnInit({systems = {Get = function(_, name) assert(name == 'Config'); return config end}})
require('Game.Narrative.NarrativeConditions')({conditions=system,rules=require('Game.Narrative.NarrativeRules').New(config)})
system:OnStart()
assert(system:Check(1, {}) and not system:Check(2, {}))
system:OnShutdown()
print('PASS condition composition, live facts, DAG reuse, validation, handler failures and exported config lifecycle')
