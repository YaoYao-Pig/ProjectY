-- 真实配表定向回归：河网、瀑布概率、地貌装饰与聚落资源契约。
package.path = 'Lua/?.lua;' .. package.path
local Registry = require('Core.SystemRegistry')
local Generator = require('Game.Map.MapGenerator')
local Hex = require('Game.Map.HexGrid')
local registry = Registry({ ReadConfig = function(_, name)
    local file = assert(io.open('Assets/GameFramework/Resources/Config/' .. name .. '.bytes', 'rb'))
    local bytes = file:read('*a'); file:close(); return bytes
end, LogError = error })
registry:Register('Config', require('Config.ConfigSystem'))
registry:Register('Map', require('Game.Map.MapSystem'), {'Config'}); registry:Start()
local config, system = registry:Get('Config'), registry:Get('Map')
local recipe = {1,2,3,4,5,6,1,4,5,6}
math.randomseed(62); local expected = math.random(); math.randomseed(62)
local map = system:Generate(20260921, recipe)
assert(math.random() == expected, 'Generation polluted the global RNG')
local main, branches = 0, 0
local waterRow = config:GetTable('MapWaterNetworkTable'):Get(1)
for _, river in ipairs(map:GetRivers()) do
    if river.kind == 'main' then
        main = main + 1; assert(#river.regionIds >= waterRow.minCrossRegions and not river.parentRiverId)
    else
        branches = branches + 1
        assert(river.parentRiverId < river.id and river.mouth.riverId == river.parentRiverId)
        assert(map.rivers[river.parentRiverId].rootId == river.rootId)
    end
    assert(river.source == river.cells[1] and river.mouth == river.cells[#river.cells])
    for i = 2, #river.cells do
        local a, b = river.cells[i-1], river.cells[i]
        assert(Hex.Distance(a.q,a.r,b.q,b.r) == 1 and a.flowTo == b)
        assert(a.waterLevel >= b.waterLevel - 1e-6, 'River flows uphill')
    end
end
assert(main > 0 and branches > 0 and #map.waterfalls > 0, 'Fixture must exercise all water structures')
for _, cell in ipairs(map.cells) do
    if cell.flowTo then
        local seen, cursor = {}, cell
        while cursor do assert(not seen[cursor], 'Flow cycle'); seen[cursor]=true; cursor=cursor.flowTo end
    end
    if cell.waterLevel then
        assert(cell.waterDepth > 0 and cell.height < cell.waterLevel)
        for _, other in ipairs(map:GetNeighbors(cell.q, cell.r)) do
            assert(other.waterLevel or other.height >= cell.waterLevel - 1e-6, 'Water above its dry bank')
        end
    end
    local color = cell.groundColor; assert(#color == 3)
    for _, value in ipairs(color) do assert(value >= 0 and value <= 1) end
    config:GetTable('MapAssetTable'):Get(cell.terrainAssetId)
end
for _, fall in ipairs(map.waterfalls) do
    assert(fall.from.flowTo == fall.to and fall.from.regionId ~= fall.to.regionId)
    assert(fall.drop >= waterRow.waterfallMinDrop and fall.drop == fall.from.waterLevel - fall.to.waterLevel)
    assert(#fall.poolCells >= 3)
    local members, seen, queue = {}, {[fall.to]=true}, {fall.to}
    for _, cell in ipairs(fall.poolCells) do
        members[cell] = true; assert(cell.waterLevel == fall.to.waterLevel and cell.waterKind == 'lake')
    end
    local head = 1
    while head <= #queue do
        local cell = queue[head]; head = head + 1
        for _, other in ipairs(map:GetNeighbors(cell.q, cell.r)) do
            if members[other] and not seen[other] then seen[other]=true; queue[#queue+1]=other end
        end
    end
    assert(#queue == #fall.poolCells)
end
local styles, decorationAssets = {}, {}
for _, town in ipairs(map.towns) do
    styles[town.configId] = true
    local used = {}; for _, building in ipairs(town.buildings) do used[building.configId]=true end
    for _, id in ipairs(config:GetTable('MapTownTable'):Get(town.configId).requiredBuildingIds) do assert(used[id]) end
end
for id=1,4 do assert(styles[id], 'Missing settlement style in fixture') end
for _, building in ipairs(map.buildings) do
    local row = config:GetTable('MapBuildingTable'):Get(building.configId)
    assert(building.assetId == row.assetId and building.platformAssetId == row.platformAssetId)
end
for _, item in ipairs(map.decorations) do
    local cell = item.cell
    assert(not cell.waterLevel and not cell.buildingId and #cell.roadIds == 0)
    assert(cell.decorationId == item.id)
    decorationAssets[item.assetId] = true
end
assert(decorationAssets[7] and decorationAssets[13] and decorationAssets[14] and decorationAssets[15])
print(string.format('PASS ecosystem: %d main, %d tributaries, %d waterfalls, 4 settlement styles, %d decorations', main, branches, #map.waterfalls, #map.decorations))

-- 配置概率只影响瀑布与落水潭；同一配方仍有河网，概率 0 不伪造瀑布。
local function generateChance(chance)
    local row = {}; for key,value in pairs(waterRow) do row[key]=value end; row.waterfallChance=chance
    local proxy = setmetatable({ GetTable=function(_,name)
        if name == 'MapWaterNetworkTable' then return {All=function() return {row} end} end
        return config:GetTable(name)
    end }, {__index=function(_,key) return function(_,...) return config[key](config,...) end end})
    local generator = Generator(proxy)
    for id,name in ipairs({'Grassland','Mountain','Lake','River','Forest','Snow'}) do
        local strategy = require('Game.Map.'..name..'Region'); generator:RegisterRegion(id,strategy.Convert,strategy.Instance)
    end
    return generator:Generate(20260921, recipe)
end
local off, on = generateChance(0), generateChance(1)
assert(#off.waterfalls == 0 and #on.waterfalls >= #map.waterfalls and #off.rivers == #map.rivers)
-- 普通混合配方的湖盆阻断外沿排水时，也应保留汇入既有水域的跨区河道。
local mixed = system:Generate(20260921, {1,2,3,4,5,6,1,2})
assert(#mixed.rivers > 0)
for _, river in ipairs(mixed.rivers) do
    if river.kind == 'main' then assert(#river.regionIds >= waterRow.minCrossRegions) end
end
local again = system:Generate(20260921, recipe)
assert(#again.decorations == #map.decorations and #again.waterfalls == #map.waterfalls)
for i,cell in ipairs(map.cells) do
    local other = again.cells[i]
    assert(cell.height == other.height and cell.waterLevel == other.waterLevel and cell.riverId == other.riverId)
    assert(cell.terrainAssetId == other.terrainAssetId and cell.decorationId == other.decorationId)
end
local snapshot = require('Game.Map.MapRenderSnapshot')(map)
assert(#snapshot.assets == 18 and #snapshot.decorations == #map.decorations)
snapshot.cells[1].groundColor[1] = -1; snapshot.assets[1].prefabPath = 'changed'
assert(map.cells[1].groundColor[1] >= 0 and map.assets[1].prefabPath ~= 'changed')
print('PASS flow acyclicity, downhill stages, banks, connected pools, probability extremes, determinism and detached render data')
registry:Shutdown()
