-- 在配置的 q/r 尺寸内构造噪声轮廓，只保留中心连通块，保证每个区域自身连通。
local HexGrid = require('Game.Map.HexGrid')
local Footprint = {}
function Footprint.Create(sizeX, sizeY, random, channel, irregularity)
    local candidates, centerQ, centerR = {}, (sizeX - 1) // 2, (sizeY - 1) // 2
    local halfX, halfY = math.max(0.5, sizeX / 2), math.max(0.5, sizeY / 2)
    for r = 0, sizeY - 1 do
        for q = 0, sizeX - 1 do
            local x, y = (q - (sizeX - 1) / 2) / halfX, (r - (sizeY - 1) / 2) / halfY
            local noise = random:Fractal(q, r, math.max(2, math.min(sizeX, sizeY) * 0.38), 0.55, channel)
            local radius = 0.86 + (noise - 0.5) * irregularity * 1.5
            -- 交叉项匹配六边形轴坐标的夹角，使整体接近圆润地块而非斜矩形。
            if x * x + y * y + x * y * 0.65 <= radius * radius then
                candidates[HexGrid.Key(q, r)] = { q = q, r = r }
            end
        end
    end
    -- 极小尺寸也必须有一个有效种子格；这属于轮廓算法的定义。
    local center = { q = centerQ, r = centerR }
    candidates[HexGrid.Key(centerQ, centerR)] = center
    local cells, seen, head = { center }, { [HexGrid.Key(centerQ, centerR)] = true }, 1
    while head <= #cells do
        local cell = cells[head]; head = head + 1
        for direction = 1, 6 do
            local q, r = HexGrid.Neighbor(cell.q, cell.r, direction)
            local key = HexGrid.Key(q, r)
            if candidates[key] and not seen[key] then seen[key] = true; cells[#cells + 1] = candidates[key] end
        end
    end
    -- 固定按行排序，避免哈希遍历次序影响布局、JSON 索引与复现。
    table.sort(cells, function(a, b) return a.r < b.r or (a.r == b.r and a.q < b.q) end)
    local rim, west = {}, cells[1]
    for _, cell in ipairs(cells) do
        if cell.q < west.q then west = cell end
        for direction = 1, 6 do
            local q, r = HexGrid.Neighbor(cell.q, cell.r, direction)
            if not seen[HexGrid.Key(q, r)] then rim[#rim + 1] = cell; break end
        end
    end
    return { cells = cells, rim = rim, west = west, centerQ = centerQ, centerR = centerR }
end
return Footprint
