-- 山城的地面、台阶坡道与上层桥路；每一条可走边同时用于寻路、编队、NPC 与显示。
local Hex=require('Game.Map.HexGrid')
local Geometry=require('Game.MapArea.DungeonGeometry')
local Terrain={}
local corners={{1,6,3,4},{5,6,3,2},{4,5,2,1},{3,4,1,6},{2,3,6,5},{1,2,5,4}}
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
function Terrain.Build(area,row,random)
    local turn=random:Integer(0,5);local cq,cr=area.width//2,area.height//2
    local step=row.terraceHeight*area.theme.reliefScale
    assert(step*2-row.bridgeThickness>=row.bridgeClearance,'Town bridge clearance is below its configured minimum')
    local context={turn=turn,step=step,connectors={},streets=row.streetRows}
    function context:World(q,r) local x,y=Geometry.Rotate(q,r,turn);return cq+x,cr+y end
    function context:Local(q,r) return Geometry.Rotate(q-cq,r-cr,-turn) end
    function context:Cell(q,r,layer) local x,y=self:World(q,r);return area:Find(x,y,layer) end
    local low,mid,upper,high=table.unpack(row.streetRows)
    assert(#row.streetRows==4 and low-mid>=9 and mid-upper>=9 and upper-high>=9,'Town needs four separated contour streets')
    local boundaries={(low+mid)/2,(mid+upper)/2,(upper+high)/2}
    local function level(v)
        if v>=boundaries[1] then return 0 elseif v>=boundaries[2] then return 1 elseif v>=boundaries[3] then return 2 else return 3 end
    end
    local function add(axis,cross,lowAt,highAt,bottom,top,style)
        context.connectors[#context.connectors+1]={axis=axis,cross=cross,lowAt=lowAt,highAt=highAt,bottom=bottom,top=top,style=style}
    end
    local length=row.rampLength
    add('v',0,boundaries[1]+length/2,boundaries[1]-length/2,0,step,'stairs')
    for _,side in ipairs({-1,1}) do
        add('u',upper,side*row.valleyHalfWidth,side*(row.valleyHalfWidth+length),step,step*2,side<0 and 'stairs' or 'ramp')
        add('v',side*(row.halfWidth-2),boundaries[3]+length/2,boundaries[3]-length/2,step*2,step*3,side<0 and 'ramp' or 'stairs')
    end
    for _,cell in ipairs(area.cells) do
        local q,r=context:Local(cell.q,cell.r);local u=q+r/2
        cell.localQ=q;cell.localR=r;cell.kind='garden';cell.blocksSight=false;cell.surface='ground'
        cell.blocked=math.abs(u)>row.halfWidth or r<high-6 or r>low+8
        cell.height=level(r)*step
        if math.abs(u)<row.valleyHalfWidth then cell.height=math.min(cell.height,step) end
        local connector
        for _,candidate in ipairs(context.connectors) do
            local along=candidate.axis=='v' and r or u;local cross=candidate.axis=='v' and u or r
            if math.abs(cross-candidate.cross)<=row.rampWidth/2 and along>=math.min(candidate.lowAt,candidate.highAt)-.7
                and along<=math.max(candidate.lowAt,candidate.highAt)+.7 then connector=candidate;break end
        end
        local function sample(dx,dz)
            if not connector then return cell.height end
            -- 把世界六边形顶点转回街区局部坐标，保证整体旋转后坡面接缝仍一致。
            local angle=math.rad(-turn*60);local x=dx*math.cos(angle)-dz*math.sin(angle);local z=dx*math.sin(angle)+dz*math.cos(angle)
            local along=connector.axis=='v' and r+z/1.5 or u+x/math.sqrt(3)
            local t=clamp((along-connector.lowAt)/(connector.highAt-connector.lowAt),0,1)
            return connector.bottom+(connector.top-connector.bottom)*t
        end
        cell.corners={}
        for i=1,6 do local angle=math.rad(30+(i-1)*60);cell.corners[i]=sample(math.cos(angle),math.sin(angle)) end
        if connector then
            cell.height=sample(0,0);cell.kind=connector.style;cell.reserved=true
            cell.stairRise=connector.style=='stairs' and row.stairRise or 0
            cell.floorAccent=area.theme.roadColor;cell.floorAccentWeight=.9
        end
        cell.townInside=not cell.blocked
        if not cell.blocked then area.walkableCount=area.walkableCount+1 end
    end
    -- 桥下保留完整地面，桥面增加独立 layer=1 地格；桥侧没有跃下或斜穿栏杆的邻接边。
    local bridgeRow=high;local bridgeCells={};local half=(row.bridgeWidth-1)//2
    for r=bridgeRow-half,bridgeRow+half do
        for q=-row.halfWidth,row.halfWidth do
            local u=q+r/2
            if math.abs(u)<row.valleyHalfWidth then
                local base=assert(context:Cell(q,r));assert(not base.blocked)
                local cell=area:AddLayerCell(base.q,base.r,1,step*3)
                cell.localQ=q;cell.localR=r;cell.corners={cell.height,cell.height,cell.height,cell.height,cell.height,cell.height}
                cell.deckThickness=row.bridgeThickness;cell.floorAccent=area.theme.plazaColor;cell.floorAccentWeight=.95
                bridgeCells[#bridgeCells+1]=cell.index
            end
        end
    end
    Terrain.Connect(area,row)
    context.bridgeCells=bridgeCells;context.bridgeRow=bridgeRow
    return context
end
function Terrain.Connect(area,row)
    local function compatible(from,to,direction)
        if not to or from.blocked or to.blocked or math.abs(from.height-to.height)>row.maxWalkRise then return false end
        if from.layer~=to.layer and from.localR~=to.localR then return false end
        local pair=corners[direction]
        return math.max(math.abs(from.corners[pair[1]]-to.corners[pair[3]]),math.abs(from.corners[pair[2]]-to.corners[pair[4]]))<=row.maxEdgeRise
    end
    for _,cell in ipairs(area.cells) do
        cell.walkMask=0
        for d=1,6 do
            local q,r=Hex.Neighbor(cell.q,cell.r,d)
            local other=area:Find(q,r,cell.layer)
            if cell.layer==1 and not other then other=area:Find(q,r) end
            if cell.layer==0 and not compatible(cell,other,d) then
                local upperCell=area:Find(q,r,1)
                if compatible(cell,upperCell,d) then other=upperCell end
            end
            cell.neighbors[d]=other and other.index or 0
            if compatible(cell,other,d) then cell.walkMask=cell.walkMask | (1 << (d-1)) end
        end
    end
end
return Terrain
