-- 巨型山体以连续主脊、支脊、尖峰和陡壁构成；外缘低缓山脚供大地图接近。
local Class = require('Core.Class')
local Terrain = require('Game.Map.TerrainNoise')
local Convert = Class('HighMountainRegionConvert', require('Game.Map.MapRegionConvertBase'))
local Instance = Class('HighMountainRegionInstance', require('Game.Map.MapRegionInstanceBase'))

local function sample(config, q, r, random, region)
    local dq, dr = q - region.centerQ, r - region.centerR
    local x, z = dq + dr * .5, dr * math.sqrt(3) * .5
    local radius = math.max(3, math.min(region.sizeX, region.sizeY) * .5)
    local angle = random:Noise(region.centerQ, region.centerR, 1, 41701) * math.pi
    local along, across = x * math.cos(angle) + z * math.sin(angle), -x * math.sin(angle) + z * math.cos(angle)
    local bend = (random:Fractal(along, 7, radius * .8, .42, 41717) - .5) * radius * .36
    local spine = 1 - Terrain.Smooth(.025, .48, math.abs(across - bend) / radius)
    local branch = 1 - Terrain.Smooth(.02, .3, math.abs(across + along * .62 + radius * .12) / radius)
    branch = branch * (1 - Terrain.Smooth(.12, .72, math.abs(along) / radius)) * .78
    local ridge = math.max(spine, branch)
    local edge = 1 - Terrain.Smooth(.48, .91, math.sqrt(x * x + z * z) / radius)
    local crest = random:Fractal(along, 31, radius * .24, config.roughness, 41731)
    local crags = random:Ridged(x, z, math.max(1.8, radius * .15), config.roughness, 41759)
    local relief = Terrain.Clamp(edge * (.44 * ridge ^ 1.7 + .48 * ridge ^ 5 * (.72 + crest * .28)
        + .12 * crags * ridge), 0, 1)
    local foot = random:Fractal(x, z, radius * .55, .35, 41777) * .025
    return Terrain.Clamp(foot + relief, 0, 1), relief
end

function Convert:GetHeight(config, q, r, random, noiseScale, region)
    local height = sample(config, q, r, random, region)
    return config.minHeight + (config.maxHeight - config.minHeight) * height
end

function Convert:GetLandform(config, cell, random, noiseScale, region)
    local _, elevation = sample(config, cell.q, cell.r, random, region)
    local zone = elevation > .62 and 'mountainPeak' or elevation > .07 and 'mountainWall' or 'mountainFoot'
    return 'HighMountain', zone, elevation, elevation > .07
end

return { Convert = Convert, Instance = Instance }
