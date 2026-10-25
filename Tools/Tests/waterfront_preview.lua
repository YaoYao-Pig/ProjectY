-- Actual generated city layout only; preview changes do not run travel, economy or saves.
local registry=require('Core.SystemRegistry')(Services)
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('Map',require('Game.Map.MapSystem'),{'Config'})
function GameShutdown()registry:Shutdown()end
registry:Start()
local config=registry:Get('Config')
local map=registry:Get('Map'):GenerateSeeded(20261025,10000,nil,nil,10)
local generator=require('Game.MapArea.MapAreaGenerator')(config)
generator:Register(2,require('Game.MapArea.TownGenerator'),'MapAreaTownTable','MapAreaTownThemeTable')
local entrances=setmetatable({config=config,entrances={},generator={definitions=config:GetTable('MapAreaTable')}},
    {__index=require('Game.MapArea.MapAreaSystem')})
for _,row in ipairs(config:GetTable('MapAreaEntranceTable'):All()) do entrances.entrances[row.townId]=generator.definitions:Get(row.areaId) end
local result={}
for _,site in ipairs(entrances:Entrances(map)) do if site.source.dock and (site.source.dock.id==2 or site.source.dock.id==3) then
    local area=generator:Generate(site.areaConfigId,map.seed,site.pointId,site.source)
    local facade={config=config,appearance=require('Game.Adventure.PawnAppearance').New(config),ActiveLayout=function()return area end}
    local layout=require('Game.MapArea.MapAreaSystem').LayoutSnapshot(facade)
    result[#result+1]={layout=layout,dockIndex=area.waterfront.landingIndex,direction=area.dock.direction,dockId=site.source.dock.id,
        waterCount=#area.dock.waterCells,cellCount=#area.cells}
end end
assert(#result==2,'Both reference waterfronts must exist')
return result
