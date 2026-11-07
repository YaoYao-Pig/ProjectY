package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local Rules=require('Game.Progression.EnemyProfessions')
local rules=Rules.New(config)
local Birth=require('Game.Progression.CharacterBirth');local birth=Birth.New(config)
local count=0
local function test(name,run)run();count=count+1;print('PASS '..name)end
local function actor(id,template)
    local result={Id=id,TemplateId=template or 4,Team=2,HasInitialAttributes=false,InitialAttributesAssigned=false,
        InitialProfessionId=0,AnimalSpeciesId=0,Growth={Initialized=false,SkillCount=0},professionAttributes={}}
    function result:HasProfessionAttributes(id)return self.professionAttributes[id]~=nil end
    return result
end
CS={ProjectY={Data={CharacterBirthState={
    Initialize=function(unit,profession,names,values)
        assert(not unit.InitialAttributesAssigned);unit.InitialAttributesAssigned=true;unit.HasInitialAttributes=true
        unit.InitialProfessionId=profession;unit.attributes={}
        for i,name in ipairs(names)do unit.attributes[name]=values[i]end
    end,
    UseTemplate=function(unit)assert(not unit.InitialAttributesAssigned);unit.InitialAttributesAssigned=true end,
    AssignProfession=function(unit,id,names,values)
        assert(not unit:HasProfessionAttributes(id));unit.professionAttributes[id]={}
        for i,name in ipairs(names)do unit.professionAttributes[id][name]=values[i]end
    end,
}}}}
local function known(ids,id)for _,value in ipairs(ids)do if value==id then return true end end;return false end
test('ordinary humanoids receive every configured career deterministically without shared RNG or initialized growth',function()
    local seen={};local oldRandom=math.random;math.random=function()error('Shared RNG used')end
    for id=50001,52048 do
        local a,b=actor(id),actor(id)
        birth:InitializeEnemy(a,72810);birth:InitializeEnemy(b,72810)
        assert(a.InitialProfessionId==b.InitialProfessionId and not a.Growth.Initialized)
        seen[a.InitialProfessionId]=true
        local profession=a.InitialProfessionId;local attributes=a.attributes
        birth:InitializeEnemy(a,1)
        assert(a.InitialProfessionId==profession and a.attributes==attributes,'Existing birth must never reroll')
    end
    math.random=oldRandom
    for _,profession in ipairs(config:GetTable('ProfessionTable'):All())do assert(seen[profession.id],'Unreachable profession '..profession.id)end
end)
test('authored NPC actors, named legends and nonhumans preserve birth and template skills',function()
    for _,entry in ipairs({{10301,910},{10302,920},{81001,910},{81002,920},{80001,705},{80002,706},{80003,201},{80004,402}})do
        local unit=actor(entry[1],entry[2]);assert(not rules:Eligible(unit))
        birth:InitializeEnemy(unit,456)
        assert(unit.InitialProfessionId==(config:GetTable('CombatUnitTable'):Get(unit.TemplateId).bodyInjuries and 12 or 0))
        local template=config:GetTable('CombatUnitTable'):Get(unit.TemplateId)
        assert(rules:SkillIds(unit,template)==template.skillIds)
        local items,slots={51},{'head'}
        local main,off,worn,places=rules:Loadout(unit,40,0,items,slots)
        assert(main==40 and off==0 and worn==items and places==slots)
    end
end)
test('shared NPC templates remain eligible and shields require actual equipment support',function()
    assert(rules:Eligible(actor(80008,3)) and rules:Eligible(actor(80009,6)))
    assert(not rules:Supports(rules.weapons:Get(40),rules.skills:Get(1901)))
end)
test('each career gets compatible ordinary equipment and available skills without player-only resource actions',function()
    local unit=actor(80005);unit.HasInitialAttributes=true
    local template=config:GetTable('CombatUnitTable'):Get(4)
    for _,profession in ipairs(config:GetTable('ProfessionTable'):All())do
        unit.InitialProfessionId=profession.id
        local main,off,items,slots=rules:Loadout(unit,40,0,{51,57},{'head','offhand'})
        local weapon=config:GetTable('EquipmentWeaponTable'):Get(main)
        assert(not config:GetTable('LegendaryEquipmentTable'):Find(main))
        if weapon.hands==2 then assert(off==0 and #slots==1 and slots[1]=='head')end
        local attacks=0
        for _,id in ipairs(weapon.skillIds)do
            local skill=rules.skills:Get(id)
            if skill.target=='enemy' and skill.ammoPerShot==0 then attacks=attacks+1 end
        end
        assert(attacks>0,'Career needs a real weapon attack: '..profession.id)
        local skills=rules:SkillIds(unit,template);assert(known(skills,4))
        for _,id in ipairs(skills)do if id~=4 then
            assert(rules:Supports(weapon,rules.skills:Get(id)),'Weapon/course mismatch: '..profession.id..'/'..id)
            local rule=rules.combat:Find(id);assert(not rule or rule.materialId==0)
            assert(not config:GetTable('ConstructionTable'):Find(id) and rules.skills:Get(id).skillGroup~='animal')
        end end
        if profession.id==3 then assert(weapon.catalystKind=='arcane' and known(skills,103))end
        if profession.id==14 then assert(weapon.catalystKind=='arcane' and weapon.kind=='melee' and known(skills,101) and known(skills,103))end
        if profession.id==15 then assert(weapon.kind=='melee' and known(skills,2601))end
    end
end)
test('old class spell and attack templates are replaced while player skills remain unchanged',function()
    local unit=actor(80006,3);unit.HasInitialAttributes=true;unit.InitialProfessionId=1
    local template=config:GetTable('CombatUnitTable'):Get(3)
    local skills=rules:SkillIds(unit,template)
    assert(not known(skills,3) and not known(skills,5) and known(skills,101) and known(skills,4))
    unit.Team=1;assert(rules:SkillIds(unit,template)==template.skillIds)
end)
test('enemy initial equipment grants the selected profession plan once',function()
    local unit=actor(80007);unit.HasInitialAttributes=true;unit.InitialProfessionId=3
    local writes=0;local state=CS.ProjectY.Data
    state.EquipmentCombatState={IsInitialized=function()return writes>0 end,Initialize=function(_,id,main,off,items,slots)
        writes=writes+1;assert(id==unit.Id and rules.weapons:Get(main).catalystKind=='arcane' and off==0)
        assert(#items==2 and slots[1]=='head' and slots[2]=='body')
    end}
    local loadout=require('Game.Equipment.InitialLoadout').New(config,{enemyProfessions=rules})
    loadout:ApplyEnemy({},unit);loadout:ApplyEnemy({},unit);assert(writes==1)
end)
for _,path in ipairs({'Lua/Game/Progression/EnemyProfessions.lua','Lua/Game/Progression/CharacterBirth.lua',
    'Lua/Game/Equipment/InitialLoadout.lua','Lua/Game/MapArea/MapAreaSystem.lua','Lua/Game/Adventure/WorldFactions.lua',
    'Lua/Game/Adventure/ProfessionDuels.lua'})do assert(loadfile(path))end
print('Enemy professions: '..count..' checks passed')
