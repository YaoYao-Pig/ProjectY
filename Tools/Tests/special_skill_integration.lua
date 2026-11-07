-- Requires fresh FrameworkServices supplied by the idle-Editor host. No world, scene or save is created.
-- Native JSON roundtrip coverage belongs to special_skill_integration_editmode.cs.
local registry=require('Core.SystemRegistry')(assert(Services,'Fresh FrameworkServices are required'))
for _,spec in ipairs({{'Config','Config.ConfigSystem'},
    {'Battle','Game.Battle.BattleSystem',{'Config'}},{'Growth','Game.Progression.GrowthSystem',{'Battle'}}})do
    registry:Register(spec[1],require(spec[2]),spec[3])
end
local messages={}
local function test(name,run)run();messages[#messages+1]='PASS '..name end
local function contains(values,id)for _,value in ipairs(values)do if value==id then return true end end;return false end
local model
local ok,err=xpcall(function()
    registry:Start()
    local config,battle,growth=registry:Get('Config'),registry:Get('Battle'),registry:Get('Growth')
    local data=Services.Adventure;assert(data.PartyCount==0,'Integration requires isolated fresh services')
    data:Reset(8642)
    local stats=battle.stats
    local function add(id,template)
        local actor=data:AddPartyActor(id,template)
        growth:PrepareActor(actor)
        actor:SetMaxHP(stats:MaximumHP(actor));actor:Restore()
        return actor
    end
    local teacher=add(1,705)
    local npc=add(10202,config:GetTable('NpcTable'):Get(202).actorTemplateId)
    local learner=add(2,1)
    local successor=add(3,1)
    local adventure={config=config,battle=battle,growth=growth,data=data,sites={}}
    model=require('Game.Progression.SpecialSkills').New(adventure);model:Start()
    local bridge=CS.ProjectY.Data.SpecialSkillBattleState
    local language=require('Language')
    local rng=CS.ProjectY.Data.CharacterGrowthData()
    rng:Initialize((data.Seed+learner.Id*104729)%4294967296,0,0,0)
    local function meet(actor,id)
        local row=stats.specialSkills.bySkill[id]
        for i,name in ipairs(row.attributeNames)do
            local missing=row.attributeValues[i]-stats:Get(actor,name,true)
            if missing>0 then actor.Growth:InvestAttribute(name,1,missing)end
        end
        assert(stats.specialSkills:Requirements(actor,id,stats))
    end
    local function deploy()
        -- Directly prepare native combat participants; no enemy creation, world generation or game turn is required.
        data.Battle:Reset(201,20)
        for i=0,data.PartyCount-1 do data.Battle:AddUnit(data:GetPartyAt(i),1,i,0)end
        data.Battle:BeginDeployment();data.Battle:BeginRound()
        battle.Changed:Emit({kind='battle_started'})
    end
    test('real template and NPC holder skills enter equipment skill aggregation',function()
        assert(teacher.TemplateId==705 and npc.TemplateId==902)
        assert(stats.specialSkills:IsOriginal(teacher,2701) and not teacher.Growth:HasSkill(2701))
        assert(stats.specialSkills:IsOriginal(npc,2702) and not npc.Growth:HasSkill(2702))
        assert(contains(stats.equipment:SkillIds(teacher,stats:Template(teacher)),2701))
        assert(contains(stats.equipment:SkillIds(npc,stats:Template(npc)),2702))
        assert(not stats.specialSkills:IsOriginal(learner,2701))
        assert(CS.ProjectY.Data.PartyRoster.Find(data,learner.Id)==learner)
    end)
    test('native bond and attribute requirements gate teaching without consuming course opportunities',function()
        local allowed,reason=model:CanTeach(teacher,learner,2701)
        assert(not allowed and reason==string.format(language.SpecialSkillRelationshipRequired,60))
        data.PartyBonds:BeginBattle()
        for i=0,data.PartyCount-1 do data.PartyBonds:AddParticipant(data:GetPartyAt(i))end
        assert(data.PartyBonds:SettleBattle(true,100))
        assert(data.PartyBonds:Score(teacher.Id,learner.Id)==100)
        meet(learner,2701)
        local pending=learner.Growth.PendingCount;local journal=data.JournalCount
        assert(model:Teach(teacher.Id,learner.Id,2701))
        assert(learner.Growth:HasSkill(2701) and learner.Growth.PendingCount==pending)
        assert(not model:Teach(teacher.Id,learner.Id,2701) and data.JournalCount==journal+1)
        local entry=data:GetJournalAt(journal)
        assert(entry.SubjectId==learner.Id and entry.ObjectId==teacher.Id and entry.ParticipantCount==2)
        allowed,reason=model:CanTeach(learner,successor,2701)
        assert(not allowed and reason==language.SpecialSkillCannotReteach and not successor.Growth:HasSkill(2701))
    end)
    test('configured retransmission grants a learned special skill to another real actor',function()
        meet(learner,2702);meet(successor,2702)
        local pendingLearner,pendingSuccessor=learner.Growth.PendingCount,successor.Growth.PendingCount
        assert(model:Teach(npc.Id,learner.Id,2702))
        assert(not stats.specialSkills:IsOriginal(learner,2702) and model:CanTeach(learner,successor,2702))
        assert(model:Teach(learner.Id,successor.Id,2702))
        assert(successor.Growth:HasSkill(2702) and not stats.specialSkills:IsOriginal(successor,2702))
        assert(learner.Growth.PendingCount==pendingLearner and successor.Growth.PendingCount==pendingSuccessor)
        assert(learner.Growth:NextRandom()==rng:NextRandom(),'Teaching must not consume the growth random stream')
    end)
    test('real skill detail resolves special acquisition and disables ordinary course learning',function()
        local detail=require('UI.GrowthSkillDetailModel').New(config):Build(learner,stats,'map',2701)
        assert(detail.sourceKind=='special' and detail.learned and detail.owned and not detail.canLearn)
        assert(detail.sourceText==language.SpecialSkillOwned and not detail.attributeIncludesEquipment)
        assert(detail.body:find(language.SpecialSkillSource,1,true))
        assert(detail.body:find(language.SpecialSkillOriginalOnly,1,true))
        assert(detail.body:find(language.SpecialSkillObserveBasis,1,true))
        assert(detail.buttonText==language.UICharacterGrowthInvestTextText4)
        assert(#detail.courseRoutes==0)
    end)
    test('native observation authority keeps the highest chance and consumes only once',function()
        deploy();assert(bridge.IsParticipant(data,learner))
        assert(not bridge.IsParticipant(data,CS.ProjectY.Data.CombatActorData(learner.Id,learner.TemplateId)))
        bridge.Observe(data,learner,2703,.2,'first source')
        bridge.Observe(data,learner,2703,.8,'best source')
        bridge.Observe(data,learner,2703,.4,'later source')
        assert(bridge.Consume(data) and not bridge.Consume(data))
        assert(not bridge.IsParticipant(data,learner))
        local observations=bridge.Observations(data)
        assert(observations.Length==1)
        local row=observations[0]
        assert(row.Learner==learner and row.SkillId==2703 and row.Chance==.8 and row.SourceName=='best source')
        assert(not model:Settle('victory','Native test location') and not learner.Growth:HasSkill(2703))
    end)
    test('real settlement learns once and advances the native RNG exactly once',function()
        deploy();local pending=learner.Growth.PendingCount;local journal=data.JournalCount
        bridge.Observe(data,learner,2703,.5,'lower source')
        bridge.Observe(data,learner,2703,1,'guaranteed source')
        assert(model:Settle('victory','Native test location'))
        assert(learner.Growth:HasSkill(2703) and learner.Growth.PendingCount==pending and data.JournalCount==journal+1)
        assert(data:GetJournalAt(journal).Body:find('guaranteed source',1,true))
        rng:NextRandom() -- The single authoritative learning roll consumed by Settle.
        assert(learner.Growth:NextRandom()==rng:NextRandom())
        assert(not model:Settle('victory','Native test location') and data.JournalCount==journal+1)
        assert(learner.Growth:NextRandom()==rng:NextRandom(),'Duplicate settlement must not draw again')
        deploy();bridge.Observe(data,learner,2703,1,'already known source')
        assert(model:Settle('draw','Native test location') and data.JournalCount==journal+1)
        assert(learner.Growth:NextRandom()==rng:NextRandom(),'Known skills must not draw again')
    end)
    test('surviving real participants may learn after defeat and draw',function()
        for _,entry in ipairs({{actor=successor,result='defeat'},{actor=teacher,result='draw'}})do
            deploy();local pending=entry.actor.Growth.PendingCount
            assert(not stats.specialSkills:Owns(entry.actor,2703))
            bridge.Observe(data,entry.actor,2703,1,'survived observation')
            assert(model:Settle(entry.result,'Native test location'))
            assert(entry.actor.Growth:HasSkill(2703) and entry.actor.Growth.PendingCount==pending)
            assert(not model:Settle(entry.result,'Native test location'))
        end
    end)
end,debug.traceback)
if model then model:Dispose()end
registry:Shutdown()
if not ok then error(err,0)end
return table.concat(messages,'\n')
