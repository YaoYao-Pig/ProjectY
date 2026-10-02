-- 三层开采区：按房间/矿道格罩开挖，坍塌处保留真实空洞而不是透明地板。
local Hex=require('Game.Map.HexGrid')
local Builder=require('Game.MapArea.LayeredFloorBuilder')
local Floors={}
local function rows(config,name,profileId)
    local result={}
    for _,row in ipairs(config:GetTable(name):All()) do if row.profileId==profileId then result[#result+1]=row end end
    return result
end
function Floors.Build(area,profile,random,config)
    local origin={q=math.floor(area.width/2),r=math.floor(area.height/2)};area.mineOrigin=origin
    local definitions=rows(config,'MapAreaMineFloorTable',profile.id);assert(#definitions==3,'Mine profile requires three floor definitions')
    local rooms=rows(config,'MapAreaMineRoomTable',profile.id)
    local openings=rows(config,'MapAreaMineOpeningTable',profile.id)
    local stairs=rows(config,'MapAreaMineStairTable',profile.id)
    area.mineFloors=definitions;area.openings={};area.stairs={}
    local masks,roomById,stairKeys={},{},{}
    for _,floor in ipairs(definitions) do assert(not masks[floor.layer],'Duplicate mine floor layer');masks[floor.layer]={} end
    for _,row in ipairs(rooms) do
        local room={id=row.id,name=row.name,tier=1,presetId=0,layer=row.layer,cells={},definition=row}
        area.rooms[#area.rooms+1]=room;roomById[row.id]=room
        local mask=assert(masks[row.layer],'Mine room references an undefined floor')
        for dr=-row.radius-1,row.radius+1 do for dq=-row.radius-1,row.radius+1 do
            local distance=Hex.Distance(0,0,dq,dr)
            local radius=row.radius+(random:Noise(row.q+dq,row.r+dr,3,row.id*47)>.58 and 1 or 0)
            if distance<=radius then mask[Hex.Key(row.q+dq,row.r+dr)]={q=row.q+dq,r=row.r+dr,roomId=row.id} end
        end end
        -- 分支由宽矿道接入中厅；原点到分支为直矿轨轴，宽度不被边缘噪声缩窄。
        if row.q~=0 then
            local sign=row.q>0 and 1 or -1
            for q=0,row.q,sign do for dr=-profile.corridorRadius,profile.corridorRadius do
                for dq=math.max(-profile.corridorRadius,-dr-profile.corridorRadius),math.min(profile.corridorRadius,-dr+profile.corridorRadius) do
                    local key=Hex.Key(q+dq,row.r+dr)
                    if not mask[key] then mask[key]={q=q+dq,r=row.r+dr,roomId=row.id} end
                end
            end end
        end
    end
    local holes={}
    for _,row in ipairs(openings) do
        local mask=assert(masks[row.layer]);holes[row.layer]=holes[row.layer] or {}
        local opening={id=row.id,name=row.name,layer=row.layer,q=origin.q+row.q,r=origin.r+row.r,radius=row.radius,cells={}}
        for dr=-row.radius,row.radius do for dq=math.max(-row.radius,-dr-row.radius),math.min(row.radius,-dr+row.radius) do
            local key=Hex.Key(row.q+dq,row.r+dr);assert(mask[key],'Mine opening must be inside an excavated room')
            holes[row.layer][key]=true;mask[key]=nil;opening.cells[#opening.cells+1]={q=origin.q+row.q+dq,r=origin.r+row.r+dr}
        end end
        area.openings[#area.openings+1]=opening
    end
    for _,row in ipairs(stairs) do
        stairKeys[row.toLayer]=stairKeys[row.toLayer] or {}
        for i,q in ipairs(row.q) do
            local key=Hex.Key(q,row.r[i]);assert(masks[row.toLayer][key],'Mine stair leaves excavated floor')
            assert(not stairKeys[row.toLayer][key],'Mine stairs overlap');stairKeys[row.toLayer][key]=true
        end
    end
    Builder.Reset(area,profile.wallSurfaceId)
    for _,floor in ipairs(definitions) do
        local mask=masks[floor.layer];local walls={}
        -- 只在开采边缘生成岩壁，破口边缘不补墙、不填柱，真实露出下层。
        for _,point in pairs(mask) do for direction=1,6 do
            local q,r=Hex.Neighbor(point.q,point.r,direction);local key=Hex.Key(q,r)
            if not mask[key] and not (holes[floor.layer] and holes[floor.layer][key]) then walls[key]={q=q,r=r} end
        end end
        -- 按底层索引遍历使生成顺序稳定，不让 pairs 顺序成为地格身份。
        local baseCount=area.width*area.height
        for i=1,baseCount do
            local base=area.cells[i];local key=Hex.Key(base.q-origin.q,base.r-origin.r);local point=mask[key]
            if point and not (stairKeys[floor.layer] and stairKeys[floor.layer][key]) then
                local cell=Builder.Add(area,base.q,base.r,floor.layer,floor.height,{deckThickness=profile.deckThickness,surfaceId=floor.surfaceId,sideSurfaceId=profile.wallSurfaceId,cutawayGroup=1,roomId=point.roomId})
                cell.floorAccent=config:GetTable('MapAreaSurfaceTable'):Get(floor.surfaceId).baseColor;cell.floorAccentWeight=1
                roomById[point.roomId].cells[#roomById[point.roomId].cells+1]=cell.index
            elseif walls[key] then
                Builder.Add(area,base.q,base.r,floor.layer,floor.height,{kind='wall',deckThickness=profile.deckThickness,surfaceId=profile.wallSurfaceId,sideSurfaceId=profile.wallSurfaceId,cutawayGroup=1})
            end
        end
    end
    for _,row in ipairs(stairs) do
        local stair=Builder.AddStair(area,row,origin,{deckThickness=profile.deckThickness,surfaceId=profile.stairSurfaceId,sideSurfaceId=profile.wallSurfaceId,cutawayGroup=1,stairRise=profile.stairRise,minimumClearance=profile.minimumClearance})
        for _,index in ipairs(stair.cells) do
            local cell=area.cells[index];cell.roomId=area.cells[stair.top].roomId
            roomById[cell.roomId].cells[#roomById[cell.roomId].cells+1]=index
        end
        area.stairs[#area.stairs+1]=stair
    end
    Builder.Connect(area,area.stairs,profile.minimumClearance)
end
return Floors
