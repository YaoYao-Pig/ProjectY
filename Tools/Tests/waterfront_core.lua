-- 真实配表的码头选址、城内水岸与一对客运港口定向检查；无需 Editor / Play / C# Data。
-- 执行：python -B Tools/Tests/run_lua.py Tools/Tests/waterfront_core.lua
package.path='Lua/?.lua;'..package.path
local registry=require('Core.SystemRegistry')({ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local data=file:read('*a');file:close();return data
end,LogError=error})
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('Map',require('Game.Map.MapSystem'),{'Config'});registry:Start()
local config,mapSystem=registry:Get('Config'),registry:Get('Map')
local Hex=require('Game.Map.HexGrid')
local Geometry=require('Game.MapArea.DungeonGeometry')
local Squad=require('Game.MapArea.SquadMovement')
local Docks=require('Game.Map.MapDocks')
local settings=config:GetTable('DockSettingsTable'):Get(1)

-- 小型选址反例单独覆盖浅水、孤立水格和无法步行接近的悬崖，不靠随机种子碰巧命中。
local fixtureConfig={GetTable=function(_,name)
    return {Get=function()return name=='DockSettingsTable' and settings or {maxHeightStep=1}end}
end}
local function fixture(mode)
    local map=require('Game.Map.Map')(42,1);map.generationVersion=9
    for r=-4,4 do for q=-4,7 do
        local wet=q>=4;if mode=='isolated' then wet=q==4 and r==0 end
        local cell={q=q,r=r,height=wet and 0 or 1,roadIds={},waterAssetId=7}
        if wet then
            cell.waterLevel=1;cell.waterDepth=mode=='shallow' and settings.minWaterDepth/2 or 1;cell.waterKind='river'
        end
        if mode=='cliff' and q==3 then cell.height=10 end
        map.cells[#map.cells+1]=cell;map.cellsByKey[Hex.Key(q,r)]=cell
    end end
    map.towns[1]={id=1,role='settlement',center=map:GetCell(0,0)}
    Docks.Build(map,fixtureConfig);return map
end
local first,second=fixture('valid'),fixture('valid')
assert(#first.docks==1 and #second.docks==1)
for _,key in ipairs({'landQ','landR','waterQ','waterR','direction','initialDamaged','initialThreat'}) do
    assert(first.docks[1][key]==second.docks[1][key],'Dock selection must be deterministic: '..key)
end
for _,mode in ipairs({'shallow','isolated','cliff'}) do assert(#fixture(mode).docks==0,'Invalid dock accepted: '..mode) end
print('PASS deterministic dock selection / shallow water / isolated water / inaccessible cliff')

local seed=20261025
local map=mapSystem:GenerateSeeded(seed,10000,nil,nil,10)
local legacy=mapSystem:GenerateSeeded(seed,10000,nil,nil,8)
assert(#legacy.docks==0 and #legacy.cells==#map.cells and #legacy.towns==#map.towns)
for i,cell in ipairs(legacy.cells) do local other=map.cells[i]
    assert(cell.q==other.q and cell.r==other.r and cell.height==other.height and cell.waterLevel==other.waterLevel
        and cell.buildingId==other.buildingId,'Docks changed the previous terrain or building random stream')
end
for i,town in ipairs(legacy.towns) do
    assert(town.center.q==map.towns[i].center.q and town.center.r==map.towns[i].center.r)
end
for _,dock in ipairs(map.docks) do
    local land,water=map:GetCell(dock.landQ,dock.landR),map:GetCell(dock.waterQ,dock.waterR)
    assert(not land.waterLevel and water.waterLevel and water.waterDepth>=settings.minWaterDepth)
    assert(Hex.Distance(land.q,land.r,water.q,water.r)==1 and map.towns[dock.townId].dock==dock)
    assert(dock.approachCells[1]==map.towns[dock.townId].center and dock.approachCells[#dock.approachCells]==land)
    for i=2,#dock.approachCells do local a,b=dock.approachCells[i-1],dock.approachCells[i]
        assert(not b.waterLevel and not b.buildingId and not b.worldTravelBlocked and Hex.Distance(a.q,a.r,b.q,b.r)==1)
        assert(math.abs(a.height-b.height)<=config:GetTable('WorldTravelTable'):Get(1).maxHeightStep)
    end
    assert(not pcall(function()dock.initialDamaged=not dock.initialDamaged end),'Dock layouts must be read-only')
end
print('PASS v8/v10 terrain and city compatibility / real dock banks and access paths')

local generator=require('Game.MapArea.MapAreaGenerator')(config)
generator:Register(2,require('Game.MapArea.TownGenerator'),'MapAreaTownTable','MapAreaTownThemeTable')
local definitions=config:GetTable('MapAreaTable')
local entrances=setmetatable({config=config,entrances={},generator={definitions=definitions}},
    {__index=require('Game.MapArea.MapAreaSystem')})
for _,row in ipairs(config:GetTable('MapAreaEntranceTable'):All()) do entrances.entrances[row.townId]=definitions:Get(row.areaId) end
local ports={}
local recipe=config:GetTable('AdventureDemoTable'):Get(5)
for index,site in ipairs(entrances:Entrances(map)) do
    if site.source.dock then
        site.id=1+#recipe.wildEventIds+index;ports[site.source.dock.id]=site
    end
end
local function inspectTown(area)
    local front,dock=assert(area.waterfront),assert(area.dock)
    assert(front.npcId>0 and #dock.waterCells>=dock.internalWaterCount)
    local shore=assert(dock.shoreline,'v10 town needs a full-side shoreline')
    local slices,waterSet={},{}
    local shallow,deep,shallowCount,deepCount=0,0,0,0
    local minDepth,maxDepth=math.huge,-math.huge
    for _,cell in ipairs(area.cells) do if cell.layer==0 then
        local q,r=Geometry.Rotate(cell.q-shore.centerQ,cell.r-shore.centerR,-shore.turn)
        local along=q+r/2;local slice=slices[r] or {water=0,cells={}};slices[r]=slice
        slice.cells[#slice.cells+1]={along=along,water=cell.waterLevel~=nil}
        assert((cell.waterLevel~=nil)==(along>shore.curve[r]),'Water must occupy the entire outward side of its shoreline')
        if cell.waterLevel then
            waterSet[cell.index]=true;slice.water=slice.water+1
            minDepth=math.min(minDepth,cell.waterDepth);maxDepth=math.max(maxDepth,cell.waterDepth)
            local distance=along-shore.curve[r]
            if distance<=2 then shallow=shallow+cell.waterDepth;shallowCount=shallowCount+1
            elseif distance>=6 then deep=deep+cell.waterDepth;deepCount=deepCount+1 end
        end
    end end
    for r=shore.cityMin,shore.cityMax do assert(slices[r] and slices[r].water>0,'Waterfront does not span the full city width: '..r) end
    for _,slice in pairs(slices) do
        table.sort(slice.cells,function(a,b)return a.along<b.along end)
        local entered=false
        for _,point in ipairs(slice.cells) do
            assert(not entered or point.water,'A land wall or island interrupts outward water')
            entered=entered or point.water
        end
    end
    local queue,seen,head={dock.waterCells[1]},{[dock.waterCells[1]]=true},1
    while head<=#queue do local cell=area.cells[queue[head]];head=head+1
        for direction=1,6 do local q,r=Hex.Neighbor(cell.q,cell.r,direction);local other=area:Find(q,r)
            if other and waterSet[other.index] and not seen[other.index] then seen[other.index]=true;queue[#queue+1]=other.index end
        end
    end
    assert(#queue==#dock.waterCells,'Full-side water must form one continuous body')
    assert(shallowCount>0 and deepCount>0 and shallow/shallowCount<deep/deepCount and minDepth<.9 and maxDepth>=3,
        'The shore requires a visible shallow-to-deep transition')
    local minBank,maxBank=math.huge,-math.huge
    for _,index in ipairs(shore.bankCells) do local cell=area.cells[index]
        assert(not cell.waterLevel);minBank=math.min(minBank,cell.height);maxBank=math.max(maxBank,cell.height)
    end
    assert(maxBank-minBank>.45,'Land bank must retain natural height variation')
    local curvature=0
    for r=shore.cityMin+1,shore.cityMax-1 do
        curvature=math.max(curvature,math.abs(shore.curve[r-1]-2*shore.curve[r]+shore.curve[r+1]))
    end
    assert(curvature>.1,'Shoreline must not be a straight artificial edge')
    for _,prop in ipairs(area.props) do if not prop.dockId then
        for _,index in ipairs(prop.cells) do assert(not area.cells[index].waterLevel,'Water submerged a neighboring building or prop') end
    end end
    assert(#Geometry.Reachable(area,area.entryIndex)==area.walkableCount,'Waterfront disconnected public space')
    assert(area:FindPath(area.entryIndex,dock.deckIndex),'Shared intact deck must be walkable')
    for _,cell in ipairs(area.cells) do
        if cell.waterLevel then assert(cell.blocked and cell.walkMask==0 and cell.height<cell.waterLevel and cell.renderGround==false) end
        if not cell.blocked then for _,nextCell in ipairs(area:Neighbors(cell)) do assert(area:CanStep(nextCell,cell),'One-way waterfront edge') end end
    end
    for _,facility in ipairs(area.facilities) do assert(area:FindPath(area.entryIndex,facility.entryIndex)) end
    for _,patch in ipairs(area.floorBoundaryPatches) do
        assert(not area.cells[patch.ownerIndex].waterLevel,'Water cells must not own ground boundary patches')
    end
    local worker=area.cells[dock.workerIndex];assert(worker.layer==0 and not worker.blocked,'Worker must stand on dry bank')
    local occupied={};for _,npc in ipairs(area.npcs) do occupied[npc.spawnIndex]=true end
    assert(not occupied[dock.deckIndex],'Worker must leave the shared deck clear')
    assert(#Squad.Deploy(area,front.landingIndex,4,function(cell)return not occupied[cell.index]end)==4)
    local positions=Squad.Deploy(area,area.entryIndex,4)
    local path=assert(area:FindPath(area.entryIndex,front.landingIndex))
    local frames,reason=Squad.Plan(area,positions,path,function()return true end);assert(frames,reason)
    print('PASS full-side waterfront: water='..#dock.waterCells..', internal='..dock.internalWaterCount..', crossSections='..
        (shore.cityMax-shore.cityMin+1)..', bankRelief='..string.format('%.2f',maxBank-minBank)..', depth='..string.format('%.2f..%.2f',minDepth,maxDepth))
end

-- 固定验收世界只生成这两座真实普通城，不遍历全部城市或已知有独立规划问题的王城。
local a,b=assert(ports[2]),assert(ports[3])
assert(a.areaConfigId==2 and b.areaConfigId==2)
local navigation=require('Game.Adventure.WaterNavigation').New(map,settings)
local paths=require('Game.Map.MapPathfinder')(map)
local from,to=a.source.dock,b.source.dock
local route=assert(paths:FindPath(map:GetCell(from.waterQ,from.waterR),map:GetCell(to.waterQ,to.waterR),
    function(x,y)return navigation:Cost(x,y)end),'Reference ports must share a navigable water route')
assert(#route>1 and navigation:Bank(map:GetCell(from.landQ,from.landR),route[1])
    and navigation:Bank(map:GetCell(to.landQ,to.landR),route[#route]))
for _,site in ipairs({a,b}) do
    inspectTown(generator:Generate(site.areaConfigId,seed,site.pointId,site.source))
    print('PASS reference port: seed='..seed..', dockId='..site.source.dock.id..', pointId='..site.pointId..', siteId='..site.id)
end
print('PASS real ferry route: '..(#route-1)..' water edges')

-- 普通城/王城各保留一个曾验证的方向样本，验证共用水岸实现而非扩大世界压力测试。
for _,id in ipairs({2,6}) do
    local source={regionId=7,regionType=1,regionConfigId=1,q=0,r=0,height=1,biomeWeights={{regionType=1,weight=1}},generationVersion=10,
        dock={id=11,townId=11,shoreDirection=1,landHeight=1,waterLevel=.6,waterDepth=1,waterKind='river',waterAssetId=from.waterAssetId}}
    inspectTown(generator:Generate(id,20260924,11,source))
    print('PASS ordinary/royal shared waterfront and occupied-bank squad landing: area='..id)
    if id==2 then
        source.generationVersion=9
        local old=generator:Generate(id,20260924,11,source)
        assert(old.generationVersion==3 and not old.dock.shoreline and #old.dock.waterCells==45,'v9 city must retain its saved waterfront indices')
        print('PASS v9 saved narrow-bay layout remains unchanged')
    end
end
registry:Shutdown()
