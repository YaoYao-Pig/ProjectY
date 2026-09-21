-- 自然地貌的定向回归：检查真实地图的形状、策略差异、水体和边界契约。
package.path = 'Lua/?.lua;' .. package.path
local Class = require('Core.Class')
local Registry = require('Core.SystemRegistry')
local Generator = require('Game.Map.MapGenerator')
local Random = require('Game.Map.SeededRandom')
local tests = 0
local function test(name, callback)
    local ok, err = xpcall(callback, debug.traceback)
    assert(ok, name .. '\n' .. tostring(err)); tests = tests + 1; print('PASS ' .. name)
end
local registry = Registry({ ReadConfig = function(_, name)
    local file = assert(io.open('Assets/GameFramework/Resources/Config/' .. name .. '.bytes', 'rb'))
    local bytes = file:read('*a'); file:close(); return bytes
end, LogError = error })
registry:Register('Config', require('Config.ConfigSystem'))
registry:Register('Map', require('Game.Map.MapSystem'), {'Config'})
registry:Start()
local system, config = registry:Get('Map'), registry:Get('Config')

test('fractal and ridge noise are bounded, deterministic and independent of placement RNG', function()
    local random, other = Random(973), Random(973)
    for x = -5, 5 do
        local a = random:Fractal(x * 0.7, x * -1.3, 7, 0.5, 13)
        local b = random:Ridged(x * 0.7, x * -1.3, 7, 0.5, 13)
        assert(a >= 0 and a <= 1 and b >= 0 and b <= 1)
        assert(a == other:Fractal(x * 0.7, x * -1.3, 7, 0.5, 13))
        local near = random:Fractal(x * 0.7 + 0.0001, x * -1.3, 7, 0.5, 13)
        assert(math.abs(a - near) < 0.001)
    end
    assert(random.state == 973)
end)

test('organic footprints contain connected cells and leave corners outside their region', function()
    local map = system:Generate(20260921, {1, 2, 3, 4})
    for _, region in ipairs(map:GetRegions()) do
        assert(#region.cells < region.sizeX * region.sizeY * 0.85)
        assert(not region:Contains(region.originQ, region.originR))
        assert(region:Contains(region.centerQ, region.centerR))
        local queue, seen, head = { region.cells[1] }, { [region.cells[1]] = true }, 1
        while head <= #queue do
            local cell = queue[head]; head = head + 1
            for _, neighbor in ipairs(map:GetNeighbors(cell.q, cell.r)) do
                if neighbor.regionId == region.instanceId and not seen[neighbor] then
                    seen[neighbor] = true; queue[#queue + 1] = neighbor
                end
            end
        end
        assert(#queue == #region.cells)
    end
end)

test('mountains have more relief and lake and river strategies produce real wet cells', function()
    local function range(map)
        local minimum, maximum = math.huge, -math.huge
        for _, cell in ipairs(map.cells) do minimum = math.min(minimum, cell.height); maximum = math.max(maximum, cell.height) end
        return maximum - minimum
    end
    for _, seed in ipairs({1, 73, 20260921}) do
        assert(range(system:Generate(seed, {2})) > range(system:Generate(seed, {1})) * 1.5)
        for _, entry in ipairs({ {3, 'lake'}, {4, 'river'} }) do
            local map = system:Generate(seed, {entry[1]})
            assert(#map.waterBodies > 0)
            for _, body in ipairs(map.waterBodies) do assert(body.kind == entry[2]) end
        end
    end
end)

test('water surfaces are flat, held by their banks and share immutable cell identities', function()
    local map = system:Generate(73, {1, 3, 4, 2, 3, 4})
    local wet = 0
    for _, body in ipairs(map:GetWaterBodies()) do
        assert(#body.cells > 0)
        for _, cell in ipairs(body.cells) do
            wet = wet + 1
            assert(cell.waterBodyId == body.id and cell.waterLevel == body.level)
            assert(cell.waterDepth == cell.waterLevel - cell.height and cell.waterDepth > 0)
            assert(map:GetCell(cell.q, cell.r) == cell)
            for _, other in ipairs(map:GetNeighbors(cell.q, cell.r)) do
                -- 同一水体分组等高；相邻河段允许沿下游降低，由水系测试验证方向。
                if not other.waterLevel then assert(other.height >= body.level - 0.000001) end
            end
        end
    end
    assert(wet > 0)
    local ok = pcall(function() map.waterBodies[1].level = 100 end); assert(not ok)
end)

-- 用高度范围不相交的两块平面制造阶跃，防止按所属区截断后重新出现接缝。
test('border blending reduces a controlled height step and leaves region interiors intact', function()
    local base = require('Game.Map.MapRegionConvertBase')
    local Convert = Class('TerrainStepTestConvert', base)
    function Convert:GetHeight(row) return row.id == 1 and 1 or 11 end
    local row = config:GetTable('MapRegionTable'):Get(1)
    local rows = {}
    for i = 1, 2 do
        local item = {}; for key, value in pairs(row) do item[key] = value end
        item.id = i; item.minHeight = i == 1 and 0 or 10; item.maxHeight = i == 1 and 2 or 12; rows[i] = item
    end
    local width = 0
    local proxy = {
        GetEnum = function(_, ...) return config:GetEnum(...) end,
        GetConstant = function(_, module, name) return name == 'BorderBlendWidth' and width or config:GetConstant(module, name) end,
        GetTable = function(_, name)
            if name == 'MapTownTable' or name == 'MapWaterNetworkTable' or name == 'MapBiomeTable' then
                return { All = function() return {} end }
            end
            if name ~= 'MapRegionTable' then return config:GetTable(name) end
            return { All = function() return rows end, Get = function(_, id) return assert(rows[id]) end }
        end,
    }
    local function build()
        local gen = Generator(proxy)
        gen:RegisterRegion(1, Convert, require('Game.Map.MapRegionInstanceBase'))
        return gen:Generate(155, {1, 2})
    end
    local hard = build(); width = 4; local smooth = build()
    assert(#hard.cells == #smooth.cells and #smooth.borders > 0)
    local before, after, interior, outsideOwner = 0, 0, 0, false
    for _, border in ipairs(hard.borders) do for _, edge in ipairs(border.edges) do before = before + math.abs(edge.heightDelta) end end
    for _, border in ipairs(smooth.borders) do for _, edge in ipairs(border.edges) do after = after + math.abs(edge.heightDelta) end end
    assert(after < before * 0.35)
    for _, cell in ipairs(smooth.cells) do
        assert(cell.height >= 0 and cell.height <= 12)
        local owner = rows[smooth.regions[cell.regionId].configId]
        if cell.height < owner.minHeight or cell.height > owner.maxHeight then outsideOwner = true end
        if cell.blendAmount == 0 then assert(cell.height == cell.baseHeight); interior = interior + 1 end
        local sum = 0; for _, biome in ipairs(cell.biomeWeights) do sum = sum + biome.weight end
        assert(math.abs(sum - 1) < 0.000001)
    end
    assert(interior > 0 and outsideOwner)
end)

test('water strategies reject a level outside their terrain range before generation', function()
    for _, name in ipairs({'Lake', 'River'}) do
        local strategy = require('Game.Map.' .. name .. 'Region').Convert()
        assert(not pcall(function() strategy:ValidateConfig({minHeight = 0, maxHeight = 3, waterLevel = 3}) end))
    end
end)
registry:Shutdown()
print(string.format('Map terrain: %d tests passed', tests))
