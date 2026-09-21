-- 地图最小回归：种子复现、六邻接连通、边界唯一、坐标查询、只读与非法输入。
package.path = 'Lua/?.lua;' .. package.path
local Class = require('Core.Class')
local Generator = require('Game.Map.MapGenerator')
local Grassland = require('Game.Map.GrasslandRegion')
local HexGrid = require('Game.Map.HexGrid')
local Random = require('Game.Map.SeededRandom')
local tests = 0
local function test(name, callback)
    local ok, err = xpcall(callback, debug.traceback)
    assert(ok, name .. '\n' .. tostring(err)); tests = tests + 1; print('PASS ' .. name)
end
local function throws(callback, pattern)
    local ok, err = pcall(callback); assert(not ok, 'Expected failure')
    if pattern then assert(tostring(err):find(pattern), tostring(err)) end
end
local function tableOf(rows)
    return { All = function() return rows end, Get = function(_, id)
        for _, row in ipairs(rows) do if row.id == id then return row end end
        error('Missing test config row: ' .. tostring(id))
    end }
end
-- 两种地貌的轻量配置夹具，验证扩展契约；末尾另用真实导出配置检查系统生命周期。
local function fixture()
    local config = { enums = { Grassland = 1, TestPlateau = 9 },
        constants = { HexRadius = 1.25, HeightNoiseScale = 5, MaxCells = 4096, BorderBlendWidth = 3, RoadMaxStep = 1.2, RoadSlopeCost = 4 },
        rows = {
            { id = 10, MapRegion = 1, minX = 2.2, maxX = 5.9, minY = 2, maxY = 5, minHeight = -1, maxHeight = 3 },
            { id = 20, MapRegion = 9, minX = 2, maxX = 4, minY = 2, maxY = 4, minHeight = 8, maxHeight = 8 },
        },
        enemies = { { id = 1, regions = { 1 } }, { id = 2, regions = { 9 } }, { id = 3, regions = {} } },
        buildings = { { id = 1, regions = { 1, 9 } } },
    }
    for _, row in ipairs(config.rows) do
        row.shapeIrregularity = 0.65; row.noiseScale = 1; row.roughness = 0.5; row.warpStrength = 0.7
        row.waterLevel = 0; row.riverWidth = 1.5; row.lakeSize = 0.5
    end
    function config:GetEnum(module, name) assert(module == 'Map' and name == 'E_MapRegion'); return self.enums end
    function config:GetConstant(module, name) assert(module == 'Map'); return assert(self.constants[name]) end
    function config:GetTable(name)
        return tableOf(assert(({ MapRegionTable = self.rows, MapEnemyTable = self.enemies, MapBuildingTable = self.buildings,
            MapTownTable = {}, MapAssetTable = {}, MapBiomeTable = {}, MapWaterNetworkTable = {} })[name]))
    end
    return config
end
local TestConvert = Class('TestPlateauConvert', require('Game.Map.MapRegionConvertBase'))
function TestConvert:GetHeight(config) return config.minHeight end
local TestInstance = Class('TestPlateauInstance', require('Game.Map.MapRegionInstanceBase'))
function TestInstance:IsTestPlateau() return true end
local function generator(config)
    local value = Generator(config)
    value:RegisterRegion(1, Grassland.Convert, Grassland.Instance)
    value:RegisterRegion(9, TestConvert, TestInstance)
    return value
