-- 将只读布局复制为渲染输入；不生成地形、不修改快照、不创建玩法实体。
return function(map)
    local result = { seed = map.seed, generationVersion = map.generationVersion, hexRadius = map.hexRadius,
        cells = {}, buildings = {}, roads = {}, towns = {}, regionCount = #map:GetRegions(),
        assets = {}, decorations = {}, waterfalls = {}, rivers = {} }
    local indices = {}
    for i, cell in ipairs(map:GetCells()) do indices[cell] = i end
    local function cellIds(cells)
        local ids = {}; for i, cell in ipairs(cells) do ids[i] = assert(indices[cell]) end
        return ids
    end
    for i, cell in ipairs(map:GetCells()) do
        local x, y, z = map:GetCellWorldPosition(cell.q, cell.r)
        local weights = {}
        for j, item in ipairs(cell.biomeWeights) do
            weights[j] = { regionType = item.regionType, weight = item.weight }
        end
        result.cells[i] = { x = x, y = y, z = z, hasWater = cell.waterLevel ~= nil,
            waterLevel = cell.waterLevel or 0, weights = weights,
            groundColor = {cell.groundColor[1], cell.groundColor[2], cell.groundColor[3]},
            neighbors = cellIds(map:GetNeighbors(cell.q, cell.r)),
            terrainAssetId = cell.terrainAssetId, waterAssetId = cell.waterAssetId }
    end
    for i, town in ipairs(map:GetTowns()) do
        result.towns[i] = { name = town.name, center = indices[town.center], groundColor = town.groundColor }
    end
    for i, building in ipairs(map:GetBuildings()) do
        result.buildings[i] = { configId = building.configId, townId = building.townId,
            center = indices[building.cell], entrance = indices[building.entrance], cells = cellIds(building.cells),
            baseHeight = building.baseHeight, height = building.height, roofHeight = building.roofHeight,
            assetId = building.assetId, platformAssetId = building.platformAssetId,
            footprintRadius = building.footprintRadius }
    end
    for i, road in ipairs(map:GetRoads()) do result.roads[i] = { kind = road.kind, cells = cellIds(road.cells) } end
    for i, item in ipairs(map:GetDecorations()) do
        result.decorations[i] = { cell = indices[item.cell], assetId = item.assetId, scale = item.scale, yaw = item.yaw }
    end
    for i, item in ipairs(map:GetWaterfalls()) do
        result.waterfalls[i] = { from = indices[item.from], to = indices[item.to], drop = item.drop }
    end
    for i, river in ipairs(map:GetRivers()) do result.rivers[i] = { kind = river.kind, cells = cellIds(river.cells) } end
    -- 共用资源表还包含小地图陈设；大地图仅携带实际渲染引用，避免要求场景绑定无关模型。
    local required = {}
    for _, cell in ipairs(result.cells) do
        required[cell.terrainAssetId] = true
        if cell.hasWater then required[cell.waterAssetId] = true end
    end
    for _, building in ipairs(result.buildings) do
        required[building.assetId], required[building.platformAssetId] = true, true
    end
    for _, item in ipairs(result.decorations) do required[item.assetId] = true end
    -- 保留资源表顺序并复制为连续普通数组，避免只读代理及空洞数组跨越 Lua/C# 边界。
    for _, asset in ipairs(map.assets) do
        if required[asset.id] then
            result.assets[#result.assets + 1] = { id = asset.id, prefabPath = asset.prefabPath,
                referenceHeight = asset.referenceHeight, tintMaterial = asset.tintMaterial }
            required[asset.id] = nil
        end
    end
    assert(next(required) == nil, '大地图渲染引用了资源表中不存在的模型：' .. tostring(next(required)))
    return result
end
