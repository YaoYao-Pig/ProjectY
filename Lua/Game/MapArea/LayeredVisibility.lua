-- 可选多层探索视线：按射线穿过的六角柱查询楼板和墙，不遍历全图。
-- 几何沿用 TownSurfaceRenderer：六角扇形顶面、向下量化踏步、最低角点下方的平板底。
local Hex=require('Game.Map.HexGrid')
local Visibility={}
local epsilon=0.000001
local corners,normals,neighborQ,neighborR={},{},{},{}
local sqrt3=math.sqrt(3)
-- 仅缓存平移不变的六角射线数学模板；不包含地图格、可见性或动态营造状态。
local rays={}
for i=1,6 do
    local angle=math.rad(30+60*(i-1));corners[i]={math.cos(angle),math.sin(angle)}
    local q,r=Hex.Neighbor(0,0,i);local x,_,z=Hex.ToWorld(q,r,0,1);normals[i]={x,z};neighborQ[i]=q;neighborR[i]=r
end
local function stepHeight(height,rise)
    return rise>0 and math.floor(height/rise+.0001)*rise or height
end
-- 在线段参数区间内裁剪 a+b*t>=0；空区间返回 nil。
local function clip(first,last,a,b)
    if math.abs(b)<1e-12 then if a<0 then return nil end;return first,last end
    local t=-a/b
    if b>0 then first=math.max(first,t) else last=math.min(last,t) end
    if first>last then return nil end
    return first,last
end
local function heightOverlap(first,last,y,dy,bottom,top)
    local a,b=y+dy*first,y+dy*last
    return math.max(a,b)>=bottom and math.min(a,b)<=top
end
-- 只在一次 VisibleFrom 内缓存坐标和几何，避开每条射线重复穿越冻结代理/扫描角点。
-- 该表不挂到布局上，也不跨移动/营造查询保存。
local function geometry(cell,area)
    local height=cell.height;local rise=cell.stairRise or 0;local values
    local low,high=height,height
    if cell.corners then
        values={};for i,value in ipairs(cell.corners) do values[i]=value;low=math.min(low,value);high=math.max(high,value) end
    end
    local thickness=cell.deckThickness or 0
    local bottom=cell.layer==0 and thickness<=0 and -math.huge or low-thickness
    local wall=cell.blocksSight and (cell.sightHeight or cell.wallHeight or assert(area.theme.wallHeight,'Layered sight blockers need a height'))
    return {index=cell.index,q=cell.q,r=cell.r,height=height,rise=rise,corners=values,bottom=bottom,top=stepHeight(high,rise),
        floor=cell.renderGround~=false and cell.kind~='water',flat=high-low<1e-8,wallTop=wall and height+wall,
        x=sqrt3*(cell.q+cell.r/2),z=1.5*cell.r,cell=cell}
