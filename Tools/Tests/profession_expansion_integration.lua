-- Isolated Edit Mode integration: real FrameworkServices, generated tables, C# actors and production commands.
-- Fixture resources are supplied through public Data APIs; no gameplay result or combat service is mocked.
local registry=require('Core.SystemRegistry')(Services)
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('Battle',require('Game.Battle.BattleSystem'),{'Config'})
registry:Register('Equipment',require('Game.Equipment.EquipmentSystem'),{'Config'})
registry:Register('Growth',require('Game.Progression.GrowthSystem'),{'Battle'})
-- Equipment's real OnEquip curse hook needs an Adventure context, but no world simulation participates here.
-- Supply only that context; the actual ProfessionExploration implementation and C# NarrativeData remain in use.
local System=require('Core.LuaSystem')
local FixtureAdventure=require('Core.Class')('ProfessionIntegrationAdventure',System)
function FixtureAdventure:OnInit(context)
    System.OnInit(self,context)
    self.config=context.systems:Get('Config');self.data=context.services.Adventure
    self.battle=context.systems:Get('Battle');self.equipment=context.systems:Get('Equipment');self.growth=context.systems:Get('Growth')
    self.characterAppearances=require('Game.Adventure.CharacterAppearance').New(self.config,context.services.Appearances)
    self.professionExploration=require('Game.Adventure.ProfessionExploration').New(self)
