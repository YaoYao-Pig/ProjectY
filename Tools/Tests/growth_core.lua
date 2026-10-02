package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local f=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local bytes=f:read('*a');f:close();return bytes
end}})
local rules=require('Game.Progression.GrowthRules').New(config)
local count=0
local function test(name,run) run();count=count+1;print('PASS '..name) end
local function actor(ranks,treeIds)
    local growth={Level=10,TalentPoints=20,SkillCount=0,TalentCount=0}
    function growth:HasTree(id) return treeIds[id]==true end
    function growth:GetRank(id) return ranks[id] or 0 end
    function growth:GetAttribute() return 0 end
    function growth:NextRandom() return .35 end
    return {Growth=growth,TemplateId=1,TraitCount=0}
end
test('adjacency can expand from either endpoint; locks and ranks remain enforced',function()
    local a=actor({[1]=1,[4]=1},{[1]=true})
    assert(rules:CanInvest(a,2));assert(not rules:CanInvest(a,9));assert(not rules:CanInvest(a,101))
    a.Growth.TalentPoints=0;assert(not rules:CanInvest(a,1))
end)
test('directed convergence requires every prerequisite, not a single branch',function()
    local ranks={[101]=1,[102]=1};local a=actor(ranks,{[2]=true})
    assert(not rules:CanInvest(a,104));ranks[103]=1;assert(rules:CanInvest(a,104))
    ranks[104]=1;assert(not rules:CanInvest(a,104))
end)
test('real pool draw excludes learned/current skills, respects attribute tier gates and deduplicates',function()
    local a=actor({},{});local values={}
    local stats={Get=function(_,_,name) return values[name] or 0 end,Template=function() return {} end,
        equipment={SkillIds=function() return {101,103} end}}
    local ids=rules:Draw(a,stats);assert(#ids>=1 and #ids<=3)
    local seen={};for _,id in ipairs(ids) do assert(id~=101 and id~=103 and not seen[id]);seen[id]=true end
    for _,id in ipairs(ids) do assert(id~=102 and id~=104 and id~=106 and id~=108,'High tier leaked below threshold') end
    stats.equipment.SkillIds=function() local all={};for _,skill in ipairs(rules.skills:All()) do all[#all+1]=skill.id end;return all end
    assert(#rules:Draw(a,stats)==0)
end)
test('talent config rejects disconnected graphs and directed cycles before gameplay',function()
    local override={}
    for _,edge in ipairs(rules.edges:All()) do override[#override+1]=edge end
    override[#override+1]={id=99,fromId=104,toId=102}
    local bad={GetTable=function(_,name) if name=='TalentEdgeTable' then return {All=function() return override end} end return config:GetTable(name) end}
    assert(not pcall(function() require('Game.Progression.GrowthRules').New(bad) end))
end)
test('story templates substitute named values and reject unknown tokens',function()
    local format=require('Game.Progression.Chronicle').Format
    assert(format('{actor}在{location}：{detail}',{actor='艾岚',location='营地',detail='休整'})=='艾岚在营地：休整')
    assert(not pcall(function() format('{missing}',{}) end))
end)
print('Growth core: '..count..' checks passed')
