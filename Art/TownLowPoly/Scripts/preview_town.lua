-- 使用真实大地图入口和运行时命令生成验收快照，绝不直接修改小队占格。
local Registry=require('Core.SystemRegistry');local registry=Registry(Services)
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('PlayerModel',require('Game.PlayerModelSystem'),{'Config'})
registry:Register('Map',require('Game.Map.MapSystem'),{'Config'})
registry:Register('MapArea',require('Game.MapArea.MapAreaSystem'),{'Config'})
registry:Register('Battle',require('Game.Battle.BattleSystem'),{'Config'})
registry:Register('AdventureEvents',require('Game.Adventure.EventSystem'),{'Battle','PlayerModel'})
registry:Register('Adventure',require('Game.Adventure.AdventureSystem'),{'Map','MapArea','AdventureEvents'})
local ok,layout,snapshot=xpcall(function()
    registry:Start();local adventure,areas=registry:Get('Adventure'),registry:Get('MapArea');adventure:Start()
    local selected
    for _,site in ipairs(adventure.sites) do if site.areaConfigId and site.areaConfigId~=1 then
        selected=site;if site.areaConfigId==2 then break end
    end end
    assert(selected and adventure:Visit(selected.id))
    local area,state=areas:ActiveLayout(),Services.Adventure.Areas.Active
    local destination
    for _,facility in ipairs(area.facilities) do if facility.kind=='smithy' then destination=facility;break end end
    destination=destination or area.facilities[2]
    local door=area.cells[destination.entryIndex]
    assert(areas:MoveTo(door.q,door.r))
    local steps=state.RemainingSteps
    for _=1,steps do areas:Tick(area.moveStepSeconds+.001) end
    local result=adventure:Snapshot();result.error=''
    return areas:LayoutSnapshot(),result
end,debug.traceback)
registry:Shutdown();if not ok then error(layout,0) end
return layout,snapshot
