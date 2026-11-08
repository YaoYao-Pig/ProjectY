package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local bytes=file:read('*a');file:close();return bytes
end}})
local Rules=require('Game.Progression.SkillCraft')
local professions=require('Game.Progression.ProfessionRules').New(config)
local rules=Rules.New(config,professions)
local learned,joined,points={},{},{}
local actor={Growth={}}
function actor.Growth:HasSkill(id)return learned[id]==true end
function actor.Growth:HasProfession(id)return joined[id]==true end
CS={ProjectY={Data={SkillCraftState={Points=function(_,id)return points[id]or 0 end}}}}
local count=0
local function test(name,run)run();count=count+1;print('PASS '..name)end
local function unlock(skill)
    learned[skill]=true
    local p=assert(professions.bySkill[skill])[1].professionId;joined[p]=true;points[p]=rules.maximum;return p
end
local function recipe(body,mods)
    local r={bodyId=body,bodyProfessionId=unlock(body),name='Test',modifierIds=mods,modifierProfessionIds={}}
    for i,id in ipairs(mods)do r.modifierProfessionIds[i]=unlock(rules.modifiers:Get(id).skillId)end
    return r
end
test('ten is not mastery, eleven is; learned skills never imply mastery',function()
    local p=unlock(101);points[p]=rules.maximum-1;assert(rules:Progress(actor,p)==10 and #rules:Origins(actor,101,true)==0)
    points[p]=rules.maximum;assert(rules:Progress(actor,p)==11 and #rules:Origins(actor,101,true)==1)
    learned[101]=nil;assert(#rules:Origins(actor,101,true)==0)
end)
test('shared source uses every joined profession, independent of current profession',function()
    learned[101]=true;joined[1]=true;joined[5]=true;joined[14]=true;actor.Growth.CurrentProfessionId=3
    local origins=rules:Origins(actor,101,false);assert(#origins==3 and origins[1]==1 and origins[2]==5 and origins[3]==14)
end)
test('same profession composition adds status without a second damage budget',function()
    local r=recipe(101,{1});r.bodyProfessionId=1;joined[1]=true;points[1]=rules.maximum
    local skill=assert(rules:Compile(actor,r));local base=config:GetTable('CombatSkillTable'):Get(101)
    assert(skill.sourceSkillId==101 and skill.crafted and #skill.effectIds==#base.effectIds+1 and skill.effectIds[#skill.effectIds]==1313)
    assert(skill.damageScale==base.damageScale and skill.cost==base.cost+1 and not skill.opportunityAttack and not skill.affectsContainers)
end)
test('cross profession element preserves one formula and adds an explicit resource requirement',function()
    local skill=assert(rules:Compile(actor,recipe(101,{3})))
    assert(skill.craftDamageType=='fire' and skill.craftCastingCost==1 and skill.skillGroup=='weapon' and #skill.effectIds==1)
    assert(skill.visualSkillId==2301 and skill.sourceSkillId==101)
end)
test('three professions can contribute, two elements and duplicate buffs cannot',function()
    local r=recipe(103,{1,6});assert(rules:Compile(actor,r))
    assert(not rules:Compile(actor,recipe(101,{3,4})))
    assert(not rules:Compile(actor,recipe(502,{2})))
    assert(not rules:Compile(actor,recipe(101,{3,8})))
    assert(not rules:Compile(actor,recipe(101,{1,2,3})))
end)
test('each material origin must be mastered and learned; foreign provenance is rejected',function()
    local r=recipe(101,{3});learned[2301]=nil;assert(not rules:Compile(actor,r));learned[2301]=true
    r.modifierProfessionIds[1]=1;assert(not rules:Compile(actor,r))
end)
test('broad attacks pay additional cost and split their damage budget',function()
    local r=recipe(102,{1});local original=rules.skills;local base={}
    for key,value in pairs(original:Get(102))do base[key]=value end;base.maxTargets=3
    rules.skills={Get=function(_,id)return id==102 and base or original:Get(id)end}
    local skill=assert(rules:Compile(actor,r));rules.skills=original
    assert(skill.cost==base.cost+2 and skill.damageScale==base.damageScale*.8)
end)
print('PASS '..count..' crafted skill rule groups')
