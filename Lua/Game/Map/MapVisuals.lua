-- 配置驱动的资源选择和确定性装饰散布；在水体、聚落和道路完成之后执行。
local Class = require('Core.Class')
local Random = require('Game.Map.SeededRandom')
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
        for _, id in ipairs(row.decorationAssetIds) do self.assets:Get(id) end
        assert(row.decorationDensity >= 0 and row.decorationDensity <= 1 and row.minScale > 0 and row.maxScale >= row.minScale, 'Invalid decoration distribution')
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
    if #self.rows == 0 then return end
    local random = Random(map.seed ~ 0x26100931)
    for _, cell in ipairs(map.cells) do
        local rgb, dominant = {0,0,0}, nil
        for _, weight in ipairs(cell.biomeWeights) do
            local profile = assert(self.biomes[weight.regionType])
            for c = 1, 3 do rgb[c] = rgb[c] + profile.color[c] * weight.weight end
            if not dominant or weight.weight > dominant.weight then dominant = weight end
        end
        local row = self.biomes[dominant.regionType].row
        cell.groundColor = rgb; cell.terrainAssetId = row.terrainAssetId; cell.waterAssetId = row.waterAssetId
        if not cell.waterLevel and not cell.buildingId and #cell.roadIds == 0 and #row.decorationAssetIds > 0 then
            local cluster = random:Noise(cell.q, cell.r, 5, 9701)
            local probability = row.decorationDensity * dominant.weight * (.45 + cluster * .8)
            if random:Noise(cell.q, cell.r, 1, 9719) < probability then
                local slope = 0
                for _, neighbor in ipairs(map:GetNeighbors(cell.q, cell.r)) do slope = math.max(slope, math.abs(cell.height - neighbor.height)) end
                if slope <= row.decorationMaxSlope then
                    local pick = math.min(#row.decorationAssetIds, 1 + math.floor(random:Noise(cell.q, cell.r, 1, 9733) * #row.decorationAssetIds))
                    local scale = row.minScale + (row.maxScale - row.minScale) * random:Noise(cell.q, cell.r, 1, 9739)
                    local item = { id = #map.decorations + 1, cell = cell, assetId = row.decorationAssetIds[pick],
                        scale = scale, yaw = random:Noise(cell.q, cell.r, 1, 9743) * 360 }
                    cell.decorationId = item.id; map.decorations[item.id] = item
                end
            end
        end
    end
    require('Game.Map.MapDressing').Build(map,self.dressing)
end
return Visuals
