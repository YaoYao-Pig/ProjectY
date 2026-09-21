-- 全图静态水系：低洼出口的优先洪泛建立无环下游树，河道沿树汇合，允许跨 Region。
-- 仅开挖有限深度的河床；不模拟水量、侵蚀或队伍通行。
local Class = require('Core.Class')
local Hex = require('Game.Map.HexGrid')
local Random = require('Game.Map.SeededRandom')
local Pathfinder = require('Game.Map.MapPathfinder')
local Water = require('Game.Map.MapWater')
local Hydrology = Class('MapHydrology')
local function before(a, b)
    return a.level < b.level or (a.level == b.level and (a.depth < b.depth or (a.depth == b.depth and a.index < b.index)))
end
local function push(heap, entry)
    local i = #heap + 1
    while i > 1 do
        local p = i // 2; if not before(entry, heap[p]) then break end
        heap[i] = heap[p]; i = p
    end
    heap[i] = entry
end
local function pop(heap)
    local first, last = heap[1], heap[#heap]; heap[#heap] = nil
    if #heap > 0 then
        local i = 1
        while i * 2 <= #heap do
            local c = i * 2
            if c + 1 <= #heap and before(heap[c + 1], heap[c]) then c = c + 1 end
            if not before(heap[c], last) then break end
            heap[i] = heap[c]; i = c
        end
        heap[i] = last
    end
    return first
end
local function distance(a, b) return Hex.Distance(a.q, a.r, b.q, b.r) end
function Hydrology:ctor(config)
    local rows = config:GetTable('MapWaterNetworkTable'):All()
    assert(#rows <= 1, 'MapWaterNetworkTable supports at most one active profile')
    self.row = rows[1]
    if not self.row then return end
    local row = self.row
    for name, maximum in pairs({maxRivers=8,maxTributaries=8,minLength=512,minBranchLength=256,minCrossRegions=16,
        sourceSpacing=128,sourceAttempts=512,outletCount=8,outletSpacing=256,poolRadius=3}) do
        local value = row[name]
        assert(type(value) == 'number' and value == math.floor(value) and value >= 0 and value <= maximum, 'Invalid water network setting: ' .. name)
    end
    assert(row.minLength >= 2 and row.minBranchLength >= 2 and row.outletCount >= 1, 'River paths and outlets must be nonempty')
    assert(row.waterfallChance >= 0 and row.waterfallChance <= 1 and row.waterfallMinDrop > 0, 'Invalid waterfall probability or drop')
    assert(row.depth > 0 and row.maxCarveDepth >= row.depth and row.poolDepth > 0 and row.maxPoolCarve >= row.poolDepth, 'Invalid channel excavation budget')
end

-- 仅选择少量相隔较远的低洼出口，使主河有机会穿越多个实例，不在每个 Region 单独截断。
function Hydrology:Drainage(map, graph, random)
    local boundary = {}
    for i, cell in ipairs(map.cells) do
        if #graph.neighbors[cell] < 6 then boundary[#boundary + 1] = { cell = cell, index = i,
            score = (cell.waterLevel or cell.height) + random:Noise(cell.q, cell.r, 1, 11003) * .08 } end
    end
    table.sort(boundary, function(a,b) return a.score < b.score or (a.score == b.score and a.index < b.index) end)
    local outlets = {}
    for _, candidate in ipairs(boundary) do
        local allowed = true
        for _, cell in ipairs(outlets) do if distance(cell, candidate.cell) < self.row.outletSpacing then allowed = false; break end end
        if allowed then outlets[#outlets + 1] = candidate.cell end
        if #outlets >= self.row.outletCount then break end
    end
    local heap, seen, parent, depth = {}, {}, {}, {}
    for _, cell in ipairs(outlets) do
        seen[cell] = true; depth[cell] = 0
        push(heap, {cell=cell, level=cell.waterLevel or cell.height, depth=0, index=graph.indices[cell]})
    end
    while #heap > 0 do
        local entry = pop(heap)
        for _, other in ipairs(graph.neighbors[entry.cell]) do
            if not seen[other] then
                seen[other] = true; parent[other] = entry.cell; depth[other] = entry.depth + 1
                push(heap, {cell=other, level=math.max(entry.level, other.waterLevel or other.height),
                    depth=depth[other], index=graph.indices[other]})
            end
        end
    end
    return parent, depth
end

-- 每个候选先完整计算水面，保证沿下游不升高、岸外不悬空、开挖不超过配置预算。
function Hydrology:Plan(path, graph, occupied)
    local members, levels, previous = {}, {}, math.huge
    for _, cell in ipairs(path) do members[cell] = true end
    for i, cell in ipairs(path) do
        local level
        if occupied[cell] or cell.waterLevel then
            level = cell.waterLevel
            if level > previous + 1e-6 then return nil end
        else
            level = math.min(previous, cell.height - .06)
            for _, neighbor in ipairs(graph.neighbors[cell]) do
                if not members[neighbor] and not neighbor.waterLevel then level = math.min(level, neighbor.height) end
            end
        end
        if cell.height - (level - self.row.depth) > self.row.maxCarveDepth then return nil end
        levels[i] = level; previous = level
    end
    return levels
end

-- 瀑布下方必须能形成真实、连通、有干岸的湖泊；失败就不生成悬空的瀑布装饰。
function Hydrology:PlanPool(graph, start, upstream, radius)
    local row, level = self.row, start.waterLevel
    local cells
    -- 湖水可以降低到周围最低干岸，但不能低于下一格河水，避免下游倒流。
    local minimum = start.flowTo and start.flowTo.waterLevel or -math.huge
    for _ = 1, 1 + 3 * radius * (radius + 1) do
        local included, head = {[start]=true}, 1; cells = {start}
        while head <= #cells do
            local cell = cells[head]; head = head + 1
            for _, other in ipairs(graph.neighbors[cell]) do
                if not included[other] and other ~= upstream and distance(start, other) <= radius
                    and not other.waterLevel and other.height <= level + row.maxPoolCarve - row.poolDepth then
                    included[other] = true; cells[#cells + 1] = other
                end
            end
        end
        if #cells < 3 or start.height - (level-row.poolDepth) > row.maxPoolCarve then return nil end
        local capped = level
        for _, cell in ipairs(cells) do
            for _, other in ipairs(graph.neighbors[cell]) do
                if not included[other] and not other.waterLevel then capped = math.min(capped, other.height) end
            end
        end
        if capped < minimum - 1e-6 then return nil end
        if capped == level then break end
        level = capped
    end
    return cells, level
end
function Hydrology:Pool(map, graph, start, upstream)
    -- 先尝试配置允许的大湖；外圈岸线太低时缩为较小的落水潭，不改写河流方向。
    for radius = self.row.poolRadius, 1, -1 do
        local cells, level = self:PlanPool(graph, start, upstream, radius)
        if cells then
            for _, cell in ipairs(cells) do
                cell.height = math.min(cell.height, level - self.row.poolDepth)
                cell.waterLevel = level; cell.waterKind = 'lake'; cell.hydrologyCarved = true
            end
            return cells
        end
    end
end

function Hydrology:Build(map)
    local row = self.row
    if not row or row.maxRivers == 0 then return end
    local graph, random = Pathfinder(map), Random(map.seed ~ 0x7312ac09)
    local parent, depth = self:Drainage(map, graph, random)
    local candidates = {}
    for i, cell in ipairs(map.cells) do
        if depth[cell] >= row.minBranchLength and cell.height >= row.minSourceHeight then
            candidates[#candidates + 1] = { cell=cell, index=i,
                score=depth[cell] * .4 + cell.height * 3 + random:Noise(cell.q,cell.r,1,11027)*8 }
        end
    end
    table.sort(candidates, function(a,b) return a.score > b.score or (a.score == b.score and a.index < b.index) end)
    local occupied, sources, branchCounts, mainCount = {}, {}, {}, 0
    local attempts = 0
    for candidateIndex = 1, #candidates do
        if attempts >= row.sourceAttempts then break end
        local source, allowed = candidates[candidateIndex].cell, true
        for _, other in ipairs(sources) do if distance(source, other) < row.sourceSpacing then allowed=false; break end end
        if allowed and not occupied[source] then
            local path, cursor, regions, regionIds = {}, source, {}, {}
            while cursor do
                path[#path + 1] = cursor
                if not regions[cursor.regionId] then regions[cursor.regionId]=true; regionIds[#regionIds+1]=cursor.regionId end
                -- 既有水域也是合法河口；不强迫河流穿过整个湖盆再抵达地图外缘。
                -- 已生成河段优先作为汇流连接，保留 parentRiverId 和主支流关系。
                if occupied[cursor] or (#path > 1 and cursor.waterLevel) then break end
                cursor = parent[cursor]
            end
            local join = occupied[path[#path]]
            local rootId = join and join.rootId or (#map.rivers + 1)
            allowed = join and #path > row.minBranchLength and branchCounts[rootId] < row.maxTributaries
                or not join and mainCount < row.maxRivers and #path >= row.minLength and #regionIds >= row.minCrossRegions
            if allowed then attempts = attempts + 1 end
            local levels = allowed and self:Plan(path, graph, occupied)
            if levels then
                local river = { id=#map.rivers+1, rootId=rootId, parentRiverId=join and join.id or nil,
                    kind=join and 'tributary' or 'main', cells=path, source=source, mouth=path[#path], regionIds=regionIds }
                if join then branchCounts[rootId]=branchCounts[rootId]+1 else mainCount=mainCount+1; branchCounts[rootId]=0 end
                map.rivers[river.id]=river; sources[#sources+1]=source
                for i, cell in ipairs(path) do
                    if not occupied[cell] then
                        cell.height=math.min(cell.height,levels[i]-row.depth)
                        cell.waterLevel=levels[i]; cell.waterKind=cell.waterKind or 'river'; cell.hydrologyCarved=true
                        cell.riverId=river.id; cell.flowTo=path[i+1]; occupied[cell]=river
                    end
                end
            end
        end
    end
    for _, cell in ipairs(map.cells) do
        local other = cell.flowTo
        if other and cell.regionId ~= other.regionId and cell.waterLevel - other.waterLevel >= row.waterfallMinDrop
            and random:Noise(cell.q, cell.r, 1, 11113) < row.waterfallChance then
            local pool = self:Pool(map, graph, other, cell)
            if pool then
                local waterfall = {id=#map.waterfalls+1, from=cell, to=other, drop=cell.waterLevel-other.waterLevel,
                    riverId=cell.riverId, poolCells=pool}
                map.waterfalls[waterfall.id]=waterfall; cell.waterfallId=waterfall.id
            end
        end
    end
    Water.Reindex(map)
end
return Hydrology
