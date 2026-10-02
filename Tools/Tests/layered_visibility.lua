-- 定向离线检查：三层探索真实楼板遮挡、破洞下视、墙格和连续楼梯；不启动 Unity。
package.path='Lua/?.lua;'..package.path
local Layout=require('Game.MapArea.MapAreaLayout')
local Hex=require('Game.Map.HexGrid')
local function fixture(layered)
    local area=Layout.New({id=1,name='Layered visibility',areaType=1,width=16,height=16,hexRadius=1.5,visionRadius=4,moveStepSeconds=.1},1,{}, {wallHeight=3})
    area.layeredVisibility=layered;area.layerCount=3
    for _,cell in ipairs(area.cells) do
        cell.blocked=false;cell.blocksSight=false;cell.height=0;cell.kind='floor';cell.renderGround=true
    end
    return area
end
local function floor(area,q,r,layer,height)
    local cell=layer==0 and area:Find(q,r) or area:Find(q,r,layer) or area:AddLayerCell(q,r,layer,height)
    cell.height=height;cell.corners={height,height,height,height,height,height}
    cell.deckThickness=.35;cell.renderGround=true;cell.kind='floor';cell.blocksSight=false;cell.blocked=false
    return cell
end
local function deck(area,layer,height)
    for r=0,area.height-1 do for q=0,area.width-1 do floor(area,q,r,layer,height) end end
end
local function gap(area,q,r,layer)
    area.cellsByLayer[Hex.Key(q,r)..':'..layer]=nil
end
local function contains(list,index)
    for _,value in ipairs(list) do if value==index then return true end end
    return false
end

local area=fixture(false)
local origin,target=area:Find(2,5),area:Find(7,5)
assert(area:CanSee(origin,target))
local wall=area:Find(4,5);wall.kind='wall';wall.blocksSight=true
assert(area:CanSee(origin,wall) and not area:CanSee(origin,target),'Legacy wall behavior changed')
local upper=floor(area,2,5,1,4)
assert(not contains(area:VisibleFrom(origin.index),upper.index),'Legacy visibility unexpectedly enumerated new layers')
assert(area:CanSee(origin,upper),'Legacy same-coordinate behavior changed without opt-in')
print('PASS opt-in preserves existing single-layer queries')

area=fixture(true);deck(area,1,4);deck(area,2,8)
origin=area:Find(3,5,2);target=area:Find(5,5,1)
assert(not area:CanSee(origin,target),'Intact upper floor leaked to the lower layer')
assert(not area:CanSee(origin,area:Find(3,5,1)),'Same-coordinate lower floor bypassed its ceiling')
assert(not area:CanSee(area:Find(3,5,1),origin),'Same-coordinate upper floor bypassed its floor')
assert(not area:CanSee(origin,area:Find(4,5,1)),'Adjacent cross-layer target bypassed the origin floor')
gap(area,4,5,2)
assert(area:CanSee(origin,target),'A real upper gap did not expose the lower facility cell')
assert(area:CanSee(target,origin),'A real gap should also permit the reverse eye line')
assert(not area:CanSee(origin,area:Find(3,5,1)),'Opening a nearby gap exposed the origin ceiling')
assert(contains(area:VisibleFrom(origin.index),target.index),'VisibleFrom omitted the exposed lower floor')
assert(not contains(area:VisibleFrom(origin.index),area:Find(3,5,1).index),'VisibleFrom revealed a covered stacked floor')
print('PASS intact/adjacent/stacked slabs block sight and real gaps expose lower cells')

local thin=floor(area,4,5,2,8);thin.deckThickness=0
assert(not area:CanSee(origin,target),'A zero-thickness floor plane allowed sight through its surface')
gap(area,4,5,2)

target=area:Find(7,5)
assert(not area:CanSee(origin,target),'Top gap saw through an intact middle floor')
gap(area,6,5,1)
assert(area:CanSee(origin,target),'Aligned gaps did not expose the third floor')
floor(area,4,5,2,8)
assert(not area:CanSee(origin,target),'Restoring the top slab failed to close the sight line')
print('PASS every intervening level must contain a real opening')

