-- 地貌转换器基类：统一抽取尺寸、生成连通轮廓并贴边摆放，子类只负责地形采样。
local Class = require('Core.Class')
local Footprint = require('Game.Map.RegionFootprint')
local Convert = Class('MapRegionConvertBase')
-- 非水体策略不增加额外约束；特殊策略可以在完整配方执行前校验自己的参数。
function Convert:ValidateConfig(config) end
-- 返回裸地高度、可选水位和水体类型；水体在全图过渡完成后统一整理。
function Convert:GetHeight(config, q, r, random, noiseScale, region)
    error('MapRegionConvertBase.GetHeight must be implemented')
end
-- map1 是生成期草稿；追加当前区域后返回同一草稿，供后续区域继续累积。
-- MapGenerator 会在全部区域完成后冻结结果，再交给业务代码。
function Convert:Generate(map1, config, random, instanceType)
    local sizeX = random:Integer(math.ceil(config.minX), math.floor(config.maxX))
    local sizeY = random:Integer(math.ceil(config.minY), math.floor(config.maxY))
    -- 先限制采样包围盒，再分配轮廓，避免极端输入在容量校验前耗尽资源。
    assert(sizeX * sizeY <= map1.cellLimit * 2, 'Map region sampling area exceeds MaxCells budget')
    local footprint = Footprint.Create(sizeX, sizeY, random, (#map1.map.regions + 1) * 3571, config.shapeIrregularity)
    local q, r, placed = map1:FindPlacement(footprint, random)
    map1:CheckCapacity(#placed.cells)
    map1:AddRegion(config, q, r, sizeX, sizeY, instanceType, placed, self)
    return map1
end
return Convert
