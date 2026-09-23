-- 城镇与道路的生成期布局：先在平缓陆地试排建筑，再连接街道与城镇。
-- 不整平地面、不创建玩法实体；所有路径使用最终地形，水域和陡坡禁止通过。
local Class = require('Core.Class')
local Hex = require('Game.Map.HexGrid')
local Random = require('Game.Map.SeededRandom')
local Pathfinder = require('Game.Map.MapPathfinder')
local SiteSelection = require('Game.Map.MapSiteSelection')
local Infrastructure = Class('MapInfrastructure')
local function contains(values, target)
    for _, value in ipairs(values) do if value == target then return true end end
    return false
end
local function range(value, minimum, maximum, integer, label)
    assert(type(value) == 'number' and value >= minimum and value <= maximum
        and (not integer or value == math.floor(value)), 'Invalid infrastructure config: ' .. label)
end
local function distance(a, b) return Hex.Distance(a.q, a.r, b.q, b.r) end
-- 完整六边形占地必须位于地图内；边缘缺格的候选不参与选址。
local function disk(map, center, radius)
    local cells = {}
    for r = -radius, radius do
        for q = math.max(-radius, -r-radius), math.min(radius, -r+radius) do
            local cell = map.cellsByKey[Hex.Key(center.q + q, center.r + r)]
            if not cell then return nil end
            cells[#cells + 1] = cell
        end
    end
    return cells
end
local function relief(cells)
    local minimum, maximum = math.huge, -math.huge
    for _, cell in ipairs(cells) do
        if cell.waterLevel then return nil end
        minimum = math.min(minimum, cell.height); maximum = math.max(maximum, cell.height)
    end
    return maximum - minimum, maximum
end
function Infrastructure:ctor(config, regionTypes)
    self.rows = {}; self.buildingTable = config:GetTable('MapBuildingTable')
    for i, row in ipairs(config:GetTable('MapTownTable'):All()) do self.rows[i] = row end
    table.sort(self.rows, function(a, b) return a.priority > b.priority or (a.priority == b.priority and a.id < b.id) end)
    self.maxStep = config:GetConstant('Map', 'RoadMaxStep'); self.slopeCost = config:GetConstant('Map', 'RoadSlopeCost')
    range(self.maxStep, 0, 100, false, 'RoadMaxStep'); range(self.slopeCost, 0, 100, false, 'RoadSlopeCost')
    local total = 0
    if #self.rows > 0 then self.selection = SiteSelection(config) end
    for _, row in ipairs(self.rows) do
        assert(row.placementStage == 'BeforeRoads' or row.placementStage == 'AfterRoads', 'Invalid placement stage')
        assert(type(row.connectRoad) == 'boolean' and type(row.generateStreets) == 'boolean', 'Missing road generation flags')
        assert(row.placementStage ~= 'AfterRoads' or (not row.connectRoad and not row.generateStreets), 'AfterRoads sites cannot create roads or streets')
        assert(not row.connectRoad or row.generateStreets, 'Connected settlements need entrance streets')
        assert(#row.siteProfileIds > 0, 'Town needs site profiles')
        for _, id in ipairs(row.siteProfileIds) do self.selection.profiles:Get(id) end
        assert(type(row.groundColor) == 'string' and row.groundColor:match('^#%x%x%x%x%x%x$'), 'Town groundColor must be #RRGGBB')
        range(row.maxCount, 0, 16, true, 'maxCount'); total = total + row.maxCount
        range(row.maxPerRegion, 1, 16, true, 'maxPerRegion'); range(row.radius, 2, 12, true, 'radius')
        range(row.minSpacing, 1, 256, true, 'minSpacing'); range(row.siteAttempts, 1, 128, true, 'siteAttempts')
        range(row.minBuildings, 1, 48, true, 'minBuildings'); range(row.maxBuildings, row.minBuildings, 48, true, 'maxBuildings')
        range(row.maxGroundDelta, 0, 4, false, 'maxGroundDelta')
        for _, kind in ipairs(row.regions) do assert(regionTypes[kind], 'Town refers to an unknown region type') end
        assert(#row.buildingIds > 0, 'Town needs building candidates')
        for _, id in ipairs(row.requiredBuildingIds) do assert(contains(row.buildingIds, id), 'Required landmark is not in buildingIds') end
        for _, id in ipairs(row.buildingIds) do
            local building = self.buildingTable:Get(id)
            range(building.footprintRadius, 0, 2, true, 'footprintRadius')
            range(building.height, 0.1, 20, false, 'building height'); range(building.roofHeight, 0, 10, false, 'roofHeight')
        end
    end
    assert(total <= 16, 'Town maxCount total exceeds the generation budget of 16')
end
function Infrastructure:EdgeCost(a, b)
    if a.waterLevel or b.waterLevel or a.buildingId or b.buildingId then return nil end
    local step = math.abs(a.height - b.height)
    if step > self.maxStep then return nil end
    -- 优先复用已铺设的路段，避免每一对城镇都产生互不相干的平行道路。
    return (1 + step * self.slopeCost) * (#a.roadIds > 0 and #b.roadIds > 0 and 0.55 or 1)
end
-- 试排过程只修改局部集合；建筑数量不足时可以放弃候选，不留下残缺占地或道路。
function Infrastructure:PlanTown(map, finder, random, row, center)
    local candidates, occupied, streets = {}, {}, {}
    if row.generateStreets then occupied[center] = true end
    for _, cell in ipairs(map.regions[center.regionId].cells) do
        local span = distance(center, cell)
        if span >= (row.generateStreets and 2 or 0) and span <= row.radius and not cell.waterLevel and not cell.townId then
            candidates[#candidates + 1] = { cell = cell, score = span + random:Noise(cell.q, cell.r, 1, 8101) * 2 }
        end
    end
    table.sort(candidates, function(a, b) return a.score < b.score or (a.score == b.score and finder.indices[a.cell] < finder.indices[b.cell]) end)
    local buildings = {}
    for attempt = 1, random:Integer(row.minBuildings, row.maxBuildings) do
        local config = self.buildingTable:Get(row.buildingIds[(attempt - 1) % #row.buildingIds + 1])
        for _, candidate in ipairs(candidates) do
            local cell = candidate.cell
            local footprint = disk(map, cell, config.footprintRadius)
            local delta, base
            if footprint then delta, base = relief(footprint) end
            local allowed = delta and delta <= row.maxGroundDelta
            local plot = {}
            if allowed then
                for _, item in ipairs(footprint) do
                    plot[item] = true
                    if occupied[item] or streets[item] or item.buildingId or #item.roadIds > 0
                        or item.regionId ~= center.regionId or distance(center, item) > row.radius
                        or not contains(config.regions, map.regions[item.regionId].regionType) then allowed = false end
                end
            end
            if allowed then
                local entries, seen = {}, {}
                for _, item in ipairs(footprint) do
                    for _, other in ipairs(finder.neighbors[item]) do
                        if not plot[other] and not seen[other] and (not occupied[other] or other == center)
                            and math.abs(other.height - base) <= self.maxStep then
                            seen[other] = true; entries[#entries + 1] = other
                        end
                    end
                end
                table.sort(entries, function(a, b)
                    local da, db = distance(center, a), distance(center, b)
                    return da < db or (da == db and finder.indices[a] < finder.indices[b])
                end)
                local path, entrance
                for _, entry in ipairs(entries) do
                    if not row.generateStreets then
                        -- 偏远地点只需要实际干燥入口，不从中心铺街，更不参加城际道路。
                        if not entry.waterLevel and not entry.buildingId and not occupied[entry] and #entry.roadIds == 0 then path = {entry} end
                    else path = finder:FindPath(center, entry, function(a, b)
                        if plot[b] or (occupied[b] and b ~= center) or b.regionId ~= center.regionId
                            or distance(center, b) > row.radius then return nil end
                        return self:EdgeCost(a, b)
                    end) end
                    if path then entrance = entry; break end
                end
                if path then
                    buildings[#buildings + 1] = { config = config, cell = cell, cells = footprint,
                        baseHeight = base, entrance = entrance, path = path }
                    for _, item in ipairs(footprint) do occupied[item] = true end
                    for _, item in ipairs(path) do streets[item] = true end
                    break
                end
            end
        end
    end
    for _, id in ipairs(row.requiredBuildingIds) do
        local found = false
        for _, plan in ipairs(buildings) do if plan.config.id == id then found = true; break end end
        if not found then return nil end
    end
    if #buildings >= row.minBuildings then return buildings end
end
local function addRoad(map, kind, path, townA, townB, buildingId)
    local road = { id = #map.roads + 1, kind = kind, cells = path, townA = townA, townB = townB, buildingId = buildingId }
    map.roads[road.id] = road
    for _, cell in ipairs(path) do cell.roadIds[#cell.roadIds + 1] = road.id end
    return road
end
function Infrastructure:PlaceTowns(map, finder, random, stage)
    for _, row in ipairs(self.rows) do
      if row.placementStage == stage then
        local selection = self.selection
        selection:RefreshCivilization(128)
        local pools, perRegion, attempts, count = {}, {}, {}, 0
        local diagnostic = {configId=row.id,name=row.name,stage=stage,requested=row.maxCount,placed=0,
            hardRejected=0,spacingRejected=0,layoutRejected=0,budgetRejected=0,eligible=0}
        map.siteDiagnostics[#map.siteDiagnostics+1] = diagnostic
        for _, profileId in ipairs(row.siteProfileIds) do
            local profile=selection.profiles:Get(profileId)
            local terrain, water=selection:Analyze(profile)
            local pool={profile=profile,terrain=terrain,water=water,candidates={},cursor=1}
            local rejectedSamples = {}
            pools[#pools+1]=pool
            map.siteProfiles[profileId]=profile
            for _, cell in ipairs(map.cells) do
                local metrics=selection:Metrics(cell,profile,terrain,water)
                local score, reason=selection:Evaluate(profile,metrics)
                if cell.waterLevel then score=nil; reason='water' end
                if not contains(row.regions,map.regions[cell.regionId].regionType) then score=nil; reason='region' end
                -- 被同一硬规则排除的格子共享只读评分记录，避免大地图复制数十万张空评分表。
                if score == nil then
                    if not rejectedSamples[reason] then rejectedSamples[reason] = { reason = reason } end
                    cell.siteScores[profileId] = rejectedSamples[reason]
                else cell.siteScores[profileId]={score=score,reason=reason} end
                if score and score > 0 then
                    -- 指数竞赛实现不放回加权抽选；空间随机流独立，参数相同即可复现。
                    local noise=math.max(1e-9,random:Noise(cell.q,cell.r,1,7907+profileId))
                    pool.candidates[#pool.candidates+1]={cell=cell,score=score,order=-math.log(noise)/score^profile.scoreExponent}
                    diagnostic.eligible=diagnostic.eligible+1
                else diagnostic.hardRejected=diagnostic.hardRejected+1 end
            end
            table.sort(pool.candidates,function(a,b) return a.order < b.order or (a.order==b.order and finder.indices[a.cell]<finder.indices[b.cell]) end)
        end
        while count < row.maxCount do
            local choices={}
            for _, pool in ipairs(pools) do
                if pool.cursor <= math.min(#pool.candidates,pool.profile.candidateBudget) then
                    local noise=math.max(1e-9,random:Noise(count,pool.profile.id,1,17131))
                    choices[#choices+1]={pool=pool,order=-math.log(noise)/pool.profile.pickWeight}
                end
            end
            table.sort(choices,function(a,b) return a.order<b.order or (a.order==b.order and a.pool.profile.id<b.pool.profile.id) end)
            if #choices==0 then break end
            local pool=choices[1].pool
            local candidate=pool.candidates[pool.cursor]; pool.cursor=pool.cursor+1
            local center, allowed = candidate.cell, true
            local regionId = center.regionId
            if (perRegion[regionId] or 0) >= row.maxPerRegion or (attempts[regionId] or 0) >= row.siteAttempts then
                allowed=false; diagnostic.budgetRejected=diagnostic.budgetRejected+1
            end
            for _, town in ipairs(map.towns) do
                if allowed and distance(center,town.center) < math.max(row.minSpacing,town.minSpacing,row.radius+town.radius+1) then
                    allowed=false; diagnostic.spacingRejected=diagnostic.spacingRejected+1; break
                end
            end
            if allowed then
                attempts[regionId] = (attempts[regionId] or 0) + 1
                local area=disk(map,center,1)
                local delta=area and relief(area)
                local metrics=selection:Metrics(center,pool.profile,pool.terrain,pool.water)
                local score=selection:Evaluate(pool.profile,metrics)
                local plans = score and delta and delta<=row.maxGroundDelta and self:PlanTown(map,finder,random,row,center)
                if plans and not selection:CheckPlans(plans,pool.profile,pool.terrain,pool.water) then plans=nil end
                if plans then
                    local town = { id = #map.towns + 1, configId = row.id, name = row.name, regionId = regionId, groundColor = row.groundColor,
                        center = center, radius = row.radius, minSpacing = row.minSpacing, buildings = {}, roadIds = {},
                        role=stage=='AfterRoads' and 'remote' or 'settlement',connectRoad=row.connectRoad,
                        siteProfileId=pool.profile.id,siteScore=score,siteMetrics=metrics }
                    map.towns[town.id] = town
                    local region = map.regions[regionId]; region.towns[#region.towns + 1] = town
                    for _, cell in ipairs(region.cells) do
                        if distance(center, cell) <= row.radius and not cell.waterLevel then cell.townId = town.id end
                    end
                    for _, plan in ipairs(plans) do
                        local building = { id = #map.buildings + 1, configId = plan.config.id, name = plan.config.name,
                            townId = town.id, regionId = regionId, cell = plan.cell, cells = plan.cells, entrance = plan.entrance,
                            baseHeight = plan.baseHeight, height = plan.config.height, roofHeight = plan.config.roofHeight,
                            assetId = plan.config.assetId, platformAssetId = plan.config.platformAssetId,
                            footprintRadius = plan.config.footprintRadius }
                        map.buildings[building.id] = building; town.buildings[#town.buildings + 1] = building
                        region.buildings[#region.buildings + 1] = building
                        for _, cell in ipairs(building.cells) do cell.buildingId = building.id end
                        if row.generateStreets then
                            local road = addRoad(map, 'street', plan.path, town.id, nil, building.id)
                            town.roadIds[#town.roadIds + 1] = road.id
                        end
                    end
                    count = count + 1; perRegion[regionId] = (perRegion[regionId] or 0) + 1
                    selection:RefreshCivilization(128)
                else diagnostic.layoutRejected=diagnostic.layoutRejected+1 end
            end
        end
        diagnostic.placed=count
      end
    end
end
-- 近邻优先的连通森林：只连接不同连通分量，水域隔断时明确保留多个道路网络。
function Infrastructure:ConnectTowns(map, finder)
    local parent, pairs = {}, {}
    for _, town in ipairs(map.towns) do if town.connectRoad then parent[town.id] = town.id end end
    local function root(id)
        while parent[id] ~= id do parent[id] = parent[parent[id]]; id = parent[id] end
        return id
    end
    for a = 1, #map.towns do for b = a + 1, #map.towns do
        if parent[a] and parent[b] then pairs[#pairs + 1] = { a = a, b = b, span = distance(map.towns[a].center, map.towns[b].center) } end
    end end
    table.sort(pairs, function(a, b) return a.span < b.span or (a.span == b.span and (a.a < b.a or (a.a == b.a and a.b < b.b))) end)
    for _, pair in ipairs(pairs) do
        if root(pair.a) ~= root(pair.b) then
            local a, b = map.towns[pair.a], map.towns[pair.b]
            local path = finder:FindPath(a.center, b.center, function(from, to) return self:EdgeCost(from, to) end)
            if path then
                local road = addRoad(map, 'road', path, a.id, b.id)
                a.roadIds[#a.roadIds + 1] = road.id; b.roadIds[#b.roadIds + 1] = road.id
                parent[root(b.id)] = root(a.id)
            end
        end
    end
    local networks = {}
    for _, town in ipairs(map.towns) do
      if town.connectRoad then
        local id = root(town.id)
        if not networks[id] then
            local network = { id = #map.roadNetworks + 1, townIds = {} }
            networks[id] = network; map.roadNetworks[network.id] = network
        end
        local network = networks[id]; network.townIds[#network.townIds + 1] = town.id; town.roadNetworkId = network.id
      end
    end
end
function Infrastructure:Build(map)
    for _, cell in ipairs(map.cells) do cell.roadIds = {} end
    if #self.rows == 0 then return end
    local finder = Pathfinder(map)
    self.selection:Begin(map,finder)
    -- 独立随机流使城镇配置调整不会反过来改变地貌轮廓和高度。
    self:PlaceTowns(map, finder, Random(map.seed ~ 0x51f2a913),'BeforeRoads')
    self:ConnectTowns(map, finder)
    self:PlaceTowns(map, finder, Random(map.seed ~ 0x394f318b),'AfterRoads')
    self.selection:Finish()
end
return Infrastructure
