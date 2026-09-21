-- 各地貌策略共用的采样坐标与曲线工具，噪声仍由本次地图的独立随机源提供。
local Terrain = {}
function Terrain.Clamp(value, minimum, maximum) return math.max(minimum, math.min(maximum, value)) end
function Terrain.Smooth(minimum, maximum, value)
    local t = Terrain.Clamp((value - minimum) / (maximum - minimum), 0, 1)
    return t * t * (3 - 2 * t)
end
function Terrain.Coordinates(config, q, r, random, noiseScale)
    -- 转成等距平面坐标再采样，避免轴坐标的 60 度夹角拉歪噪声。
    local x, y = q + r / 2, r * math.sqrt(3) / 2
    local scale = noiseScale * config.noiseScale
    x, y = random:Warp(x, y, scale, config.warpStrength, 2027)
    return x, y, scale
end
function Terrain.Rolling(config, q, r, random, noiseScale)
    local x, y, scale = Terrain.Coordinates(config, q, r, random, noiseScale)
    return random:Fractal(x, y, scale, config.roughness, 421)
end
function Terrain.ValidateWater(config)
    assert(config.waterLevel > config.minHeight and config.waterLevel < config.maxHeight,
        'Lake/river waterLevel must be strictly inside minHeight/maxHeight')
end
return Terrain
