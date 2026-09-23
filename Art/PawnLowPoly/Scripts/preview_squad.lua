-- Edit Mode 资源验收：真实远征、真实入口、真实角色和生产快照，不启动 Play。
local Registry=require('Core.SystemRegistry');local registry=Registry(Services)
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('PlayerModel',require('Game.PlayerModelSystem'),{'Config'})
registry:Register('Map',require('Game.Map.MapSystem'),{'Config'})
registry:Register('MapArea',require('Game.MapArea.MapAreaSystem'),{'Config'})
registry:Register('Battle',require('Game.Battle.BattleSystem'),{'Config'})
registry:Register('AdventureEvents',require('Game.Adventure.EventSystem'),{'Battle','PlayerModel'})
registry:Register('Adventure',require('Game.Adventure.AdventureSystem'),{'Map','MapArea','AdventureEvents'})
local ok,layout,snapshot=xpcall(function()
    registry:Start();local adventure,areas=registry:Get('Adventure'),registry:Get('MapArea')
    adventure:Start()
    for _,site in ipairs(adventure.sites) do
        if site.areaConfigId==1 then
            assert(adventure:Visit(site.id))
            local area,state=areas:ActiveLayout(),Services.Adventure.Areas.Active
            -- 取入口附近已知地面上的六格行程，使截图同时验收移动后的编队装配。
            local destination
            for i=0,state.KnownCount-1 do
                local cell=area.cells[state:GetKnownAt(i)]
                local path=not cell.blocked and area:FindPath(state.CellIndex,cell.index,function(c) return state:IsKnown(c.index) end)
                if path and #path==6 then destination=cell;break end
            end
            assert(destination and areas:MoveTo(destination.q,destination.r))
            local steps=state.RemainingSteps
            for _=1,steps do areas:Tick(area.moveStepSeconds+.01) end
            local result=adventure:Snapshot();result.error=''
            return areas:LayoutSnapshot(),result
        end
    end
    error('No dungeon entrance in demo world')
end,debug.traceback)
registry:Shutdown()
if not ok then error(layout,0) end
return layout,snapshot
