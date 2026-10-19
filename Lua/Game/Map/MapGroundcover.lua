-- 纯显示用草花与虫群锚点；只使用位置噪声，不推进地图随机流或改写格子布局。
local Random = require('Game.Map.SeededRandom')
local Groundcover = {}

function Groundcover.Build(map)
    map.groundcover = {}
    local profiles = {}
    for _, row in ipairs(map.biomes) do profiles[row.id] = row end
    if next(profiles) == nil then return end
    assert(map.hexRadius > 0, 'Groundcover requires a positive hex radius')
    local radius, random = map.hexRadius, Random(map.seed ~ 0x6b216f39)
    local trees = {}
    for _, asset in ipairs(map.assets) do
        if asset.previewShape == 'tree' or asset.previewShape == 'conifer' or asset.previewShape == 'snowpine' then trees[asset.id] = true end
    end
    local function add(cell, kind, slot, centerX, centerZ, underTree)
        local channel = 28103 + slot * 113 + kind * 37
        local angle = random:Noise(cell.q, cell.r, 1, channel) * math.pi * 2
        local spread = math.sqrt(random:Noise(cell.q, cell.r, 1, channel + 11))
        local x, z = centerX + math.cos(angle) * spread * .24, centerZ + math.sin(angle) * spread * .24
        if kind == 2 then x, z = x * .48, z * .48 end
        if underTree then x, z = math.cos(angle) * (.34 + spread * .18), math.sin(angle) * (.34 + spread * .18) end
        map.groundcover[#map.groundcover + 1] = { cell = cell, kind = kind,
            offsetX = x * radius, offsetZ = z * radius,
            scale = .72 + random:Noise(cell.q, cell.r, 1, channel + 23) * .48,
            yaw = random:Noise(cell.q, cell.r, 1, channel + 43) * 360,
            phase = random:Noise(cell.q, cell.r, 1, channel + 61) * math.pi * 2 }
    end
    for _, cell in ipairs(map.cells) do
        if not cell.waterLevel and not cell.buildingId and not cell.townId and #cell.roadIds == 0 then
            local underTree, blocked = false, false
            if cell.decorationId then
                local decoration = assert(map.decorations[cell.decorationId], 'Missing groundcover obstacle decoration')
                underTree = trees[decoration.assetId] == true
                blocked = not underTree
            end
            if not blocked then
                local slope = 0
                for _, other in ipairs(map:GetNeighbors(cell.q, cell.r)) do slope = math.max(slope, math.abs(cell.height - other.height)) end
                if slope <= radius * .9 then
                    local grass, shrub, butterfly, gnat = 0, 0, 0, 0
                    for _, weight in ipairs(cell.biomeWeights) do
                        local row = assert(profiles[weight.regionType], 'Missing groundcover biome profile')
                        grass = grass + row.groundcoverDensity * weight.weight
                        shrub = shrub + row.shrubDensity * weight.weight
                        butterfly = butterfly + row.butterflyDensity * weight.weight
                        gnat = gnat + row.gnatDensity * weight.weight
                    end
                    -- 大片疏密加逐格采样，保留真正空白；簇内共享偏移中心，各植株位置分别采样。
                    local patch = math.max(0, math.min(1, (random:Noise(cell.q, cell.r, 7, 27011) - .30) / .5))
                    local centerAngle = random:Noise(cell.q, cell.r, 1, 27031) * math.pi * 2
                    local centerRadius = random:Noise(cell.q, cell.r, 1, 27059) * .26
                    local centerX, centerZ = math.cos(centerAngle) * centerRadius, math.sin(centerAngle) * centerRadius
                    local hasShrub = not underTree and slope <= radius * .6 and random:Noise(cell.q, cell.r, 1, 27077) < shrub * patch
                    if hasShrub then add(cell, 2, 1, centerX, centerZ, false) end
                    for slot = 1, underTree and 1 or 3 do
                        local density = grass * patch * (underTree and .25 or slot == 1 and 1 or slot == 2 and .36 or .14)
                        if not (slot == 1 and hasShrub) and random:Noise(cell.q, cell.r, 1, 27101 + slot * 43) < density then
                            local flower = not underTree and butterfly > 0 and slope <= radius * .6
                                and random:Noise(cell.q, cell.r, 1, 27311 + slot * 67) < .22
                            add(cell, flower and 3 or 1, slot, centerX, centerZ, underTree)
                        end
                    end
                    if not underTree and patch > .25 then
                        local roll = random:Noise(cell.q, cell.r, 1, 27581)
                        local kind = roll < butterfly * patch and 4 or roll < (butterfly + gnat) * patch and 5 or nil
                        if kind then add(cell, kind, 4, centerX, centerZ, false) end
                    end
                end
            end
        end
    end
end
return Groundcover
