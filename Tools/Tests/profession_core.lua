package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local bytes=file:read('*a');file:close();return bytes
end}})
local rules=require('Game.Progression.GrowthRules').New(config)
local learned,available={},{}
local growth={Initialized=true,CurrentProfessionId=1,Level=1,PendingCount=1,TalentPoints=2,Revision=0,OfferCount=0}
function growth:HasSkill(id) return learned[id]==true end
function growth:HasTree(id) return id==3 end
function growth:GetRank() return 0 end
local actor={Growth=growth};local values={}
local stats={growth=rules,Template=function()return {skillIds={}} end,Get=function(_,_,name)return values[name] or 0 end,
    equipment={SkillIds=function()local ids={};for id in pairs(available)do ids[#ids+1]=id end;return ids end}}
local professions=rules.professions
local count=0
local function test(name,run) run();count=count+1;print('PASS '..name) end
test('profession catalog includes every initial preparation exactly once',function()
    for _,profession in ipairs(professions.professions:All()) do
        local seen={}
        for _,id in ipairs(profession.initialSkillIds) do
            assert(not seen[id] and professions.byProfession[profession.id][id])
            assert(rules.skills:Get(id).skillKind=='preparation')
            seen[id]=true
        end
        assert(#profession.initialSkillIds==(profession.baseProfession and 0 or 1))
    end
    assert(rules.profileByUnit[1].initialProfessionId==1 and rules.profileByUnit[2].initialProfessionId==2 and rules.profileByUnit[3].initialProfessionId==3)
end)
test('normal learning selects eligible courses directly without random offers',function()
    assert(professions:CanLearn(actor,101,stats,rules.atlas))
    assert(not professions:CanLearn(actor,103,stats,rules.atlas))
    growth.CurrentProfessionId=3;assert(professions:CanLearn(actor,103,stats,rules.atlas))
    growth.PendingCount=0;assert(not professions:CanLearn(actor,103,stats,rules.atlas))
    growth.PendingCount=1;learned[103]=true;assert(not professions:CanLearn(actor,103,stats,rules.atlas));learned[103]=nil
end)
test('level and attribute thresholds reject just-below values and accept the boundary',function()
    values.intellect=8;assert(not professions:CanLearn(actor,104,stats,rules.atlas))
    growth.Level=2;values.intellect=7;assert(not professions:CanLearn(actor,104,stats,rules.atlas))
    values.intellect=8;assert(professions:CanLearn(actor,104,stats,rules.atlas))
end)
test('profession courses share real atlas prerequisites and cannot teach item actions',function()
    growth.CurrentProfessionId=4;values.crafting=12
    assert(not professions:CanLearn(actor,304,stats,rules.atlas))
    available[303]=true;assert(professions:CanLearn(actor,304,stats,rules.atlas))
    assert(not professions:CanLearn(actor,701,stats,rules.atlas) and not professions.bySkill[701] and not professions.bySkill[702])
end)
test('arcane armament specialization has a real learnable level-two passive node',function()
    growth.Level=1;assert(not rules:CanInvest(actor,301))
    growth.Level=2;assert(rules:CanInvest(actor,301))
    local node=rules.nodes:Get(301);assert(node.treeId==3 and node.pointCost==1 and rules.passives:Get(node.passiveId).attributeNames[1]=='intellect')
end)
test('empty courses and legacy refresh calls preserve learning opportunities without RNG',function()
    local system=require('Game.Progression.GrowthSystem')()
    system:PrepareOffers(actor)
    assert(growth.PendingCount==1 and growth.Revision==0 and growth.OfferCount==0)
end)
test('arcane knight reuses two partial catalogs with their existing learning thresholds',function()
    local profession=professions.professions:Get(14)
    assert(not profession.baseProfession and #profession.treeIds==2 and profession.treeIds[1]==1 and profession.treeIds[2]==3)
    assert(#profession.initialSkillIds==1 and profession.initialSkillIds[1]==403)
    local expected={[101]=5,[102]=5,[501]=5,[103]=3,[403]=3,[1905]=3,[1906]=3}
    local own={[2531]=true,[2532]=true,[2533]=true}
    local size=0
    for id,course in pairs(professions.byProfession[14]) do
        if expected[id] then
            local source=assert(professions.byProfession[expected[id]][id])
            assert(course.minLevel==source.minLevel and #course.attributeNames==#source.attributeNames)
            for i,name in ipairs(source.attributeNames) do
                assert(course.attributeNames[i]==name and course.attributeValues[i]==source.attributeValues[i])
            end
        else
            assert(own[id] and course.attributeNames[1]=='intellect','Arcane knight adds only its authored spellblade progression')
        end
        size=size+1
    end
    assert(size==10 and not professions.byProfession[14][104] and not professions.byProfession[14][1910])
    growth.CurrentProfessionId=14;growth.Level=2;values.intellect=4
    assert(not professions:CanLearn(actor,1905,stats,rules.atlas))
    growth.Level=3;values.intellect=3
    assert(not professions:CanLearn(actor,1905,stats,rules.atlas))
    values.intellect=4;assert(professions:CanLearn(actor,1905,stats,rules.atlas))
    values.strength=7;assert(not professions:CanLearn(actor,102,stats,rules.atlas))
    values.strength=8;assert(professions:CanLearn(actor,102,stats,rules.atlas))
end)
test('joining arcane knight preserves skills and opportunities; learning uses the shared identity',function()
    local owned,joined,trees={}, {[5]=true}, {[1]=true}
    local state={CurrentProfessionId=5,Level=3,PendingCount=2}
    function state:HasSkill(id)return owned[id]==true end
    function state:HasProfession(id)return joined[id]==true end
    function state:JoinProfession(id)joined[id]=true;self.CurrentProfessionId=id end
    function state:UnlockTree(id)trees[id]=true end
    function state:LearnSelected(id)assert(self.PendingCount>0 and not owned[id]);owned[id]=true;self.PendingCount=self.PendingCount-1 end
    local unit={Id=1,Growth=state,SetMaxHP=function()end}
    local system=require('Game.Progression.GrowthSystem')()
    system.rules=rules
    system.data={Phase='map',Seed=1,PartyCount=1,GetPartyAt=function()return unit end}
    system.stats={growth=rules,Get=function()return 8 end,Template=function()return {skillIds={}} end,
        equipment={SkillIds=function()local ids={};for id in pairs(owned)do ids[#ids+1]=id end;return ids end},
        birth={EnsureProfession=function()end},MaximumHP=function()return 100 end}
    system.chronicle={Record=function()end}
    assert(system:Learn(1,101));assert(state.PendingCount==1 and owned[101])
    assert(system:ChangeProfession(1,14))
    assert(joined[14] and trees[3] and owned[101] and not owned[403] and state.PendingCount==1)
    assert(not system:Learn(1,101) and state.PendingCount==1)
    assert(system:Learn(1,1905) and state.PendingCount==0 and owned[1905])
    assert(system:ChangeProfession(1,3))
    assert(owned[101] and owned[1905] and state.PendingCount==0)
    assert(not system:Learn(1,1905) and state.PendingCount==0)
end)
print('Profession core: '..count..' checks passed')
