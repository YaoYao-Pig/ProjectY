-- 依据区域配方生成连通、无重叠的只读布局，统一维护格子与区域边界索引。
local Class = require('Core.Class')
local HexGrid = require('Game.Map.HexGrid')
local Random = require('Game.Map.SeededRandom')
local Map = require('Game.Map.Map')
local TerrainBlend = require('Game.Map.TerrainBlend')
local Infrastructure = require('Game.Map.MapInfrastructure')
local Hydrology = require('Game.Map.MapHydrology')
local Visuals = require('Game.Map.MapVisuals')
local Generator = Class('MapGenerator')

local function finite(value, label)
    assert(type(value) == 'number' and math.abs(value) < math.huge, label .. ' must be finite')
end
local function positiveInteger(value, label)
    finite(value, label)
    assert(value > 0 and value == math.floor(value), label .. ' must be a positive integer')
end
local function validateSpan(minimum, maximum, label)
    finite(minimum, label); finite(maximum, label)
    assert(minimum > 0 and minimum <= maximum and math.ceil(minimum) <= math.floor(maximum), label .. ' must contain a positive whole-cell span')
end
-- 布局与各级索引一起冻结；seen 保留共享对象身份，代理仍能调用原类方法。
-- 配表记录已经是 ConfigTable 的只读代理，不重复包装。
local function freeze(value, seen)
    if type(value) ~= 'table' or getmetatable(value) == false then return value end
    if seen[value] then return seen[value] end
    local proxy, data, class = {}, {}, getmetatable(value)
    seen[value] = proxy
    for key, item in pairs(value) do data[key] = freeze(item, seen) end
    return setmetatable(proxy, {
        __index = function(_, key)
            local item = data[key]
            if item ~= nil then return item end
            if class then return class[key] end
        end,
        __newindex = function() error('Map layout is read-only', 2) end,
        __pairs = function() return next, data, nil end,
        __len = function() return #data end,
        __metatable = false,
    })
end
-- 可写草稿只在一次生成内部存在，不向业务层泄漏中间状态。
local Draft = Class('MapGenerationDraft')
function Draft:ctor(generator, random)
    self.map = Map(random.seed, generator.hexRadius); self.random = random
    self.noiseScale = generator.noiseScale; self.cellLimit = generator.cellLimit
    self.blendWidth = generator.blendWidth
    self.infrastructure = generator.infrastructure
    self.hydrology = generator.hydrology; self.visuals = generator.visuals
    self.terrain = {}; self.frontier = {}; self.frontierByKey = {}
    self.enemyConfigs = generator.enemyConfigs; self.buildingConfigs = generator.buildingConfigs
    for regionType in pairs(generator.regionTypes) do self.map.regionsByType[regionType] = {} end
