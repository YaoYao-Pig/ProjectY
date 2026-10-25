-- Targeted outdoor geometry/navigation test; uses actual exported configuration by default.
package.path='Lua/?.lua;'..package.path
local config=terrainSourceConfig
if not config then
    config=require('Config.ConfigSystem')()
    config:OnInit({services={ReadConfig=function(_,name)
        local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
        local bytes=file:read('*a');file:close();return bytes
    end}})
end
local Generator=require('Game.MapArea.MapAreaGenerator')
local Squad=require('Game.MapArea.SquadMovement')
local entries={{70,9,'HighMountain'},{71,10,'Canyon'},{72,11,'GiantTree'}}
local generator=Generator(config)
for _,entry in ipairs(entries) do generator:Register(entry[2],require('Game.MapArea.'..entry[3]..'Generator'),
    'MapArea'..entry[3]..'Table','MapArea'..entry[3]..'ThemeTable') end
local offsets={{1,1},{0,2},{-1,1},{-1,-1},{0,-2},{1,-1}}
local function signature(area)
    local values={}
    for _,cell in ipairs(area.cells) do values[#values+1]=table.concat({cell.height,cell.walkMask,cell.surfaceId},':') end
    for _,prop in ipairs(area.props) do values[#values+1]=table.concat({prop.assetId,prop.q,prop.r,prop.yaw},':') end
    return table.concat(values,'|')
end
local function generate(entry,seed,region)
    return generator:Generate(entry[1],seed,1700+entry[1],{regionType=region,biomeWeights={{regionType=region,weight=.8},{regionType=1,weight=.2}}})
end
local checked=0
for _,entry in ipairs(entries) do
    local row=config:GetTable('MapArea'..entry[3]..'Table'):Get(1)
    local previous
    for _,seed in ipairs({20261025,7,91247}) do
        local area=generate(entry,seed,entry[1]==71 and 13 or 12)
        local queue,seen,head={area.entryIndex},{[area.entryIndex]=true},1
        while head<=#queue do
            local cell=area.cells[queue[head]];head=head+1
            for _,other in ipairs(area:Neighbors(cell)) do
                assert(area:CanStep(other,cell),'Natural navigation edges must be reciprocal')
                assert(math.abs(other.height-cell.height)<=row.maxWalkRise+.00001,'Navigation crosses a cliff')
                if not seen[other.index] then seen[other.index]=true;queue[#queue+1]=other.index end
            end
        end
        assert(#queue==area.walkableCount and #queue>=row.minWalkableCells and seen[area.goalIndex])
        local vertices={};local low,high=math.huge,-math.huge;local water=0
        for _,cell in ipairs(area.cells) do
            assert(cell.kind~='void' and cell.renderGround and #cell.corners==6,'Outdoor relief cannot be empty space')
            assert(cell.blocked or seen[cell.index],'Every open cell must belong to the entry component')
            assert(cell.height==cell.height and math.abs(cell.height)<1000,'Invalid terrain height')
            low=math.min(low,cell.height);high=math.max(high,cell.height)
            if cell.surfaceId==40 then
                water=water+1;assert(cell.blocked,'Water basin/stream must not be walkable')
                if entry[1]==70 then for _,height in ipairs(cell.corners) do
                    assert(math.abs(height-cell.height)<.00001,'Alpine lake water must form a flat basin')
                end end
            end
            for i,o in ipairs(offsets) do
                if entry[1]==70 then
                    assert(cell.corners[i]==cell.height,'High mountain must keep flat hex tops')
                else
                    local key=(cell.q*2+cell.r+o[1])..':'..(cell.r*3+o[2])
                    assert(not vertices[key] or math.abs(vertices[key]-cell.corners[i])<.00001,'Shared terrain corner has a crack')
                    vertices[key]=cell.corners[i]
                end
            end
        end
        assert(high-low>=(entry[1]==72 and 6 or 45),'Terrain has insufficient relief')
        local deployment=Squad.Deploy(area,area.entryIndex,4)
        local occupied={}
        for _,index in ipairs(deployment) do assert(seen[index] and not occupied[index]);occupied[index]=true end
        for _,room in ipairs(area.rooms) do assert(seen[room.center],'Scenic destination is inaccessible') end
        for _,prop in ipairs(area.props) do for _,index in ipairs(prop.cells) do
            assert(area.cells[index].blocked,'Natural scenery footprint must not overlap navigation')
        end end
        if entry[1]==70 then
            assert(area.cells[area.goalIndex].height-area.cells[area.entryIndex].height>=row.summitHeight-1 and water>10)
            assert(area.goalDistance>area.height,'Mountain must use a winding ascent')
        elseif entry[1]==71 then
            assert(area.ropeLandingIndex==area.entryIndex and area.cells[area.entryIndex].height<-20 and water>15)
            assert(area.cells[area.rooms[2].center].height-area.cells[area.entryIndex].height>=row.shelfHeight-1,'Canyon shelf did not climb above valley')
        else
            local roots,trunks,trees=0,0,0
            for _,prop in ipairs(area.props) do
                if prop.assetId==row.rootAssetId then roots=roots+1;assert(#prop.cells>1)
                elseif prop.assetId==row.trunkAssetId then trunks=trunks+1;assert(prop.scaleX==1 and prop.scaleY==1 and prop.scaleZ==1)
                elseif prop.assetId==row.treeAssetId then trees=trees+1;assert(prop.scaleY<=1.1)
                else error('Tree root scene unexpectedly contains an entire giant-tree model') end
                for _,index in ipairs(prop.cells) do assert(area.cells[index].blocked,'Tree geometry must not overlap a walking cell') end
            end
            assert(roots==6 and trunks==1 and trees==8,'Giant-tree local scale-reference set is incomplete')
        end
        local hash=signature(area)
        assert(hash==signature(generate(entry,seed,entry[1]==71 and 13 or 12)),'Equal seed must reproduce terrain and props')
        if previous then assert(hash~=previous,'Different seeds must vary the terrain') end
        previous=hash
        assert(not pcall(function()area.cells[area.entryIndex].height=999 end),'Natural terrain must be immutable')
        checked=checked+1
        print(string.format('PASS %s seed %d: %d reachable cells, %.1fm relief, route %d cells',entry[3],seed,area.walkableCount,high-low,area.goalDistance))
    end
end
print(string.format('PASS natural MapArea: %d cases, graded connectivity, shared corners, 4-member deployment, water and local giant-tree footprint',checked))
if config.OnShutdown then config:OnShutdown() end
