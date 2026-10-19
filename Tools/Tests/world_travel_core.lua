package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local f=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local bytes=f:read('*a');f:close();return bytes
end}})
local Hex=require('Game.Map.HexGrid');local Travel=require('Game.Adventure.WorldTravel')
local state={Q=0,R=0,AnchorQ=0,AnchorR=0,Speed=1,Paused=true,Progress=0,TargetSiteId=0,Message='',StepCount=0,Active=false}
function state:Reset(seed,q,r,nextId) self.Q=q;self.R=r;self.AnchorQ=q;self.AnchorR=r;self.nextId=nextId;self.Paused=false end
function state:Plan(qs,rs,minutes,target)self.plan={qs=qs,rs=rs,minutes=minutes};self.TargetSiteId=target;self.Active=#qs>0 end
function state:SetPaused(value)self.Paused=value end
function state:SetSpeed(value)self.Speed=value end
function state:Roll(maximum)return self.roll or 1 end
function state:AddStop(event,encounter)self.Paused=true;return {Id=self.nextId,Q=self.Q,R=self.R,EventId=event,EncounterId=encounter}end
CS={ProjectY={Data={WorldTravelData={For=function()return state end,BeginBattle=function(data,id)data.Phase='resolving';data.SiteId=id end}}}}
local map={cells={},cellsByKey={}}
function map:GetCells()return self.cells end
function map:GetCell(q,r)return assert(self.cellsByKey[Hex.Key(q,r)])end
function map:GetRegion(id)return {instanceId=id,configId=id,regionType=id}end
function map:GetCellWorldPosition(q,r)return q,0,r end
for q=0,5 do for r=0,3 do
    local cell={q=q,r=r,height=0,regionId=1,roadIds={},biomeWeights={{regionType=1,weight=1}}}
    map.cells[#map.cells+1]=cell;map.cellsByKey[Hex.Key(q,r)]=cell
end end
map:GetCell(2,0).waterLevel=1;map:GetCell(2,1).height=100
local adventure={parties={data={IsOpen=false,Target=function()end}},config=config,data={Phase='map',Seed=431},context={services={UI={IsWorldPaused=false}}},camp={data={IsOpen=false}},sites={{id=1,q=0,r=0}},
    events={CanVisit=function()return true end,LivingParty=function()return {1}end,events=config:GetTable('AdventureEventTable')},
    battle={encounters=config:GetTable('CombatEncounterTable')}}
local travel=Travel.New(adventure);travel:Reset(map,adventure.sites)
assert(travel:Plan(map:GetCell(5,0),0));local previous=map:GetCell(0,0)
for i,q in ipairs(state.plan.qs) do
    local cell=map:GetCell(q,state.plan.rs[i]);assert(not cell.waterLevel and math.abs(cell.height-previous.height)<=travel.maxStep)
    assert(Hex.Distance(previous.q,previous.r,cell.q,cell.r)==1);previous=cell
end
assert(previous==map:GetCell(5,0),'Route did not reach the requested destination')
local plan=state.plan;assert(not travel:Plan(map:GetCell(2,0),0) and state.plan==plan,'Rejected water route mutated the current trip')
local a,b=map:GetCell(0,1),map:GetCell(1,1);local offRoad=travel:Cost(a,b)
a.roadIds={1};b.roadIds={1};assert(travel:Cost(a,b)<offRoad)
b.regionId=5;assert(travel:Cost(a,b)>offRoad*travel.rule.roadMultiplier)
assert(travel:Command('travel_pause') and state.Paused)
assert(travel:Command('travel_speed',4) and state.Speed==4)
assert(not travel:Command('travel_speed',3) and state.Speed==4)
adventure.context.services.UI.IsWorldPaused=true;assert(not travel:Command('travel_pause') and state.Paused)
adventure.context.services.UI.IsWorldPaused=false
print('PASS weighted land routes, water/cliff rejection, roads, terrain costs, pause and speed guards')

-- Direct encounters enter the generated battlefield without consuming an event choice.
state.Q=1;state.R=1;state.nextId=2
local entered,started,looted,source
adventure.areas={layouts={},EnterEventBattlefield=function(_,site,seed,input)
    assert(adventure.data.Phase=='resolving' and site.id==2 and seed==431);entered=true;source=input
    adventure.data.Phase='area';adventure.data.Areas={Active={GetEncounterAt=function()return 'group' end}};return true
end,StartBattle=function(_,battle,group)assert(group=='group' and battle==adventure.battle);started=true;adventure.data.Phase='battle'end}
adventure.equipment={InitializeLoot=function()looted=true end}
assert(travel:Trigger(config:GetTable('WorldTravelEventTable'):Get(4)))
assert(entered and started and looted and state.Paused and source.regionType==5 and #source.propIds==2)
assert(source.encounterId==204 and source.q==1 and source.r==1 and adventure.sites[2].travelStop)
print('PASS direct travel encounter preserves the route and uses its actual terrain/position')

-- The real generator must produce connected, repeatable and varied tactical maps.
local areaType=config:GetEnum('MapArea','E_MapAreaType').Battlefield
local generator=require('Game.MapArea.MapAreaGenerator')(config)
generator:Register(areaType,require('Game.MapArea.BattlefieldGenerator'),'MapAreaBattlefieldTable','MapAreaBattlefieldThemeTable')
local definition=config:GetConstant('Loot','EventBattlefieldAreaId')
source.biomeWeights={{regionType=5,weight=1}}
local first=generator:Generate(definition,431,2,source)
local again=generator:Generate(definition,431,2,source)
local other=generator:Generate(definition,431,3,source)
local function signature(area)local out={};for _,cell in ipairs(area.cells)do out[#out+1]=cell.blocked and '1' or '0'end;return table.concat(out)end
assert(signature(first)==signature(again) and signature(first)~=signature(other))
assert(#first.props>0 and first.cells[1].surfaceId==201)
assert(first:FindPath(first.entryIndex,first.goalIndex),'Entry and exit must be connected')
for _,cell in ipairs(first.encounterPlans[1].cells)do assert(not cell.blocked and first:FindPath(first.entryIndex,cell.index))end
print('PASS random forest battlefield, tree obstacles, stable seeds and connected deployment/exit')
local maps=require('Game.Map.MapSystem')()
maps:OnInit({systems={Get=function(_,name)assert(name=='Config');return config end}})
local generated=maps:Generate(431,{1,5},512)
local start,goal
for _,cell in ipairs(generated:GetCells())do if not cell.waterLevel then
    for direction=1,6 do
        local q,r=Hex.Neighbor(cell.q,cell.r,direction);local other=generated:FindCell(q,r)
        if other and not other.waterLevel and math.abs(cell.height-other.height)<=travel.maxStep then start,goal=cell,other;break end
    end
    if start then break end
end end
assert(start and goal)
adventure.data.Phase='map';adventure.sites={{id=1,q=start.q,r=start.r}}
travel:Reset(generated,adventure.sites)
assert(travel:Plan(goal,0) and #state.plan.qs==1,'Frozen map cell identities must remain valid for runtime pathfinding')
maps:OnShutdown()
print('PASS runtime route planner consumes the real generated and frozen world map')
for _,path in ipairs({'Lua/Game/Adventure/WorldTravel.lua','Lua/Game/Adventure/AdventureSystem.lua','Lua/Game/Adventure/DemoBridge.lua',
    'Lua/Game/Adventure/MainHudModel.lua','Lua/Game/Narrative/NarrativeSystem.lua','Lua/Game/MapArea/BattlefieldGenerator.lua'})do assert(loadfile(path))end
config:OnShutdown()
