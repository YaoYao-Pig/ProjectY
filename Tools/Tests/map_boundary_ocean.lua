-- Real world and waterfront snapshots; no expedition, gameplay clock or save writes.
local registry=require('Core.SystemRegistry')(Services)
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('Map',require('Game.Map.MapSystem'),{'Config'})
function GameShutdown() registry:Shutdown() end
registry:Start()
local config=registry:Get('Config')
local world=registry:Get('Map'):GenerateSeeded(20261025,10000,nil,nil,10)
local generator=require('Game.MapArea.MapAreaGenerator')(config)
if OceanPreviewShipwreck then
    generator:Register(5,require('Game.MapArea.ShipwreckGenerator'),'MapAreaShipwreckTable','MapAreaShipwreckThemeTable')
    local area=generator:Generate(40,42,100040,{regionType=3,biomeWeights={{regionType=3,weight=1}}})
    local facade={config=config,appearance=require('Game.Adventure.PawnAppearance').New(config),ActiveLayout=function()return area end}
    return require('Game.Map.MapRenderSnapshot')(world),require('Game.MapArea.MapAreaSystem').LayoutSnapshot(facade)
end
generator:Register(2,require('Game.MapArea.TownGenerator'),'MapAreaTownTable','MapAreaTownThemeTable')
local entrances=setmetatable({config=config,entrances={},generator={definitions=config:GetTable('MapAreaTable')}},
    {__index=require('Game.MapArea.MapAreaSystem')})
for _,row in ipairs(config:GetTable('MapAreaEntranceTable'):All()) do entrances.entrances[row.townId]=generator.definitions:Get(row.areaId) end
for _,site in ipairs(entrances:Entrances(world)) do if site.source.dock and site.source.dock.id==2 then
    local area=generator:Generate(site.areaConfigId,world.seed,site.pointId,site.source)
    local facade={config=config,appearance=require('Game.Adventure.PawnAppearance').New(config),ActiveLayout=function()return area end}
    return require('Game.Map.MapRenderSnapshot')(world),require('Game.MapArea.MapAreaSystem').LayoutSnapshot(facade)
end end
error('Reference waterfront missing')
