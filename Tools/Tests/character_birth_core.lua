package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local Birth=require('Game.Progression.CharacterBirth')
local birth=Birth.New(config)
local count=0
local function test(name,run) run();count=count+1;print('PASS '..name) end
local function actor(id,template)
    local result={Id=id,TemplateId=template or 1,InitialAttributesAssigned=false,HasInitialAttributes=false,
        InitialProfessionId=0,InitialAttributeCount=0,names={},values={},writes=0,
        ProfessionAttributeSetCount=0,professionIds={},professionValues={},professionNames={},professionWrites=0,
        Growth={Initialized=false,CurrentProfessionId=0,ProfessionCount=0,professions={},
            GetProfessionAt=function(self,index)return self.professions[index+1]end}}
    function result:GetInitialAttributeNameAt(index) return self.names[index+1] end
    function result:GetInitialAttribute(name) return self.values[name] or 0 end
    function result:HasProfessionAttributes(id) return self.professionValues[id]~=nil end
    function result:GetProfessionAttribute(id,name) return assert(self.professionValues[id])[name] or 0 end
    function result:GetProfessionAttributeProfessionAt(index) return self.professionIds[index+1] end
    function result:GetProfessionAttributeCount(id) return #assert(self.professionNames[id]) end
    function result:GetProfessionAttributeNameAt(id,index) return self.professionNames[id][index+1] end
    function result:Deploy(team,q,r) self.Team,self.Q,self.R=team,q,r end
    function result:SetMaxHP(value) self.MaxHP=value end
    function result:Restore() self.HP=self.MaxHP end
    return result
end
local function joined(unit,...)
    unit.Growth.professions={...};unit.Growth.ProfessionCount=#unit.Growth.professions
