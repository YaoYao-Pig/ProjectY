return function(story)
    local conditions, rules = story.conditions, story.rules
    local function register(kind, evaluate, validate) conditions:Register(kind, evaluate, validate) end
    local function positive(row) assert(row.value > 0, 'Condition threshold must be positive: '..row.id) end
    for _, kind in ipairs({'mission', 'quest'}) do
        local table = kind == 'mission' and rules.missions or rules.quests
        register(kind..'_state', function(row) return story.data:Status(kind, row.targetId) == row.state end, function(row)
            table:Get(row.targetId)
            assert(row.state == 'inactive' or row.state == 'active' or row.state == 'ready' or row.state == 'completed', 'Unknown progress state')
        end)
    end
    register('flag', function(row) return story.data:GetValue('flag:'..row.key) == row.value end,
        function(row) assert(row.key:match('^[%a_][%w_]*$'), 'Invalid flag condition key') end)
    register('item_count', function(row)
        local count=story:ItemCount(row.targetId)
        return count >= row.value, row.reason..'（'..count..' / '..row.value..'）'
    end,
        function(row) rules.config:GetTable('EquipmentItemTable'):Get(row.targetId); positive(row) end)
    register('kill_count', function(row, context)
        assert(context.kind and context.id, 'kill_count requires a mission/quest context')
        local count=story.data:KillCount(context.kind, context.id, row.targetId)
        return count >= row.value, row.reason..'（'..count..' / '..row.value..'）'
    end, function(row) rules.config:GetTable('CombatUnitTable'):Get(row.targetId); positive(row) end)
    register('npc_relation', function(row) return story.data:GetValue('relation:'..row.targetId) >= row.value end,
        function(row) local npc = rules.npcs:Get(row.targetId); assert(row.value >= npc.relationMin and row.value <= npc.relationMax, 'Relationship threshold outside bounds') end)
    register('faction_reputation', function(row) return story.data:GetValue('reputation:'..row.targetId) >= row.value end,
        function(row) local faction = rules.factions:Get(row.targetId); assert(row.value >= faction.minValue and row.value <= faction.maxValue, 'Reputation threshold outside bounds') end)
    register('npc_recruited', function(row) return story.data:GetValue('recruited:'..row.targetId) ~= 0 end,
        function(row) assert(rules.npcs:Get(row.targetId).recruitable, 'Recruit condition requires recruitable NPC') end)
    register('time_window', function(row)
        local minute = story.data.Minutes % 1440
        return minute >= row.targetId and minute < row.value
    end, function(row) assert(row.targetId >= 0 and row.targetId < row.value and row.value <= 1440, 'Invalid time window') end)
    register('coins', function(row) return story.adventure.player.Coins >= row.value end, positive)
end
