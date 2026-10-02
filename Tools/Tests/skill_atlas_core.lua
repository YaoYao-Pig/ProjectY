package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local bytes=file:read('*a');file:close();return bytes
end}})
local atlas=require('Game.Progression.SkillAtlas').New(config)
assert(atlas.nodes.Count==atlas.skills.Count,'Every combat skill needs an atlas entry')
assert(atlas:Path(304)=='营造 / 架设')
assert(#atlas:Categories(1)>=6 and #atlas:Nodes(31)==2)
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
local growth={HasSkill=function() return false end}
local actor={Growth=growth};local stats={growth={settings={includeEquipment=false}},Get=function()return 30 end}
assert(atlas:State(304,actor,stats,{})=='locked')
assert(atlas:State(304,actor,stats,{[303]=true})=='eligible')
assert(atlas:Details(304,actor,stats,{[303]=true}):find('材料',1,true))
print('PASS skill atlas: complete categories, shared identity, global search, prerequisites, cycle rejection and eligible state')
