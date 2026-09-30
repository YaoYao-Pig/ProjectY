local Rules = {}
function Rules.New(config)
    local self = { config = config }
    for key, name in pairs({missions='MissionTable', quests='QuestTable', actions='NarrativeActionTable', npcs='NpcTable',
        factions='FactionTable', placements='NpcPlacementTable', schedules='NpcScheduleTable', dialogues='DialogueTable',
        nodes='DialogueNodeTable', choices='DialogueChoiceTable', cameras='DialogueCameraTable'}) do self[key] = config:GetTable(name) end
    self.settings = config:GetTable('NarrativeSettingsTable'):Get(1)
    self.environment = config:GetTable('MapEnvironmentTable'):Get(self.settings.environmentId)
    self.questsByMission, self.schedulesByNpc = {}, {}
    for _, quest in ipairs(self.quests:All()) do
        self.missions:Get(quest.missionId)
        local rows = self.questsByMission[quest.missionId] or {}; self.questsByMission[quest.missionId] = rows; rows[#rows+1] = quest
    end
    for _, schedule in ipairs(self.schedules:All()) do
        local rows = self.schedulesByNpc[schedule.npcId] or {}; self.schedulesByNpc[schedule.npcId] = rows; rows[#rows+1] = schedule
    end
    for _, npc in ipairs(self.npcs:All()) do
        assert(npc.relationMin <= npc.initialRelation and npc.initialRelation <= npc.relationMax, 'Invalid NPC relationship range')
        local schedules = assert(self.schedulesByNpc[npc.id], 'NPC needs a full-day schedule: '..npc.id)
        table.sort(schedules, function(a,b) return a.startMinute < b.startMinute end)
        local minute = 0
        for _, row in ipairs(schedules) do
            assert(row.startMinute == minute and row.endMinute > row.startMinute, 'NPC schedule gap/overlap: '..npc.id)
            minute = row.endMinute
        end
        assert(minute == 1440, 'NPC schedule must cover the full day')
        for _, id in ipairs(npc.dialogueIds) do assert(self.dialogues:Get(id).npcId == npc.id, 'Dialogue belongs to another NPC') end
    end
    for _, faction in ipairs(self.factions:All()) do
        assert(faction.minValue <= faction.initialValue and faction.initialValue <= faction.maxValue, 'Invalid faction reputation range')
    end
    local placements = {}
    for _, row in ipairs(self.placements:All()) do
        assert(not placements[row.npcId], 'NPC has multiple world placements'); placements[row.npcId] = true
        local area = config:GetTable('MapAreaTable'):Get(row.areaId)
        assert(area.areaType == config:GetEnum('MapArea','E_MapAreaType').Town, 'NPC placement requires a town')
        local facilities = {}; for _, id in ipairs(config:GetTable('MapAreaTownTable'):Get(area.profileId).facilityIds) do facilities[id] = true end
        assert(facilities[row.facilityId], 'NPC spawn facility is absent from town')
        for _, schedule in ipairs(self.schedulesByNpc[row.npcId]) do assert(facilities[schedule.facilityId], 'NPC schedule facility is absent from town') end
    end
    for _, npc in ipairs(self.npcs:All()) do assert(placements[npc.id], 'NPC needs a world placement') end
    local choiceOwners = {}
    for _, node in ipairs(self.nodes:All()) do
        assert(node.text ~= '', 'Empty dialogue node')
        local seen = {}
        for _, id in ipairs(node.choiceIds) do
            assert(not seen[id], 'Duplicate dialogue choice'); seen[id] = true
            local choice = self.choices:Get(id)
            assert(not choiceOwners[id] or choiceOwners[id] == node.dialogueId, 'Choice shared across different dialogues')
            choiceOwners[id] = node.dialogueId
            if choice.nextNodeId ~= 0 then assert(self.nodes:Get(choice.nextNodeId).dialogueId == node.dialogueId, 'Cross-dialogue node edge') end
        end
    end
    for _, dialogue in ipairs(self.dialogues:All()) do
        assert(self.nodes:Get(dialogue.entryNodeId).dialogueId == dialogue.id, 'Dialogue entry ownership mismatch')
        local visited = {}
        local function walk(id)
            if visited[id] then return end; visited[id] = true
            for _, choiceId in ipairs(self.nodes:Get(id).choiceIds) do local nextId = self.choices:Get(choiceId).nextNodeId; if nextId ~= 0 then walk(nextId) end end
        end
        walk(dialogue.entryNodeId)
        for _, node in ipairs(self.nodes:All()) do if node.dialogueId == dialogue.id then assert(visited[node.id], 'Unreachable dialogue node: '..node.id) end end
    end
    for _, action in ipairs(self.actions:All()) do
        local kind = action.kind
        if kind == 'set_flag' then assert(action.key:match('^[%a_][%w_]*$'), 'Invalid narrative flag key')
        elseif kind == 'grant_item' then config:GetTable('EquipmentItemTable'):Get(action.targetId); assert(action.value > 0, 'Item grant must be positive')
        elseif kind == 'accept_mission' or kind == 'claim_mission' then self.missions:Get(action.targetId)
        elseif kind == 'recruit_npc' then assert(self.npcs:Get(action.targetId).recruitable, 'NPC cannot be recruited')
        elseif kind == 'add_relation' then self.npcs:Get(action.targetId)
        elseif kind == 'add_reputation' then self.factions:Get(action.targetId)
        else assert(kind == 'add_coins', 'Unknown narrative action') end
    end
    -- 任务奖励只改变事实/物品/NPC；后继任务通过条件响应，不允许递归领取奖励。
    for _, table in ipairs({self.missions, self.quests}) do for _, row in ipairs(table:All()) do
        local seen = {}
        for _, id in ipairs(row.actionIds) do
            assert(not seen[id], 'Duplicate completion action'); seen[id] = true
            local kind = self.actions:Get(id).kind
            assert(kind ~= 'accept_mission' and kind ~= 'claim_mission', 'Completion actions cannot accept/claim another mission; use conditions')
        end
    end end
    return self
end
return Rules
