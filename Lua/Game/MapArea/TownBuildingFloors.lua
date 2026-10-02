-- 建筑楼层只扩展同一导航图：独立二楼身份、连续踏步和明确楼梯井。
local Hex=require('Game.Map.HexGrid')
local Geometry=require('Game.MapArea.DungeonGeometry')
local Floors={}
local Edges=require('Game.MapArea.LayeredFloorEdges')
local edgeCorners=Edges.Corners
local direction,disconnect,connect=Edges.Direction,Edges.Disconnect,Edges.Connect
function Floors.Apply(area,definition,interior,prop,room)
    assert(#definition.floorQ==#definition.floorR and #definition.stairQ==#definition.stairR,'Building floor coordinate arrays differ')
    assert(#definition.closedGroundQ==#definition.closedGroundR,'Building closed ground arrays differ')
    assert(#definition.stairQ>0 and #definition.stairEdges==#definition.stairQ+1,'Building stairs need an edge height at both ends of each cell')
    assert(definition.stairEdges[1]==0 and math.abs(definition.stairEdges[#definition.stairEdges]-interior.storeyHeight)<.00001,'Building stairs must meet both storeys')
    local function world(q,r) local dq,dr=Geometry.Rotate(q,r,prop.rotation);return prop.q+dq,prop.r+dr end
    local function find(q,r,layer) local x,y=world(q,r);return assert(area:Find(x,y,layer),'Building floor cell is outside its map') end
    local closed={}
    for i,q in ipairs(definition.closedGroundQ) do
        local cell=find(q,definition.closedGroundR[i]);assert(cell.interiorId==room.id and not cell.blocked,'Closed stair base must belong to its building')
        assert(cell.index~=room.serviceIndex and cell.index~=room.doorIndex,'Stairs cannot occupy a building service or door')
        disconnect(area,cell);cell.blocked=true;closed[cell.index]=true;area.walkableCount=area.walkableCount-1
    end
    local open={}
    for _,index in ipairs(room.cells) do if not closed[index] then open[#open+1]=index end end
    room.cells=open
    local floors,stairs={},{}
    local function add(q,r,height,kind)
        local x,y=world(q,r);local cell=area:AddLayerCell(x,y,1,prop.height+height)
        cell.interiorId=room.id;cell.kind=kind;cell.surfaceId=definition.surfaceId;cell.deckThickness=definition.deckThickness
        cell.corners={cell.height,cell.height,cell.height,cell.height,cell.height,cell.height};cell.neighbors={0,0,0,0,0,0}
        room.cells[#room.cells+1]=cell.index;return cell
    end
    for i,q in ipairs(definition.floorQ) do floors[#floors+1]=add(q,definition.floorR[i],interior.storeyHeight,'interior') end
    for i,q in ipairs(definition.stairQ) do
        local low,high=definition.stairEdges[i],definition.stairEdges[i+1]
        assert(high>=low,'Building stairs must rise monotonically')
        local cell=add(q,definition.stairR[i],(low+high)/2,'stairs');cell.stairRise=definition.stairRise;stairs[#stairs+1]=cell
    end
    local bottom=find(definition.bottomQ,definition.bottomR);local top=find(definition.topQ,definition.topR,1)
    assert(not bottom.blocked and (bottom.index==room.doorIndex or bottom.interiorId==room.id),'Building stairs must start at its door or interior')
    assert(top.kind=='interior' and top.interiorId==room.id,'Building stairs must end on its upper floor')
    for i,cell in ipairs(stairs) do
        local previous=i==1 and bottom or stairs[i-1];local following=i==#stairs and top or stairs[i+1]
        local incoming,outgoing=direction(cell,previous),direction(cell,following)
        local low,high=definition.stairEdges[i],definition.stairEdges[i+1]
        assert(high==low or (incoming+2)%6+1==outgoing,'Turning stairs require a flat landing')
        for _,corner in ipairs(edgeCorners[incoming]) do cell.corners[corner]=prop.height+low end
        for _,corner in ipairs(edgeCorners[outgoing]) do cell.corners[corner]=prop.height+high end
        connect(previous,cell)
    end
    connect(stairs[#stairs],top)
    for _,cell in ipairs(floors) do for d=1,6 do
        local q,r=Hex.Neighbor(cell.q,cell.r,d);local other=area:Find(q,r,1)
        if other and other.interiorId==room.id and other.kind=='interior' then connect(cell,other) end
    end end
    -- 所有仍可走的下层格按实际最低板底校验，不能只比较楼层中心高度。
    for _,index in ipairs(room.cells) do
        local cell=area.cells[index]
        if cell.layer==1 then
            local lower=area:Find(cell.q,cell.r)
            if lower and not lower.blocked then
                local underside=math.min(table.unpack(cell.corners))-cell.deckThickness
                assert(underside-math.max(table.unpack(lower.corners))>=definition.minimumClearance,'Building stairs leave insufficient headroom')
            end
        end
    end
    for _,index in ipairs(room.cells) do assert(area:FindPath(room.doorIndex,index),'Building stairs disconnected an interior cell') end
    room.upperEntryIndex=top.index
    local serviceNpc=find(definition.serviceNpcQ,definition.serviceNpcR)
    assert(not serviceNpc.blocked and serviceNpc.interiorId==room.id and area:CanStep(area.cells[room.serviceIndex],serviceNpc),'Building service NPC must stand beside its service point')
    assert(area:FindPath(room.doorIndex,room.serviceIndex,function(cell)return cell.index~=serviceNpc.index end),'Building service NPC blocks its service entrance')
    room.serviceNpcIndex=serviceNpc.index
    -- 作者给定的米制墙线；首层已有完整地面覆盖，仅二楼登记封边。
    local Boundary=require('Game.MapArea.FloorBoundary')
    assert(#definition.boundaryX==#definition.boundaryZ and #definition.boundaryX>=3,'Building floor boundary arrays differ')
    local x,_,z=Hex.ToWorld(prop.q,prop.r,0,area.hexRadius)
    local angle=math.rad(prop.rotation*60);local ca,sa=math.cos(angle),math.sin(angle);local outer={}
    local sx,sz=prop.scaleX or prop.scale*area.hexRadius,prop.scaleZ or prop.scale*area.hexRadius
    for i,bx in ipairs(definition.boundaryX) do local bz=definition.boundaryZ[i];bx,bz=bx*sx,bz*sz
        outer[#outer+1]=x+bx*ca-bz*sa;outer[#outer+1]=z+bx*sa+bz*ca
    end
    local holes,protected={},{}
    local function protect(q,r)
        local key=Hex.Key(q,r);if not protected[key] then protected[key]=true;holes[#holes+1]=Boundary.Hex(q,r,area.hexRadius) end
    end
    -- 室内未声明二楼的格子是挑空，不能把回廊补成整个矩形。
    for i=1,area.width*area.height do local base=area.cells[i];local px,_,pz=Hex.ToWorld(base.q,base.r,0,area.hexRadius)
        if Boundary.Contains(outer,px,pz,true) and not area:Find(base.q,base.r,1) then protect(base.q,base.r) end
    end
    for i,q in ipairs(definition.closedGroundQ) do local px,pr=world(q,definition.closedGroundR[i]);if not area:Find(px,pr,1) then protect(px,pr) end end
    local owners={};for _,cell in ipairs(floors) do owners[#owners+1]=cell.index end
    Boundary.Register(area,{cells=owners,outer=outer,holes=holes,height=prop.height+interior.storeyHeight,thickness=definition.deckThickness,rings=1})
end
return Floors
