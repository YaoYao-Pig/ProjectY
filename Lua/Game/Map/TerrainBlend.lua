-- 地貌接缝处理：在同一世界位置采样相邻策略，按到区域的六邻接距离平滑混合。
-- 不做整图模糊；过渡带之外保留各策略原貌，避免山脊和河床被抹平。
local HexGrid = require('Game.Map.HexGrid')
local Terrain = require('Game.Map.TerrainNoise')
local Blend = {}
function Blend.Apply(map, sources, random, noiseScale, width)
    local distances, queue, head = {}, {}, 1
    for _, cell in ipairs(map.cells) do
        distances[cell] = { [cell.regionId] = 0 }
        queue[#queue + 1] = { cell = cell, regionId = cell.regionId, distance = 0 }
    end
    -- 多源广度优先传播：每个格子只记录过渡宽度内可达的区域，不扫描所有 Region。
    while head <= #queue do
        local entry = queue[head]; head = head + 1
        if entry.distance < width then
            for direction = 1, 6 do
                local q, r = HexGrid.Neighbor(entry.cell.q, entry.cell.r, direction)
                local other = map.cellsByKey[HexGrid.Key(q, r)]
                if other and distances[other][entry.regionId] == nil then
                    distances[other][entry.regionId] = entry.distance + 1
                    queue[#queue + 1] = { cell = other, regionId = entry.regionId, distance = entry.distance + 1 }
                end
            end
        end
    end
    for _, cell in ipairs(map.cells) do
        local ids = {}; for id in pairs(distances[cell]) do ids[#ids + 1] = id end
        table.sort(ids)
        local sum, height, waterSum, waterWeight, kindWeight, waterKind = 0, 0, 0, 0, 0, nil
        local types = {}
        for _, id in ipairs(ids) do
            local source = sources[id]
            local weight = 1 - Terrain.Smooth(0, width + 1, distances[cell][id])
            local ground, level, kind
            if id == cell.regionId then ground, level, kind = cell.baseHeight, cell.waterLevel, cell.waterKind
            else ground, level, kind = source.convert:GetHeight(source.config, cell.q, cell.r, random, noiseScale, source.region) end
            assert(type(ground) == 'number' and math.abs(ground) < math.huge, 'Terrain strategy returned non-finite height')
            assert(ground >= source.config.minHeight and ground <= source.config.maxHeight, 'Terrain strategy height is outside configured bounds')
            height = height + ground * weight; sum = sum + weight
            local regionType = source.region.regionType
            types[regionType] = (types[regionType] or 0) + weight
            if level then
                assert(type(level) == 'number' and math.abs(level) < math.huge and (kind == 'lake' or kind == 'river'), 'Invalid terrain water sample')
                waterSum = waterSum + level * weight; waterWeight = waterWeight + weight
                if weight > kindWeight then kindWeight = weight; waterKind = kind end
            end
        end
        -- min/max 约束策略原始采样；过渡结果允许超出所属区域范围，避免截断后重新形成台阶。
        -- 正权重混合仍处于参与策略采样的高度包络之内，不改变区域主体和格子归属。
        cell.height = height / sum
        cell.blendAmount = 1 - 1 / sum
        cell.waterLevel = waterWeight > 0 and waterSum / waterWeight or nil
        cell.waterKind = waterKind
        local sortedTypes = {}; for id in pairs(types) do sortedTypes[#sortedTypes + 1] = id end
        table.sort(sortedTypes); cell.biomeWeights = {}; cell.regionWeights = {}
        -- 水文配置绑定实例配置 ID；同地貌的两个区域也可以采用不同的局部参数。
        for _, id in ipairs(ids) do
            cell.regionWeights[#cell.regionWeights + 1] = { regionId=id,
                weight=(1-Terrain.Smooth(0, width+1, distances[cell][id])) / sum }
        end
        for _, id in ipairs(sortedTypes) do
            cell.biomeWeights[#cell.biomeWeights + 1] = { regionType = id, weight = types[id] / sum }
        end
    end
end
return Blend
