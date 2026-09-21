-- 地图生成期的最短路工具。调用方提供边代价，决定水域、坡度与建筑占地规则。
-- 使用 Dijkstra 与二叉堆，不修改格子；不可达时返回 nil，由生成器明确记录结果。
local Class = require('Core.Class')
local HexGrid = require('Game.Map.HexGrid')
local Pathfinder = Class('MapPathfinder')
local function before(a, b) return a.cost < b.cost or (a.cost == b.cost and a.order < b.order) end
local function push(heap, item)
    local index = #heap + 1
    while index > 1 do
        local parent = index // 2
        if not before(item, heap[parent]) then break end
        heap[index] = heap[parent]; index = parent
    end
    heap[index] = item
end
local function pop(heap)
    local first, last = heap[1], heap[#heap]; heap[#heap] = nil
    if #heap > 0 then
        local index = 1
        while index * 2 <= #heap do
            local child = index * 2
            if child + 1 <= #heap and before(heap[child + 1], heap[child]) then child = child + 1 end
            if not before(heap[child], last) then break end
            heap[index] = heap[child]; index = child
        end
        heap[index] = last
    end
    return first
end
function Pathfinder:ctor(map)
    self.neighbors = {}; self.indices = {}
    for index, cell in ipairs(map.cells) do
        self.indices[cell] = index
        local neighbors = {}; self.neighbors[cell] = neighbors
        for direction = 1, 6 do
            local q, r = HexGrid.Neighbor(cell.q, cell.r, direction)
            local other = map.cellsByKey[HexGrid.Key(q, r)]
            if other then neighbors[#neighbors + 1] = other end
        end
    end
end
-- edgeCost(from, to) 返回正代价或 nil（禁行）。格子索引用于代价相同的稳定排序。
function Pathfinder:FindPath(start, goal, edgeCost)
    assert(self.indices[start] and self.indices[goal], 'Path endpoints must belong to this map')
    local costs, previous = { [start] = 0 }, {}
    local heap = { { cell = start, cost = 0, order = self.indices[start] } }
    while #heap > 0 do
        local entry = pop(heap)
        -- 同一节点可以多次入堆；跳过已经被更短路径替代的旧记录。
        if entry.cost == costs[entry.cell] then
            if entry.cell == goal then
                local reversed, cursor = {}, goal
                while cursor do reversed[#reversed + 1] = cursor; cursor = previous[cursor] end
                local path = {}; for i = #reversed, 1, -1 do path[#path + 1] = reversed[i] end
                return path, entry.cost
            end
            for _, other in ipairs(self.neighbors[entry.cell]) do
                local step = edgeCost(entry.cell, other)
                if step ~= nil then
                    assert(type(step) == 'number' and step > 0 and step < math.huge, 'Path edge cost must be positive and finite')
                    local cost = entry.cost + step
                    if costs[other] == nil or cost < costs[other] then
                        costs[other] = cost; previous[other] = entry.cell
                        push(heap, { cell = other, cost = cost, order = self.indices[other] })
                    end
                end
            end
        end
    end
    return nil
end
return Pathfinder
