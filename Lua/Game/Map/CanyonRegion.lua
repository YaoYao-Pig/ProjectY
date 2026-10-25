-- 狭长曲折的实体深槽：台阶岩壁向黑暗谷床收束，沟槽两端收口，保留完整谷缘。
local Class = require('Core.Class')
local Terrain = require('Game.Map.TerrainNoise')
local Convert = Class('CanyonRegionConvert', require('Game.Map.MapRegionConvertBase'))
local Instance = Class('CanyonRegionInstance', require('Game.Map.MapRegionInstanceBase'))

local function sample(config, q, r, random, region)
    local dq, dr = q - region.centerQ, r - region.centerR
    local x, z = dq + dr * .5, dr * math.sqrt(3) * .5
    local radius = math.max(3, math.min(region.sizeX, region.sizeY) * .5)
    local angle = random:Noise(region.centerQ, region.centerR, 1, 42901) * math.pi
    local along, across = x * math.cos(angle) + z * math.sin(angle), -x * math.sin(angle) + z * math.cos(angle)
    local bend = (random:Fractal(along, 11, radius * .7, .42, 42917) - .5) * radius * .65
    local width = config.riverWidth * (.82 + random:Fractal(along, 5, radius * .45, .4, 42929) * .55)
    local section = 1 - Terrain.Smooth(.45, 1.65, math.abs(across - bend) / width)
    local ends = 1 - Terrain.Smooth(.58, .95, math.abs(along) / radius)
    local ledges = section * .82 + math.floor(section * 5) * .036
    local depth = ledges * ends * (.83 + .17 * random:Fractal(along, 23, radius * .4, .5, 42943))
    local rim = .94 + .06 * random:Fractal(x, z, radius * .7, .32, 42967)
    return Terrain.Clamp(rim - depth * .97, 0, 1), depth
end

function Convert:GetHeight(config, q, r, random, noiseScale, region)
    local height = sample(config, q, r, random, region)
    return config.minHeight + (config.maxHeight - config.minHeight) * height
end

function Convert:GetLandform(config, cell, random, noiseScale, region)
    local _, depth = sample(config, cell.q, cell.r, random, region)
    local zone = depth > .68 and 'canyonFloor' or depth > .035 and 'canyonWall' or 'canyonRim'
    return 'Canyon', zone, depth, depth > .035
end

return { Convert = Convert, Instance = Instance }
