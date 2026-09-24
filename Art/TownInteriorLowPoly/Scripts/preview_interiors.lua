-- 从真实大地图入口连续走进设施，快照只读权威状态，不直接改队员坐标。
local Registry=require('Core.SystemRegistry');local registry=Registry(Services)
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('PlayerModel',require('Game.PlayerModelSystem'),{'Config'})
registry:Register('Map',require('Game.Map.MapSystem'),{'Config'})
registry:Register('MapArea',require('Game.MapArea.MapAreaSystem'),{'Config'})
registry:Register('Battle',require('Game.Battle.BattleSystem'),{'Config'})
registry:Register('AdventureEvents',require('Game.Adventure.EventSystem'),{'Battle','PlayerModel'})
registry:Register('Adventure',require('Game.Adventure.AdventureSystem'),{'Map','MapArea','AdventureEvents'})
local ok,layout,views=xpcall(function()
    registry:Start();local adventure,areas=registry:Get('Adventure'),registry:Get('MapArea');adventure:Start()
    local selected
    for _,site in ipairs(adventure.sites) do if site.areaConfigId==6 then selected=site;break end end
    assert(selected and adventure:Visit(selected.id))
    local area,state=areas:ActiveLayout(),Services.Adventure.Areas.Active;local result={}
    local function capture(name)
        local value=adventure:Snapshot();value.error='';result[#result+1]={name=name,view=value}
    end
    local function travel(index)
        local moved,reason
        for _=1,30 do
            moved,reason=areas:MoveToIndex(index)
            if moved then break end
            areas:Tick(.5)
        end
        if not moved then
            local blockers={};local path=area:FindPath(state.CellIndex,index)
            for _,cellIndex in ipairs(path or {}) do for i=0,state.NpcCount-1 do
                local npc=state:GetNpcAt(i)
                if npc.CellIndex==cellIndex then blockers[#blockers+1]='npc '..npc.Id..' at '..cellIndex..' patrol '..#area.npcs[npc.Id].route end
            end end
            error('Travel '..state.CellIndex..' to '..index..' failed: '..tostring(reason)..' blockers='..table.concat(blockers,';'))
        end
        for _=1,state.RemainingSteps do areas:Tick(area.moveStepSeconds+.001) end
        assert(state.CellIndex==index,'Route did not finish')
    end
    capture('city-overview')
    for _,room in ipairs(area.interiors) do
        local facility
        for _,value in ipairs(area.facilities) do if value.entryIndex==room.serviceIndex then facility=value;break end end
        assert(facility,'Interior service has no configured facility')
        travel(room.doorIndex);capture(facility.kind..'-door')
        travel(room.serviceIndex)
        assert(area.cells[state.CellIndex].interiorId==room.id)
        assert(areas:Interact(1,facility.id));assert(areas:CloseInteraction());capture(facility.kind..'-interior')
        travel(area.entryIndex)
        for i=0,state.MemberCount-1 do assert(not area.cells[state:GetMemberCellAt(i)].interiorId,'Follower remained inside') end
        capture(facility.kind..'-returned')
    end
    local saved=state.CellIndex;assert(areas:Leave());assert(adventure:Visit(selected.id))
    assert(Services.Adventure.Areas.Active.CellIndex==saved,'Re-entry changed party position')
    return areas:LayoutSnapshot(),result
end,debug.traceback)
registry:Shutdown();if not ok then error(layout,0) end
return layout,views
