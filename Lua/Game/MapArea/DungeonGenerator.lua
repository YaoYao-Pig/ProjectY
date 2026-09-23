-- 混合三个生成等级：房间选择/排布、宽通道连接、内部陈设分别负责一个阶段。
local Hex=require('Game.Map.HexGrid')
local Pathfinder=require('Game.Map.MapPathfinder')
local G=require('Game.MapArea.DungeonGeometry')
local Rooms=require('Game.MapArea.DungeonRooms')
local Props=require('Game.MapArea.DungeonProps')
local Passages=require('Game.MapArea.DungeonPassages')
local Dungeon={}
function Dungeon.Validate(row)
    assert(row.basicRadiusMin<=row.basicRadiusMax and row.roomRadiusMin<=row.roomRadiusMax,'Invalid dungeon room radius range')
    assert(row.corridorRadius>=2 and row.combatRadius>=row.corridorRadius,'Dungeon must retain combat and passage clearance')
    assert(#row.styleIds>0 and #row.presetIds>0 and row.basicRoomCount>0,'Mixed dungeon needs all three room tiers')
    assert(row.corridorMaxRadius>=row.corridorRadius and #row.districtIds>0,'Invalid district or passage profile')
end
function Dungeon.Generate(area,row,random,config)
    Dungeon.Validate(row)
    area.generationVersion=3;area.props={};area.connections={};area.corridorRadius=row.corridorRadius
    Rooms.Select(area,row,random,config);Rooms.Paint(area,row,random);Props.Fixed(area,config)
    local graph=Pathfinder(area)
    local links,parent={},{}
    for i=1,#area.rooms do parent[i]=i end
    local function root(id) while parent[id]~=id do parent[id]=parent[parent[id]];id=parent[id] end;return id end
    for a=1,#area.rooms do for b=a+1,#area.rooms do
        local aa,bb=area.rooms[a],area.rooms[b]
        links[#links+1]={a=a,b=b,distance=Hex.Distance(aa.q,aa.r,bb.q,bb.r),sameDistrict=aa.districtId==bb.districtId}
    end end
    table.sort(links,function(a,b)
        if a.sameDistrict~=b.sameDistrict then return a.sameDistrict end
        return a.distance<b.distance or a.distance==b.distance and (a.a<b.a or a.a==b.a and a.b<b.b)
    end)
    -- 预计算半径净空，路径搜索与真正挖掘使用同一笔刷，拐弯和房门也保持宽度。
    local brush,passable={},{}
    for _,cell in ipairs(area.cells) do
        local cells,valid,owners={},true,{}
        G.Disk(cell.q,cell.r,row.corridorRadius,function(q,r)
            local other=area:Find(q,r)
            if not G.Inside(area,other,row.borderWidth) or other.obstacleId>0 or
                other.roomOwner>0 and area.rooms[other.roomOwner].tier==3 and other.kind=='wall' then valid=false
            else cells[#cells+1]=other;if other.roomOwner>0 then owners[other.roomOwner]=true end end
        end)
        if valid then brush[cell.index]=cells;passable[cell.index]=owners end
    end
    local function connect(link,extra)
        local start,finish=area.rooms[link.a],area.rooms[link.b]
        local path=graph:FindPath(area.cells[start.center],area.cells[finish.center],function(_,cell)
            local owners=passable[cell.index];if not owners then return nil end
            for id in pairs(owners) do if id~=start.id and id~=finish.id then return nil end end
            if cell.kind=='corridor' then return extra and 5 or 1.2 end
            return (cell.blocked and 1.5 or 1)+random:Noise(cell.q,cell.r,8,1871)*row.corridorWinding*area.theme.windingScale
        end)
        if not path then return false end -- 本条房间边不可布宽通道，有限图扫描继续尝试其他连接。
        local connection={a=link.a,b=link.b,extra=extra==true,radius=row.corridorRadius,path={}}
        Passages.Carve(area,row,random,path,brush,connection)
        area.connections[#area.connections+1]=connection;link.used=true;return true
    end
    for _,link in ipairs(links) do
        if root(link.a)~=root(link.b) and connect(link,false) then parent[root(link.b)]=root(link.a) end
    end
    for i=2,#area.rooms do assert(root(i)==root(1),'Cannot connect configured rooms with required passage width') end
    local loops=0
    local function hops(a,b)
        local queue,dist,head={a},{[a]=0},1
        while head<=#queue do
            local id=queue[head];head=head+1
            for _,edge in ipairs(area.connections) do
                local other=edge.a==id and edge.b or edge.b==id and edge.a
                if other and not dist[other] then
                    dist[other]=dist[id]+1;if other==b then return dist[other] end
                    queue[#queue+1]=other
                end
            end
        end
        error('Disconnected room graph')
    end
    -- 回路优先减少较长的折返，而不是在相邻两个房间旁再挖一条重复走廊。
    for _,link in ipairs(links) do link.detour=hops(link.a,link.b) end
    table.sort(links,function(a,b)
        local sa,sb=a.detour/a.distance,b.detour/b.distance
        return sa>sb or sa==sb and (a.a<b.a or a.a==b.a and a.b<b.b)
    end)
    for _,link in ipairs(links) do
        if loops>=row.loopConnections then break end
        if not link.used and hops(link.a,link.b)>=row.loopMinHops and connect(link,true) then loops=loops+1 end
    end
    local entry,goal
    for _,room in ipairs(area.rooms) do
        if room.presetId==row.entryPresetId then entry=room end
        if room.presetId==row.goalPresetId then goal=room end
    end
    assert(entry and goal and entry~=goal,'Dungeon needs distinct configured entrance and goal halls')
    area.entryIndex=entry.center;area.cells[entry.center].kind='entry'
    Props.Scatter(area,random,config)
    local queue,distance=G.Reachable(area,area.entryIndex)
    assert(#queue==area.walkableCount,'Dungeon props and rooms must preserve a single connected floor')
    -- 深处目标选在主要房间中央，避免把终点藏在狭窄边角里。
    area.goalIndex=goal.center
    for _,room in ipairs(area.rooms) do
        room.preset=nil;room.style=nil
    end
    area.goalDistance=distance[area.goalIndex];area.cells[area.goalIndex].kind='landmark'
    return area
end
return Dungeon
