-- 可复用的薄楼板与直梯构建器：空洞不创建楼板，层间只通过显式梯道接边。
local Hex=require('Game.Map.HexGrid')
local Edges=require('Game.MapArea.LayeredFloorEdges')
local Builder={}
function Builder.Reset(area,surfaceId)
    assert(math.tointeger(surfaceId) and surfaceId>0,'Layered void requires a configured surface ID')
    for _,cell in ipairs(area.cells) do
        cell.kind='void';cell.height=0;cell.blocked=true;cell.blocksSight=false;cell.renderGround=false
        cell.walkMask=0;cell.neighbors={0,0,0,0,0,0};cell.surfaceId=surfaceId;cell.sideSurfaceId=surfaceId
    end
end
function Builder.Add(area,q,r,layer,height,settings)
    local cell=area:Find(q,r,layer)
    if layer==0 then assert(cell and cell.kind=='void','Layered base floor must occupy an unused base cell')
    else assert(not cell,'Layered floor overlaps another floor or stair');cell=area:AddLayerCell(q,r,layer,height) end
    cell.height=height;cell.kind=settings.kind or 'floor';cell.blocked=cell.kind=='wall';cell.blocksSight=cell.blocked
    cell.renderGround=true;cell.walkMask=0;cell.neighbors={0,0,0,0,0,0};cell.reserved=false
    cell.corners={height,height,height,height,height,height};cell.deckThickness=settings.deckThickness
    cell.surfaceId=settings.surfaceId;cell.sideSurfaceId=settings.sideSurfaceId
    cell.cutawayGroup=settings.cutawayGroup;cell.cutawayLayer=layer
    cell.roomId=settings.roomId or 0;cell.interiorId=0;cell.coverInteriorId=0
    return cell
end
function Builder.AddStair(area,row,origin,settings)
    assert(#row.q>0 and #row.q==#row.r and #row.edges==#row.q+1,'Layered stair arrays differ')
    local bottom=assert(area:Find(origin.q+row.bottomQ,origin.r+row.bottomR,row.fromLayer),'Missing layered stair bottom')
    local top=assert(area:Find(origin.q+row.topQ,origin.r+row.topR,row.toLayer),'Missing layered stair top')
    assert(not bottom.blocked and not top.blocked,'Layered stair endpoint is blocked')
    assert(math.abs(bottom.height-row.edges[1])<.00001 and math.abs(top.height-row.edges[#row.edges])<.00001,'Layered stair does not meet its floor')
    local stair={id=row.id,name=row.name,fromLayer=row.fromLayer,toLayer=row.toLayer,bottom=bottom.index,top=top.index,cells={}}
    for i,q in ipairs(row.q) do
        assert(row.edges[i+1]>row.edges[i],'Layered stairs must rise from bottom to top')
        local cell=Builder.Add(area,origin.q+q,origin.r+row.r[i],row.toLayer,(row.edges[i]+row.edges[i+1])/2,settings)
        cell.kind='stairs';cell.stairRise=settings.stairRise;cell.reserved=true;cell.cutawayLayer=row.fromLayer
        stair.cells[#stair.cells+1]=cell.index
    end
    for i,index in ipairs(stair.cells) do
        local cell=area.cells[index];local before=i==1 and bottom or area.cells[stair.cells[i-1]]
        local after=i==#stair.cells and top or area.cells[stair.cells[i+1]]
        local incoming,outgoing=Edges.Direction(cell,before),Edges.Direction(cell,after)
        assert((incoming+2)%6+1==outgoing,'Layered stairs need a flat landing before turning')
        for _,corner in ipairs(Edges.Corners[incoming]) do cell.corners[corner]=row.edges[i] end
        for _,corner in ipairs(Edges.Corners[outgoing]) do cell.corners[corner]=row.edges[i+1] end
        for layer=0,row.toLayer-1 do
            local lower=area:Find(cell.q,cell.r,layer)
            if lower and not lower.blocked and math.min(table.unpack(cell.corners))-cell.deckThickness-math.max(table.unpack(lower.corners))<settings.minimumClearance then
                assert(lower.kind~='stairs','Layered stair blocks another stair')
                lower.blocked=true;lower.stairBase=true
            end
        end
    end
    return stair
end
function Builder.Connect(area,stairs,minimumClearance)
    for _,cell in ipairs(area.cells) do if not cell.blocked and cell.kind~='stairs' then
        for direction=1,6 do
            local q,r=Hex.Neighbor(cell.q,cell.r,direction);local other=area:Find(q,r,cell.layer)
            if other and not other.blocked and other.kind~='stairs' then
                assert(math.abs(cell.height-other.height)<.00001,'Flat layered floors have mismatched heights')
                Edges.Connect(cell,other)
            end
        end
    end end
    for _,stair in ipairs(stairs) do
        local previous=area.cells[stair.bottom];previous.reserved=true
        for _,index in ipairs(stair.cells) do Edges.Connect(previous,area.cells[index]);previous=area.cells[index] end
        Edges.Connect(previous,area.cells[stair.top]);area.cells[stair.top].reserved=true
    end
    for _,cell in ipairs(area.cells) do if not cell.blocked and cell.layer>0 then
        for layer=0,cell.layer-1 do
            local lower=area:Find(cell.q,cell.r,layer)
            if lower and not lower.blocked then
                assert(math.min(table.unpack(cell.corners))-cell.deckThickness-math.max(table.unpack(lower.corners))>=minimumClearance-.00001,'Layered floors leave insufficient headroom')
            end
        end
    end end
end
return Builder
