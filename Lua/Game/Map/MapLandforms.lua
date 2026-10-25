-- 生成期地貌通行与入口候选；独立于玩家探索状态，所有候选均保留原格子身份。
local Terrain = require('Game.Map.TerrainNoise')
local Landforms = {}

function Landforms.Build(map, sources, random, noiseScale)
    for _, source in ipairs(sources) do
        local convert, region = source.convert, source.region
        if convert.GetLandform then
            for _, cell in ipairs(region.cells) do
                local kind, zone, relief, blocked = convert:GetLandform(source.config, cell, random, noiseScale, region)
                cell.landformType, cell.landformZone, cell.worldTravelBlocked = kind, zone, blocked
                if kind == 'HighMountain' then cell.mountainElevation = relief else cell.canyonDepth = relief end
            end
        end
        -- 高度采样与地貌标记已经完成，冻结结果只保留脊谷描述和最终格子数据。
        region._mountainField=nil
    end
end

-- 设施与多格奇观布局可能占用山脚；只在这些布局完成后发布最终候选。
function Landforms.BuildEntrances(map)
    for _, cell in ipairs(map.cells) do
        if cell.landformType and not cell.worldTravelBlocked and not cell.waterLevel
            and not cell.buildingId and not cell.wonderId then
            local access, feature = false, false
            for _, other in ipairs(map:GetNeighbors(cell.q, cell.r)) do
                if not other.worldTravelBlocked and not other.waterLevel and math.abs(cell.height - other.height) <= map.hexRadius * 1.2 then access = true end
                if other.regionId == cell.regionId and other.worldTravelBlocked then feature = true end
            end
            if access and feature then cell.landformEntrance = cell.landformType end
        end
    end
end

function Landforms.Color(cell, rgb)
    if cell.canyonDepth then
        local darkness = Terrain.Smooth(.015, .72, cell.canyonDepth)
        local bottom = {.028, .034, .047}
        for i = 1, 3 do rgb[i] = rgb[i] * (1 - darkness) + bottom[i] * darkness end
    elseif cell.mountainElevation then
        local snow = Terrain.Smooth(.62, .91, cell.mountainElevation)
        local summit = {.88, .92, .95}
        for i = 1, 3 do rgb[i] = rgb[i] * (1 - snow) + summit[i] * snow end
    end
end

return Landforms
