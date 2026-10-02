-- 独立真实 C# 状态；不启动 Play，不修改当前游戏会话。
local registry=require('Core.SystemRegistry')(Services)
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('PlayerModel',require('Game.PlayerModelSystem'),{'Config'})
registry:Register('Map',require('Game.Map.MapSystem'),{'Config'})
registry:Register('MapArea',require('Game.MapArea.MapAreaSystem'),{'Config'})
registry:Register('Battle',require('Game.Battle.BattleSystem'),{'Config'})
registry:Register('Growth',require('Game.Progression.GrowthSystem'),{'Battle'})
registry:Register('Equipment',require('Game.Equipment.EquipmentSystem'),{'Config'})
registry:Register('AdventureEvents',require('Game.Adventure.EventSystem'),{'Battle','PlayerModel','Growth','Equipment'})
registry:Register('Adventure',require('Game.Adventure.AdventureSystem'),{'Map','MapArea','AdventureEvents','Equipment'})
local ok,result=xpcall(function()
    registry:Start()
    local adventure,areas=registry:Get('Adventure'),registry:Get('MapArea')
    adventure:Start(20260921)
    local site
    for _,point in ipairs(adventure.sites) do if point.areaConfigId==50 then site=point;break end end
    assert(site,'Default expedition has no mine entrance')
    local accepted,reason=adventure:Visit(site.id);assert(accepted,reason)
    local area,state=areas:ActiveLayout(),Services.Adventure.Areas.Active
    assert(area.areaType==6 and area.layerCount==3 and state.MemberCount==4)
    local rows,frames,layers={},0,{}
    local function travel(target)
        local commands=0
        while state.CellIndex~=target do
            commands=commands+1;assert(commands<500,'Mine exploration failed to progress')
            local path=assert(area:FindPath(state.CellIndex,target),'Mine target unreachable')
            local step
            for i=1,math.min(5,#path) do
                if not state:IsKnown(path[i]) then break end
                step=path[i]
            end
            assert(step,'A navigable adjacent mine cell was hidden from exploration')
            local moved,why=areas:MoveToIndex(step,false);assert(moved,why)
            local count=state.RemainingSteps;assert(count>0,'Mine route has no frames')
            for _=1,count do
                local before={};for i=0,3 do before[i+1]=state:GetMemberCellAt(i) end
                areas:Tick(area.moveStepSeconds+.001);frames=frames+1
                local occupied={}
                for i=0,3 do
                    local nextIndex=state:GetMemberCellAt(i);local cell=area.cells[nextIndex]
                    assert(not cell.blocked and not occupied[nextIndex],'Mine squad overlap or blocked cell')
                    assert(nextIndex==before[i+1] or area:CanStep(area.cells[before[i+1]],cell),'Mine squad skipped a navigation edge')
                    occupied[nextIndex]=true;layers[cell.layer]=true
                end
            end
            assert(state.CellIndex==step,'Mine route ended on wrong floor')
        end
    end
    local function capture(name,opening)
        local view=adventure:Snapshot();view.error=''
        rows[#rows+1]={name=name,layout=areas:LayoutSnapshot(),view=view,
            focusIndex=opening and opening.lowerTargetIndex or state.CellIndex,
            lowerTargetIndex=opening and opening.lowerTargetIndex or 0}
    end
    capture('mine-arrival')
    for i=1,#area.openings do
        local opening=area.openings[i]
        travel(assert(opening.viewpointIndex))
        assert(state:IsKnown(opening.lowerTargetIndex),'Lower gallery not discovered through collapse')
        capture('mine-opening-'..opening.layer,opening)
    end
    travel(area.goalIndex);capture('mine-bottom')
    for _,stair in ipairs(area.stairs) do travel(stair.bottom);travel(stair.top) end
    assert(layers[0] and layers[1] and layers[2],'Mine exploration missed a floor')
    travel(area.entryIndex);capture('mine-upper-return')
    local positions={};for i=0,3 do positions[i+1]=state:GetMemberCellAt(i) end
    local known=state.KnownCount
    assert(adventure:AreaCommand('area_leave'))
    assert(adventure:Visit(site.id));state=Services.Adventure.Areas.Active
    assert(areas:ActiveLayout()==area and state.KnownCount==known,'Mine re-entry lost layout or discovery')
    for i=0,3 do assert(state:GetMemberCellAt(i)==positions[i+1],'Mine re-entry lost floor/position') end
    local report={passed=true,siteId=site.id,pointId=site.pointId,frames=frames,states=#rows,
        walkableCount=area.walkableCount,knownCount=known,checks={'world entrance','four-member three-floor exploration',
        'real collapse discovery','all stairs','return and re-entry'}}
    local json=assert(loadfile('Tools/MapPreview/json.lua'))()
    report.checks=json.array(report.checks)
    local file=assert(io.open('Docs/Previews/Mine/native-validation.json','wb'));file:write(json.encode(report));file:close()
    return rows
end,debug.traceback)
registry:Shutdown();if not ok then error(result,0) end
return result
