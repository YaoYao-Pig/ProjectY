-- 精确格数、末区连通、重生成所有权及旧调用兼容；只用真实配置与工程生成器。
package.path = 'Lua/?.lua;' .. package.path
local Hex = require('Game.Map.HexGrid')
local registry = require('Core.SystemRegistry')({ReadConfig = function(_, name)
    local file = assert(io.open('Assets/GameFramework/Resources/_Gen/Config/' .. name .. '.bytes', 'rb'))
    local bytes = file:read('*a'); file:close(); return bytes
end, LogError = error})
registry:Register('Config', require('Config.ConfigSystem'))
registry:Register('Map', require('Game.Map.MapSystem'), {'Config'}); registry:Start()
local system = registry:Get('Map')
for _, target in ipairs({1, 2, 37, 700}) do
    local map = system:Generate(20260921, {1, 2}, target)
    assert(#map.cells == target and map.targetCells == target)
    local queue, seen, head = {map.cells[1]}, {[map.cells[1]]=true}, 1
    while head <= #queue do
        local cell = queue[head]; head = head + 1
        for direction = 1, 6 do
            local q, r = Hex.Neighbor(cell.q, cell.r, direction)
            local other = map:FindCell(q, r)
            if other and not seen[other] then seen[other]=true; queue[#queue+1]=other end
        end
    end
    assert(#queue == target, 'Final budget crop broke global connectivity')
    assert(not pcall(function() map.cells[1].height = -99 end), 'Snapshot must remain immutable')
    local again = system:Generate(20260921, {1, 2}, target)
    for i, cell in ipairs(map.cells) do
        local other = again.cells[i]
        assert(cell.q == other.q and cell.r == other.r and cell.height == other.height and cell.waterLevel == other.waterLevel)
    end
    assert(system.generator.infrastructure.selection.map == nil, 'Generation caches retained a draft')
end
for _, bad in ipairs({0, -1, 1.5, 100001, '10000'}) do assert(not pcall(system.Generate, system, 1, {1}, bad)) end
local old = system:Generate(20260921, {1, 2})
assert(#old.regions == 2 and old.targetCells == nil, 'Omitted target must keep the one-pass recipe')
package.loaded.Main = registry
local settings = require('Game.Map.MapPreviewSettings')()
assert(settings.defaultCells == 10000 and settings.maxCells == 100000)
local snapshot = require('Game.Map.GenerateRenderMap')(20260921, '1,2', 37)
assert(#snapshot.cells == 37, 'Unity entry must pass the same exact cell budget')
registry:Shutdown()
print('Map size: exact budgets, connectivity, determinism, read-only ownership, input errors and Unity entry passed')
