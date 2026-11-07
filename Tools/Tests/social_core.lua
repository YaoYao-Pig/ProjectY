package.path='Lua/?.lua;'..package.path
local config
if SocialSource then
    config={GetTable=function(_,name)
        local rows=assert(SocialSource[name],name)
        return {All=function()return rows end,Get=function(_,id)for _,row in ipairs(rows)do if row.id==id then return row end end;error('Missing test row')end}
    end}
else
    config=require('Config.ConfigSystem')()
    config:OnInit({services={ReadConfig=function(_,name)local f=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local bytes=f:read('*a');f:close();return bytes end}})
end
local rules=require('Game.Progression.PartyStoryRules').New(config)
local checks=0
local function test(name,fn)fn();checks=checks+1;print('PASS '..name)end
local a={Id=1,Team=1,MaxHP=100,HasTrait=function()return false end}
local b={Id=2,Team=1,MaxHP=100,HasTrait=function()return false end}
local function heal(before,after,periodic)return {kind='heal',hpBefore=before,hpAfter=after,amount=after-before,periodic=periodic==true}end
test('all five relationship boundaries including negative scores',function()
    for _,case in ipairs({{-100,'仇恨'},{-61,'仇恨'},{-60,'厌恶'},{-21,'厌恶'},{-20,'一般'},{0,'一般'},{29,'一般'},{30,'友好'},{59,'友好'},{60,'挚友'},{100,'挚友'}})do
        assert(rules:Stage(case[1]).name==case[2])
    end
    assert(not pcall(function()rules:Stage(-101)end));assert(not pcall(function()rules:Stage(101)end))
end)
test('ordinary care, critical rescue and death-door rescue are mutually exclusive',function()
    local kind,amount=rules:Help(heal(50,70),'combat',a,b,20,0);assert(kind=='heal' and amount==3)
    kind,amount=rules:Help(heal(25,40),'combat',a,b,15,0);assert(kind=='rescue' and amount==12)
    kind,amount=rules:Help(heal(0,1),'combat',a,b,1,0);assert(kind=='rescue' and amount==20)
end)
test('deployment, periodic, self, zero and trivial healing grant nothing',function()
    assert(not rules:Help(heal(20,40),'deployment',a,b,20,0))
    assert(not rules:Help(heal(20,40,true),'combat',a,b,20,0))
    assert(not rules:Help(heal(20,40),'combat',a,a,20,0))
    assert(not rules:Help(heal(100,100),'combat',a,b,0,0))
    assert(not rules:Help(heal(20,21),'combat',a,b,1,0))
    b.Team=2;assert(not rules:Help(heal(20,40),'combat',a,b,20,0));b.Team=1
end)
test('friendly-damage provenance cannot manufacture rescue credit',function()
    assert(not rules:Help(heal(0,20),'combat',a,b,0,20))
    local kind=rules:Help(heal(10,50),'combat',a,b,20,20);assert(kind=='heal')
end)
test('reserved personalities respond less to ordinary care, not lifesaving care',function()
    b.HasTrait=function(_,id)return id==6 end
    local kind,amount=rules:Help(heal(50,70),'combat',a,b,20,0);assert(kind=='heal' and amount==2)
    kind,amount=rules:Help(heal(20,40),'combat',a,b,20,0);assert(kind=='rescue' and amount==12)
    b.HasTrait=function()return false end
end)
test('harm follows actual damage and respects zero-HP death-door impact',function()
    assert(not rules:Harm({amount=0,hpAfter=50},b))
    local amount,grudge=rules:Harm({amount=2,hpAfter=98},b);assert(amount==-2 and grudge==1)
    amount=rules:Harm({amount=1,hpAfter=0,impact={incomingDamage=30}},b);assert(amount==-18)
    amount=rules:Harm({amount=0,hpAfter=0,impact={incomingDamage=10}},b);assert(amount==-18)
end)
test('all player text keys exist and modules parse',function()
    local L=require('Language')
    for _,file in ipairs({'Lua/Game/Progression/PartyStory.lua','Lua/UI/Panel/CharacterGrowthCtr.lua','Lua/Game/Adventure/DemoBridge.lua','Lua/Game/Battle/GameEffects.lua'})do
        assert(loadfile(file))
        local f=assert(io.open(file));local text=f:read('*a');f:close()
        for key in text:gmatch('%.(Relationship[%w_]+)')do
            assert(type(L[key])=='string','Missing '..key)
            assert(config:GetTable('LuaTxt'):Get(key).txt==L[key],'Stale localization override: '..key)
        end
    end
    assert(string.format(L.RelationshipEvent,'test',-2):find('-2',1,true))
end)
print('Social core: '..checks..' checks passed')
