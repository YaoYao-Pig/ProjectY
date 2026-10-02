-- 独立矿井地牢策略；探索状态、物品和移动仍由通用 MapArea 系统负责。
local Hex=require('Game.Map.HexGrid')
local Mine={}
function Mine.Validate(profile)
    assert(profile.entryLayer==2 and profile.corridorRadius>=2,'Mine entrance and passage profile is invalid')
    assert(profile.deckThickness>0 and profile.deckThickness<1 and profile.minimumClearance>=2,'Mine floor clearance is invalid')
    assert(profile.stairRise>0 and profile.stairRise<=.25 and profile.minWalkableCells>=100,'Mine stair or room profile is invalid')
end
function Mine.Reachable(area)
    local queue,seen,head={area.entryIndex},{[area.entryIndex]=true},1
    while head<=#queue do
        local cell=area.cells[queue[head]];head=head+1
        for _,other in ipairs(area:Neighbors(cell)) do if not seen[other.index] then seen[other.index]=true;queue[#queue+1]=other.index end end
    end
    return queue,seen
end
function Mine.Generate(area,profile,random,config)
    area.generationVersion=1;area.layeredVisibility=true;area.layerCount=3;area.corridorRadius=profile.corridorRadius;area.props={}
    require('Game.MapArea.MineFloors').Build(area,profile,random,config)
    local origin=area.mineOrigin
    local entry=assert(area:Find(origin.q+profile.entryQ,origin.r+profile.entryR,profile.entryLayer),'Mine entrance is outside a floor')
    assert(not entry.blocked,'Mine entrance is blocked');area.entryIndex=entry.index;entry.reserved=true
    for _,room in ipairs(area.rooms) do
        local row=room.definition;local best,distance
        for _,index in ipairs(room.cells) do
            local cell=area.cells[index]
            if not cell.blocked and cell.kind~='stairs' then
                local d=Hex.Distance(origin.q+row.q,origin.r+row.r,cell.q,cell.r)
                if not distance or d<distance then best,distance=cell,d end
            end
        end
        room.center=assert(best,'Mine room has no navigable center').index;best.reserved=true
        if room.id==profile.goalRoomId then area.goalIndex=best.index end
    end
    assert(area.goalIndex,'Mine goal room is missing')
    for _,stair in ipairs(area.stairs) do
        area.cells[stair.bottom].reserved=true;area.cells[stair.top].reserved=true
        -- 阶梯口及出口侧向留出编队会合空间，不允许后续矿石将其堵住。
        for _,index in ipairs({stair.bottom,stair.top}) do for _,other in ipairs(area:Neighbors(area.cells[index])) do other.reserved=true end end
    end
    local _,before=Mine.Reachable(area)
    for _,cell in ipairs(area.cells) do assert(cell.blocked or before[cell.index],'Mine geometry left an unreachable pocket') end
    require('Game.MapArea.MineProps').Build(area,profile,random,config)
    local queue,seen=Mine.Reachable(area);local actual=0
    for _,cell in ipairs(area.cells) do if not cell.blocked then actual=actual+1;assert(seen[cell.index],'Mine furnishing disconnects a floor') end end
    assert(#queue==actual and actual>=profile.minWalkableCells,'Mine has insufficient connected exploration space')
    area.walkableCount=actual;area.goalDistance=#assert(area:FindPath(area.entryIndex,area.goalIndex))
    entry.kind='entry';area.cells[area.goalIndex].kind='landmark'
end
return Mine
