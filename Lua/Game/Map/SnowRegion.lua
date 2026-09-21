-- 冰雪高地以宽阔雪坡和低频山脊构成，雪色与雪松由配置关联资源。
local Class = require('Core.Class')
local Terrain = require('Game.Map.TerrainNoise')
local Convert = Class('SnowRegionConvert', require('Game.Map.MapRegionConvertBase'))
local Instance = Class('SnowRegionInstance', require('Game.Map.MapRegionInstanceBase'))
function Convert:GetHeight(config, q, r, random, noiseScale)
    local x, y, scale = Terrain.Coordinates(config, q, r, random, noiseScale)
    local plateau = random:Fractal(x, y, scale * 1.6, config.roughness, 6251)
    local ridge = random:Ridged(x, y, scale, .3, 6263)
    return config.minHeight + (config.maxHeight - config.minHeight) * Terrain.Clamp(plateau * .7 + ridge * .3, 0, 1)
end
return { Convert = Convert, Instance = Instance }
