-- Read-only render fixture: real expedition -> royal town, without routes, saves or UI.
local registry=require('Core.SystemRegistry')(Services)
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('PlayerModel',require('Game.PlayerModelSystem'),{'Config'})
registry:Register('Map',require('Game.Map.MapSystem'),{'Config'})
registry:Register('MapArea',require('Game.MapArea.MapAreaSystem'),{'Config'})
registry:Register('Battle',require('Game.Battle.BattleSystem'),{'Config'})
registry:Register('Equipment',require('Game.Equipment.EquipmentSystem'),{'Config'})
registry:Register('Growth',require('Game.Progression.GrowthSystem'),{'Battle'})
registry:Register('AdventureEvents',require('Game.Adventure.EventSystem'),{'Battle','PlayerModel','Growth','Equipment'})
registry:Register('Adventure',require('Game.Adventure.AdventureSystem'),{'Map','MapArea','AdventureEvents','Equipment'})
local ok,layout,view,lighting=xpcall(function()
    registry:Start()
    local adventure,areas=registry:Get('Adventure'),registry:Get('MapArea')
    adventure:Start()
    local selected
    for _,site in ipairs(adventure.sites) do if site.areaConfigId==6 then selected=site;break end end
    assert(selected and adventure:Visit(selected.id),'Royal town fixture unavailable')
    local snapshot=adventure:Snapshot();snapshot.error=''
    return areas:LayoutSnapshot(),snapshot,require('Game.Rendering.MapPresentation').Snapshot(registry:Get('Config'))
end,debug.traceback)
registry:Shutdown()
if not ok then error(layout,0) end
return layout,view,lighting
