-- 纯显示封边：裁切边界附近的空六角，不创建地格、不改变通行与占格。
local Hex=require('Game.Map.HexGrid')
local Boundary={}
local epsilon=1e-8
local function area(points)
    local value=0
    for i=1,#points,2 do local j=i+2;if j>#points then j=1 end;value=value+points[i]*points[j+1]-points[j]*points[i+1] end
    return value/2
end
local function clean(points)
    local result={}
    for i=1,#points,2 do
        if #result==0 or (points[i]-result[#result-1])^2+(points[i+1]-result[#result])^2>epsilon^2 then result[#result+1]=points[i];result[#result+1]=points[i+1] end
    end
    if #result>=4 and (result[1]-result[#result-1])^2+(result[2]-result[#result])^2<=epsilon^2 then result[#result]=nil;result[#result]=nil end
    return #result>=6 and area(result)>epsilon and result or nil
end
local function valid(points)
    assert(#points>=6 and #points%2==0 and area(points)>epsilon,'Floor boundary requires a CCW polygon')
    for i=1,#points,2 do
        local j=i+2;if j>#points then j=1 end;local k=j+2;if k>#points then k=1 end
        assert((points[j]-points[i])*(points[k+1]-points[j+1])-(points[j+1]-points[i+1])*(points[k]-points[j])>=-epsilon,'Floor boundary must be convex')
    end
end
local function clip(points,ax,az,bx,bz,inside)
    local result={};local px,pz=points[#points-1],points[#points]
    local before=((bx-ax)*(pz-az)-(bz-az)*(px-ax))*inside
    for i=1,#points,2 do
        local x,z=points[i],points[i+1];local after=((bx-ax)*(z-az)-(bz-az)*(x-ax))*inside
        if (before>=0)~=(after>=0) then
            local t=before/(before-after);result[#result+1]=px+(x-px)*t;result[#result+1]=pz+(z-pz)*t
        end
        if after>=0 then result[#result+1]=x;result[#result+1]=z end
        px,pz,before=x,z,after
    end
    return clean(result)
end
function Boundary.Intersection(points,outer)
    local result=points
    for i=1,#outer,2 do local j=i+2;if j>#outer then j=1 end
        result=clip(result,outer[i],outer[i+1],outer[j],outer[j+1],1);if not result then return nil end
    end
    return result
end
local function subtract(points,hole)
    local pieces,current={},points
    for i=1,#hole,2 do local j=i+2;if j>#hole then j=1 end
        local outside=clip(current,hole[i],hole[i+1],hole[j],hole[j+1],-1)
        if outside then pieces[#pieces+1]=outside end
        current=clip(current,hole[i],hole[i+1],hole[j],hole[j+1],1);if not current then break end
    end
    return pieces
end
function Boundary.Contains(points,x,z,strict)
    for i=1,#points,2 do local j=i+2;if j>#points then j=1 end
        local side=(points[j]-points[i])*(z-points[i+1])-(points[j+1]-points[i+1])*(x-points[i])
        if strict and side<=epsilon or not strict and side < -epsilon then return false end
    end
    return true
end
function Boundary.Hex(q,r,radius)
    local x,_,z=Hex.ToWorld(q,r,0,radius);local points={}
    for side=0,5 do local a=math.rad(30+side*60);points[#points+1]=x+math.cos(a)*radius;points[#points+1]=z+math.sin(a)*radius end
    return points
end
function Boundary.Register(layout,spec)
    layout.floorBoundaryDefinitions=layout.floorBoundaryDefinitions or {}
    layout.floorBoundaryDefinitions[#layout.floorBoundaryDefinitions+1]=spec
end
function Boundary.Append(layout,spec)
    valid(spec.outer);for _,hole in ipairs(spec.holes or {}) do valid(hole) end
    assert(spec.thickness>0 and math.abs(spec.height)<math.huge and #spec.cells>0,'Invalid floor boundary owner or height')
    local layer=assert(layout.cells[spec.cells[1]]).layer
    local occupied={}
    for _,cell in ipairs(layout.cells) do
        if cell.layer==layer and cell.kind~='void' and cell.kind~='water' and cell.renderGround~=false then occupied[Hex.Key(cell.q,cell.r)]=true end
    end
    local queue,known={},{}
    local owners={};for i,index in ipairs(spec.cells) do owners[i]=index end;table.sort(owners)
    for _,index in ipairs(owners) do
        local cell=assert(layout.cells[index]);assert(cell.layer==layer and cell.kind~='stairs' and math.abs(cell.height-spec.height)<.00001,'Boundary owner must be a matching flat floor')
        local key=Hex.Key(cell.q,cell.r);known[key]=true;queue[#queue+1]={q=cell.q,r=cell.r,owner=index,distance=0}
    end
    local head=1;local candidates={};local rings=spec.rings or 1
    assert(math.tointeger(rings) and rings>=1 and rings<=3,'Floor boundary ring budget must be 1..3')
    while head<=#queue do local current=queue[head];head=head+1
        if current.distance<rings then for d=1,6 do
            local q,r=Hex.Neighbor(current.q,current.r,d);local key=Hex.Key(q,r)
            if q>=0 and r>=0 and q<layout.width and r<layout.height and not known[key] then
                known[key]=true
                if not occupied[key] then
                    local value={q=q,r=r,owner=current.owner,distance=current.distance+1};queue[#queue+1]=value;candidates[#candidates+1]=value
                end
            end
        end end
    end
    table.sort(candidates,function(a,b)return a.r<b.r or a.r==b.r and a.q<b.q end)
    layout.floorBoundaryPatches=layout.floorBoundaryPatches or {}
    for _,candidate in ipairs(candidates) do
        local polygon=Boundary.Intersection(Boundary.Hex(candidate.q,candidate.r,layout.hexRadius),spec.outer)
        if polygon then
            local pieces={polygon}
            for _,hole in ipairs(spec.holes or {}) do
                local nextPieces={}
                for _,piece in ipairs(pieces) do for _,part in ipairs(subtract(piece,hole)) do nextPieces[#nextPieces+1]=part end end
                pieces=nextPieces
            end
            for _,piece in ipairs(pieces) do layout.floorBoundaryPatches[#layout.floorBoundaryPatches+1]={ownerIndex=candidate.owner,points=piece,height=spec.height,thickness=spec.thickness} end
        end
    end
end
function Boundary.Build(layout)
    layout.floorBoundaryPatches={}
    for _,spec in ipairs(layout.floorBoundaryDefinitions or {}) do Boundary.Append(layout,spec) end
    layout.floorBoundaryDefinitions=nil
end
return Boundary
