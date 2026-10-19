package.path='Lua/?.lua;'..package.path
local registry=require('Core.SystemRegistry')({ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local bytes=file:read('*a');file:close();return bytes
end,LogError=error})
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('Map',require('Game.Map.MapSystem'),{'Config'});registry:Start()
local config=registry:Get('Config')
local areas=require('Game.MapArea.MapAreaSystem')();areas.config=config
areas.generator=require('Game.MapArea.MapAreaGenerator')(config);areas.entrances={}
for _,row in ipairs(config:GetTable('MapAreaEntranceTable'):All())do areas.entrances[row.townId]=areas.generator.definitions:Get(row.areaId)end
local adventure=require('Game.Adventure.AdventureSystem')();adventure.config=config;adventure.mapSystem=registry:Get('Map');adventure.areas=areas
adventure.events={events=config:GetTable('AdventureEventTable')};adventure.travel={maxStep=config:GetTable('WorldTravelTable'):Get(1).maxHeightStep}
local target=tonumber(os.getenv('PROJECT_Y_TEST_CELLS')) or 10000
local world=adventure:BuildWorld(20261016,3,target)
assert(#world.map:GetCells()==target and world.recipe.id==3 and world.recipe.equipmentRecipeId==2)
assert(adventure.map==nil and adventure.sites==nil,'Preparing a world mutated the active world')
local market;for _,site in ipairs(world.sites)do if site.areaConfigId==world.recipe.startAreaId then market=site;break end end
assert(market,'Formal campaign omitted the narrative town')
local camp=world.sites[1];assert(require('Game.Map.HexGrid').Distance(camp.q,camp.r,market.q,market.r)==1)
assert(math.abs(world.map:GetCell(camp.q,camp.r).height-world.map:GetCell(market.q,market.r).height)<=adventure.travel.maxStep)
print('PASS formal '..target..'-cell campaign recipe, reachable narrative town, immutable preparation and starter equipment routing')
for _,file in ipairs({'Lua/Game/Adventure/CharacterSave.lua','Lua/Game/Adventure/ExpeditionSave.lua','Lua/Game/Adventure/DemoBridge.lua','Lua/Game/Adventure/MainHudModel.lua'})do assert(loadfile(file))end
registry:Shutdown()
