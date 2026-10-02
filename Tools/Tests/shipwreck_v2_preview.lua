-- 在现有独立FrameworkServices/LuaEnv内执行，返回真实{name,layout,view}状态供原渲染器预览。
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
    registry:Start();local adventure,areas=registry:Get('Adventure'),registry:Get('MapArea');adventure:Start(20260921)
    local site;for _,point in ipairs(adventure.sites) do if point.areaConfigId==40 then site=point;break end end
    assert(site and adventure:Visit(site.id),'Real shipwreck entrance failed')
    assert(not adventure:Visit(site.id),'Nested visit was accepted')
    local area,state=areas:ActiveLayout(),Services.Adventure.Areas.Active
    assert(area.generationVersion==2 and area.walkableCount>=1200 and state.MemberCount==4 and state.LootCount>=6)
    local rows={};local frames=0;local visitedLayers={}
    local function travel(index)
        local accepted,reason=areas:MoveToIndex(index);assert(accepted,reason)
        local count=state.RemainingSteps
        for _=1,count do
            local before={};for i=0,3 do before[i+1]=state:GetMemberCellAt(i) end
            areas:Tick(area.moveStepSeconds+.001);frames=frames+1
            local occupied={}
            for i=0,3 do local nextIndex=state:GetMemberCellAt(i);local cell=area.cells[nextIndex]
                assert(not cell.blocked and not occupied[nextIndex],'Real squad collided with ship navigation')
                assert(nextIndex==before[i+1] or area:CanStep(area.cells[before[i+1]],cell),'Real squad jumped between floors')
                occupied[nextIndex]=true;visitedLayers[cell.layer]=true
            end
        end
        assert(state.CellIndex==index and state.RemainingSteps==0,'Real squad stopped before its ship destination')
    end
    local function capture(name)
        local view=adventure:Snapshot();view.error=''
        rows[#rows+1]={name=name,layout=areas:LayoutSnapshot(),view=view}
    end
    capture('ship-arrival-main')
    travel(area.stairs[1].top);travel(area.stairs[1].bottom);travel(area.rooms[2].center);capture('ship-lower-cargo')
    travel(area.rooms[1].center);capture('ship-lower-crew')
    travel(area.rooms[3].center);capture('ship-lower-galley')
    travel(area.stairs[2].bottom);travel(area.stairs[2].top);travel(area.rooms[7].center);capture('ship-main-restored')
    travel(area.stairs[3].bottom);travel(area.stairs[3].top);travel(area.rooms[9].center);capture('ship-forecastle-upper')
    travel(area.stairs[3].top);travel(area.stairs[3].bottom)
    travel(area.stairs[4].bottom);travel(area.stairs[4].top);travel(area.rooms[8].center);capture('ship-aftcastle-upper')
    travel(area.stairs[4].top);travel(area.stairs[4].bottom);travel(area.rooms[5].center);capture('ship-captain-interior')
    travel(area.rooms[7].center);capture('ship-exterior-restored')
    assert(visitedLayers[0] and visitedLayers[1] and visitedLayers[2])
    local cells={};for i=0,3 do cells[i+1]=state:GetMemberCellAt(i) end
    local lootCount=state.LootCount
    assert(adventure:AreaCommand('area_leave') and Services.Adventure.Phase=='map')
    assert(adventure:Visit(site.id));state=Services.Adventure.Areas.Active
    assert(areas:ActiveLayout()==area and state.LootCount==lootCount)
    for i=0,3 do assert(state:GetMemberCellAt(i)==cells[i+1],'Ship re-entry changed member floor or position') end
    travel(area.entryIndex);assert(adventure:AreaCommand('area_leave'))
    local project=CS.System.IO.Directory.GetParent(CS.UnityEngine.Application.dataPath).FullName
    local json=assert(loadfile(project..'/Tools/MapPreview/json.lua'))()
    local function serial(value)
        if type(value)~='table' then return value end
        local out={};for k,v in pairs(value) do out[k]=serial(v) end
        return (#value>0 or next(out)==nil) and json.array(out) or out
    end
    local function save(name,value)
        local file=assert(io.open(project..'/Art/AssetExpansion202610/ShipwreckV2/Integration/'..name,'wb'))
        file:write(json.encode(serial(value)));file:close()
    end
    -- Adventure 快照可包含供 C# 读取的 userdata；档案只存本检查的明确原生字段，
    -- 完整 view 仍由返回 rows 直接交给原有 AdventureViewData.Read。
    local states={};for _,row in ipairs(rows) do
        local view=row.view.area
        states[#states+1]={name=row.name,cellIndex=view.cellIndex,layer=row.layout.cells[view.cellIndex].layer,
            memberCount=#view.members}
    end
    save('native_states.json',states)
    save('native_validation.json',{passed=true,frames=frames,states=#rows,walkableCount=area.walkableCount,lootCount=lootCount,
        checks={'real world visit','four-member three-layer movement','both cargo stairs','fore and aft raised platforms','captain interior and exterior restoration','leave and re-entry persistence'}})
    return rows
end,debug.traceback)
registry:Shutdown();if not ok then error(result,0) end
return result
