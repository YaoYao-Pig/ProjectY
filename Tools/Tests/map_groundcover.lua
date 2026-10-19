-- 小型合成格网覆盖生态散布契约，另用 240 格真实生成结果检查只读快照桥接。
package.path = 'Lua/?.lua;' .. package.path
local registry = require('Core.SystemRegistry')({ReadConfig = function(_, name)
    local file = assert(io.open('Assets/GameFramework/Resources/_Gen/Config/' .. name .. '.bytes', 'rb'))
    local bytes = file:read('*a'); file:close(); return bytes
end, LogError = error})
registry:Register('Config', require('Config.ConfigSystem'))
registry:Register('Map', require('Game.Map.MapSystem'), {'Config'}); registry:Start()
local config = registry:Get('Config')
local Map, HexGrid = require('Game.Map.Map'), require('Game.Map.HexGrid')
local Groundcover, snapshot = require('Game.Map.MapGroundcover'), require('Game.Map.MapRenderSnapshot')
local map = Map(20261011, 2)
map.biomes = config:GetTable('MapBiomeTable'):All(); map.assets = config:GetTable('MapAssetTable'):All()
map.random = require('Game.Map.SeededRandom')(91)
for q = -12, 12 do for r = -12, 12 do
    local cell = {q = q, r = r, height = q == 12 and 5 or 0, roadIds = {},
        biomeWeights = {{regionType = 1, weight = 1}}, groundColor = {.4, .6, .3}, terrainAssetId = 1, waterAssetId = 6}
    map.cells[#map.cells + 1] = cell; map.cellsByKey[HexGrid.Key(q, r)] = cell
    if q == -12 then cell.waterLevel = 1; cell.waterKind = 'lake'; cell.waterDepth = 1
    elseif q == -11 then cell.roadIds = {1}
    elseif q == -10 then cell.buildingId = 1
    elseif q == -9 then cell.townId = 1
    elseif q >= -8 and q <= -5 then
        local id = #map.decorations + 1; cell.decorationId = id
        map.decorations[id] = {id = id, cell = cell, assetId = q == -8 and 89 or 13, scale = 1, yaw = 0}
    end
end end
map:GetCell(2, 2).biomeWeights = {{regionType = 1, weight = .1}, {regionType = 2, weight = .2}, {regionType = 5, weight = .7}}
local function layoutSignature()
    local result = {}
    for _, cell in ipairs(map.cells) do
        result[#result + 1] = table.concat({cell.q, cell.r, cell.height, cell.waterLevel or -1, cell.buildingId or 0,
            cell.townId or 0, table.concat(cell.roadIds, ','), cell.decorationId or 0}, ':')
    end
    return table.concat(result, ';')
end
local original = layoutSignature(); local randomState = map.random.state
math.randomseed(715); local expectedRandom = math.random(); math.randomseed(715)
Groundcover.Build(map)
assert(math.random() == expectedRandom and map.random.state == randomState, 'Groundcover changed another random stream')
assert(layoutSignature() == original, 'Groundcover changed gameplay layout')
local function signature(items)
    local result = {}
    for _, item in ipairs(items) do
        result[#result + 1] = string.format('%d:%d:%d:%.9f:%.9f:%.9f:%.9f:%.9f', item.cell.q, item.cell.r,
            item.kind, item.offsetX, item.offsetZ, item.scale, item.yaw, item.phase)
    end
    return table.concat(result, ';')
