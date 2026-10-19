-- 美术展示夹具，非随机生成地图：六种地貌同框，表现数据全部来自真实配表和 MapVisuals。
-- python -B Tools/Tests/run_lua.py Tools/Rendering/export_map_ground_preview.lua
package.path = 'Lua/?.lua;Tools/MapPreview/?.lua;' .. package.path
local config = require('Config.ConfigSystem')()
config:OnInit({services = {ReadConfig = function(_, name)
    local file = assert(io.open('Assets/GameFramework/Resources/_Gen/Config/' .. name .. '.bytes', 'rb'))
    local bytes = file:read('*a'); file:close(); return bytes
end}})
local Map, HexGrid = require('Game.Map.Map'), require('Game.Map.HexGrid')
local regionTypes = {}
for _, value in pairs(config:GetEnum('Map', 'E_MapRegion')) do regionTypes[value] = true end
local visuals = require('Game.Map.MapVisuals')(config, regionTypes)
local types = {{1, 2, 6}, {3, 4, 5}}
local function fixture(seed)
    local map = Map(seed, 1)
    for kind = 1, 6 do map.regions[kind] = {instanceId = kind, regionType = kind} end
    for q = -9, 8 do for r = -8, 7 do
        local column = math.floor((q + 9) / 6) + 1
        local row = r < 0 and 1 or 2
        local kind = types[row][column]
        local weights = {{regionType = kind, weight = 1}}
        local adjacent
        if q == -4 or q == 2 then adjacent = types[row][column + 1]
        elseif q == -3 or q == 3 then adjacent = types[row][column - 1] end
        if adjacent then weights[1].weight = .65; weights[2] = {regionType = adjacent, weight = .35} end
        if r == -1 or r == 0 then
            for _, weight in ipairs(weights) do weight.weight = weight.weight * .7 end
            weights[#weights + 1] = {regionType = types[3 - row][column], weight = .3}
        end
        local cell = {q = q, r = r, regionId = kind,
            height = .13 + math.sin(q * .26) * .08 + math.cos(r * .31) * .045,
            roadIds = {}, biomeWeights = weights}
        map.cells[#map.cells + 1] = cell; map.cellsByKey[HexGrid.Key(q, r)] = cell
        -- 七格连通湖面，用于观察岸边材质与草本避让；不调用或替换生产水文算法。
        if math.max(math.abs(q + 5), math.abs(r - 3), math.abs(q + r + 2)) <= 1 then
            cell.height = -.23; cell.waterLevel = .055; cell.waterDepth = .285; cell.waterKind = 'lake'
        end
    end end
    local road = {kind = 'road', cells = {}}
    for q = -4, 4 do
        local cell = map:GetCell(q, -3); cell.roadIds = {1}; road.cells[#road.cells + 1] = cell
    end
    map.roads[1] = road
    -- 内部顺序包含原树石散布、MapDressing 和 MapGroundcover.Build。
    visuals:Build(map)
    return map
end

local selected, counts, attempts
for attempt = 1, 8 do
    local map = fixture(20261011 + attempt - 1)
    local kinds = {0, 0, 0, 0, 0}
    for _, item in ipairs(map.groundcover) do kinds[item.kind] = kinds[item.kind] + 1 end
    local complete = true
    for kind = 1, 5 do if kinds[kind] == 0 then complete = false end end
    if complete then selected, counts, attempts = map, kinds, attempt; break end
end
assert(selected, 'Eight bounded fixture seeds did not cover all five ecological kinds')
local output = require('Game.Map.MapRenderSnapshot')(selected)
local json = require('json')
local arrays = {cells = true, buildings = true, roads = true, towns = true, assets = true,
    decorations = true, waterfalls = true, rivers = true, surfaces = true, groundcover = true,
    neighbors = true, weights = true, groundColor = true}
local function markArrays(value, key)
    if type(value) ~= 'table' then return end
    if arrays[key] then json.array(value) end
    for childKey, child in pairs(value) do markArrays(child, childKey) end
end
markArrays(output)
local path = 'Docs/Previews/Rendering/map-ground-layout.json'
local file = assert(io.open(path, 'wb')); file:write(json.encode(output)); file:close()
print(string.format('EXPORTED ART FIXTURE (not a generated world): %s; seed=%d attempts=%d cells=%d surfaces=%d decorations=%d',
    path, selected.seed, attempts, #output.cells, #output.surfaces, #output.decorations))
print(string.format('Groundcover: grass=%d shrubs=%d flowers=%d butterflies=%d gnats=%d', counts[1], counts[2], counts[3], counts[4], counts[5]))
