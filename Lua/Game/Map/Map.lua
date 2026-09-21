-- 地图布局与查询接口。生成器完成后整体冻结，玩法状态由其他系统持有。
local Class = require('Core.Class')
local HexGrid = require('Game.Map.HexGrid')
local Map = Class('Map')
function Map:ctor(seed, radius)
    self.seed = seed; self.hexRadius = radius; self.generationVersion = 4
    self.cells = {}; self.cellsByKey = {}; self.regions = {}; self.regionsByType = {}
    self.borders = {}; self.bordersByPair = {}; self.waterBodies = {}
    self.towns = {}; self.buildings = {}; self.roads = {}; self.roadNetworks = {}
    self.rivers = {}; self.waterfalls = {}; self.decorations = {}; self.assets = {}; self.biomes = {}
end
function Map:GetCells() return self.cells end
function Map:GetRegions() return self.regions end
function Map:GetBorders() return self.borders end
-- 静态连通水体列表；格子 height 始终表示地面，waterLevel 单独表示水面。
function Map:GetWaterBodies() return self.waterBodies end
function Map:GetRivers() return self.rivers end
function Map:GetWaterfalls() return self.waterfalls end
function Map:GetDecorations() return self.decorations end
-- 生成期的静态占地与道路布局；不代表玩法实体或运行时通行规则。
function Map:GetTowns() return self.towns end
function Map:GetBuildings() return self.buildings end
function Map:GetRoads() return self.roads end
function Map:GetRoadNetworks() return self.roadNetworks end
-- Find 查询允许未命中并返回 nil；对应的 Get 查询要求目标存在。
function Map:FindCell(q, r)
    HexGrid.CheckCoordinate(q, r)
    return self.cellsByKey[HexGrid.Key(q, r)]
end
function Map:GetCell(q, r) return assert(self:FindCell(q, r), 'Cell is outside this map') end
function Map:FindCellAtWorld(x, z)
    local q, r = HexGrid.FromWorld(x, z, self.hexRadius)
    return self:FindCell(q, r)
end
-- 使用格子真实高度返回顶面中心，不包含预览中的高度放大。
function Map:GetCellWorldPosition(q, r)
    local cell = self:GetCell(q, r)
    return HexGrid.ToWorld(q, r, cell.height, self.hexRadius)
end
function Map:GetRegion(instanceId)
    return assert(self.regions[instanceId], 'Unknown region instance: ' .. tostring(instanceId))
end
-- 已知类型可以返回空列表；未注册的类型属于调用错误。
function Map:GetRegionsByType(regionType)
    return assert(self.regionsByType[regionType], 'Unknown region type: ' .. tostring(regionType))
end
-- 按 HexGrid 方向顺序返回实际存在的邻居，每次查询创建独立结果列表。
function Map:GetNeighbors(q, r)
    self:GetCell(q, r)
    local result = {}
    for direction = 1, 6 do
        local nq, nr = HexGrid.Neighbor(q, r, direction)
        local cell = self:FindCell(nq, nr)
        if cell then result[#result + 1] = cell end
    end
    return result
end
-- 边界按区域实例对查询，入参顺序无关；不相邻时返回 nil。
function Map:FindBorder(a, b)
    self:GetRegion(a); self:GetRegion(b)
    a, b = math.tointeger(a), math.tointeger(b)
    return self.bordersByPair[math.min(a, b) .. ':' .. math.max(a, b)]
end
return Map
