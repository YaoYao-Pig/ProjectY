-- 可进入建筑的静态契约：米制模型、室内地格、真实门洞边与可剖切上盖。
-- 室内身份由小队占格推导，不另存“当前建筑”这一份可变游戏状态。
local Geometry=require('Game.MapArea.DungeonGeometry')
local Buildings={};Buildings.__index=Buildings
function Buildings.New(area,config)
    area.interiors={}
    return setmetatable({area=area,definitions=config:GetTable('MapAreaTownInteriorTable')},Buildings)
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
    return true
end
function Buildings.Scale(prop,lot)
    if lot.scaleMode=='meters' then prop.scaleX=lot.scale;prop.scaleY=lot.scale;prop.scaleZ=lot.scale end
end
function Buildings:Apply(lot,prop,door)
    Buildings.Scale(prop,lot)
    local definition=self:Definition(lot);if not definition then return door end
    local area=self.area;local id=#area.interiors+1;local cells=assert(self:Cells(definition,prop.q,prop.r,prop.rotation))
    local inside,indices={},{}
    for _,cell in ipairs(cells) do
        assert(not cell.blocked and not cell.interiorId,'Interior floor overlaps another building')
        inside[cell.index]=true;indices[#indices+1]=cell.index
        cell.interiorId=id;cell.reserved=true;cell.kind='interior';cell.surfaceId=definition.surfaceId;cell.floorAccent=definition.floorColor;cell.floorAccentWeight=1
    end
    local function removeEdge(from,to)
        for direction,index in ipairs(from.neighbors) do if index==to.index then from.walkMask=from.walkMask & (~(1 << (direction-1))) end end
    end
    -- 房间只从配置门洞连到街上，不能从窗下、侧墙或相邻院落穿墙进入。
    for _,cell in ipairs(cells) do for _,index in ipairs(cell.neighbors) do
        local other=area.cells[index]
        if other and not inside[index] and index~=door.index then removeEdge(cell,other);removeEdge(other,cell) end
    end end
    local sq,sr=Geometry.Rotate(definition.serviceQ,definition.serviceR,prop.rotation)
    local service=assert(area:Find(prop.q+sq,prop.r+sr));assert(inside[service.index],'Building service point must be on an interior floor')
    prop.interiorId=id
    area.props[#area.props+1]={id=#area.props+1,assetId=definition.coverAssetId,q=prop.q,r=prop.r,rotation=prop.rotation,height=prop.height,
        scale=lot.scale,scaleX=lot.scale,scaleY=lot.scale,scaleZ=lot.scale,cells=prop.cells,interiorId=id,cutaway=true}
    area.interiors[id]={id=id,lotId=lot.id,doorIndex=door.index,serviceIndex=service.index,cells=indices}
    return service
end
return Buildings
