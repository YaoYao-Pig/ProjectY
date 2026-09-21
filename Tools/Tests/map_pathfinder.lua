-- 生成期路径搜索的定向检查：验证绕路、不可达、最小代价和稳定性。
package.path = 'Lua/?.lua;' .. package.path
local Map = require('Game.Map.Map')
local HexGrid = require('Game.Map.HexGrid')
local Pathfinder = require('Game.Map.MapPathfinder')
local map = Map(1, 1)
for r = -2, 2 do
    for q = -2, 2 do
        local cell = { q = q, r = r }
        map.cells[#map.cells + 1] = cell; map.cellsByKey[HexGrid.Key(q, r)] = cell
    end
end
local finder = Pathfinder(map)
local start, goal = map:GetCell(-2, 0), map:GetCell(2, 0)
local function cost(_, target)
    -- 中心格禁行，上方一带代价高；搜索必须发现从下方经过的最便宜路径。
    if target.q == 0 and target.r == 0 then return nil end
    return target.r < 0 and 10 or 1
end
local path, total = finder:FindPath(start, goal, cost)
assert(path[1] == start and path[#path] == goal and total == 5)
for i = 2, #path do
    assert(HexGrid.Distance(path[i-1].q, path[i-1].r, path[i].q, path[i].r) == 1)
    assert(cost(path[i-1], path[i]) == 1)
end
local repeated = finder:FindPath(start, goal, cost)
for i, cell in ipairs(path) do assert(repeated[i] == cell) end
assert(finder:FindPath(start, goal, function() return nil end) == nil)
local single, zero = finder:FindPath(start, start, cost)
assert(#single == 1 and single[1] == start and zero == 0)
assert(not pcall(function() finder:FindPath(start, goal, function() return 0 end) end))
assert(not pcall(function() finder:FindPath({}, goal, cost) end))
print('Map pathfinder: shortest detour, stable ties, unreachable and invalid input passed')
