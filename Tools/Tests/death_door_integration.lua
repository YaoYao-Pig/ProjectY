-- Actual exported rules and native state, with deterministic damage/check inputs in isolated services.
local registry=require('Core.SystemRegistry')(Services)
for _,spec in ipairs({
    {'Config','Config.ConfigSystem'}, {'Condition','Game.Condition.ConditionSystem',{'Config'}},
    {'PlayerModel','Game.PlayerModelSystem',{'Config'}}, {'Map','Game.Map.MapSystem',{'Config'}},
    {'MapArea','Game.MapArea.MapAreaSystem',{'Config'}}, {'Battle','Game.Battle.BattleSystem',{'Config'}},
    {'Equipment','Game.Equipment.EquipmentSystem',{'Config'}}, {'Growth','Game.Progression.GrowthSystem',{'Battle'}},
    {'AdventureEvents','Game.Adventure.EventSystem',{'Battle','PlayerModel','Growth','Equipment'}},
    {'Adventure','Game.Adventure.AdventureSystem',{'Map','MapArea','AdventureEvents','Equipment'}},
    {'Narrative','Game.Narrative.NarrativeSystem',{'Adventure','Condition'}}
})do registry:Register(spec[1],require(spec[2]),spec[3])end
local ok,result=xpcall(function()
    registry:Start();local adventure=registry:Get('Adventure');adventure:Start(20261031,3,2500)
    local battle,stats=adventure.battle,adventure.battle.stats
    local state,morale=CS.ProjectY.Data.DeathDoorState,CS.ProjectY.Data.MoraleState
    local actor=adventure.data:GetPartyAt(0);local enemy
    local effect;for _,row in ipairs(battle.effects:All())do if row.kind=='damage' and row.duration=='instant' and row.recipient=='target'then effect=row;break end end
    local function begin()
        battle.data:Reset(1,30);battle.board=require('Game.Battle.BattleBoard').Create(4,8,0)
        battle.data:AddUnit(actor,1,0,0);enemy=battle.data:AddEnemy(95001,4,1,0)
        stats.birth:Initialize(enemy,8);enemy:SetMaxHP(stats:MaximumHP(enemy));enemy:Restore()
        adventure.equipment:InitializeEnemy(enemy)
        battle:Emit('battle_started','Death-door fixture');battle.data:BeginDeployment();battle.data:BeginRound()
        battle.data:AddTurn(actor.Id);battle.data:AddTurn(enemy.Id);battle.data:SelectTurn(0)
        actor:BeginTurn(stats:Template(actor).actionPoints);enemy:BeginTurn(stats:Template(enemy).actionPoints)
        battle.spellcasting:BindBoard(battle)
    end
    begin()
    local checks,entered,defeated={},0,0
    local unsubscribe=battle.Changed:Subscribe(function(event)
        if event.kind=='death_door_check'then checks[#checks+1]=event
        elseif event.kind=='death_door_entered'then entered=entered+1
        elseif event.kind=='defeated' and event.targetId==actor.Id then defeated=defeated+1 end
    end)
    local raw=99;local rngCalls=0
    battle.gameEffects.roll=function()rngCalls=rngCalls+1;return raw end
    local function hit(amount,periodic)
        battle.gameEffects:Execute(effect,actor,amount,enemy.Id,stats:Template(enemy).name,effect.name,enemy,false,{},periodic==true)
    end
    hit(actor.HP+100)
    assert(actor.HP==0 and state.Alive(actor) and state.Entered(actor) and state.Used(actor) and not state.Dead(actor))
    assert(#checks==0 and entered==1 and defeated==0 and not battle:CheckWinner(),'First lethal hit incorrectly killed or rolled')
    assert(battle:Occupied()[require('Game.Map.HexGrid').Key(actor.Q,actor.R)]==actor and #battle:Reachable()>0,'Death-door actor lost occupancy/movement')
    actor:SpendAction('secondary',0);actor:BeginTurn(stats:Template(actor).actionPoints)
    battle.data:SelectTurn(1)
    local canTarget=false;for _,id in ipairs(battle:SkillIds(enemy))do if battle:CanUseSkill(id,actor.Id)then canTarget=true;break end end
    assert(canTarget,'AI cannot target a living actor at zero HP');battle.data:SelectTurn(0)
    local maximum=morale.Maximum(actor);morale.Set(actor,maximum,maximum,1)
    local before=rngCalls;hit(1)
    assert(#checks==1 and rngCalls==before+1 and checks[1].impact.roll==20 and checks[1].impact.deathChance==10)
    assert(actor.HP==0 and state.Alive(actor) and state.Survived(actor)==1 and stats.deathDoor:Penalty(actor)==10)
    assert(morale.Current(actor)==maximum-math.ceil(maximum*.4),'Survival must heavily reduce actual morale')
    before=rngCalls;hit(0);assert(rngCalls==before and #checks==1,'Zero damage rerolled death')
    assert(actor:Heal(3)>0 and not state.Entered(actor) and state.Used(actor),'Healing must leave death door without refreshing protection')
    hit(actor.HP);assert(#checks==2 and state.Survived(actor)==2 and actor.HP==0,'Repeat lethal hit after healing avoided its check')
    hit(1,true);assert(#checks==3 and state.Survived(actor)==3,'Damage over time must check at zero HP')
    assert(checks[3].impact.deathChance>checks[1].impact.deathChance,'Lower morale did not raise risk')
    local request=require('Game.Presentation.DiceChecks').FromBattleEvent(checks[1]);assert(request.dice[1].kind=='D20' and request.dice[1].value==20)
    battle:BeginTurn(0)
    assert(actor.HP==0 and state.Alive(actor) and (actor.Q~=0 or actor.R~=0) and battle.data.ActiveId==enemy.Id,'Zero-HP panic failed to move and yield its turn')
    local survived=state.Survived(actor);local checksBeforeRestart=#checks
    battle:ClearBattleEffects();battle.data:Clear()
    local save=require('Game.Adventure.CharacterSave');local saved,why=save.Write(adventure);assert(saved,why)
    local prepared=adventure.characterSaves:Prepare(adventure.data.Equipment);save.Validate(adventure,prepared)
    local restored=prepared:GetActorAt(0);assert(restored.HP==0 and state.Alive(restored) and state.Survived(restored)==survived)
    restored:Restore();assert(restored.HP>0 and state.Survived(restored)==0,'Rest did not clear a survivor weakness')
    actor:Restore();assert(actor.HP>0 and state.Survived(actor)==0);begin()
    hit(actor.HP);assert(entered==2 and #checks==checksBeforeRestart,'New battle must restore the first-hit protection')
    maximum=morale.Maximum(actor);morale.Set(actor,maximum,maximum,1);raw=0;hit(1)
    assert(#checks==checksBeforeRestart+1 and checks[#checks].impact.roll==1 and not checks[#checks].impact.passed and state.Dead(actor) and not state.Alive(actor) and defeated==1)
    assert(actor:Heal(100)==0);actor:Restore();assert(actor.HP==0 and state.Dead(actor),'Permanent death was resurrected')
    assert(battle:CheckWinner() and battle.data.Winner=='defeat','Dead party did not end combat')
    assert(save.Write(adventure));prepared=adventure.characterSaves:Prepare(adventure.data.Equipment);save.Validate(adventure,prepared)
    restored=prepared:GetActorAt(0);assert(state.Dead(restored));restored:Restore();assert(restored.HP==0)
    CheckDeathDoorLegacy(adventure.characterSaves,adventure.data.Equipment)
    unsubscribe()
    return 'PASS native systems: first lethal protection, zero-HP actions/occupancy/AI targeting, D20 single draw, morale pressure, healing/re-entry, DOT, rest, permanent death, current-save round trip and v38 migration'
end,debug.traceback)
registry:Shutdown();if not ok then error(result,0)end
return result
