-- V5 定向夹具：真实配表驱动，验证地牢净距、高山平台、水岸悬崖及地形决定河湖形态。
package.path='Lua/?.lua;'..package.path
local Map=require('Game.Map.Map')
local Hex=require('Game.Map.HexGrid')
local Pathfinder=require('Game.Map.MapPathfinder')
local Selection=require('Game.Map.MapSiteSelection')
local Hydrology=require('Game.Map.MapHydrology')
local Random=require('Game.Map.SeededRandom')
local registry=require('Core.SystemRegistry')({ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local data=file:read('*a');file:close();return data
end,LogError=error})
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('Map',require('Game.Map.MapSystem'),{'Config'});registry:Start()
local config=registry:Get('Config')
local function grid(radius,height)
    local map=Map(20260921,1)
    map.regions[1]={instanceId=1,configId=1,regionType=1,cells={}}
    for r=-radius,radius do for q=-radius,radius do
        local cell={q=q,r=r,height=height(q,r),regionId=1,roadIds={},regionWeights={{regionId=1,weight=1}}}
        map.cells[#map.cells+1]=cell;map.cellsByKey[Hex.Key(q,r)]=cell;map.regions[1].cells[#map.regions[1].cells+1]=cell
    end end
    return map
end
local function proxyTable(name,rows)
    return setmetatable({GetTable=function(_,key)
        if key==name then return {All=function() return rows end,Get=function(_,id)
            for _,row in ipairs(rows) do if row.id==id then return row end end;error('Missing fixture row')
        end} end
        return config:GetTable(key)
    end},{__index=function(_,key) return function(_,...) return config[key](config,...) end end})
end
local function copy(row) local out={};for k,v in pairs(row) do out[k]=v end;return out end

-- 紧邻水面的悬崖不算方便取水；高山台地仍然允许城市方案，高度是独立指标。
local plateau=grid(6,function(q) return q<0 and 0 or 10 end)
for _,cell in ipairs(plateau.cells) do if cell.q<0 then cell.waterLevel=1 end end
local selection=Selection(config);selection:Begin(plateau,Pathfinder(plateau));selection:RefreshCivilization(128)
local high=config:GetTable('MapSiteProfileTable'):Get(202)
local terrain,water=selection:Analyze(high)
local cliff=selection:Metrics(plateau:GetCell(0,0),high,terrain,water)
assert(cliff.waterClearance==1 and cliff.waterAccessDistance==high.distanceCap,'Cliff water should be inaccessible for siting')
local metrics=selection:Metrics(plateau:GetCell(4,0),high,terrain,water)
assert(selection:Evaluate(high,metrics),'Buildable highland plateau must remain eligible')
metrics.height=2;local score,reason=selection:Evaluate(high,metrics)
assert(not score and reason=='height','Highland profile must read its height hard range')
print('PASS highland plateau and cliff shore access are evaluated independently')

-- 完整占地必须远离道路；改表可改变这一规则，不在建筑 ID 或算法中硬编码地牢距离。
local remote=grid(14,function() return 2 end)
for _,cell in ipairs(remote.cells) do if cell.q==0 then cell.roadIds={1} end end
local site=Selection(config);site:Begin(remote,Pathfinder(remote));site:RefreshCivilization(128)
local profile=config:GetTable('MapSiteProfileTable'):Get(401)
local land,wet=site:Analyze(profile)
local plans={{cells={remote:GetCell(7,0),(remote:GetCell(8,0))},entrance=remote:GetCell(9,0)}}
assert(not site:CheckPlans(plans,profile,land,wet),'Footprint edge must obey road clearance')
plans[1].cells={(remote:GetCell(8,0))};assert(site:CheckPlans(plans,profile,land,wet))
local rules={};for _,rule in ipairs(config:GetTable('MapSiteRuleTable'):All()) do
    local row=copy(rule);if row.profileId==401 and row.metric=='roadDistance' then row.hardRange={10,48} end;rules[#rules+1]=row
end
local stricter=Selection(proxyTable('MapSiteRuleTable',rules));stricter:Begin(remote,Pathfinder(remote));stricter:RefreshCivilization(128)
local land2,wet2=stricter:Analyze(profile)
assert(not stricter:CheckPlans(plans,profile,land2,wet2),'Changed table must change placement eligibility')
print('PASS full footprint and entrance obey data-driven remoteness')

-- 带岛屿和缺口的真实盆地：保留高地岛，不将同一区域整块涂成圆湖。
local basin=grid(7,function(q,r)
    local span=Hex.Distance(0,0,q,r)
    if span>5 then return 0 end
    if span>=4 then return 6 end
    if q==0 and r==0 then return 7 end
    return 1+.08*(q+3)+.06*(r+3)
end)
basin.regions[1].configId=3
local row=copy(config:GetTable('MapWaterNetworkTable'):Get(1));row.maxRivers=0;row.maxLakes=1
local hydro=Hydrology(proxyTable('MapWaterNetworkTable',{row}));hydro:Build(basin)
assert(not basin:GetCell(0,0).waterLevel and basin:GetCell(1,0).waterLevel,'Basin must preserve its island')
assert(not basin:GetCell(6,0).waterLevel,'Lake must stop at its natural bank')
for _,cell in ipairs(basin.cells) do if cell.waterLevel then
    for _,other in ipairs(basin:GetNeighbors(cell.q,cell.r)) do assert(other.waterLevel or other.height>=cell.waterLevel) end
end end
local flat=grid(7,function() return 1 end);flat.regions[1].configId=3;hydro:Build(flat)
assert(#flat.waterBodies==0,'A lake-friendly profile cannot flood terrain without a basin')
print('PASS true basins, dry islands and banks determine lake extent')

-- 相同汇水量的平缓河段应更宽；陡坡会收窄，开挖始终受岸边高度预算限制。
local function width(drop)
    local map=grid(5,function() return 5 end)
    local a,b=map:GetCell(0,0),map:GetCell(1,0)
    a.height=4.45;a.waterLevel=5;a.waterKind='river';a.flowTo=b;a.flowAccumulation=600
    b.height=4.45-drop;b.waterLevel=5-drop;b.waterKind='river';b.flowAccumulation=600
    map.rivers={{id=1,cells={a}}}
    local waterSystem=Hydrology(config);local random=Random(13);waterSystem:Parameters(map,random)
    waterSystem:Widen(map,Pathfinder(map),random)
    local count=0;for _,cell in ipairs(map.cells) do if cell.channelBank then count=count+1;assert(5-cell.height<=row.bankCarveDepth) end end
    return count
end
assert(width(0)>width(2),'Steep river reach should be narrower at equal accumulation')
print('PASS equal flow widens on flat land and contracts on steep terrain')

-- 最后检查实际配方：偏远地点不参与道路，并逐格核对与所有道路/城镇实体的最短六边形距离。
local map=registry:Get('Map'):Generate(20260921,{1,2,3,4,5,6,1,4,5,6})
local remoteCount=0
local occupied={}
for _,town in ipairs(map.towns) do if town.role=='settlement' then
    occupied[#occupied+1]=town.center
    for _,building in ipairs(town.buildings) do for _,cell in ipairs(building.cells) do occupied[#occupied+1]=cell end end
end end
for _,road in ipairs(map.roads) do if road.kind=='street' then for _,cell in ipairs(road.cells) do occupied[#occupied+1]=cell end end end
for _,town in ipairs(map.towns) do if town.role=='remote' then
    remoteCount=remoteCount+1;assert(not town.roadNetworkId and #town.roadIds==0)
    for _,building in ipairs(town.buildings) do
        local cells={building.entrance};for _,cell in ipairs(building.cells) do cells[#cells+1]=cell end
        for _,cell in ipairs(cells) do
            for _,road in ipairs(map.roads) do for _,other in ipairs(road.cells) do
                assert(Hex.Distance(cell.q,cell.r,other.q,other.r)>=8,'Remote site too close to road')
            end end
            for _,other in ipairs(occupied) do assert(Hex.Distance(cell.q,cell.r,other.q,other.r)>=12,'Remote site too close to settlement') end
        end
    end
end end
assert(remoteCount>0)
print('PASS actual remote sites are outside road networks and away from all settlement footprints')
registry:Shutdown()
