package.path='Lua/?.lua;'..package.path
package.loaded['UI.ArtSkin']={}
local rows,click
package.loaded['UI.GrowthWidgets']={Rows=function(_,_,_,values,callback)rows=values;click=callback end}
local Growth=require('UI.Panel.CharacterGrowthCtr')
local learner,teacher={Id=1},{Id=2}
local available=true
local special={TeachingRows=function(_,student,mentor)
    assert(student==learner and mentor==teacher)
    return {{title='study',body='eligibility',allowed=available,skillId=2701}}
end}
local story={Actor=function(_,id)assert(id==2);return teacher end,Name=function()return 'teacher' end,
    StageName=function()return 'trust' end,PairBody=function()return 'bond' end,ActionRows=function()return {}end}
local commands={}
local panel=setmetatable({actor=learner,relationshipId=2,view={Hint={}},
    context={systems={Get=function(_,name)assert(name=='Adventure');return {specialSkills=special}end}},
    demo={SendCommand=function(_,...)commands[#commands+1]={...}end}},Growth)
function panel:TraitText(value)self.detail=value end
function panel:Refresh()self:Relationship(story)end
function panel:Overview()self.overview=true end
panel:Relationship(story)
assert(#rows==3 and rows[3].available==true)
click(rows[3]);assert(#commands==0 and panel.relationshipAction.skillId==2701)
assert(rows[2].confirmSkillId==2701)
click(rows[2]);assert(#commands==1 and panel.relationshipAction==nil)
assert(commands[1][1]=='special_skill_teach' and commands[1][2]==2 and commands[1][3]==1 and commands[1][4]==2701)
available=false;panel:Refresh();click(rows[3])
assert(#commands==1 and panel.relationshipAction==nil and panel.detail=='eligibility')
click(rows[1]);assert(panel.overview and panel.relationshipId==nil)
print('SPECIAL_SKILL_UI_PASS: teacher/learner direction, preview before grant, confirmation, disabled reason and back navigation')
