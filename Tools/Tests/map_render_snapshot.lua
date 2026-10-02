-- 只验证新增的 Unity 渲染适配层：真实配表、索引身份、水位及快照所有权。
package.path = 'Lua/?.lua;' .. package.path
local registry = require('Core.SystemRegistry')({ ReadConfig = function(_, name)
    local file = assert(io.open('Assets/GameFramework/Resources/_Gen/Config/' .. name .. '.bytes', 'rb'))
    local bytes = file:read('*a'); file:close(); return bytes
end, LogError = error })
registry:Register('Config', require('Config.ConfigSystem'))
registry:Register('Map', require('Game.Map.MapSystem'), {'Config'})
registry:Start()
local map = registry:Get('Map'):Generate(20260921, {1, 2, 3, 4, 1, 2, 3, 4})
local build = require('Game.Map.MapRenderSnapshot')
local snapshot = build(map)
-- 真实共享资源表含地牢室内陈设；快照应覆盖全部实际引用，且不能要求绑定未用资源。
local required = {}
for _, cell in ipairs(snapshot.cells) do
    required[cell.terrainAssetId] = true
    if cell.hasWater then required[cell.waterAssetId] = true end
end
for _, building in ipairs(snapshot.buildings) do
    required[building.assetId], required[building.platformAssetId] = true, true
end
for _, decoration in ipairs(snapshot.decorations) do required[decoration.assetId] = true end
for _, asset in ipairs(snapshot.assets) do
    assert(required[asset.id], 'Snapshot includes an unused or duplicate asset: ' .. asset.id)
    required[asset.id] = nil
