-- 配置驱动的资源选择和确定性装饰散布；在水体、聚落和道路完成之后执行。
local Class = require('Core.Class')
local Random = require('Game.Map.SeededRandom')
local Groundcover = require('Game.Map.MapGroundcover')
local Landforms = require('Game.Map.MapLandforms')
local Visuals = Class('MapVisuals')
local function color(text)
    assert(type(text) == 'string' and text:match('^#%x%x%x%x%x%x$'), 'Map color must be #RRGGBB')
    return { tonumber(text:sub(2,3),16)/255, tonumber(text:sub(4,5),16)/255, tonumber(text:sub(6,7),16)/255 }
end
function Visuals:ctor(config, regionTypes)
    self.dressing=config:GetTable('MapDecorationRuleTable'):All()
    for _,row in ipairs(self.dressing) do
        config:GetTable('MapAssetTable'):Get(row.assetId)
        assert(row.minScale>0 and row.maxScale>=row.minScale,'Invalid world dressing scale')
        for _,id in ipairs(row.regions) do assert(regionTypes[id],'Unknown dressing region') end
    end
    self.assets = config:GetTable('MapAssetTable'); self.biomes = {}; self.rows = config:GetTable('MapBiomeTable'):All()
    for _, asset in ipairs(self.assets:All()) do
        assert(asset.prefabPath:match('^Assets/.*%.%w+$') and not asset.prefabPath:find('..',1,true), 'Invalid map asset path')
        color(asset.previewColor); assert(asset.referenceHeight > 0, 'Asset referenceHeight must be positive')
    end
    for _, row in ipairs(self.rows) do
        assert(regionTypes[row.id], 'Biome profile refers to an unknown region type')
        self.biomes[row.id] = { row = row, color = color(row.groundColor) }
        self.assets:Get(row.terrainAssetId); self.assets:Get(row.waterAssetId)
        for _, id in ipairs(row.terrainVariantAssetIds) do
            local asset = self.assets:Get(id)
            assert(asset.previewShape == 'terrain' and asset.footprintRadius == 0, 'Terrain variant requires a single hex tile')
        end
        for _, id in ipairs(row.decorationAssetIds) do self.assets:Get(id) end
        assert(row.decorationDensity >= 0 and row.decorationDensity <= 1 and row.minScale > 0 and row.maxScale >= row.minScale, 'Invalid decoration distribution')
        assert(type(row.groundTexture) == 'string' and row.groundTexture:match('^MapGround/%w+$'), 'Invalid ground texture resource key')
        assert(row.textureWorldSize > 0 and row.textureStrength >= 0 and row.textureStrength <= 1 and row.windStrength >= 0, 'Invalid ground surface parameters')
        assert(row.cliffTintStrength >= 0 and row.cliffTintStrength <= 1, 'Invalid cliff tint strength')
        for _, field in ipairs({'groundcoverDensity', 'shrubDensity', 'butterflyDensity', 'gnatDensity'}) do
            assert(row[field] >= 0 and row[field] <= 1, 'Invalid groundcover density: ' .. field)
        end
    end
    if #self.rows > 0 then
        for regionType in pairs(regionTypes) do assert(self.biomes[regionType], 'Missing biome visual profile') end
        for _, row in ipairs(config:GetTable('MapBuildingTable'):All()) do
            local model, platform = self.assets:Get(row.assetId), self.assets:Get(row.platformAssetId)
            assert(model.footprintRadius == row.footprintRadius and platform.footprintRadius == row.footprintRadius, 'Building asset footprint mismatch')
        end
    end
end
function Visuals:Build(map)
    map.assets = self.assets:All(); map.biomes = self.rows
    if #self.rows == 0 then Groundcover.Build(map); return end
    local random = Random(map.seed ~ 0x26100931)
    for _, cell in ipairs(map.cells) do
        local rgb, dominant = {0,0,0}, nil
        for _, weight in ipairs(cell.biomeWeights) do
            local profile = assert(self.biomes[weight.regionType])
            for c = 1, 3 do rgb[c] = rgb[c] + profile.color[c] * weight.weight end
            if not dominant or weight.weight > dominant.weight then dominant = weight end
        end
        local row = self.biomes[dominant.regionType].row
        Landforms.Color(cell, rgb)
        cell.groundColor = rgb; cell.terrainAssetId = row.terrainAssetId; cell.waterAssetId = row.waterAssetId
        if #row.terrainVariantAssetIds > 0 then
            local pick = math.min(#row.terrainVariantAssetIds,
                1 + math.floor(random:Noise(cell.q, cell.r, 3, 9751) * #row.terrainVariantAssetIds))
            cell.terrainAssetId = row.terrainVariantAssetIds[pick]
        end
        if not cell.waterLevel and not cell.buildingId and not cell.wonderId and cell.landformZone ~= 'canyonFloor'
            and #cell.roadIds == 0 and #row.decorationAssetIds > 0 then
            local cluster = random:Noise(cell.q, cell.r, 5, 9701)
            local probability = row.decorationDensity * dominant.weight * (.45 + cluster * .8)
            if random:Noise(cell.q, cell.r, 1, 9719) < probability then
                local slope = 0
                for _, neighbor in ipairs(map:GetNeighbors(cell.q, cell.r)) do slope = math.max(slope, math.abs(cell.height - neighbor.height)) end
                if slope <= row.decorationMaxSlope then
                    local pick = math.min(#row.decorationAssetIds, 1 + math.floor(random:Noise(cell.q, cell.r, 1, 9733) * #row.decorationAssetIds))
                    -- 高山装饰池按海拔排列，岩体位于山脚/山腰，雪峰只在高处出现。
                    if cell.mountainElevation then
                        pick = math.min(#row.decorationAssetIds, 1 + math.floor(cell.mountainElevation * #row.decorationAssetIds))
                    end
                    local scale = row.minScale + (row.maxScale - row.minScale) * random:Noise(cell.q, cell.r, 1, 9739)
                    local item = { id = #map.decorations + 1, cell = cell, assetId = row.decorationAssetIds[pick],
                        scale = scale, yaw = random:Noise(cell.q, cell.r, 1, 9743) * 360 }
                    cell.decorationId = item.id; map.decorations[item.id] = item
                end
            end
        end
    end
    require('Game.Map.MapDressing').Build(map,self.dressing)
    Groundcover.Build(map)
end
return Visuals
