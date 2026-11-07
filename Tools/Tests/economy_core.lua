package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local f=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local data=f:read('*a');f:close();return data
end}})
local Profile=require('Game.Map.TownEconomyProfile')
local Hex=require('Game.Map.HexGrid')
local function terrain(kind,water,barrier)
    local cells={};local map={}
    for q=-14,14 do for r=-14,14 do
        cells[Hex.Key(q,r)]={q=q,r=r,regionId=kind,height=0,roadIds={},worldTravelBlocked=barrier and q==1,
            waterLevel=water and q<-1 and .1 or nil}
    end end
    function map:FindCell(q,r)return cells[Hex.Key(q,r)] end
    function map:GetRegion(id)return {regionType=id} end
    return map
end
local forest=Profile.ForTown(terrain(5),{center={q=0,r=0}},config)
local mountain=Profile.ForTown(terrain(2),{center={q=0,r=0}},config)
local lake=Profile.ForTown(terrain(1,true),{center={q=0,r=0}},config)
assert(forest.resources[3]>mountain.resources[3] and mountain.resources[4]>forest.resources[4])
assert(lake.resources[2]>forest.resources[2],'Reachable shoreline must supply fish')
local separated=terrain(1,false,true)
local previous=separated.GetRegion
function separated:GetRegion(id)return previous(self,id) end
local find=separated.FindCell
function separated:FindCell(q,r)local c=find(self,q,r);if c and q>1 then c.regionId=5 end;return c end
local isolated=Profile.ForTown(separated,{center={q=0,r=0}},config)
assert(isolated.resources[3]==0,'Blocked forest incorrectly contributes production')
print('PASS resource strengths, shoreline and blocked-resource exclusion')

local generator=require('Game.MapArea.MapAreaGenerator')(config)
generator:Register(2,require('Game.MapArea.TownGenerator'),'MapAreaTownTable','MapAreaTownThemeTable')
for _,areaId in ipairs({2,3,4,5,6}) do
    local definition=config:GetTable('MapAreaTable'):Find(areaId)
    if definition and definition.areaType==2 then
        for _,seed in ipairs({20261029,20260924}) do
            local area=generator:Generate(areaId,seed,11,{generationVersion=11,regionId=5,regionType=5,regionConfigId=5,q=0,r=0,height=1,biomeWeights={{regionType=5,weight=1}}})
            local banks=0
            for _,facility in ipairs(area.facilities) do if facility.kind=='bank' then
                banks=banks+1;assert(area:FindPath(area.entryIndex,facility.entryIndex),'Bank counter unreachable')
                local found=false;for _,npc in ipairs(area.npcs) do if npc.facilityId==facility.id then assert(npc.templateId==5);found=true end end
                assert(found,'Bank clerk missing')
            end end
            assert(banks==1,'Each generated town must contain one bank')
        end
    end
end
print('PASS bank building, clerk and reachable counter in new town layouts')
for _,path in ipairs({'Lua/Game/Economy/EconomyModel.lua','Lua/UI/Panel/BankCtr.lua','Lua/UI/Panel/ShopCtr.lua','Lua/Game/Adventure/WorldParties.lua'}) do assert(loadfile(path)) end
local L=require('Language')
assert(string.format(L.EconomyChartOHLC,1,100,102,99,101,1):find('101'))
assert(string.format(L.EconomyBankRisk,7,30,15,1000):find('30%%'))
print('PASS changed Lua syntax and localized numeric templates')

local originalCS=CS
CS={ProjectY={Data={AnimalCompanionState={Bound=function(actor)return actor.animal end}}}}
local animal={Id=101,HP=10,AnimalSpeciesId=1,Growth={Level=1}}
local members={{Id=1,HP=10,AnimalSpeciesId=0,Growth={Level=1},animal=animal},
    {Id=2,HP=10,AnimalSpeciesId=0,Growth={Level=1},animal=animal}}
local needsModel=setmetatable({rule=config:GetTable('EconomyRuleTable'):Get(1),adventure={config=config,
    data={PartyCount=2,GetPartyAt=function(_,i)return members[i+1] end}}},{__index=require('Game.Economy.EconomyModel')})
local ids,food,wages=needsModel:Needs()
assert(#ids==3 and wages[1]==0 and wages[2]==0 and wages[3]>0,'Leader, unique animal and employee accounting failed')
local initialAnimalFood,initialWage=food[2],wages[3]
animal.Growth.Level=6;members[2].Growth.Level=6
ids,food,wages=needsModel:Needs();assert(food[2]>initialAnimalFood and wages[3]>initialWage,'Level growth did not increase animal food / employee wage')
animal.HP=0;ids=needsModel:Needs();assert(#ids==2,'Dead companion still consumed supplies')
CS=originalCS
print('PASS leader salary exemption, animal deduplication, level growth and dead companion exclusion')

local registry=require('Core.SystemRegistry')({ReadConfig=function(_,name)
    local f=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local data=f:read('*a');f:close();return data
end,LogError=error})
registry:Register('Config',require('Config.ConfigSystem'));registry:Register('Map',require('Game.Map.MapSystem'),{'Config'});registry:Start()
local world=registry:Get('Map'):GenerateSeeded(20261029,3000)
assert(world.generationVersion==11)
local count=0;for _,town in ipairs(world:GetTowns()) do if town.role=='settlement' then assert(town.economy and #town.economy.resources==6);count=count+1 end end
assert(count>0);registry:Shutdown();print('PASS generated world persists town economy profiles')
