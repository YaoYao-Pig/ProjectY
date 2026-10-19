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
        assert(#profession.initialSkillIds==1 and profession.initialSkillIds[1]==400+profession.id)
        assert(professions.byProfession[profession.id][400+profession.id])
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
print('Profession core: '..count..' checks passed')
