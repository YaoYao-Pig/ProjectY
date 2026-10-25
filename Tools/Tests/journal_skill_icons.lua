-- Editor-free check of real node widgets using exported skill and icon configuration.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local skills,icons=config:GetTable('CombatSkillTable'),config:GetTable('BattleIconTable')
local atlas=config:GetTable('SkillAtlasTable')
local function vector(x,y,z) return {x=x,y=y,z=z} end
CS={UnityEngine={Vector2=vector,Vector3=vector,Color=vector}}
local talent=require('UI.Widget.TalentNode')
local atlasWidget=require('UI.Widget.SkillAtlasNode')
local style={
    SetArt=function(_,image,path) image.sprite='art:'..path;image.enabled=true end,
    SetGlyph=function(_,image,code) image.sprite='glyph:'..code end,
    Tint=function(_,image,color) image.color=color end,
    PlaceNode=function() end,
}
local function view()
    return {Root={gameObject={SetActive=function() end}},Title={},Rank={rectTransform={}},State={},
        Icon={rectTransform={}},Background={},Ring={rectTransform={}},Border={},Group={}}
end
local tree={view=view(),icons=icons}
local graph={view=view(),icons=icons}
local artCount,glyphCount=0,0
local artSkill
local function check(skill,state,iconTable)
    local node=atlas:Get(skill.id)
    local rows=iconTable or icons
    tree.icons,graph.icons=rows,rows
    local path=rows:Get(skill.iconId).spritePath
    tree.view.Icon.enabled=false;graph.view.Icon.enabled=false
    talent.SetSkillData(tree,node,skill,state,'',style,false,function() end)
    atlasWidget.SetData(graph,node,skill,state,'',style,{Place=function() end},false,true,function() end)
    for _,widget in ipairs({tree,graph}) do
        local image=widget.view.Icon
        assert(image.sprite==(path~='' and 'art:'..path or 'glyph:'..node.glyphCode),'Wrong image: '..skill.id)
        assert(image.enabled and image.preserveAspect,'Icon must be enabled and preserve aspect: '..skill.id)
        if path~='' then assert(image.color=='FFFFFF','Artwork tinted in '..state..' state: '..skill.id) end
    end
    if path=='' then
        assert(tree.view.Icon.color==(state=='owned' and 'E8D3A7' or state=='eligible' and '51462F' or '999483'))
        assert(graph.view.Icon.color==(state=='owned' and 'ECDAB2' or '62583F'))
    end
end
for _,skill in ipairs(skills:All()) do
    if icons:Get(skill.iconId).spritePath~='' then artCount=artCount+1;artSkill=skill
    else glyphCount=glyphCount+1 end
    for _,state in ipairs({'owned','eligible','locked'}) do check(skill,state) end
end
assert(artSkill,'Need published artwork coverage')
local emptyPath={Get=function(_,id) assert(id==artSkill.iconId);return {spritePath=''} end}
check(artSkill,'owned')
for _,state in ipairs({'owned','eligible','locked'}) do check(artSkill,state,emptyPath) end
check(artSkill,'eligible')
local missing={Get=function() return {spritePath='missing-sprite'} end}
local ok,err=pcall(require('UI.SkillIcon').Set,{}, {
    SetArt=function() error('Missing saved skill Sprite') end,
    SetGlyph=function() error('Must not hide an invalid configured Sprite with a glyph') end,
},artSkill,missing,'strength','51462F')
assert(not ok and tostring(err):find('Missing saved skill Sprite',1,true),'Configured resource failures must remain visible')
print('PASS journal and atlas nodes: '..artCount..' artwork, '..glyphCount..' configured glyph fallback; all three states, explicit empty-path fallback, reused images and missing-resource errors')
