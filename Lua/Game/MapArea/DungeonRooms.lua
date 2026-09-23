-- 先选房间内容再排空间；三级模板保持固定格罩与陈设，二级按形状策略细化。
local Hex=require('Game.Map.HexGrid')
local G=require('Game.MapArea.DungeonGeometry')
local Districts=require('Game.MapArea.DungeonDistricts')
local Rooms={}
local shapes={}
function shapes.cavern(q,r,radius,noise,roughness)
    local x,z=q+r*.5,r*.8660254
    return math.sqrt(x*x+z*z/.82^2)<=radius*.96-noise*roughness
end
function shapes.hall(q,r,radius)
    return math.abs(q+r*.5)<=radius*.90 and math.abs(r)<=radius*.72
end
function shapes.apse(q,r,radius,noise,roughness)
    local x,z=q+r*.5,r*.8660254
    -- 直墙前厅接弧形后殿，形体来自房间用途，避免每个房间都是噪声圆。
    return math.abs(x)<=radius*.82 and z>=-radius*.62 and
        (z<=radius*.18 or x*x+(z-radius*.18)^2<=(radius*.82-noise*roughness)^2)
end
function shapes.lobed(q,r,radius,noise,roughness)
    local offset=radius*.28
    local x,z=q+r*.5,r*.8660254
    return math.min(math.sqrt((x-offset)^2+z*z),math.sqrt((x+offset)^2+z*z))<=radius*.70-noise*roughness*.4
end
function Rooms.Select(area,row,random,config)
    local selected={}
    local presets=config:GetTable('MapAreaRoomPresetTable')
    for _,id in ipairs(row.presetIds) do
        local preset=presets:Get(id)
        selected[#selected+1]={tier=3,name=preset.name,presetId=id,preset=preset,radius=preset.radius,districtId=preset.districtId}
    end
    local styles=config:GetTable('MapAreaRoomStyleTable')
    for i=1,row.detailedRoomCount do
        local style=styles:Get(row.styleIds[(i-1)%#row.styleIds+1])
        assert(shapes[style.shape],'Unknown detailed room shape: '..style.shape)
        -- 山地可缩小房间，但不突破主要房间的下限和战斗净空要求。
        local radius=math.max(row.roomRadiusMin,math.floor(random:Integer(row.roomRadiusMin,row.roomRadiusMax)*area.theme.roomRadiusScale))
        radius=math.min(row.roomRadiusMax,radius)
        selected[#selected+1]={tier=2,name=style.name,presetId=0,style=style,radius=radius,districtId=style.districtId}
    end
    for i=1,row.basicRoomCount do
        selected[#selected+1]={tier=1,name='侵蚀连接石窟',presetId=0,radius=random:Integer(row.basicRadiusMin,row.basicRadiusMax),districtId=row.districtIds[(i-1)%#row.districtIds+1]}
    end
    for i,room in ipairs(selected) do room.order=i end
    Districts.Place(area,row,random,config,selected)
end
function Rooms.Paint(area,row,random)
    for _,room in ipairs(area.rooms) do
        if room.preset then
            local size=room.radius*2+1
            assert(#room.preset.tiles==size,'Preset row count does not match its radius')
            for _,line in ipairs(room.preset.tiles) do assert(#line==size and not line:find('[^.#]'),'Invalid preset floor mask') end
        end
        G.Disk(room.q,room.r,room.radius,function(q,r,dq,dr)
            local cell=assert(area:Find(q,r));cell.roomOwner=room.id
            local localQ,localR=G.Rotate(dq,dr,6-room.rotation)
            local floor
            if room.preset then
                floor=room.preset.tiles[localR+room.radius+1]:sub(localQ+room.radius+1,localQ+room.radius+1)=='.'
            elseif room.tier==2 then
                local noise=random:Noise(q,r,3,room.id*1741)
                floor=shapes[room.style.shape](localQ,localR,room.radius,noise,room.style.roughness*area.theme.windingScale)
            else
                floor=shapes.cavern(localQ,localR,room.radius,random:Noise(q,r,3,1741),.65)
            end
            if Hex.Distance(0,0,dq,dr)<=room.combatRadius then
                assert(not room.preset or floor,'Preset must contain the configured open combat area')
                floor=true;cell.reserved=true
            end
            if floor then
                G.Carve(area,cell,'room',room.id);cell.roomTier=room.tier
                if room.preset then cell.floorAccent=room.preset.floorAccent end
            end
        end)
    end
end
return Rooms
