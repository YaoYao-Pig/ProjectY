-- 使用真实大地图入口和运行时命令生成验收快照，绝不直接修改小队占格。
local Registry=require('Core.SystemRegistry');local registry=Registry(Services)
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('PlayerModel',require('Game.PlayerModelSystem'),{'Config'})
registry:Register('Map',require('Game.Map.MapSystem'),{'Config'})
registry:Register('MapArea',require('Game.MapArea.MapAreaSystem'),{'Config'})
registry:Register('Battle',require('Game.Battle.BattleSystem'),{'Config'})
registry:Register('AdventureEvents',require('Game.Adventure.EventSystem'),{'Battle','PlayerModel'})
registry:Register('Adventure',require('Game.Adventure.AdventureSystem'),{'Map','MapArea','AdventureEvents'})
local ok,layout,snapshot,bridgeSnapshot,underSnapshot=xpcall(function()
    registry:Start();local adventure,areas=registry:Get('Adventure'),registry:Get('MapArea');adventure:Start()
    local selected
    for _,site in ipairs(adventure.sites) do if site.areaConfigId==6 then selected=site;break end end
    assert(selected and adventure:Visit(selected.id))
    local area,state=areas:ActiveLayout(),Services.Adventure.Areas.Active
    local destination
    for _,facility in ipairs(area.facilities) do if facility.kind=='palace' then destination=facility;break end end
    destination=destination or area.facilities[2]
    local door=area.cells[destination.entryIndex]
    assert(areas:MoveTo(door.q,door.r))
    local steps=state.RemainingSteps
    for _=1,steps do areas:Tick(area.moveStepSeconds+.001) end
    assert(areas:Interact(1,destination.id));assert(state.InteractionId==destination.id);assert(areas:CloseInteraction())
    local result=adventure:Snapshot();result.error=''
    -- 上下层分别沿真实路线抵达，截图只是显示这些独立快照，不改权威占格。
    local deck,best,bridgeR,bridgeU,bridgeCount=nil,nil,0,0,0
    for _,cell in ipairs(area.cells) do if cell.layer==1 then bridgeR=bridgeR+cell.localR;bridgeU=bridgeU+cell.localQ+cell.localR/2;bridgeCount=bridgeCount+1 end end
    assert(bridgeCount>0);bridgeR=bridgeR/bridgeCount;bridgeU=bridgeU/bridgeCount
    for _,cell in ipairs(area.cells) do if cell.layer==1 then
        local distance=math.abs(cell.localQ+cell.localR/2-bridgeU)+math.abs(cell.localR-bridgeR)
        if not best or distance<best then deck,best=cell,distance end
    end end
    local function travel(cell)
        for _=1,30 do if not state:IsNpcOccupied(cell.index) then break end;areas:Tick(.5) end
        assert(areas:MoveToIndex(cell.index))
        for _=1,state.RemainingSteps do areas:Tick(area.moveStepSeconds+.001) end
        assert(state.CellIndex==cell.index)
        local value=adventure:Snapshot();value.error='';return value
    end
    local bridge=travel(assert(deck));local under=travel(assert(area:Find(deck.q,deck.r)))
    local saved=state.CellIndex;assert(areas:Leave() and Services.Adventure.Phase=='map')
    assert(adventure:Visit(selected.id) and Services.Adventure.Areas.Active.CellIndex==saved,'Royal re-entry lost party position')
    return areas:LayoutSnapshot(),result,bridge,under
end,debug.traceback)
registry:Shutdown();if not ok then error(layout,0) end
return layout,snapshot,bridgeSnapshot,underSnapshot
