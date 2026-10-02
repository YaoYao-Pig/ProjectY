-- Isolated real C# state: walk into both new upper floors and return without changing the live Editor session.
local Registry=require('Core.SystemRegistry');local registry=Registry(Services)
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
    registry:Start();local adventure,areas=registry:Get('Adventure'),registry:Get('MapArea');adventure:Start()
    local output={}
    local function visit(id)
        for _,site in ipairs(adventure.sites) do if site.areaConfigId==id then
            assert(adventure:Visit(site.id));return site
        end end
        error('Preview area has no world entrance: '..id)
    end
    local site=visit(6);local area,state=areas:ActiveLayout(),Services.Adventure.Areas.Active
    local function travel(index)
        local moved,reason
        for _=1,30 do
            moved,reason=areas:MoveToIndex(index);if moved then break end;areas:Tick(.5)
        end
        if not moved then
            local route=area:FindPath(state.CellIndex,index);local details={}
            local ids={};for i=0,state.MemberCount-1 do ids[#ids+1]=state:GetMemberIdAt(i) end
            local shape=areas:SquadFootprint(area,ids)
            for _,nextIndex in ipairs(route or {}) do
                local cell=area.cells[nextIndex];local footprint=shape(nextIndex,1)
                details[#details+1]=string.format('%d(%d,%d,L%d) known=%s npc=%s footprint=%s',nextIndex,cell.q,cell.r,cell.layer,
                    tostring(state:IsKnown(nextIndex)),tostring(state:IsNpcOccupied(nextIndex)),footprint and table.concat(footprint,',') or 'nil')
            end
            error('Multilevel route '..state.CellIndex..' -> '..index..': '..tostring(reason)..' / '..table.concat(details,'; '))
        end
        local steps=state.RemainingSteps
        for _=1,steps do areas:Tick(area.moveStepSeconds+.001) end
        assert(state.CellIndex==index,'Multilevel route did not reach its target')
    end
    local function capture(name)
        local view=adventure:Snapshot();view.error='';output[#output+1]={name=name,layout=areas:LayoutSnapshot(),view=view}
    end
    capture('town-arrival')
    for _,room in ipairs(area.interiors) do if room.upperEntryIndex then
        local name=room.lotId==1 and 'tavern' or 'guild'
        travel(room.serviceIndex)
        local serviceNpc
        for i=0,state.NpcCount-1 do local npc=state:GetNpcAt(i)
            if npc.CellIndex==room.serviceNpcIndex then serviceNpc=npc.Id;break end
        end
        assert(serviceNpc and areas:Interact(2,serviceNpc));assert(areas:CloseInteraction())
        capture(name..'-ground')
        travel(room.upperEntryIndex);capture(name..'-upper')
        assert(area.cells[state.CellIndex].layer==1)
        assert(not areas:Interact(2,serviceNpc),'Upper floor spoke through its floor slab')
        local members,npcs={},{}
        for i=0,state.MemberCount-1 do members[i]=state:GetMemberCellAt(i) end
        for i=0,state.NpcCount-1 do npcs[i]=state:GetNpcAt(i).CellIndex end
        local top=state.CellIndex;assert(areas:Leave());assert(adventure:Visit(site.id));state=Services.Adventure.Areas.Active
        assert(state.CellIndex==top,'Re-entry lost upper floor identity')
        for i=0,state.MemberCount-1 do assert(members[i]==state:GetMemberCellAt(i)) end
        for i=0,state.NpcCount-1 do assert(npcs[i]==state:GetNpcAt(i).CellIndex) end
        travel(room.serviceIndex);travel(area.entryIndex)
        for i=0,state.MemberCount-1 do assert(area.cells[state:GetMemberCellAt(i)].layer==0) end
    end end
    assert(areas:Leave());visit(1);area,state=areas:ActiveLayout(),Services.Adventure.Areas.Active
    local blocked=adventure.obstacles:BlockedCells();local enemies=areas:EnemyOccupancy(area,state)
    local queue,seen,head={state.CellIndex},{[state.CellIndex]=true},1;local goal
    while head<=#queue and not goal do
        local index=queue[head];head=head+1;local cell=area.cells[index]
        if cell.stairRise>0 and cell.height>=1 and cell.height<=2.5 then goal=index;break end
        for _,other in ipairs(area:Neighbors(cell)) do if not seen[other.index] and not blocked[other.index] and not enemies[other.index] then
            seen[other.index]=true;queue[#queue+1]=other.index
        end end
    end
    assert(goal,'No reachable staircase for the dungeon view')
    local path=assert(area:FindPath(state.CellIndex,goal,function(cell)return not blocked[cell.index] and not enemies[cell.index]end))
    for _,index in ipairs(path) do travel(index) end
    capture('dungeon-terraces')
    return output
end,debug.traceback)
registry:Shutdown();if not ok then error(result,0) end
return result
