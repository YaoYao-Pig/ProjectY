-- Shared geometry for outdoor exploration: real ground everywhere, graded trails and explicit slope edges.
local Hex=require('Game.Map.HexGrid')
local Terrain={}
local offsets={{1,1},{0,2},{-1,1},{-1,-1},{0,-2},{1,-1}}
function Terrain.Validate(row)
    assert(row.maxWalkRise>0 and row.maxWalkRise<=2 and row.trailRadius>=1,'Invalid natural terrain navigation profile')
    assert(row.minWalkableCells>=50 and row.rockSurfaceId>0 and row.trailSurfaceId>0,'Invalid natural terrain surfaces')
end
function Terrain.Local(area,q,r) return q-area.width/2+(r-area.height/2)/2,r-area.height/2 end
function Terrain.At(area,u,r)
    return assert(area:Find(math.floor(area.width/2+u-(r-area.height/2)/2+.5),r),'Natural terrain anchor leaves the sampling rectangle')
end
function Terrain.Begin(area,row,sample)
    Terrain.Validate(row)
    area.props={};area.corridorRadius=row.trailRadius;area.generationVersion=1;area.trails={}
    for _,cell in ipairs(area.cells) do
        local u,v=Terrain.Local(area,cell.q,cell.r)
        local height,surface,barrier=sample(u,v,cell)
        cell.height=height;cell.surfaceId=surface;cell.sideSurfaceId=row.rockSurfaceId
        cell.naturalWater=surface==row.waterSurfaceId
        cell.kind='floor';cell.surface='ground';cell.renderGround=true;cell.blocksSight=false
        cell.naturalBarrier=barrier or cell.q<2 or cell.r<2 or cell.q>=area.width-2 or cell.r>=area.height-2
        cell.blocked=cell.naturalBarrier;cell.walkMask=0
    end