end
CS={ProjectY={Data={CharacterBirthState={
    Initialize=function(unit,profession,names,values)
        assert(not unit.InitialAttributesAssigned)
        unit.writes=unit.writes+1;unit.InitialAttributesAssigned=true;unit.HasInitialAttributes=true
        unit.InitialProfessionId=profession;unit.InitialAttributeCount=#names
        for i,name in ipairs(names) do unit.names[i]=name;unit.values[name]=values[i] end
    end,
    UseTemplate=function(unit) assert(not unit.InitialAttributesAssigned);unit.InitialAttributesAssigned=true;unit.writes=unit.writes+1 end,
    AssignProfession=function(unit,id,names,values)
        assert(not unit:HasProfessionAttributes(id))
        unit.professionWrites=unit.professionWrites+1;unit.professionIds[#unit.professionIds+1]=id
        unit.ProfessionAttributeSetCount=#unit.professionIds
        unit.professionNames[id]={};unit.professionValues[id]={}
        for i,name in ipairs(names) do unit.professionNames[id][i]=name;unit.professionValues[id][name]=values[i] end
    end,
}}}}
local function same(a,b)
    for _,name in ipairs(birth.names) do if a:GetInitialAttribute(name)~=b:GetInitialAttribute(name) then return false end end
    return true
end
test('all configured humanoid templates roll exactly once; nonhuman templates retain their base values',function()
    local humans,others=0,0
    for _,row in ipairs(config:GetTable('CombatUnitTable'):All()) do
        local unit=actor(100000+row.id,row.id)
        birth:Initialize(unit,68403)
        assert(unit.InitialAttributesAssigned and unit.HasInitialAttributes==row.bodyInjuries)
        if row.bodyInjuries then humans=humans+1;assert(unit.InitialProfessionId==12)
        else others=others+1;assert(unit.InitialProfessionId==0 and unit.InitialAttributeCount==0) end
        birth:Validate(unit);birth:Initialize(unit,123)
        assert(unit.writes==1 and not unit.Growth.Initialized)
    end
    assert(humans>0 and others>0)
end)
test('same seed and identity reproduce; different identities and creation seeds vary without shared RNG',function()
    local a,b,c,d=actor(10031),actor(10031),actor(10032),actor(10031)
    local random=math.random;math.random=function()error('Birth consumed global RNG')end
    birth:Initialize(a,9123);birth:Initialize(b,9123);birth:Initialize(c,9123);birth:Initialize(d,34213)
    math.random=random
    assert(same(a,b) and not same(a,c) and not same(a,d))
    local snapshot=actor(a.Id);birth:Initialize(snapshot,9123)
    a.Growth.CurrentProfessionId=3
    birth:Initialize(a,982739)
    assert(same(a,snapshot) and a.InitialProfessionId==12 and a.writes==1)
    assert(not pcall(function()birth:Initialize(a,9123,13)end))
    birth:Initialize(a,9123,12);assert(a.writes==1)
end)
test('all professions share base ranges; configured profession bonuses and secondary variations remain bounded',function()
    local primary={vitality=true,endurance=true,intellect=true,strength=true,speed=true,defense=true}
    local base=birth.templates[1];local missing
    for _,name in ipairs(birth.names) do if not primary[name] and not base[name] then missing=name;break end end
    assert(missing,'Fixture must include an unspecified secondary attribute')
    for _,profession in ipairs({12,13,1}) do
        local seen={}
        for id=1,1024 do
            local unit=actor(id);birth:Initialize(unit,95123,profession)
            for _,name in ipairs(birth.names) do
                local value=unit:GetInitialAttribute(name)
                local minimum,maximum=2,6
                if not primary[name] then minimum,maximum=math.max(0,(base[name] or 0)-1),(base[name] or 0)+1 end
                assert(value>=minimum and value<=maximum and value==math.floor(value),name)
                seen[name..':'..value]=true
                local bonus=unit:GetProfessionAttribute(profession,name)
                assert(bonus>=0 and bonus<=2)
                seen['bonus:'..name..':'..bonus]=true
            end
        end
        assert(seen[missing..':0'] and seen[missing..':1'])
        assert(not seen['strength:8'] and not seen['speed:8'])
        if profession==12 then assert(seen['bonus:strength:0'] and seen['bonus:strength:2'] and not seen['bonus:speed:2']) end
        if profession==13 then assert(seen['bonus:speed:0'] and seen['bonus:speed:2'] and not seen['bonus:strength:2']) end
    end
end)
test('fixed and random modifiers apply to any configured profession and attribute and never reroll',function()
    local modified={GetTable=function(_,name)
        if name=='ProfessionAttributeTable' then return {All=function()return {
            {id=1,professionId=1,attributeId=5,fixedBonus=3,randomMin=1,randomMax=2},
            {id=2,professionId=3,attributeId=15,fixedBonus=2,randomMin=0,randomMax=0},
        }end} end
        return config:GetTable(name)
    end}
    local rules=Birth.New(modified);local unit,copy=actor(537),actor(537)
    rules:Initialize(unit,945,1);rules:Initialize(copy,945,3)
    assert(same(unit,copy),'Profession must not change the base roll')
    local speed=unit:GetProfessionAttribute(1,'speed');assert(speed>=4 and speed<=5)
    rules:EnsureProfession(unit,945,3);assert(unit:GetProfessionAttribute(3,'scouting')==2)
    rules:EnsureProfession(unit,1,1);rules:EnsureProfession(unit,2,3)
    assert(unit:GetProfessionAttribute(1,'speed')==speed and unit.professionWrites==2)
    rules:EnsureProfession(unit,945,2);assert(unit:GetProfessionAttributeCount(2)==0)
    rules:EnsureProfession(unit,1,2);assert(unit.professionWrites==3)
    joined(unit,1,2,3)
    rules:Validate(unit)
    birth:Validate(unit);birth:EnsureProfession(unit,1982,1)
    assert(unit:GetProfessionAttribute(1,'speed')==speed,'Removed configuration must not alter historical rolls')
    local historical=actor(538);birth:Initialize(historical,945,1)
    rules:EnsureProfession(historical,0,1);rules:Validate(historical)
    assert(historical:GetProfessionAttributeCount(1)==0,'New configuration must not reroll an existing empty record')
end)
test('saved history remains valid after range adjustments; corrupt or incomplete attribute records fail',function()
    local unit=actor(382);birth:Initialize(unit,0,13)
    unit.values.speed=37 -- A historical range need not match the current generation range.
    birth:Validate(unit)
    unit.values.speed=-1;assert(not pcall(function()birth:Validate(unit)end));unit.values.speed=37
    unit.InitialProfessionId=999999;assert(not pcall(function()birth:Validate(unit)end));unit.InitialProfessionId=13
    unit.InitialAttributeCount=unit.InitialAttributeCount-1;assert(not pcall(function()birth:Validate(unit)end))
    unit.InitialAttributeCount=#unit.names
    local first=unit.names[1];unit.names[1]='unknownBirthAttribute';assert(not pcall(function()birth:Validate(unit)end));unit.names[1]=first
    unit.professionValues[13].speed=99;birth:Validate(unit)
    unit.professionValues[13].speed=-1;assert(not pcall(function()birth:Validate(unit)end));unit.professionValues[13].speed=99
    unit.professionNames[13][1]='unknownProfessionAttribute';assert(not pcall(function()birth:Validate(unit)end));unit.professionNames[13][1]='speed'
    joined(unit,3);assert(not pcall(function()birth:Validate(unit)end))
    birth:EnsureProfession(unit,0,3);birth:Validate(unit)
    local legacy=actor(472);CS.ProjectY.Data.CharacterBirthState.UseTemplate(legacy)
    joined(legacy,1);CS.ProjectY.Data.CharacterBirthState.AssignProfession(legacy,1,{},{})
    birth:Validate(legacy);birth:Initialize(legacy,100,13)
    assert(legacy.writes==1 and not legacy.HasInitialAttributes)
    assert(not pcall(function()birth:Validate(actor(744))end))
    for _,row in ipairs(birth.units:All()) do if not row.bodyInjuries then
        local mount=actor(745,row.id);birth:Validate(mount)
        assert(not mount.InitialAttributesAssigned and mount.writes==0)
        break
    end end
end)
test('saved profession bonuses must belong to an initial or joined profession',function()
    local unit=actor(384);birth:Initialize(unit,0,12)
    birth:Validate(unit) -- Encounter actors have an initial profession without initialized growth.
    birth:EnsureProfession(unit,0,3)
    assert(not pcall(function()birth:Validate(unit)end),'Unjoined profession bonus record must be rejected')
    joined(unit,3);birth:Validate(unit)
    local legacy=actor(473);CS.ProjectY.Data.CharacterBirthState.UseTemplate(legacy)
    CS.ProjectY.Data.CharacterBirthState.AssignProfession(legacy,1,{},{})
    assert(not pcall(function()birth:Validate(legacy)end),'Legacy template actors cannot pre-store unjoined bonuses')
    joined(legacy,1);birth:Validate(legacy)
end)
test('CombatStats applies only the current saved profession while retaining growth, equipment and legacy semantics',function()
    local unit=actor(678);birth:Initialize(unit,100)
    unit.TraitCount=1;unit.GetTraitAt=function()return 5 end;unit.Effects={Count=0}
    local stats={attributes={[1]={strength=25}},traits={Get=function()return {attribute='strength',amount=2}end},
        growth={Bonus=function()return 3 end},equipment={AttributeBonus=function()return 4 end},
        injuries={ApplyAttribute=function(_,_,_,value)return value end}}
    local Get=require('Game.Battle.CombatStats').Get
    local bonus=unit:GetProfessionAttribute(12,'strength')
    assert(Get(stats,unit,'strength')==unit:GetInitialAttribute('strength')+bonus+9)
    assert(Get(stats,unit,'strength',true)==unit:GetInitialAttribute('strength')+bonus+5)
    unit.Growth.CurrentProfessionId=3
    assert(not pcall(Get,stats,unit,'strength'),'Missing current profession snapshot must fail')
    birth:EnsureProfession(unit,100,3)
    assert(Get(stats,unit,'strength')==unit:GetInitialAttribute('strength')+9)
    unit.Growth.CurrentProfessionId=12
    assert(Get(stats,unit,'strength')==unit:GetInitialAttribute('strength')+bonus+9)
    unit.HasInitialAttributes=false;unit.InitialProfessionId=0;unit.Growth.CurrentProfessionId=3
    assert(Get(stats,unit,'strength')==34 and Get(stats,unit,'strength',true)==30)
    unit.InitialProfessionId=nil;unit.HasInitialAttributes=nil;unit.Growth.CurrentProfessionId=1
    assert(Get(stats,unit,'strength')==34,'Older Lua fixtures retain template semantics')
end)
test('world rosters initialize birth before equipment and health without initializing recruit growth',function()
    local template=1
    local appearance={Group=function()return {}end,Assign=function()end}
    local equipment={InitializeEnemy=function(_,unit) assert(unit.HasInitialAttributes and not unit.Growth.Initialized) end}
    local stats={birth=birth,animals={IsStaticBody=function()return false end},MaximumHP=function(_,unit)
        assert(unit.HasInitialAttributes);return unit:GetInitialAttribute('vitality')*10
    end}
    local adventure={data={Seed=123},characterAppearances=appearance,equipment=equipment,
        battle={stats=stats,encounters={Get=function()return {appearancePoolId=1,enemyIds={template,template}}end}}}
    local party={Id=53,MemberCount=0,members={}}
    function party:AddMember(id)
        local unit=actor(self.Id*100+self.MemberCount+1,id)
        self.MemberCount=self.MemberCount+1;self.members[#self.members+1]=unit;return unit
    end
    local prepare=require('Game.Adventure.WorldFactions').PrepareRoster
    prepare({adventure=adventure},party,1)
    assert(party.MemberCount==2)
    for _,unit in ipairs(party.members) do assert(unit.HP==unit:GetInitialAttribute('vitality')*10 and unit.writes==1) end
    prepare({adventure=adventure},party,1);assert(party.MemberCount==2)
end)
test('event encounter actors receive birth attributes before equipment but remain eligible for later recruitment',function()
    local encounter={appearancePoolId=1,enemyIds={1}}
    local actorId=10122;local member
    local group={AddEnemy=function(_,id,template)member=actor(id,template);return member end}
    local state={SiteId=432,AddEncounter=function()return group end,CompleteEncounterInitialization=function(self)self.EncountersInitialized=true end}
    local stats={birth=birth,animals={byUnit={},IsStaticBody=function()return false end},MaximumHP=function(_,unit)
        assert(unit.HasInitialAttributes and not unit.Growth.Initialized);return unit:GetInitialAttribute('vitality')*10
    end}
    local equipment={InitializeEnemy=function(_,unit)assert(unit.HasInitialAttributes and not unit.Growth.Initialized)end}
    local area={config={GetTable=function()return {Get=function()return encounter end}end},
        encounterRules={Find=function()return {encounterId=1}end},adventure={Seed=123},combatStats=stats,
        context={systems={Get=function()return equipment end}},
        characterAppearances={Group=function()return {}end,Party=function()end}}
    local layout={configId=1,seed=412,encounterPlans={{id=1,encounterId=1,actorIds={actorId},cells={{q=0,r=0}}}}}
    local initialize=require('Game.MapArea.MapAreaSystem').InitializeEncounters
    initialize(area,layout,state)
    assert(member.Id==actorId and member.HasInitialAttributes and not member.Growth.Initialized and member.HP==member.MaxHP)
    initialize(area,layout,state);assert(member.writes==1)
end)
for _,path in ipairs({'Lua/Game/Progression/CharacterBirth.lua','Lua/Game/Battle/CombatStats.lua','Lua/Game/Battle/BattleSystem.lua',
    'Lua/Game/MapArea/MapAreaSystem.lua','Lua/Game/Adventure/WorldFactions.lua','Lua/Game/Adventure/ProfessionDuels.lua',
    'Lua/Game/Adventure/CharacterSave.lua','Lua/Game/Adventure/ExpeditionSave.lua'}) do assert(loadfile(path)) end
print('Character birth core: '..count..' checks passed')
