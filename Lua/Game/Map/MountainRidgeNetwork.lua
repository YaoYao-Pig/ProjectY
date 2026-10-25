-- v8：真实占地中的峰/鞍约束、下降支脊和排水谷地；位置噪声只补细节。
-- 借鉴 Hnaidi 2010 特征曲线、Genevaux 2013 脊谷组织，不是完整地质模拟。
local Hex=require('Game.Map.HexGrid')
local Terrain=require('Game.Map.TerrainNoise')
local Network={}
local root3=math.sqrt(3)
local function position(q,r) return q+r*.5,r*root3*.5 end
local function distance2(a,x,z) return (a.x-x)^2+(a.z-z)^2 end
local function node(point,height,width)
    return {q=point.q,r=point.r,x=point.x,z=point.z,height=height,width=width}
end
local function closest(points,x,z,inset)
    local chosen,score
    for _,point in ipairs(points) do
        if point.depth>=inset then
            local value=distance2(point,x,z)
            if not score or value<score then chosen,score=point,value end
        end
    end
    -- 极小裁剪块没有要求的内部层时，取最深点附近；仍不构造轮廓外节点。
    if not chosen then
        for _,point in ipairs(points) do
            local value=distance2(point,x,z)+math.max(0,inset-point.depth)^2*8
            if not score or value<score then chosen,score=point,value end
        end
    end
    return assert(chosen)
end
local function lineSample(a,b,x,z)
    local dx,dz=b.x-a.x,b.z-a.z
    local length=dx*dx+dz*dz
    local t=length>0 and Terrain.Clamp(((x-a.x)*dx+(z-a.z)*dz)/length,0,1) or 0
    local px,pz=a.x+dx*t,a.z+dz*t
    local smooth=t*t*(3-2*t)
    return math.sqrt((x-px)^2+(z-pz)^2),a.height+(b.height-a.height)*smooth,a.width+(b.width-a.width)*t