end
local function signature(map)
    local entries = {}
    for _, cell in ipairs(map:GetCells()) do
        entries[#entries + 1] = string.format('%d,%d,%d,%.17g', cell.q, cell.r, cell.regionId, cell.height)
    end
    for _, border in ipairs(map:GetBorders()) do entries[#entries + 1] = border.regionA .. ':' .. border.regionB .. ':' .. #border.edges end
    return table.concat(entries, ';')
end
-- 确认局部随机序列可复现且不污染全局随机数。
test('seeded generation repeats exactly and leaves global RNG untouched', function()
    local random = Random(0); random:Integer(0, 1); assert(random.state == 1013904223)
    local gen = generator(fixture()); local recipe = {10, 20, 10, 10, 20, 10}
    math.randomseed(18); local a, b = math.random(), math.random()
    math.randomseed(18); assert(math.random() == a)
    local first = gen:Generate(20260921, recipe)
    assert(math.random() == b)
    assert(signature(first) == signature(gen:Generate(20260921, recipe)))
    assert(signature(first) ~= signature(gen:Generate(20260922, recipe)))
    assert(first.generationVersion == 4 and first.seed == 20260921)
    assert(#first:GetRegionsByType(1) == 4 and #first:GetRegionsByType(9) == 2)
    assert(first:GetRegion(2):IsTestPlateau())
    assert(first:GetRegion(1).configId == first:GetRegion(3).configId)
    assert(first:GetRegion(1).instanceId ~= first:GetRegion(3).instanceId)
end)
-- 从格子图反向验证唯一归属、高度范围和整图连通，而非复写摆放算法。
test('generated cells have unique ownership, bounded heights and a connected six-neighbor graph', function()
    local config = fixture(); local gen = generator(config)
    for _, seed in ipairs({0, 1, 7919, 0xffffffff}) do
        local map = gen:Generate(seed, {10, 10, 20, 10, 20, 10, 20, 10})
        local unique, expected, varying = {}, 0, false
        for _, region in ipairs(map:GetRegions()) do
            local row = config:GetTable('MapRegionTable'):Get(region.configId)
            assert(region.sizeX >= row.minX and region.sizeX <= row.maxX)
            assert(region.sizeY >= row.minY and region.sizeY <= row.maxY)
            expected = expected + #region:GetCells()
            assert(#region:GetCells() > 0 and #region:GetCells() <= region.sizeX * region.sizeY)
            for _, cell in ipairs(region:GetCells()) do
                assert(region:Contains(cell.q, cell.r) and cell.regionId == region.instanceId)
                assert(cell.baseHeight >= row.minHeight and cell.baseHeight <= row.maxHeight)
                assert(cell.height >= -1 and cell.height <= 8)
                if cell.height ~= region.cells[1].height then varying = true end
            end
        end
        assert(#map:GetCells() == expected and varying)
        for _, cell in ipairs(map:GetCells()) do
            local key = HexGrid.Key(cell.q, cell.r); assert(not unique[key]); unique[key] = true
            assert(map:GetCell(cell.q, cell.r) == cell)
        end
        local queue, seen, head = { map:GetCells()[1] }, {}, 1
        seen[HexGrid.Key(queue[1].q, queue[1].r)] = true
        while head <= #queue do
            local cell = queue[head]; head = head + 1
            for _, neighbor in ipairs(map:GetNeighbors(cell.q, cell.r)) do
                assert(HexGrid.Distance(cell.q, cell.r, neighbor.q, neighbor.r) == 1)
                local key = HexGrid.Key(neighbor.q, neighbor.r)
                if not seen[key] then seen[key] = true; queue[#queue + 1] = neighbor end
            end
        end
        assert(#queue == #map:GetCells())
    end
end)
-- 同地貌的独立实例仍有边界，每条实际共享边只能记录一次。
test('borders contain each shared edge exactly once including equal-type regions', function()
    local map = generator(fixture()):Generate(47, {10, 10, 10, 20, 20, 10})
    local expected, actual, sameType = {}, {}, false
    for _, cell in ipairs(map:GetCells()) do
        for _, other in ipairs(map:GetNeighbors(cell.q, cell.r)) do
            if cell.regionId < other.regionId then expected[HexGrid.Key(cell.q, cell.r) .. '/' .. HexGrid.Key(other.q, other.r)] = true end
        end
    end
    for _, border in ipairs(map:GetBorders()) do
        assert(map:FindBorder(border.regionA, border.regionB) == border)
        assert(map:FindBorder(border.regionB, border.regionA) == border)
        assert(map:FindBorder(border.regionA + 0.0, border.regionB + 0.0) == border)
        local a, b = map:GetRegion(border.regionA), map:GetRegion(border.regionB)
        if a.regionType == b.regionType then sameType = true end
        local function contains(items, item) for _, value in ipairs(items) do if value == item then return true end end end
        assert(contains(a:GetBorders(), border) and contains(b:GetBorders(), border))
        assert(contains(a:GetNeighborIds(), b.instanceId) and contains(b:GetNeighborIds(), a.instanceId))
        for _, edge in ipairs(border.edges) do
            local key = HexGrid.Key(edge.a.q, edge.a.r) .. '/' .. HexGrid.Key(edge.b.q, edge.b.r)
            assert(expected[key] and not actual[key]); actual[key] = true
            assert(edge.heightDelta == edge.b.height - edge.a.height)
        end
    end
    assert(sameType)
    for key in pairs(expected) do assert(actual[key]) end
end)
-- 包含负坐标和整数浮点输入，验证格子中心与世界坐标之间的往返查询。
test('hex world queries preserve negative coordinates and top-surface heights', function()
    for q = -12, 12 do for r = -12, 12 do
        local x, y, z = HexGrid.ToWorld(q, r, 2.5, 1.25)
        local aq, ar = HexGrid.FromWorld(x, z, 1.25)
        assert(aq == q and ar == r and y == 2.5)
    end end
    local map = generator(fixture()):Generate(90, {10, 20, 10, 10})
    for _, cell in ipairs(map:GetCells()) do
        local x, y, z = map:GetCellWorldPosition(cell.q, cell.r)
        assert(map:FindCellAtWorld(x, z) == cell and y == cell.height)
        assert(map:FindCellAtWorld(x + 0.01, z + 0.01) == cell)
    end
    assert(map:GetCell(0.0, 0.0) == map:GetCell(0, 0))
    assert(map:FindCell(100000, 100000) == nil)
    assert(map:FindCellAtWorld(100000, 100000) == nil)
    throws(function() map:GetCell(100000, 100000) end, 'outside')
    throws(function() map:FindCell(0.5, 1) end, 'integers')
end)
-- 验证枚举数组按地貌筛选候选，返回配置对象而非新建实体。
test('region candidates filter enum arrays without creating gameplay entities', function()
    local map = generator(fixture()):Generate(8, {10, 20})
    assert(#map:GetRegion(1):GetEnemyConfigs() == 1 and map:GetRegion(1):GetEnemyConfigs()[1].id == 1)
    assert(#map:GetRegion(2):GetEnemyConfigs() == 1 and map:GetRegion(2):GetEnemyConfigs()[1].id == 2)
    assert(map:GetRegion(1):GetBuildingConfigs()[1] == map:GetRegion(2):GetBuildingConfigs()[1])
    local onlyGrass = generator(fixture()):Generate(8, {10})
    assert(#onlyGrass:GetRegionsByType(9) == 0)
    throws(function() onlyGrass:GetRegionsByType(999) end, 'Unknown region type')
end)
-- 从各级索引尝试修改，验证深层只读和共享对象身份都保留。
test('layout indices, cells, region instances and borders are deeply read-only', function()
    local gen = generator(fixture()); local map = gen:Generate(42, {10, 10})
    local before = signature(map)
    for _, write in ipairs({
        function() map.seed = 0 end,
        function() map.cells[1] = {} end,
        function() map:GetCells()[1].height = 100 end,
        function() map:GetRegion(1).originQ = 100 end,
        function() map:GetRegion(1):GetNeighborIds()[1] = 99 end,
        function() map:GetRegion(1):GetBuildingConfigs()[1].regions[1] = 9 end,
        function() map:GetBorders()[1].edges[1].a.q = 99 end,
        function() map.cellsByKey['0:0'] = {} end,
        function() map:GetRegionsByType(1)[1] = {} end,
    }) do throws(write, 'read%-only') end
    local neighbors = map:GetNeighbors(0, 0); neighbors[1] = nil
    gen:Generate(99, {10}); assert(signature(map) == before)
end)
-- 非法输入在入口失败，避免产生不完整地图或隐式替代值。
test('invalid recipes, seeds, configuration and capacity fail at their boundary', function()
    local config = fixture(); local gen = generator(config)
    for _, seed in ipairs({ -1, 1.1, 4294967296, math.huge, '1' }) do throws(function() gen:Generate(seed, {10}) end, 'uint32') end
    throws(function() gen:Generate(0/0, {10}) end, 'uint32')
    throws(function() gen:Generate(1, {}) end, 'nonempty')
    throws(function() gen:Generate(1, {10, extra = 10}) end, 'dense array')
    throws(function() gen:Generate(1, {[1] = 10, [3] = 10}) end)
    throws(function() gen:Generate(1, {99}) end, 'Missing test config')
    throws(function() Generator(config):Generate(1, {10}) end, 'Missing converter')
    throws(function() gen:RegisterRegion(1, Grassland.Convert, Grassland.Instance) end, 'Duplicate')
    for _, mutate in ipairs({
        function(c) c.rows[1].minX = 6 end,
        function(c) c.rows[1].minX = 2.1; c.rows[1].maxX = 2.9 end,
        function(c) c.rows[1].minY = 0 end,
        function(c) c.rows[1].minHeight = 10 end,
        function(c) c.rows[1].maxHeight = math.huge end,
        function(c) c.constants.HeightNoiseScale = 0 end,
        function(c) c.constants.HexRadius = 0 end,
        function(c) c.constants.BorderBlendWidth = 1.5 end,
        function(c) c.rows[1].roughness = 2 end,
        function(c) c.rows[1].noiseScale = 0 end,
        function(c) c.enemies[1].regions = {999} end,
        function(c) c.enemies[1].regions = {1, 1} end,
    }) do local bad = fixture(); mutate(bad); throws(function() generator(bad) end) end
    local small = fixture(); small.constants.MaxCells = 6
    local limited = generator(small)
    throws(function() limited:Generate(1, {10, 20}) end, 'MaxCells')
    assert(#limited:Generate(1, {20}):GetCells() <= 6)
end)
-- 使用工程真实 ConfigSystem、二进制与注册流程验证集成链路。
test('actual exported configuration loads through Map system lifecycle', function()
    local Registry = require('Core.SystemRegistry')
    local registry = Registry({ ReadConfig = function(_, name)
        local file = assert(io.open('Assets/GameFramework/Resources/Config/' .. name .. '.bytes', 'rb'))
        local bytes = file:read('*a'); file:close(); return bytes
    end, LogError = error })
    registry:Register('Map', require('Game.Map.MapSystem'), {'Config'})
    registry:Register('Config', require('Config.ConfigSystem'))
    registry:Start()
    local map = registry:Get('Map'):Generate(20260921, {1, 1, 1, 1})
    assert(#map:GetRegions() == 4 and #map:GetCells() > 0)
    assert(map:GetRegion(1):GetBuildingConfigs()[1].name == '地牢入口')
    assert(#map:GetRegion(1):GetEnemyConfigs() == 0)
    registry:Shutdown(); assert(#map:GetCells() > 0)
    local registration = Registry({}); require('Game.Systems')(registration)
    assert(registration.definitions.Map.dependencies[1] == 'Config')
    assert(registration.definitions.PlayerModel.dependencies[1] == 'Config')
    assert(registration.definitions.UI.dependencies[1] == 'PlayerModel')
end)
-- 用单格区域覆盖高实例数的贴边摆放，并验证容量上限及时阻止继续生成。
test('many single-cell instances attach without overlap and stop at the cell budget', function()
    local config = fixture(); config.constants.MaxCells = 64
    config.rows[1].minX = 1; config.rows[1].maxX = 1
    config.rows[1].minY = 1; config.rows[1].maxY = 1
    local recipe = {}; for i = 1, 64 do recipe[i] = 10 end
    local gen = generator(config); local map = gen:Generate(15, recipe)
    assert(#map:GetCells() == 64 and #map:GetRegions() == 64)
    local seen, queue, head = {[1] = true}, {1}, 1
    while head <= #queue do
        local region = map:GetRegion(queue[head]); head = head + 1
        for _, neighbor in ipairs(region:GetNeighborIds()) do
            if not seen[neighbor] then seen[neighbor] = true; queue[#queue + 1] = neighbor end
        end
    end
    assert(#queue == 64)
    recipe[65] = 10; throws(function() gen:Generate(15, recipe) end, 'nonempty')
end)
print(string.format('Map: %d tests passed', tests))
