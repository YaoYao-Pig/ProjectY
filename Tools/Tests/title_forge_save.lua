-- Real exported configuration and save services; the host supplies a unique temporary directory.
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
    local adventure=registry:Get('Adventure');adventure:Start(20261101,3,2500)
    local data,stats=adventure.data,adventure.battle.stats
    local state,rep=CS.ProjectY.Data.TitleState,CS.ProjectY.Data.ReputationState
    local save=require('Game.Adventure.CharacterSave')
    local service,bag=adventure.characterSaves,data.Equipment
    local actor=data:GetPartyAt(0)
    -- A pre-forge baseline preserves an existing configured title and its historical counters.
    state.Award(actor,1);state.Increment(actor,'kill:0');state.Increment(actor,'kill:0')
    assert(adventure.titles:Equip(actor.Id,1))
    local saved,reason=save.Write(adventure);assert(saved,reason)
    PrepareTitleForgeFixture(service,bag,'baseline')
    local legacy=PrepareTitleForgeFixture(service,bag,'legacy44');save.Validate(adventure,legacy)
    local old=legacy:GetActorAt(0)
    assert(PreparedTitleForgeBalance(legacy)==0 and state.Owns(old,1) and state.Equipped(old)==1
        and state.Counter(old,'kill:0')==2 and state.CustomCount(old)==0,'v44 migration changed titles, counters, or reputation')
    assert(adventure.titles:Equip(actor.Id,0))

    local attributes=adventure.config:GetTable('GrowthAttributeTable'):All()
    assert(#attributes==20,'The integration fixture must cover all 20 registered attributes')
    local ranks,bonuses,base={},{},{}
    for _,effect in ipairs(adventure.config:GetTable('TitleForgeEffectTable'):All())do
        if effect.kind=='attribute' and not effect.negative then
            assert(not bonuses[effect.attribute],'Duplicate positive attribute option')
            ranks[effect.id]=1;bonuses[effect.attribute]=effect.amount
        end
    end
    for _,attribute in ipairs(attributes)do
        assert(bonuses[attribute.code],'Missing title option: '..attribute.code)
        base[attribute.code]=stats:Get(actor,attribute.code)
    end
    -- Attribute deltas are compared while healthy; body HP loss independently changes injury penalties.
    local baselineMaximum=actor.MaxHP
    local missing=actor.MaxHP-actor.HP
    assert(missing==0,'All-attribute comparison requires a healthy starting actor')
    local missionReward=adventure.titles:Complete('mission',100)
    assert(missionReward==stats.titles.forge.policy.missionReward and missionReward>0)
    assert(adventure.titles:Complete('mission',100)==0,'Repeated mission paid reputation')
    -- Fixture funding uses the real shared currency boundary; combat attribution has separate checks.
    assert(rep.AwardKill(data,890001,10000))
    local before=rep.Balance(data)
    local quote=adventure.titles:Quote('全属性验证',ranks);assert(quote.valid,quote.reason)
    local crafted,why,id=adventure.titles:Craft(actor.Id,'全属性验证',ranks);assert(crafted,why)
    assert(id<0 and state.CustomCost(actor,id)==quote.cost and rep.Balance(data)==before-quote.cost)
    assert(adventure.titles:Equip(actor.Id,id))
    local function verifyAll(subject,expected,message)
        for _,attribute in ipairs(attributes)do
            local name=attribute.code
            assert(stats:Get(subject,name)==expected[name],message..': '..name)
        end
    end
    local boosted={};for name,value in pairs(base)do boosted[name]=value+bonuses[name]end
    verifyAll(actor,boosted,'Custom title attribute mismatch')
    assert(actor.MaxHP==stats:MaximumHP(actor) and actor.MaxHP>baselineMaximum
        and actor.MaxHP-actor.HP==missing,'Title HP synchronization changed existing damage')
    local spentBalance=rep.Balance(data)
    assert(adventure.titles:Equip(actor.Id,1))
    local configured={};for name,value in pairs(base)do configured[name]=value end
    local definition=stats.titles.definitions:Get(1)
    for i,attributeId in ipairs(definition.attributeIds)do
        local name=stats.titles.attributes:Get(attributeId).code
        configured[name]=configured[name]+definition.attributeValues[i]
    end
    verifyAll(actor,configured,'Single-slot replacement stacked bonuses')
    assert(adventure.titles:Equip(actor.Id,0));verifyAll(actor,base,'Unequip kept attribute bonuses')
    assert(actor.MaxHP==baselineMaximum and actor.MaxHP-actor.HP==missing and rep.Balance(data)==spentBalance
        and state.Owns(actor,id),'Unequip refunded reputation or removed a permanent title')
    -- Separately verify HP preservation with real damage, without comparing uninjured attribute values.
    actor:Damage(5);local damagedMissing=actor.MaxHP-actor.HP
    assert(damagedMissing==5 and adventure.titles:Equip(actor.Id,id))
    assert(actor.MaxHP==stats:MaximumHP(actor) and actor.MaxHP>baselineMaximum
        and actor.MaxHP-actor.HP==damagedMissing,'Equipping title changed the existing HP deficit')
    assert(adventure.titles:Equip(actor.Id,0))
    assert(actor.MaxHP==baselineMaximum and actor.MaxHP-actor.HP==damagedMissing,'Unequipping title changed the existing HP deficit')
    actor:Heal(actor.MaxHP);assert(actor.HP==actor.MaxHP)
    assert(adventure.titles:Equip(actor.Id,id))
    verifyAll(actor,boosted,'Healthy title effects after damage recovery')

    saved,reason=save.Write(adventure);assert(saved,reason)
    assert(CheckTitleForgeSaveVersion(service)==46,'Full expedition must save as v46')
    local prepared=service:Prepare(bag);save.Validate(adventure,prepared)
    local candidate=prepared:GetActorAt(0)
    assert(PreparedTitleForgeBalance(prepared)==spentBalance and state.Equipped(candidate)==id
        and state.CustomCost(candidate,id)==quote.cost and state.EffectCount(candidate,id)==20)
    verifyAll(candidate,boosted,'Prepared title lost attribute effects')
    -- Both native schema rejection and configuration rejection leave the running session intact.
    for _,mode in ipairs({'missingReputation','unknownEffect'})do
        local accepted=pcall(function()
            local malformed=PrepareTitleForgeFixture(service,bag,mode)
            save.Validate(adventure,malformed)
        end)
        assert(not accepted and data:GetPartyAt(0)==actor and state.Equipped(actor)==id
            and rep.Balance(data)==spentBalance,'Invalid candidate mutated live state: '..mode)
    end
    -- Change live state before Apply so a no-op restoration cannot pass.
    assert(adventure.titles:Equip(actor.Id,0));actor:Damage(3);assert(rep.AwardKill(data,890002,7))
    service:Apply(prepared,data,adventure.player)
    actor=data:GetPartyAt(0)
    assert(rep.Balance(data)==spentBalance and state.Equipped(actor)==id and state.CustomCount(actor)==1
        and state.CustomName(actor,id)=='全属性验证' and state.CustomCost(actor,id)==quote.cost,'Apply lost balance or custom identity')
    verifyAll(actor,boosted,'Apply lost attribute effects')
    assert(actor.MaxHP==stats:MaximumHP(actor) and actor.MaxHP-actor.HP==missing,'Apply lost title HP or existing damage')
    assert(not rep.AwardSettlement(data,'mission',100,missionReward)
        and not state.RecordSettlement(actor,'mission',100) and rep.Balance(data)==spentBalance,'Apply lost permanent settlement receipts')
    return 'PASS real save integration: all 20 attributes, HP synchronization, single-slot replacement, permanent cost, v44 migration, v46 catalog, Prepare/Validate/Apply, shared balance, receipts, and invalid-candidate isolation'
end,debug.traceback)
registry:Shutdown();if not ok then error(result)end
return result
