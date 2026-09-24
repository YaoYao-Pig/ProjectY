-- 城镇地面表现由源表选择；只写外观字段，不改高度、阻挡或导航边。
local Hex=require('Game.Map.HexGrid')
local Surfaces={}
local function rgb(text)
    assert(text:match('^#%x%x%x%x%x%x$'),'Invalid surface color')
    return {tonumber(text:sub(2,3),16),tonumber(text:sub(4,5),16),tonumber(text:sub(6,7),16)}
end
local function mix(a,b,t)
    a,b=rgb(a),rgb(b)
    return string.format('#%02x%02x%02x',math.floor(a[1]*(1-t)+b[1]*t+.5),math.floor(a[2]*(1-t)+b[2]*t+.5),math.floor(a[3]*(1-t)+b[3]*t+.5))
end
function Surfaces.Apply(area,town,config)
    local profile=config:GetTable('MapAreaTownSurfaceTable'):Get(town.surfaceProfileId)
    local definitions=config:GetTable('MapAreaSurfaceTable')
    local outside=definitions:Get(area.theme.outsideSurfaceId)
    local buildingDistance,edgeDistance={},{}
    -- 地表距离不沿可走边传播，否则围墙外与被模型占用的院落会留下明显硬边。
    local function distances(target,seeds,limit)
        local queue={};for _,cell in ipairs(seeds) do target[cell.index]=0;queue[#queue+1]=cell end
        local head=1
        while head<=#queue do
            local cell=queue[head];head=head+1;local d=target[cell.index]
            if d<limit then for direction=1,6 do
                local q,r=Hex.Neighbor(cell.q,cell.r,direction);local other=area:Find(q,r,cell.layer)
                if other and target[other.index]==nil then target[other.index]=d+1;queue[#queue+1]=other end
            end end
        end
    end
    local buildings,inside={},{}
    for _,cell in ipairs(area.cells) do
        if cell.townInside then inside[#inside+1]=cell end
        if cell.obstacleId and cell.obstacleId>0 then buildings[#buildings+1]=cell end
    end
    distances(buildingDistance,buildings,profile.yardDistance)
    distances(edgeDistance,inside,profile.transitionCells)
    for _,cell in ipairs(area.cells) do
        local id=cell.surfaceId
        if not id then
            if cell.layer>0 then id=profile.bridgeId
            elseif not cell.townInside then id=outside.id
            elseif cell.kind=='square' or cell.pavingRole=='plaza' then id=profile.plazaId
            elseif cell.kind=='street' or cell.kind=='stairs' or cell.kind=='ramp' or cell.kind=='entry' then id=profile.roadId
            elseif buildingDistance[cell.index] then id=profile.yardId
            else id=profile.gardenId end
        end
        local surface=definitions:Get(id)
        cell.surfaceId=id;cell.sideSurfaceId=profile.cliffId
        cell.floorAccent=surface.baseColor;cell.floorAccentWeight=1
        if not cell.townInside and cell.layer==0 and edgeDistance[cell.index] then
            local t=(1-edgeDistance[cell.index]/(profile.transitionCells+1))*.55
            cell.floorAccent=mix(outside.baseColor,definitions:Get(profile.trailId).baseColor,t)
        end
    end
end
return Surfaces
