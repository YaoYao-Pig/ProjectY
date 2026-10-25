-- Real WaterTravel/WaterNavigation/Pathfinder rules and C# Data in an isolated LuaEnv.
-- This deliberately supplies a small map/config fixture. UI, fog, factions and area
-- activation are boundaries; area occupancy and squad placement still use real Data.
-- It does not cover production map generation, rendering, world Tick or disk saves.
local Hex=require('Game.Map.HexGrid')
local Water=require('Game.Adventure.WaterTravel')
local data,player=WaterFixtureAdventure,WaterFixturePlayer
local travel=CS.ProjectY.Data.WorldTravelData.For(data)
local reports={}
local function test(name,body) body();reports[#reports+1]='PASS '..name end
local rule={minWaterDepth=.2,maxWaterStep=.2,maxBankRise=1,minutesPerCell=2,
    threatKills=2,threatRadius=3,repairItemId=83,repairCount=3,boatPrice=60,fareBase=5,farePerCell=2}
local map={cells={},cellsByKey={},hexRadius=1}
local function cell(q,r,water)
    local value={q=q,r=r,index=#map.cells+1,height=water and -1 or .2,waterLevel=water and 0 or nil,waterDepth=water and 1 or 0}
    map.cells[#map.cells+1]=value;map.cellsByKey[Hex.Key(q,r)]=value;return value
end
for q=0,4 do cell(q,0,true);cell(q,1,false);cell(q,2,false) end
cell(10,0,true);cell(10,1,false);cell(10,2,false)
function map:FindCell(q,r) return self.cellsByKey[Hex.Key(q,r)] end
function map:GetCell(q,r) return assert(self:FindCell(q,r),'Fixture coordinate is outside its map') end
function map:GetNeighbors(q,r)
    local result={};for direction=1,6 do local nq,nr=Hex.Neighbor(q,r,direction);local nextCell=self:FindCell(nq,nr);if nextCell then result[#result+1]=nextCell end end
    return result
end
function map:GetCells() return self.cells end
function map:GetWaterfalls() return {} end
function map:GetCellWorldPosition(q,r) local value=self:GetCell(q,r);return Hex.ToWorld(q,r,value.height,1) end
map.docks={
    {id=1,waterQ=0,waterR=0,landQ=0,landR=1,initialDamaged=true,initialThreat=true},
    {id=2,waterQ=4,waterR=0,landQ=4,landR=1,initialDamaged=false,initialThreat=false},
    {id=3,waterQ=10,waterR=0,landQ=10,landR=1,initialDamaged=false,initialThreat=false}}
local sites={};for _,dock in ipairs(map.docks) do sites[dock.id]={id=dock.id,q=dock.landQ,r=dock.landR,areaConfigId=1,pointId=dock.id,source={dock=dock}} end
local config={};function config:GetTable(name)
    assert(name=='DockSettingsTable','Unexpected fixture configuration table: '..name)
    return {Get=function(_,id) assert(id==1);return rule end}
end
local layouts={}
for _,dock in ipairs(map.docks) do
    local layout={configId=1,entryIndex=1,waterfront={dockId=dock.id,npcId=1,landingIndex=1},cells={}}
    for i=1,6 do layout.cells[i]={index=i,q=i-1,r=0,blocked=false,neighbors={}} end
    for i=1,6 do if i>1 then layout.cells[i].neighbors[#layout.cells[i].neighbors+1]=i-1 end;if i<6 then layout.cells[i].neighbors[#layout.cells[i].neighbors+1]=i+1 end end
    function layout:Neighbors(value) local result={};for _,index in ipairs(value.neighbors) do result[#result+1]=self.cells[index] end;return result end
    function layout:CanStep(first,last) return first~=nil and last~=nil and not last.blocked end
    layouts[dock.id]=layout
end
local blocked,known={},true
local adventure={data=data,player=player,config=config,sites=sites,map=map,
    equipment={data=data.Equipment},travel={data=travel},parties={data={Target=function()end}},
    narrative={townMissions={escort={data={AttachedId=0},Detach=function() error('Fixture is not escorting') end}}},
    obstacles={BlockedCells=function() return {[3]=true} end}}
adventure.fog={Known=function() return known end,Update=function()end}
adventure.factions={ServiceAllowed=function(_,id) if blocked[id] then return false,'Fixture port is occupied' end;return true end}
adventure.areas={layouts=layouts}
function adventure.areas:ActiveLayout() return assert(self.layouts[data.Areas.ActiveSiteId]) end
function adventure.areas:Interact(kind,id) assert(kind==2 and id==1);data.Areas.Active:SetInteraction(kind,id);return true end
function adventure.areas:CloseInteraction() data.Areas.Active:SetInteraction(0,0);return true end
function adventure.areas:Leave() data:LeaveArea();return true end
function adventure.areas:CanEnter() return data.Phase=='map' end
function adventure.areas:SquadFootprint() return function(index) return {index} end end
function adventure.areas:EnemyOccupancy() return {[2]=true} end
function adventure.areas:RevealSquad(_,state) state:Reveal({state:GetMemberCellAt(0),state:GetMemberCellAt(1)}) end
function adventure:EnterSite(id)
    assert(data.Phase=='map');local layout=assert(layouts[id]);local state=data.Areas:Enter(id,#layout.cells,1)
    if state.NpcCount==0 then state:AddNpc(1,5) end
    state:DeployMembers({data:GetPartyAt(0).Id,data:GetPartyAt(1).Id},{1,4});data:BeginArea(id);return true
end
local water=Water.New(adventure);adventure.water=water;water:Bind(map,sites,true)
function adventure.travel:Arrive()
    local handled,ok,reason=water:Arrive();if handled then return ok,reason end
    travel:Arrived();return true
end
local function command(name,value) return water:Command(name,value or 1,water.data.Revision) end
local function finishSteps()
    travel:SetPaused(false)
    while travel.Active do
        assert(travel:Step(100)>0)
        if water.data.Mode=='owned' then water.data:SyncBoat(travel.Q,travel.R) end
    end
end
local function fixtureWalkTo(q,r)
    assert(data.Phase=='map' and water.data.Mode=='walk' and not travel.Active)
    travel:Relocate(q,r) -- Walking/navigation outside the water subsystem is not under test here.
end
travel:Reset(91,0,1,4);assert(adventure:EnterSite(1));assert(water:Open(1))

test('repair command rechecks threats, materials and revision without duplicate consumption',function()
    assert(command('water_accept'));assert(not command('water_accept'))
    local before=data.Equipment:CountItem(83);assert(before==1)
    assert(not command('water_repair'));assert(data.Equipment:CountItem(83)==before)
    water:RecordKill();assert(water.data:GetDock(1).ThreatRemaining==1)
    water:RecordKill();assert(water.data:GetDock(1).ThreatRemaining==0)
    assert(not command('water_repair'));data.Equipment:AddStack(83,2)
    local revision=water.data.Revision;assert(command('water_repair'))
    assert(water.data:GetDock(1).Ready and data.Equipment:CountItem(83)==0)
    assert(not water:Command('water_repair',1,revision));assert(not command('water_repair'))
    assert(data.Equipment:CountItem(83)==0)
end)

test('buy command spends real currency once and preserves the only boat on repeated clicks',function()
    assert(player.Coins==40 and not command('water_buy') and not water.data.Owned)
    player:AddCoins(60);local revision=water.data.Revision
    assert(command('water_buy'));assert(player.Coins==40 and water.data.Owned and water.data.BoatDockId==1)
    assert(not water:Command('water_buy',1,revision));assert(not command('water_buy'))
    assert(player.Coins==40 and water.data.BoatQ==0 and water.data.BoatR==0)
    assert(not pcall(function() water.data.Mode='ferry' end),'Lua must not directly mutate authority')
end)

test('real route planning rejects mid-edge landing and supports wild mooring and reboarding',function()
    assert(command('water_board'));assert(data.Phase=='map' and water.data.Mode=='owned' and travel.Q==0 and travel.R==0)
    assert(water:Plan(map:GetCell(2,0),0));assert(travel.StepCount==2)
    assert(travel:Step(.5)==.5 and travel.Progress==.25)
    assert(not water:Plan(map:GetCell(0,1),0));assert(water.data.Mode=='owned' and travel.Progress==.25)
    finishSteps();assert(adventure.travel:Arrive())
    assert(water:Plan(map:GetCell(2,1),0))
    assert(water.data.Mode=='walk' and water.data.BoatQ==2 and water.data.BoatR==0 and water.data.BoatDockId==0)
    assert(travel.Q==2 and travel.R==1 and travel.Paused)
    fixtureWalkTo(0,1);assert(not water:Plan(map:GetCell(2,0),0));assert(water.data.Mode=='walk')
    fixtureWalkTo(2,1);assert(water:Plan(map:GetCell(2,0),0));assert(water.data.Mode=='owned' and travel.Paused)
    assert(water:Plan(map:GetCell(2,1),0));fixtureWalkTo(0,1)
end)

test('ferry command rejects unavailable routes and atomically charges one valid trip',function()
    assert(adventure:EnterSite(1));assert(water:Open(1))
    local before=player.Coins
    assert(not command('water_ferry',3) and player.Coins==before and water.data.Mode=='walk')
    known=false;assert(not command('water_ferry',2));known=true
    blocked[2]=true;assert(not command('water_ferry',2));blocked[2]=nil
    assert(player.Coins==before)
    local revision=water.data.Revision;assert(command('water_ferry',2))
    assert(player.Coins==before-13 and water.data.Mode=='ferry' and water.data.FerryPaid==13 and water.data.FerryTargetDockId==2)
    assert(data.Phase=='map' and travel.Q==0 and travel.R==0 and travel.StepCount==4 and travel.TargetSiteId==2)
    assert(water.data.BoatQ==2 and water.data.BoatR==0 and water.data.BoatDockId==0,'Ferry cannot move the parked owned boat')
    assert(not water:Command('water_ferry',2,revision));assert(player.Coins==before-13)
end)

test('real serialized candidates validate route endpoints, complete docks and parked boat references',function()
    local world={map=map,sites=sites}
    water:ValidateSaved(MakeWaterCandidate(data,'valid'),world)
    for _,defect in ipairs({'wrong_endpoint','missing_dock','wrong_boat_dock'}) do
        local candidate=MakeWaterCandidate(data,defect)
        assert(not pcall(function() water:ValidateSaved(candidate,world) end),'Expected candidate rejection: '..defect)
    end
    assert(player.Coins==27 and water.data.Mode=='ferry' and water.data.FerryPaid==13 and travel.StepCount==4)
end)

test('arrival requires the actual destination water cell and retains a blocked paid trip for retry',function()
    local handled,ok=water:Arrive();assert(handled and not ok and water.data.Mode=='ferry' and travel.Q==0 and travel.StepCount==4)
    finishSteps();assert(travel.Q==4 and travel.R==0 and not travel.Active)
    blocked[2]=true;handled,ok=water:Arrive()
    assert(handled and not ok and water.data.Mode=='ferry' and water.data.FerryPaid==13 and travel.Paused)
    blocked[2]=nil;assert(adventure.travel:Arrive())
    assert(data.Phase=='area' and data.SiteId==2 and water.data.Mode=='walk' and water.data.FerryPaid==0)
    assert(travel.Q==4 and travel.R==1 and travel.Paused and player.Coins==27)
    assert(water.data.BoatQ==2 and water.data.BoatR==0 and water.data.BoatDockId==0)
    local state=data.Areas.Active
    assert(state:GetMemberCellAt(0)==1 and state:GetMemberCellAt(1)==4,'Arrival must avoid enemy, obstacle and NPC occupied cells')
    water:ValidateSaved(MakeWaterCandidate(data,'valid'),{map=map,sites=sites})
    assert(water:Open(2));assert(not command('water_board',2),'A parked boat cannot be summoned to another port')
end)

return table.concat(reports,'\n')
