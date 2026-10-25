-- Real world/configuration entrance coverage plus the narrow first-entry inventory boundary.
-- No Editor, Play, native adventure state or save-file writes.
package.path='Lua/?.lua;'..package.path
local registry=require('Core.SystemRegistry')({ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end,LogError=error})
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('Map',require('Game.Map.MapSystem'),{'Config'});registry:Start()
local config,system=registry:Get('Config'),registry:Get('Map')
local AreaSystem=require('Game.MapArea.MapAreaSystem')
local definitions=config:GetTable('MapAreaTable')
local areas=setmetatable({config=config,entrances={},generator={definitions=definitions}},{__index=AreaSystem})
for _,row in ipairs(config:GetTable('MapAreaEntranceTable'):All()) do areas.entrances[row.townId]=definitions:Get(row.areaId) end
local adventure=setmetatable({config=config,mapSystem=system,areas=areas,
    events={events=config:GetTable('AdventureEventTable')},
    travel={maxStep=config:GetTable('WorldTravelTable'):Get(1).maxHeightStep},
    data={Phase='map'},parties={data={}},camp={data={}},shop={data={}},narrative={data={}},equipment={worldLoot={session={}}}},
    {__index=require('Game.Adventure.AdventureSystem')})
local Hex=require('Game.Map.HexGrid')
local Travel=require('Game.Adventure.WorldTravel')
local counts={HighMountain=0,Canyon=0,GiantTree=0};local canyonSite;local wonderCount=0
for _,seed in ipairs({42,43}) do
    local world=adventure:BuildWorld(seed,5,10000)
    local map=world.map;local camp=map:GetCell(world.sites[1].q,world.sites[1].r)
    assert(map.generationVersion==8 and #map:GetWonders()<=1,'Only one giant-tree wonder may exist per world')
    local travel=setmetatable({map=map,rule=config:GetTable('WorldTravelTable'):Get(1),terrains={},maxStep=adventure.travel.maxStep},{__index=Travel})
    for _,row in ipairs(config:GetTable('WorldTravelTerrainTable'):All()) do travel.terrains[row.regionType]=row end
    local paths=require('Game.Map.MapPathfinder')(map)
    local sitesByPoint={};local present={}
    for _,site in ipairs(world.sites) do if site.naturalKind then
        local cell=map:GetCell(site.q,site.r)
        assert(not cell.waterLevel and not cell.worldTravelBlocked and not cell.buildingId,'Natural entrance must be usable dry land')
        assert(not sitesByPoint[site.pointId],'Natural entrance identity was duplicated');sitesByPoint[site.pointId]=site
        assert(site.source.q==cell.q and site.source.r==cell.r and site.source.height==cell.height)
        assert(site.source.regionType==map:GetRegion(cell.regionId).regionType and site.source.biomeWeights==cell.biomeWeights)
        local route=assert(paths:FindPath(camp,cell,function(a,b)return travel:Cost(a,b)end),'Natural entrance is disconnected from the real camp')
        for i=2,#route do assert(not route[i].worldTravelBlocked and travel:Cost(route[i-1],route[i])) end
        counts[site.naturalKind]=counts[site.naturalKind]+1;present[site.naturalKind]=true
        if site.naturalKind=='Canyon' then
            assert(site.areaConfigId==71 and site.entryItemId==82 and site.entryItemCount==1)
            assert(cell.landformEntrance=='Canyon' and cell.landformZone=='canyonRim')
            canyonSite=site
        elseif site.naturalKind=='HighMountain' then
            assert(site.areaConfigId==70 and site.entryItemId==0 and cell.landformEntrance=='HighMountain')
        else assert(site.naturalKind=='GiantTree' and site.areaConfigId==72 and site.entryItemId==0) end
    end end
    for _,wonder in ipairs(map:GetWonders()) do
        wonderCount=wonderCount+1
        local row=config:GetTable('MapWonderTable'):Get(wonder.configId)
        local asset=config:GetTable('MapAssetTable'):Get(row.assetId)
        assert(row.assetId==1106 and row.maxCount==1 and row.footprintRadius==9 and asset.footprintRadius==9)
        local radius=row.footprintRadius;assert(#wonder.cells==1+3*radius*(radius+1),'Giant-tree footprint is incomplete')
        local occupied={};local low,high=math.huge,-math.huge
        for _,cell in ipairs(wonder.cells) do
            assert(not occupied[cell] and Hex.Distance(cell.q,cell.r,wonder.cell.q,wonder.cell.r)<=radius)
            occupied[cell]=true;low=math.min(low,cell.height);high=math.max(high,cell.height)
            assert(cell.wonderId==wonder.id and cell.worldTravelBlocked and not cell.waterLevel and not cell.buildingId and #cell.roadIds==0)
            for _,other in ipairs(map:GetNeighbors(cell.q,cell.r)) do
                assert(travel:Cost(other,cell)==nil and travel:Cost(cell,other)==nil,'World travel crossed the giant root footprint')
            end
        end
        assert(high-low<=row.maxGroundDelta and not occupied[wonder.entrance])
        assert(Hex.Distance(wonder.entrance.q,wonder.entrance.r,wonder.cell.q,wonder.cell.r)==radius+1)
        local decoration=map.decorations[wonder.decorationId]
        local variant=false;for _,id in ipairs(row.variantAssetIds) do if id==decoration.assetId then variant=true end end
        assert(decoration.wonder and variant and decoration.height==low-row.rootEmbed)
        local distance=paths:Distances({camp},function(a,b)return travel:Cost(a,b) and 1 end,math.huge)
        local reachable=false
        for _,entry in ipairs(wonder.entrances) do
            assert(not occupied[entry] and Hex.Distance(entry.q,entry.r,wonder.cell.q,wonder.cell.r)==radius+1)
            if distance[entry] then reachable=true end
        end
        assert((sitesByPoint[wonder.pointId]~=nil)==reachable,'Wonder entrance must match reachability of any outside root edge')
    end
    print(string.format('PASS world %d: %d giant tree, mountain=%s canyon=%s roots=%s',seed,#map:GetWonders(),tostring(present.HighMountain==true),tostring(present.Canyon==true),tostring(present.GiantTree==true)))
end
assert(wonderCount>0 and counts.HighMountain>0 and counts.Canyon>0 and counts.GiantTree>0,'Representative real worlds must exercise all natural entrance types')

-- A single eligible center makes the two boundary failures reproducible with the real 271-cell wonder rule.
local function flatWonderFixture()
    local map=require('Game.Map.Map')(42,1)
    map.regions={{instanceId=1,regionType=5,configId=5,cells={}},{instanceId=2,regionType=2,configId=2,cells={}}}
    map.regionsByType={[5]={map.regions[1]},[2]={map.regions[2]},[12]={},[13]={}}
    for q=-12,12 do for r=math.max(-12,-q-12),math.min(12,-q+12) do
        local center=q==0 and r==0
        local cell={q=q,r=r,height=1,regionId=center and 1 or 2,roadIds={},
            biomeWeights={{regionType=center and 5 or 2,weight=1}}}
        map.cells[#map.cells+1]=cell;map.cellsByKey[Hex.Key(q,r)]=cell
        local region=map.regions[cell.regionId];region.cells[#region.cells+1]=cell
    end end
    return map
end
local Wonders=require('Game.Map.MapWonders')
local NaturalEntrances=require('Game.MapArea.NaturalEntrances')
do
    local row=config:GetTable('MapWonderTable'):Get(1)
    local original={};for key,value in pairs(row) do original[key]=value end
    original.variantAssetIds={}
    local originalConfig={GetTable=function(_,name)
        if name=='MapWonderTable' then return {All=function() return {original} end} end
        return config:GetTable(name)
    end}
    local seen={}
    for seed=0,31 do
        local first,again,legacy=flatWonderFixture(),flatWonderFixture(),flatWonderFixture()
        first.seed=seed;again.seed=seed;legacy.seed=seed
        Wonders(config):Build(first);Wonders(config):Build(again);Wonders(originalConfig):Build(legacy)
        local a,b,old=first.wonders[1],again.wonders[1],legacy.wonders[1]
        local asset=first.decorations[a.decorationId].assetId
        assert(asset==1106 or asset==1109,'Unknown giant-tree variant')
        seen[asset]=true
        assert(asset==again.decorations[b.decorationId].assetId,'Reloading the same seed changed giant-tree shape')
        assert(legacy.decorations[old.decorationId].assetId==1106,'Empty variant pool must retain original giant tree')
        assert(a.pointId==old.pointId and a.cell.q==old.cell.q and a.cell.r==old.cell.r and #a.cells==#old.cells)
        assert(#a.entrances==#old.entrances,'Cosmetic variant changed root access')
        for i,cell in ipairs(first.cells) do
            local prior=legacy.cells[i]
            assert(cell.q==prior.q and cell.r==prior.r and cell.height==prior.height and cell.worldTravelBlocked==prior.worldTravelBlocked,
                'Cosmetic tree selection changed world geometry or travel')
        end
    end
    assert(seen[1106] and seen[1109],'Seeded giant-tree pool must retain and select both shapes')
    print('PASS original and fantasy tree variants: seeded selection, reload determinism, unchanged footprint and entrance identity')
end
do
    local map=flatWonderFixture()
    -- The north rim retains one dry neighbor, but that neighbor becomes blocked by the roots.
    for _,point in ipairs({{1,-10},{1,-11},{0,-11},{-1,-10},{-1,-9}}) do
        map:GetCell(point[1],point[2]).waterLevel=2
    end
    Wonders(config):Build(map)
    local wonder=assert(map.wonders[1]);assert(#wonder.cells==271)
    assert(wonder.entrance.q==0 and wonder.entrance.r==-10,'Fixture must preserve the isolated initial edge')
    local sites=NaturalEntrances.Build(map,config,definitions,{q=0,r=12})
    assert(#sites==1 and sites[1].naturalKind=='GiantTree' and sites[1].pointId==wonder.pointId)
    assert(sites[1].q==0 and sites[1].r==10,'A reachable south edge must replace the isolated north edge')
end
for _,kind in ipairs({'building','town'}) do
    local map=flatWonderFixture();local entrance=map:GetCell(9,0)
    if kind=='building' then
        local cell=map:GetCell(10,0);cell.buildingId=1
        map.buildings={{id=1,cell=cell,cells={cell},entrance=entrance}}
    else map.towns={{id=1,center=entrance}} end
    Wonders(config):Build(map)
    assert(#map.wonders==0 and not entrance.worldTravelBlocked,
        'Giant roots must not cover an existing '..kind..' entrance even when it has no road')
end
print('PASS giant roots: choose a reachable alternate edge; preserve unroaded building entrances and town centers')

-- Replace only the native adventure/inventory boundary; run the production CanEnter/Enter methods.
local generator=require('Game.MapArea.MapAreaGenerator')(config)
generator:Register(config:GetEnum('MapArea','E_MapAreaType').Canyon,require('Game.MapArea.CanyonGenerator'),'MapAreaCanyonTable','MapAreaCanyonThemeTable')
local persistedVisited={};local ropes,consumed,activations=0,0,0;local actor={Id=1,HP=100}
local inventory={CountItem=function(_,id)assert(id==82);return ropes end,
    ConsumeStack=function(_,id,count)assert(id==82 and count==1 and ropes>=count);ropes=ropes-count;consumed=consumed+count end}
local data={Phase='map',PartyCount=1,Equipment=inventory,GetPartyAt=function(_,index)assert(index==0);return actor end,
    HasVisited=function(_,id)return persistedVisited[id]==true end}
local enterMode='success'
local function session()
    return setmetatable({config=config,generator=generator,layouts={},adventure=data,Activate=function(_,site)
        activations=activations+1
        if enterMode=='error' then error('Intentional generation failure') end
        if enterMode=='failure' then return false,'Intentional deployment failure' end
        persistedVisited[site.id]=true;return true
    end},{__index=AreaSystem})
end
local instance=session()
assert(not instance:Enter(canyonSite,42) and activations==0 and consumed==0,'No rope must reject before activation')
ropes=1;enterMode='failure'
assert(not instance:Enter(canyonSite,42) and ropes==1 and consumed==0 and not persistedVisited[canyonSite.id],'Failed activation charged rope')
enterMode='error'
assert(not pcall(function()instance:Enter(canyonSite,42)end) and ropes==1 and consumed==0,'Generation exception charged rope')
enterMode='success';actor.HP=0
assert(not instance:Enter(canyonSite,42) and ropes==1 and consumed==0,'Ineligible party charged rope')
actor.HP=100
assert(instance:Enter(canyonSite,42) and ropes==0 and consumed==1 and persistedVisited[canyonSite.id],'First successful descent must consume exactly one rope')
assert(instance:Enter(canyonSite,42) and ropes==0 and consumed==1,'Established rope entrance charged again')
assert(session():Enter(canyonSite,42) and ropes==0 and consumed==1,'Restored visited projection did not retain the fixed entrance')
print('PASS canyon rope: item 82 x1 only after success; no rope/failure/exception/dead-party never charge; visited revisit and restored projection are free')
registry:Shutdown()
