-- Giant-tree footprint identity, discovery and walking-to-entry dispatch.
-- Real config/maps and production Lua methods; only native state boundaries are in-memory substitutes.
package.path='Lua/?.lua;'..package.path
local registry=require('Core.SystemRegistry')({ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end,LogError=error})
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('Map',require('Game.Map.MapSystem'),{'Config'});registry:Start()
local config,system=registry:Get('Config'),registry:Get('Map')
local Adventure=require('Game.Adventure.AdventureSystem')
local AreaSystem=require('Game.MapArea.MapAreaSystem')
local Travel=require('Game.Adventure.WorldTravel')
local Fog=require('Game.Adventure.WorldFog')
local Hex=require('Game.Map.HexGrid')
local generator=require('Game.MapArea.MapAreaGenerator')(config)
generator:Register(config:GetEnum('MapArea','E_MapAreaType').GiantTree,
    require('Game.MapArea.GiantTreeGenerator'),'MapAreaGiantTreeTable','MapAreaGiantTreeThemeTable')
local definitions=generator.definitions
local entrances=setmetatable({config=config,entrances={},generator=generator},{__index=AreaSystem})
for _,row in ipairs(config:GetTable('MapAreaEntranceTable'):All()) do entrances.entrances[row.townId]=definitions:Get(row.areaId) end
local builder=setmetatable({config=config,mapSystem=system,areas=entrances,
    events={events=config:GetTable('AdventureEventTable')},
    travel={maxStep=config:GetTable('WorldTravelTable'):Get(1).maxHeightStep}}, {__index=Adventure})

