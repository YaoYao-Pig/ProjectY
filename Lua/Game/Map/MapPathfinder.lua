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
    self.minQ = math.huge; self.maxQ = -math.huge; self.minR = math.huge; self.maxR = -math.huge
    self.cellCount = #map.cells
    for index, cell in ipairs(map.cells) do
        self.minQ = math.min(self.minQ, cell.q); self.maxQ = math.max(self.maxQ, cell.q)
        self.minR = math.min(self.minR, cell.r); self.maxR = math.max(self.maxR, cell.r)
        self.indices[cell] = index
        local neighbors = {}; self.neighbors[cell] = neighbors
        for direction = 1, 6 do
            local q, r = HexGrid.Neighbor(cell.q, cell.r, direction)
            local other = map.cellsByKey[HexGrid.Key(q, r)]
            if other then neighbors[#neighbors + 1] = other end
        end
    end
end
-- 在完整轴坐标包围盒上做六方向距离变换，穿过缺格仍计算直线净距。
-- 使用整数数组索引；紧凑大地图的反复文明距离更新不再逐格查询空间树。
function Pathfinder:BoxHexDistances(sources, cap)
    local width = self.maxQ - self.minQ + 1
    local height = self.maxR - self.minR + 1
    local costs, queue, head = {}, {}, 1
    for _, cell in ipairs(sources) do
        assert(self.indices[cell], 'Distance source must belong to this map')
        local index = cell.q - self.minQ + (cell.r - self.minR) * width + 1
        if not costs[index] then costs[index] = 0; queue[#queue + 1] = index end
    end
    local function visit(index, value)
        if costs[index] == nil then costs[index] = value; queue[#queue + 1] = index end
    end
    while head <= #queue do
        local index = queue[head]; head = head + 1
        local value = costs[index] + 1
        if value < cap then
            local q, r = (index - 1) % width, (index - 1) // width
            if q > 0 then visit(index - 1, value) end
            if q + 1 < width then visit(index + 1, value) end
            if r > 0 then
                visit(index - width, value)
                if q + 1 < width then visit(index - width + 1, value) end
            end
            if r + 1 < height then
                visit(index + width, value)
                if q > 0 then visit(index + width - 1, value) end
            end
        end
    end
    local values = {}
    for cell in pairs(self.indices) do
        values[cell] = costs[cell.q - self.minQ + (cell.r - self.minR) * width + 1] or cap
    end
    return values
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
-- 一次多源搜索生成距离场；cap 外保持缺失，由调用方显式标记不可达/超出范围。
function Pathfinder:Distances(sources, edgeCost, cap)
    local costs, heap = {}, {}
    for _, cell in ipairs(sources) do
        assert(self.indices[cell], 'Distance source must belong to this map')
        if costs[cell] == nil then
            costs[cell] = 0; push(heap, {cell=cell, cost=0, order=self.indices[cell]})
        end
    end
    while #heap > 0 do
        local entry = pop(heap)
        if costs[entry.cell] == entry.cost then
            for _, other in ipairs(self.neighbors[entry.cell]) do
                local step = edgeCost(entry.cell, other)
                if step then
                    assert(step > 0 and step < math.huge, 'Distance edge cost must be positive and finite')
                    local cost = entry.cost + step
                    if cost <= cap and (costs[other] == nil or cost < costs[other]) then
                        costs[other] = cost; push(heap, {cell=other, cost=cost, order=self.indices[other]})
                    end
                end
            end
        end
    end
    return costs
end
-- 净距采用直线六边形距离，不能因地图轮廓缺格而被绕路距离夸大。
-- (q,r,q+r) 的切比雪夫距离等于轴坐标六边形距离；包围盒树避免逐格扫描所有来源。
function Pathfinder:HexDistances(sources, cap)
    if #sources == 0 then return {} end
    local area = (self.maxQ - self.minQ + 1) * (self.maxR - self.minR + 1)
    -- 稀疏/长距离坐标仍使用空间树，避免包围盒面积远大于实际格数时分配巨型数组。
    if area <= self.cellCount * 8 and area <= 2000000 then return self:BoxHexDistances(sources, cap) end
    local points, seen={},{}
    for _, cell in ipairs(sources) do
        assert(self.indices[cell], 'Distance source must belong to this map')
        if not seen[cell] then seen[cell]=true;points[#points+1]={cell.q,cell.r,cell.q+cell.r,index=self.indices[cell]} end
    end
    local function build(items)
        if #items==0 then return nil end
        local node={minimum={math.huge,math.huge,math.huge},maximum={-math.huge,-math.huge,-math.huge}}
        for _, point in ipairs(items) do for axis=1,3 do
            node.minimum[axis]=math.min(node.minimum[axis],point[axis]);node.maximum[axis]=math.max(node.maximum[axis],point[axis])
        end end
        if #items<=8 then node.points=items;return node end
        local axis=1;for candidate=2,3 do
            if node.maximum[candidate]-node.minimum[candidate]>node.maximum[axis]-node.minimum[axis] then axis=candidate end
        end
        table.sort(items,function(a,b) return a[axis]<b[axis] or (a[axis]==b[axis] and a.index<b.index) end)
        local left,right={},{};for i,point in ipairs(items) do
            local part=i<=#items//2 and left or right;part[#part+1]=point
        end
        node.left=build(left);node.right=build(right);return node
    end
    local root=build(points);local values={}
    if not root then return values end
    local function bound(node,point)
        local value=0;for axis=1,3 do value=math.max(value,node.minimum[axis]-point[axis],point[axis]-node.maximum[axis]) end
        return value
    end
    local function nearest(node,point,best)
        if bound(node,point)>best then return best end
        if node.points then
            for _, other in ipairs(node.points) do best=math.min(best,math.max(math.abs(point[1]-other[1]),math.abs(point[2]-other[2]),math.abs(point[3]-other[3]))) end
        else
            local first,second=node.left,node.right
            if bound(second,point)<bound(first,point) then first,second=second,first end
            best=nearest(first,point,best);best=nearest(second,point,best)
        end
        return best
    end
    for cell in pairs(self.indices) do values[cell]=nearest(root,{cell.q,cell.r,cell.q+cell.r},cap) end
    return values
end
return Pathfinder
