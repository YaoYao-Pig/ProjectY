-- 全图静态水系：低洼出口的优先洪泛建立无环下游树，河道沿树汇合，允许跨 Region。
-- 仅开挖有限深度的河床；不模拟水量、侵蚀或队伍通行。
local Class = require('Core.Class')
local Hex = require('Game.Map.HexGrid')
local Random = require('Game.Map.SeededRandom')
local Pathfinder = require('Game.Map.MapPathfinder')
local Water = require('Game.Map.MapWater')
local Curve = require('Game.Map.MapConfigCurve')
local Hydrology = Class('MapHydrology')
local function before(a, b)
    return a.level < b.level or (a.level == b.level and (a.cost < b.cost or (a.cost == b.cost and a.index < b.index)))
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
    assert(row.meanderScale >= 1 and row.runoffNoise >= 0 and row.runoffNoise < 1 and row.bankNoise >= 0 and row.bankNoise < 1, 'Invalid spatial water noise')
    assert(row.maxChannelRadius >= 0 and row.maxChannelRadius <= 3 and row.bankCarveDepth >= 0, 'Invalid river width budget')
    assert(row.maxLakes >= 0 and row.maxLakes <= 32 and row.minLakeCells >= 1 and row.maxLakeCells >= row.minLakeCells and row.minLakeDepth > 0, 'Invalid lake limits')
    Curve.Validate(row.widthFlowXs,row.widthRadiusYs,0,3)
    self.regionTable=config:GetTable('MapRegionTable'); self.profiles=config:GetTable('MapHydrologyProfileTable')
    for _, profile in ipairs(self.profiles:All()) do
        assert(profile.runoff > 0 and profile.carveResistance > 0 and profile.meander >= 0 and profile.widthScale > 0 and profile.slopeNarrowing >= 0, 'Invalid hydrology coefficients')
        assert(profile.lakeChance >= 0 and profile.lakeChance <= 1 and profile.lakeFill > 0 and profile.lakeFill <= 1, 'Invalid basin fill settings')
    end
end

-- 相同地貌也允许使用不同配置；边界以参与地形混合的实例权重插值，避免河宽突变。
function Hydrology:Parameters(map,random)
    self.parameters={}
    local profiles={}
    for _, region in ipairs(map.regions) do profiles[region.instanceId]=self.profiles:Get(self.regionTable:Get(region.configId).hydrologyProfileId) end
    for _, cell in ipairs(map.cells) do
        local values={runoff=0,carveResistance=0,meander=0,widthScale=0,slopeNarrowing=0,lakeChance=0,lakeFill=0}
        for _, weight in ipairs(cell.regionWeights) do
            local profile=assert(profiles[weight.regionId], 'Missing region water profile')
            for key in pairs(values) do values[key]=values[key]+profile[key]*weight.weight end
        end
        self.parameters[cell]=values
        cell.runoff=values.runoff*(1+(random:Noise(cell.q,cell.r,self.row.meanderScale,11201)*2-1)*self.row.runoffNoise)
    end
end

