-- 船舱固定构件和独立小物池。所有家具、门与桌面小物保持真实米制尺度。
local Hex=require('Game.Map.HexGrid')
local Props={}
local function localPosition(area,cell)
    local x,_,z=Hex.ToWorld(cell.q,cell.r,0,area.hexRadius);return x-area.shipOrigin.x,z-area.shipOrigin.z
end
local function rotate(x,z,yaw)
    local a=math.rad(yaw);return x*math.cos(a)+z*math.sin(a),z*math.cos(a)-x*math.sin(a)
end
local function box(x,z,hx,hz,cx,cz,yaw,layer)
    local dx,dz=rotate(cx,cz,yaw);local a=math.rad(yaw)
    return {x=x+dx,z=z+dz,halfX=hx*math.abs(math.cos(a))+hz*math.abs(math.sin(a)),
        halfZ=hz*math.abs(math.cos(a))+hx*math.abs(math.sin(a)),layer=layer}
end
local function overlaps(a,b,margin)
    return a.layer==b.layer and math.abs(a.x-b.x)<a.halfX+b.halfX+(margin or 0) and math.abs(a.z-b.z)<a.halfZ+b.halfZ+(margin or 0)
end
local function anchor(area,q,r,layer,structural)
    local cell=area:Find(q,r,layer)
    if cell and cell.kind~='water' then return cell end
    assert(structural,'Fixed ship furniture is outside its floor: '..q..','..r..' layer '..layer)
    for _,candidate in ipairs(area.cells) do if candidate.layer==layer and not candidate.blocked then return candidate end end
    error('Ship structural visibility anchor has no floor')
