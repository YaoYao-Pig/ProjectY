-- v8 使用真实占地脊谷网络；旧存档继续调用原 v7 公式。
local Class=require('Core.Class')
local Legacy=require('Game.Map.HighMountainLegacy')
local Network=require('Game.Map.MountainRidgeNetwork')
local Convert=Class('HighMountainRegionConvertV8',Legacy.Convert)
function Convert:PrepareRegion(config,region,random,footprint,q,r)
    if region.generationVersion>=8 then Network.Prepare(config,region,random,footprint,q,r) end
end
function Convert:GetHeight(config,q,r,random,noiseScale,region)
    if region.generationVersion>=8 then return Network.Height(region,q,r) end
    return Legacy.Convert.GetHeight(self,config,q,r,random,noiseScale,region)
end
function Convert:GetLandform(config,cell,random,noiseScale,region)
    if region.generationVersion>=8 then return Network.Landform(region,cell) end
    return Legacy.Convert.GetLandform(self,config,cell,random,noiseScale,region)
end
-- Preserve the foothill support plane when blending a neighboring deep basin.
function Convert:GetBlendFloor(config,region)
    if region.generationVersion>=8 then return config.minHeight end
end
return {Convert=Convert,Instance=Legacy.Instance}
