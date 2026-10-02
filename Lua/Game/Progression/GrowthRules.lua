-- 配表规则与只读查询。所有持久养成状态均由 CharacterGrowthData 持有。
local Rules = {}; Rules.__index = Rules
local function contains(values, value) for _, item in ipairs(values) do if item == value then return true end end return false end
function Rules.New(config)
    local self = setmetatable({}, Rules)
    for key, name in pairs({rules='GrowthRuleTable',levels='GrowthLevelTable',attributes='GrowthAttributeTable',
        profiles='GrowthProfileTable',trees='TalentTreeTable',nodes='TalentNodeTable',edges='TalentEdgeTable',
        passives='PassiveSkillTable',pools='ActiveSkillPoolTable',skills='CombatSkillTable',traits='CombatTraitTable'}) do
        self[key] = config:GetTable(name)
    end
    self.settings = self.rules:Get(1)
    self.atlas = require('Game.Progression.SkillAtlas').New(config)
    assert(self.settings.directionMin <= self.settings.directionMax, 'Invalid skill direction count')
    self.attributeByCode, self.profileByUnit, self.incoming, self.neighbors = {}, {}, {}, {}
    self.maxLevel = 1
    for _, row in ipairs(self.levels:All()) do self.maxLevel = math.max(self.maxLevel, row.id) end
    for level = 2, self.maxLevel do self.levels:Get(level) end
    for _, row in ipairs(self.attributes:All()) do
        assert(not self.attributeByCode[row.code], 'Duplicate growth attribute: '..row.code)
        -- 是否参与研习由 skillDirection 决定；生活属性也可开放动物驯服等技能方向。
        self.attributeByCode[row.code] = row
    end
    for _, row in ipairs(self.profiles:All()) do
        assert(not self.profileByUnit[row.unitId], 'Duplicate growth profile'); self.profileByUnit[row.unitId] = row
    end
    for _, row in ipairs(self.passives:All()) do
        assert(#row.attributeNames > 0 and #row.attributeNames == #row.attributeValues, 'Passive attributes differ')
        for _, name in ipairs(row.attributeNames) do assert(self.attributeByCode[name], 'Unknown passive attribute: '..name) end
    end
    for _, row in ipairs(self.nodes:All()) do
        self.incoming[row.id], self.neighbors[row.id] = {}, {}
        assert(row.minLevel <= self.maxLevel, 'Unreachable talent level: '..row.id)
    end
    local edges = {}
    for _, edge in ipairs(self.edges:All()) do
        local a,b = self.nodes:Get(edge.fromId), self.nodes:Get(edge.toId)
        assert(a.treeId == b.treeId and a.id ~= b.id, 'Invalid talent edge')
        local key = a.id..':'..b.id; assert(not edges[key], 'Duplicate talent edge'); edges[key] = true
        table.insert(self.incoming[b.id], a.id); table.insert(self.neighbors[a.id], b.id); table.insert(self.neighbors[b.id], a.id)
    end
    for _, tree in ipairs(self.trees:All()) do
        assert(#tree.rootIds > 0, 'Talent tree needs roots')
        local reached = {}
        for _, id in ipairs(tree.rootIds) do
            assert(self.nodes:Get(id).treeId == tree.id and not reached[id], 'Invalid talent root')
            if tree.unlockRule == 'prerequisite_all' then assert(#self.incoming[id] == 0, 'Root cannot have prerequisites') end
            reached[id] = true
        end
        local changed = true
        while changed do
            changed = false
            for _, node in ipairs(self.nodes:All()) do
                if node.treeId == tree.id and not reached[node.id] then
                    local links = tree.unlockRule == 'adjacent_any' and self.neighbors[node.id] or self.incoming[node.id]
                    local count = 0; for _, id in ipairs(links) do if reached[id] then count = count + 1 end end
                    if #links > 0 and ((tree.unlockRule == 'adjacent_any' and count > 0) or count == #links) then reached[node.id] = true; changed = true end
                end
            end
        end
        for _, node in ipairs(self.nodes:All()) do assert(node.treeId ~= tree.id or reached[node.id], 'Unreachable/cyclic talent: '..node.id) end
    end
    for _, pool in ipairs(self.pools:All()) do
        assert(self.attributes:Get(pool.attributeId).skillDirection and pool.minValue <= pool.maxValue, 'Invalid active pool direction/range')
    end
    return self
end
function Rules:Bonus(actor, name)
    local growth, value = actor.Growth, 0
    value = growth:GetAttribute(name)
    for i = 0, growth.TalentCount - 1 do
        local node = self.nodes:Get(growth:GetTalentAt(i)); local passive = self.passives:Get(node.passiveId)
        for j, code in ipairs(passive.attributeNames) do if code == name then value = value + passive.attributeValues[j] * growth:GetRank(node.id) end end
    end
    return value
end
function Rules:CanInvest(actor, id)
    local node = self.nodes:Find(id)
    if not node then return false, '未知天赋节点' end
    local growth = actor.Growth
    if not growth:HasTree(node.treeId) then return false, '需要特定经历解锁此天赋树' end
    if growth:GetRank(id) >= node.maxRank then return false, '已达到最高阶数' end
    if growth.Level < node.minLevel then return false, '需要等级 '..node.minLevel end
    if growth.TalentPoints < node.pointCost then return false, '被动天赋点不足' end
    if growth:GetRank(id) > 0 then return true end
    local tree = self.trees:Get(node.treeId)
    if contains(tree.rootIds, id) then return true end
    local links = tree.unlockRule == 'adjacent_any' and self.neighbors[id] or self.incoming[id]
    local count = 0; for _, other in ipairs(links) do if growth:GetRank(other) > 0 then count = count + 1 end end
    if tree.unlockRule == 'adjacent_any' then return count > 0, '需要点亮任一相邻节点' end
    return #links > 0 and count == #links, '需要点亮全部前置节点'
end
local function weighted(rows, random)
    local total = 0
    for _, row in ipairs(rows) do
        assert(row.weight > 0 and row.weight < math.huge, 'Skill weight must be positive and finite')
        total = total + row.weight
    end
    local roll = random() * total
    for _, row in ipairs(rows) do roll = roll - row.weight; if roll < 0 then return row end end
    return rows[#rows]
end
function Rules:Draw(actor, stats)
    local growth, owned, selected, result = actor.Growth, {}, {}, {}
    -- 固有、装备与已学习技能均不再作为候选。
    for _, id in ipairs(stats.equipment:SkillIds(actor, stats:Template(actor))) do owned[id] = true end
    for i = 0, growth.SkillCount - 1 do owned[growth:GetSkillAt(i)] = true end
    local count = self.settings.directionMin + math.floor(growth:NextRandom() * (self.settings.directionMax-self.settings.directionMin+1))
    local function random() return growth:NextRandom() end
    while #result < count do
        local directions = {}
        for _, attribute in ipairs(self.attributes:All()) do
            if attribute.skillDirection and not selected[attribute.id] then
                local value = stats:Get(actor, attribute.code, not self.settings.includeEquipment)
                local candidates, seen = {}, {}
                for _, pool in ipairs(self.pools:All()) do
                    if pool.attributeId == attribute.id and value >= pool.minValue and value <= pool.maxValue and not owned[pool.skillId]
                        and self.atlas:Prerequisites(pool.skillId,owned) then
                        assert(not seen[pool.skillId], 'Overlapping rows for same skill/direction'); seen[pool.skillId] = true
                        candidates[#candidates+1] = {id=pool.skillId,weight=self.settings.tierWeight:Evaluate({value=value,tier=pool.tier,weight=pool.weight})}
                    end
                end
                if #candidates > 0 then directions[#directions+1] = {id=attribute.id,candidates=candidates,weight=self.settings.directionWeight:Evaluate({value=value})} end
            end
        end
        if #directions == 0 then break end -- 全部已学或没有符合门槛的技能；允许合法空池。
        local direction = weighted(directions, random)
        local candidate = weighted(direction.candidates, random)
        selected[direction.id], owned[candidate.id] = true, true; result[#result+1] = candidate.id
    end
    return result
end
return Rules