area=fixture(true);deck(area,1,4)
origin=area:Find(2,5,1);target=area:Find(7,5,1)
wall=area:Find(4,5,1);wall.blocksSight=true;wall.kind='wall';wall.wallHeight=3
assert(area:CanSee(origin,wall),'The facing upper wall itself should remain visible')
assert(not area:CanSee(origin,target),'Upper wall was ignored in favor of layer zero')
wall.blocksSight=false
local lowerWall=area:Find(4,5);lowerWall.blocksSight=true;lowerWall.wallHeight=3
assert(area:CanSee(origin,target),'A lower wall blocked a physically higher sight line')
lowerWall.wallHeight=8
assert(not area:CanSee(origin,target),'A tall lower wall failed to block an upper sight line')
print('PASS walls block at their real layer and height; facing walls remain discoverable')

area=fixture(true);origin=area:Find(5,8);target=area:Find(7,4)
assert(area:CanSee(origin,target))
for _,q in ipairs({5,6}) do
    wall=area:Find(q,7);wall.blocksSight=true;wall.wallHeight=3
    assert(not area:CanSee(origin,target),'A ray slipped past one side of a shared hex vertex')
    wall.blocksSight=false
end
print('PASS both sides of shared hex vertices prevent wall-gap peeking')

area=fixture(true)
origin=area:Find(1,5);target=floor(area,7,5,1,4)
for q=2,6 do
    local low=(q-2)*.8;local high=low+.8;local center=(low+high)/2
    local stair=floor(area,q,5,1,center)
    stair.kind='stairs';stair.stairRise=.16
    stair.corners={high,center,low,low,center,high}
    -- 梯道下部的原地面仍为实体地面，但不会变成向上遮挡整层的柱体。
end
assert(area:CanSee(origin,target) and area:CanSee(target,origin),'Continuous stairs blocked travel-direction visibility')
local under=area:Find(5,5);local above=area:Find(5,5,1)
assert(not area:CanSee(under,above),'A stair slab did not block a stacked vertical sight line')
local frozen=Layout.Freeze(area)
assert(frozen:CanSee(frozen.cells[origin.index],frozen.cells[target.index]),'Frozen layout broke layered geometry queries')
print('PASS continuous quantized stairs and frozen layout geometry')

area=fixture(true);deck(area,1,4);deck(area,2,8)
origin=area:Find(7,7,2)
local find=area.Find;local queries=0
function area:Find(q,r,layer)
    queries=queries+1
    assert(Hex.Distance(origin.q,origin.r,q,r)<=self.visionRadius+1,'Visibility scanned beyond its local radius')
    return find(self,q,r,layer)
end
local visible=area:VisibleFrom(origin.index);local seen={}
for _,index in ipairs(visible) do
    local cell=area.cells[index]
    assert(not seen[index] and cell.layer==2 and Hex.Distance(origin.q,origin.r,cell.q,cell.r)<=area.visionRadius)
    seen[index]=true
end
assert(seen[origin.index] and #visible==61 and queries<10000,'Layered visibility was not bounded by its visible disk')
print('PASS bounded local visible disk: '..#visible..' cells, '..queries..' coordinate queries')

-- 单次队伍查询共享几何缓存，但仍必须执行营造投影自己的 CanSee。
area=fixture(true);origin=area:Find(2,5);target=area:Find(6,5);wall=area:Find(4,5)
local Terrain=require('Game.MapArea.ConstructionTerrain')
local reads=0;local records={[wall.index]={SkillId=9}}
local construction={Records=function()reads=reads+1;return records end,
    Record=function()error('Squad reveal must use the command-local construction projection')end,
    definitions={Get=function()return {kind='wall',height=3,blocksSight=true,blocksMovement=true}end}}
local projected=Terrain.Wrap(Layout.Freeze(area),construction,1)
local state={MemberCount=2,GetMemberCellAt=function()return origin.index end,
    Reveal=function(_,indices)visible=indices end}
local System=require('Game.MapArea.MapAreaSystem')
System.RevealSquad({},projected,state)
assert(reads==1 and contains(visible,origin.index) and not contains(visible,target.index),'Shared sight query bypassed construction sight blocking')
records=nil;reads=0
System.RevealSquad({},projected,state)
assert(reads==1 and contains(visible,target.index),'Next reveal retained stale construction or repeatedly queried its state')
print('PASS shared squad geometry cache preserves construction overlays and expires between reveals')
