-- 尖顶六边形的轴坐标工具：q、r 表示格子，Unity 的 XZ 为地面，Y 为高度。
local HexGrid = {}
-- 六个方向的固定顺序也用于预览数据；方向编号为 1..6。
local directions = { {1, 0}, {1, -1}, {0, -1}, {-1, 0}, {-1, 1}, {0, 1} }
local sqrt3 = math.sqrt(3)
function HexGrid.CheckCoordinate(q, r)
    assert(type(q) == 'number' and type(r) == 'number' and math.tointeger(q) and math.tointeger(r), 'Hex coordinates must be integers')
end
-- 整数化后生成索引键，避免 1 与 1.0 指向不同字符串。
function HexGrid.Key(q, r) return math.tointeger(q) .. ':' .. math.tointeger(r) end
function HexGrid.Neighbor(q, r, direction)
    local offset = assert(directions[direction], 'Hex direction must be 1..6')
    return q + offset[1], r + offset[2]
end
-- 以立方坐标的三轴差计算格子距离，不计高度与通行规则。
function HexGrid.Distance(q1, r1, q2, r2)
    HexGrid.CheckCoordinate(q1, r1); HexGrid.CheckCoordinate(q2, r2)
    local q, r = q2 - q1, r2 - r1
    return (math.abs(q) + math.abs(r) + math.abs(q + r)) // 2
end
local function checkRadius(radius)
    assert(type(radius) == 'number' and radius > 0 and radius < math.huge, 'Hex radius must be positive and finite')
end
-- 返回格子顶面中心的世界坐标；radius 为中心到顶点的距离。
function HexGrid.ToWorld(q, r, height, radius)
    HexGrid.CheckCoordinate(q, r); checkRadius(radius)
    assert(type(height) == 'number' and math.abs(height) < math.huge, 'Height must be finite')
    return sqrt3 * radius * (q + r / 2), height, 1.5 * radius * r
end
-- 世界位置转为最近格子的轴坐标，随后由 Map 判断该格子是否存在。
function HexGrid.FromWorld(x, z, radius)
    checkRadius(radius)
    assert(type(x) == 'number' and type(z) == 'number' and math.abs(x) < math.huge and math.abs(z) < math.huge, 'World position must be finite')
    local q, r = (sqrt3 / 3 * x - z / 3) / radius, (2 / 3 * z) / radius
    local s = -q - r
    local iq, ir, is = math.floor(q + 0.5), math.floor(r + 0.5), math.floor(s + 0.5)
    local dq, dr, ds = math.abs(iq - q), math.abs(ir - r), math.abs(is - s)
    -- 修正舍入误差最大的轴，使立方坐标始终满足 q + r + s = 0。
    if dq > dr and dq > ds then iq = -ir - is
    elseif dr > ds then ir = -iq - is end
    return iq, ir
end
return HexGrid
