-- 地牢的六边形几何操作；房间模板、通道与占地使用同一坐标和旋转。
local Geometry={}
function Geometry.Rotate(q,r,turns)
    for _=1,turns%6 do q,r=-r,q+r end
    return q,r
end
function Geometry.Disk(q,r,radius,visit)
    for dr=-radius,radius do
        for dq=math.max(-radius,-dr-radius),math.min(radius,-dr+radius) do visit(q+dq,r+dr,dq,dr) end
    end
end
function Geometry.Carve(area,cell,kind,roomId)
    assert(cell.obstacleId==0,'Cannot carve through a configured prop')
    if cell.blocked then area.walkableCount=area.walkableCount+1 end
    cell.blocked=false;cell.blocksSight=false
    if cell.roomId==0 then cell.kind=kind;cell.roomId=roomId or 0 end
end
function Geometry.Reachable(area,index)
    local queue,distance,head={index},{[index]=0},1
    while head<=#queue do
        local current=queue[head];head=head+1
        for _,neighbor in ipairs(area:Neighbors(area.cells[current])) do
            if distance[neighbor.index]==nil then distance[neighbor.index]=distance[current]+1;queue[#queue+1]=neighbor.index end
        end
    end
    return queue,distance
end
function Geometry.Inside(area,cell,margin)
    return cell and cell.q>=margin and cell.r>=margin and cell.q<area.width-margin and cell.r<area.height-margin
end
return Geometry
