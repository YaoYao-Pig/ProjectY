local registry=require('Core.SystemRegistry')(Services)
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('PlayerModel',require('Game.PlayerModelSystem'),{'Config'})
registry:Register('Map',require('Game.Map.MapSystem'),{'Config'})
registry:Register('MapArea',require('Game.MapArea.MapAreaSystem'),{'Config'})
registry:Register('Battle',require('Game.Battle.BattleSystem'),{'Config'})
registry:Register('Equipment',require('Game.Equipment.EquipmentSystem'),{'Config'})
registry:Register('Growth',require('Game.Progression.GrowthSystem'),{'Battle'})
registry:Register('AdventureEvents',require('Game.Adventure.EventSystem'),{'Battle','PlayerModel','Growth','Equipment'})
registry:Register('Adventure',require('Game.Adventure.AdventureSystem'),{'Map','MapArea','AdventureEvents','Equipment'})
local messages={}
local function test(name,run)run();messages[#messages+1]='PASS '..name end
local ok,err=xpcall(function()
    registry:Start()
    local adventure=registry:Get('Adventure');adventure:Start()
    local data,areas,battle,eq=adventure.data,adventure.areas,adventure.battle,adventure.equipment
    local actor=data:GetPartyAt(0);actor.Growth:GrantSkill(3);actor.Growth:GrantSkill(103)
    local Layout=require('Game.MapArea.MapAreaLayout')
    local base=Layout.New({id=999,name='Container test',areaType=3,width=10,height=10,hexRadius=1,visionRadius=10,moveStepSeconds=.1},71,{}, {})
    for _,cell in ipairs(base.cells) do cell.blocked=false;cell.blocksSight=false;cell.height=0;cell.kind='floor';cell.surfaceId=201 end
    base.entryIndex=1;base.goalIndex=100;base.props={};base.containerPlans={}
    local plans={{200,4,4},{201,5,4},{206,4,6},{204,7,7},{202,2,4},{205,2,6}}
    for i,row in ipairs(plans) do local cell=base:Find(row[2],row[3]);local cells={cell.index}
        if row[1]==206 then cells[2]=base:Find(row[2]+1,row[3]).index end
        base.containerPlans[i]={cellIndex=cell.index,cells=cells,rotation=0,lootTableId=row[1],seed=i*97,poolOverrideId=i==2 and 5 or 0,unlockEncounterId=i==4 and 1 or 0}
    end
    base=Layout.Freeze(base);areas.layouts[987]=adventure.construction:Layout(base,987)
    local state=data.Areas:Enter(987,#base.cells,base.entryIndex)
    local group=state:AddEncounter(1,1);local enemy=group:AddEnemy(900,battle.encounters:Get(1).enemyIds[1],8,8);enemy:SetMaxHP(500);enemy:Restore();state:CompleteEncounterInitialization()
    state:DeployMembers({actor.Id},{base:Find(3,4).index})
    local all={};for i=1,#base.cells do all[i]=i end;state:Reveal(all);data:BeginArea(987)
    eq:InitializeLoot(areas)
    local area=areas:ActiveLayout();local cc=adventure.containerCombat;local physical=CS.ProjectY.Data.ContainerState
    local pot,wood,tableLoot,boss=state:GetLootAt(0),state:GetLootAt(1),state:GetLootAt(2),state:GetLootAt(3)
    local function contents(row)
        local result={};for i=0,row.ItemCount-1 do result[#result+1]=row:GetItemIdAt(i)..':'..row:GetCountAt(i) end;return table.concat(result,',')
    end
    test('reflection bridge, immutable base and initial interaction gates',function()
        assert(physical.Of(pot).Durability==12 and not physical.Of(pot).CanSearch)
        assert(area.cells[pot.CellIndex].blocked and not base.cells[pot.CellIndex].blocked)
        assert(not eq:Loot(areas,pot.Id),'Unbroken pottery must not be searchable')
        assert(not cc:CanArea(actor,5,pot.Id),'Healing must not damage a container')
        assert(not cc:CanArea(actor,3,boss.Id),'Encounter-locked boss reward must resist attacks')
        assert(not eq:Loot(areas,5),'Crate requires equipped crowbar or destruction')
        assert(eq:Grant(74,1));local crowbar
        for i=0,eq.data.WeaponCount-1 do local weapon=eq.data:GetWeaponAt(i);if weapon.ItemId==74 then crowbar=weapon end end
        assert(not eq:Loot(areas,5),'An unequipped tool must not qualify')
        assert(eq:Command('equip_offhand',actor.Id,crowbar.Id));local round=state.WorldRound
        assert(eq:Loot(areas,5));eq.worldLoot.session:Close();assert(state.WorldRound==round+1)
        assert(eq:Command('unequip_offhand',actor.Id));assert(eq:Loot(areas,5));eq.worldLoot.session:Close()
        assert(state.WorldRound==round+1,'An already opened crate must not charge the tool cost twice')
        local rows=adventure.characterSkills:Rows(actor.Id,'life');local skill
        for _,row in ipairs(rows) do if row.id==3 then skill=row end end
        assert(skill and skill.target=='container' and skill.available,'Exploration skill bar must expose container targets')
        state:Reveal({state:GetMemberCellAt(0)});assert(not cc:CanArea(actor,3,pot.Id),'A cached target must disappear when sight changes')
        state:Reveal(all);assert(cc:CanArea(actor,3,pot.Id))
    end)
    test('exploration damage preserves inventory, consumes time and removes blocking once',function()
        local original=contents(pot);local count=state.LootCount;local rounds=state.WorldRound
        for attempt=1,20 do if physical.Of(pot).Destroyed then break end;assert(adventure.characterSkills:Use(actor.Id,3,pot.Id)) end
        assert(physical.Of(pot).Destroyed and not area.cells[pot.CellIndex].blocked)
        assert(state.WorldRound>rounds and contents(pot)==original and state.LootCount==count)
        rounds=state.WorldRound
        assert(not cc:Area(actor,3,pot.Id) and state.WorldRound==rounds,'Duplicate destroy must not consume resources or generate rewards')
        assert(eq:Loot(areas,pot.Id));eq.worldLoot.session:Close()
    end)
    test('partial looting then destruction retains the same item ownership',function()
        state:DeployMembers({actor.Id},{base:Find(4,4).index})
        assert(eq:Loot(areas,wood.Id));local session=eq.worldLoot.session
        local item=session:GetAt(0);session:Advance(item.Key,2,1)
        local placed=false
        for rotation=0,1 do for y=0,eq.data.Grid.Height-1 do for x=0,eq.data.Grid.Width-1 do
            if not placed and eq.worldLoot:Take(areas,item.Key,x,y,rotation==1) then placed=true end
        end end end
        assert(placed,'Test inventory cannot fit the guaranteed weapon')
        session:Close();local original=contents(wood);local count=state.LootCount
        for attempt=1,20 do if physical.Of(wood).Destroyed then break end;assert(cc:Area(actor,3,wood.Id)) end
        assert(physical.Of(wood).Destroyed and contents(wood)==original and state.LootCount==count)
        local before=physical.Of(wood).Durability;eq:InitializeLoot(areas)
        assert(physical.Of(wood).Durability==before and contents(wood)==original,'Reinitialization must not reset contents or durability')
    end)
    test('multi-cell side access and cooldown are authoritative',function()
        state:DeployMembers({actor.Id},{base:Find(6,6).index})
        assert(eq.worldLoot:Near(areas,tableLoot),'Access from far end of a two-cell table must work')
        assert(eq:Loot(areas,tableLoot.Id));eq.worldLoot.session:Close()
        assert(cc:Area(actor,103,tableLoot.Id));assert(actor:GetCooldown(103)==1)
        local round=state.WorldRound;assert(not cc:Area(actor,103,tableLoot.Id) and state.WorldRound==round)
        areas:SpendWorkRounds(1);assert(actor:GetCooldown(103)==0)
    end)
    test('combat attacks spend normal AP and never add containers to the initiative',function()
        local board=require('Game.Battle.BattleBoard').FromArea(area,5,5,8);board.allowed=function()return true end
        battle:StartArea(1,board,{{actor=actor,q=3,r=6}},{enemy})
        local function turn()
            for i=0,battle.data.TurnCount-1 do if battle.data:GetTurnAt(i)==actor.Id then battle:BeginTurn(i);return end end
            error('Missing player turn')
        end
        turn();local ap=actor.AP;local turns=battle.data.TurnCount
        assert(not cc:Battle(battle,3,boss.Id) and actor.AP==ap,'Locked target must not spend AP')
        local rack=state:GetLootAt(5)
        assert(cc:Battle(battle,3,rack.Id));assert(actor.AP==ap-battle:Skill(actor,3).cost)
        assert(battle.data.TurnCount==turns and battle.data.Winner=='','Container damage must not affect victory or initiative')
        assert(not cc:Battle(battle,3,rack.Id),'Normal main-action budget applies')
        enemy:Damage(enemy.HP);eq.worldLoot:SyncLock(state,boss)
        assert(physical.Of(boss).Unlocked,'Clearing the guarding encounter must unlock the reward')
    end)
    test('real snapshot carries footprint, durability, visibility and remaining loot',function()
        local snapshot=eq:LootSnapshot(areas);local found=false
        for _,row in ipairs(snapshot) do if row.id==tableLoot.Id then
            assert(#row.cells==2 and row.maxDurability==40 and row.scale>0);found=true
        end end
        assert(found)
        data.Areas:Leave();local isolated=data.Areas:Enter(988,#base.cells,1);assert(isolated.LootCount==0)
        data.Areas:Leave();data.Areas:Enter(987,#base.cells,1);assert(state:GetLootAt(1)==wood and physical.Of(wood).Destroyed)
    end)
    test('real rune splash damages a multi-cell container only once per shot',function()
        data:LeaveArea()
        local fresh=Layout.New({id=999,name='Splash test',areaType=3,width=10,height=10,hexRadius=1,visionRadius=10,moveStepSeconds=.1},83,{}, {})
        for _,cell in ipairs(fresh.cells) do cell.blocked=false;cell.blocksSight=false;cell.height=0;cell.kind='floor' end
        fresh.entryIndex=1;fresh.goalIndex=100;fresh.props={};fresh.containerPlans={}
        for i,row in ipairs({{201,4,4},{206,5,4},{200,5,5}}) do local cell=fresh:Find(row[2],row[3]);local cells={cell.index}
            if row[1]==206 then cells[2]=fresh:Find(6,4).index end
            fresh.containerPlans[i]={cellIndex=cell.index,cells=cells,rotation=0,lootTableId=row[1],seed=i,poolOverrideId=0,unlockEncounterId=0}
        end
        fresh=Layout.Freeze(fresh);areas.layouts[989]=adventure.construction:Layout(fresh,989)
        state=data.Areas:Enter(989,#fresh.cells,1);state:CompleteEncounterInitialization();state:DeployMembers({actor.Id},{fresh:Find(3,4).index})
        local known={};for i=1,#fresh.cells do known[i]=i end;state:Reveal(known);data:BeginArea(989)
        eq:InitializeLoot(areas);area=areas:ActiveLayout()
        assert(eq:Grant(1,1));assert(eq:Grant(11,1));local staff
        for i=0,eq.data.WeaponCount-1 do local weapon=eq.data:GetWeaponAt(i);if weapon.ItemId==1 then staff=weapon end end
        assert(eq:Command('equip',actor.Id,staff.Id));assert(eq:Command('attach',actor.Id,staff.Id,1,11))
        local enemy=CS.ProjectY.Data.CombatActorData(990,4);enemy:SetMaxHP(100);enemy:Restore();enemy:Deploy(2,8,8)
        local board=require('Game.Battle.BattleBoard').FromArea(area,5,5,8);board.allowed=function()return true end
        battle:StartArea(1,board,{{actor=actor,q=3,r=4}},{enemy})
        for i=0,battle.data.TurnCount-1 do if battle.data:GetTurnAt(i)==actor.Id then battle:BeginTurn(i) end end
        local skill=battle:Skill(actor,103);assert(skill.maxTargets==3 and skill.splashRadius==2)
        local middle=state:GetLootAt(1);local before=physical.Of(middle).Durability
        local amount=cc:Prepare(actor,skill,middle).effects[1]
        assert(cc:Battle(battle,103,1))
        assert(physical.Of(middle).Durability==before-amount,'Two occupied cells must not receive duplicate area damage')
        assert(physical.Of(state:GetLootAt(0)).Durability<30 and physical.Of(state:GetLootAt(2)).Durability<12)
        assert(enemy.HP==100,'An actor outside the splash must remain untouched')
    end)
    test('shared q/r coordinates across floors reject exploration attacks and looting',function()
        data:LeaveArea()
        local layered=Layout.New({id=999,name='Layer test',areaType=3,width=2,height=2,hexRadius=1,visionRadius=4,moveStepSeconds=.1},17,{}, {})
        for _,cell in ipairs(layered.cells) do cell.blocked=false;cell.blocksSight=false;cell.height=0;cell.kind='floor' end
        local upper=layered:AddLayerCell(0,0,1,3);layered.entryIndex=1;layered.goalIndex=4;layered.props={}
        layered.containerPlans={{cellIndex=upper.index,cells={upper.index},rotation=0,lootTableId=201,seed=999,poolOverrideId=0,unlockEncounterId=0}}
        layered=Layout.Freeze(layered);areas.layouts[991]=adventure.construction:Layout(layered,991)
        state=data.Areas:Enter(991,#layered.cells,1);state:CompleteEncounterInitialization();state:DeployMembers({actor.Id},{1});state:Reveal({1,2,3,4,5});data:BeginArea(991)
        eq:InitializeLoot(areas)
        assert(not cc:CanArea(actor,3,1) and not eq:Loot(areas,1),'Another floor must not be reachable through its shared coordinates')
    end)
end,debug.traceback)
registry:Shutdown()
if not ok then error(err) end
return table.concat(messages,'\n')
