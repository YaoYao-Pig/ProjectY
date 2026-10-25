local Rules = {}
function Rules.New(config)
    local self = { config = config }
    for key, name in pairs({missions='MissionTable', quests='QuestTable', actions='NarrativeActionTable', npcs='NpcTable',
        factions='FactionTable', placements='NpcPlacementTable', schedules='NpcScheduleTable', dialogues='DialogueTable',
        nodes='DialogueNodeTable', choices='DialogueChoiceTable', cameras='DialogueCameraTable',
        interjections='DialogueInterjectionTable', specialEvents='SpecialEventTable'}) do self[key] = config:GetTable(name) end
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
        if npc.locationKind=='town' then
            local schedules = assert(self.schedulesByNpc[npc.id], 'NPC needs a full-day schedule: '..npc.id)
            table.sort(schedules, function(a,b) return a.startMinute < b.startMinute end)
            local minute = 0
            for _, row in ipairs(schedules) do
                assert(row.startMinute == minute and row.endMinute > row.startMinute, 'NPC schedule gap/overlap: '..npc.id)
                minute = row.endMinute
            end
            assert(minute == 1440, 'NPC schedule must cover the full day')
        elseif npc.locationKind=='event' then
            assert(npc.recruitable and not self.schedulesByNpc[npc.id], 'Event NPC must be recruitable and cannot use town schedules')
            local binding
            for _,row in ipairs(self.specialEvents:All()) do if row.npcId==npc.id then
                assert(not binding, 'Event NPC needs one special-event binding'); binding=row
            end end
            assert(binding and binding.allyUnitId==npc.actorTemplateId, 'Event NPC template must match its special-event ally')
        elseif npc.locationKind=='animal' then
            assert(not npc.recruitable and not self.schedulesByNpc[npc.id], 'Animal dialogue identity cannot use town schedules or recruitment')
            assert(config:GetTable('AnimalSpeechRuleTable'):Get(1).npcId==npc.id,'Animal dialogue identity needs a speech rule')
        else
            assert(npc.locationKind=='world_party' and not npc.recruitable and not self.schedulesByNpc[npc.id], 'World-party NPC cannot use town schedules or recruitment')
        end
        for _, id in ipairs(npc.dialogueIds) do assert(self.dialogues:Get(id).npcId == npc.id, 'Dialogue belongs to another NPC') end
    end
    for _, faction in ipairs(self.factions:All()) do
        assert(faction.minValue <= faction.initialValue and faction.initialValue <= faction.maxValue, 'Invalid faction reputation range')
    end
    local placements = {}
    for _, row in ipairs(self.placements:All()) do
        assert(self.npcs:Get(row.npcId).locationKind=='town','Only town NPCs can have a town placement')
        assert(not placements[row.npcId], 'NPC has multiple world placements'); placements[row.npcId] = true
        local area = config:GetTable('MapAreaTable'):Get(row.areaId)
        assert(area.areaType == config:GetEnum('MapArea','E_MapAreaType').Town, 'NPC placement requires a town')
        local facilities = {}; for _, id in ipairs(config:GetTable('MapAreaTownTable'):Get(area.profileId).facilityIds) do facilities[id] = true end
        assert(facilities[row.facilityId], 'NPC spawn facility is absent from town')
        for _, schedule in ipairs(self.schedulesByNpc[row.npcId]) do assert(facilities[schedule.facilityId], 'NPC schedule facility is absent from town') end
    end
    for _, npc in ipairs(self.npcs:All()) do if npc.locationKind=='town' then assert(placements[npc.id], 'NPC needs a world placement') end end
    local choiceOwners = {}
    self.interjectionsByNode = {}
    local conditions = config:GetTable('ConditionTable')
    local function checkScope(id, actorAllowed, killAllowed, visited)
        visited = visited or {}
        if visited[id] then return end; visited[id] = true
        local row = conditions:Get(id)
        assert(actorAllowed or not row.kind:match('^actor_'), 'Actor condition outside an interjection: '..id)
        assert(killAllowed or row.kind ~= 'kill_count', 'kill_count needs an accepted mission/quest context: '..id)
        for _, child in ipairs(row.conditionIds) do checkScope(child,actorAllowed,killAllowed,visited) end
    end
    for _, row in ipairs(self.interjections:All()) do
        local node = self.nodes:Get(row.nodeId)
        assert(row.cue:match('%S') and row.text:match('%S'), 'Interjection needs cue and text')
        assert(row.mode == 'auto' or row.mode == 'optional', 'Invalid interjection mode')
        assert(row.mode ~= 'auto' or row.nextNodeId == 0, 'Automatic interjection cannot change the dialogue node')
        checkScope(row.conditionId,true,false)
        if row.nextNodeId ~= 0 then assert(self.nodes:Get(row.nextNodeId).dialogueId == node.dialogueId, 'Cross-dialogue interjection edge') end
        local rows = self.interjectionsByNode[node.id] or {}; self.interjectionsByNode[node.id] = rows; rows[#rows+1] = row
    end
    for _, rows in pairs(self.interjectionsByNode) do
        table.sort(rows,function(a,b) if a.order ~= b.order then return a.order < b.order end; return a.id < b.id end)
    end
    for _, row in ipairs(self.missions:All()) do checkScope(row.startConditionId,false,false); checkScope(row.completeConditionId,false,true) end
    for _, row in ipairs(self.quests:All()) do checkScope(row.startConditionId,false,true); checkScope(row.completeConditionId,false,true) end
    for _, row in ipairs(self.choices:All()) do checkScope(row.conditionId,false,false) end
    for _, node in ipairs(self.nodes:All()) do
        assert(node.text ~= '', 'Empty dialogue node')
        local seen = {}
        for _, id in ipairs(node.choiceIds) do
            assert(not seen[id], 'Duplicate dialogue choice'); seen[id] = true
            local choice = self.choices:Get(id)
            assert(choice.worldAction=='none' or choice.worldAction=='attack','Unknown world dialogue action')
            if choice.worldAction=='attack' then
                assert(choice.nextNodeId==0 and self.npcs:Get(self.dialogues:Get(node.dialogueId).npcId).locationKind=='world_party','Attack choice requires a terminal world-party dialogue')
                assert(#choice.actionIds==0,'Attack choices cannot also grant narrative rewards')
            end
            assert(not choiceOwners[id] or choiceOwners[id] == node.dialogueId, 'Choice shared across different dialogues')
            choiceOwners[id] = node.dialogueId
            if choice.nextNodeId ~= 0 then assert(self.nodes:Get(choice.nextNodeId).dialogueId == node.dialogueId, 'Cross-dialogue node edge') end
        end
    end
    for _, dialogue in ipairs(self.dialogues:All()) do
        checkScope(dialogue.conditionId,false,false)
        assert(self.nodes:Get(dialogue.entryNodeId).dialogueId == dialogue.id, 'Dialogue entry ownership mismatch')
        local visited = {}
        local function walk(id)
            if visited[id] then return end; visited[id] = true
            for _, choiceId in ipairs(self.nodes:Get(id).choiceIds) do local nextId = self.choices:Get(choiceId).nextNodeId; if nextId ~= 0 then walk(nextId) end end
            for _, row in ipairs(self.interjectionsByNode[id] or {}) do if row.nextNodeId ~= 0 then walk(row.nextNodeId) end end
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
        elseif kind == 'grant_experience' then assert(action.value > 0 and action.targetId == 0 and action.key == '', 'Experience reward requires positive value and whole-party target')
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
