-- 地牢台地的导航、共享台阶顶点及陈设支撑检查；使用真实配置，不启动 Unity。
package.path='Lua/?.lua;'..package.path
local Config=require('Config.ConfigSystem')
local config=Config()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local Generator=require('Game.MapArea.MapAreaGenerator')
local Layout=require('Game.MapArea.MapAreaLayout')
local G=require('Game.MapArea.DungeonGeometry')
local generator=Generator(config)
generator:Register(1,require('Game.MapArea.DungeonGenerator'),'MapAreaDungeonTable')
local row=config:GetTable('MapAreaDungeonTable'):Get(1)
local offsets={{1,1},{0,2},{-1,1},{-1,-1},{0,-2},{1,-1}}
local function near(a,b) return math.abs(a-b)<.00001 end
local function source(kind)
    return {regionId=7,regionConfigId=kind,regionType=kind,q=5,r=2,height=1,biomeWeights={{regionType=kind,weight=1}}}
end
local function check(area)
    local seen,min,max,stairs={},math.huge,-math.huge,0
    for _,cell in ipairs(area.cells) do
        assert(cell.height>=0 and cell.height<=row.terraceHeight*row.terraceCount+.00001)
        assert(#cell.corners==6)
        if cell.kind~='wall' then
            min=math.min(min,cell.height);max=math.max(max,cell.height)
            if cell.stairRise>0 then assert(cell.roomId==0);stairs=stairs+1 end
            for i,offset in ipairs(offsets) do
                local key=(cell.q*2+cell.r+offset[1])..':'..(cell.r*3+offset[2])
                assert(seen[key]==nil or near(seen[key],cell.corners[i]),'Floor seam is not continuous')
                seen[key]=cell.corners[i]
            end
            for _,other in ipairs(not cell.blocked and area:Neighbors(cell) or {}) do
                assert(math.abs(other.height-cell.height)<=row.terraceHeight/row.stairLength+.00001,'Stairs exceed configured gradient')
                assert(area:CanStep(other,cell),'Stairs must be traversable in both directions')
            end
        else
            for _,y in ipairs(cell.corners) do assert(near(y,cell.height),'Wall must keep its solid flat top') end
        end
        if cell.roomId>0 then
            assert(near(cell.height,area.rooms[cell.roomId].height))
            for _,y in ipairs(cell.corners) do assert(near(y,cell.height),'Room must remain a flat combat platform') end
        end
    end
    assert(max-min>=row.terraceHeight and stairs>0,'Dungeon must visibly climb a terrace')
    for _,room in ipairs(area.rooms) do
        G.Disk(room.q,room.r,room.combatRadius,function(q,r)
            local cell=assert(area:Find(q,r));assert(not cell.blocked and near(cell.height,room.height))
        end)
    end
    for _,prop in ipairs(area.props) do
        local height=area.cells[prop.cellIndex].height
        for _,index in ipairs(prop.cells) do
            local cell=area.cells[index];assert(near(cell.height,height))
            for _,y in ipairs(cell.corners) do assert(near(y,height),'Furniture footprint is unsupported') end
        end
    end
    for _,connection in ipairs(area.connections) do for i,index in ipairs(connection.path) do
        local center=area.cells[index]
        G.Disk(center.q,center.r,connection.radii[i],function(q,r)
            local cell=assert(area:Find(q,r));assert(not cell.blocked,'Stairs narrowed a passage')
        end)
    end end
    local queue=G.Reachable(area,area.entryIndex);assert(#queue==area.walkableCount)
    assert(area:FindPath(area.entryIndex,area.goalIndex) and area:FindPath(area.goalIndex,area.entryIndex))
    print(string.format('PASS Region %d seed %d: %.2fm relief, %d stair cells, %d reachable cells',
        area.source.regionType,area.seed,max-min,stairs,#queue))
end
for kind=1,6 do check(generator:Generate(1,20260921,4,source(kind))) end
for _,seed in ipairs({1,1729}) do check(generator:Generate(1,seed,7,source(2))) end
local a=generator:Generate(1,1729,7,source(2));local b=generator:Generate(1,1729,7,source(2))
for i,cell in ipairs(a.cells) do
    assert(cell.height==b.cells[i].height)
    for k,y in ipairs(cell.corners) do assert(y==b.cells[i].corners[k]) end
end
print('PASS deterministic terrain heights and shared stair corners')
local fixture=Layout.New({id=9,name='台地视线',areaType=1,width=8,height=8,hexRadius=1.5,visionRadius=6,moveStepSeconds=.1},1,{}, {})
for _,cell in ipairs(fixture.cells) do cell.blocked=false;cell.blocksSight=false;cell.height=0 end
local origin,target=fixture:Find(1,3),fixture:Find(5,3)
assert(fixture:CanSee(origin,target))
fixture:Find(3,3).height=2.7
assert(not fixture:CanSee(origin,target),'Elevated ground must block lower line of sight')
origin.height=5.4;target.height=5.4
assert(fixture:CanSee(origin,target),'A low terrace must not hide targets seen from above')
print('PASS terrain height occludes sight at eye level')
config:OnShutdown()
