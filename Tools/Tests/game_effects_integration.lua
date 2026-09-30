assert(Services.CharacterSaves.FilePath:find('project-y-ux-',1,true),'Use a dedicated project-y-ux-* temporary save path')
local registry=require('Core.SystemRegistry')(Services)
require('Game.Systems')(registry)
local ok,result=xpcall(function()
    registry:Start()
    local adventure,battle,config=registry:Get('Adventure'),registry:Get('Battle'),registry:Get('Config')
    adventure:Start()
    local definitions={};for _,row in ipairs(config:GetTable('CombatEffectTable'):All())do definitions[row.id]=row end
    local function define(id,kind,amount,extra)
        local row={id=id,name='验证效果 '..id,description='隔离测试，不写入正式配置',kind=kind,amount={Evaluate=function()return amount end},duration='duration',durationTurns=3,periodTurns=1,tickPhase='turn_start',stacking='refresh',maxStacks=1,removeOnBattleEnd=false,removeOnDeath=true,attribute='',iconId=1}
        for k,v in pairs(extra or {})do row[k]=v end;definitions[id]=row;return row
    end
    define(901,'damage',2);define(902,'heal',2,{tickPhase='turn_end'});define(903,'modifier',3,{periodTurns=0,attribute='strength'})
    define(904,'damage',1,{duration='infinite',durationTurns=0,stacking='stack',maxStacks=2,removeOnBattleEnd=true})
    define(905,'damage',10000,{removeOnBattleEnd=true});define(906,'damage',1,{stacking='independent'})
    define(907,'modifier',100,{duration='infinite',durationTurns=0,periodTurns=0,attribute='speed',removeOnBattleEnd=true})
    local table={Get=function(_,id)return assert(definitions[id])end,All=function()local all={};for _,r in pairs(definitions)do all[#all+1]=r end;return all end}
    battle.effects=table;battle.stats.effects=table;battle.gameEffects.definitions=table;battle.gameEffects:Validate()
    local actor=adventure.data:GetPartyAt(0);local second=adventure.data:GetPartyAt(1)
    local effect=battle.gameEffects
    actor:Damage(8);local before=actor.HP
    effect:Apply(901,second,actor);effect:TickActor(actor,'turn_start');assert(actor.HP==before-2)
    effect:Apply(902,second,actor);effect:TickActor(actor,'turn_end');assert(actor.HP==before)
    local strength=battle.stats:Get(actor,'strength');effect:Apply(903,second,actor);assert(battle.stats:Get(actor,'strength')==strength+3)
    effect:Apply(904,second,actor);effect:Apply(904,second,actor);effect:Apply(904,second,actor);assert(actor.Effects:Find(904).Stacks==2)
    effect:Apply(906,second,actor);effect:Apply(906,second,actor)
    local count=actor.Effects.Count;effect:Clear(actor,'battle_end');assert(actor.Effects.Count==count-1 and actor.Effects:Find(901))
    local hp=actor.HP;local remaining=actor.Effects:Find(901).Remaining
    Services.CharacterSaves:Save(adventure.data,Services.Player)
    local restored=Services.CharacterSaves:Prepare(adventure.data.Equipment):GetActorAt(0)
    assert(restored.HP==hp and restored.Effects.Count==actor.Effects.Count and restored.Effects:Find(901).Remaining==remaining)
    assert(restored.Effects:Find(901).SourceId==second.Id and restored.Effects:Find(901).SourceName~='')
    effect:ValidateSaved(restored)
    local file=assert(io.open(Services.CharacterSaves.FilePath,'rb'));local saved=file:read('*a');file:close()
    local legacy,replaced=saved:gsub('"version": 3','"version": 2',1);assert(replaced==1)
    file=assert(io.open(Services.CharacterSaves.FilePath,'wb'));file:write(legacy);file:close()
    local old=Services.CharacterSaves:Prepare(adventure.data.Equipment)
    assert(old:GetActorAt(0).Effects.Count==0 and not old.LegacyNarrative,'v2 migrates effects without losing narrative data')
    file=assert(io.open(Services.CharacterSaves.FilePath,'wb'));file:write(saved);file:close()
    while actor.Effects.Count>0 do effect:Remove(actor,actor.Effects:GetAt(0).Id) end
    local site;for _,candidate in ipairs(adventure.sites)do if candidate.areaConfigId==1 then site=candidate;break end end
    assert(site and adventure:Visit(site.id));local areas=adventure.areas
    areas.combatStats.effects=table
    local layout,state=areas:ActiveLayout(),adventure.data.Areas.Active
    local all={};for _,cell in ipairs(layout.cells)do all[#all+1]=cell.index end;state:Reveal(all)
    local found=false
    for i=#layout.cells,1,-1 do
        local cell=layout.cells[i]
        if not cell.blocked and areas:MoveToIndex(cell.index) and state.RemainingSteps*layout.moveStepSeconds>=areas.explorationRoundSeconds*2 then found=true;break end
    end
    assert(found,'Effect fixture needs a real exploration route')
    effect:Apply(901,second,actor);local oldHP=actor.HP
    areas:Tick(areas.explorationRoundSeconds)
    assert(actor.HP==oldHP-2 and actor.Effects:Find(901).Remaining==2,'Exploration route advances periodic effects')
    areas:Stop();oldHP=actor.HP;areas:Tick(areas.explorationRoundSeconds*2);assert(actor.HP==oldHP,'Idle exploration must not advance the effect clock')
    local group=state:GetEncounterAt(0);local victim=group:GetEnemyAt(0)
    for i=1,group.EnemyCount-1 do group:GetEnemyAt(i):Damage(1000000) end
    local occupied=areas:EnemyOccupancy(layout,state);local origin
    for _,cell in ipairs(layout:Neighbors(assert(layout:Find(victim.Q,victim.R))))do if not occupied[cell.index] then origin=cell;break end end
    assert(origin);local ids={};for i=0,state.MemberCount-1 do ids[#ids+1]=state:GetMemberIdAt(i) end
    local positions=require('Game.MapArea.SquadMovement').Deploy(layout,origin.index,#ids,function(cell)return not occupied[cell.index]end)
    state:DeployMembers(ids,positions)
    effect:Apply(907,second,victim);effect:Apply(905,second,victim)
    areas:StartBattle(battle,group)
    assert(battle.data.Winner=='victory' and group.Defeated,'A retained effect can settle the encounter on its first turn')
    adventure:Tick();assert(adventure.data.Phase=='area','An opening effect victory must settle exactly once')
    assert(areas:Leave())
    while actor.Effects.Count>0 do effect:Remove(actor,actor.Effects:GetAt(0).Id) end
    local party={};for i=0,adventure.data.PartyCount-1 do local unit=adventure.data:GetPartyAt(i);unit:Restore();party[#party+1]=unit end
    battle:Start(1,party,123)
    local active=battle:Active();effect:Apply(905,second,active)
    battle:BeginTurn(battle.data.TurnIndex)
    assert(active.HP==0 and (battle.data.Winner~='' or battle:Active().Id~=active.Id),'Start-of-turn damage must skip a defeated actor')
    return 'PASS real C# GameEffect instances, attribute projection, capped/independent stacks, battle cleanup, v3 save round-trip/v2 migration, exploration/idle clocks and lethal turn-start advancement'
end,debug.traceback)
registry:Shutdown()
if not ok then error(result,0)end
return result
