-- 一个区域实例的布局信息；instanceId 区分实例，configId 指向配表记录。
local Class = require('Core.Class')
local HexGrid = require('Game.Map.HexGrid')
local Region = Class('MapRegionInstanceBase')
function Region:ctor(instanceId, config, q, r, sizeX, sizeY, enemyConfigs, buildingConfigs)
    self.instanceId = instanceId; self.configId = config.id; self.regionType = config.MapRegion
    self.originQ = q; self.originR = r; self.sizeX = sizeX; self.sizeY = sizeY
    self.cells = {}; self.cellsByKey = {}; self.neighborIds = {}; self.borders = {}
    self.enemyConfigs = enemyConfigs; self.buildingConfigs = buildingConfigs
    self.towns = {}; self.buildings = {}
end
-- 不规则轮廓以实际格子索引判定，包围盒内的空白不属于本区域。
function Region:Contains(q, r)
    HexGrid.CheckCoordinate(q, r)
    return self.cellsByKey[HexGrid.Key(q, r)] ~= nil
end
function Region:GetCells() return self.cells end
function Region:GetNeighborIds() return self.neighborIds end
function Region:GetBorders() return self.borders end
-- 返回适用于本区域的只读配置候选，不代表已经生成的可变玩法实体。
function Region:GetEnemyConfigs() return self.enemyConfigs end
function Region:GetBuildingConfigs() return self.buildingConfigs end
-- 实际生成的只读布局与候选配置分开查询。
function Region:GetTowns() return self.towns end
function Region:GetBuildings() return self.buildings end
return Region
