-- 在最终地形上整理预览水体：连通水面保持同一高度，岸边低点限制水位。
-- 这里只维护静态范围与深度，不模拟流向、流量、侵蚀或角色通行。
local HexGrid = require('Game.Map.HexGrid')
local Water = {}
local function visitNeighbors(map, cell, callback)
    for direction = 1, 6 do
        local q, r = HexGrid.Neighbor(cell.q, cell.r, direction)
        local other = map.cellsByKey[HexGrid.Key(q, r)]
        if other then callback(other) end
    end
end
function Water.Build(map)
    local seen = {}
    for _, start in ipairs(map.cells) do
        if start.waterLevel and start.height < start.waterLevel and not seen[start] then
            local cells, head, level = { start }, 1, start.waterLevel
            seen[start] = true
            while head <= #cells do
                local cell = cells[head]; head = head + 1
                level = math.min(level, cell.waterLevel)
                visitNeighbors(map, cell, function(other)
                    if other.waterLevel and other.height < other.waterLevel then
                        if not seen[other] then seen[other] = true; cells[#cells + 1] = other end
                    else
                        -- 以相邻干地最低点限制水面，避免画出高于岸边的悬空水墙。
                        level = math.min(level, other.height)
                    end
                end)
            end
            for _, cell in ipairs(cells) do cell.waterLevel = level end
        end
    end
    Water.Reindex(map)
end
-- 河流允许沿途降水位；此处仅重建等水位连通片，不再把整条河压成最低水位。
function Water.Reindex(map)
    map.waterBodies = {}
    for _, cell in ipairs(map.cells) do
        cell.waterBodyId = nil
        if cell.waterLevel and cell.waterLevel - cell.height > 0.000001 then
            cell.waterDepth = cell.waterLevel - cell.height
        else cell.waterLevel = nil; cell.waterKind = nil; cell.waterDepth = 0 end
    end
    -- 降水位可能把水域分开；按最终湿格重新分组，水体 ID 对应真实连通范围。
    local seen = {}
    for _, start in ipairs(map.cells) do
        if start.waterLevel and not seen[start] then
            local body = { id = #map.waterBodies + 1, kind = start.waterKind, level = start.waterLevel, cells = {} }
            map.waterBodies[body.id] = body
            local cells, head = { start }, 1; seen[start] = true
            while head <= #cells do
                local cell = cells[head]; head = head + 1
                cell.waterBodyId = body.id; body.cells[#body.cells + 1] = cell
                if cell.waterKind == 'river' then body.kind = 'river' end
                visitNeighbors(map, cell, function(other)
                    if other.waterLevel == body.level and not seen[other] then
                        seen[other] = true; cells[#cells + 1] = other
                    end
                end)
            end
        end
    end
end
return Water
