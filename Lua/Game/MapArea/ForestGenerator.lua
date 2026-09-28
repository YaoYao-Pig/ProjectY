local Hex=require('Game.Map.HexGrid')
local Forest={}
function Forest.Validate(profile)
    assert(profile.gladeCount>=4 and profile.gladeCount<=16 and profile.gladeRadius>=2,'Invalid forest clearings')
end
function Forest.Generate(area,profile,random,config)
    local function sample() return random:Integer(0,999999)/1000000 end
    area.generationVersion=1;area.corridorRadius=1;area.props={}
    local function floor(cell,reserved)
        cell.blocked=false;cell.blocksSight=false;cell.kind='floor';cell.height=0
        cell.surfaceId=profile.groundSurfaceId;cell.sideSurfaceId=profile.trailSurfaceId
        if reserved then cell.reserved=true end
    end
    for _,cell in ipairs(area.cells) do
        cell.height=0;cell.kind='floor';cell.surfaceId=profile.groundSurfaceId;cell.sideSurfaceId=profile.trailSurfaceId
        if cell.q>0 and cell.r>0 and cell.q<area.width-1 and cell.r<area.height-1 then floor(cell) end
    end
    local entry=area:Find(3,math.floor(area.height/2));area.entryIndex=entry.index
    local centers={entry};local columns=math.ceil(math.sqrt(profile.gladeCount))
    local rows=math.ceil(profile.gladeCount/columns)
    for i=1,profile.gladeCount do
        local column=(i-1)%columns;local row=math.floor((i-1)/columns)
        local q=math.floor(8+(area.width-16)*(column+.5)/columns)+random:Integer(-1,1)
        local r=math.floor(5+(area.height-10)*(row+.5)/rows)+random:Integer(-1,1)
        local center=assert(area:Find(q,r));centers[#centers+1]=center
        area.rooms[#area.rooms+1]={id=i,name='林间空地 '..i,tier=1,presetId=0,center=center.index}
    end
    for id,center in ipairs(centers) do
        for dr=-profile.gladeRadius,profile.gladeRadius do for dq=-profile.gladeRadius,profile.gladeRadius do
            local cell=area:Find(center.q+dq,center.r+dr)
            if cell and cell.q>0 and cell.r>0 and cell.q<area.width-1 and cell.r<area.height-1 and Hex.Distance(0,0,dq,dr)<=profile.gladeRadius then
                floor(cell,true);cell.roomId=math.max(0,id-1)
            end
        end end
    end
    -- 连通空地的林间小径至少三格宽，避开森林边界。
    for i=2,#centers do
        local path=assert(area:FindPath(centers[i-1].index,centers[i].index))
        for _,index in ipairs(path) do
            local center=area.cells[index];center.reserved=true;center.surfaceId=profile.trailSurfaceId
            for _,cell in ipairs(area:Neighbors(center)) do cell.reserved=true end
        end
    end
    area.goalIndex=centers[#centers].index
    local function addProp(cell,asset,scale)
        config:GetTable('MapAssetTable'):Get(asset)
        area.props[#area.props+1]={assetId=asset,q=cell.q,r=cell.r,rotation=random:Integer(0,5),scale=scale/area.hexRadius,
            scaleX=scale,scaleY=scale,scaleZ=scale,cells={cell.index}}
    end
    local trees={}
    for _,cell in ipairs(area.cells) do
        if not cell.reserved then
            local boundary=cell.q==0 or cell.r==0 or cell.q==area.width-1 or cell.r==area.height-1
            local density=profile.treeChance*(.55+random:Noise(cell.q,cell.r,7,177)*.9)
            if boundary or sample()<density then
                cell.blocked=true;cell.blocksSight=true;trees[cell.index]=true
            end
        end
    end
    local function reachable()
        local queue,seen,head={entry.index},{[entry.index]=true},1
        while head<=#queue do
            local cell=area.cells[queue[head]];head=head+1
            for _,other in ipairs(area:Neighbors(cell)) do if not seen[other.index] then seen[other.index]=true;queue[#queue+1]=other.index end end
        end
        return seen
    end
    local seen=reachable()
    -- 每个被树丛隔开的空地通过最短轴向步连接至入口，移除相应树木。
    for _,cell in ipairs(area.cells) do if not cell.blocked and not seen[cell.index] then
        local current=cell
        while not seen[current.index] do
            floor(current,true);trees[current.index]=nil
            local best,bestDistance
            for direction=1,6 do
                local q,r=Hex.Neighbor(current.q,current.r,direction);local candidate=area:Find(q,r)
                if candidate and q>0 and r>0 and q<area.width-1 and r<area.height-1 then
                    local distance=Hex.Distance(q,r,entry.q,entry.r)
                    if not bestDistance or distance<bestDistance then best,bestDistance=candidate,distance end
                end
            end
            current=assert(best)
        end
        seen=reachable()
    end end
    for _,cell in ipairs(area.cells) do
        if trees[cell.index] then
            addProp(cell,random:Integer(1,100)<=70 and profile.oakAssetId or profile.pineAssetId,.82+sample()*.25)
        elseif not cell.blocked and not cell.reserved and sample()<profile.fernChance then
            addProp(cell,profile.fernAssetId,.7+sample()*.4)
        end
        if not cell.blocked then area.walkableCount=area.walkableCount+1 end
        cell.floorAccent=config:GetTable('MapAreaSurfaceTable'):Get(cell.surfaceId).baseColor
        cell.floorAccentWeight=1
    end
end
return Forest
