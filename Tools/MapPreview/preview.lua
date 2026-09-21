-- 预览适配器只启动工程系统并序列化查询结果，不实现另一套读表或地图算法。
local snapshotRoot, seed, regionIds = ...
-- 限定本次快照的搜索路径，避免混入请求期间保存的新源码或旧 Generated 文件。
package.path = snapshotRoot .. '/Lua/?.lua'
local json = assert(loadfile('Tools/MapPreview/json.lua'))()
local HexGrid = require('Game.Map.HexGrid')
local registry = require('Core.SystemRegistry')({
    -- 与 Unity 的 ReadConfig 契约一致，读取真实导出器生成的二进制。
    ReadConfig = function(_, name)
        local file = assert(io.open(snapshotRoot .. '/Assets/GameFramework/Resources/Config/' .. name .. '.bytes', 'rb'))
        local bytes = file:read('*a'); file:close(); return bytes
    end,
    LogError = function(_, message) error(message) end,
})
registry:Register('Config', require('Config.ConfigSystem'))
registry:Register('Map', require('Game.Map.MapSystem'), {'Config'})
local ok, result = xpcall(function()
    registry:Start()
    local config = registry:Get('Config')
    local map = registry:Get('Map'):Generate(seed, regionIds)
    local output = { seed = map.seed, generationVersion = map.generationVersion, hexRadius = map.hexRadius,
        cells = json.array(), regions = json.array(), borders = json.array(), waterBodies = json.array(), recipe = json.array(regionIds),
        towns = json.array(), buildings = json.array(), roads = json.array(), roadNetworks = json.array(),
        rivers = json.array(), waterfalls = json.array(), decorations = json.array(), assets = json.array() }
    for _, asset in ipairs(map.assets) do
        output.assets[#output.assets+1] = { id=asset.id, name=asset.name, prefabPath=asset.prefabPath,
            previewShape=asset.previewShape, previewColor=asset.previewColor, referenceHeight=asset.referenceHeight }
    end
    -- 对象引用转换为从 1 开始的 JSON 索引，避免复制格子和循环引用。
    local indices, typeNames = {}, {}
    for name, value in pairs(config:GetEnum('Map', 'E_MapRegion')) do typeNames[value] = name end
    for index, cell in ipairs(map:GetCells()) do indices[cell] = index end
    -- 冻结后的布局数组不可修改元表；复制标量索引后再添加 JSON 数组标记。
    local function idsArray(source)
        local items = json.array(); for i, value in ipairs(source) do items[i] = value end
        return items
    end
    local minimum, maximum, waterCells = math.huge, -math.huge, 0
    for index, cell in ipairs(map:GetCells()) do
        local x, y, z = map:GetCellWorldPosition(cell.q, cell.r)
        local neighbors = json.array()
        -- 保留完整六方向槽位；0 表示地图外，前端据此绘制外露柱面。
        for direction = 1, 6 do
            local q, r = HexGrid.Neighbor(cell.q, cell.r, direction)
            local neighbor = map:FindCell(q, r)
            neighbors[direction] = neighbor and indices[neighbor] or 0
        end
        local weights = json.array()
        for _, weight in ipairs(cell.biomeWeights) do weights[#weights + 1] = { regionType = weight.regionType, weight = weight.weight } end
        output.cells[index] = { q = cell.q, r = cell.r, height = y, baseHeight = cell.baseHeight, x = x, z = z,
            regionId = cell.regionId, neighbors = neighbors, blendAmount = cell.blendAmount, biomeWeights = weights,
            waterLevel = cell.waterLevel, waterDepth = cell.waterDepth, waterKind = cell.waterKind, waterBodyId = cell.waterBodyId,
            townId = cell.townId, buildingId = cell.buildingId, roadIds = idsArray(cell.roadIds),
            groundColor = idsArray(cell.groundColor), terrainAssetId = cell.terrainAssetId, waterAssetId = cell.waterAssetId,
            decorationId = cell.decorationId, riverId = cell.riverId, flowTo = cell.flowTo and indices[cell.flowTo],
            waterfallId = cell.waterfallId, hydrologyCarved = cell.hydrologyCarved or false }
        if cell.waterLevel then waterCells = waterCells + 1 end
        minimum = math.min(minimum, y); maximum = math.max(maximum, y)
    end
    -- 水体仅输出格子索引，地面与水面共享同一份格子记录。
    for _, body in ipairs(map:GetWaterBodies()) do
        local cells = json.array()
        for _, cell in ipairs(body.cells) do cells[#cells + 1] = indices[cell] end
        output.waterBodies[#output.waterBodies + 1] = { id = body.id, kind = body.kind, level = body.level, cells = cells }
    end
    -- 城镇、建筑和道路均序列化真实 Lua 布局，网页只按占地与高度绘制占位模型。
    local function cellIndices(cells)
        local result = json.array(); for _, cell in ipairs(cells) do result[#result + 1] = indices[cell] end
        return result
    end
    for _, town in ipairs(map:GetTowns()) do
        local buildings = json.array(); for _, building in ipairs(town.buildings) do buildings[#buildings + 1] = building.id end
        output.towns[#output.towns + 1] = { id = town.id, configId = town.configId, name = town.name, regionId = town.regionId, groundColor = town.groundColor,
            center = indices[town.center], radius = town.radius, buildings = buildings, roadIds = idsArray(town.roadIds), roadNetworkId = town.roadNetworkId }
    end
    for _, building in ipairs(map:GetBuildings()) do
        output.buildings[#output.buildings + 1] = { id = building.id, configId = building.configId, name = building.name,
            townId = building.townId, regionId = building.regionId, cell = indices[building.cell], cells = cellIndices(building.cells),
            entrance = indices[building.entrance], baseHeight = building.baseHeight, height = building.height,
            assetId = building.assetId, platformAssetId = building.platformAssetId,
            roofHeight = building.roofHeight, footprintRadius = building.footprintRadius }
    end
    for _, river in ipairs(map:GetRivers()) do
        output.rivers[#output.rivers+1] = { id=river.id, kind=river.kind, rootId=river.rootId, parentRiverId=river.parentRiverId,
            cells=cellIndices(river.cells), source=indices[river.source], mouth=indices[river.mouth], regionIds=idsArray(river.regionIds) }
    end
    for _, waterfall in ipairs(map:GetWaterfalls()) do
        output.waterfalls[#output.waterfalls+1] = { id=waterfall.id, from=indices[waterfall.from], to=indices[waterfall.to],
            drop=waterfall.drop, riverId=waterfall.riverId, poolCells=cellIndices(waterfall.poolCells) }
    end
    for _, item in ipairs(map:GetDecorations()) do
        output.decorations[#output.decorations+1] = { id=item.id, cell=indices[item.cell], assetId=item.assetId, scale=item.scale, yaw=item.yaw }
    end
    local roadCount = 0
    for _, road in ipairs(map:GetRoads()) do
        output.roads[#output.roads + 1] = { id = road.id, kind = road.kind, cells = cellIndices(road.cells),
            townA = road.townA, townB = road.townB, buildingId = road.buildingId }
        if road.kind == 'road' then roadCount = roadCount + 1 end
    end
    for _, network in ipairs(map:GetRoadNetworks()) do
        output.roadNetworks[#output.roadNetworks + 1] = { id = network.id, townIds = idsArray(network.townIds) }
    end
    -- 只展示候选配置的标识和名称，不实例化玩法实体。
    local function candidates(rows)
        local items = json.array()
        for _, row in ipairs(rows) do items[#items + 1] = { id = row.id, name = row.name } end
        return items
    end
    for _, region in ipairs(map:GetRegions()) do
        local neighbors = json.array()
        for i, id in ipairs(region:GetNeighborIds()) do neighbors[i] = id end
        output.regions[#output.regions + 1] = { instanceId = region.instanceId, configId = region.configId,
            regionType = region.regionType, typeName = assert(typeNames[region.regionType]),
            sizeX = region.sizeX, sizeY = region.sizeY, cellCount = #region:GetCells(),
            neighborIds = neighbors, enemies = candidates(region:GetEnemyConfigs()), buildings = candidates(region:GetBuildingConfigs()) }
    end
    local edges = 0
    for _, border in ipairs(map:GetBorders()) do
        local borderEdges = json.array()
        for _, edge in ipairs(border.edges) do
            borderEdges[#borderEdges + 1] = { a = indices[edge.a], b = indices[edge.b], heightDelta = edge.heightDelta }
            edges = edges + 1
        end
        output.borders[#output.borders + 1] = { regionA = border.regionA, regionB = border.regionB, edges = borderEdges }
    end
    output.stats = { cellCount = #output.cells, regionCount = #output.regions,
        borderCount = #output.borders, sharedEdges = edges, minHeight = minimum, maxHeight = maximum,
        waterCellCount = waterCells, waterBodyCount = #output.waterBodies,
        townCount = #output.towns, buildingCount = #output.buildings, roadCount = roadCount,
        streetCount = #output.roads - roadCount, roadNetworkCount = #output.roadNetworks,
        riverCount = #output.rivers, waterfallCount = #output.waterfalls, decorationCount = #output.decorations }
    return json.encode(output)
end, debug.traceback)
-- 无论生成成功与否，都按工程系统生命周期执行关闭。
registry:Shutdown()
if not ok then error(result, 0) end
return result
