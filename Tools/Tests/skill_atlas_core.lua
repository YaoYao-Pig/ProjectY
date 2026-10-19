package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local bytes=file:read('*a');file:close();return bytes
end}})
local rules=require('Game.Progression.GrowthRules').New(config)
local atlas=rules.atlas
assert(atlas.nodes.Count==atlas.skills.Count,'Every combat skill needs an atlas entry')
local glyphs={}
for _,attribute in ipairs(atlas.attributes:All()) do glyphs[attribute.code]=true end
for _,node in ipairs(atlas.nodes:All()) do assert(glyphs[node.glyphCode],'Missing explicit atlas glyph: '..node.id) end
for _,id in ipairs({401,402,403,404,701,702}) do
    assert(atlas.skills:Get(id).proficiency=='','Regression must cover skills without damage proficiency')
    assert(glyphs[atlas.nodes:Get(id).glyphCode])
end
-- Exercise the actual widget boundary: glyph selection must not depend on damage proficiency.
local savedCS=CS
CS={UnityEngine={Color=function(...) return {...} end}}
local widget=require('UI.Widget.SkillAtlasNode')
local view={Root={gameObject={SetActive=function() end}},Title={},State={},Icon={},Background={},Border={},Group={}}
local glyphCount=0
local style={SetGlyph=function(_,_,code) assert(glyphs[code],'Widget requested an absent journal glyph: '..tostring(code));glyphCount=glyphCount+1 end,Tint=function() end}
for _,node in ipairs(atlas.nodes:All()) do
    widget.SetData({view=view},node,atlas.skills:Get(node.id),'eligible','',style,{Place=function() end},false,true,function() end)
end
assert(glyphCount==atlas.nodes.Count)
CS=savedCS
assert(atlas:Path(304)=='营造 / 架设')
assert(#atlas:Categories(1)>=6 and #atlas:Nodes(31)==3)
assert(atlas:Search('高台')[1].id==304)
assert(#atlas:Search('枪械')==3 and #atlas:Search('  ')==0)
local shields=atlas:Nodes(13);assert(#shields==2 and atlas.nodes:Get(shields[1].id).categoryId~=13)
assert(not atlas:Prerequisites(304,{}) and atlas:Prerequisites(304,{[303]=true}))
local related=atlas:Related(303);assert(related[303] and related[304] and not related[301])
local replacement={}
for _,node in ipairs(atlas.nodes:All()) do
    local copy={};for key,value in pairs(node) do copy[key]=value end
    if node.id==303 then copy.prerequisiteIds={304} end
    replacement[node.id]=copy
end
local broken={GetTable=function(_,name)
    if name~='SkillAtlasTable' then return config:GetTable(name) end
    return {Get=function(_,id) return assert(replacement[id]) end,All=function() local rows={};for _,node in pairs(replacement) do rows[#rows+1]=node end;return rows end}
end}
assert(not pcall(require('Game.Progression.SkillAtlas').New,broken),'Cyclic prerequisites must fail before rendering')
replacement[303].prerequisiteIds=atlas.nodes:Get(303).prerequisiteIds
replacement[404].glyphCode=''
local glyphOk,glyphError=pcall(require('Game.Progression.SkillAtlas').New,broken)
assert(not glyphOk and tostring(glyphError):find('Invalid atlas glyph for skill 404',1,true),'Missing glyph must identify the skill before UI rendering')
local growth={CurrentProfessionId=4,Level=10,HasSkill=function() return false end}
local actor={Growth=growth};local stats={growth=rules,Get=function()return 30 end,Template=function()return {skillIds={}} end}
assert(atlas:State(304,actor,stats,{})=='locked')
assert(atlas:State(304,actor,stats,{[303]=true})=='eligible')
assert(atlas:Details(304,actor,stats,{[303]=true}):find('材料',1,true))
growth.CurrentProfessionId=1;assert(atlas:State(304,actor,stats,{[303]=true})=='locked')
assert(atlas:State(701,actor,stats,{})=='source' and atlas:Details(701,actor,stats,{}):find('不能研习',1,true))
stats.Template=function()return {skillIds={3}}end
stats.equipment={CheckSkillEquipment=function()return false,'需要奥术触媒'end}
local _,label=atlas:State(3,actor,stats,{[3]=true});assert(label=='固有技能')
assert(atlas:Details(3,actor,stats,{[3]=true}):find('施放条件：需要奥术触媒',1,true))
stats.equipment.CheckSkillEquipment=function()return true end
assert(atlas:Details(3,actor,stats,{[3]=true}):find('触媒就绪',1,true))
print('PASS skill atlas: complete categories, shared identity, global search, prerequisites, cycle rejection and eligible state')
