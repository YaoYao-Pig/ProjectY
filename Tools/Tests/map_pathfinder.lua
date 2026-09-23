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

-- 净距和路径代价是两种契约；用直接枚举对照距离树，并覆盖地图缺格及距离截断。
local sources={start,goal,(map:GetCell(0,-2))}
for i,cell in ipairs(map.cells) do if i%2==0 then sources[#sources+1]=cell end end
local direct=finder:HexDistances(sources,2)
for _,cell in ipairs(map.cells) do
    local expected=2
    for _,source in ipairs(sources) do expected=math.min(expected,HexGrid.Distance(cell.q,cell.r,source.q,source.r)) end
    assert(direct[cell]==expected)
end
local costs=finder:Distances({start},cost,20)
assert(costs[goal]==total and costs[start]==0)
assert(next(finder:HexDistances({},20))==nil)
local split=Map(1,1)
for _,q in ipairs({0,2}) do
    local cell={q=q,r=0};split.cells[#split.cells+1]=cell;split.cellsByKey[HexGrid.Key(q,0)]=cell
end
local isolated=Pathfinder(split)
assert(isolated:HexDistances({split.cells[1]},10)[split.cells[2]]==2)
assert(isolated:Distances({split.cells[1]},function() return 1 end,10)[split.cells[2]]==nil)
print('Map distance fields: exact hex distance across gaps, truncation, absent sources and terrain path costs passed')
