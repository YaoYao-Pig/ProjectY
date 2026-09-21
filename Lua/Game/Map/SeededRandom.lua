-- 地图独立的随机序列与空间噪声；不会修改全局 math.random 的状态。
local Class = require('Core.Class')
local Random = Class('MapSeededRandom')
function Random:ctor(seed)
    assert(type(seed) == 'number' and seed == math.floor(seed) and seed >= 0 and seed <= 0xffffffff, 'Map seed must be a uint32')
    self.seed = math.tointeger(seed); self.state = self.seed
end
-- 闭区间整数采样；固定 uint32 线性同余参数保证相同种子可复现。
function Random:Integer(minimum, maximum)
    assert(minimum == math.floor(minimum) and maximum == math.floor(maximum) and minimum <= maximum, 'Invalid random integer range')
    self.state = (1664525 * self.state + 1013904223) % 4294967296
    return minimum + math.floor(self.state / 4294967296 * (maximum - minimum + 1))
end
-- 对整数网格点做带种子的哈希，得到 [0, 1] 范围的基础噪声。
local function lattice(seed, x, y)
    local n = (seed ~ (x * 374761393) ~ (y * 668265263)) & 0xffffffff
    n = ((n ~ (n >> 16)) * 0x45d9f3b) & 0xffffffff
    n = ((n ~ (n >> 16)) * 0x45d9f3b) & 0xffffffff
    return (n ~ (n >> 16)) / 4294967295
end
local function lerp(a, b, t) return a + (b - a) * t end
-- 平滑插值四个网格点；只由种子和位置决定，不消耗区域摆放的随机序列。
function Random:Noise(x, y, scale, channel)
    local sx, sy = x / scale, y / scale
    local ix, iy = math.floor(sx), math.floor(sy)
    local tx, ty = sx - ix, sy - iy
    tx = tx * tx * (3 - 2 * tx); ty = ty * ty * (3 - 2 * ty)
    local seed = self.seed ~ (channel or 0)
    return lerp(lerp(lattice(seed, ix, iy), lattice(seed, ix + 1, iy), tx),
        lerp(lattice(seed, ix, iy + 1), lattice(seed, ix + 1, iy + 1), tx), ty)
end
-- 多层分形噪声：大尺度负责轮廓，小尺度补细节，按振幅总和归一化到 [0, 1]。
-- 各层使用不同通道，避免原点附近的采样相关性；不会消耗 Integer 的随机序列。
function Random:Fractal(x, y, scale, roughness, channel)
    local value, total, amplitude = 0, 0, 1
    for octave = 1, 4 do
        value = value + self:Noise(x, y, scale, channel + octave * 1013) * amplitude
        total = total + amplitude; amplitude = amplitude * roughness; scale = scale / 2
    end
    return value / total
end
-- 用两个独立连续噪声扰动采样坐标，消除整齐排列的山峰与规则岸线。
function Random:Warp(x, y, scale, strength, channel)
    return x + (self:Fractal(x, y, scale, 0.5, channel) - 0.5) * scale * strength,
        y + (self:Fractal(x, y, scale, 0.5, channel + 7919) - 0.5) * scale * strength
end
-- 折叠并锐化噪声形成山脊，适合山地策略；与基础起伏按策略权重组合。
function Random:Ridged(x, y, scale, roughness, channel)
    local value, total, amplitude = 0, 0, 1
    for octave = 1, 4 do
        local ridge = 1 - math.abs(self:Noise(x, y, scale, channel + octave * 1013) * 2 - 1)
        value = value + ridge * ridge * amplitude
        total = total + amplitude; amplitude = amplitude * roughness; scale = scale / 2
    end
    return value / total
end
return Random
