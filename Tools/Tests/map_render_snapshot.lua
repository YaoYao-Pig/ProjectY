-- 只验证新增的 Unity 渲染适配层：真实配表、索引身份、水位及快照所有权。
package.path = 'Lua/?.lua;' .. package.path
local registry = require('Core.SystemRegistry')({ ReadConfig = function(_, name)
    local file = assert(io.open('Assets/GameFramework/Resources/Config/' .. name .. '.bytes', 'rb'))
    local bytes = file:read('*a'); file:close(); return bytes
end, LogError = error })
registry:Register('Config', require('Config.ConfigSystem'))
registry:Register('Map', require('Game.Map.MapSystem'), {'Config'})
registry:Start()
local map = registry:Get('Map'):Generate(20260921, {1, 2, 3, 4, 1, 2, 3, 4})
local build = require('Game.Map.MapRenderSnapshot')
local snapshot = build(map)
assert(snapshot.hexRadius == map.hexRadius and snapshot.regionCount == #map:GetRegions())
assert(#snapshot.cells == #map:GetCells() and #snapshot.buildings == #map:GetBuildings())
local wet = 0
for i, row in ipairs(snapshot.cells) do
    local cell = map:GetCells()[i]
    local x, y, z = map:GetCellWorldPosition(cell.q, cell.r)
    assert(row.x == x and row.y == y and row.z == z)
    assert(row.hasWater == (cell.waterLevel ~= nil))
    assert(row.waterLevel == (cell.waterLevel or 0))
    if row.hasWater then assert(row.waterLevel > row.y); wet = wet + 1 end
    for j, weight in ipairs(row.weights) do
        assert(weight.regionType == cell.biomeWeights[j].regionType and weight.weight == cell.biomeWeights[j].weight)
    end
end
assert(wet > 0 and #snapshot.towns > 0 and #snapshot.roads > 0, 'Fixture must cover water, towns and roads')
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
