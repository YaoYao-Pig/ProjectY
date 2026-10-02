-- 独立中型船副本：三层船形、连续楼梯环路、真实米制舱室和随机小物件。
local Hex=require('Game.Map.HexGrid')
local Floors=require('Game.MapArea.ShipwreckFloors')
local Shipwreck={}
function Shipwreck.Validate(profile)
    assert(#profile.deckZ>=3 and #profile.deckZ==#profile.deckHalfWidth,'Ship deck station arrays differ')
    for i=1,#profile.deckZ do
        assert(profile.deckHalfWidth[i]>0 and (i==1 or profile.deckZ[i]>profile.deckZ[i-1]),'Ship deck stations must be ordered and positive')
    end
    assert(profile.waterHeight<0 and profile.navMargin>0 and profile.minimumClearance>=2,'Invalid shipwreck dimensions')
end
function Shipwreck.Reachable(area)
    local queue,seen,head={area.entryIndex},{[area.entryIndex]=true},1
    while head<=#queue do
        local cell=area.cells[queue[head]];head=head+1
        for _,other in ipairs(area:Neighbors(cell)) do if not seen[other.index] then seen[other.index]=true;queue[#queue+1]=other.index end end
    end
    return queue,seen
end
function Shipwreck.Generate(area,profile,random,config)
    area.generationVersion=2;area.corridorRadius=1;area.props={}
    Floors.Build(area,profile,config)
    require('Game.MapArea.ShipwreckProps').Fixed(area,profile,config)
    local origin=area.shipOrigin
    local function closest(layer,x,z,roomId)
        local found,score
        for _,cell in ipairs(area.cells) do if cell.layer==layer and not cell.blocked and cell.kind~='stairs' and (not roomId or cell.roomId==roomId) then
            local cx,_,cz=Hex.ToWorld(cell.q,cell.r,0,area.hexRadius);local distance=(cx-origin.x-x)^2+(cz-origin.z-z)^2
            if not score or distance<score then found,score=cell,distance end
        end end
        return assert(found,'Ship room has no walkable destination')
    end
    area.entryIndex=closest(profile.entryLayer,profile.entryX,profile.entryZ).index
    -- 舷壁与家具之间的一两格死角没有接入空间；保留木板外观，但不开放为可走岛。
    local _,seen=Shipwreck.Reachable(area)
    for _,cell in ipairs(area.cells) do if not cell.blocked and not seen[cell.index] then
        local pocket,head={cell},1;seen[cell.index]=true
        while head<=#pocket do local current=pocket[head];head=head+1
            for _,other in ipairs(area:Neighbors(current)) do if not seen[other.index] then seen[other.index]=true;pocket[#pocket+1]=other end end
        end
        assert(#pocket<=3,'Fixed ship furniture disconnects a room')
        for _,part in ipairs(pocket) do part.blocked=true;part.narrowPocket=true end
    end end
    for _,room in ipairs(area.rooms) do
        room.center=closest(room.layer,room.definition.centerX,room.definition.centerZ,room.id).index
        if room.id==profile.goalRoomId then area.goalIndex=room.center end
    end
    assert(area.goalIndex,'Ship objective room is missing')
    local targets={area.entryIndex,area.goalIndex}
    for _,room in ipairs(area.rooms) do targets[#targets+1]=room.center end
    for _,stair in ipairs(area.stairs) do targets[#targets+1]=stair.bottom;targets[#targets+1]=stair.top end
    for _,target in ipairs(targets) do
        local path=assert(area:FindPath(area.entryIndex,target),'Ship room or stair is disconnected before dressing')
        area.cells[target].reserved=true
        for _,index in ipairs(path) do
            area.cells[index].reserved=true
            for _,other in ipairs(area:Neighbors(area.cells[index])) do if other.layer==area.cells[index].layer then other.reserved=true end end
        end
    end
    require('Game.MapArea.ShipwreckProps').Dress(area,profile,random,config)
    local reachable,seen=Shipwreck.Reachable(area);local actual=0
    for _,cell in ipairs(area.cells) do if not cell.blocked then actual=actual+1;assert(seen[cell.index],'Ship dressing left an unreachable floor island') end end
    assert(#reachable==actual and actual>=profile.minWalkableCells,'Shipwreck has insufficient connected exploration space')
    area.walkableCount=actual;area.goalDistance=#assert(area:FindPath(area.entryIndex,area.goalIndex))
    area.cells[area.entryIndex].kind='entry';area.cells[area.goalIndex].kind='landmark'
end
return Shipwreck
