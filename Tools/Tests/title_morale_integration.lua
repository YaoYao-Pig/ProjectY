-- Real exported tables, systems and C# state in an isolated Editor LuaEnv.
-- Fixture preparation sets progress immediately before boundaries; gameplay hooks perform the final event.
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
    registry:Start()
    local adventure=registry:Get('Adventure');adventure:Start(20261031,3,2500)
    local battle,stats,story=adventure.battle,adventure.battle.stats,registry:Get('Narrative')
    local state,morale=CS.ProjectY.Data.TitleState,CS.ProjectY.Data.MoraleState
    local actor=adventure.data:GetPartyAt(0);local other=adventure.data:GetPartyAt(1)
    assert(stats.titles.definitions.Count==10 and #stats.titles:Rows(actor,adventure.data.PartyBonds)==10,'Ten configured titles must be visible')
    local courage=stats:Get(actor,'courage');assert(courage>=40 and stats.morale:Maximum(actor)==50+courage)
    for i=1,9 do state.Increment(actor,'kill:0')end
    battle:Start(1,{actor},923)
    while battle.data.Phase=='deployment' do battle:EndTurn()end
    assert(morale.Active(actor) and morale.Current(actor)==math.floor(morale.Maximum(actor)*.75))
    local target;for _,unit in ipairs(battle:Units())do if battle:IsHostile(actor,unit)then target=unit;break end end
    local effect;for _,row in ipairs(battle.effects:All())do if row.kind=='damage' and row.duration=='instant' and row.recipient=='target'then effect=row;break end end
    assert(effect and target)
    battle.gameEffects:Execute(effect,target,target.HP,actor.Id,stats:Template(actor).name,effect.name,actor,false,{},false)
    assert(target.HP==0 and state.Counter(actor,'kill:0')==10 and state.Owns(actor,1),'Actual lethal damage must award the killer')
    battle:Emit('defeated','duplicate fixture',actor.Id,target.Id,0,target)
    assert(state.Counter(actor,'kill:0')==10 and state.Counter(other,'kill:0')==0,'Repeated death or non-killer received credit')
    battle:ClearBattleEffects();battle.data:Clear()
    local strength=stats:Get(actor,'strength');assert(adventure.titles:Equip(actor.Id,1));assert(stats:Get(actor,'strength')==strength+1)
    local attack=battle:Skill(actor,battle:SkillIds(actor)[1]);assert(adventure.titles:Equip(actor.Id,0))
    local baseAttack=battle:Skill(actor,attack.id);assert(math.abs(attack.damageScale-baseAttack.damageScale*1.05)<.000001,'Title damage multiplier not applied')
    -- A configured legendary death awards both generic and identity-specific titles to its killer.
    battle.data:Reset(1,20);battle.data:AddUnit(actor,1,0,0)
    local legend=battle.data:AddEnemy(92001,701,1,0);stats.birth:Initialize(legend,772);legend:SetMaxHP(stats:MaximumHP(legend));legend:Restore()
    battle.data:BeginDeployment();battle.data:BeginRound();state.BeginBattle(actor)
    legend:Damage(legend.HP);battle:Emit('defeated','legend fixture',actor.Id,legend.Id,0,legend)
    assert(state.Owns(actor,3) and state.Owns(actor,4) and not state.Owns(other,3),'Legend identity attribution failed')
    battle.data:Clear();assert(not morale.Active(actor))
    -- Real mission claim hook; both current party members receive it once.
    if story.data:Status('mission',100)=='inactive' then story.data:Begin('mission',100)end
    story.data:Ready('mission',100)
    local before=state.Counter(actor,'mission:0')
    local claimed,why=story:Claim('mission',100);assert(claimed,why)
    assert(state.Counter(actor,'mission:0')==before+1 and state.Counter(other,'mission:100')==1)
    assert(state.Owns(actor,6) and state.Owns(other,6) and not story:Claim('mission',100))
    assert(state.Counter(actor,'mission:0')==before+1,'Repeat claim changed title progress')
    -- Remaining unlock boundaries use attributed completion records, independent of reward preview.
    for id=93001,93019 do adventure.titles:Complete('town',id,1)end
    assert(state.Owns(actor,7) and state.Owns(actor,8) and state.Owns(actor,9),'Mission/town cumulative titles failed')
    local total=state.Counter(actor,'mission:0');adventure.titles:Complete('town',93019,1);assert(state.Counter(actor,'mission:0')==total)
    for i=11,50 do state.Increment(actor,'kill:0')end
    state.Increment(actor,'legend:15');state.Increment(actor,'legend:0')
    local bonds=adventure.data.PartyBonds
    for i=1,3 do bonds:BeginBattle();bonds:AddParticipant(actor);bonds:AddParticipant(other);assert(bonds:TryRescue(actor.Id,other.Id,25))end
    adventure.titles:Evaluate(actor);assert(state.Count(actor)==10,'All ten title requirements must be reachable')
    local originalMaximum=actor.MaxHP;actor:Damage(5);local missing=actor.MaxHP-actor.HP;local endurance=stats:Get(actor,'endurance')
    assert(adventure.titles:Equip(actor.Id,9) and stats:Get(actor,'endurance')==endurance+2 and actor.MaxHP-actor.HP==missing,'Attribute title must preserve existing damage')
    assert(adventure.titles:Equip(actor.Id,0) and stats:Get(actor,'endurance')==endurance and actor.MaxHP==originalMaximum and actor.MaxHP-actor.HP==missing,'Removing title must preserve existing damage')
    local defense=stats:Get(actor,'defense');assert(adventure.titles:Equip(actor.Id,10))
    assert(stats:Get(actor,'defense')==defense+2 and stats:Get(actor,'courage')==courage+3)
    assert(stats.morale:Maximum(actor)==50+courage+3+10,'Courage and direct morale capacity must both apply')
    assert(adventure.titles:Equip(actor.Id,3));assert(stats:Get(actor,'defense')==defense and stats:Get(actor,'courage')==courage+2,'Old title bonuses stacked')
    -- Actual save services: owned titles, counters, current slot and current max HP round trip.
    local save=require('Game.Adventure.CharacterSave');local saved,reason=save.Write(adventure);assert(saved,reason)
    local prepared=adventure.characterSaves:Prepare(adventure.data.Equipment);save.Validate(adventure,prepared)
    local restored=prepared:GetActorAt(0)
    assert(state.Count(restored)==10 and state.Equipped(restored)==3 and state.Counter(restored,'mission:0')==total)
    assert(not state.RecordSettlement(restored,'town',93019),'Save lost settlement receipts')
    local legacy=CheckLegacyTitleSave(adventure.characterSaves,adventure.data.Equipment)
    save.Validate(adventure,legacy)
    for i=0,legacy.ActorCount-1 do
        local old=legacy:GetActorAt(i);assert(old.InitialAttributeCount==19 and stats:Get(old,'courage')==40,'Old birth values must not be rerolled for courage')
    end
    return 'PASS real config + C# + systems: ten titles reachable, lethal damage attribution, legend identities, mission claim/duplicate rejection, task recipient scope, slot replacement, courage/max morale and temporary-save round trip + v36 migration'
end,debug.traceback)
registry:Shutdown();if not ok then error(result)end
return result
