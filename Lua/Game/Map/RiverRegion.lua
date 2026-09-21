-- 河谷策略：连续噪声控制曲流中心线，横断面形成河床、缓岸和外围低丘。
-- 这是地形与水面预览策略，不计算降雨、流量、上下游网络或通行规则。
local Class = require('Core.Class')
local Terrain = require('Game.Map.TerrainNoise')
local Convert = Class('RiverRegionConvert', require('Game.Map.MapRegionConvertBase'))
local Instance = Class('RiverRegionInstance', require('Game.Map.MapRegionInstanceBase'))
function Convert:ValidateConfig(config) Terrain.ValidateWater(config) end
function Convert:GetHeight(config, q, r, random, noiseScale, region)
    local along = r - region.centerR
    local channel = region.instanceId * 65537 + 73
    local meander = (random:Fractal(along, 13.7, math.max(4, region.sizeY * 0.6), 0.4, channel) - 0.5) * region.sizeX * 0.85
    local center = region.centerQ - along * 0.25 + meander
    local distance = math.abs(q - center)
    local banks = Terrain.Smooth(config.riverWidth * 0.6, config.riverWidth * 2.7, distance)
    local noise = Terrain.Rolling(config, q, r, random, noiseScale)
    local bottom = config.minHeight + (config.waterLevel - config.minHeight) * 0.2 * noise
    local land = config.waterLevel + (config.maxHeight - config.waterLevel) * (0.25 + noise * 0.75)
    local height = bottom + (land - bottom) * banks
    return height, height < config.waterLevel and config.waterLevel or nil, 'river'
end
return { Convert = Convert, Instance = Instance }