end
assert(next(required) == nil, 'Snapshot omitted a referenced asset')
assert(#snapshot.assets < #map.assets, 'Fixture must contain unused shared assets')
assert(snapshot.hexRadius == map.hexRadius and snapshot.regionCount == #map:GetRegions())
assert(#snapshot.cells == #map:GetCells() and #snapshot.buildings == #map:GetBuildings())
local wet, riverCells, lakeCells, directedCells, bankCells = 0, 0, 0, 0, 0
for i, row in ipairs(snapshot.cells) do
    local cell = map:GetCells()[i]
    local x, y, z = map:GetCellWorldPosition(cell.q, cell.r)
    assert(row.x == x and row.y == y and row.z == z)
    assert(row.hasWater == (cell.waterLevel ~= nil))
    assert(row.waterLevel == (cell.waterLevel or 0))
    assert(row.waterDepth == (cell.waterDepth or 0))
    assert(row.isRiver == (cell.waterKind == 'river'))
    assert(row.riverId == (cell.riverId or 0))
    if cell.flowTo then
        assert(map:GetCells()[row.flowTo] == cell.flowTo, 'Flow target lost source cell identity')
        directedCells = directedCells + 1
    else assert(row.flowTo == 0) end
    if row.hasWater then assert(row.waterLevel > row.y); wet = wet + 1 end
    if row.isRiver then riverCells = riverCells + 1 end
    if cell.waterKind == 'lake' then lakeCells = lakeCells + 1 end
    if cell.channelBank then bankCells = bankCells + 1 end
    for j, weight in ipairs(row.weights) do
        assert(weight.regionType == cell.biomeWeights[j].regionType and weight.weight == cell.biomeWeights[j].weight)
    end
end
assert(wet > 0 and #snapshot.towns > 0 and #snapshot.roads > 0, 'Fixture must cover water, towns and roads')
-- 河网生成受地形严格约束；用六格夹具保证无河流种子也覆盖全部水体适配分支。
local fixture = require('Game.Map.Map')(1, 1)
local HexGrid = require('Game.Map.HexGrid')
fixture.assets = {{id = 1, prefabPath = 'ground', referenceHeight = 1},
    {id = 2, prefabPath = 'water', referenceHeight = 1}}
for i = 1, 6 do
    local cell = {q = i - 1, r = 0, height = 0, biomeWeights = {{regionType = 1, weight = 1}},
        groundColor = {.2, .3, .4}, terrainAssetId = 1, waterAssetId = 2}
    fixture.cells[i] = cell; fixture.cellsByKey[HexGrid.Key(cell.q, cell.r)] = cell
    if i > 1 then cell.waterLevel = .75; cell.waterDepth = .75; cell.waterKind = 'river'; cell.riverId = 7 end
end
fixture.cells[2].flowTo = fixture.cells[6]
fixture.cells[4].channelBank = true
fixture.cells[5].waterKind = 'lake'; fixture.cells[5].riverId = nil
-- 落水潭可保留河流中心线引用，但视觉分类仍按最终 waterKind。
fixture.cells[6].waterKind = 'lake'; fixture.cells[6].flowTo = fixture.cells[3]
local waterSnapshot = build(fixture)
assert(not waterSnapshot.cells[1].hasWater and not waterSnapshot.cells[1].isRiver)
assert(waterSnapshot.cells[1].waterDepth == 0 and waterSnapshot.cells[1].riverId == 0 and waterSnapshot.cells[1].flowTo == 0)
for i = 2, 4 do
    assert(waterSnapshot.cells[i].hasWater and waterSnapshot.cells[i].isRiver)
    assert(waterSnapshot.cells[i].waterDepth == .75 and waterSnapshot.cells[i].riverId == 7)
end
assert(waterSnapshot.cells[2].flowTo == 6 and waterSnapshot.cells[3].flowTo == 0 and waterSnapshot.cells[4].flowTo == 0)
assert(not waterSnapshot.cells[5].isRiver and waterSnapshot.cells[5].hasWater)
assert(waterSnapshot.cells[5].riverId == 0 and waterSnapshot.cells[5].flowTo == 0 and waterSnapshot.cells[5].waterDepth == .75)
assert(not waterSnapshot.cells[6].isRiver and waterSnapshot.cells[6].riverId == 7 and waterSnapshot.cells[6].flowTo == 3)
waterSnapshot.cells[2].flowTo = 0; waterSnapshot.cells[2].riverId = 99; waterSnapshot.cells[2].waterDepth = 9
assert(fixture.cells[2].flowTo == fixture.cells[6] and fixture.cells[2].riverId == 7 and fixture.cells[2].waterDepth == .75)
for i, row in ipairs(snapshot.buildings) do
    local original = map:GetBuildings()[i]
    assert(map:GetCells()[row.center] == original.cell and map:GetCells()[row.entrance] == original.entrance)
    assert(row.townId == original.townId and row.baseHeight == original.baseHeight)
    for j, index in ipairs(row.cells) do assert(map:GetCells()[index] == original.cells[j]) end
end
for i, road in ipairs(snapshot.roads) do
    for j, index in ipairs(road.cells) do assert(map:GetCells()[index] == map:GetRoads()[i].cells[j]) end
end
local sourceHeight = map:GetCells()[1].height
snapshot.cells[1].y = -999; snapshot.cells[1].weights[1].weight = -1
assert(map:GetCells()[1].height == sourceHeight and map:GetCells()[1].biomeWeights[1].weight >= 0)
-- 注入当前测试注册器，确认入口复用它，而不是另建系统或 LuaEnv。
package.loaded.Main = registry
local generate = require('Game.Map.GenerateRenderMap')
local again = generate(20260921, '1,2,3,4,1,2,3,4')
assert(#again.cells == #snapshot.cells and again.cells[1].y == sourceHeight)
for _, bad in ipairs({'', '1,,2', '1,', '1;2', '1,-2', 'unknown'}) do
    assert(not pcall(generate, 1, bad), 'Invalid recipe was accepted: ' .. bad)
end
package.loaded.Main = nil
registry:Shutdown()
assert(again.cells[1].y == sourceHeight)
print(string.format('PASS render snapshot: %d cells, %d water cells, %d towns, %d buildings; indices, detached data, shared runtime and bad inputs',
    #again.cells, wet, #again.towns, #again.buildings))
print(string.format('PASS water snapshot: %d real river cells, %d lake cells, %d flow targets, %d river bank cells; six-cell river/lake/flow/depth/ownership fixture',
    riverCells, lakeCells, directedCells, bankCells))
