-- 城镇与道路的最小回归：占地、坡度、水域绕行、网络断开与快照对象身份。
package.path = 'Lua/?.lua;' .. package.path
local Registry = require('Core.SystemRegistry')
local Hex = require('Game.Map.HexGrid')
local Map = require('Game.Map.Map')
local Infrastructure = require('Game.Map.MapInfrastructure')
local Pathfinder = require('Game.Map.MapPathfinder')
local registry = Registry({ ReadConfig = function(_, name)
    local file = assert(io.open('Assets/GameFramework/Resources/Config/' .. name .. '.bytes', 'rb'))
    local bytes = file:read('*a'); file:close(); return bytes
end, LogError = error })
registry:Register('Config', require('Config.ConfigSystem'))
registry:Register('Map', require('Game.Map.MapSystem'), {'Config'}); registry:Start()
local config = registry:Get('Config')
local function has(items, value) for _, item in ipairs(items) do if item == value then return true end end end
for _, seed in ipairs({20260921, 73}) do
    local map = registry:Get('Map'):Generate(seed, {1, 2, 3, 4, 1, 2, 3, 4})
    assert(#map:GetTowns() > 1 and #map:GetBuildings() > 0 and #map:GetRoads() > 0)
    local occupied, mainRoads = {}, 0
    for _, town in ipairs(map:GetTowns()) do
        local row = config:GetTable('MapTownTable'):Get(town.configId)
        assert(#town.buildings >= row.minBuildings and #town.buildings <= row.maxBuildings)
        assert(not town.center.waterLevel and not town.center.buildingId)
        assert(has(map:GetRegion(town.regionId):GetTowns(), town))
        assert(has(map.roadNetworks[town.roadNetworkId].townIds, town.id))
        for _, other in ipairs(map.towns) do
            if other.id ~= town.id then assert(Hex.Distance(town.center.q, town.center.r, other.center.q, other.center.r) >= math.max(town.minSpacing, other.minSpacing, town.radius + other.radius + 1)) end
        end
    end
    for _, building in ipairs(map:GetBuildings()) do
        local row = config:GetTable('MapBuildingTable'):Get(building.configId)
        local town = map.towns[building.townId]
        local townRow = config:GetTable('MapTownTable'):Get(town.configId)
        local minimum, maximum = math.huge, -math.huge
        assert(has(town.buildings, building) and has(map:GetRegion(building.regionId):GetBuildings(), building))
        assert(#building.cells == 1 + 3 * row.footprintRadius * (row.footprintRadius + 1))
        for _, cell in ipairs(building.cells) do
            assert(not occupied[cell] and not cell.waterLevel and #cell.roadIds == 0)
            assert(map:GetCell(cell.q, cell.r) == cell and cell.buildingId == building.id and cell.townId == town.id)
            assert(has(row.regions, map:GetRegion(cell.regionId).regionType))
            occupied[cell] = true; minimum = math.min(minimum, cell.height); maximum = math.max(maximum, cell.height)
        end
        assert(building.baseHeight == maximum and maximum - minimum <= townRow.maxGroundDelta)
        assert(not building.entrance.buildingId and #building.entrance.roadIds > 0)
        assert(math.abs(building.entrance.height - building.baseHeight) <= config:GetConstant('Map', 'RoadMaxStep'))
    end
    for _, road in ipairs(map:GetRoads()) do
        assert(road.cells[1] == map.towns[road.townA].center)
        if road.kind == 'road' then
            mainRoads = mainRoads + 1
            assert(road.cells[#road.cells] == map.towns[road.townB].center)
            assert(map.towns[road.townA].roadNetworkId == map.towns[road.townB].roadNetworkId)
        else assert(road.cells[#road.cells] == map.buildings[road.buildingId].entrance) end
        for i, cell in ipairs(road.cells) do
            assert(not cell.waterLevel and not cell.buildingId and has(cell.roadIds, road.id))
            if i > 1 then
                local before = road.cells[i-1]
                assert(Hex.Distance(cell.q, cell.r, before.q, before.r) == 1)
                assert(math.abs(cell.height - before.height) <= config:GetConstant('Map', 'RoadMaxStep'))
            end
        end
    end
    assert(mainRoads == #map.towns - #map.roadNetworks)
    assert(not pcall(function() map.buildings[1].baseHeight = 0 end))
    assert(not pcall(function() map.towns[1].buildings[1].cells[1].height = 0 end))
end
print('PASS real towns have valid dry plots, reachable entrances, immutable identities and continuous roads')

-- 全宽障碍将地图分为两岸；任何一种障碍都不能被直线道路或隐式桥梁穿越。
local infrastructure = Infrastructure(config, { [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true })
for _, barrier in ipairs({'water', 'cliff', 'building'}) do
    local map = Map(1, 1)
    for r = -2, 2 do for q = 0, 8 do
        local cell = { q = q, r = r, height = 0, roadIds = {} }
        if q == 4 then
            if barrier == 'water' then cell.waterLevel = 1
            elseif barrier == 'cliff' then cell.height = 100
            else cell.buildingId = 1 end
        end
        map.cells[#map.cells + 1] = cell; map.cellsByKey[Hex.Key(q, r)] = cell
    end end
    for i, point in ipairs({{1, 0}, {2, 1}, {7, 0}}) do
        map.towns[i] = { id = i, center = map:GetCell(point[1], point[2]), roadIds = {} }
    end
    infrastructure:ConnectTowns(map, Pathfinder(map))
    assert(#map.roadNetworks == 2 and #map.roads == 1)
    assert(map.towns[1].roadNetworkId == map.towns[2].roadNetworkId)
    assert(map.towns[1].roadNetworkId ~= map.towns[3].roadNetworkId)
end
print('PASS water, cliffs and building barriers leave explicitly disconnected road networks')
registry:Shutdown()
