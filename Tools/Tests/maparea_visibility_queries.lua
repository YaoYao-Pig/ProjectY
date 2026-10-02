-- 单次队伍视野查询复用动态投影；离线验证结果与活视图一致，并约束跨桥查询次数。
package.path='Lua/?.lua;'..package.path
local Layout=require('Game.MapArea.MapAreaLayout')
local AreaSystem=require('Game.MapArea.MapAreaSystem')
local Construction=require('Game.Battle.Construction')
local ContainerTerrain=require('Game.Loot.ContainerTerrain')
local function fixture(layered)
    local base=Layout.New({id=1,name='Visibility query',areaType=1,width=16,height=16,hexRadius=1,
        visionRadius=6,moveStepSeconds=.13},1,{}, {wallHeight=3})
    for _,cell in ipairs(base.cells) do
        cell.blocked=false;cell.blocksSight=false;cell.kind='floor';cell.height=0
    end
    if layered then
        base.layeredVisibility=true;base.layerCount=2
        for q=6,10 do for r=4,9 do
            local cell=base:AddLayerCell(q,r,1,3);cell.deckThickness=.2
        end end
    end
    local wall=base:Find(7,7);wall.blocked=true;wall.blocksSight=true;wall.wallHeight=3
    local containerIndex=base:Find(6,6).index
    local constructionIndex=base:Find(6,8).index
    local positions={base:Find(5,7).index,base:Find(5,6).index,base:Find(4,7).index,base:Find(4,8).index}
    base=Layout.Freeze(base)
    local revision,revisionReads,destroyed,destroyedReads=0,0,false,0
    local data=setmetatable({Count=0,records={}},{__index=function(_,key)
        assert(key=='Revision');revisionReads=revisionReads+1;return revision
    end})
    function data:GetAt(i)return self.records[i+1] end
    local construction=setmetatable({data=data,cache={},cacheRevision=-1,definitions={Get=function(_,id)
        assert(id==1);return {kind='wall',height=3,blocksMovement=true,blocksSight=true,moveExtra=0}
    end}},Construction)
    local physical=setmetatable({Configured=true,CellCount=1,GetCellAt=function()return containerIndex end},
        {__index=function(_,key)assert(key=='Destroyed');destroyedReads=destroyedReads+1;return destroyed end})
    local container={TableId=1}
    local state={LootCount=1,MemberCount=4,GetLootAt=function()return container end,
        GetMemberCellAt=function(_,i)return positions[i+1] end,Reveal=function(self,values)self.visible=values end}
    local loot={Physical=function()return physical end,rules={containers={Get=function()
        return {blocksMovement=true,blocksSight=true}
    end}}}
    local area=ContainerTerrain.Wrap(construction:Layout(base,1),loot,state)
    local system=AreaSystem()
    local function union()
        local result={}
        for _,index in ipairs(positions) do for _,visible in ipairs(area:VisibleFrom(index)) do result[visible]=true end end
        return result
    end
    local function check(label)
        local expected=union();revisionReads=0;destroyedReads=0
        local original=Layout.CanSee
        local missingQuery=false
        Layout.CanSee=function(self,origin,target,query)
            if layered and not query then missingQuery=true end
            return original(self,origin,target,query)
        end
        local start=os.clock()
        local ok,err=pcall(system.RevealSquad,system,area,state)
        local ms=(os.clock()-start)*1000
        Layout.CanSee=original
        assert(ok,err)
        local actual={};for _,index in ipairs(state.visible) do assert(not actual[index]);actual[index]=true end
        for index in pairs(expected) do assert(actual[index],'Visibility lost at '..index) end
        for index in pairs(actual) do assert(expected[index],'Visibility leaked at '..index) end
        print(string.format('%s %s visible=%d ms=%.3f constructionRevisionReads=%d containerReads=%d',
            layered and 'layered' or 'flat',label,#state.visible,ms,revisionReads,destroyedReads))
        assert(revisionReads==1,'Squad reveal must read construction revision once, not once per ray/cell field')
        assert(not missingQuery,'Terrain overlays must forward the shared layered visibility query')
        return actual
    end
    -- 坐标、邻接、楼层等静态字段不应读取容器耐久状态。
    local cell=area.cells[containerIndex]
    local identity={cell.index,cell.q,cell.r,cell.layer,cell.neighbors,cell.height}
    assert(#identity==6 and destroyedReads==0,'Static container cell fields queried durability')
    check('empty construction')
    data.Count=1;data.records[1]={SiteId=1,CellIndex=constructionIndex,SkillId=1,Removed=false};revision=revision+1
    check('constructed wall')
    data.records[1].Removed=true;revision=revision+1;destroyed=true
    check('wall removed and container destroyed')
    assert(not area:NavigationView().cells[containerIndex].blocked,'Destroyed container remained blocked')
end
fixture(false)
fixture(true)
print('PASS squad visibility equivalence, construction changes, container destruction and shared layered queries')
