-- 独立移动检查：真实 C# MapAreaStateData + Lua 命令/编队，不依赖远征角色初始化。
local Layout=require('Game.MapArea.MapAreaLayout')
local Squad=require('Game.MapArea.SquadMovement')
local AreaSystem=require('Game.MapArea.MapAreaSystem')
local function fixture(town,count)
    local area=Layout.New({id=1,name='Movement',areaType=town and 2 or 1,width=12,height=12,
        hexRadius=1.5,visionRadius=8,moveStepSeconds=.5,discovery=town and 'open' or 'explore'},1,{}, {})
    local all={}
    for _,cell in ipairs(area.cells) do cell.blocked=false;cell.blocksSight=false;all[#all+1]=cell.index end
    local state=CS.ProjectY.Data.MapAreaStateData(1,#area.cells,area:Find(4,5).index)
    local ids={};for i=1,count do ids[i]=i end
    state:DeployMembers(ids,Squad.Deploy(area,state.CellIndex,count));state:Reveal(all)
    local system=AreaSystem()
    local actors={};for i=1,count do actors[i]={Id=i,HP=1} end
    system.data={Active=state,ActiveSiteId=1};system.layouts={[1]=area}
    system.adventure={Phase='area',PartyCount=count,GetPartyAt=function(_,i) return actors[i+1] end}
    system.effectTicks=0
    local battle={gameEffects={Tick=function() system.effectTicks=system.effectTicks+1 end}}
    system.context={services={},systems={Get=function(_,name) assert(name=='Battle');return battle end}}
    system.townType=2;system.explorationRoundSeconds=1
    -- 本夹具只有未骑乘、单格占地的角色；不模拟 C# 的占格、时钟或路线。
    system.SquadFootprint=function() return function(index) return {index} end end
    return system,area,state
end
local function positions(state)
    local cells={};for i=0,state.MemberCount-1 do cells[i+1]=state:GetMemberCellAt(i) end;return cells
end
local function valid(area,state,old)
    local used={}
    for i,index in ipairs(positions(state)) do
        assert(not used[index] and not area.cells[index].blocked,'Overlapping/blocked squad step');used[index]=true
        assert(index==old[i] or area:CanStep(area.cells[old[i]],area.cells[index]),'Non-adjacent squad step')
        for j=1,i-1 do assert(not(index==old[j] and state:GetMemberCellAt(j-1)==old[i]),'Head-on swap') end
    end
end
for count=1,4 do
    local system,area,state=fixture(true,count)
    for _=1,2 do
        local before=positions(state);local goal=area:Find(area.cells[state.CellIndex].q+1,5)
        local direction
        for d,index in ipairs(area.cells[state.CellIndex].neighbors) do if index==goal.index then direction=d end end
        assert(direction and system:Walk(direction))
        assert(state.CellIndex==goal.index,'First keyboard step must commit without waiting for Tick')
        valid(area,state,before)
        assert(system:Stop());system:Tick(.75)
        assert(state.CellIndex==goal.index and state.RemainingSteps==0,'Short press was cancelled or kept walking')
    end
    assert(state.WorldRound==1,'Immediate steps must still count their exploration time')
    assert(system.effectTicks==count*2,'Immediate movement skipped exploration round effects')
    local blocked=area:Find(7,5);blocked.blocked=true
    local stopped=state.CellIndex
    assert(not system:MoveToIndex(blocked.index));assert(state.CellIndex==stopped)
    blocked.blocked=false
    state:SetInteraction(1,1)
    assert(not system:MoveToIndex(blocked.index));assert(state.CellIndex==stopped)
    state:SetInteraction(0,0)
    local before=positions(state);local goal=area:Find(9,5)
    assert(system:MoveToIndex(goal.index,false));valid(area,state,before)
    assert(state.CellIndex~=stopped,'Click route must start immediately')
    local first=state.CellIndex;system:Tick(.25)
    assert(state.CellIndex==first,'Next step must retain its smooth movement duration')
    before=positions(state);system:Tick(.25);valid(area,state,before)
    assert(state.CellIndex~=first,'Next step stalled after the movement duration')
    for _=1,16 do
        if state.RemainingSteps==0 then break end
        before=positions(state);system:Tick(.5);valid(area,state,before)
    end
    assert(state.CellIndex==goal.index and state.RemainingSteps==0)
end
local system,area,state=fixture(false,1)
local before=state.CellIndex;local goal=area:Find(5,5)
assert(system:MoveToIndex(goal.index,false));assert(state.CellIndex==before,'Dungeon timing changed')
system:Tick(.25);assert(state.CellIndex==before)
system:Tick(.25);assert(state.CellIndex==goal.index)
return 'PASS town movement: 1..4 members, immediate keyboard/click steps, short press/stop, smooth cadence, blockers, interaction, exploration time, unchanged dungeon timing'
