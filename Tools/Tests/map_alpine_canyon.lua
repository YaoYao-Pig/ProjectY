-- 真实配表的高山/峡谷定向回归；只使用项目 xLua，不启动 Editor 或 Play。
package.path = 'Lua/?.lua;' .. package.path
local registry = require('Core.SystemRegistry')({ReadConfig = function(_, name)
    local file = assert(io.open('Assets/GameFramework/Resources/_Gen/Config/' .. name .. '.bytes', 'rb'))
    local bytes = file:read('*a'); file:close(); return bytes
end, LogError = error})
registry:Register('Config', require('Config.ConfigSystem'))
registry:Register('Map', require('Game.Map.MapSystem'), {'Config'}); registry:Start()
local config, system = registry:Get('Config'), registry:Get('Map')
local types = config:GetEnum('Map', 'E_MapRegion')
assert(types.HighMountain == 12 and types.Canyon == 13)

local function connected(map, cells)
    local allowed, seen, queue, head = {}, {}, {cells[1]}, 1
    for _, cell in ipairs(cells) do allowed[cell] = true end
    seen[cells[1]] = true
    while head <= #queue do
        local cell = queue[head]; head = head + 1
        for _, other in ipairs(map:GetNeighbors(cell.q, cell.r)) do
            if allowed[other] and not seen[other] then seen[other] = true; queue[#queue + 1] = other end
        end
    end
    assert(#queue == #cells, 'Landform removed cells or broke map topology')
end

local function check(map)
    assert(map.generationVersion == 8)
    connected(map, map.cells)
    local summary = {}
    for _, kind in ipairs({types.HighMountain, types.Canyon}) do
        local region = assert(map:GetRegionsByType(kind)[1])
        connected(map, region.cells)
        local low, high, step, entries, dark, blocked = math.huge, -math.huge, 0, 0, 0, 0
        for _, cell in ipairs(region.cells) do
            assert(map:FindCell(cell.q, cell.r) == cell, 'Deep land must be an actual indexed cell')
            low, high = math.min(low, cell.height), math.max(high, cell.height)
            if cell.worldTravelBlocked then
                blocked = blocked + 1
                assert(not cell.buildingId and #cell.roadIds == 0, 'Infrastructure crossed an impassable cliff')
            end
            local access, feature = false, false
            for _, other in ipairs(map:GetNeighbors(cell.q, cell.r)) do
                step = math.max(step, math.abs(cell.height - other.height))
                if not other.waterLevel and not other.worldTravelBlocked and math.abs(cell.height - other.height) <= 1.2 then access = true end
                if other.regionId == region.instanceId and other.worldTravelBlocked then feature = true end
            end
            if cell.landformEntrance then
                assert(not cell.waterLevel and not cell.worldTravelBlocked and access and feature,
                    string.format('Entrance must be on a traversable foot or rim: %d,%d zone=%s blocked=%s water=%s access=%s feature=%s',
                        cell.q, cell.r, cell.landformZone, tostring(cell.worldTravelBlocked), tostring(cell.waterLevel), tostring(access), tostring(feature)))
                assert(cell.landformZone == 'mountainFoot' or cell.landformZone == 'canyonRim')
                entries = entries + 1
            end
            if cell.landformZone == 'canyonFloor' then
                assert(cell.worldTravelBlocked and cell.terrainAssetId == 1105, 'Canyon floor must be solid and inaccessible from the world map')
                if cell.canyonDepth >= .72 then
                    assert(cell.groundColor[1] < .08 and cell.groundColor[2] < .08 and cell.groundColor[3] < .08)
                    dark = dark + 1
                end
            end
        end
        assert(entries > 0 and blocked > 0, 'Landform edge entrance or impassable interior is missing')
        if kind == types.Canyon then
            assert(high-low>30 and low < -25 and dark > 0, 'Canyon lacks a deep black solid floor')
        else
            local shape=assert(region.mountainShape)
            assert(region:Contains(shape.centerQ,shape.centerR),'Mountain center must lie inside the actual cropped footprint')
            assert(shape.detailAmplitude<=shape.relief*.03 and #shape.mainRidge==7 and #shape.branches==6 and #shape.valleys==4)
            local heights={}
            for i,node in ipairs(shape.mainRidge) do heights[i]=map:GetCell(node.q,node.r).baseHeight end
            assert(heights[2]>heights[3]+shape.relief*.06 and heights[4]>math.max(heights[3],heights[5])+shape.relief*.15
                and heights[6]>heights[5]+shape.relief*.06,'Actual terrain must preserve secondary peaks and lower saddles: '..table.concat(heights,','))
            local broad,rawStep,plateauEdges,finalInternalStep=0,0,0,0;local minimum,maximum=math.huge,-math.huge
            local terraceLevels={}
            for _,cell in ipairs(region.cells) do
                minimum=math.min(minimum,cell.baseHeight);maximum=math.max(maximum,cell.baseHeight)
                if cell.baseHeight>=1+shape.relief*.35 then broad=broad+1 end
                local level=(cell.baseHeight-shape.baseHeight)/shape.terraceStep
                assert(math.abs(level-math.floor(level+.5))<1e-6,'Mountain tile top escaped its elevation terrace')
                terraceLevels[math.floor(level+.5)]=true
                for _,other in ipairs(map:GetNeighbors(cell.q,cell.r)) do
                    if other.regionId==cell.regionId then
                        rawStep=math.max(rawStep,math.abs(cell.baseHeight-other.baseHeight))
                        finalInternalStep=math.max(finalInternalStep,math.abs(cell.height-other.height))
                        if level>1 and math.abs(cell.baseHeight-other.baseHeight)<1e-6 then plateauEdges=plateauEdges+1 end
                    end
                end
            end
            assert(broad>=#region.cells*.08,'Mountain relief collapsed into isolated needles')
            assert(maximum-minimum<=shape.radiusCells*math.sqrt(3)*map.hexRadius*1.8+1e-6,'Peak height ignored actual footprint width')
            assert(rawStep<=shape.maxStep+1e-6 and shape.maxStep<=map.hexRadius*4+1e-6,'Adjacent mountain tiles became tall isolated columns')
            assert(finalInternalStep<=map.hexRadius*6,'Border blending cut deep canyon columns inside the mountain')
            assert(plateauEdges>=#region.cells*.04,'Raised hex terraces do not form connected patches')
            local levelCount=0;for _ in pairs(terraceLevels) do levelCount=levelCount+1 end
            print(string.format('PASS mountain terraces: %d tiles, %d levels, %.1f height, %.1f base step, %.1f final internal step, %d raised equal-height edges',
                #region.cells,levelCount,maximum-minimum,rawStep,finalInternalStep,plateauEdges))
            for _,branch in ipairs(shape.branches) do
                assert(branch.nodes[1].height>branch.nodes[2].height and branch.nodes[2].height>branch.nodes[3].height)
            end
            for _,valley in ipairs(shape.valleys) do
                assert(valley.nodes[1].height>valley.nodes[2].height and valley.nodes[2].height>valley.nodes[3].height)
                local outlet=valley.nodes[3];local cell=map:GetCell(outlet.q,outlet.r);local edge=false
                for direction=1,6 do
                    local q,r=require('Game.Map.HexGrid').Neighbor(cell.q,cell.r,direction)
                    local other=map:FindCell(q,r)
                    if not other or other.regionId~=cell.regionId then edge=true end
                end
                assert(edge,'Drainage outlet must reach the actual region edge')
            end
        end
        summary[kind] = {low = low, high = high}
        print(string.format('PASS region %d: relief %.1f, max step %.1f, %d entrances, %d dark floor cells', kind, high-low, step, entries, dark))
    end
    assert(#map.clouds > 0, 'Large mountain must generate a cloud belt')
    for _, cloud in ipairs(map.clouds) do
        assert(cloud.y > summary[12].low and cloud.y < summary[12].high and cloud.opacity > 0 and cloud.opacity < 1)
    end
    local snapshot = require('Game.Map.MapRenderSnapshot')(map)
    assert(#snapshot.cells == #map.cells and #snapshot.clouds == #map.clouds)
    local floor = config:GetTable('MapBiomeTable'):Get(13)
    assert(floor.textureStrength == 0 and floor.cliffTintStrength == 1, 'Canyon tint must survive top and side materials')
    for _,cell in ipairs(map.cells) do
        assert(cell.surfaceCorners==nil,'Terrain must retain its complete flat hex top')
    end
end

local map = system:Generate(42, {1, 12, 13, 5})
check(map)
local same = system:Generate(42, {1, 12, 13, 5})
assert(#same.cells == #map.cells and #same.clouds == #map.clouds)
for i, cell in ipairs(map.cells) do
    local other = same.cells[i]
    assert(cell.q == other.q and cell.r == other.r and cell.height == other.height
        and cell.worldTravelBlocked == other.worldTravelBlocked and cell.landformEntrance == other.landformEntrance,
        'Landforms changed for an identical seed and recipe')
end
check(system:Generate(73, {12, 13}))
local clipped=system:GenerateSeeded(42,2500)
local croppedMountain=assert(clipped:GetRegionsByType(types.HighMountain)[1])
local croppedLow,croppedHigh=math.huge,-math.huge
for _,cell in ipairs(croppedMountain.cells) do croppedLow=math.min(croppedLow,cell.baseHeight);croppedHigh=math.max(croppedHigh,cell.baseHeight) end
assert(#croppedMountain.cells>=100 and croppedHigh-croppedLow>=15,'Small-world budget reduced the mountain to a tiny hill')
print(string.format('PASS small world mountain: %d tiles, %.1f height',#croppedMountain.cells,croppedHigh-croppedLow))

-- v7 基线在替换算法前记录；检查原高度、水文、通行、配色、资源及装饰均未改变。
local function fingerprint(map)
    local hash=2166136261
    local function push(value)
        local text=type(value)=='number' and string.format('%.17g',value) or tostring(value)
        for i=1,#text do hash=((hash ~ text:byte(i))*16777619)&0xffffffff end
        hash=((hash ~ 124)*16777619)&0xffffffff
    end
    for _,cell in ipairs(map.cells) do
        for _,key in ipairs({'q','r','height','baseHeight','waterLevel','waterKind','worldTravelBlocked','landformZone','landformEntrance','terrainAssetId','waterAssetId'}) do push(cell[key]) end
        for _,value in ipairs(cell.groundColor) do push(value) end
        assert(cell.surfaceCorners==nil,'Legacy world acquired new geometry')
    end
    for _,item in ipairs(map.decorations) do
        for _,value in ipairs({item.cell.q,item.cell.r,item.assetId,item.scale,item.yaw,item.height or item.cell.height}) do push(value) end
    end
    return hash
end
local legacy=system:Generate(42,{1,12,13,5},nil,nil,7)
assert(fingerprint(legacy)==1314487183,'Existing v7 terrain snapshot changed')
assert(#legacy.cells==#map.cells)
for i,cell in ipairs(map.cells) do
    assert(cell.q==legacy.cells[i].q and cell.r==legacy.cells[i].r and cell.regionId==legacy.cells[i].regionId,
        'Mountain preparation consumed the shared placement random stream')
end
registry:Shutdown()
print('PASS ridge network, true footprint proportions, flat hex terraces, canyon, entrances, clouds, determinism and unchanged v7')
