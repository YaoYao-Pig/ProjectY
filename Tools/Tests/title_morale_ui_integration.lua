-- Actual saved title page, controller and equip command. No live game or player saves.
local registry=require('Core.SystemRegistry')(Services)
require('Game.Systems')(registry)
local ok,result=xpcall(function()
    registry:Start()
    local ui,adventure=registry:Get('UI'),registry:Get('Adventure')
    local data,growth=Services.Adventure,adventure.growth;data:Reset(20261031)
    for i,id in ipairs({1,2})do
        local actor=data:AddPartyActor(i,id);adventure.characterAppearances:Party(actor,20261031);growth:PrepareActor(actor)
        actor:SetMaxHP(growth.stats:MaximumHP(actor));actor:Restore()
    end
    adventure.equipment:Start();adventure.equipment:StartPartyLoadouts()
    local actor=data:GetPartyAt(0);local state=CS.ProjectY.Data.TitleState
    state.Award(actor,1);state.Award(actor,10)
    for i=1,10 do state.Increment(actor,'kill:0')end
    local adapter={LastError='',commands=0}
    function adapter:SetGrowthOpen(value)self.growthOpen=value end
    function adapter:SendCommand(command,a,b)
        assert(command=='title_equip');local success,reason=adventure.titles:Equip(a,b)
        self.LastError=success and '' or reason;self.commands=self.commands+1
    end
    local panel=ui:Open('CharacterGrowth',{demo=adapter,tab='Titles'})
    assert(#panel.pools.TitleRows==10 and panel.view.TitleEquip.interactable,'Title page must show all ten configured rows')
    local function choose(id)
        for _,widget in ipairs(panel.pools.TitleRows)do if widget.row and widget.row.id==id then widget.view.Button.onClick:Invoke();return end end
        error('Missing title row')
    end
    choose(3);assert(not panel.view.TitleEquip.interactable and panel.view.TitleDetail.text:find('传奇',1,true),'Locked titles must remain inspectable')
    choose(1);panel.view.TitleEquip.onClick:Invoke();assert(state.Equipped(actor)==1 and adapter.commands==1)
    choose(10);panel.view.TitleEquip.onClick:Invoke();assert(state.Equipped(actor)==10 and adapter.commands==2)
    panel.view.Party2.onClick:Invoke();assert(not panel.view.TitleEquip.interactable,'Unearned title became equipable after switching actors')
    panel.view.Party1.onClick:Invoke();panel.view.TitleEquip.onClick:Invoke();assert(state.Equipped(actor)==0,'Unequip button failed')
    panel.view.OverviewTab.onClick:Invoke()
    local found=false;for _,widget in ipairs(panel.pools.Attributes)do if widget.row and widget.row.id==20 then found=true;assert(widget.view.Icon.sprite~=nil)end end
    assert(found,'Courage must appear in actual attribute controls')
    ui:Close('CharacterGrowth');panel=ui:Open('CharacterGrowth',{demo=adapter,tab='Titles'})
    choose(1);panel.view.TitleEquip.onClick:Invoke();assert(state.Equipped(actor)==1 and adapter.commands==4)
    CaptureTitleUI(panel.reference)
    ui:Close('CharacterGrowth');assert(not adapter.growthOpen and not Services.UI.IsWorldPaused)
    return 'PASS actual title UI: ten rows, locked inspection, equip/replace/unequip, actor switching, courage glyph, cached reopen and unpause'
end,debug.traceback)
registry:Shutdown();if not ok then error(result,0)end
return result