end
local first = signature(map.groundcover); Groundcover.Build(map)
assert(signature(map.groundcover) == first, 'Groundcover is nondeterministic')
local counts, kinds, underTrees, occupied = {}, {}, 0, {}
for _, item in ipairs(map.groundcover) do
    local cell = item.cell
    assert(map:GetCell(cell.q, cell.r) == cell, 'Groundcover lost source cell identity')
    assert(not cell.waterLevel and not cell.buildingId and not cell.townId and #cell.roadIds == 0, 'Groundcover blocked a protected cell')
    assert(cell.q ~= -8 and cell.q < 11, 'Groundcover overlapped a large prop or steep edge')
    assert(item.kind >= 1 and item.kind <= 5 and item.kind == math.floor(item.kind))
    local distance = math.sqrt(item.offsetX ^ 2 + item.offsetZ ^ 2)
    assert(distance <= map.hexRadius * .55 and distance > 0, 'Groundcover offset escaped its cell or stayed on the center')
    if item.kind == 2 then assert(distance < map.hexRadius * .3, 'Shrub offset exceeds its narrower range') end
    if cell.decorationId then
        underTrees = underTrees + 1
        assert(item.kind == 1 and distance >= map.hexRadius * .34, 'Understory did not leave the trunk center clear')
    end
    assert(item.scale >= .7 and item.scale <= 1.25 and item.yaw >= 0 and item.yaw <= 360 and item.phase >= 0 and item.phase <= math.pi * 2)
    counts[cell] = counts[cell] or {plants = 0, creatures = 0}
    local key = item.kind <= 3 and 'plants' or 'creatures'; counts[cell][key] = counts[cell][key] + 1
    assert(counts[cell].plants <= 3 and counts[cell].creatures <= 1, 'Groundcover exceeded its per-cell budget')
    kinds[item.kind] = true; occupied[cell] = true
end
for kind = 1, 5 do assert(kinds[kind], 'Fixture omitted groundcover kind ' .. kind) end
assert(underTrees > 0, 'Fixture omitted sparse understory')
-- 只观察成片疏密与空地，不把实现所用噪声函数复制进测试。
local blocks, occupiedCells = {}, 0
for _, cell in ipairs(map.cells) do
    if cell.q >= -4 and cell.q <= 10 then
        local key = math.floor(cell.q / 4) .. ':' .. math.floor(cell.r / 4)
        local block = blocks[key] or {cells = 0, occupied = 0}; blocks[key] = block
        block.cells = block.cells + 1
        if occupied[cell] then block.occupied = block.occupied + 1; occupiedCells = occupiedCells + 1 end
    end
end
local lowest, highest = 1, 0
for _, block in pairs(blocks) do if block.cells >= 12 then
    local density = block.occupied / block.cells; lowest = math.min(lowest, density); highest = math.max(highest, density)
end end
assert(highest - lowest > .15 and occupiedCells < 250, 'Groundcover lost patch contrast or filled the open meadow')

local render = snapshot(map)
assert(#render.surfaces == #map.biomes and #render.groundcover == #map.groundcover)
local mixedIndex
for i, cell in ipairs(map.cells) do if cell.q == 2 and cell.r == 2 then mixedIndex = i end end
local mixed = render.cells[mixedIndex]
assert(mixed.surfaceA == 5 and mixed.surfaceB == 2 and math.abs(mixed.surfaceBlend - 2 / 9) < 1e-9, 'Surface blend did not use the two largest weights')
assert(render.cells[1].surfaceA == 1 and render.cells[1].surfaceB == 1 and render.cells[1].surfaceBlend == 0)
for i, item in ipairs(render.groundcover) do assert(map.cells[item.cell] == map.groundcover[i].cell) end
render.surfaces[1].groundTexture = 'changed'; render.groundcover[1].offsetX = 999
assert(map.biomes[1].groundTexture == 'MapGround/Grass' and map.groundcover[1].offsetX ~= 999, 'Render snapshot retained mutable source tables')
local empty = Map(1, 1); Groundcover.Build(empty); assert(#empty.groundcover == 0)
local savedProfiles = map.biomes; map.biomes = {}
assert(not pcall(snapshot, map), 'Snapshot invented a missing biome surface'); map.biomes = savedProfiles

local real = registry:Get('Map'):Generate(20261011, {1, 3, 5}, 240)
local actual = snapshot(real)
assert(#actual.cells == 240 and #actual.surfaces == 6 and #actual.groundcover == #real.groundcover)
for i, surface in ipairs(actual.surfaces) do
    local row = real.biomes[i]
    for _, field in ipairs({'id', 'groundTexture', 'textureWorldSize', 'textureStrength', 'windStrength', 'groundColor'}) do
        assert(surface[field] == row[field], 'Surface snapshot changed ' .. field)
    end
end
for i, item in ipairs(actual.groundcover) do
    assert(real.cells[item.cell] == real.groundcover[i].cell)
    assert(not real.cells[item.cell].waterLevel and not real.cells[item.cell].townId)
end
registry:Shutdown()
print(string.format('PASS groundcover: %d synthetic cells, %d items, %d understory items; patch occupancy %.2f..%.2f, five kinds, deterministic placement, avoidance and detached surfaces',
    #map.cells, #map.groundcover, underTrees, lowest, highest))
print(string.format('PASS real groundcover snapshot: %d cells, %d surfaces, %d groundcover items', #actual.cells, #actual.surfaces, #actual.groundcover))
