local registry=require('Core.SystemRegistry')(Services)
require('Game.Systems')(registry)
local ok,result=xpcall(function()
    registry:Start()
    local ui,adventure=registry:Get('UI'),registry:Get('Adventure')
    local data,stats=Services.Adventure,adventure.battle.stats;data:Reset(8642)
    local actor=data:AddPartyActor(1,1);adventure.characterAppearances:Party(actor,8642)
    adventure.growth:PrepareActor(actor,1);actor:SetMaxHP(stats:MaximumHP(actor));actor:Restore()
    adventure.equipment:Start();adventure.equipment:StartPartyLoadouts()
    local adapter={LastError='',snapshots=0}
    function adapter:SetGrowthOpen(value)self.growthOpen=value end
    function adapter:SendCommand(command)assert(command=='snapshot');self.snapshots=self.snapshots+1 end
    local growth=ui:Open('CharacterGrowth',{demo=adapter,tab='Skills'})
    growth.pools.SkillRows[1].view.Button.onClick:Invoke()
    assert(ui:IsOpen('SkillCraft'),'Journal craft entry must open the registered panel')
    local panel=ui.panels.SkillCraft.ctrl
    assert(not panel.view.Craft.interactable and panel.recipe.id==0)
    for _,row in ipairs(panel.rows)do assert(not row.allowed,'No mastery must expose no selectable bodies')end
    CaptureSkillCraftUI('locked',panel.reference)
    assert(adventure.growth:ChangeProfession(actor.Id,3))
    for _,id in ipairs({101,2301,2401})do actor.Growth:GrantSkill(id)end
    local state=CS.ProjectY.Data.SkillCraftState
    state.Practice(actor,{1,3},200000,stats.skillCraft.maximum)
    panel:Tick()
    local function click(kind,id,profession,plus)
        local key=({body='primary',element='combat',status='life',saved='special'})[kind]
        panel.view['Group_'..key].onClick:Invoke()
        local index
        for i,row in ipairs(panel.rows)do if row.id==id and (not profession or row.professionId==profession)then index=i;break end end
        assert(index,'Missing requested craft row');panel.list:ScrollTo(index,.5)
        local cell=assert(panel.list:GetVisibleCell(index));cell.view[plus and 'Plus' or 'Minus'].onClick:Invoke()
    end
    click('body',101,1,true);click('element',3,3,true);click('status',1,1,true)
    panel.view.Name.text='烽刃破甲';assert(panel.view.Craft.interactable)
    CaptureSkillCraftUI('composition',panel.reference)
    local pending=actor.Growth.PendingCount;panel.view.Craft.onClick:Invoke()
    assert(state.Count(actor)==1 and panel.recipe.id>1000000000 and pending==actor.Growth.PendingCount and adapter.snapshots==1)
    local id=panel.recipe.id;ui:Close('SkillCraft')
    panel=ui:Open('SkillCraft',{demo=adapter,actorId=actor.Id});assert(panel.recipe.id==0 and #panel.recipe.modifierIds==0)
    click('saved',id,nil,true);assert(panel.recipe.id==id and panel.view.Name.text=='烽刃破甲')
    panel.view.Name.text='烽刃改';panel.view.Craft.onClick:Invoke()
    assert(state.Count(actor)==1 and state.Find(actor,id).name=='烽刃改')
    CaptureSkillCraftUI('saved',panel.reference)
    panel.view.Group_negative.onClick:Invoke();assert(panel.recipe.id==0 and #panel.recipe.modifierIds==0 and panel.view.Name.text=='')
    ui:Close('SkillCraft');ui:Close('CharacterGrowth')
    assert(not Services.UI.IsWorldPaused,'Closing both panels must release pause ownership')
    return 'PASS real journal entry, locked mastery, saved material buttons, cross-profession preview, create, cache reopen, edit identity, new draft and pause release'
end,debug.traceback)
registry:Shutdown();if not ok then error(result,0)end
return result
