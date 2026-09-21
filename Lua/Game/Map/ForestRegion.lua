-- 森林保留可建聚落的宽缓坡，树木分布由地貌表现配置统一控制。
local Class = require('Core.Class')
local Terrain = require('Game.Map.TerrainNoise')
local Convert = Class('ForestRegionConvert', require('Game.Map.MapRegionConvertBase'))
local Instance = Class('ForestRegionInstance', require('Game.Map.MapRegionInstanceBase'))
function Convert:GetHeight(config, q, r, random, noiseScale)
    local rolling = Terrain.Rolling(config, q, r, random, noiseScale)
    return config.minHeight + (config.maxHeight - config.minHeight) * rolling ^ 1.3
end
return { Convert = Convert, Instance = Instance }
