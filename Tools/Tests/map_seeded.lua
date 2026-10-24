-- 真实配置与开场静态生成链路；不启动 Editor/Play，不创建 Data 或写入存档。
package.path = 'Lua/?.lua;' .. package.path
local registry = require('Core.SystemRegistry')({ReadConfig = function(_, name)
    local file = assert(io.open('Assets/GameFramework/Resources/_Gen/Config/' .. name .. '.bytes', 'rb'))
    local bytes = file:read('*a'); file:close(); return bytes
end, LogError = error})
registry:Register('Config', require('Config.ConfigSystem'))
registry:Register('Map', require('Game.Map.MapSystem'), {'Config'}); registry:Start()
local config, system = registry:Get('Config'), registry:Get('Map')
local definitions = config:GetTable('MapAreaTable')
local areas = setmetatable({config = config, entrances = {}, generator = {definitions = definitions}},
    {__index = require('Game.MapArea.MapAreaSystem')})
for _, row in ipairs(config:GetTable('MapAreaEntranceTable'):All()) do areas.entrances[row.townId] = definitions:Get(row.areaId) end
local adventure = setmetatable({config = config, mapSystem = system, areas = areas,
    events = {events = config:GetTable('AdventureEventTable')},
    travel = {maxStep = config:GetTable('WorldTravelTable'):Get(1).maxHeightStep},
    data = {Phase = 'map'}, parties = {data = {}}, camp = {data = {}}, shop = {data = {}},
    narrative = {data = {}}, equipment = {worldLoot = {session = {}}}},
    {__index = require('Game.Adventure.AdventureSystem')})
local Hex = require('Game.Map.HexGrid')
local function inspect(world, target)
    local map = world.map
    assert(world.recipe.id == 5 and world.recipe.seededRegions and map.generationVersion == 6)
    assert(#map.cells == target and map.targetCells == target)
    local counts, ids = {}, {}
    for _, region in ipairs(map.regions) do
        counts[region.configId] = (counts[region.configId] or 0) + #region.cells
        ids[#ids + 1] = region.configId
        local reached, queue, head = {[region.cells[1]] = true}, {region.cells[1]}, 1
        while head <= #queue do
            local cell = queue[head]; head = head + 1
            for _, nextCell in ipairs(map:GetNeighbors(cell.q, cell.r)) do
                if nextCell.regionId == region.instanceId and not reached[nextCell] then
                    reached[nextCell] = true; queue[#queue + 1] = nextCell
                end
            end
        end
        assert(#queue == #region.cells, 'Coverage crop disconnected a region')
    end
    for _, row in ipairs(config:GetTable('MapRegionTable'):All()) do
        assert(counts[row.id] and counts[row.id] >= 100, 'Missing or unrecognizably small terrain: ' .. row.id)
    end
    local reached, queue, head = {[map.cells[1]] = true}, {map.cells[1]}, 1
    while head <= #queue do
        local cell = queue[head]; head = head + 1
        for _, nextCell in ipairs(map:GetNeighbors(cell.q, cell.r)) do
            if not reached[nextCell] then reached[nextCell] = true; queue[#queue + 1] = nextCell end
        end
    end
    assert(#queue == target, 'Coverage crop disconnected the world')
    local market
    for _, site in ipairs(world.sites) do if site.areaConfigId == world.recipe.startAreaId then market = site; break end end
    assert(market, 'Shuffled world lost the story market')
    local camp = map:GetCell(world.sites[1].q, world.sites[1].r)
    assert(not camp.waterLevel and Hex.Distance(camp.q, camp.r, market.q, market.r) == 1)
    assert(math.abs(camp.height - map:GetCell(market.q, market.r).height) <= adventure.travel.maxStep)
    print('PASS seed ' .. map.seed .. ', ' .. target .. ' cells, region order ' .. table.concat(ids, ','))
    return table.concat(ids, ',')
end
local orders = {}
for _, seed in ipairs({0, 1234, 0xffffffff}) do
    local world = adventure:BuildWorld(seed, 5, 2500)
    orders[inspect(world, 2500)] = true
end
local orderCount = 0; for _ in pairs(orders) do orderCount = orderCount + 1 end
assert(orderCount > 1, 'Different seeds kept the same region order')
local large = adventure:BuildWorld(42, 5, 10000)
inspect(large, 10000)
local poolSize = config:GetTable('MapRegionTable').Count
for first = 1, #large.map.regions, poolSize do
    local seen = {}
    for i = first, math.min(first + poolSize - 1, #large.map.regions) do
        local id = large.map.regions[i].configId
        assert(not seen[id], 'A round repeated a terrain before exhausting the pool'); seen[id] = true
    end
end
local Creation = require('Game.Adventure.CampaignCreation')
local job = Creation.New(adventure, '42', 2500)
local previous, snapshot = 0, nil
while true do
    local done, value = Creation.Step(job)
    if done then snapshot = value; break end
    assert(value >= previous and value < 1); previous = value
end
assert(job.ready and not job.committed and job.recipeId == job.world.recipe.id and snapshot.generationVersion == 6)
inspect(job.world, 2500)
local old = adventure:BuildWorld(0, 3, 2500)
assert(not old.recipe.seededRegions and old.map.generationVersion == 5)
for i, region in ipairs(old.map.regions) do
    assert(region.configId == old.recipe.regionIds[(i - 1) % #old.recipe.regionIds + 1], 'Legacy recipe order changed')
end
local legacySeeded = adventure:BuildWorld(42, 4, 2500)
assert(#legacySeeded.recipe.regionIds == 6 and legacySeeded.map.generationVersion == 6)
for _, region in ipairs(legacySeeded.map.regions) do assert(region.configId <= 6, 'Legacy seeded campaign acquired new terrain') end
registry:Shutdown()
print('Seeded campaign coverage, topology, market access, loading preparation and legacy recipe checks passed')
