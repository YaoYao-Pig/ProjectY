-- 真实 Prefab 的图标契约回归：角色总览及图谱的每一种技能熟练属性。
local registry=require('Core.SystemRegistry')(Services)
require('Game.Systems')(registry)
local report={}
local ok,err=xpcall(function()
    registry:Start()
    local data=Services.Adventure;data:Reset(20261003)
    local growth=registry:Get('Growth');local actor=data:AddPartyActor(1,1)
    growth:Initialize(actor);actor:SetMaxHP(growth.stats:MaximumHP(actor));actor:Restore()
    local ui=registry:Get('UI');local adapter={SetGrowthOpen=function(self,value)self.open=value end,LastError=''}
    local journal=ui:Open('CharacterGrowth',{demo=adapter})
    assert(adapter.open and #journal.pools.Attributes==growth.rules.attributes.Count)
    local seen={}
    for i,row in ipairs(growth.rules.attributes:All()) do
        local widget=journal.pools.Attributes[i]
        assert(widget.view.Icon.sprite~=nil,'Missing journal sprite: '..row.code)
        seen[row.code]=widget.view.Icon.sprite
    end
    assert(seen.animalAffinity and seen.charisma and seen.animalAffinity~=seen.charisma,'Animal affinity and charisma need distinct sprites')
    report[#report+1]='PASS CharacterGrowth: all '..growth.rules.attributes.Count..' configured attribute icons render, including animalAffinity/charisma'
    ui:Close('CharacterGrowth')
    local atlas=ui:Open('SkillAtlas',{demo=adapter});local displayed={}
    for _,category in ipairs(atlas.atlas.categories:All()) do
        atlas.disciplineId=category.disciplineId;atlas.categoryId=category.id;atlas.selectedId=nil;atlas:Refresh()
        for _,widget in ipairs(atlas.nodes) do if widget.node then
            local skill=atlas.atlas.skills:Get(widget.node.id)
            assert(widget.view.Icon.sprite~=nil,'Missing atlas sprite: '..skill.name..' / '..skill.proficiency)
            displayed[skill.id]=true
        end end
    end
    local count=0;for _,skill in ipairs(atlas.atlas.skills:All()) do assert(displayed[skill.id],'Skill not rendered: '..skill.id);count=count+1 end
    atlas:Jump(201);assert(atlas.view.Geometry.PopupVisible and atlas.view.TipTitle.text==atlas.atlas.skills:Get(201).name)
    report[#report+1]='PASS SkillAtlas: all '..count..' configured skills render across every category; animal skill popup opens'
    ui:Close('SkillAtlas')
    journal=ui:Open('CharacterGrowth',{demo=adapter});assert(#journal.pools.Attributes==growth.rules.attributes.Count)
    ui:Close('CharacterGrowth');assert(not adapter.open and not Services.UI.IsWorldPaused)
    report[#report+1]='PASS cached journal reopen and pause restoration'
end,debug.traceback)
registry:Shutdown()
if not ok then error(err) end
return table.concat(report,'\n')
