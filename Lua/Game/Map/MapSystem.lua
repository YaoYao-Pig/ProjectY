-- 地图系统依赖 Config，仅持有生成器；生成结果的生命周期由调用方管理。
local Class = require('Core.Class')
local System = require('Core.LuaSystem')
local MapSystem = Class('MapSystem', System)
function MapSystem:OnInit(context)
    System.OnInit(self, context)
    local config = context.systems:Get('Config')
    self.generator = require('Game.Map.MapGenerator')(config)
    -- 新增地貌时在这里绑定对应的转换器和实例类。
    local types = config:GetEnum('Map', 'E_MapRegion')
    for _, name in ipairs({'Grassland', 'Mountain', 'Lake', 'River', 'Forest', 'Snow'}) do
        local strategy = require('Game.Map.' .. name .. 'Region')
        self.generator:RegisterRegion(types[name], strategy.Convert, strategy.Instance)
    end
    -- 新生态复用已有地貌形状策略，起伏、水文、地块和装饰各自由配表定义。
    for _, entry in ipairs({{'Swamp','Lake'}, {'DarkForest','Forest'}, {'Lava','Mountain'},
        {'Volcano','Mountain'}, {'Mushroom','Forest'}}) do
        local strategy = require('Game.Map.' .. entry[2] .. 'Region')
        self.generator:RegisterRegion(types[entry[1]], strategy.Convert, strategy.Instance)
    end
end
function MapSystem:Generate(seed, regionIds, targetCells, progress)
    return self.generator:Generate(seed, regionIds, targetCells, progress)
end
function MapSystem:GenerateSeeded(seed, targetCells, progress, regionIds)
    return self.generator:GenerateSeeded(seed, targetCells, progress, regionIds)
end
function MapSystem:OnShutdown() self.generator = nil end
return MapSystem
