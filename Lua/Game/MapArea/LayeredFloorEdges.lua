-- 楼板和楼梯共享的明确双向边；不按坐标暗中连接重叠楼层。
local Hex=require('Game.Map.HexGrid')
local Edges={}
Edges.Corners={{1,6},{5,6},{4,5},{3,4},{2,3},{1,2}}
function Edges.Direction(from,to)
    for d=1,6 do local q,r=Hex.Neighbor(from.q,from.r,d);if q==to.q and r==to.r then return d end end
    error('Layered floor paths must follow consecutive hex neighbors')
end
function Edges.Disconnect(area,cell)
    for _,index in ipairs(cell.neighbors) do
        local other=area.cells[index]
        if other then for d,nextIndex in ipairs(other.neighbors) do
            if nextIndex==cell.index then other.walkMask=other.walkMask & (~(1 << (d-1))) end
        end end
    end
    cell.walkMask=0
end
function Edges.Connect(from,to)
    local d=Edges.Direction(from,to);local opposite=(d+2)%6+1
    assert((from.walkMask & (1 << (d-1)))==0 or from.neighbors[d]==to.index,'Layered floor edge replaces an existing navigation edge')
    assert((to.walkMask & (1 << (opposite-1)))==0 or to.neighbors[opposite]==from.index,'Layered floor edge replaces an existing navigation edge')
    from.neighbors[d]=to.index;from.walkMask=from.walkMask | (1 << (d-1))
    to.neighbors[opposite]=from.index;to.walkMask=to.walkMask | (1 << (opposite-1))
end
return Edges
