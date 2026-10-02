-- Unity Edit Mode 专用输入：独立 Services/真实 C# 占格；不改现场远征或伪造人物位置。
-- 返回去重的 layouts 与 captures；layoutIndex、propIndex、门洞索引均为 Lua 的 1 基索引。
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
local Hex=require('Game.Map.HexGrid')
local ok,result=xpcall(function()
    registry:Start();local adventure,areas=registry:Get('Adventure'),registry:Get('MapArea')
    adventure:Start(rawget(_G,'OpenBuildingPreviewSeed'))
    local result={seed=Services.Adventure.Seed,layouts={},captures={},checks={}}
    result.environment=require('Game.Rendering.MapPresentation').Snapshot(registry:Get('Config'))
    local wanted={[14]=74,[15]=75,[16]=76,[18]=55,[19]=56,[31]=113,[32]=114}
    local done={};local area,state,site,layoutIndex;local totalFrames=0
    local function members()
        local values={}
        for i=0,state.MemberCount-1 do values[i+1]={id=state:GetMemberIdAt(i),cell=state:GetMemberCellAt(i)} end
        return values
    end
    local function validate()
        assert(Services.Adventure.Phase=='area' and state.MemberCount==4,'Preview needs a live four-member exploration squad')
        local occupied={}
        for _,member in ipairs(members()) do
            assert(not area.cells[member.cell].blocked and not occupied[member.cell],'Invalid squad occupancy')
            occupied[member.cell]=true
        end
        for i=0,state.NpcCount-1 do local npc=state:GetNpcAt(i)
            if npc.Present then
                assert(not area.cells[npc.CellIndex].blocked and not occupied[npc.CellIndex],'NPC overlaps blocked ground or another actor')
                occupied[npc.CellIndex]=true
            end
        end
    end
    local function tick(dt)
        local before=members();areas:Tick(dt);validate()
        for i,member in ipairs(before) do local nextIndex=state:GetMemberCellAt(i-1)
            assert(nextIndex==member.cell or area:CanStep(area.cells[member.cell],area.cells[nextIndex]),'A real squad member skipped a navigation edge')
        end
    end
    local function travel(index)
        local moved,reason
        for _=1,30 do
            moved,reason=areas:MoveToIndex(index);if moved then break end
            tick(.5)
        end
        if not moved then
            local route=area:FindPath(state.CellIndex,index);local onPath,blocking={},{}
            for _,cellIndex in ipairs(route or {}) do onPath[cellIndex]=true end
            for i=0,state.NpcCount-1 do local npc=state:GetNpcAt(i)
                if npc.Present and onPath[npc.CellIndex] then blocking[#blocking+1]=npc.Id..'@'..npc.CellIndex end
            end
            local positions={};for _,member in ipairs(members()) do positions[#positions+1]=member.cell end
            error('Open-building route site='..site.id..' area='..area.configId..' '..state.CellIndex..' -> '..index
                ..' reason='..tostring(reason)..' interaction='..state.InteractionKind..' path='..tostring(route and #route)
                ..' members='..table.concat(positions,',')..' NPCs='..table.concat(blocking,','))
        end
        local steps=state.RemainingSteps;assert(steps<=#area.cells*4,'Preview route exceeds its bounded frame budget')
        for _=1,steps do tick(area.moveStepSeconds+.001) end
        totalFrames=totalFrames+steps
        assert(state.RemainingSteps==0 and state.CellIndex==index,'Open-building route did not finish')
        validate()
    end
    local function capture(name,room,prop)
        local view=adventure:Snapshot();view.error=''
        result.captures[#result.captures+1]={name=name,layoutIndex=layoutIndex,view=view,interiorId=room.id,
            lotId=room.lotId,assetId=prop.assetId,propIndex=prop.id}
    end
    local function leaveRoomTarget(room)
        -- 与所有室内格至少隔五条导航边，使四人队形最后一人也确实离开建筑。
        local queue,distance,head={},{},1
        for _,index in ipairs(room.cells) do queue[#queue+1]=index;distance[index]=0 end
        while head<=#queue do
            local index=queue[head];head=head+1;local cell=area.cells[index]
            if distance[index]>=5 and not cell.interiorId and not state:IsNpcOccupied(index) then return index end
            for _,other in ipairs(area:Neighbors(cell)) do if distance[other.index]==nil then
                distance[other.index]=distance[index]+1;queue[#queue+1]=other.index
            end end
        end
        error('Building has no public position for a complete squad exit: '..room.lotId)
    end
    local function verifyReentry(room)
        local before=members();local npcs={}
        for i=0,state.NpcCount-1 do local npc=state:GetNpcAt(i);npcs[i+1]={cell=npc.CellIndex,present=npc.Present} end
        local count=#area.cells;assert(areas:Leave());assert(adventure:Visit(site.id))
        area,state=areas:ActiveLayout(),Services.Adventure.Areas.Active
        assert(#area.cells==count and state.MemberCount==#before and state.NpcCount==#npcs,'Reentry changed the building layout or actor counts')
        for i,member in ipairs(before) do
            assert(state:GetMemberIdAt(i-1)==member.id and state:GetMemberCellAt(i-1)==member.cell,'Reentry lost a member position')
        end
        for i,previous in ipairs(npcs) do local npc=state:GetNpcAt(i-1)
            assert(npc.CellIndex==previous.cell and npc.Present==previous.present,'Reentry changed an NPC position or presence')
        end
        assert(area.cells[state.CellIndex].interiorId==room.id and state.InteractionKind==0,'Reentry lost the occupied interior')
        validate()
    end
    local function sample(room)
        local prop
        for _,value in ipairs(area.props) do if value.interiorId==room.id and not value.cutaway then prop=value;break end end
        assert(prop and prop.assetId==wanted[room.lotId],'Interior does not use the requested building asset')
        for _,portal in ipairs(room.portals) do
            travel(portal.outsideIndex);travel(portal.insideIndex)
            assert(area.cells[state.CellIndex].interiorId==room.id,'Door did not enter its actual interior')
            travel(portal.outsideIndex)
        end
        travel(room.serviceIndex);verifyReentry(room)
        local name='asset'..prop.assetId
        capture(name..'-inside',room,prop)
        travel(leaveRoomTarget(room))
        for i=0,state.MemberCount-1 do assert(area.cells[state:GetMemberCellAt(i)].interiorId~=room.id,'A follower remained inside') end
        capture(name..'-outside',room,prop)
        local portals={};for _,portal in ipairs(room.portals) do portals[#portals+1]={outsideIndex=portal.outsideIndex,insideIndex=portal.insideIndex} end
        result.checks[#result.checks+1]={assetId=prop.assetId,lotId=room.lotId,interiorId=room.id,layoutIndex=layoutIndex,
            propIndex=prop.id,portals=portals,reentry=true,fullSquadExit=true}
        done[room.lotId]=true
        local progress=assert(io.open('Art/TownOpenBuildings/Integration/preview-progress.txt','w'))
        progress:write('Navigation complete: lot '..room.lotId..'; samples '..#result.checks..'/7');progress:close()
    end
    local function inspect(candidate)
        site=candidate;assert(adventure:Visit(site.id));area,state=areas:ActiveLayout(),Services.Adventure.Areas.Active
        assert(area.areaType==2 and area.discovery=='open','Open-building preview only visits public town layouts')
        validate();layoutIndex=#result.layouts+1
        result.layouts[layoutIndex]={siteId=site.id,areaConfigId=area.configId,layout=areas:LayoutSnapshot()}
        while true do
            local selected,best
            local leader=area.cells[state.CellIndex]
            for _,room in ipairs(area.interiors) do if wanted[room.lotId] and not done[room.lotId] then
                local door=area.cells[room.portals[1].outsideIndex];local distance=Hex.Distance(leader.q,leader.r,door.q,door.r)
                if not best or distance<best then selected,best=room,distance end
            end end
            if not selected then break end
            sample(selected)
        end
        assert(areas:Leave())
    end
    local ordinary,royal={},nil;local priority={[2]=1,[3]=2,[4]=3,[5]=4}
    for _,candidate in ipairs(adventure.sites) do
        if priority[candidate.areaConfigId] then ordinary[#ordinary+1]=candidate
        elseif candidate.areaConfigId==6 then assert(not royal,'More than one royal preview entrance');royal=candidate end
    end
    table.sort(ordinary,function(a,b)
        local x,y=priority[a.areaConfigId],priority[b.areaConfigId];return x<y or x==y and a.id<b.id
    end)
    assert(#ordinary>0 and royal,'Preview expedition needs an ordinary town and royal town')
    inspect(ordinary[1])
    -- 农场是可选摆放；最多补访另一个真实普通城镇，不换种子或循环寻找场景。
    if not done[31] or not done[32] then
        assert(ordinary[2],'No second town for missing farm buildings');inspect(ordinary[2])
    end
    inspect(royal)
    local missing={};for _,id in ipairs({14,15,16,18,19,31,32}) do if not done[id] then missing[#missing+1]=id end end
    assert(#missing==0,'Bounded real-world preview is missing building lots: '..table.concat(missing,',')..'; world seed='..result.seed)
    result.frames=totalFrames
    return result
end,debug.traceback)
registry:Shutdown();if not ok then error(result,0) end
return result
