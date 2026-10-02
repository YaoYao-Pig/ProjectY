-- 真实米制矿道木架、矿轨、矿车和工作台；大件占格后仍须保持整层可达。
local Hex=require('Game.Map.HexGrid')
local Props={}
local function flat(cell)
    return cell and not cell.blocked and cell.kind~='stairs' and cell.renderGround
end
local function supported(area,cell,halfX,halfZ)
    local x,_,z=Hex.ToWorld(cell.q,cell.r,0,area.hexRadius)
    for _,dx in ipairs({-halfX,0,halfX}) do for _,dz in ipairs({-halfZ,0,halfZ}) do
        local q,r=Hex.FromWorld(x+dx,z+dz,area.hexRadius);local support=area:Find(q,r,cell.layer)
        if not flat(support) or math.abs(support.height-cell.height)>.00001 then return false end
    end end
    return true
end
local function block(area,cells)
    for _,cell in ipairs(cells) do if not flat(cell) or cell.reserved then return false end end
    for _,cell in ipairs(cells) do cell.blocked=true end
    local queue,seen,head={area.entryIndex},{[area.entryIndex]=true},1
    while head<=#queue do
        local cell=area.cells[queue[head]];head=head+1
        for _,other in ipairs(area:Neighbors(cell)) do if not seen[other.index] then seen[other.index]=true;queue[#queue+1]=other.index end end
    end
    for _,cell in ipairs(area.cells) do if not cell.blocked and not seen[cell.index] then
        for _,part in ipairs(cells) do part.blocked=false end
        return false
    end end
    return true
end
local function obstacleCells(area,cell,halfX,halfZ)
    local result={};local x,_,z=Hex.ToWorld(cell.q,cell.r,0,area.hexRadius)
    for dr=-2,2 do for dq=-2,2 do
        local other=area:Find(cell.q+dq,cell.r+dr,cell.layer)
        if other then
            local ox,_,oz=Hex.ToWorld(other.q,other.r,0,area.hexRadius)
            if math.abs(x-ox)<halfX+area.hexRadius*.65 and math.abs(z-oz)<halfZ+area.hexRadius*.65 then result[#result+1]=other end
        end
    end end
    return result
end
function Props.Build(area,profile,random,config)
    for _,assetId in ipairs({profile.supportAssetId,profile.railAssetId,profile.cartAssetId,profile.oreAssetId,profile.workstationAssetId}) do
        config:GetTable('MapAssetTable'):Get(assetId)
    end
    local origin=area.mineOrigin;local used={}
    local function add(cell,assetId,kind,yaw,cells)
        local indices={};for _,part in ipairs(cells or {cell}) do indices[#indices+1]=part.index;used[part.index]=true end
        local prop={id=#area.props+1,assetId=assetId,mineKind=kind,q=cell.q,r=cell.r,layer=cell.layer,height=cell.height,
            rotation=0,yaw=yaw or 0,scale=1/area.hexRadius,scaleX=1,scaleY=1,scaleZ=1,cells=indices,
            roomId=cell.roomId,interiorId=0,cutawayGroup=1,cutawayLayer=cell.layer,cameraObstacle=kind=='support'}
        area.props[#area.props+1]=prop;return prop
    end
    local function placeObstacle(cell,assetId,kind,halfX,halfZ,yaw)
        if not flat(cell) or used[cell.index] or not supported(area,cell,halfX,halfZ) then return nil end
        local cells=obstacleCells(area,cell,halfX,halfZ)
        if not block(area,cells) then return nil end
        return add(cell,assetId,kind,yaw,cells)
    end
    -- 两处塌陷正下方明确放置工作设施，供上层视线直接看到下层建筑。
    for _,opening in ipairs(area.openings) do
        local target=assert(area:Find(opening.q,opening.r,opening.layer-1),'Mine opening has no lower floor')
        local prop=assert(placeObstacle(target,profile.workstationAssetId,'workstation',1.35,.84,0),'Mine opening workshop cannot be supported')
        opening.lowerTargetIndex=target.index;opening.lowerPropId=prop.id
    end
    for _,room in ipairs(area.rooms) do
        local row=room.definition
        if row.q~=0 then
            local cell=area:Find(origin.q+row.q,origin.r+row.r+2,row.layer)
            assert(placeObstacle(cell,profile.workstationAssetId,'workstation',1.35,.84,0),'Mine branch workshop cannot be supported')
            local cart=area:Find(origin.q+row.q+2,origin.r+row.r-2,row.layer)
            assert(placeObstacle(cart,profile.cartAssetId,'cart',.9,.66,90),'Mine branch cart cannot be supported')
        end
    end
    -- 木架横跨轨道；两根立柱拥有实际下层支撑和独立占格，中间仍可穿行。
    for layer=0,2 do for q=-16,16,4 do
        local cell=area:Find(origin.q+q,origin.r,layer)
        if flat(cell) and not used[cell.index] and supported(area,cell,.27,2.15) then
            local x,_,z=Hex.ToWorld(cell.q,cell.r,0,area.hexRadius);local posts={}
            for _,dz in ipairs({-1.95,1.95}) do
                local pq,pr=Hex.FromWorld(x,z+dz,area.hexRadius);posts[#posts+1]=assert(area:Find(pq,pr,layer))
            end
            if block(area,posts) then add(cell,profile.supportAssetId,'support',90,posts) end
        end
    end end
    -- 每段模型长一个轴向格间距；在孔洞或设施前终止，不悬空跨井。
    for layer=0,2 do for q=-20,20 do
        local cell=area:Find(origin.q+q,origin.r,layer)
        if flat(cell) and not used[cell.index] and supported(area,cell,.8661,.575) then add(cell,profile.railAssetId,'rail',90) end
    end end
    for layer=0,2 do
        local candidates={}
        for _,cell in ipairs(area.cells) do if cell.layer==layer and flat(cell) and not cell.reserved and not used[cell.index] then
            local wall=false
            for dr=-2,2 do for dq=math.max(-2,-dr-2),math.min(2,-dr+2) do
                local other=area:Find(cell.q+dq,cell.r+dr,layer)
                if other and other.kind=='wall' then wall=true end
            end end
            if wall and supported(area,cell,.76,.71) then candidates[#candidates+1]=cell end
        end end
        local placed=0
        while placed<profile.oreCountPerLayer and #candidates>0 do
            local choice=random:Integer(1,#candidates);local cell=table.remove(candidates,choice)
            -- 只翻转半圈，保持矿石真实占地在单格内；避免旋转包围盒封掉四个侧格。
            local yaw=random:Integer(0,1)*180
            if placeObstacle(cell,profile.oreAssetId,'ore',.76,.71,yaw) then placed=placed+1 end
        end
        assert(placed==profile.oreCountPerLayer,'Mine floor '..layer..' has insufficient supported ore positions: '..placed..'/'..profile.oreCountPerLayer)
    end
    for _,opening in ipairs(area.openings) do
        local best,distance
        for _,cell in ipairs(area.cells) do if cell.layer==opening.layer and flat(cell) then
            local d=Hex.Distance(opening.q,opening.r,cell.q,cell.r)
            if not distance or d<distance then best,distance=cell,d end
        end end
        opening.viewpointIndex=assert(best,'Mine opening has no safe viewing lip').index
        best.reserved=true
    end
end
return Props
