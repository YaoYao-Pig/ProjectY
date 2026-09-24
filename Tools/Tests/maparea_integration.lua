-- Editor 独立 LuaEnv 最小集成：真实 C# 状态、真实入口与配置，不依赖 Play 场景。
local Registry=require('Core.SystemRegistry')
local registry=Registry(Services)
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('PlayerModel',require('Game.PlayerModelSystem'),{'Config'})
registry:Register('Map',require('Game.Map.MapSystem'),{'Config'})
registry:Register('MapArea',require('Game.MapArea.MapAreaSystem'),{'Config'})
registry:Register('Battle',require('Game.Battle.BattleSystem'),{'Config'})
registry:Register('AdventureEvents',require('Game.Adventure.EventSystem'),{'Battle','PlayerModel'})
registry:Register('Equipment',require('Game.Equipment.EquipmentSystem'),{'Config'})
registry:Register('Adventure',require('Game.Adventure.AdventureSystem'),{'Map','MapArea','AdventureEvents','Equipment'})
local count,messages=0,{}
local function test(name,run) run();count=count+1;messages[#messages+1]='PASS '..name end
local function rejects(run) assert(not pcall(run),'Expected invalid state rejection') end
local ok,err=xpcall(function()
    registry:Start()
    local adventure,areas=registry:Get('Adventure'),registry:Get('MapArea')
    local data=Services.Adventure
    adventure:Start()
    test('four-person party limit is enforced by real data',function()
        assert(data.PartyCount==4)
        rejects(function() data:AddPartyActor(5,1) end)
        assert(data.PartyCount==4)
    end)
    local site,town
    test('real world points use configured area types and a single entrance per settlement',function()
        local points={}
        for _,candidate in ipairs(adventure.sites) do
            if candidate.areaConfigId then
                assert(not points[candidate.pointId]);points[candidate.pointId]=true
                if candidate.areaConfigId==1 then site=site or candidate else town=candidate end
            end
        end
        assert(site,'Demo recipe did not generate a dungeon entrance')
        assert(town and adventure:Visit(town.id) and data.Phase=='area')
        assert(areas:Leave() and data.Phase=='map')
        assert(adventure:Visit(site.id) and data.Phase=='area')
        assert(not adventure:Visit(site.id),'Cannot nest an area entry')
    end)
    local layout=areas:ActiveLayout();local state=data.Areas.Active
    test('Lua to C# snapshots preserve cell indices, colors and actual source Region',function()
        assert(state.CellCount==9216 and state.CellIndex==layout.entryIndex)
        assert(layout.source.regionId==site.source.regionId and state.KnownCount>0 and state.KnownCount<9216)
        local snapshot=adventure:Snapshot();snapshot.error=''
        local view=CS.ProjectY.Samples.AdventureViewData.Read(snapshot)
        local tiles=CS.ProjectY.Samples.MapAreaViewData.Read(areas:LayoutSnapshot())
        assert(view.Area.CellIndex==state.CellIndex-1 and tiles.Cells.Length==state.CellCount)
        assert(state.MemberCount==4 and view.Area.Members.Length==4 and tiles.Radius==1.5)
        for i=0,3 do
            assert(view.Area.Members[i].ActorId==data:GetPartyAt(i).Id)
            assert(view.Area.Members[i].CellIndex==state:GetMemberCellAt(i)-1)
            assert(view.Party[i].Appearance.Parts.Length>=6)
        end
        assert(tiles.Cells[0].Color.r>0 and tiles.Cells[0].Color.a==1)
        assert(tiles.AssetId==layout.theme.assetId)
        assert(tiles.Rooms.Length==10 and tiles.Props.Length==#layout.props and tiles.CorridorWidth==5)
        local used={};local usedCount=0
        for _,prop in ipairs(layout.props) do if not used[prop.assetId] then used[prop.assetId]=true;usedCount=usedCount+1 end end
        assert(view.Area.PropCount==#layout.props and tiles.PropAssets.Length==usedCount)
        for i=0,tiles.Props.Length-1 do
            local prop=tiles.Props[i]
            assert(prop.Cells.Length>=1 and prop.Scale>0)
            for j=0,prop.Cells.Length-1 do assert(tiles.Cells[prop.Cells[j]].Blocked) end
        end
    end)
    test('walls and unknown destinations are rejected without mutating the route',function()
        local wall,unknown
        for _,cell in ipairs(layout.cells) do
            if cell.blocked then wall=cell elseif not state:IsKnown(cell.index) then unknown=cell end
            if wall and unknown then break end
        end
        assert(not areas:MoveTo(wall.q,wall.r));assert(not areas:MoveTo(unknown.q,unknown.r))
        assert(state.RemainingSteps==0 and state.CellIndex==layout.entryIndex)
        rejects(function() state:SetRoute({state.CellCount+1}) end)
        local first=state:GetMemberCellAt(0)
        rejects(function() state:SetSquadRoute({first,first,first,first}) end)
        assert(state.RemainingSteps==0)
    end)
    local destination
    test('real C# movement follows known hex paths, reveals walls and stops on command',function()
        local furthest=-1
        for i=0,state.KnownCount-1 do
            local cell=layout.cells[state:GetKnownAt(i)]
            if not cell.blocked then
                local path=layout:FindPath(state.CellIndex,cell.index,function(next) return state:IsKnown(next.index) end)
                if path and #path>furthest then destination=cell;furthest=#path end
            end
        end
        assert(furthest>1 and areas:MoveTo(destination.q,destination.r))
        local before=state.CellIndex;areas:Tick(0);assert(state.CellIndex==before)
        areas:Tick(layout.moveStepSeconds+0.01);assert(state.CellIndex~=before)
        assert(areas:Stop() and state.RemainingSteps==0)
        assert(areas:MoveTo(destination.q,destination.r))
        local steps=state.RemainingSteps;local discovered=state.KnownCount
        for _=1,steps do
            local before={};for i=0,state.MemberCount-1 do before[i+1]=state:GetMemberCellAt(i) end
            areas:Tick(layout.moveStepSeconds+0.01)
            local used={}
            for i=0,state.MemberCount-1 do
                local cell=layout.cells[state:GetMemberCellAt(i)];local old=layout.cells[before[i+1]]
                assert(not cell.blocked and not used[cell.index]);used[cell.index]=true
                assert(require('Game.Map.HexGrid').Distance(old.q,old.r,cell.q,cell.r)<=1)
            end
        end
        assert(state.CellIndex==destination.index and state.KnownCount>=discovered and state.RemainingSteps==0)
        local center=layout.cells[state.CellIndex];local board=areas:BattleWindow(state.CellIndex,6)
        assert(board:Find(center.q,center.r)==center)
    end)
    test('re-entry preserves the same layout, position and discovery; new expedition clears records',function()
        local known=state.KnownCount
        local occupied={};for i=0,3 do occupied[i+1]=state:GetMemberCellAt(i) end
        assert(areas:Leave() and data.Phase=='map' and data.Areas.ActiveSiteId==0)
        assert(adventure:Visit(site.id) and areas:ActiveLayout()==layout)
        assert(data.Areas.Active.CellIndex==destination.index and data.Areas.Active.KnownCount==known)
        for i=0,3 do assert(data.Areas.Active:GetMemberCellAt(i)==occupied[i+1]) end
        assert(areas:Leave());adventure:Start()
        assert(data.Areas.ActiveSiteId==0 and next(areas.layouts)==nil)
    end)
end,debug.traceback)
registry:Shutdown()
if not ok then error(err,0) end
return 'MapArea integration: '..count..' checks passed\n'..table.concat(messages,'\n')
