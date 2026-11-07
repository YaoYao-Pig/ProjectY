-- Actual journal controller, saved prefab and authoritative learning command in isolated services.
local registry=require('Core.SystemRegistry')(Services)
require('Game.Systems')(registry)
local messages={}
local ok,err=xpcall(function()
    registry:Start()
    local ui,growth,adventure=registry:Get('UI'),registry:Get('Growth'),registry:Get('Adventure')
    local data=Services.Adventure;data:Reset(20261027)
    local actor=data:AddPartyActor(1,1)
    adventure.characterAppearances:Party(actor,20261027);growth:PrepareActor(actor,5)
    adventure.equipment:Start();adventure.equipment:StartPartyLoadouts()
    actor:SetMaxHP(growth.stats:MaximumHP(actor));actor:Restore()
    local adapter={LastError='',commands=0}
    function adapter:SetGrowthOpen(value)self.growthOpen=value end
    function adapter:SendCommand(command,a,b)
        assert(command=='growth_skill','Unexpected gameplay command')
        local success,reason=growth:Learn(a,b);self.LastError=success and '' or reason;self.commands=self.commands+1
    end
    local panel=ui:Open('CharacterGrowth',{demo=adapter,tab='Skills',selectedCourse=108})
    local pending,revision=actor.Growth.PendingCount,actor.Growth.Revision
    assert(panel.selectedCourse==108 and not panel.view.Invest.interactable)
    assert(panel.view.CourseDetail.gameObject.activeSelf and not panel.view.TalentDetail.gameObject.activeSelf)
    CheckGrowthSkillDetail(panel.view.CourseDetail,'locked',panel.view.Invest.interactable)
    CaptureGrowthSkillDetail(panel.reference,'locked')
    panel:SelectCourse(108)
    assert(adapter.commands==0 and actor.Growth.PendingCount==pending and actor.Growth.Revision==revision,'Detail selection mutated learning state')
    messages[#messages+1]='PASS locked course shows independent actual conditions; selection remains read-only'
    growth:AddExperience(actor,growth.rules.levels:Get(2).experience,'Detail fixture')
    local missing=8-growth.stats:Get(actor,'endurance',not growth.rules.settings.includeEquipment)
    if missing>0 then actor.Growth:InvestAttribute('endurance',1,missing)end
    actor:SetMaxHP(growth.stats:MaximumHP(actor));panel:Refresh()
    assert(panel.view.Invest.interactable)
    CheckGrowthSkillDetail(panel.view.CourseDetail,'ready',true)
    CaptureGrowthSkillDetail(panel.reference,'ready')
    local before=actor.Growth.PendingCount
    panel.view.Invest.onClick:Invoke()
    assert(actor.Growth:HasSkill(108) and actor.Growth.PendingCount==before-1 and adapter.commands==1)
    assert(not panel.view.Invest.interactable)
    CheckGrowthSkillDetail(panel.view.CourseDetail,'learned',false)
    messages[#messages+1]='PASS thresholds turn green and crossed out; learning command spends exactly once'
    panel.view.NextTree.onClick:Invoke()
    assert(not panel.view.CourseDetail.gameObject.activeSelf and panel.view.TalentDetail.gameObject.activeSelf)
    panel.view.PreviousTree.onClick:Invoke();panel:SelectCourse(108)
    ui:Close('CharacterGrowth')
    panel=ui:Open('CharacterGrowth',{demo=adapter,tab='Skills',selectedCourse=108})
    CheckGrowthSkillDetail(panel.view.CourseDetail,'learned',false)
    assert(adapter.commands==1 and not panel.view.TalentDetail.gameObject.activeSelf)
    messages[#messages+1]='PASS passive/active navigation and cached reopen keep correct detail visible'
    panel.view.Atlas.onClick:Invoke()
    assert(ui:IsOpen('SkillAtlas') and not ui:IsOpen('CharacterGrowth'))
    local atlas=ui.panels.SkillAtlas.ctrl
    assert(#atlas.domains==8 and atlas.domainPage==1)
    atlas.view.Domain6.onClick:Invoke();assert(atlas.domainPage==2)
    for slot=1,3 do atlas.view['Domain'..slot].onClick:Invoke();assert(atlas.disciplineId==slot+5)end
    atlas.view.Close.onClick:Invoke();panel=ui.panels.CharacterGrowth.ctrl
    assert(ui:IsOpen('CharacterGrowth') and panel.selectedCourse==108 and panel.view.CourseDetail.gameObject.activeSelf)
    messages[#messages+1]='PASS real journal/atlas round trip and all second-page domains remain usable'
    CheckGrowthSkillDetail(panel.view.CourseDetail,'long',false)
    ui:Close('CharacterGrowth')
end,debug.traceback)
registry:Shutdown();if not ok then error(err,0)end
return table.concat(messages,'\n')
