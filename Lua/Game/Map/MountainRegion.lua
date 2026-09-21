-- 山地策略：低频决定山体分布，折叠噪声提供连绵山脊，小尺度保留岩坡细节。
local Class = require('Core.Class')
local Terrain = require('Game.Map.TerrainNoise')
local Convert = Class('MountainRegionConvert', require('Game.Map.MapRegionConvertBase'))
local Instance = Class('MountainRegionInstance', require('Game.Map.MapRegionInstanceBase'))
function Convert:GetHeight(config, q, r, random, noiseScale)
    local x, y, scale = Terrain.Coordinates(config, q, r, random, noiseScale)
    local body = random:Fractal(x, y, scale * 1.9, 0.4, 313)
    local ridges = random:Ridged(x, y, scale * 0.85, config.roughness, 1049)
    local height = Terrain.Clamp((body * 0.35 + ridges * 0.65) ^ 1.65, 0, 1)
    return config.minHeight + (config.maxHeight - config.minHeight) * height
end
return { Convert = Convert, Instance = Instance }
