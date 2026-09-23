-- 聚落选址分析：地形、水岸接近代价与文明距离统一由配表评分。
-- 距离场和地形统计按方案参数缓存；不对每个候选重复进行路径搜索。
local Class = require('Core.Class')
local Hex = require('Game.Map.HexGrid')
local Curve = require('Game.Map.MapConfigCurve')
local Selection = Class('MapSiteSelection')
local metricNames = {height=true,slope=true,roughness=true,relativeHeight=true,buildableCells=true,
    waterClearance=true,waterAccessDistance=true,riverJunctionDistance=true,settlementDistance=true,roadDistance=true}
local clearanceNames = {waterClearance=true,settlementDistance=true,roadDistance=true}
function Selection:ctor(config)
    self.profiles = config:GetTable('MapSiteProfileTable'); self.rules = {}
    for _, profile in ipairs(self.profiles:All()) do
        assert(profile.sampleRadius >= 1 and profile.sampleRadius <= 8 and profile.distanceCap >= 1 and profile.distanceCap <= 128, 'Invalid site analysis radius')
        assert(profile.pickWeight > 0 and profile.scoreExponent >= 1 and profile.scoreExponent <= 12, 'Invalid site selection weight')
        assert(profile.minScore >= 0 and profile.minScore <= 1 and profile.candidateBudget >= 1 and profile.candidateBudget <= 1024, 'Invalid site candidate budget')
        assert(profile.accessMaxStep > 0 and profile.accessSlopeCost >= 0 and profile.shoreAccessMaxDrop >= 0, 'Invalid shore access settings')
        self.rules[profile.id] = {}
    end
    for _, rule in ipairs(config:GetTable('MapSiteRuleTable'):All()) do
        local rules = assert(self.rules[rule.profileId], 'Unknown site rule profile')
        assert(metricNames[rule.metric], 'Unknown site metric: ' .. rule.metric)
        assert(#rule.hardRange == 0 or (#rule.hardRange == 2 and rule.hardRange[1] <= rule.hardRange[2]), 'Invalid site hard range')
        Curve.Validate(rule.scoreXs, rule.scoreYs, 0, 1)
        assert(rule.weight >= 0, 'Site rule weight must be nonnegative')
        for _, other in ipairs(rules) do assert(other.metric ~= rule.metric, 'Duplicate metric in site profile') end
        rules[#rules+1] = rule
    end
    for _, rules in pairs(self.rules) do
        local weight = 0; for _, rule in ipairs(rules) do weight = weight + rule.weight end
        assert(weight > 0, 'Site profile needs a positive total rule weight')
    end
end
function Selection:Begin(map, graph)
    self.map = map; self.graph = graph; self.terrainCache = {}; self.waterCache = {}
    self.roadDistance = nil; self.settlementDistance = nil
    for _, cell in ipairs(map.cells) do cell.siteScores = {} end
end
-- 分析缓存只属于本次生成，不能让常驻生成器保留上一张大地图的可写草稿。
function Selection:Finish()
    self.map = nil; self.graph = nil; self.terrainCache = nil; self.waterCache = nil
    self.roadDistance = nil; self.settlementDistance = nil
end
-- 从实际建筑、聚落中心和内部街道计算文明距离，不以整个圆形搜索区代替城市。
function Selection:RefreshCivilization(cap)
    local settlementCount = 0
    for _, town in ipairs(self.map.towns) do if town.role == 'settlement' then settlementCount = settlementCount + 1 end end
    if self.roadDistance and self.civilizationCap == cap and self.civilizationRoadCount == #self.map.roads
        and self.civilizationSettlementCount == settlementCount then return end
    local roads, settlements = {}, {}
    for _, cell in ipairs(self.map.cells) do
        if #cell.roadIds > 0 then roads[#roads+1] = cell end
        local town = cell.townId and self.map.towns[cell.townId]
        if town and town.role == 'settlement' and cell.buildingId then settlements[#settlements+1] = cell end
    end
    for _, town in ipairs(self.map.towns) do
        if town.role == 'settlement' then settlements[#settlements+1] = town.center end
    end
    for _, road in ipairs(self.map.roads) do
        if road.kind == 'street' and self.map.towns[road.townA].role == 'settlement' then
            for _, cell in ipairs(road.cells) do settlements[#settlements+1] = cell end
        end
    end
    self.roadDistance = self.graph:HexDistances(roads, cap)
    self.settlementDistance = self.graph:HexDistances(settlements, cap)
    self.civilizationCap = cap; self.civilizationRoadCount = #self.map.roads
    self.civilizationSettlementCount = settlementCount
end
function Selection:Analyze(profile)
    local graph, map = self.graph, self.map
    local key = table.concat({profile.sampleRadius,profile.accessMaxStep}, ':')
    local terrain = self.terrainCache[key]
    if not terrain then
        terrain = {}; self.terrainCache[key] = terrain
        local slopes = {}
        for _, cell in ipairs(map.cells) do
            local slope = 0
            for _, other in ipairs(graph.neighbors[cell]) do
                if not other.waterLevel then slope = math.max(slope, math.abs(cell.height-other.height)) end
            end
            slopes[cell] = slope
        end
        for _, cell in ipairs(map.cells) do
            local count, sum, sumSquares, buildable = 0, 0, 0, 0
            local radius = profile.sampleRadius
            for r = -radius, radius do
                for q = math.max(-radius,-r-radius), math.min(radius,-r+radius) do
                    local other = map.cellsByKey[Hex.Key(cell.q+q,cell.r+r)]
                    if other then
                        count=count+1; sum=sum+other.height; sumSquares=sumSquares+other.height*other.height
                        if not other.waterLevel and slopes[other] <= profile.accessMaxStep then buildable=buildable+1 end
                    end
                end
            end
            terrain[cell] = {height=cell.height,slope=slopes[cell],roughness=math.sqrt(math.max(0,sumSquares/count-(sum/count)^2)),
                relativeHeight=cell.height-sum/count,buildableCells=buildable}
        end
    end
    local waterKey = table.concat({profile.distanceCap,profile.accessMaxStep,profile.accessSlopeCost,profile.shoreAccessMaxDrop}, ':')
    local water = self.waterCache[waterKey]
    if not water then
        local wet, shores, junctions, incoming = {}, {}, {}, {}
        for _, cell in ipairs(map.cells) do if cell.flowTo then incoming[cell.flowTo]=(incoming[cell.flowTo] or 0)+1 end end
        for _, cell in ipairs(map.cells) do
            if cell.waterLevel then wet[#wet+1]=cell
            else
                for _, other in ipairs(graph.neighbors[cell]) do
                    if other.waterLevel and math.abs(cell.height-other.waterLevel) <= profile.shoreAccessMaxDrop then
                        shores[#shores+1]=cell; break
                    end
                end
            end
            if (incoming[cell] or 0) >= 2 then junctions[#junctions+1]=cell end
        end
        water = {clearance=graph:HexDistances(wet,profile.distanceCap), junction=graph:HexDistances(junctions,profile.distanceCap),
            access=graph:Distances(shores,function(a,b)
                if b.waterLevel then return nil end
                local step=math.abs(a.height-b.height)
                if step <= profile.accessMaxStep then return 1+step*profile.accessSlopeCost end
            end,profile.distanceCap)}
        self.waterCache[waterKey]=water
    end
    return terrain, water
end
function Selection:Metrics(cell, profile, terrain, water)
    local values = {}; for k,v in pairs(terrain[cell]) do values[k]=v end
    values.waterClearance=water.clearance[cell] or profile.distanceCap
    values.waterAccessDistance=water.access[cell] or profile.distanceCap
    values.riverJunctionDistance=water.junction[cell] or profile.distanceCap
    values.settlementDistance=math.min(profile.distanceCap,self.settlementDistance[cell] or profile.distanceCap)
    values.roadDistance=math.min(profile.distanceCap,self.roadDistance[cell] or profile.distanceCap)
    return values
end
function Selection:Evaluate(profile, metrics, clearanceOnly)
    local score, weight = 0, 0
    for _, rule in ipairs(self.rules[profile.id]) do
        local value = assert(metrics[rule.metric], 'Missing measured site metric')
        if (not clearanceOnly or clearanceNames[rule.metric]) and #rule.hardRange == 2
            and (value < rule.hardRange[1] or value > rule.hardRange[2]) then return nil, rule.metric end
        score = score + Curve.Sample(rule.scoreXs,rule.scoreYs,value)*rule.weight; weight = weight+rule.weight
    end
    score = score/weight
    if not clearanceOnly and score < profile.minScore then return nil, 'minScore' end
    return score
end
-- 建筑完整占地和入口都复核净距，防止只有中心远离道路而大建筑伸到路边。
function Selection:CheckPlans(plans, profile, terrain, water)
    for _, plan in ipairs(plans) do
        local function allowed(cell)
            return self:Evaluate(profile,self:Metrics(cell,profile,terrain,water),true) ~= nil
        end
        if not allowed(plan.entrance) then return false end
        for _, cell in ipairs(plan.cells) do if not allowed(cell) then return false end end
    end
    return true
end
return Selection