end
-- Every anchor carries a desired height. Distance along the polyline grades its connecting slope.
function Terrain.Trail(area,row,anchors)
    local path={}
    for segment=2,#anchors do
        local first,last=anchors[segment-1],anchors[segment]
        local ax,_,az=Hex.ToWorld(first.cell.q,first.cell.r,0,1)
        local bx,_,bz=Hex.ToWorld(last.cell.q,last.cell.r,0,1)
        local distance=Hex.Distance(first.cell.q,first.cell.r,last.cell.q,last.cell.r)
        assert(distance>0 and math.abs(last.height-first.height)/distance<=row.maxWalkRise*.7,'Natural trail is too steep')
        for step=0,distance do
            local t=step/distance;local q,r=Hex.FromWorld(ax+(bx-ax)*t,az+(bz-az)*t,1)
            local cell=assert(area:Find(q,r));local h=first.height+(last.height-first.height)*t
            if #path==0 or path[#path].index~=cell.index then path[#path+1]={index=cell.index,height=h} end
        end
    end
    local assigned={}
    for _,node in ipairs(path) do
        local center=area.cells[node.index]
        for dr=-row.trailRadius,row.trailRadius do for dq=-row.trailRadius,row.trailRadius do
            local distance=Hex.Distance(0,0,dq,dr)
            if distance<=row.trailRadius then
                local cell=area:Find(center.q+dq,center.r+dr)
                assert(cell and cell.q>=2 and cell.r>=2 and cell.q<area.width-2 and cell.r<area.height-2,'Natural trail touches boundary')
                local previous=assigned[cell.index]
                if not previous or distance<previous.distance then assigned[cell.index]={distance=distance,height=node.height} end
            end
        end end
    end
    for index,node in pairs(assigned) do
        local cell=area.cells[index]
        -- Junctions retain the already graded main trail; branches begin at its exact elevation.
        if not cell.reserved then cell.height=node.height end
        cell.reserved=true;cell.naturalBarrier=false;cell.blocked=false;cell.surfaceId=row.trailSurfaceId
    end
    area.trails[#area.trails+1]=path
    return path
end
function Terrain.Prop(area,config,cell,assetId,scale,yaw,cells)
    config:GetTable('MapAssetTable'):Get(assetId)
    local prop={id=#area.props+1,assetId=assetId,q=cell.q,r=cell.r,layer=0,rotation=0,yaw=yaw,
        height=cell.height,scale=scale/area.hexRadius,scaleX=scale,scaleY=scale,scaleZ=scale,cells=cells or {cell.index}}
    area.props[#area.props+1]=prop;return prop
end
function Terrain.ScenicProp(area,config,cell,assetId,scale,yaw)
    local occupied={cell.index}
    -- Existing rock/tree meshes extend past a hex center. Leave an entire ring clear of navigation.
    for _,index in ipairs(cell.neighbors) do
        local other=area.cells[index]
        if other then
            if not other.blocked then return end
            occupied[#occupied+1]=index
        end
    end
    return Terrain.Prop(area,config,cell,assetId,scale,yaw,occupied)
end
function Terrain.Finish(area,row,config,options)
    local vertices={}
    local function key(cell,i) local o=offsets[i];return (cell.q*2+cell.r+o[1])..':'..(cell.r*3+o[2]) end
    for _,cell in ipairs(area.cells) do for i=1,6 do
        local k=key(cell,i);local vertex=vertices[k]
        if not vertex then vertex={sum=0,count=0,trailSum=0,trailCount=0,waterSum=0,waterCount=0};vertices[k]=vertex end
        vertex.sum=vertex.sum+cell.height;vertex.count=vertex.count+1
        if cell.reserved then vertex.trailSum=vertex.trailSum+cell.height;vertex.trailCount=vertex.trailCount+1 end
        if cell.naturalWater then vertex.waterSum=vertex.waterSum+cell.height;vertex.waterCount=vertex.waterCount+1 end
        if options and options.navigationCorners and not cell.blocked then
            vertex.navigationHeights=vertex.navigationHeights or {}
            vertex.navigationHeights[#vertex.navigationHeights+1]=cell.height
        end
    end end
    local surfaces=config:GetTable('MapAreaSurfaceTable')
    for _,cell in ipairs(area.cells) do
        cell.corners={};local low,high=cell.height,cell.height
        for i=1,6 do
            local v=vertices[key(cell,i)]
            local height=v.waterCount>0 and v.waterSum/v.waterCount or (v.trailCount>0 and v.trailSum/v.trailCount or v.sum/v.count)
            if options and options.vertexHeight then
                if v.sampledHeight==nil then
                    local offset=offsets[i];local r=cell.r+offset[2]/3;local q=cell.q+(offset[1]-offset[2]/3)/2
                    v.sampledHeight=options.vertexHeight(q,r)
                end
                height=v.sampledHeight
            end
            if v.navigationHeights then
                if v.navigationHeight==nil then
                    local values=v.navigationHeights;table.sort(values)
                    -- A hex vertex has at most three owners. Its median lies between each touching
                    -- walkable pair, so a monotone center route cannot acquire a crest at the edge.
                    v.navigationHeight=#values==2 and (values[1]+values[2])*.5 or values[(#values+1)//2]
                end
                height=v.navigationHeight
            end
            if options and options.flatTops then height=cell.height end
            cell.corners[i]=height;low=math.min(low,height);high=math.max(high,height)
        end
        -- Steep scenic faces are solid rendered terrain but cannot be entered.
        cell.blocked=cell.naturalBarrier or high-low>row.maxWalkRise*2.5
        cell.floorAccent=surfaces:Get(cell.surfaceId).baseColor;cell.floorAccentWeight=1
    end
    for _,cell in ipairs(area.cells) do
        cell.walkMask=0
        if not cell.blocked then for direction,index in ipairs(cell.neighbors) do
            local other=area.cells[index]
            if other and not other.blocked and math.abs(cell.height-other.height)<=row.maxWalkRise
                and (not options or not options.connect or options.connect(cell,other)) then
                cell.walkMask=cell.walkMask | (1 << (direction-1))
            end
        end end
    end
    local entry=assert(area.cells[area.entryIndex]);assert(not entry.blocked,'Natural terrain entry must be walkable')
    local queue,seen,head={entry.index},{[entry.index]=true},1
    while head<=#queue do
        local cell=area.cells[queue[head]];head=head+1
        for _,other in ipairs(area:Neighbors(cell)) do if not seen[other.index] then seen[other.index]=true;queue[#queue+1]=other.index end end
    end
    for _,trail in ipairs(area.trails) do for _,node in ipairs(trail) do assert(seen[node.index],'Natural terrain graded trail is disconnected') end end
    if options and options.requireAllOpen then
        for _,cell in ipairs(area.cells) do assert(cell.blocked or seen[cell.index],'Mountain ascent left an unreachable open cell') end
    end
    -- Only the entry-connected slope domain is navigable; isolated mountaintops stay scenery.
    for _,cell in ipairs(area.cells) do if not seen[cell.index] then cell.blocked=true;cell.walkMask=0 end end
    for _,cell in ipairs(area.cells) do for direction,index in ipairs(cell.neighbors) do
        if index==0 or area.cells[index].blocked then cell.walkMask=cell.walkMask & (~(1 << (direction-1))) end
    end end
    area.walkableCount=#queue
    assert(seen[area.goalIndex] and #queue>=row.minWalkableCells,'Natural terrain lacks connected exploration space')
    area.goalDistance=#assert(area:FindPath(area.entryIndex,area.goalIndex))
    area.cells[area.entryIndex].kind='entry';area.cells[area.goalIndex].kind='landmark'
end
return Terrain
