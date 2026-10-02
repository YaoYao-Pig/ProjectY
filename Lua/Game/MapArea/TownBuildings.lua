-- 可进入建筑的静态契约：米制模型、室内地格、真实门洞边与可剖切上盖。
-- 室内身份由小队占格推导，不另存“当前建筑”这一份可变游戏状态。
local Geometry=require('Game.MapArea.DungeonGeometry')
local Hex=require('Game.Map.HexGrid')
local Buildings={};Buildings.__index=Buildings
function Buildings.New(area,config)
    area.interiors={}
    return setmetatable({area=area,definitions=config:GetTable('MapAreaTownInteriorTable'),floors=config:GetTable('MapAreaTownFloorTable')},Buildings)
end
function Buildings:Doors(lot,q,r,rotation)
    local result,seen={},{}
    local function add(x,y)
        local dq,dr=Geometry.Rotate(x,y,rotation);local cell=self.area:Find(q+dq,r+dr)
        if not cell then return false end
        if not seen[cell.index] then result[#result+1]=cell;seen[cell.index]=true end
        return true
    end
    if not add(lot.entryQ,lot.entryR) then return nil end
    local definition=self:Definition(lot)
    if definition then
        assert(#definition.doorQ==#definition.doorR and #definition.doorQ==#definition.doorInsideQ and #definition.doorQ==#definition.doorInsideR,'Building portal arrays differ')
        for i,x in ipairs(definition.doorQ) do if not add(x,definition.doorR[i]) then return nil end end
    end
    return result
end
function Buildings:Portals(lot,q,r,rotation,cells)
    local definition=assert(self:Definition(lot));local portals={}
    local inside={};for _,cell in ipairs(cells) do inside[cell.index]=true end
    local function at(x,y)local dq,dr=Geometry.Rotate(x,y,rotation);return assert(self.area:Find(q+dq,r+dr)) end
    if #definition.doorQ==0 then
        local door=at(lot.entryQ,lot.entryR)
        for _,cell in ipairs(cells) do if Hex.Distance(cell.q,cell.r,door.q,door.r)==1 then portals[#portals+1]={outside=door,inside=cell} end end
    else
        for i,x in ipairs(definition.doorQ) do
            local outside=at(x,definition.doorR[i]);local floor=at(definition.doorInsideQ[i],definition.doorInsideR[i])
            assert(inside[floor.index] and not inside[outside.index] and Hex.Distance(outside.q,outside.r,floor.q,floor.r)==1,'Building portal must join an adjacent outside and inside cell')
            portals[#portals+1]={outside=outside,inside=floor}
        end
    end
    assert(#portals>0,'Building has no door edges');return portals
end
-- 候选阶段与正式落地使用相同的外墙截边，避免先按穿墙通路验连通再封死街区。
function Buildings:LimitEdges(cells,portals)
    local inside,allowed,saved={},{},{}
    for _,cell in ipairs(cells) do inside[cell.index]=true end
    for _,portal in ipairs(portals) do allowed[portal.inside.index..':'..portal.outside.index]=true end
    local function remove(from,to)
        if saved[from.index]==nil then saved[from.index]=from.walkMask end
        for d,index in ipairs(from.neighbors) do if index==to.index then from.walkMask=from.walkMask & (~(1 << (d-1))) end end
    end
    for _,cell in ipairs(cells) do for _,index in ipairs(cell.neighbors) do
        local other=self.area.cells[index]
        if other and not inside[index] and not allowed[cell.index..':'..index] then remove(cell,other);remove(other,cell) end
    end end
    return saved,inside
end
function Buildings:Reachable(lot,q,r,rotation)
    local definition=self:Definition(lot)
    if not definition then local queue,distance=Geometry.Reachable(self.area,self.area.entryIndex);return queue,distance,true end
    local cells=assert(self:Cells(definition,q,r,rotation));local portals=self:Portals(lot,q,r,rotation,cells)
    local saved,inside=self:LimitEdges(cells,portals)
    local queue,distance=Geometry.Reachable(self.area,self.area.entryIndex)
    local public,head,seen={self.area.entryIndex},1,{[self.area.entryIndex]=true}
    while head<=#public do
        local cell=self.area.cells[public[head]];head=head+1
        for _,other in ipairs(self.area:Neighbors(cell)) do
            if not inside[other.index] and not other.interiorId and not seen[other.index] then seen[other.index]=true;public[#public+1]=other.index end
        end
    end
    local connected=true
    for _,cell in ipairs(cells) do if not distance[cell.index] then connected=false end end
    for _,door in ipairs(assert(self:Doors(lot,q,r,rotation))) do if not seen[door.index] then connected=false end end
    for index,mask in pairs(saved) do self.area.cells[index].walkMask=mask end
    return queue,distance,connected
end
function Buildings:Definition(lot)
    if not lot.id then return nil end -- 树木等生成期地块没有室内配置。
    return self.definitions:Find(lot.id)
end
function Buildings:Cells(definition,q,r,rotation)
    local result={}
    for i,x in ipairs(definition.interiorQ) do
        local dx,dr=Geometry.Rotate(x,definition.interiorR[i],rotation);local cell=self.area:Find(q+dx,r+dr)
        if not cell then return nil end
        result[#result+1]=cell
    end
    return result
end
function Buildings:CanFit(lot,q,r,rotation,height,accept)
    local definition=self:Definition(lot);if not definition then return true end
    assert(math.abs(self.area.hexRadius-definition.navRadius)<.00001,'Building navigation footprint and meter-scale model radius differ')
    local cells=self:Cells(definition,q,r,rotation);if not cells then return false end
    for _,cell in ipairs(cells) do
        if cell.blocked or cell.interiorId or not accept(cell) or math.abs(cell.height-height)>.01 then return false end
        for _,h in ipairs(cell.corners) do if math.abs(h-height)>.01 then return false end end
    end
    local occupied={}
    for i,x in ipairs(lot.footprintQ) do local dq,dr=Geometry.Rotate(x,lot.footprintR[i],rotation);occupied[Hex.Key(q+dq,r+dr)]=true end
    local doors=self:Doors(lot,q,r,rotation);if not doors then return false end
    for _,door in ipairs(doors) do
        if door.blocked or door.interiorId or occupied[Hex.Key(door.q,door.r)] or math.abs(door.height-height)>.01 then return false end
        for _,h in ipairs(door.corners) do if math.abs(h-height)>.01 then return false end end
    end
    return true
end
function Buildings.Scale(prop,lot)
    if lot.scaleMode=='meters' then prop.scaleX=lot.scale;prop.scaleY=lot.scale;prop.scaleZ=lot.scale end
end
function Buildings:Apply(lot,prop,door)
    Buildings.Scale(prop,lot)
    local definition=self:Definition(lot);if not definition then return door end
    local area=self.area;local id=#area.interiors+1;local cells=assert(self:Cells(definition,prop.q,prop.r,prop.rotation))
    local portals=self:Portals(lot,prop.q,prop.r,prop.rotation,cells)
    local inside,indices={},{}
    for _,cell in ipairs(cells) do
        assert(not cell.blocked and not cell.interiorId,'Interior floor overlaps another building')
        inside[cell.index]=true;indices[#indices+1]=cell.index
        cell.interiorId=id;cell.reserved=true;cell.kind='interior';cell.surfaceId=definition.surfaceId;cell.floorAccent=definition.floorColor;cell.floorAccentWeight=1
    end
    -- 房间只从配置门洞连到街上，不能从窗下、侧墙或相邻院落穿墙进入。
    self:LimitEdges(cells,portals)
    local doorIndices={};for _,entry in ipairs(assert(self:Doors(lot,prop.q,prop.r,prop.rotation))) do entry.reserved=true;doorIndices[#doorIndices+1]=entry.index end
    local edges={};for _,portal in ipairs(portals) do
        assert(area:CanStep(portal.inside,portal.outside) and area:CanStep(portal.outside,portal.inside),'Building portal has no bidirectional terrain edge')
        edges[#edges+1]={outsideIndex=portal.outside.index,insideIndex=portal.inside.index}
    end
    local sq,sr=Geometry.Rotate(definition.serviceQ,definition.serviceR,prop.rotation)
    local service=assert(area:Find(prop.q+sq,prop.r+sr));assert(inside[service.index],'Building service point must be on an interior floor')
    prop.interiorId=id
    area.props[#area.props+1]={id=#area.props+1,assetId=definition.coverAssetId,q=prop.q,r=prop.r,rotation=prop.rotation,height=prop.height,
        scale=lot.scale,scaleX=lot.scale,scaleY=lot.scale,scaleZ=lot.scale,cells=prop.cells,interiorId=id,cutaway=true}
    local room={id=id,lotId=lot.id,doorIndex=door.index,doorIndices=doorIndices,portals=edges,serviceIndex=service.index,cells=indices};area.interiors[id]=room
    local floor=self.floors:Find(lot.id)
    if floor then
        require('Game.MapArea.TownBuildingFloors').Apply(area,floor,definition,prop,room)
        -- 楼梯可能替代原门内的首层格，门户身份必须跟随最终的真实邻接。
        room.portals={}
        for _,index in ipairs(room.cells) do for _,other in ipairs(area:Neighbors(area.cells[index])) do
            if other.interiorId~=id then room.portals[#room.portals+1]={outsideIndex=other.index,insideIndex=index} end
        end end
    end
    return service
end
return Buildings