end
function Props.Fixed(area,profile,config)
    area.propBounds={};area.shipSupports={}
    for _,row in ipairs(config:GetTable('MapAreaShipwreckPlacementTable'):All()) do if row.profileId==profile.id then
        config:GetTable('MapAssetTable'):Get(row.assetId)
        local q,r=area.shipOrigin.q+row.q,area.shipOrigin.r+row.r
        local cell=anchor(area,q,r,row.layer,row.structural)
        if not row.structural then assert(cell.kind~='stairs' and math.abs(cell.height-row.height)<.001,'Furniture must rest on a flat ship floor: '..row.id) end
        local x,_,z=Hex.ToWorld(q,r,0,area.hexRadius);x=x-area.shipOrigin.x+row.offsetX;z=z-area.shipOrigin.z+row.offsetZ
        local boxes={}
        if row.blocksMovement then
            if row.doorHalfWidth>0 then
                local half=(row.halfX-row.doorHalfWidth)/2;local center=(row.halfX+row.doorHalfWidth)/2
                for _,side in ipairs({-1,1}) do boxes[#boxes+1]=box(x,z,half,row.halfZ,row.centerX+side*center,row.centerZ,row.yaw,row.layer) end
            else boxes[1]=box(x,z,row.halfX,row.halfZ,row.centerX,row.centerZ,row.yaw,row.layer) end
        end
        local cells={}
        for _,candidate in ipairs(area.cells) do if candidate.layer==row.layer and candidate.kind~='water' then
            local cx,cz=localPosition(area,candidate)
            for _,bounds in ipairs(boxes) do
                if math.abs(cx-bounds.x)<bounds.halfX+area.hexRadius*.8660254+.10 and math.abs(cz-bounds.z)<bounds.halfZ+area.hexRadius+.10 then
                    assert(candidate.kind~='stairs' and not candidate.stairBase,'Furniture intersects a ship staircase: '..row.id)
                    candidate.blocked=true;cells[#cells+1]=candidate.index;break
                end
            end
        end end
        if #cells==0 then cells[1]=cell.index end
        local prop={id=#area.props+1,placementId=row.id,assetId=row.assetId,q=q,r=r,offsetX=row.offsetX,offsetZ=row.offsetZ,layer=row.layer,height=row.height,yaw=row.yaw,rotation=0,
            scale=row.scale/area.hexRadius,scaleX=row.scale,scaleY=row.scale,scaleZ=row.scale,cells=cells,cameraObstacle=row.cameraObstacle,
            interiorId=row.interiorId~=0 and row.interiorId or (cell.coverInteriorId~=0 and cell.coverInteriorId or cell.interiorId),
            cutawayGroup=1,cutawayLayer=row.cutawayLayer,roomId=cell.roomId,bounds=boxes}
        area.props[#area.props+1]=prop
        for _,bounds in ipairs(boxes) do bounds.placementId=row.id;area.propBounds[#area.propBounds+1]=bounds end
        if row.surfaceHeight>0 then area.shipSupports[#area.shipSupports+1]={prop=prop,row=row,slots={}} end
    end end
end
function Props.Dress(area,profile,random,config)
    local surfaceUsed={}
    local function belongs(ids,id) for _,value in ipairs(ids) do if value==id then return true end end;return false end
    for _,support in ipairs(area.shipSupports) do
        local row=support.row
        for ix=1,3 do
            local x=row.surfaceMinX+(row.surfaceMaxX-row.surfaceMinX)*(ix-.5)/3
            local rows=row.surfaceMaxZ-row.surfaceMinZ>=.9 and 2 or 1
            for iz=1,rows do
                support.slots[#support.slots+1]={x=x,z=row.surfaceMinZ+(row.surfaceMaxZ-row.surfaceMinZ)*(iz-.5)/rows}
            end
        end
    end
    for _,row in ipairs(config:GetTable('MapAreaShipwreckDressingTable'):All()) do if row.profileId==profile.id then
        config:GetTable('MapAssetTable'):Get(row.assetId)
        local placed=0
        for _=1,row.count do
            local candidates={}
            if row.placement=='surface' then
                for _,support in ipairs(area.shipSupports) do if belongs(row.roomIds,support.prop.roomId) then
                    for i,slot in ipairs(support.slots) do if not slot.used then
                        local parent=support.row
                        if slot.x+row.centerX-row.halfX>=parent.surfaceMinX and slot.x+row.centerX+row.halfX<=parent.surfaceMaxX and
                            slot.z+row.centerZ-row.halfZ>=parent.surfaceMinZ and slot.z+row.centerZ+row.halfZ<=parent.surfaceMaxZ then
                            candidates[#candidates+1]={support=support,slot=slot}
                        end
                    end end
                end end
            else
                for _,cell in ipairs(area.cells) do if not cell.blocked and not cell.reserved and cell.kind~='stairs' and not surfaceUsed[cell.index] and belongs(row.roomIds,cell.roomId) then
                    candidates[#candidates+1]={cell=cell}
                end end
            end
            if #candidates==0 then assert(placed>0,'No supported position for ship dressing asset '..row.assetId);break end
            local choice=candidates[random:Integer(1,#candidates)]
            local prop
            if choice.support then
                local parent=choice.support.prop;local slot=choice.slot;slot.used=true
                local dx,dz=rotate(slot.x,slot.z,parent.yaw)
                prop={q=parent.q,r=parent.r,offsetX=(parent.offsetX or 0)+dx,offsetZ=(parent.offsetZ or 0)+dz,layer=parent.layer,height=parent.height+choice.support.row.surfaceHeight-row.baseY,
                    yaw=parent.yaw,rotation=0,cells={parent.cells[1]},roomId=parent.roomId,interiorId=parent.interiorId,supportId=parent.id,
                    supportHeight=parent.height+choice.support.row.surfaceHeight,localX=slot.x,localZ=slot.z}
            else
                local cell=choice.cell;surfaceUsed[cell.index]=true
                prop={q=cell.q,r=cell.r,layer=cell.layer,height=cell.height-row.baseY,yaw=random:Integer(0,5)*60,rotation=0,cells={cell.index},
                    roomId=cell.roomId,interiorId=cell.coverInteriorId~=0 and cell.coverInteriorId or cell.interiorId}
            end
            prop.id=#area.props+1;prop.assetId=row.assetId;prop.scale=1/area.hexRadius;prop.scaleX=1;prop.scaleY=1;prop.scaleZ=1
            prop.cameraObstacle=false;prop.cutawayGroup=1;prop.cutawayLayer=prop.layer==0 and 0 or 1
            prop.dressingId=row.id;area.props[#area.props+1]=prop;placed=placed+1
        end
    end end
end
Props.Overlaps=overlaps
return Props