local function discovery(map)
    local known,order,indices={},{},{}
    for i,cell in ipairs(map.cells) do indices[cell]=i end
    local data={KnownCount=0,CellCount=#map.cells,ReadCount=0}
    function data:IsKnown(index) return known[index]==true end
    function data:GetKnownAt(index) self.ReadCount=self.ReadCount+1;return assert(order[index+1]) end
    function data:Reveal(cell)
        local index=assert(indices[cell])
        if not known[index] then known[index]=true;order[#order+1]=index;self.KnownCount=#order end
    end
    function data:Reset()
        known={};order={};self.KnownCount=0
    end
    local fog=setmetatable({data=data},{__index=Fog});fog:Bind(map)
    -- The fixture controls native discovery directly; Snapshot.Update must not advance a visibility clock.
    fog.fullVision=true
    return fog,data
end

local function travelState(start)
    local data={Q=start.q,R=start.r,AnchorQ=start.q,AnchorR=start.r,TargetSiteId=0,
        Active=false,Paused=false,Speed=1,RemainingMinutes=0,Message='',Progress=0,StepCount=0,PlanCount=0}
    function data:Plan(qs,rs,minutes,siteId)
        self.PlanCount=self.PlanCount+1;self.route={};self.cursor=1;self.TargetSiteId=siteId
        for i,q in ipairs(qs) do self.route[i]={Q=q,R=rs[i],Minutes=minutes[i]} end
        self.StepCount=#self.route;self.Active=self.StepCount>0
    end
    function data:GetStepAt(index) return assert(self.route[self.cursor+index]) end
    function data:Advance()
        local step=self:GetStepAt(0)
        self.Q,self.R,self.AnchorQ,self.AnchorR=step.Q,step.R,step.Q,step.R
        self.cursor=self.cursor+1;self.StepCount=self.StepCount-1;self.Active=self.StepCount>0
    end
    function data:Arrived()
        assert(not self.Active,'Arrival was dispatched before the native route ended')
        self.TargetSiteId=0
    end
    return data
end

for _,seed in ipairs({42,43}) do
    local world=builder:BuildWorld(seed,5,10000)
    local map=world.map;local wonder=assert(map:GetWonders()[1],'Representative world lost its giant tree')
    local site
    for _,candidate in ipairs(world.sites) do
        if candidate.naturalKind=='GiantTree' then
            assert(not site and candidate.worldWonderId==wonder.id)
            site=candidate
        else assert(candidate.worldWonderId==nil,'An unrelated site acquired a wonder identity') end
    end
    assert(site and site.pointId==wonder.pointId and site.areaConfigId==72)
    local entry=map:GetCell(site.q,site.r)
    assert(not entry.worldTravelBlocked and not entry.wonderId and not entry.waterLevel)
    assert(Hex.Distance(site.q,site.r,wonder.cell.q,wonder.cell.r)==10,'Tree entry moved into the blocked root footprint')
    assert(site.source.q==site.q and site.source.r==site.r and site.source.height==entry.height)
    assert(site.source.regionId==entry.regionId and site.source.regionType==map:GetRegion(entry.regionId).regionType)
    assert(site.source.generationVersion==map.generationVersion and site.source.biomeWeights==entry.biomeWeights)
    local belongs=false;for _,candidate in ipairs(wonder.entrances) do if candidate==entry then belongs=true end end
    assert(belongs,'Tree destination is not one of the generated outside entries')

    local snapshot=require('Game.Map.MapRenderSnapshot')(map)
    local occupied={};for _,cell in ipairs(wonder.cells) do occupied[cell]=true end
    local count=0
    for i,cell in ipairs(map.cells) do
        local rendered=snapshot.cells[i]
        assert(type(rendered.wonderId)=='number' and rendered.wonderId==(cell.wonderId or 0))
        if rendered.wonderId==site.worldWonderId then
            assert(occupied[cell] and cell.worldTravelBlocked);count=count+1
        else assert(not occupied[cell],'Render footprint lost a root tile') end
    end
    assert(count==271,'Wonder footprint must include all 271 tiles and no entire-region expansion')

    local occupiedCell,unrelated
    for _,cell in ipairs(wonder.cells) do
        for _,other in ipairs(map:GetRegion(cell.regionId).cells) do
            if not other.wonderId and other~=entry then occupiedCell,unrelated=cell,other;break end
        end
        if unrelated then break end
    end
    assert(unrelated,'Discovery fixture needs a same-region tile outside the root footprint')
    local fog,fogData=discovery(map)
    fogData:Reveal(unrelated)
    assert(not fog:Known(site.q,site.r,nil,wonder.id),'Same-region terrain incorrectly discovered the giant tree')
    assert(not fog:Known(site.q,site.r),'The fixed tree entry must remain individually unknown')

    -- Execute the production Adventure snapshot with empty native party/battle state.
    local actor={Id=1,HP=10}
    local native={Phase='map',PartyCount=0,ResultText='',Battle={Phase='idle',UnitCount=0},Areas={ActiveSiteId=0},
        Equipment={CountItem=function()return 0 end},Narrative={GetValue=function()return 0 end},
        GetPartyAt=function(_,index)assert(index==0);return actor end,HasVisited=function()return false end}
    local instance=setmetatable({config=config,map=map,sites=world.sites,data=native,fog=fog,player={Coins=0},
        context={services={UI={IsWorldPaused=false}}},camp={data={IsOpen=false}},
        events={CanVisit=function()return true end},specialEvents={byEvent={},CanEnter=function()return true end},
        factions={data={FindConflict=function()return nil end}},
        parties={data={IsOpen=false,Target=function(_,id)assert(id==0)end},Snapshot=function()return {} end},
        water={data={Mode='walk'},WorldSnapshot=function()return {} end,Arrive=function()return false end}}, {__index=Adventure})
    instance.areas=setmetatable({config=config,adventure=native,generator=generator,layouts={}},{__index=AreaSystem})
    local state=travelState(map:GetCell(world.sites[1].q,world.sites[1].r))
    instance.travel=setmetatable({adventure=instance,data=state,map=map,cells=map.cells,
        paths=require('Game.Map.MapPathfinder')(map),rule=config:GetTable('WorldTravelTable'):Get(1),
        maxStep=builder.travel.maxStep,terrains={}},{__index=Travel})
    for _,row in ipairs(config:GetTable('WorldTravelTerrainTable'):All()) do instance.travel.terrains[row.regionType]=row end
    local function projectedTree()
        local result=instance:Snapshot()
        for _,candidate in ipairs(result.sites) do if candidate.id==site.id then return candidate end end
    end
    assert(not projectedTree(),'Unrelated known terrain leaked the tree site into AdventureSnapshot')
    fogData:Reveal(occupiedCell)
    assert(fog:Known(site.q,site.r,nil,wonder.id) and not fog:Known(site.q,site.r))
    local projected=assert(projectedTree(),'Seeing the root footprint must expose the giant-tree site')
    assert(projected.worldWonderId==wonder.id and projected.worldRegionId==0 and projected.areaConfigId==72)
    assert(projected.q==site.q and projected.r==site.r,'Visual footprint rewrote the fixed travel destination')
    local reads=fogData.ReadCount
    for _=1,12 do assert(fog:Known(site.q,site.r,nil,wonder.id)) end
    assert(fogData.ReadCount==reads,'Wonder discovery rescanned already indexed native cells')
    fogData:Reset()
    assert(not fog:Known(site.q,site.r,nil,wonder.id),'Native discovery reset retained an old wonder')
    fogData:Reveal(unrelated);fog:Bind(map);fog.fullVision=true
    assert(not fog:Known(site.q,site.r,nil,wonder.id),'Rebind retained a previous root-footprint discovery')
    fogData:Reset();fogData:Reveal(wonder.cells[#wonder.cells]);fog:Bind(map);fog.fullVision=true
    assert(fog:Known(site.q,site.r,nil,wonder.id),'Another root tile did not reconstruct discovery after rebind')

    -- Keep production Visit/Plan/Arrive and actual pathfinding; observe the downstream EnterSite dispatch.
    native.PartyCount=1
    local entered=0;local source=site.source
    function instance:EnterSite(id)
        assert(id==site.id and not state.Active and state.Q==site.q and state.R==site.r)
        assert(self.areas:AreaId(self.sites[id])==72 and self.sites[id].source==source)
        entered=entered+1;self.data.Phase='area';return true
    end
    assert(not instance.travel:Plan(wonder.cell,site.id) and state.PlanCount==0,'Direct root-center travel must remain blocked')
    assert(instance.travel:Visit(site.id) and state.Active and entered==0)
    assert(state.TargetSiteId==site.id and state.StepCount>0)
    local previous=map:GetCell(state.Q,state.R)
    for _,step in ipairs(state.route) do
        local cell=map:GetCell(step.Q,step.R)
        assert(not occupied[cell] and not cell.worldTravelBlocked and instance.travel:Cost(previous,cell))
        previous=cell
    end
    assert(previous==entry,'Clicking the tree did not route to its fixed reachable outside entry')
    while state.Active do state:Advance();assert(entered==0,'Tree area opened while the party was still travelling') end
    assert(instance.travel:Arrive() and entered==1 and native.Phase=='area')
    native.Phase='map'
    assert(instance.travel:Visit(site.id) and entered==2,'Already-at-foot entry should dispatch once without walking into roots')
    assert(site.source==source and site.q==entry.q and site.r==entry.r)
    print(string.format('PASS giant tree world %d: 271-tile identity, discovery/snapshot, fixed outside route and arrival-only area 72 dispatch',seed))
end

-- Numeric region/wonder identities can collide; discovery namespaces must remain independent across regions.
do
    local cells={{q=0,r=0,regionId=3},{q=1,r=0,regionId=1,wonderId=1},
        {q=2,r=0,regionId=2,wonderId=1},{q=3,r=0,regionId=1}}
    local map={cells=cells,GetCells=function(self)return self.cells end}
    local fog,data=discovery(map)
    data:Reveal(cells[4]);assert(not fog:Known(0,0,nil,1))
    for _,index in ipairs({2,3}) do
        data:Reset();fog:Bind(map);data:Reveal(cells[index])
        assert(fog:Known(0,0,nil,1) and not fog:Known(0,0,nil,2))
        assert(not fog:Known(0,0),'Wonder discovery must not mark its unseen outside destination as known')
    end
    print('PASS cross-region root footprint and separate region/wonder discovery identities')
end
registry:Shutdown()
