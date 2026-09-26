-- 地牢材质按完整房间与走廊分区；地貌可覆盖房间功能，潮湿、林地与冰雪有各自配方。
local Hex=require('Game.Map.HexGrid')
local Surfaces={}
function Surfaces.Apply(area,random,config)
    local profile=config:GetTable('MapAreaDungeonSurfaceTable'):Get(area.theme.surfaceProfileId)
    local definitions=config:GetTable('MapAreaSurfaceTable');local rooms={}
    local function pick(pool,room,salt)
        assert(#pool>0,'Dungeon surface pool cannot be empty')
        return definitions:Get(pool[1+math.floor(random:Noise(room.q,room.r,1,salt)*#pool)]).id
    end
    for _,room in ipairs(area.rooms) do
        local style=room.preset or room.style
        local regional=not style or random:Noise(room.q,room.r,1,17311)<profile.regionOverrideChance
        local floors=not regional and #style.floorSurfaceIds>0 and style.floorSurfaceIds or profile.floorIds
        local walls=not regional and #style.wallSurfaceIds>0 and style.wallSurfaceIds or profile.wallIds
        rooms[room.id]={floor=pick(floors,room,17333),wall=pick(walls,room,17359)}
    end
    local owners,distance,queue={},{},{}
    for _,cell in ipairs(area.cells) do
        if cell.roomId>0 and cell.kind~='wall' then owners[cell.index]=cell.roomId;distance[cell.index]=0;queue[#queue+1]=cell end
    end
    local head=1
    while head<=#queue do
        local cell=queue[head];head=head+1
        if distance[cell.index]<profile.wallBand then for direction=1,6 do
            local q,r=Hex.Neighbor(cell.q,cell.r,direction);local other=area:Find(q,r)
            if other and other.kind=='wall' and distance[other.index]==nil then
                owners[other.index]=owners[cell.index];distance[other.index]=distance[cell.index]+1;queue[#queue+1]=other
            end
        end end
    end
    for _,cell in ipairs(area.cells) do
        local room=rooms[owners[cell.index]]
        local id=cell.kind=='wall' and (room and room.wall or profile.corridorWallId) or (room and room.floor or profile.corridorFloorId)
        local surface=definitions:Get(id)
        cell.surfaceId=id;cell.sideSurfaceId=id;cell.floorAccent=surface.baseColor;cell.floorAccentWeight=1
    end
end
return Surfaces
