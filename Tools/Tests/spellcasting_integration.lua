-- Real C# actors, inventory, effect rules and BattleSystem; isolated services, no active game.
local registry=require('Core.SystemRegistry')(Services)
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('Battle',require('Game.Battle.BattleSystem'),{'Config'})
registry:Register('Equipment',require('Game.Equipment.EquipmentSystem'),{'Config'})
local results={}
local ok,err=xpcall(function()
    registry:Start()
    local battle,equipment=registry:Get('Battle'),registry:Get('Equipment')
    local data=Services.Adventure;data:Reset(20261027);equipment:Start()
    local source=data:AddPartyActor(1,3);local ally=data:AddPartyActor(2,1)
    local enemies={CS.ProjectY.Data.CombatActorData(101,4),CS.ProjectY.Data.CombatActorData(102,4)}
    local units={source,ally,enemies[1],enemies[2]}
    for _,actor in ipairs(units)do
        actor.Growth:Initialize(actor.Id,0,10,0)
        actor:SetMaxHP(battle.stats:MaximumHP(actor));actor:Restore()
    end
    for _,id in ipairs({2301,2302,2303,2308,104})do source.Growth:GrantSkill(id)end
    source.Growth:InvestTalent(302,1)
    local staff=equipment.data:AddWeapon(103);assert(equipment.data:Equip(source.Id,staff.Id))
    local Layout=require('Game.MapArea.MapAreaLayout')
    local area=Layout.New({id=999,name='Spell fixture',areaType=1,width=12,height=12,hexRadius=1,visionRadius=9,moveStepSeconds=.1},1,{}, {wallHeight=3})
    for _,cell in ipairs(area.cells)do cell.height=0;cell.blocked=false;cell.blocksSight=false;cell.kind='floor' end
    battle.board=require('Game.Battle.BattleBoard').FromArea(area,4,4,8)
    battle.data:Reset(1,20)
    local positions={{2,4},{5,3},{5,4},{8,4}}
    for i,actor in ipairs(units)do battle.data:AddUnit(actor,i<=2 and 1 or 2,positions[i][1],positions[i][2])end
    battle.data:BeginDeployment();battle.data:BeginRound();battle.data:AddTurn(source.Id);battle.data:SelectTurn(0)
    battle.spellcasting:BindBoard(battle);battle.spellcasting:Sync(source)
    local state=CS.ProjectY.Data.SpellcastingState
    assert(state.Current(source)==8 and state.Maximum(source)==8)
    local owned={};for _,id in ipairs(battle:SkillIds(source))do owned[id]=true end
    assert(owned[2304] and owned[2305] and owned[2306] and owned[2307])
    source:BeginTurn(8)
    assert(battle:SetCastingBoost(2304,2));assert(state.Current(source)==8)
    local ap,points=source.AP,state.Current(source)
    assert(not battle:TrySkillAt(2304,99,99));assert(source.AP==ap and state.Current(source)==points)
    local friendHP,enemyHP=ally.HP,enemies[1].HP
    assert(battle:TrySkillAt(2304,5,4))
    assert(source.AP==5 and state.Current(source)==1 and state.Boost(source,2304)==0)
    assert(ally.HP<friendHP and enemies[1].HP<enemyHP and state.FieldCount(battle.data)==1)
    assert(battle.spellcasting:FieldRows(battle)[1].kind=='fire')
    results[#results+1]='PASS real bridge: learning/equipment, automatic recipes, preview/rejection zero cost, boosted meteor one payment and friendly fire'
    source:BeginTurn(8);source:SetCooldown(2304,0)
    ap,points=source.AP,state.Current(source)
    assert(not battle:TrySkillAt(2304,5,4));assert(source.AP==ap and state.Current(source)==points)
    assert(battle:TrySkill(2308,source.Id));assert(state.Current(source)==4 and source.AP==6 and not source.MainUsed)
    assert(battle:TrySkillAt(2305,5,4));assert(state.Current(source)==1)
    assert(state.FieldCount(battle.data)==1 and state.FieldAt(battle.data,0).Kind=='mist')
    assert(not require('Game.Battle.SkillTrajectory').CanReach(battle.board,battle.board:Find(2,4),battle.board:Find(8,4),'direct'))
    assert(not battle:CanUseSkill(6,102))
    results[#results+1]='PASS real bridge: exhausted casts refuse, recovery preserves main action, steam extinguishes fire and blocks targeting'
    local before=state.Current(source);battle.spellcasting:BeginTurn(source,battle)
    assert(state.Current(source)==before+1)
    battle:ClearBattleEffects();assert(state.FieldCount(battle.data)==0 and state.Current(source)==before+1)
    results[#results+1]='PASS real bridge: turn recovery and battle cleanup preserve persistent casting points'
end,debug.traceback)
registry:Shutdown();if not ok then error(err,0)end
return table.concat(results,'\n')