end
local function column(query,q,r)
    local area=query.area
    if q<0 or r<0 or q>=query.width or r>=query.height then return nil end
    local key=r*query.width+q;local result=query.columns[key]
    if result then return result end
    result={};query.columns[key]=result
    for layer=0,query.layerCount-1 do
        local cell=area:Find(q,r,layer)
        if cell then local value=geometry(cell,area);result[#result+1]=value;query.cells[cell.index]=value end
    end
    return result
end
local function newQuery(area)
    assert(math.tointeger(area.layerCount) and area.layerCount>0,'Layered visibility needs a positive layerCount')
    local base=area.baseLayout or area
    return {area=base,width=base.width,height=base.height,layerCount=base.layerCount,columns={},cells={}}
end
local function floorBlocks(cell,x,z,dx,dz,y,dy,first,last)
    if not cell.floor or not heightOverlap(first,last,y,dy,cell.bottom,cell.top) then return false end
    if cell.flat then return true end
    local height,rise,bottom=cell.height,cell.rise,cell.bottom
    for i=1,6 do
        local j=i%6+1;local a,b=corners[i],corners[j]
        local determinant=a[1]*b[2]-a[2]*b[1]
        local u,du=(x*b[2]-z*b[1])/determinant,(dx*b[2]-dz*b[1])/determinant
        local v,dv=(a[1]*z-a[2]*x)/determinant,(a[1]*dz-a[2]*dx)/determinant
        local start,finish=clip(first,last,u,du)
        if start then start,finish=clip(start,finish,v,dv) end
        if start then start,finish=clip(start,finish,1-u-v,-du-dv) end
        if start then
            local ha,hb=cell.corners[i]-height,cell.corners[j]-height
            local h,dh=height+ha*u+hb*v,ha*du+hb*dv
            if rise<=0 then
                start,finish=clip(start,finish,h-y,dh-dy)
                if start and heightOverlap(start,finish,y,dy,bottom,math.huge) then return true end
            else
                local min=math.min(h+dh*start,h+dh*finish)
                local max=math.max(h+dh*start,h+dh*finish)
                for band=math.floor(min/rise+.0001),math.floor(max/rise+.0001) do
                    local bandLow=band*rise
                    local near,far=clip(start,finish,h-bandLow,dh)
                    if near then near,far=clip(near,far,bandLow+rise-h,-dh) end
                    if near and heightOverlap(near,far,y,dy,bottom,bandLow) then return true end
                end
            end
        end
    end
    return false
end
local function columnBlocks(cells,origin,target,x,z,dx,dz,y,dy,first,last)
    if not cells then return true end
    local a,b=y+dy*first,y+dy*last;local low,high=math.min(a,b),math.max(a,b)
    for _,cell in ipairs(cells) do
        if cell.floor and high>=cell.bottom and low<=cell.top then
            if cell.flat or floorBlocks(cell,x,z,dx,dz,y,dy,first,last) then return true end
        end
        -- 被观察墙格本身可见，但它的地板仍阻挡跨层视线。
        if cell.wallTop and cell.index~=origin.index and cell.index~=target.index then
            if high>=cell.height and low<=cell.wallTop then return true end
        end
    end
    return false
end
local function rayPath(dq,dr,distance,offset)
    local x,z=offset,offset
    local dx,dz=sqrt3*(dq+dr/2),1.5*dr
    local q,r,first=0,0,0;local path={dx=dx,dz=dz}
    -- 每个投影六角内裁剪同一条射线；双偏移覆盖沿公共顶点的两侧，禁止从墙缝窥视。
    for _=1,distance*3+6 do
        local cx,cz=sqrt3*(q+r/2),1.5*r
        local last,direction=1,nil
        for i,normal in ipairs(normals) do
            local speed=dx*normal[1]+dz*normal[2]
            if speed>1e-12 then
                local exit=(1.5-(x-cx)*normal[1]-(z-cz)*normal[2])/speed
                if exit<last then last,direction=exit,i end
            end
        end
        path[#path+1]={q=q,r=r,x=x-cx,z=z-cz,first=first,last=last}
        if last>=1 then return path end
        assert(direction and last>=first-1e-10,'Layered visibility left its hex ray interval')
        q=q+neighborQ[direction];r=r+neighborR[direction];first=last
    end
    error('Layered visibility hex traversal exceeded its bounded ray length')
end
local function clearRay(query,origin,target,path,y,dy)
    for _,part in ipairs(path) do
        if columnBlocks(column(query,origin.q+part.q,origin.r+part.r),origin,target,part.x,part.z,path.dx,path.dz,y,dy,part.first,part.last) then return false end
    end
    return true
end
function Visibility.CanSee(area,origin,target,query)
    if origin.index==target.index then return true end
    query=query or newQuery(area)
    if not query.cells[origin.index] then column(query,origin.q,origin.r) end
    if not query.cells[target.index] then column(query,target.q,target.r) end
    local a,b=query.cells[origin.index],query.cells[target.index]
    local dq,dr=b.q-a.q,b.r-a.r;local distance=(math.abs(dq)+math.abs(dr)+math.abs(dq+dr))//2
    local key=Hex.Key(dq,dr);local paths=rays[key]
    if not paths then paths={rayPath(dq,dr,distance,-epsilon),rayPath(dq,dr,distance,epsilon)};rays[key]=paths end
    local y=stepHeight(origin.height,a.rise)+1.6
    local dy=stepHeight(target.height,b.rise)+1.6-y
    return clearRay(query,a,b,paths[1],y,dy) and clearRay(query,a,b,paths[2],y,dy)
end
function Visibility.NewQuery(area) return newQuery(area) end
function Visibility.VisibleFrom(area,index,query)
    local origin=assert(area.cells[index]);local radius=area.visionRadius;local result={};query=query or newQuery(area)
    for dr=-radius,radius do for dq=math.max(-radius,-dr-radius),math.min(radius,-dr+radius) do
        for layer=0,area.layerCount-1 do
            local target=area:Find(origin.q+dq,origin.r+dr,layer)
            if target and area:CanSee(origin,target,query) then result[#result+1]=target.index end
        end
    end end
    return result
end
return Visibility
