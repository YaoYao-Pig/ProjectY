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
    local function actor(context)
        return assert(context.actor, 'Actor condition requires a specific dialogue participant')
    end
    register('actor_trait', function(row, context)
        return actor(context):HasTrait(row.targetId)
    end, function(row)
        rules.config:GetTable('CombatTraitTable'):Get(row.targetId)
        assert(row.key == '' and row.state == '' and row.value == 0, 'actor_trait uses targetId only')
    end)
    register('actor_attribute', function(row, context)
        local attribute = rules.config:GetTable('GrowthAttributeTable'):Get(row.targetId)
        local value = story.adventure.battle.stats:Get(actor(context), attribute.code)
        return value >= row.value, row.reason..'（'..value..' / '..row.value..'）'
    end, function(row)
        rules.config:GetTable('GrowthAttributeTable'):Get(row.targetId); positive(row)
        assert(row.key == '' and row.state == '', 'actor_attribute uses targetId/value only')
    end)
    register('actor_history', function(row, context)
        local id, count = actor(context).Id, 0
        local data = story.adventure.data
        for i=0,data.JournalCount-1 do
            local entry = data:GetJournalAt(i)
            local involved = row.state == 'subject' and entry.SubjectId == id
                or row.state == 'object' and entry.ObjectId == id
                or row.state == 'participant' and entry:Involves(id)
            if involved and entry.Kind == row.key and (row.targetId == 0 or entry.EventId == row.targetId) then
                count = count + 1
                if count >= row.value then return true end
            end
        end
        return false, row.reason..'（'..count..' / '..row.value..'）'
    end, function(row)
        positive(row)
        local known = false
        for _, template in ipairs(rules.config:GetTable('StoryLogTemplateTable'):All()) do
            if template.kind == row.key then known = true; break end
        end
        assert(known and (row.state == 'participant' or row.state == 'subject' or row.state == 'object'), 'Invalid actor_history kind/role')
        assert(row.targetId >= 0, 'Invalid actor_history event ID')
        if row.targetId > 0 then
            assert(row.key == 'event', 'An event ID requires event history')
            rules.config:GetTable('AdventureEventTable'):Get(row.targetId)
        end
    end)
    register('party_attribute', function(row)
        local attribute = rules.config:GetTable('GrowthAttributeTable'):Get(row.targetId)
        local best = 0
        for i=0,story.adventure.data.PartyCount-1 do
            local actor = story.adventure.data:GetPartyAt(i)
            if actor.HP > 0 then best = math.max(best, story.adventure.battle.stats:Get(actor, attribute.code)) end
        end
        return best >= row.value, row.reason..'（队伍最高 '..best..' / '..row.value..'）'
    end, function(row)
        rules.config:GetTable('GrowthAttributeTable'):Get(row.targetId); positive(row)
        assert(row.key == '' and row.state == '', 'party_attribute uses targetId/value only')
    end)
end
