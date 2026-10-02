-- 船体固定剖面上的真实薄楼板；与城镇共享层身份、双向边和连续梯面约定。
local Hex=require('Game.Map.HexGrid')
local Edges=require('Game.MapArea.LayeredFloorEdges')
local Floors={}
function Floors.HalfWidth(profile,z)
    local zs,ws=profile.deckZ,profile.deckHalfWidth
    if z<zs[1] or z>zs[#zs] then return nil end
    for i=2,#zs do if z<=zs[i] then return ws[i-1]+(ws[i]-ws[i-1])*(z-zs[i-1])/(zs[i]-zs[i-1]) end end
end
function Floors.OnDeck(profile,floor,x,z,margin)
    if z<floor.minZ+margin or z>floor.maxZ-margin then return false end
    local width=Floors.HalfWidth(profile,z)
    if not width or math.abs(x)+margin>width*floor.widthFactor then return false end
    if floor.layer==1 and z>=profile.gapMinZ-margin and z<=profile.gapMaxZ+margin and x<profile.gapMaxX+margin then return false end
    return true
end
function Floors.SafeCell(profile,floor,x,z,radius)
    if not Floors.OnDeck(profile,floor,x,z,profile.navMargin) then return false end
    for side=0,5 do local a=math.rad(30+60*side)
        if not Floors.OnDeck(profile,floor,x+radius*math.cos(a),z+radius*math.sin(a),profile.navMargin) then return false end
    end
    return true
end
function Floors.Build(area,profile,config)
    local origin=assert(area:Find(math.floor(area.width/2),math.floor(area.height/2)))
    local ox,_,oz=Hex.ToWorld(origin.q,origin.r,0,area.hexRadius)
    area.shipOrigin={q=origin.q,r=origin.r,x=ox,z=oz};area.shipProfileId=profile.id
    local definitions={};for _,row in ipairs(config:GetTable('MapAreaShipwreckFloorTable'):All()) do
        if row.profileId==profile.id then definitions[#definitions+1]=row end
    end
    area.shipFloors=definitions
    local rooms={}
    for _,row in ipairs(config:GetTable('MapAreaShipwreckRoomTable'):All()) do if row.profileId==profile.id then
        rooms[#rooms+1]=row;area.rooms[#area.rooms+1]={id=row.id,name=row.name,tier=1,presetId=0,layer=row.layer,cells={},definition=row}
    end end
    local function roomAt(layer,z,stair)
        for i,row in ipairs(rooms) do if row.layer==layer and z>=row.minZ and z<=row.maxZ then return area.rooms[i],row end end
        if stair then
            local best,distance
            for i,row in ipairs(rooms) do if row.layer==layer then
                local delta=math.min(math.abs(z-row.minZ),math.abs(z-row.maxZ))
                if not distance or delta<distance then best,distance=i,delta end
            end end
            if best then return area.rooms[best],rooms[best] end
        end
        error('Ship floor has no room definition at layer '..layer..', z '..z)
    end
    local stairRows,stairKeys={},{}
    for _,row in ipairs(config:GetTable('MapAreaShipwreckStairTable'):All()) do if row.profileId==profile.id then
        assert(#row.q==#row.r and #row.edges==#row.q+1 and #row.q>0,'Ship stair arrays differ')
        stairRows[#stairRows+1]=row;stairKeys[row.toLayer]=stairKeys[row.toLayer] or {}
        for i,q in ipairs(row.q) do stairKeys[row.toLayer][Hex.Key(origin.q+q,origin.r+row.r[i])]=true end
    end end
    local function localPosition(cell)
        local x,_,z=Hex.ToWorld(cell.q,cell.r,0,area.hexRadius);return x-ox,z-oz
    end
    local function prepare(cell,height,kind)
        local _,z=localPosition(cell);local room,row=roomAt(cell.layer,z,kind=='stairs')
        cell.height=height;cell.kind=kind;cell.blocked=false;cell.blocksSight=false;cell.renderGround=true
        cell.walkMask=0;cell.neighbors={0,0,0,0,0,0};cell.deckThickness=profile.deckThickness
        cell.corners={height,height,height,height,height,height};cell.surfaceId=profile.deckSurfaceId;cell.sideSurfaceId=profile.deckSurfaceId
        cell.roomId=room.id;cell.interiorId=row.interiorId;cell.coverInteriorId=row.coverInteriorId
        cell.cutawayGroup=1;cell.cutawayLayer=cell.layer==0 and 0 or 1
        cell.floorAccent=config:GetTable('MapAreaSurfaceTable'):Get(profile.deckSurfaceId).baseColor;cell.floorAccentWeight=1
        room.cells[#room.cells+1]=cell.index
    end
    for _,cell in ipairs(area.cells) do
        cell.height=profile.waterHeight;cell.kind='water';cell.blocked=true;cell.blocksSight=false;cell.renderGround=true
        cell.walkMask=0;cell.neighbors={0,0,0,0,0,0};cell.surfaceId=profile.waterSurfaceId;cell.sideSurfaceId=profile.waterSurfaceId
        cell.floorAccent=config:GetTable('MapAreaSurfaceTable'):Get(profile.waterSurfaceId).baseColor;cell.floorAccentWeight=1
    end
    local baseCount=area.width*area.height
    for _,floor in ipairs(definitions) do
        for i=1,baseCount do local base=area.cells[i];local x,z=localPosition(base)
            if Floors.SafeCell(profile,floor,x,z,area.hexRadius) and not (stairKeys[floor.layer] and stairKeys[floor.layer][Hex.Key(base.q,base.r)]) then
                local cell=floor.layer==0 and base or area:AddLayerCell(base.q,base.r,floor.layer,floor.height)
                prepare(cell,floor.height,'deck')
            end
        end
    end
    area.stairs={}
    for _,row in ipairs(stairRows) do
        local stair={id=row.id,name=row.name,fromLayer=row.fromLayer,toLayer=row.toLayer,cells={}}
        local bottom=assert(area:Find(origin.q+row.bottomQ,origin.r+row.bottomR,row.fromLayer),'Missing ship stair bottom')
        local top=assert(area:Find(origin.q+row.topQ,origin.r+row.topR,row.toLayer),'Missing ship stair top')
        assert(not bottom.blocked and not top.blocked and math.abs(bottom.height-row.edges[1])<.00001 and math.abs(top.height-row.edges[#row.edges])<.00001,'Ship stairs do not meet their floors')
        stair.bottom=bottom.index;stair.top=top.index
        for i,q in ipairs(row.q) do
            local low,high=row.edges[i],row.edges[i+1];assert(high>low,'Ship stair run must rise')
            local cell=area:AddLayerCell(origin.q+q,origin.r+row.r[i],row.toLayer,(low+high)/2)
            prepare(cell,(low+high)/2,'stairs');cell.stairRise=profile.stairRise;cell.reserved=true
            cell.interiorId=bottom.interiorId~=0 and bottom.interiorId or (top.coverInteriorId or top.interiorId)
            cell.cutawayLayer=row.fromLayer==0 and 0 or 1
            stair.cells[#stair.cells+1]=cell.index
        end
        for i,index in ipairs(stair.cells) do
            local cell=area.cells[index];local previous=i==1 and bottom or area.cells[stair.cells[i-1]]
            local following=i==#stair.cells and top or area.cells[stair.cells[i+1]]
            local incoming,outgoing=Edges.Direction(cell,previous),Edges.Direction(cell,following)
            assert((incoming+2)%6+1==outgoing,'Ship stair turns require a landing')
            for _,corner in ipairs(Edges.Corners[incoming]) do cell.corners[corner]=row.edges[i] end
            for _,corner in ipairs(Edges.Corners[outgoing]) do cell.corners[corner]=row.edges[i+1] end
            local lower=area:Find(cell.q,cell.r,row.fromLayer)
            if lower and not lower.blocked and math.min(table.unpack(cell.corners))-cell.deckThickness-lower.height<profile.minimumClearance then
                lower.blocked=true;lower.stairBase=true
            end
        end
        area.stairs[#area.stairs+1]=stair
    end
    -- 同层仅连接真实相邻楼板。楼梯井和水面缺边，不允许从主甲板破口跳向下舱。
    for _,cell in ipairs(area.cells) do if not cell.blocked and cell.kind~='stairs' then
        for d=1,6 do local q,r=Hex.Neighbor(cell.q,cell.r,d);local other=area:Find(q,r,cell.layer)
            if other and not other.blocked and other.kind~='stairs' then Edges.Connect(cell,other) end
        end
    end end
    for _,stair in ipairs(area.stairs) do
        local previous=area.cells[stair.bottom];previous.reserved=true
        for _,index in ipairs(stair.cells) do Edges.Connect(previous,area.cells[index]);previous=area.cells[index] end
        Edges.Connect(previous,area.cells[stair.top]);area.cells[stair.top].reserved=true
    end
    for _,cell in ipairs(area.cells) do if not cell.blocked and cell.layer>0 then
        for layer=0,cell.layer-1 do local lower=area:Find(cell.q,cell.r,layer)
            if lower and not lower.blocked then
                assert(math.min(table.unpack(cell.corners))-cell.deckThickness-math.max(table.unpack(lower.corners))>=profile.minimumClearance-.00001,'Ship floor leaves insufficient headroom')
            end
        end
    end end
    -- 可视楼板延伸至模型周界木带内缘，导航仍保留原完整六角与安全余量。
    local Boundary=require('Game.MapArea.FloorBoundary')
    for _,floor in ipairs(definitions) do
        local zs={floor.boundaryMinZ,floor.boundaryMaxZ}
        for _,z in ipairs(profile.deckZ) do if z>floor.boundaryMinZ and z<floor.boundaryMaxZ then zs[#zs+1]=z end end
        table.sort(zs)
        local samples={}
        local function width(z) return assert(Floors.HalfWidth(profile,z))*floor.boundaryWidthFactor-floor.boundaryInset end
        for i,z in ipairs(zs) do
            local w=width(z)
            if i>1 then
                local previous=zs[i-1];local before=width(previous)
                if before*w<0 then samples[#samples+1]={z=previous+(z-previous)*before/(before-w),w=0} end
            end
            if w>=0 then samples[#samples+1]={z=z,w=w} end
        end
        assert(#samples>=2,'Ship trim inner boundary has no positive width')
        local outer={}
        for _,sample in ipairs(samples) do outer[#outer+1]=ox+sample.w;outer[#outer+1]=oz+sample.z end
        for i=#samples,1,-1 do outer[#outer+1]=ox-samples[i].w;outer[#outer+1]=oz+samples[i].z end
        local owners={}
        for _,cell in ipairs(area.cells) do if cell.layer==floor.layer and cell.kind~='stairs' and cell.kind~='water' and math.abs(cell.height-floor.height)<.00001 then
            local _,z=localPosition(cell);if z>=floor.minZ and z<=floor.maxZ then owners[#owners+1]=cell.index end
        end end
        local holes={}
        if floor.layer==1 then
            local left=ox-math.max(table.unpack(profile.deckHalfWidth))*floor.boundaryWidthFactor-1
            holes[1]={left,oz+profile.gapMinZ,ox+profile.gapMaxX,oz+profile.gapMinZ,
                ox+profile.gapMaxX,oz+profile.gapMaxZ,left,oz+profile.gapMaxZ}
        end
        Boundary.Register(area,{cells=owners,outer=outer,holes=holes,height=floor.height,thickness=profile.deckThickness,rings=2})
    end
    return rooms
end
return Floors
