-- Real exported curriculum, atlas and tooltip content; only actor/stat inputs
-- are isolated. This projection must not learn, spend, roll or touch native UI.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local rules=require('Game.Progression.GrowthRules').New(config)
local Model=require('UI.GrowthSkillDetailModel');local model=Model.New(config)
local learned,granted,innate,values,bonuses={},{},{},{},{}
local reads={};local writes=0
local growth={Initialized=true,CurrentProfessionId=1,Level=1,PendingCount=0,Revision=17}
function growth:HasSkill(id)return learned[id]==true end
function growth:GetRank()return 0 end
function growth:LearnSelected()writes=writes+1;error('Read-only detail attempted to learn')end
local actor={Id=1,Growth=growth}
local stats={growth=rules,effects=config:GetTable('CombatEffectTable'),equipment={}}
function stats:Template()return {skillIds=innate}end
function stats:Get(_,code,excludeEquipment)
    reads[#reads+1]={code=code,excludeEquipment=excludeEquipment}
    return (values[code] or 0)+(excludeEquipment and 0 or (bonuses[code] or 0))
end
function stats.equipment:SkillIds()
    local ids,seen={},{}
    for id in pairs(learned)do ids[#ids+1]=id;seen[id]=true end
    for id in pairs(granted)do if not seen[id]then ids[#ids+1]=id;seen[id]=true end end
    for _,id in ipairs(innate)do if not seen[id]then ids[#ids+1]=id end end
    return ids
end
function stats.equipment:CheckSkillEquipment()return false,'fixture catalyst unavailable' end
stats.spellcasting=require('Game.Battle.Spellcasting').New(config,stats)
local count=0
local function test(name,run)run();count=count+1;print('PASS '..name)end
local function rows(detail,kind)
    local result={};for _,row in ipairs(detail.conditions)do
        assert(type(row.text)=='string' and type(row.met)=='boolean','Every condition must have plain text and explicit state')
        assert(not row.text:find('<s>',1,true),'Strikethrough belongs to the native condition renderer')
        if row.kind==kind then result[#result+1]=row end
    end;return result
end
local function build(id,phase)return model:Build(actor,stats,phase or 'map',id)end
test('returns all failed level, attribute, opportunity and phase conditions together',function()
    local detail=build(108,'combat')
    assert(not detail.canLearn and #rows(detail,'level')==1 and not rows(detail,'level')[1].met)
    assert(#rows(detail,'attribute')==1 and not rows(detail,'attribute')[1].met)
    assert(not rows(detail,'opportunity')[1].met and not rows(detail,'phase')[1].met)
    assert(rows(detail,'profession')[1].met and type(detail.statusText)=='string')
    assert(#detail.tags>=2 and detail.tags[1].backgroundColor:match('^#%x+$'))
    assert(detail.body:find('<color=#A45C22><b>3</b></color>',1,true),'Actual guard_three fragment must supply and highlight the body')
end)
test('current profession selects one shared course and real phase gates learning',function()
    growth.Level=2;growth.PendingCount=1;values.endurance=8
    for _,profession in ipairs({1,5})do
        growth.CurrentProfessionId=profession;local detail=build(108)
        assert(detail.canLearn and #detail.courseRoutes==2)
        assert(#rows(detail,'level')==1 and #rows(detail,'attribute')==1,'Other profession routes cannot become extra mandatory gates')
        assert(rows(detail,'profession')[1].professionId==profession)
    end
    assert(build(108,'area').canLearn and not build(108,'deployment').canLearn)
    assert(rules.professions:CanLearn(actor,108,stats,rules.atlas),'Phase is the extra GrowthSystem.Editable gate, not a changed course rule')
end)
test('attribute rows honor includeEquipment exactly and catalyst is separate from learning',function()
    local original=rules.settings;local settings={};for key,value in pairs(original)do settings[key]=value end;rules.settings=settings
    values.endurance=7;bonuses.endurance=1;settings.includeEquipment=false;reads={}
    assert(not build(108).canLearn and reads[#reads].excludeEquipment)
    settings.includeEquipment=true;reads={};local detail=build(108)
    assert(detail.canLearn and not reads[#reads].excludeEquipment and rows(detail,'attribute')[1].current==8)
    growth.CurrentProfessionId=3;growth.Level=2;values.intellect=8
    detail=build(103);assert(detail.canLearn and detail.equipmentText:find('fixture catalyst unavailable',1,true))
    assert(#rows(detail,'equipment')==0,'Missing catalyst must not become a learning condition')
    rules.settings=original;bonuses={}
end)
test('all prerequisites are individual rows and any prerequisites are one alternative gate',function()
    growth.CurrentProfessionId=4;growth.Level=5;values.crafting=6;granted={[2431]=true}
    local detail=build(2433);local prerequisites=rows(detail,'prerequisite')
    assert(#prerequisites==2 and prerequisites[1].met and not prerequisites[2].met and not detail.canLearn)
    local original=rules.atlas.nodes
    rules.atlas.nodes={Get=function(_,id)
        local row=original:Get(id);if id~=2433 then return row end
        local copy={};for key,value in pairs(row)do copy[key]=value end;copy.prerequisiteMode='any';return copy
    end}
    detail=build(2433);local alternatives=rows(detail,'prerequisite_any')
    assert(#rows(detail,'prerequisite')==0 and #alternatives==1 and alternatives[1].met and detail.canLearn)
    assert(alternatives[1].options[1].met and not alternatives[1].options[2].met)
    granted={};detail=build(2433);assert(not rows(detail,'prerequisite_any')[1].met and not detail.canLearn)
    rules.atlas.nodes=original
end)
test('foreign shared courses remain alternatives instead of a combined AND requirement',function()
    growth.CurrentProfessionId=3;growth.Level=5;values.endurance=8
    local detail=build(108)
    assert(not detail.canLearn and detail.sourceKind=='other_profession' and #detail.courseRoutes==2)
    assert(#rows(detail,'profession_any')==1 and not rows(detail,'profession_any')[1].met)
    assert(#rows(detail,'level')==0 and #rows(detail,'attribute')==0)
    for _,row in ipairs(rows(detail,'course_route'))do assert(row.alternative and not row.blocking and #row.conditions==2)end
end)
test('learned and inherent skills stay acquired without repeat-learning or action conditions',function()
    growth.CurrentProfessionId=1;growth.Level=1;growth.PendingCount=0;values.endurance=0;learned={[108]=true}
    local detail=build(108,'combat')
    assert(detail.learned and detail.owned and not detail.canLearn and #rows(detail,'phase')==0 and #rows(detail,'opportunity')==0)
    for _,row in ipairs(detail.conditions)do assert(not row.blocking)end
    learned={};innate={108};detail=build(108)
    assert(detail.inherent and not detail.canLearn and detail.sourceKind=='inherent' and type(detail.statusText)=='string')
    innate={}
end)
test('equipment-granted skills can still be learned while automatic recipes cannot',function()
    growth.CurrentProfessionId=1;growth.Level=5;growth.PendingCount=1;values.endurance=8;granted={[108]=true}
    local detail=build(108);assert(detail.owned and not detail.learned and detail.sourceKind=='equipment' and detail.canLearn)
    growth.CurrentProfessionId=3;granted={[2301]=true,[2302]=true};detail=build(2304,'combat')
    assert(detail.owned and detail.sourceKind=='recipe' and not detail.canLearn)
    assert(#rows(detail,'phase')==0 and #rows(detail,'opportunity')==0 and #rows(detail,'prerequisite')==2)
    for _,row in ipairs(rows(detail,'prerequisite'))do assert(row.met)end
    detail=build(701);assert(not detail.canLearn and #detail.courseRoutes==0 and detail.sourceKind=='special')
end)
test('numeric highlights preserve TMP attributes, links and explicit colors',function()
    local source='<link="term:cost_2301">12.5%</link> <color=#123456>7</color> <size=24>3</size> 100.'
    local highlighted=Model.HighlightNumbers(source)
    assert(highlighted:find('<link="term:cost_2301">',1,true) and highlighted:find('<size=24>',1,true))
    assert(highlighted:find('<color=#A45C22><b>12.5%</b></color>',1,true))
    assert(highlighted:find('<color=#123456><b>7</b></color>',1,true),'An authored color must not be replaced')
    assert(highlighted:find('<color=#A45C22><b>100</b></color>.',1,true),'Sentence punctuation is outside numeric highlight')
    assert(Model.HighlightNumbers(highlighted)==highlighted,'Repeated read-only formatting must be idempotent')
end)
assert(writes==0 and growth.Revision==17 and growth.PendingCount==1,'Detail projection must not mutate learning or opportunity state')
print('Growth skill detail model: '..count..' checks passed')
