-- 房间收缩为同高节点，通道沿拓扑深度爬升；共享顶点使宽楼梯在转弯/交汇处连续。
local Terrain={}
local cornerOffsets={{1,1},{0,2},{-1,1},{-1,-1},{0,-2},{1,-1}}
function Terrain.Validate(row)
    assert(row.terraceHeight>0 and row.terraceCount>=1 and row.stairRise>0,'Invalid dungeon terrace profile')
    assert(row.stairLength>0 and row.terraceSpacing>row.stairLength,'Dungeon terraces need landings between stairs')
    local steps=row.terraceHeight/row.stairRise
    assert(math.abs(steps-math.floor(steps+.5))<.00001,'Dungeon terrace height must be a whole number of stair risers')
end
function Terrain.Apply(area,row)
    Terrain.Validate(row)
    local nodes,owners={},{}
    for _,cell in ipairs(area.cells) do
        if cell.kind~='wall' then
            local id=cell.roomId>0 and cell.roomId or #area.rooms+cell.index
            local node=nodes[id]
            if not node then node={cells={}};nodes[id]=node end
            node.cells[#node.cells+1]=cell;owners[cell.index]=node
        end
    end
    -- 固定设施占地仍是地板，参与高度求解；房间内部不累计距离，保留平整战斗区。
    local entry=assert(owners[area.entryIndex]);entry.depth=0
    local queue,head={entry},1
    while head<=#queue do
        local node=queue[head];head=head+1
        for _,cell in ipairs(node.cells) do for _,index in ipairs(cell.neighbors) do
            local other=owners[index]
            if other and other.depth==nil then other.depth=node.depth+1;queue[#queue+1]=other end
        end end
    end
    local function height(depth)
        local level=math.floor(depth/row.terraceSpacing)
        local along=depth%row.terraceSpacing
        local slope=math.max(0,(along-row.terraceSpacing+row.stairLength)/row.stairLength)
        return math.min(row.terraceCount,level+slope)*row.terraceHeight
    end
    local wallQueue={}
    for _,cell in ipairs(area.cells) do
        local node=owners[cell.index]
        if node then
            assert(node.depth~=nil,'Dungeon terrain contains disconnected floor')
            cell.height=height(node.depth);cell.surface='ground';wallQueue[#wallQueue+1]=cell
            if cell.roomId>0 then area.rooms[cell.roomId].height=cell.height end
        end
    end
    -- 墙基从最近地面延伸，墙高仍由主题负责；不把山体墙基留在原来的零高度。
    head=1
    while head<=#wallQueue do
        local cell=wallQueue[head];head=head+1
        for _,index in ipairs(cell.neighbors) do
            local other=area.cells[index]
            if other and other.height==nil then other.height=cell.height;wallQueue[#wallQueue+1]=other end
        end
    end
    local vertices={}
    local function vertex(cell,i)
        local offset=cornerOffsets[i]
        local key=(cell.q*2+cell.r+offset[1])..':'..(cell.r*3+offset[2])
        local value=vertices[key]
        if not value then value={sum=0,count=0};vertices[key]=value end
        return value
    end
    for _,cell in ipairs(area.cells) do
        if cell.kind~='wall' then for i=1,6 do
            local value=vertex(cell,i)
            value.sum=value.sum+cell.height;value.count=value.count+1
            if cell.roomId>0 then
                assert(value.roomHeight==nil or math.abs(value.roomHeight-cell.height)<.00001,
                    'Different dungeon terraces cannot share a room corner')
                value.roomHeight=cell.height
            end
        end end
    end
    for _,cell in ipairs(area.cells) do
        cell.corners={}
        local slope=false
        for i=1,6 do
            local value=vertex(cell,i)
            local y=cell.kind=='wall' and cell.height or (value.roomHeight or value.sum/value.count)
            cell.corners[i]=y;slope=slope or math.abs(y-cell.height)>.00001
        end
        cell.stairRise=cell.kind~='wall' and slope and row.stairRise or 0
    end
end
return Terrain