end
function Draft:CheckCapacity(amount)
    assert(amount <= self.cellLimit - #self.map.cells, 'Map generation exceeds MaxCells')
end
-- 目标格数模式只裁剪最后一块。以接壤格为起点扩张，保留区域与全图的连通性。
function Draft:FitBudget(q, r, footprint)
    if not self.map.targetCells then return footprint end
    local remaining = self.map.targetCells - #self.map.cells
    if #footprint.cells <= remaining then return footprint end
    local available, start, best = {}, nil, math.huge
    for _, point in ipairs(footprint.cells) do
        available[HexGrid.Key(point.q, point.r)] = point
        local touches = #self.map.cells == 0
        for direction = 1, 6 do
            local nq, nr = HexGrid.Neighbor(q + point.q, r + point.r, direction)
            if self.map.cellsByKey[HexGrid.Key(nq, nr)] then touches = true end
        end
        local distance = HexGrid.Distance(point.q, point.r, footprint.centerQ, footprint.centerR)
        if touches and distance < best then start, best = point, distance end
    end
    assert(start and remaining > 0, 'Final region requires an adjoining cell and positive budget')
    local cells, seen, head = { start }, { [HexGrid.Key(start.q, start.r)] = true }, 1
    while #cells < remaining do
        local point = assert(cells[head], 'Final region footprint is disconnected'); head = head + 1
        for direction = 1, 6 do
            local nq, nr = HexGrid.Neighbor(point.q, point.r, direction)
            local key = HexGrid.Key(nq, nr)
            if available[key] and not seen[key] and #cells < remaining then
                seen[key] = true; cells[#cells + 1] = available[key]
            end
        end
    end
    table.sort(cells, function(a, b) return a.r < b.r or (a.r == b.r and a.q < b.q) end)
    return { cells = cells, centerQ = start.q, centerR = start.r }
end
function Draft:CanPlace(q, r, footprint)
    for _, offset in ipairs(footprint.cells) do
        if self.map.cellsByKey[HexGrid.Key(q + offset.q, r + offset.r)] then return false end
    end
    return true
end
-- 允许轮廓包围盒相互穿插，只保留未占用的中心连通块，形成更宽的曲折共享边。
function Draft:FitPlacement(q, r, footprint)
    local available = {}
    for _, point in ipairs(footprint.cells) do
        if not self.map.cellsByKey[HexGrid.Key(q + point.q, r + point.r)] then
            available[HexGrid.Key(point.q, point.r)] = point
        end
    end
    local centerKey = HexGrid.Key(footprint.centerQ, footprint.centerR)
    local center = available[centerKey]
    if not center then return nil end
    local cells, seen, head, contacts = { center }, { [centerKey] = true }, 1, 0
    while head <= #cells do
        local point = cells[head]; head = head + 1
        for direction = 1, 6 do
            local nq, nr = HexGrid.Neighbor(point.q, point.r, direction)
            local key = HexGrid.Key(nq, nr)
            if available[key] and not seen[key] then seen[key] = true; cells[#cells + 1] = available[key] end
            if self.map.cellsByKey[HexGrid.Key(q + nq, r + nr)] then contacts = contacts + 1 end
        end
    end
    -- 不接受狭长碎屑或与全图断开的剩余块；中心保留以维护湖盆/河谷的地貌锚点。
    if contacts == 0 or #cells < #footprint.cells * 0.6 then return nil end
    table.sort(cells, function(a, b) return a.r < b.r or (a.r == b.r and a.q < b.q) end)
    return { cells = cells, centerQ = footprint.centerQ, centerR = footprint.centerR }, contacts
end
function Draft:FindPlacement(footprint, random)
    if #self.map.regions == 0 then return -footprint.centerQ, -footprint.centerR, footprint end
    local bestQ, bestR, bestScore, bestFootprint
    -- 从实际外沿空格尝试贴合，优先共享边更多的方案，避免按矩形边机械拼接。
    for _ = 1, 64 do
        local target = self.frontier[random:Integer(1, #self.frontier)]
        local point = footprint.cells[random:Integer(1, #footprint.cells)]
        local q, r = target.q - point.q, target.r - point.r
        local placed, contacts = self:FitPlacement(q, r, footprint)
        if placed then
            local score = contacts - (math.abs(q + footprint.centerQ) + math.abs(r + footprint.centerR)) * 0.001
            if not bestScore or score > bestScore then bestQ, bestR, bestScore, bestFootprint = q, r, score, placed end
        end
    end
    if bestQ then return bestQ, bestR, bestFootprint end
    -- 最东格子的东邻必然空闲；将新轮廓最西格贴上去，保证有限步内完成。
    local anchor = self.easternmost
    return anchor.q + 1 - footprint.west.q, anchor.r - footprint.west.r, footprint
end
-- 同步填充总格子列表、坐标索引和区域列表，让所有查询引用同一个格子对象。
function Draft:AddRegion(config, q, r, sizeX, sizeY, instanceType, footprint, convert)
    positiveInteger(sizeX, 'Region sizeX'); positiveInteger(sizeY, 'Region sizeY')
    HexGrid.CheckCoordinate(q, r); self:CheckCapacity(#footprint.cells)
    assert(self:CanPlace(q, r, footprint), 'Region placement overlaps the existing map')
    local map = self.map
    local region = instanceType(#map.regions + 1, config, q, r, sizeX, sizeY,
        self.enemyConfigs[config.MapRegion], self.buildingConfigs[config.MapRegion])
    map.regions[region.instanceId] = region
    region.centerQ = q + footprint.centerQ; region.centerR = r + footprint.centerR
    self.terrain[region.instanceId] = { config = config, region = region, convert = convert }
    local instances = map.regionsByType[config.MapRegion]
    instances[#instances + 1] = region
    for _, point in ipairs(footprint.cells) do
        local cq, cr = q + point.q, r + point.r
        local height, waterLevel, waterKind = convert:GetHeight(config, cq, cr, self.random, self.noiseScale, region)
        finite(height, 'Cell height')
        assert(height >= config.minHeight and height <= config.maxHeight, 'Cell height is outside region bounds')
        local cell = { q = cq, r = cr, height = height, baseHeight = height, regionId = region.instanceId,
            waterLevel = waterLevel, waterKind = waterLevel and waterKind or nil }
        map.cells[#map.cells + 1] = cell; map.cellsByKey[HexGrid.Key(cq, cr)] = cell
        region.cells[#region.cells + 1] = cell; region.cellsByKey[HexGrid.Key(cq, cr)] = cell
        if not self.easternmost or cq > self.easternmost.q then self.easternmost = cell end
    end
    -- 外沿采用稠密数组与键索引，删除已占用格时交换末项，随机采样无需扫描全图。
    for _, cell in ipairs(region.cells) do
        local key = HexGrid.Key(cell.q, cell.r)
        local existing = self.frontierByKey[key]
        if existing then
            local last = self.frontier[#self.frontier]
            self.frontier[existing.index] = last; last.index = existing.index
            self.frontier[#self.frontier] = nil; self.frontierByKey[key] = nil
        end
        for direction = 1, 6 do
            local nq, nr = HexGrid.Neighbor(cell.q, cell.r, direction)
            local neighborKey = HexGrid.Key(nq, nr)
            if not map.cellsByKey[neighborKey] and not self.frontierByKey[neighborKey] then
                local entry = { q = nq, r = nr, index = #self.frontier + 1 }
                self.frontier[entry.index] = entry; self.frontierByKey[neighborKey] = entry
            end
        end
    end
end
-- 每条跨区域共享边只从较小实例 ID 记录一次；同地貌的不同实例仍有边界。
function Draft:Build()
    local map = self.map
    -- 先混合地貌再整理水位；Border 保存最终高差，避免查询看到过渡前的旧值。
    TerrainBlend.Apply(map, self.terrain, self.random, self.noiseScale, self.blendWidth)
    self.hydrology:Build(map)
    self.infrastructure:Build(map)
    self.visuals:Build(map)
    for _, cell in ipairs(map.cells) do
        for direction = 1, 6 do
            local q, r = HexGrid.Neighbor(cell.q, cell.r, direction)
            local other = map.cellsByKey[HexGrid.Key(q, r)]
            if other and cell.regionId < other.regionId then
                local key = cell.regionId .. ':' .. other.regionId
                local border = map.bordersByPair[key]
                if not border then
                    border = { regionA = cell.regionId, regionB = other.regionId, edges = {} }
                    map.bordersByPair[key] = border; map.borders[#map.borders + 1] = border
                    local a, b = map.regions[border.regionA], map.regions[border.regionB]
                    a.borders[#a.borders + 1] = border; b.borders[#b.borders + 1] = border
                    a.neighborIds[#a.neighborIds + 1] = b.instanceId
                    b.neighborIds[#b.neighborIds + 1] = a.instanceId
                end
                border.edges[#border.edges + 1] = { a = cell, b = other, heightDelta = other.height - cell.height }
            end
        end
    end
    for _, region in ipairs(map.regions) do table.sort(region.neighborIds) end
    return freeze(map, {})
end

-- 预先按地貌类型分组实体候选配置；这里只筛选配置，不生成敌人或建筑。
local function indexEligible(rows, regionTypes)
    local index = {}
    for regionType in pairs(regionTypes) do index[regionType] = {} end
    for _, row in ipairs(rows) do
        local seen = {}
        for _, regionType in ipairs(row.regions) do
            assert(index[regionType], 'Spawn config refers to an unknown region type')
            assert(not seen[regionType], 'Spawn config contains a duplicate region type')
            seen[regionType] = true
            local entries = index[regionType]; entries[#entries + 1] = row
        end
    end
    return index
end
-- 初始化时校验表与常量，使非法配置在首次生成前暴露。
function Generator:ctor(config)
    self.config = config; self.registrations = {}; self.regionTypes = {}
    for _, value in pairs(config:GetEnum('Map', 'E_MapRegion')) do self.regionTypes[value] = true end
    self.regionTable = config:GetTable('MapRegionTable')
    self.hexRadius = config:GetConstant('Map', 'HexRadius')
    self.noiseScale = config:GetConstant('Map', 'HeightNoiseScale')
    self.cellLimit = config:GetConstant('Map', 'MaxCells')
    self.blendWidth = config:GetConstant('Map', 'BorderBlendWidth')
    finite(self.hexRadius, 'HexRadius'); assert(self.hexRadius > 0, 'HexRadius must be positive')
    finite(self.noiseScale, 'HeightNoiseScale'); assert(self.noiseScale >= 1, 'HeightNoiseScale must be at least one cell')
    positiveInteger(self.cellLimit, 'MaxCells')
    finite(self.blendWidth, 'BorderBlendWidth')
    assert(self.blendWidth >= 0 and self.blendWidth <= 12 and self.blendWidth == math.floor(self.blendWidth), 'BorderBlendWidth must be an integer in 0..12')
    for _, row in ipairs(self.regionTable:All()) do
        assert(self.regionTypes[row.MapRegion], 'Region config uses an unknown enum value')
        validateSpan(row.minX, row.maxX, 'Region X span'); validateSpan(row.minY, row.maxY, 'Region Y span')
        assert(row.maxX <= self.cellLimit and row.maxY <= self.cellLimit, 'Region span exceeds MaxCells')
        finite(row.minHeight, 'minHeight'); finite(row.maxHeight, 'maxHeight')
        assert(row.minHeight <= row.maxHeight, 'Region minHeight exceeds maxHeight')
        for _, name in ipairs({'shapeIrregularity', 'roughness'}) do
            finite(row[name], name); assert(row[name] >= 0 and row[name] <= 1, name .. ' must be in 0..1')
        end
        finite(row.noiseScale, 'noiseScale'); assert(row.noiseScale >= 0.1 and row.noiseScale <= 8, 'noiseScale must be in 0.1..8')
        finite(row.warpStrength, 'warpStrength'); assert(row.warpStrength >= 0 and row.warpStrength <= 2, 'warpStrength must be in 0..2')
        finite(row.waterLevel, 'waterLevel')
        finite(row.riverWidth, 'riverWidth'); assert(row.riverWidth >= 0.5 and row.riverWidth <= 12, 'riverWidth must be in 0.5..12')
        finite(row.lakeSize, 'lakeSize'); assert(row.lakeSize >= 0.15 and row.lakeSize <= 0.75, 'lakeSize must be in 0.15..0.75')
    end
    self.enemyConfigs = indexEligible(config:GetTable('MapEnemyTable'):All(), self.regionTypes)
    self.buildingConfigs = indexEligible(config:GetTable('MapBuildingTable'):All(), self.regionTypes)
    self.infrastructure = Infrastructure(config, self.regionTypes)
    self.hydrology = Hydrology(config)
    self.visuals = Visuals(config, self.regionTypes)
end
-- 地貌扩展点：每种枚举分别绑定生成转换器与查询实例类。
function Generator:RegisterRegion(regionType, convertType, instanceType)
    assert(self.regionTypes[regionType], 'RegisterRegion requires an E_MapRegion value')
    assert(not self.registrations[regionType], 'Duplicate region converter registration')
    assert(type(convertType.Generate) == 'function' and type(instanceType.GetCells) == 'function', 'Invalid region implementation')
    self.registrations[regionType] = { convert = convertType(), instance = instanceType }
end
-- regionIds 为有序、连续的配置 ID 数组；重复 ID 表示生成多个独立实例。
function Generator:Generate(seed, regionIds, targetCells)
    local random = Random(seed)
    if targetCells ~= nil then
        positiveInteger(targetCells, 'Target cells')
        assert(targetCells <= self.cellLimit, 'Target cells exceeds MaxCells')
    end
    assert(type(regionIds) == 'table' and #regionIds > 0 and #regionIds <= self.cellLimit, 'Supply a nonempty region config ID array')
    local count = 0
    for key in pairs(regionIds) do
        assert(type(key) == 'number' and key == math.floor(key) and key >= 1 and key <= #regionIds, 'Region IDs must be a dense array')
        count = count + 1
    end
    assert(count == #regionIds, 'Region IDs must be a dense array')
    -- 先解析完整配方再执行转换器；缺配置或未绑定地貌直接作为配置错误报出。
    local rows = {}
    for i, id in ipairs(regionIds) do
        local row = self.regionTable:Get(id)
        assert(self.registrations[row.MapRegion], 'Missing converter for region type ' .. tostring(row.MapRegion))
        self.registrations[row.MapRegion].convert:ValidateConfig(row)
        rows[i] = row
    end
    local draft = Draft(self, random)
    draft.map.targetCells = targetCells
    local index = 1
    -- 未指定目标时仍只生成一遍配方；指定后循环配方，数量由实际占地决定。
    while targetCells and #draft.map.cells < targetCells or not targetCells and index <= #rows do
        local row = rows[(index - 1) % #rows + 1]
        local registration = self.registrations[row.MapRegion]
        local map2 = registration.convert:Generate(draft, row, random, registration.instance)
        assert(map2 == draft, 'Region converters must return the accumulated map draft')
        index = index + 1
    end
    return draft:Build()
end
return Generator
