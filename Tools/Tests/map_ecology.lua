-- 新生态须进入真实显示快照及旅行战场；不创建运行时 Data，不写玩家存档。
package.path = 'Lua/?.lua;' .. package.path
local registry = require('Core.SystemRegistry')({ReadConfig = function(_, name)
    local file = assert(io.open('Assets/GameFramework/Resources/_Gen/Config/' .. name .. '.bytes', 'rb'))
    local bytes = file:read('*a'); file:close(); return bytes
end, LogError = error})
registry:Register('Config', require('Config.ConfigSystem'))
registry:Register('Map', require('Game.Map.MapSystem'), {'Config'}); registry:Start()
local config = registry:Get('Config')
local map = registry:Get('Map'):GenerateSeeded(42, 2500)
local used, dry, sources, travel = {}, {}, {}, {}
for _, row in ipairs(config:GetTable('WorldTravelTerrainTable'):All()) do travel[row.regionType] = row end
for _, cell in ipairs(map.cells) do
    used[cell.terrainAssetId] = true
    if not cell.waterLevel then
        local region = map:GetRegion(cell.regionId)
        dry[region.regionType] = (dry[region.regionType] or 0) + 1
        sources[region.regionType] = {regionId=region.instanceId,regionConfigId=region.configId,
            regionType=region.regionType,q=cell.q,r=cell.r,height=cell.height,biomeWeights=cell.biomeWeights}
    end
end
for _, item in ipairs(map.decorations) do used[item.assetId] = true end
local snapshot = require('Game.Map.MapRenderSnapshot')(map)
local snapshotAssets = {}; for _, row in ipairs(snapshot.assets) do snapshotAssets[row.id] = row end
local variants, decorations = 0, 0
for kind = 7, 11 do
    local biome = config:GetTable('MapBiomeTable'):Get(kind)
    assert(dry[kind] and dry[kind] >= 50, 'New ecology disappeared under water: ' .. kind)
    assert(#biome.terrainVariantAssetIds == 3, 'New ecology lost its terrain variants')
    for _, id in ipairs(biome.terrainVariantAssetIds) do
        assert(used[id] and snapshotAssets[id], 'Terrain model is configured but absent from the real snapshot: ' .. id)
        assert(snapshotAssets[id].tintMaterial == '', 'Authored terrain palette must be preserved')
        variants = variants + 1
    end
    for _, id in ipairs(biome.decorationAssetIds) do
        assert(used[id] and snapshotAssets[id], 'Ecology decoration is absent from the real snapshot: ' .. id)
        decorations = decorations + 1
    end
    assert(travel[kind] and travel[kind].costMultiplier > 0, 'New ecology cannot be traversed')
    print('PASS ecology ' .. kind .. ': ' .. dry[kind] .. ' dry cells, all terrain variants and decorations rendered')
end
assert(variants == 15 and decorations == 21)
-- 边界混合也会读取相邻生态的主题，所以每种局部地图都必须有完整主题覆盖。
for _, name in ipairs({'MapAreaThemeTable','MapAreaTownThemeTable','MapAreaForestThemeTable',
    'MapAreaBattlefieldThemeTable','MapAreaShipwreckThemeTable','MapAreaMineThemeTable'}) do
    local kinds = {}; for _, row in ipairs(config:GetTable(name):All()) do kinds[row.regionType] = true end
    for _, row in ipairs(config:GetTable('MapRegionTable'):All()) do assert(kinds[row.MapRegion], name .. ' lacks biome ' .. row.MapRegion) end
end
local areaGenerator = require('Game.MapArea.MapAreaGenerator')(config)
areaGenerator:Register(config:GetEnum('MapArea','E_MapAreaType').Battlefield,
    require('Game.MapArea.BattlefieldGenerator'),'MapAreaBattlefieldTable','MapAreaBattlefieldThemeTable')
for kind = 7, 11 do
    local source, terrain = sources[kind], travel[kind]
    source.encounterId = 1; source.obstacleChance = terrain.battleObstacleChance
    source.surfaceId = terrain.battleSurfaceId; source.propIds = terrain.battlePropIds
    local area = areaGenerator:Generate(30, 42, kind, source)
    assert(#area.cells > 0 and area.cells[area.entryIndex].surfaceId == terrain.battleSurfaceId)
    for _, prop in ipairs(area.props) do config:GetTable('MapAssetTable'):Get(prop.assetId) end
end
registry:Shutdown()
print('PASS five ecology battlefields, six complete area theme sets, 15 terrain variants and 21 decorations')
return snapshot
