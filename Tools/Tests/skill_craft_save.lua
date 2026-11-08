local registry=require('Core.SystemRegistry')(Services)
for _,spec in ipairs({{'Config','Config.ConfigSystem'},{'Condition','Game.Condition.ConditionSystem',{'Config'}},
    {'PlayerModel','Game.PlayerModelSystem',{'Config'}},{'Map','Game.Map.MapSystem',{'Config'}},{'MapArea','Game.MapArea.MapAreaSystem',{'Config'}},
    {'Battle','Game.Battle.BattleSystem',{'Config'}},{'Equipment','Game.Equipment.EquipmentSystem',{'Config'}},{'Growth','Game.Progression.GrowthSystem',{'Battle'}},
    {'AdventureEvents','Game.Adventure.EventSystem',{'Battle','PlayerModel','Growth','Equipment'}},
    {'Adventure','Game.Adventure.AdventureSystem',{'Map','MapArea','AdventureEvents','Equipment'}},
    {'Narrative','Game.Narrative.NarrativeSystem',{'Adventure','Condition'}}})do registry:Register(spec[1],require(spec[2]),spec[3])end
local ok,result=xpcall(function()
    registry:Start();local adventure=registry:Get('Adventure');adventure:Start(20261108,3,2500)
    local data,stats=adventure.data,adventure.battle.stats;local actor=data:GetPartyAt(0)
    for _,p in ipairs({1,3})do if actor.Growth.CurrentProfessionId~=p then assert(adventure.growth:ChangeProfession(actor.Id,p))end end
    for _,id in ipairs({103,2401})do actor.Growth:GrantSkill(id)end
    local state=CS.ProjectY.Data.SkillCraftState;state.Practice(actor,{1,3},200000,stats.skillCraft.maximum)
    local success,reason,id=stats.skillCraft:Save(actor,'map',{name='存档自创技',bodyId=103,bodyProfessionId=3,modifierIds={1},modifierProfessionIds={1}})
    assert(success,reason)
    -- An initialized independent world actor exercises the nested GrowthSave migration.
    local worldActor
    for i=0,adventure.parties.data.Count-1 do local party=adventure.parties.data:GetAt(i)
        for j=0,party.MemberCount-1 do local member=party:GetMemberAt(j)
            if not worldActor and member.Id~=actor.Id and stats.growth.profileByUnit[member.TemplateId] then worldActor=member end
        end
    end
    assert(worldActor,'Fixture needs an independent world member')
    if not worldActor.Growth.Initialized then adventure.growth:PrepareActor(worldActor)end
    worldActor:SetMaxHP(stats:MaximumHP(worldActor));worldActor:Restore()
    local save=require('Game.Adventure.CharacterSave');local service,bag=adventure.characterSaves,data.Equipment
    success,reason=save.Write(adventure);assert(success,reason)
    local prepared=service:Prepare(bag);save.Validate(adventure,prepared)
    local restored=prepared:GetActorAt(0)
    assert(state.Count(restored)==1 and state.Points(restored,1)==100000 and state.Find(restored,id).name=='存档自创技')
    assert(stats.skillCraft:Compile(restored,stats.skillCraft:Recipe(restored,id)))
    local legacy=PrepareCraftLegacy(service,bag)
    save.Validate(adventure,legacy)
    assert(state.Count(legacy:GetActorAt(0))==0 and state.Points(legacy:GetActorAt(0),1)==0)
    local parties=CS.ProjectY.Data.WorldPartiesData.Prepared(legacy);local nested
    for i=0,parties.Count-1 do local party=parties:GetAt(i)
        for j=0,party.MemberCount-1 do local member=party:GetMemberAt(j);if member.Id==worldActor.Id then nested=member end end
    end
    assert(nested and nested.Growth.Initialized and state.Count(nested)==0 and state.Points(nested,nested.Growth.CurrentProfessionId)==0)
    return 'PASS v52 full save, current catalog, crafted skill eligibility after restore, v50 party and initialized world-member migration; one isolated 2500-cell world'
end,debug.traceback)
registry:Shutdown();if not ok then error(result,0)end
return result