-- 仅选择少量相隔较远的低洼出口，使主河有机会穿越多个实例，不在每个 Region 单独截断。
function Hydrology:Drainage(map, graph, random, allBoundary)
    local boundary = {}
    for i, cell in ipairs(map.cells) do
        if #graph.neighbors[cell] < 6 then boundary[#boundary + 1] = { cell = cell, index = i,
            score = (cell.waterLevel or cell.height) + random:Noise(cell.q, cell.r, 1, 11003) * .08 } end
    end
    table.sort(boundary, function(a,b) return a.score < b.score or (a.score == b.score and a.index < b.index) end)
    local outlets = {}
    for _, candidate in ipairs(boundary) do
        local allowed = true
        if not allBoundary then
            for _, cell in ipairs(outlets) do if distance(cell, candidate.cell) < self.row.outletSpacing then allowed = false; break end end
        end
        if allowed or allBoundary then outlets[#outlets + 1] = candidate.cell end
        if not allBoundary and #outlets >= self.row.outletCount then break end
    end
    local heap, seen, parent, depth, best, order = {}, {}, {}, {}, {}, {}
    for _, cell in ipairs(outlets) do
        local entry={cell=cell,level=cell.waterLevel or cell.height,cost=0,index=graph.indices[cell]}
        depth[cell]=0; best[cell]=entry; push(heap,entry)
    end
    while #heap > 0 do
        local entry = pop(heap)
      if best[entry.cell]==entry and not seen[entry.cell] then
        seen[entry.cell]=true; order[#order+1]=entry.cell
        for _, other in ipairs(graph.neighbors[entry.cell]) do
            if not seen[other] then
                local profile=self.parameters[other]
                local step=math.abs(other.height-entry.cell.height)
                -- 先最小化真实翻越高度，再比较开挖与空间曲流代价；噪声不能穿山捷径。
                local bend=random:Noise(other.q,other.r,self.row.meanderScale,11213)
                local cost=entry.cost+1+step*profile.carveResistance+profile.meander*bend*4/(1+step*profile.slopeNarrowing)
                local candidate={cell=other,level=math.max(entry.level,other.waterLevel or other.height),cost=cost,index=graph.indices[other]}
                if not best[other] or before(candidate,best[other]) then
                    parent[other]=entry.cell; depth[other]=depth[entry.cell]+1
                    best[other]=candidate; push(heap,candidate)
                end
            end
        end
      end
    end
    assert(#order==#map.cells, 'Drainage requires a connected map')
    local filled={}; for cell,entry in pairs(best) do filled[cell]=entry.level end
    return parent, depth, order, filled
end

-- 先用全部地图外缘求真实盆地的溢出高度；虚拟填洼只用于分析，不抬高地面。
-- 蓄水范围是等高线下的连通格，岩脊、岛屿与天然缺口会决定岸线。
function Hydrology:Lakes(map,graph,random)
    local row=self.row
    local _,_,_,filled=self:Drainage(map,graph,random,true)
    local seen, basins={},{}
    for _, start in ipairs(map.cells) do
        if not seen[start] and filled[start]-start.height>=row.minLakeDepth then
            local cells,head={start},1; seen[start]=true
            local lowest=start
            while head<=#cells do
                local cell=cells[head];head=head+1
                if cell.height<lowest.height then lowest=cell end
                for _, other in ipairs(graph.neighbors[cell]) do
                    if not seen[other] and filled[other]==filled[start] and other.height<filled[start] then
                        seen[other]=true;cells[#cells+1]=other
                    end
                end
            end
            basins[#basins+1]={cells=cells,lowest=lowest,spill=filled[start]}
        end
    end
    table.sort(basins,function(a,b)
        local da,db=a.spill-a.lowest.height,b.spill-b.lowest.height
        return da>db or (da==db and graph.indices[a.lowest]<graph.indices[b.lowest])
    end)
    local count=0
    for _, basin in ipairs(basins) do
        if count>=row.maxLakes then break end
        local start=basin.lowest;local profile=self.parameters[start]
        if random:Noise(start.q,start.r,1,11239)<profile.lakeChance then
            local level=start.height+(basin.spill-start.height)*profile.lakeFill
            local heights={};for _, cell in ipairs(basin.cells) do heights[#heights+1]=cell.height end
            table.sort(heights)
            if #heights>row.maxLakeCells then level=math.min(level,heights[row.maxLakeCells+1]) end
            local cells,head,included={start},1,{[start]=true}
            while head<=#cells do
                local cell=cells[head];head=head+1
                for _, other in ipairs(graph.neighbors[cell]) do
                    if not included[other] and other.height<level then included[other]=true;cells[#cells+1]=other end
                end
            end
            if #cells>=row.minLakeCells and #cells<=row.maxLakeCells and level-start.height>=row.minLakeDepth then
                for _, cell in ipairs(cells) do cell.waterLevel=level;cell.waterKind='lake';cell.basinSpill=basin.spill end
                count=count+1
            end
        end
    end
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
        if cell.height - (level - self.row.depth) > self.row.maxCarveDepth/self.parameters[cell].carveResistance then return nil end
        levels[i] = level; previous = level
    end
    return levels
end

-- 河宽随上游汇水增大，坡陡时收窄；只在允许开挖且能保留真实岸线的位置扩宽。
-- 每个横断面先计划再写入，不修改既有主支流中心线或湖面。
function Hydrology:Widen(map,graph,random)
    local row=self.row
    for _, river in ipairs(map.rivers) do
        for _, center in ipairs(river.cells) do
            local profile=self.parameters[center]
            local slope=center.flowTo and math.abs(center.height-center.flowTo.height) or 0
            local radius=Curve.Sample(row.widthFlowXs,row.widthRadiusYs,center.flowAccumulation)*profile.widthScale/(1+slope*profile.slopeNarrowing)
            center.channelRadius=math.min(row.maxChannelRadius,radius)
            local cells,included,head={center},{[center]=true},1
            while head<=#cells do
                local cell=cells[head];head=head+1
                for _, other in ipairs(graph.neighbors[cell]) do
                    local span=distance(center,other)
                    local noise=(random:Noise(other.q,other.r,row.meanderScale*.6,11257)*2-1)*row.bankNoise
                    local carve=other.height-(center.waterLevel-row.depth)
                    if not included[other] and not other.waterLevel and span<=row.maxChannelRadius and span<=radius+.45+noise
                        and carve<=row.bankCarveDepth/self.parameters[other].carveResistance then
                        included[other]=true;cells[#cells+1]=other
                    end
                end
            end
            local allowed=true
            for _, cell in ipairs(cells) do
                for _, other in ipairs(graph.neighbors[cell]) do
                    if not included[other] and not other.waterLevel and other.height<center.waterLevel-1e-6 then allowed=false end
                end
            end
            if allowed then
                for i=2,#cells do
                    local cell=cells[i]
                    cell.height=math.min(cell.height,center.waterLevel-row.depth)
                    cell.waterLevel=center.waterLevel;cell.waterKind='river';cell.riverId=river.id
                    cell.hydrologyCarved=true;cell.channelBank=true
                end
            end
        end
    end
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
    if not row then Water.Build(map); return end
    local graph, random = Pathfinder(map), Random(map.seed ~ 0x7312ac09)
    self:Parameters(map,random)
    -- 地貌策略只决定地面起伏；最终河湖由同一个全图分析统一定界。
    for _, cell in ipairs(map.cells) do cell.waterLevel=nil;cell.waterKind=nil end
    self:Lakes(map,graph,random)
    local parent, depth, order = self:Drainage(map, graph, random)
    for _, cell in ipairs(map.cells) do cell.flowAccumulation=cell.runoff end
    for i=#order,1,-1 do
        local cell=order[i];local downstream=parent[cell]
        if downstream then downstream.flowAccumulation=downstream.flowAccumulation+cell.flowAccumulation end
    end
    local candidates = {}
    for i, cell in ipairs(map.cells) do
        if depth[cell] >= row.minBranchLength and cell.height >= row.minSourceHeight and not cell.waterLevel and cell.flowAccumulation>=row.minSourceRunoff then
            candidates[#candidates + 1] = { cell=cell, index=i,
                score=depth[cell] * .4 + cell.height * 3 + math.log(1+cell.flowAccumulation)*2+random:Noise(cell.q,cell.r,1,11027)*4 }
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
                or not join and mainCount < row.maxRivers and #path >= row.minLength and #regionIds >= math.min(row.minCrossRegions,#map.regions)
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
    self:Widen(map,graph,random)
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
    self.parameters=nil
end
return Hydrology
