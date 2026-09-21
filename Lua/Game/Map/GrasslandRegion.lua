-- 草原策略：多层连续噪声与坐标扰动形成缓坡，查询行为复用区域基类。
local Class = require('Core.Class')
local Terrain = require('Game.Map.TerrainNoise')
local Convert = Class('GrasslandRegionConvert', require('Game.Map.MapRegionConvertBase'))
local Instance = Class('GrasslandRegionInstance', require('Game.Map.MapRegionInstanceBase'))
function Convert:GetHeight(config, q, r, random, noiseScale)
    local noise = Terrain.Rolling(config, q, r, random, noiseScale)
    return config.minHeight + (config.maxHeight - config.minHeight) * noise
end
return { Convert = Convert, Instance = Instance }
