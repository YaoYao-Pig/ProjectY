-- 湖区策略：带扰动的中央盆地与外围起伏相接，水位独立于湖床高度。
local Class = require('Core.Class')
local Terrain = require('Game.Map.TerrainNoise')
local Convert = Class('LakeRegionConvert', require('Game.Map.MapRegionConvertBase'))
local Instance = Class('LakeRegionInstance', require('Game.Map.MapRegionInstanceBase'))
function Convert:ValidateConfig(config) Terrain.ValidateWater(config) end
function Convert:GetHeight(config, q, r, random, noiseScale, region)
    local x = (q - region.centerQ) / math.max(1, region.sizeX / 2)
    local y = (r - region.centerR) / math.max(1, region.sizeY / 2)
    x, y = random:Warp(x, y, 1.2, config.warpStrength * 0.55, region.instanceId * 65537 + 19)
    local distance = math.sqrt(x * x + y * y + x * y * 0.65)
    local shore = Terrain.Smooth(config.lakeSize * 0.55, config.lakeSize * 1.5, distance)
    local noise = Terrain.Rolling(config, q, r, random, noiseScale)
    local land = config.waterLevel + (config.maxHeight - config.waterLevel) * (0.35 + noise * 0.65)
    local bottom = config.minHeight + noise * (config.waterLevel - config.minHeight) * 0.25
    local height = bottom + (land - bottom) * shore
    return height, height < config.waterLevel and config.waterLevel or nil, 'lake'
end
return { Convert = Convert, Instance = Instance }