end
local function alongMain(main,t)
    local span=t*(#main-1)
    local index=math.min(#main-1,math.floor(span)+1)
    local a,b=main[index],main[index+1];local u=span-(index-1)
    return {x=a.x+(b.x-a.x)*u,z=a.z+(b.z-a.z)*u,height=a.height+(b.height-a.height)*(u*u*(3-2*u))}
end

function Network.Prepare(config,region,random,footprint,originQ,originR)
    local points,byKey,boundary,cx,cz={},{},{},0,0
    for _,offset in ipairs(footprint.cells) do
        local q,r=originQ+offset.q,originR+offset.r;local x,z=position(q,r)
        local point={q=q,r=r,x=x,z=z}
        points[#points+1]=point;byKey[Hex.Key(q,r)]=point;cx=cx+x;cz=cz+z
    end
    cx,cz=cx/#points,cz/#points
    for _,point in ipairs(points) do
        for direction=1,6 do
            local q,r=Hex.Neighbor(point.q,point.r,direction)
            if not byKey[Hex.Key(q,r)] then point.depth=0;boundary[#boundary+1]=point;break end
        end
    end
    local queue,head={},1
    for _,point in ipairs(boundary) do queue[#queue+1]=point end
    while head<=#queue do
        local point=queue[head];head=head+1
        for direction=1,6 do
            local q,r=Hex.Neighbor(point.q,point.r,direction);local other=byKey[Hex.Key(q,r)]
            if other and other.depth==nil then other.depth=point.depth+1;queue[#queue+1]=other end
        end
    end
    local center,xx,xz,zz=points[1],0,0,0
    for _,point in ipairs(points) do
        if point.depth>center.depth or point.depth==center.depth and distance2(point,cx,cz)<distance2(center,cx,cz) then center=point end
        local x,z=point.x-cx,point.z-cz;xx=xx+x*x;xz=xz+x*z;zz=zz+z*z
    end
    local angle=math.atan(2*xz,xx-zz)*.5+(random:Noise(center.q,center.r,1,48101)-.5)*.24
    local ax,az=math.cos(angle),math.sin(angle);local negative,positive=0,0
    for _,point in ipairs(points) do
        local along=(point.x-center.x)*ax+(point.z-center.z)*az
        negative=math.min(negative,along);positive=math.max(positive,along)
    end
    local radius=math.max(1,center.depth+1)
    -- 高度受真实内切半径约束，小预算裁剪不再保留原尺寸的针塔。
    local terraceStep=region.hexRadius
    local maxStep=terraceStep*4
    local relief=math.min(config.maxHeight-config.minHeight,radius*root3*region.hexRadius*1.8,
        math.max(0,(radius-1)*maxStep-terraceStep*2))
    local shape={centerQ=center.q,centerR=center.r,radiusCells=radius,baseHeight=config.minHeight,relief=relief,
        detailAmplitude=relief*.025,terraceStep=terraceStep,maxStep=maxStep,
        axisX=ax,axisZ=az,mainRidge={},branches={},valleys={}}
    local main=shape.mainRidge
    local stations={-.84,-.52,-.25,0,.26,.56,.85}
    local levels={.06,.78,.43,1,.49,.70,.05}
    for i,t in ipairs(stations) do
        local extent=t<0 and -negative or positive
        local offset=i==4 and 0 or (random:Noise(i,region.instanceId,1,48113)-.5)*radius*.15
        local inset=(i==1 or i==7) and 0 or (i==2 or i==6) and math.min(3,math.max(0,center.depth-1)) or 2
        local point=closest(points,center.x+ax*t*extent-az*offset,center.z+az*t*extent+ax*offset,inset)
        if i==4 then point=center end
        main[i]=node(point,math.min(relief*levels[i],point.depth*maxStep),math.max(1.2,radius*.78))
    end
    -- 高低峰之间的低鞍应靠近较低峰；按可落坡距离定位，不能一律放在几何中点。
    for _,entry in ipairs({{2,3,4},{4,5,6}}) do
        local a,b=main[entry[1]],main[entry[3]]
        local span=math.max(1,Hex.Distance(a.q,a.r,b.q,b.r))
        local t=Terrain.Clamp(.5+(a.height-b.height)/(2*maxStep*span),.2,.8)
        local point=closest(points,a.x+(b.x-a.x)*t,a.z+(b.z-a.z)*t,1)
        main[entry[2]]=node(point,math.min(a.height,b.height)*.60,math.max(1.2,radius*.78))
    end
    local branchStarts={.17,.28,.40,.59,.71,.83};local sides={-1,1,-1,1,-1,1}
    for i,t in ipairs(branchStarts) do
        local root=alongMain(main,t);local side=sides[i];local sweep=(t-.5)*radius*.45
        local outlet=closest(boundary,root.x-az*side*radius*1.3+ax*sweep,root.z+ax*side*radius*1.3+az*sweep,0)
        local bend=(random:Noise(i,region.instanceId,1,48131)-.5)*radius*.12
        local middle=closest(points,(root.x+outlet.x)*.5+ax*bend,(root.z+outlet.z)*.5+az*bend,1)
        shape.branches[i]={side=side,station=t,nodes={
            {x=root.x,z=root.z,height=root.height*.96,width=radius*.48},
            node(middle,root.height*.44,radius*.37),node(outlet,relief*.015,radius*.26)}}
    end
    -- 同侧相邻支脊之间开沟，谷口只选真实外边界格。
    for i=1,4 do
        local first,last=shape.branches[i],shape.branches[i+2]
        local root=alongMain(main,(first.station+last.station)*.5);local side=first.side
        local headPoint=closest(points,root.x-az*side*radius*.22,root.z+ax*side*radius*.22,1)
        local a,b=first.nodes[3],last.nodes[3]
        local outlet=closest(boundary,(a.x+b.x)*.5,(a.z+b.z)*.5,0)
        local middle=closest(points,(headPoint.x+outlet.x)*.5,(headPoint.z+outlet.z)*.5,1)
        shape.valleys[i]={nodes={node(headPoint,root.height*.46,radius*.14),
            node(middle,root.height*.18,radius*.20),node(outlet,0,radius*.27)}}
    end
    local function sample(point)
        local height,mainDistance,branchHeight=0,math.huge,0
        local function ridge(nodes,isMain)
            for i=1,#nodes-1 do
                local distance,level,width=lineSample(nodes[i],nodes[i+1],point.x,point.z)
                local shoulder=math.max(0,1-distance/math.max(1,width))
                local value=level*shoulder^1.15
                if isMain then
                    -- 沿最近主脊段读取峰/鞍高度，远处高峰不能跨过鞍部把整条脊填平。
                    if distance<mainDistance then mainDistance=distance;height=value end
                else branchHeight=math.max(branchHeight,value) end
            end
        end
        ridge(main,true)
        for _,branch in ipairs(shape.branches) do ridge(branch.nodes,false) end
        height=math.max(height,branchHeight*Terrain.Smooth(radius*.04,radius*.22,mainDistance))
        local original=height
        for _,valley in ipairs(shape.valleys) do for i=1,#valley.nodes-1 do
            local distance,level,width=lineSample(valley.nodes[i],valley.nodes[i+1],point.x,point.z)
            local cut=math.max(original-relief*.28,level+distance*relief/math.max(1,width*3))
            local protection=Terrain.Smooth(radius*.05,radius*.19,mainDistance)
            height=height-math.max(0,height-cut)*protection
        end end
        local envelope=Terrain.Smooth(0,math.min(3,radius*.45),point.depth)
        local detail=(random:Fractal(point.x,point.z,math.max(3,radius*.55),.42,48163)*2-1)*shape.detailAmplitude
        return config.minHeight+Terrain.Clamp((height+detail)*envelope,0,relief)
    end
    local heights={}
    for _,point in ipairs(points) do
        -- 外缘保持低地；靠边的次峰按实际落坡距离限制高度，避免边缘柱林。
        heights[Hex.Key(point.q,point.r)]=math.min(sample(point),config.minHeight+point.depth*maxStep)
    end
    -- 从脊线抬起过低的相邻肩部，而非平均压低整座山；固定传播上界保持确定性。
    -- 最大高度/maxStep 轮之后，任何峰的影响已降到基面；不依赖遍历顺序。
    for _=1,math.ceil(relief/maxStep)+1 do
        local nextHeights={}
        for _,point in ipairs(points) do
            local key=Hex.Key(point.q,point.r);local height=heights[key]
            if point.depth>0 then
                for direction=1,6 do
                    local q,r=Hex.Neighbor(point.q,point.r,direction);local other=heights[Hex.Key(q,r)]
                    if other then height=math.max(height,other-maxStep) end
                end
            end
            nextHeights[key]=height
        end
        heights=nextHeights
    end
    -- 同一高程带归为完整平顶六角台地；maxStep 是层高整数倍，量化后仍最多相差四层。
    for key,height in pairs(heights) do
        heights[key]=config.minHeight+math.floor((height-config.minHeight)/terraceStep+1e-7)*terraceStep
    end
    region.mountainShape=shape
    region._mountainField={heights=heights,points=byKey,base=config.minHeight}
end

function Network.Height(region,q,r)
    local field=assert(region._mountainField,'Mountain footprint must be prepared before sampling')
    return field.heights[Hex.Key(q,r)] or field.base
end
function Network.Landform(region,cell)
    local field=assert(region._mountainField);local key=Hex.Key(cell.q,cell.r)
    local point=assert(field.points[key])
    local elevation=(field.heights[key]-field.base)/math.max(.001,region.mountainShape.relief)
    local blocked=point.depth>=2 and elevation>.045
    return 'HighMountain',not blocked and 'mountainFoot' or elevation>.68 and 'mountainPeak' or 'mountainWall',elevation,blocked
end
return Network
