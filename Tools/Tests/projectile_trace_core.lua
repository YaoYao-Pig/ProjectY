-- Pure Lua geometry/identity checks; no generated config, Editor or probability rolls.
package.path='Lua/?.lua;'..package.path
local Hex=require('Game.Map.HexGrid')
local Layout=require('Game.MapArea.MapAreaLayout')
local Board=require('Game.Battle.BattleBoard')
local Trace=require('Game.Battle.SkillTrajectory')
local count=0
local function test(name,run)run();count=count+1;print('PASS '..name)end
local function flat()
    local area=Layout.New({id=999,name='trace',areaType=1,width=14,height=14,hexRadius=1,visionRadius=12,moveStepSeconds=.1},1,{}, {wallHeight=3})
    for _,cell in ipairs(area.cells)do cell.height=0;cell.blocked=false;cell.blocksSight=false;cell.kind='floor' end
    return area
end
local function board(area)return Board.FromArea(area,6,6,12)end
local function actor(id,q,r)
    return {Id=id,Q=q,R=r,HP=20,AnimalOwnerId=0}
end
local function shot(area,a,b,mode,occupied,guided)
    return Trace.Trace(board(area),a,b,mode or 'direct',occupied or {},guided)
end

test('six-direction direct/lobbed interception preserves distance exemptions and legacy sight',function()
    for direction=1,6 do
        local area=flat();local origin=area:Find(6,6)
        local q,r=Hex.Neighbor(6,6,direction);local near=area:Find(q,r)
        q,r=Hex.Neighbor(q,r,direction);local far=area:Find(q,r)
        q,r=Hex.Neighbor(q,r,direction);local target=area:Find(q,r)
        near.blocksSight=true;far.blocksSight=true
        local direct=shot(area,origin,target,'direct');local lobbed=shot(area,origin,target,'lobbed')
        assert(direct.reachable and #direct.blockers==1 and direct.blockers[1].cell==far)
        assert(lobbed.reachable and #lobbed.blockers==1 and lobbed.blockers[1].cell==near)
        assert(Trace.CanReach(board(area),origin,target,'direct',{}),'Identified cover must not forbid firing')
        assert(not shot(area,origin,target,'sight').reachable and not area:CanSee(origin,target))
        for _,mode in ipairs({'direct','lobbed','sight'})do
            local guided=shot(area,origin,target,mode,{},true);assert(guided.reachable and #guided.blockers==0)
        end
        local reversed=shot(area,target,origin,'direct');assert(#reversed.blockers==1 and reversed.blockers[1].cell==near)
        local adjacent=shot(area,origin,near);assert(adjacent.reachable and #adjacent.blockers==0)
    end
end)

test('dual-epsilon paths are deterministic, off-ray cells ignored and physical identities deduplicated',function()
    local area=flat();local origin,target=area:Find(4,4),area:Find(5,5)
    area:Find(3,4).blocksSight=true
    assert(#shot(area,origin,target,'lobbed').blockers==0)
    for _,cell in ipairs({area:Find(5,4),area:Find(4,5)})do cell.blocksSight=true end
    local result=shot(area,origin,target,'lobbed');assert(result.reachable and #result.blockers==2)
    local again=shot(area,origin,target,'lobbed');for i,row in ipairs(result.blockers)do assert(row.key==again.blockers[i].key)end
    area:Find(5,4).blocksSight=false;area:Find(4,5).blocksSight=false
    local animal=actor(31,5,4)
    local occupied={['5:4']=animal,['4:5']=animal}
    result=shot(area,origin,target,'lobbed',occupied);assert(#result.blockers==1 and result.blockers[1].actor==animal)
    occupied['5:5']=animal
    assert(#shot(area,origin,target,'lobbed',occupied).blockers==0,'Any target footprint cell excludes the whole physical actor')
    occupied['5:5']=nil;animal.HP=0;assert(#shot(area,origin,target,'lobbed',occupied).blockers==0)
    animal.HP=20;animal.AnimalOwnerId=1;assert(#shot(area,origin,target,'lobbed',occupied).blockers==0)
end)

test('actor blockers follow near-to-far order, preserve descriptors and exclude endpoint actors',function()
    local area=flat();local origin,target=area:Find(2,5),area:Find(8,5)
    local a,b=actor(20,6,5),actor(90,4,5)
    local occupied={['6:5']=a,['4:5']={kind='actor',key='actor:90',actor=b},['5:5']=b}
    local result=shot(area,origin,target,'direct',occupied)
    assert(#result.blockers==2 and result.blockers[1].actor==b and result.blockers[2].actor==a)
    assert(result.blockers[1].cell==area:Find(4,5),'Blocker keeps the nearest actual projected footprint cell')
    b.Q=2;b.R=5;assert(#shot(area,origin,target,'direct',occupied).blockers==1)
    b.Q=8;assert(#shot(area,origin,target,'direct',occupied).blockers==1)
end)

test('terrain heights, layered ray geometry and endpoint floors use existing CanTrace truth',function()
    local area=flat();local origin,target=area:Find(2,4),area:Find(6,4)
    local middle=area:Find(4,4);middle.height=1
    assert(#shot(area,origin,target).blockers==0)
    middle.height=3;local result=shot(area,origin,target);assert(#result.blockers==1 and result.blockers[1].kind=='terrain')
    middle.height=0;area.layeredVisibility=true;area.layerCount=2;middle.blocksSight=true
    result=shot(area,origin,target);assert(result.reachable and #result.blockers==1 and result.blockers[1].cell==middle)
    local upper=area:AddLayerCell(2,4,1,3);upper.deckThickness=.2
    assert(not shot(area,origin,upper,'direct',{},true).reachable,'Guidance cannot open cross-layer targeting')
    assert(not Trace.Trace(board(area),origin,{q=40,r=40,layer=0},'direct',{},true).reachable)
    assert(not Trace.Trace(board(area),nil,target,'direct',{},true).reachable)
    upper.height=1.7;upper.deckThickness=.2
    assert(not shot(area,origin,target,'direct',{},true).reachable,'Guidance must not tunnel through an endpoint floor')
end)

test('container and construction blockers carry owners, honor their geometry and react to destruction',function()
    local base=flat();local records={}
    local wall=base:Find(4,4);records[wall.index]={Id=11,SkillId=1,HP=20,MaxHP=20}
    local defs={[1]={height=2,kind='wall',blocksSight=true,blocksMovement=true},[2]={height=.4,kind='fence',blocksSight=false,blocksMovement=true},[3]={height=.4,kind='wall',blocksSight=true,blocksMovement=true}}
    local construction={definitions={Get=function(_,id)return assert(defs[id])end},skills={Get=function()return {name='木墙'}end}}
    function construction:Record(_,index)return records[index]end
    function construction:Records()return records end
    local built=require('Game.MapArea.ConstructionTerrain').Wrap(base,construction,1)
    local container={Id=7,TableId=1,Name='双格箱'}
    local parts={base:Find(5,4).index,base:Find(6,4).index}
    local physical={Configured=true,Destroyed=false,CellCount=2,GetCellAt=function(_,i)return parts[i+1]end}
    local loot={Physical=function()return physical end,rules={containers={Get=function()return {blocksSight=true,blocksMovement=true}end}}}
    local area=require('Game.Loot.ContainerTerrain').Wrap(built,loot,{LootCount=1,GetLootAt=function()return container end})
    local origin,target=area:Find(2,4),area:Find(8,4)
    local result=shot(area,origin,target)
    assert(result.reachable and #result.blockers==2)
    assert(result.blockers[1].kind=='construction' and result.blockers[1].record==records[wall.index] and result.blockers[1].cell==area.cells[wall.index])
    assert(result.blockers[2].kind=='container' and result.blockers[2].container==container and result.blockers[2].physical==physical)
    assert(result.blockers[2].cell==area.cells[parts[1]],'A multi-cell container has one nearest interception')
    result=shot(area,origin,area.cells[parts[2]])
    assert(#result.blockers==1 and result.blockers[1].kind=='construction','Target container footprint must not intercept itself')
    physical.Destroyed=true;assert(#shot(area,origin,target).blockers==1)
    records[wall.index].SkillId=2;assert(#shot(area,origin,target).blockers==0,'Movement-only fence is not ballistic cover')
    records[wall.index].SkillId=3;assert(#shot(area,origin,target).blockers==0,'Low structure below the existing ray height does not intercept')
    records[wall.index].SkillId=1;assert(#shot(area,origin,target).blockers==1)
    records[wall.index]=nil;assert(#shot(area,origin,target).blockers==0 and area:CanSee(origin,target))
end)

test('independent boards support original actor/true occupancy and retain non-projectile rules',function()
    local grid=Board.Create(4,1,0);local origin,target=grid:Find(-3,0),grid:Find(2,0)
    grid:Find(-1,0).blocked=true
    local occupant=actor(4,0,0)
    local result=Trace.Trace(grid,origin,target,'direct',{['0:0']=occupant,['1:0']=true})
    assert(result.reachable and #result.blockers==3 and result.blockers[1].kind=='terrain' and result.blockers[2].actor==occupant)
    assert(Trace.Trace(grid,origin,target,'sight',{}).reachable)
    assert(not pcall(Trace.Trace,grid,origin,target,'invalid',{}))
end)

test('MapArea occupancy keeps live actor/NPC/tool identities, layer and full-footprint exclusions',function()
    local area=flat();local upstairs=area:AddLayerCell(7,4,1,3)
    local source,target,friend=actor(1,2,4),actor(9,8,4),actor(2,4,4)
    local party={source,friend};local npcs={{Id=1,Present=true,CellIndex=area:Find(6,4).index},{Id=2,Present=true,CellIndex=upstairs.index}}
    area.npcs={{templateId=1},{templateId=1}}
    local group={EnemyCount=1,GetEnemyAt=function()return target end}
    local state={MemberCount=2,EncounterCount=1,NpcCount=2,GetEncounterAt=function()return group end,
        GetMemberIdAt=function(_,i)return party[i+1].Id end,GetMemberCellAt=function(_,i)return area:Find(i==0 and 2 or 10,4).index end,
        GetNpcAt=function(_,i)return npcs[i+1]end}
    local obstacle={Id=3,RuleId=1,BlocksMovement=true,Cleared=false,CellCount=2,GetCellAt=function(_,i)return area:Find(5+i,5).index end}
    local areas=require('Game.MapArea.MapAreaSystem')();areas.data={Active=state,ActiveSiteId=1};areas.layouts={[1]=area}
    areas.adventure={PartyCount=2,GetPartyAt=function(_,i)return party[i+1]end}
    areas.config={GetTable=function()return {Get=function()return {name='居民甲'}end}end}
    areas.combatStats={animals={Cells=function(_,value,layout,q,r,layer)
        if value==friend then return {layout:Find(q,r,layer),layout:Find(q+1,r,layer)}end
        return {layout:Find(q,r,layer)}
    end}}
    areas.obstacles={data={Count=function()return 1 end,Get=function()return obstacle end},rules={Get=function()return {name='木箱路障'}end}}
    local occupied=areas:ShotOccupancy(source.Id,target.Id,{},0)
    assert(occupied['4:4'].actor==friend and occupied['5:4'].key=='actor:2' and not occupied['8:4'])
    assert(occupied['6:4'].kind=='npc' and occupied['6:4'].name=='居民甲' and not occupied['7:4'])
    assert(occupied['5:5'].kind=='obstacle' and occupied['5:5'].name=='木箱路障' and occupied['5:5'].key==occupied['6:5'].key)
    friend.HP=0;obstacle.Cleared=true;npcs[1].Present=false
    occupied=areas:ShotOccupancy(source.Id,target.Id,{},0);assert(not occupied['4:4'] and not occupied['5:5'] and not occupied['6:4'])
    friend.HP=20;occupied=areas:ShotOccupancy(source.Id,target.Id,nil,0)
    assert(occupied['10:4'].actor==friend and not occupied['4:4'],'Exploration uses current squad placement')
end)

print('Projectile trace: '..count..' checks passed')
