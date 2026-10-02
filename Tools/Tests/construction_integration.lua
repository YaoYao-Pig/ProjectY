local registry=require('Core.SystemRegistry')(Services)
require('Game.Systems')(registry)
local messages={}
local function test(name,run)run();messages[#messages+1]='PASS '..name end
local ok,err=xpcall(function()
    registry:Start()
    local adventure=registry:Get('Adventure');adventure:Start()
    local data,equipment,battle=adventure.data,adventure.equipment,adventure.battle
    local actor=data:GetPartyAt(0);local Layout=require('Game.MapArea.MapAreaLayout')
    local base=Layout.New({id=1,name='Craft test',areaType=3,width=9,height=9,hexRadius=1,visionRadius=8,moveStepSeconds=.1},1,{regionId=1,regionType=1},{name='Test'})
    for _,cell in ipairs(base.cells) do cell.height=0;cell.blocked=false;cell.blocksSight=false;cell.kind='floor';cell.surfaceId=201;cell.wallHeight=2 end
    base.entryIndex=1;base.goalIndex=81;base.props={};base.assetId=1
    base=Layout.Freeze(base)
    local layout=adventure.construction:Layout(base,987)
    adventure.areas.layouts[987]=layout
    local state=data.Areas:Enter(987,#layout.cells,layout.entryIndex)
    local known={};for i=1,#layout.cells do known[i]=i end;state:Reveal(known)
    data:BeginArea(987)
    local board=require('Game.Battle.BattleBoard').FromArea(layout,4,4,7);board.allowed=function()return true end
    local enemy=CS.ProjectY.Data.CombatActorData(900,battle.encounters:Get(1).enemyIds[1]);enemy:SetMaxHP(100);enemy:Restore();enemy:Deploy(2,6,4)
    for _,id in ipairs({301,302,303,304,305,306}) do actor.Growth:GrantSkill(id) end
    battle:StartArea(1,board,{{actor=actor,q=3,r=4}},{enemy})
    local function turn()
        local index
        for i=0,battle.data.TurnCount-1 do if battle.data:GetTurnAt(i)==actor.Id then index=i end end
        assert(index);battle:BeginTurn(index)
    end
    turn()
    test('invalid material placement preserves AP, stacks and construction state',function()
        local ap=actor.AP;local rev=adventure.construction.data.Revision
        local valid=battle:TrySkillAt(301,4,4)
        assert(not valid and actor.AP==ap and adventure.construction.data.Revision==rev)
        assert(equipment:Grant(81,30));assert(equipment:Grant(82,10));assert(equipment:Grant(83,6))
        local before=equipment.data:CountItem(81)
        assert(battle:TrySkillAt(301,4,4));assert(equipment.data:CountItem(81)==before-2,'Construction must consume real stacks');assert(actor.AP==ap-2,'Construction AP cost differs')
        assert(layout:Find(4,4).blocked and not base:Find(4,4).blocked)
        assert(not battle:TrySkillAt(301,4,4) and equipment.data:CountItem(81)==before-2)
        local record=adventure.construction:Record(987,layout:Find(4,4).index)
        while not record.Removed do turn();assert(battle:TrySkillAt(307,4,4)) end
        assert(not layout:Find(4,4).blocked)
    end)
    test('high platform changes standing height and ranged reach; demolition restores ground',function()
        turn();assert(battle:TrySkillAt(304,4,4));local cell=layout:Find(4,4)
        assert(cell.height==1.4)
        turn();assert(battle:TryMove(4,4));assert(actor.Q==4)
        assert(adventure.construction:RangeBonus(board,actor,enemy,{target='enemy',range=3})==1)
        local record=adventure.construction:Record(987,cell.index)
        -- 同一套可破坏规则也允许拆毁脚下工事，单位回落到原地面。
        while not record.Removed do turn();assert(battle:TrySkillAt(307,4,4)) end
        assert(cell.height==0 and actor.Q==4 and actor.R==4)
    end)
    test('digging requires an equipped shovel and an allowed surface',function()
        turn();local ap=actor.AP
        assert(not battle:TrySkillAt(305,4,3) and actor.AP==ap)
        assert(equipment:Grant(73,1));local shovel
        for i=0,equipment.data.WeaponCount-1 do local value=equipment.data:GetWeaponAt(i);if value.ItemId==73 then shovel=value end end
        assert(shovel);assert(equipment:Command('equip',actor.Id,shovel.Id))
        assert(battle:TrySkillAt(305,4,3));assert(layout:Find(4,3).height==-.25)
        local copy=adventure.construction:Layout(base,987)
        assert(copy:Find(4,3).height==-.25,'Reentering the same location must keep excavation')
        assert(adventure.construction:Layout(base,988):Find(4,3).height==0,'Other locations must remain unchanged')
    end)
    test('C# material transaction is atomic and reset clears the terrain',function()
        local before=equipment.data:CountItem(81);local count=adventure.construction.data.Count
        assert(not pcall(function()adventure.construction.data:Place(987,10,302,40,equipment.data,{81,83},{1,999})end))
        assert(equipment.data:CountItem(81)==before and adventure.construction.data.Count==count)
        adventure.construction.data:Clear();assert(layout:Find(4,3).height==0)
    end)
    test('persistent barriers remain removable after battle through the exploration skill bar',function()
        local cell=layout:Find(4,3)
        adventure.construction.data:Place(987,cell.index,301,20,equipment.data,{}, {})
        state:DeployMembers({actor.Id},{layout:Find(4,4).index});battle.board=nil
        local record=adventure.construction:Record(987,cell.index)
        local rows=adventure.characterSkills:Rows(actor.Id,'life');local action
        for _,row in ipairs(rows) do if row.id==307 then action=row end end
        assert(action and action.available and action.target=='cell')
        local rounds=state.WorldRound
        assert(adventure.characterSkills:Use(actor.Id,307,cell.index))
        assert(record.Removed and not cell.blocked and state.WorldRound==rounds+1)
    end)
    test('material stacks pass character-save validation without changing user saves',function()
        local prepared={ActorCount=0,Equipment=equipment.data,LegacyNarrative=true}
        require('Game.Adventure.CharacterSave').Validate(adventure,prepared)
    end)
    test('enemy AI breaks a reachable barrier when every route to the party is sealed',function()
        adventure.construction.data:Clear()
        for r=0,8 do adventure.construction.data:Place(987,layout:Find(5,r).index,302,5,equipment.data,{}, {}) end
        battle:StartArea(1,board,{{actor=actor,q=4,r=4}},{enemy})
        for i=0,battle.data.TurnCount-1 do if battle.data:GetTurnAt(i)==enemy.Id then battle:BeginTurn(i) end end
        assert(battle:StepAI())
        local removed=0
        for i=0,adventure.construction.data.Count-1 do if adventure.construction.data:GetAt(i).Removed then removed=removed+1 end end
        assert(removed==1,'Enemy must spend its main action breaking the blockade')
    end)
end,debug.traceback)
registry:Shutdown()
if not ok then error(err) end
return table.concat(messages,'\n')
