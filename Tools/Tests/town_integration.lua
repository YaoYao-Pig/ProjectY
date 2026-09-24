-- 使用真实 C# Data、配置与 Lua 规则核对城镇；不进入 Play，不改编辑场景。
local Registry=require('Core.SystemRegistry');local registry=Registry(Services)
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('PlayerModel',require('Game.PlayerModelSystem'),{'Config'})
registry:Register('Map',require('Game.Map.MapSystem'),{'Config'})
registry:Register('MapArea',require('Game.MapArea.MapAreaSystem'),{'Config'})
registry:Register('Battle',require('Game.Battle.BattleSystem'),{'Config'})
registry:Register('AdventureEvents',require('Game.Adventure.EventSystem'),{'Battle','PlayerModel'})
registry:Register('Equipment',require('Game.Equipment.EquipmentSystem'),{'Config'})
registry:Register('Adventure',require('Game.Adventure.AdventureSystem'),{'Map','MapArea','AdventureEvents','Equipment'})
local Hex=require('Game.Map.HexGrid');local count,messages=0,{}
local function test(name,run) run();count=count+1;messages[#messages+1]='PASS '..name end
local ok,err=xpcall(function()
    registry:Start();local adventure,areas=registry:Get('Adventure'),registry:Get('MapArea');adventure:Start()
    local site
    for _,candidate in ipairs(adventure.sites) do if candidate.areaConfigId and candidate.areaConfigId~=1 then
        site=candidate;if candidate.areaConfigId==2 then break end
    end end
    assert(site and adventure:Visit(site.id))
    local layout,state=areas:ActiveLayout(),Services.Adventure.Areas.Active
    local function valid()
        local occupied={}
        for i=0,state.MemberCount-1 do
            local index=state:GetMemberCellAt(i);assert(not occupied[index] and not layout.cells[index].blocked);occupied[index]=true
        end
        for i=0,state.NpcCount-1 do
            local npc=state:GetNpcAt(i);assert(not occupied[npc.CellIndex] and not layout.cells[npc.CellIndex].blocked)
            occupied[npc.CellIndex]=true
        end
    end
    local function tick(dt)
        local old={};for i=0,state.NpcCount-1 do old[i]=state:GetNpcAt(i).CellIndex end
        areas:Tick(dt);valid()
        for i=0,state.NpcCount-1 do
            local a,b=layout.cells[old[i]],layout.cells[state:GetNpcAt(i).CellIndex]
            assert(a.index==b.index or layout:CanStep(a,b),'NPC crossed a cliff or changed floors without a connecting edge')
        end
    end
    local function finishRoute()
        local steps=state.RemainingSteps
        for _=1,steps do tick(layout.moveStepSeconds+.001) end
        assert(state.RemainingSteps==0)
    end
    test('real town entrance, open discovery, four members, NPCs and C# presentation',function()
        assert(layout.areaType==2 and state.CellCount==#layout.cells and state.CellCount>4096 and state.KnownCount==state.CellCount)
        assert(state.MemberCount==4 and state.NpcCount==#layout.npcs);valid()
        local snapshot=adventure:Snapshot();snapshot.error=''
        local view=CS.ProjectY.Samples.AdventureViewData.Read(snapshot)
        local tiles=CS.ProjectY.Samples.MapAreaViewData.Read(areas:LayoutSnapshot())
        assert(tiles.IsTown and tiles.Facilities.Length==#layout.facilities and tiles.Npcs.Length==state.NpcCount)
        assert(view.Area.Npcs.Length==state.NpcCount and tiles.MoveStepSeconds==.5)
        -- Lua 的只读代理有 __len，但 xLua Length 读原始长度；必须检查真正跨到 C# 后的数组。
        for i=0,tiles.Cells.Length-1 do
            local cell=tiles.Cells[i];local original=layout.cells[i+1]
            assert(cell.Corners.Length==6 and cell.Neighbors.Length==6,'Frozen cell arrays were not copied into the snapshot')
            for d=0,5 do
                assert(math.abs(cell.Corners[d]-original.corners[d+1])<.00001)
                assert(cell.Neighbors[d]==original.neighbors[d+1]-1)
            end
        end
        for i=0,tiles.Npcs.Length-1 do assert(tiles.Npcs[i].Appearance.Parts.Length==2) end
    end)
    test('patrol moves with unique cells and adjacent steps',function()
        local before={};for i=0,state.NpcCount-1 do before[i]=state:GetNpcAt(i).CellIndex end
        for _=1,24 do tick(.5) end
        local moved=false;for i=0,state.NpcCount-1 do if before[i]~=state:GetNpcAt(i).CellIndex then moved=true end end
        assert(moved,'Patrol never advanced')
    end)
    test('facility approach, reserved squad route and distance-checked interaction',function()
        local facility=layout.facilities[1];assert(not areas:Interact(1,facility.id))
        -- 目标若正好有居民经过，等待其巡游离开，不强行改位置。
        for _=1,24 do if not state:IsNpcOccupied(facility.entryIndex) then break end;tick(.5) end
        local cell=layout.cells[facility.entryIndex];assert(areas:MoveTo(cell.q,cell.r));finishRoute()
        assert(areas:Interact(1,facility.id) and state.InteractionKind==1)
        assert(not areas:MoveTo(cell.q,cell.r));assert(areas:CloseInteraction())
    end)
    test('NPC interaction holds its position; keyboard uses the same squad planner',function()
        local npc=state:GetNpcAt(0);local target
        for _,cell in ipairs(layout:Neighbors(layout.cells[npc.CellIndex])) do
            if not state:IsNpcOccupied(cell.index) and areas:MoveTo(cell.q,cell.r) then target=cell;break end
        end
        assert(target);finishRoute();assert(areas:Interact(2,npc.Id))
        local before=npc.CellIndex;for _=1,4 do tick(.5) end;assert(npc.CellIndex==before)
        assert(areas:CloseInteraction())
        local moved=false
        for direction=1,6 do if areas:Walk(direction) then finishRoute();moved=true;break end end
        assert(moved);assert(areas:Stop());valid()
    end)
    test('four members traverse the bridge and then its separate underpass',function()
        local deck
        for _,cell in ipairs(layout.cells) do if cell.layer==1 and not state:IsNpcOccupied(cell.index) then deck=cell;break end end
        assert(deck and areas:MoveToIndex(deck.index));finishRoute();assert(state.CellIndex==deck.index)
        local below=layout:Find(deck.q,deck.r)
        for _=1,20 do if not state:IsNpcOccupied(below.index) then break end;tick(.5) end
        assert(areas:MoveToIndex(below.index));assert(state.RemainingSteps>10);finishRoute()
        assert(state.CellIndex==below.index and below.layer==0);valid()
        local snapshot=adventure:Snapshot();snapshot.error=''
        local view=CS.ProjectY.Samples.AdventureViewData.Read(snapshot)
        local tiles=CS.ProjectY.Samples.MapAreaViewData.Read(areas:LayoutSnapshot())
        assert(tiles.Cells[deck.index-1].Layer==1 and tiles.Cells[below.index-1].Layer==0)
        assert(tiles:StreetDistance(deck.index-1,below.index-1,2)==2147483647)
        assert(view.Area.CellIndex==below.index-1)
    end)
    test('reenter keeps positions and does not duplicate residents',function()
        local members,npcs={},{}
        for i=0,state.MemberCount-1 do members[i]=state:GetMemberCellAt(i) end
        for i=0,state.NpcCount-1 do npcs[i]=state:GetNpcAt(i).CellIndex end
        assert(areas:Leave() and adventure:Visit(site.id));state=Services.Adventure.Areas.Active
        assert(state.NpcCount==#layout.npcs)
        for i=0,state.MemberCount-1 do assert(state:GetMemberCellAt(i)==members[i]) end
        for i=0,state.NpcCount-1 do assert(state:GetNpcAt(i).CellIndex==npcs[i]) end
        assert(state.InteractionKind==0);valid()
    end)
end,debug.traceback)
registry:Shutdown();if not ok then error(err,0) end
return 'Town integration: '..count..' checks passed\n'..table.concat(messages,'\n')
