-- 最小算法检查：真实配表、六种 Region、墙体遮挡及共享战斗坐标；不启动 Unity。
package.path='Lua/?.lua;'..package.path
local Config=require('Config.ConfigSystem')
local config=Config()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local Generator=require('Game.MapArea.MapAreaGenerator')
local generator=Generator(config)
generator:Register(config:GetEnum('MapArea','E_MapAreaType').Dungeon,require('Game.MapArea.DungeonGenerator'),'MapAreaDungeonTable')
local function source(kind)
    return {regionId=7,regionConfigId=kind,regionType=kind,q=5,r=2,height=1,biomeWeights={{regionType=kind,weight=1}}}
end
local function signature(area)
    local values={}
    for i,cell in ipairs(area.cells) do values[i]=cell.blocked and '#' or '.' end
    return table.concat(values)
end
local count=0
local function test(name,run) run();count=count+1;print('PASS '..name) end
local area
test('96 x 96 dungeon is deterministic, immutable and point-specific',function()
    area=generator:Generate(1,20260921,4,source(1))
    assert(#area.cells==9216 and #area.rooms==10)
    assert(signature(area)==signature(generator:Generate(1,20260921,4,source(1))))
    assert(signature(area)~=signature(generator:Generate(1,20260921,5,source(1))))
    assert(not pcall(function() area.cells[1].blocked=false end))
    assert(not generator:CanGenerate(2))
end)
test('all six configured Region themes produce connected terrain and change geometry',function()
    local signatures={}
    for kind=1,6 do
        local current=kind==1 and area or generator:Generate(1,20260921,4,source(kind))
        local visited,queue,head={[current.entryIndex]=true},{current.entryIndex},1
        while head<=#queue do
            local cell=current.cells[queue[head]];head=head+1
            for _,neighbor in ipairs(current:Neighbors(cell)) do
                if not visited[neighbor.index] then visited[neighbor.index]=true;queue[#queue+1]=neighbor.index end
            end
        end
        assert(#queue==current.walkableCount and #queue>1000 and #queue<7000)
        assert(visited[current.goalIndex] and current.goalDistance>60)
        signatures[signature(current)]=true
        print(string.format('  Region %d: %d rooms, %d floor, deepest path %d',kind,#current.rooms,#queue,current.goalDistance))
    end
    local unique=0;for _ in pairs(signatures) do unique=unique+1 end;assert(unique==6)
end)
test('pathfinding stays on connected floor and respects exploration limits',function()
    local path=assert(area:FindPath(area.entryIndex,area.goalIndex))
    assert(#path==area.goalDistance)
    for _,index in ipairs(path) do assert(not area.cells[index].blocked) end
    assert(area:FindPath(area.entryIndex,1)==nil)
    assert(area:FindPath(area.entryIndex,area.goalIndex,function(cell) return cell.index==area.entryIndex end)==nil)
    local visible=area:VisibleFrom(area.entryIndex);assert(#visible>10 and #visible<300)
end)
test('walls hide cells behind them while the facing wall remains visible',function()
    local Layout=require('Game.MapArea.MapAreaLayout')
    local fixture=Layout.New({id=9,name='遮挡夹具',areaType=1,width=8,height=8,hexRadius=1,visionRadius=6,moveStepSeconds=.1},1,{}, {})
    for _,cell in ipairs(fixture.cells) do cell.blocked=cell.q==3;cell.blocksSight=cell.blocked end
    local origin=fixture:Find(1,3)
    assert(fixture:CanSee(origin,fixture:Find(3,3)))
    assert(not fixture:CanSee(origin,fixture:Find(4,3)))
    assert(fixture:FindPath(origin.index,fixture:Find(5,3).index)==nil)
end)
test('battle windows share original cells and axial coordinates without regenerating terrain',function()
    local Board=require('Game.Battle.BattleBoard');local entry=area.cells[area.entryIndex]
    local window=Board.FromArea(area,entry.q,entry.r,6)
    assert(window:Find(entry.q,entry.r)==entry)
    for _,cell in ipairs(window.cells) do assert(cell==area:Find(cell.q,cell.r)) end
    local _,distance=window:Search(entry.q,entry.r,{},3)
    for cell in pairs(distance) do assert(not cell.blocked) end
end)
test('mixed tiers keep five-cell passages and clear combat pads after furnishing',function()
    local G=require('Game.MapArea.DungeonGeometry')
    local tiers={0,0,0}
    for _,room in ipairs(area.rooms) do
        tiers[room.tier]=tiers[room.tier]+1
        G.Disk(room.q,room.r,room.combatRadius,function(q,r)
            local cell=assert(area:Find(q,r));assert(not cell.blocked and cell.reserved)
        end)
    end
    assert(tiers[1]==2 and tiers[2]==5 and tiers[3]==3)
    assert(#area.connections>=9 and #area.connections<=11)
    for _,connection in ipairs(area.connections) do
        assert(connection.radius>=2)
        for _,index in ipairs(connection.path) do
            local center=area.cells[index]
            G.Disk(center.q,center.r,connection.radius,function(q,r)
                local cell=assert(area:Find(q,r));assert(not cell.blocked and cell.reserved,'Narrow or furnished passage')
            end)
        end
    end
    assert(#area.props>=29)
    for _,prop in ipairs(area.props) do
        for _,index in ipairs(prop.cells) do
            local cell=area.cells[index];assert(cell.blocked and cell.obstacleId==prop.id and cell.kind~='wall')
        end
    end
end)
test('authored rooms keep their exact floor masks and every fixed placement after rotation',function()
    local G=require('Game.MapArea.DungeonGeometry')
    local templates=config:GetTable('MapAreaRoomPresetTable')
    local placements=config:GetTable('MapAreaRoomPlacementTable'):All()
    for _,room in ipairs(area.rooms) do
        if room.tier==3 then
            local template=templates:Get(room.presetId)
            G.Disk(room.q,room.r,room.radius,function(q,r,dq,dr)
                local lq,lr=G.Rotate(dq,dr,6-room.rotation)
                local floor=template.tiles[lr+room.radius+1]:sub(lq+room.radius+1,lq+room.radius+1)=='.'
                assert((area:Find(q,r).kind~='wall')==floor,'Authored mask was damaged by corridor carving')
            end)
            for _,placement in ipairs(placements) do
                if placement.presetId==room.presetId then
                    local q,r=G.Rotate(placement.q,placement.r,room.rotation)
                    local found=false
                    for _,prop in ipairs(area.props) do
                        if prop.roomId==room.id and prop.configId==placement.propId and prop.q==room.q+q and prop.r==room.r+r then found=true;break end
                    end
                    assert(found,'Missing authored prop')
                end
            end
        end
    end
end)
test('room packing and broad connections remain valid for other point seeds',function()
    for _,seed in ipairs({1,1729,20260923}) do
        for _,kind in ipairs({2,3}) do
            local nextArea=generator:Generate(1,seed,7,source(kind))
            assert(#nextArea.rooms==10 and #nextArea.connections>=9 and nextArea.walkableCount>2000)
        end
    end
end)
test('district roles, variable passage sections and multi-cell facilities remain coherent',function()
    local G=require('Game.MapArea.DungeonGeometry')
    local profile=config:GetTable('MapAreaDungeonTable'):Get(1)
    assert(area.generationVersion==3)
    assert(area.cells[area.entryIndex].roomId~=area.cells[area.goalIndex].roomId)
    assert(area.rooms[area.cells[area.entryIndex].roomId].presetId==profile.entryPresetId)
    assert(area.rooms[area.cells[area.goalIndex].roomId].presetId==profile.goalPresetId)
    for _,room in ipairs(area.rooms) do assert(area.districts[room.districtId]) end
    local widths,extra={},0
    for _,connection in ipairs(area.connections) do
        if connection.extra then extra=extra+1 end
        assert(#connection.radii==#connection.path)
        for i,index in ipairs(connection.path) do
            local radius=connection.radii[i];widths[radius]=true
            assert(radius>=2 and radius<=profile.corridorMaxRadius)
            if i>1 then assert(math.abs(radius-connection.radii[i-1])<=1) end
            local center=area.cells[index]
            G.Disk(center.q,center.r,radius,function(q,r) assert(not area:Find(q,r).blocked) end)
        end
    end
    assert(widths[2] and widths[3] and widths[4] and extra>=1,'Fixture needs 5/7/9-cell sections and a loop')
    local large=0;local types={}
    for _,prop in ipairs(area.props) do
        local definition=config:GetTable('MapAreaPropTable'):Get(prop.configId)
        assert(#prop.cells==#definition.footprintQ)
        for i,dq in ipairs(definition.footprintQ) do
            local q,r=G.Rotate(dq,definition.footprintR[i],prop.rotation)
            assert(area.cells[prop.cells[i]]==area:Find(prop.q+q,prop.r+r),'Prop rotation and occupancy disagree')
        end
        if #prop.cells>=13 then large=large+1;types[prop.configId]=true end
    end
    local varieties=0;for _ in pairs(types) do varieties=varieties+1 end
    assert(large>=8 and varieties>=6,'Fixture needs substantial large facility variation')
    print(string.format('  %d large facilities, %d styles, %d loops; passage widths 5/7/9',large,varieties,extra))
end)
config:OnShutdown()
print('MapArea core: '..count..' checks passed')
