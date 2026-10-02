-- 矿井定向检查：三层真实坍塌、连续梯道、可见下层设施和四人逐层往返。
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local bytes=file:read('*a');file:close();return bytes
end}})
local Hex=require('Game.Map.HexGrid')
local Squad=require('Game.MapArea.SquadMovement')
local Mine=require('Game.MapArea.MineGenerator')
local generator=require('Game.MapArea.MapAreaGenerator')(config)
generator:Register(6,Mine,'MapAreaMineTable','MapAreaMineThemeTable')
local source={regionId=3,regionConfigId=3,regionType=3,q=0,r=0,height=1,biomeWeights={{regionType=3,weight=1}}}
local seam={{1,6,3,4},{5,6,3,2},{4,5,2,1},{3,4,1,6},{2,3,6,5},{1,2,5,4}}
-- Unity 导入后的实际模型米制包围盒；支撑检查使用旋转后的真实边界。
local bounds={support={2.145,3,.26325},rail={.575,.145,.8660254},cart={.6505,1.02,.9},ore={.75011,1.2,.70206},workstation={1.35,1.81,.82875}}
local function signature(area)
    local values={}
    for _,cell in ipairs(area.cells) do values[#values+1]=table.concat({cell.q,cell.r,cell.layer,cell.kind,tostring(cell.blocked),cell.height},':') end
    for _,prop in ipairs(area.props) do values[#values+1]=table.concat({prop.assetId,prop.q,prop.r,prop.layer,prop.yaw},':') end
    return table.concat(values,'|')
end
local function check(area,walk)
    assert(area.layeredVisibility and area.layerCount==3 and #area.rooms==9 and #area.stairs==4 and #area.openings==2)
    assert(area.cells[area.entryIndex].layer==2 and area.cells[area.goalIndex].layer==0)
    local queue,seen=Mine.Reachable(area);assert(#queue==area.walkableCount and #queue>=1400)
    local counts={};local vertical=0
    for _,cell in ipairs(area.cells) do
        assert(cell.surfaceId and cell.sideSurfaceId,'Mine snapshot cell is missing surface references')
        config:GetTable('MapAreaSurfaceTable'):Get(cell.surfaceId);config:GetTable('MapAreaSurfaceTable'):Get(cell.sideSurfaceId)
        if not cell.blocked then
        assert(seen[cell.index]);counts[cell.layer]=(counts[cell.layer] or 0)+1
        for direction,index in ipairs(cell.neighbors) do
            local other=area.cells[index]
            if area:CanStep(cell,other) then
                assert(area:CanStep(other,cell) and Hex.Distance(cell.q,cell.r,other.q,other.r)==1,'Mine edge is one-way or teleports')
                local edge=seam[direction]
                assert(math.abs(cell.corners[edge[1]]-other.corners[edge[3]])<.00001 and math.abs(cell.corners[edge[2]]-other.corners[edge[4]])<.00001,'Mine stair seam is discontinuous')
                assert(math.abs(cell.height-other.height)<=.834,'Mine stair is too steep')
                if cell.layer~=other.layer then vertical=vertical+1;assert(cell.kind=='stairs' or other.kind=='stairs','Mine layer change bypasses a staircase') end
            end
        end
        for layer=0,cell.layer-1 do local lower=area:Find(cell.q,cell.r,layer)
            if lower and not lower.blocked then
                assert(not area:CanStep(cell,lower),'Mine has a direct vertical jump')
                assert(math.min(table.unpack(cell.corners))-cell.deckThickness-math.max(table.unpack(lower.corners))>=2.2-.00001,'Mine has insufficient headroom')
            end
        end
    elseif cell.kind=='void' then assert(not cell.renderGround and not cell.blocksSight) end end
    assert(vertical==8 and counts[0]>400 and counts[1]>400 and counts[2]>400)
    for _,opening in ipairs(area.openings) do
        for _,point in ipairs(opening.cells) do assert(not area:Find(point.q,point.r,opening.layer),'Mine collapse still has an upper slab') end
        local lip=area.cells[opening.viewpointIndex];local lower=area.cells[opening.lowerTargetIndex]
        assert(not lip.blocked and lower.layer==opening.layer-1 and lower.renderGround)
        assert(area:CanSee(lip,lower),'Mine lower workshop cannot be seen through its collapse')
        local visible={};for _,index in ipairs(area:VisibleFrom(lip.index)) do visible[index]=true end
        assert(visible[lower.index],'Mine lower workshop is absent from exploration visibility')
    end
    local kinds={};local ore=0
    for _,prop in ipairs(area.props) do
        kinds[prop.mineKind]=true;assert(prop.scaleX==1 and prop.scaleY==1 and prop.scaleZ==1)
        assert(prop.cutawayGroup==1 and prop.cutawayLayer==prop.layer)
        local box=bounds[prop.mineKind];local x,_,z=Hex.ToWorld(prop.q,prop.r,0,area.hexRadius);local a=math.rad(prop.yaw)
        for _,dx in ipairs({-box[1],0,box[1]}) do for _,dz in ipairs({-box[3],0,box[3]}) do
            local q,r=Hex.FromWorld(x+dx*math.cos(a)+dz*math.sin(a),z+dz*math.cos(a)-dx*math.sin(a),area.hexRadius)
            local floor=area:Find(q,r,prop.layer)
            assert(floor and floor.renderGround and floor.kind~='wall' and floor.kind~='stairs' and math.abs(floor.height-prop.height)<.00001,'Mine prop bounds extend over unsupported floor: '..prop.mineKind)
            for layer=prop.layer+1,2 do local ceiling=area:Find(q,r,layer)
                if ceiling and ceiling.renderGround then assert(math.min(table.unpack(ceiling.corners))-ceiling.deckThickness>=prop.height+box[2]-.00001,'Mine prop intersects an upper slab') end
            end
        end end
        if prop.mineKind=='ore' then ore=ore+1 end
        for _,index in ipairs(prop.cells) do local cell=area.cells[index]
            assert(cell.layer==prop.layer and cell.renderGround and cell.kind~='stairs','Mine asset floats or covers a staircase')
        end
    end
    assert(kinds.support and kinds.rail and kinds.cart and kinds.ore and kinds.workstation and ore==36)
    if walk then
        local allowed=function(cell)return not cell.blocked end
        local positions=Squad.Deploy(area,area.entryIndex,4,allowed)
        local function travel(target)
            local path=assert(area:FindPath(positions[1],target));local frames,reason=Squad.Plan(area,positions,path,allowed,true);assert(frames,reason)
            for start=1,#frames,4 do
                local before={table.unpack(positions)};local occupied={}
                for member=1,4 do local index=frames[start+member-1]
                    assert(not occupied[index] and allowed(area.cells[index]))
                    assert(index==before[member] or area:CanStep(area.cells[before[member]],area.cells[index]))
                    for other=1,member-1 do assert(index~=before[other] or frames[start+other-1]~=before[member],'Mine squad swaps occupied cells') end
                    positions[member]=index;occupied[index]=true
                end
            end
            assert(positions[1]==target)
        end
        for _,opening in ipairs(area.openings) do travel(opening.viewpointIndex) end
        for _,stair in ipairs(area.stairs) do travel(stair.bottom);travel(stair.top);travel(stair.bottom) end
        for _,room in ipairs(area.rooms) do travel(room.center) end
        travel(area.goalIndex);travel(area.entryIndex)
    end
    print('PASS mine seed '..area.seed..': '..area.walkableCount..' walkable ('..counts[0]..'/'..counts[1]..'/'..counts[2]..'), '..#area.props..' props, 2 real collapse views')
end
local first=generator:Generate(50,20260921,300020,source)
check(first,true)
assert(signature(first)==signature(generator:Generate(50,20260921,300020,source)),'Mine seed is nondeterministic')
local varied=generator:Generate(50,17,300020,source);check(varied,false);assert(signature(first)~=signature(varied),'Mine seed does not change terrain or dressing')
check(generator:Generate(50,400,300020,source),false)