end
registry:Register('Adventure',FixtureAdventure,{'Config','Battle','Equipment','Growth'})
local reports,assets={},{}
local function test(name,run) run();reports[#reports+1]='PASS '..name end
local function contains(rows,id)for _,value in ipairs(rows)do if value==id then return true end end;return false end
local function accepted(ok,reason)assert(ok,reason)end
local ok,err=xpcall(function()
    registry:Start()
    local config,battle,equipment,growth,adventure=registry:Get('Config'),registry:Get('Battle'),registry:Get('Equipment'),registry:Get('Growth'),registry:Get('Adventure')
    local data=Services.Adventure;data:Reset(20261025)
    local actor=data:AddPartyActor(1,1)
    adventure.characterAppearances:Party(actor,20261025)
    growth:PrepareActor(actor);growth:AddExperience(actor,100000,'Integration arena')
    -- Enough real fixture points/opportunities to inspect every course without altering campaign progression rules.
    for _,attribute in ipairs({'strength','speed','intellect','charisma','animalAffinity','bow'})do actor.Growth:InvestAttribute(attribute,1,20)end
    for _=1,40 do actor.Growth:AddLearningOpportunity(actor.Growth.Level)end
    actor:SetMaxHP(battle.stats:MaximumHP(actor));actor:Restore()
    equipment.data.Grid:Configure(12,12)
    local learned={}
    test('all six professions expose learnable real courses and retained talent trees',function()
        for profession=6,11 do
            local definition=config:GetTable('ProfessionTable'):Get(profession)
            local first=1801+(profession-6)*10
            local pending=actor.Growth.PendingCount
            accepted(growth:ChangeProfession(actor.Id,profession))
            assert(actor.Growth.CurrentProfessionId==profession and actor.Growth:HasTree(profession))
            assert(actor.Growth.PendingCount==pending and not actor.Growth:HasSkill(first),'Changing profession must not grant a free preparation')
            for _,offset in ipairs({0,1,2,3,5})do
                local id=first+offset;local before=actor.Growth.PendingCount
                accepted(growth:Learn(actor.Id,id))
                assert(actor.Growth:HasSkill(id) and actor.Growth.PendingCount==before-1)
                learned[#learned+1]=id
            end
            accepted(growth:InvestTalent(actor.Id,first+4))
            assert(actor.Growth:GetRank(first+4)==1)
            for _,id in ipairs(learned)do assert(actor.Growth:HasSkill(id),'Cross-profession learning erased '..id)end
            assert(#definition.initialSkillIds==1 and definition.initialSkillIds[1]==first)
        end
        accepted(growth:Learn(actor.Id,201))
        accepted(growth:ChangeProfession(actor.Id,3));accepted(growth:Learn(actor.Id,1906))
        for _,id in ipairs({1861,1862,1863,1864})do assert(contains(battle:SkillIds(actor),id),'Learned skill did not expose option '..id)end
        assert(not actor.Growth:HasSkill(1861),'Options should not consume a separate course')
    end)
    local instances={}
    test('twelve real weapons equip across professions and resolve their actual skill and catalyst contracts',function()
        for id=8001,8012 do
            accepted(equipment:Grant(id,1))
            local weapon
            for index=0,equipment.data.WeaponCount-1 do local candidate=equipment.data:GetWeaponAt(index);if candidate.ItemId==id then weapon=candidate;break end end
            instances[id]=assert(weapon)
            accepted(equipment:Command('equip',actor.Id,weapon.Id,0,0))
            assert(equipment.data:Equipped(actor.Id)==weapon and weapon.OwnerActorId==actor.Id)
            local definition=equipment.rules.weapons:Get(id)
            for _,skillId in ipairs(definition.skillIds)do assert(contains(battle:SkillIds(actor),skillId),'Equipped weapon lost its own attack '..id)end
            local spell=battle:Skill(actor,1832)
            local available,_,catalyst=equipment.rules:CheckSkillEquipment(actor,spell,battle.stats)
            if definition.catalystKind=='arcane' then assert(available and catalyst==weapon,'Native catalyst was not selected: '..id)
            else assert(not available,'Non-catalyst weapon unexpectedly casts: '..id)end
            local visual=equipment.rules:WeaponVisual(weapon)
            local item=equipment.rules.items:Get(id);local asset=equipment.rules.assets:Get(item.assetId)
            assert(visual.asset.id==item.assetId and visual.asset.path==asset.prefabPath)
            assert(#visual.primaryGrip.position==3 and #visual.secondaryGrip.position==3)
            assets[#assets+1]={id=id,assetId=item.assetId,modelPath=asset.modelPath,prefabPath=asset.prefabPath,iconPath=item.iconPath}
        end
        assert(actor.Effects:Find(12020),'Blood covenant weapon must produce its real persistent curse')
        accepted(equipment:Command('equip',actor.Id,instances[8005].Id,0,0))
    end)
    test('new static C# bridges are callable from the real xLua environment',function()
        local state=CS.ProjectY.Data.ProfessionCombatState
        state.SetMark(actor,'integration_probe',17);assert(state.Mark(actor,'integration_probe')==17)
        assert(state.Once(actor,'integration_once',1) and not state.Once(actor,'integration_once',1));state.Clear(actor)
        assert(state.Mark(actor,'integration_probe')==0)
        assert(CS.ProjectY.Data.AnimalCompanionState.Bound(actor)==nil)
        assert(not CS.ProjectY.Data.ProfessionDuelState.Active(data))
        assert(CS.ProjectY.Data.ProfessionDuelState.Limit(data,actor,7)==7)
    end)
    battle.board=require('Game.Battle.BattleBoard').Create(4,20261025,0)
    battle.data:Reset(1,18);battle.data:AddUnit(actor,1,0,0)
    local enemy=battle.data:AddEnemy(501,4,1,0);enemy:SetMaxHP(250);enemy:Restore()
    assert(loadfile('Tools/Tests/combat_phase_fixture.lua'))()(battle)
    assert(battle:Active().Id==actor.Id)
    data:BeginEvent(1,1);data:ResolveChoice(1);data:BeginBattle()
    test('missing potion rejects the real battle transaction without spending AP, inventory, cooldown or RNG',function()
        assert(equipment.data:CountItem(8013)==0)
        local ap,main,moved,sequence,revision=actor.AP,actor.MainUsed,actor.Moved,actor.ActionSequence,equipment.data.Revision
        battle.data:SetRandomSeed(197)
        local reference=CS.ProjectY.Data.BattleData();reference:SetRandomSeed(197)
        local used,reason=battle:TrySkill(1802,enemy.Id)
        assert(not used and type(reason)=='string' and reason~='')
        assert(actor.AP==ap and actor.MainUsed==main and actor.Moved==moved and actor.ActionSequence==sequence)
        assert(equipment.data.Revision==revision and actor:GetCooldown(1802)==0 and not enemy.Effects:Find(12019))
        assert(battle.data:RollPercent()==reference:RollPercent(),'Failed precheck advanced combat RNG')
    end)
    test('potion to lightning uses real material consumption, shared wet state, damage and main action budget',function()
        accepted(equipment:Grant(8013,1))
        local ap,hp=actor.AP,enemy.HP
        battle.data:SetRandomSeed(1) -- Real deterministic hit roll; not a replacement RNG function.
        accepted(battle:TrySkill(1802,enemy.Id))
        assert(actor.AP==ap-1 and not actor.MainUsed and equipment.data:CountItem(8013)==0)
        assert(enemy.HP==hp and enemy.Effects:Find(12019),'Water must establish its shared state without direct damage')
        battle.data:SetRandomSeed(1)
        accepted(battle:TrySkill(1906,enemy.Id))
        assert(actor.AP==ap-3 and actor.MainUsed and enemy.HP<hp)
        assert(not enemy.Effects:Find(12019),'Conduction failed to consume wet on hit')
        assert(actor:GetCooldown(1802)==2 and actor:GetCooldown(1906)==2)
    end)
    test('new public trap state uses actual rope and resets with the encounter',function()
        assert(config:GetTable('ProfessionCombatTable'):Get(1907).materialId==82)
        assert(config:GetTable('ProfessionCombatTable'):Get(1903).materialId==82)
        local state=CS.ProjectY.Data.ProfessionCombatState
        state.PlaceTrap(battle.data,2,0,actor.Id,20016)
        local rows=battle.professions:TrapRows();assert(#rows==1 and rows[1].q==2 and rows[1].sourceId==actor.Id)
        state.RemoveTrap(battle.data,2,0);assert(state.TrapCount(battle.data)==0)
        battle.data:Clear()
    end)
end,debug.traceback)
registry:Shutdown()
if not ok then error(err,0)end
return table.concat(reports,'\n'),assets
