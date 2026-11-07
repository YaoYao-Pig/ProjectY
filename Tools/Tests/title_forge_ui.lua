-- Actual saved controls and gameplay model in an isolated PreviewScene, no player saves.
local registry=require('Core.SystemRegistry')(Services)
require('Game.Systems')(registry)
local ok,result=xpcall(function()
    registry:Start()
    local ui,adventure=registry:Get('UI'),registry:Get('Adventure')
    local data,stats=Services.Adventure,adventure.battle.stats
    data:Reset(20261101)
    for i,id in ipairs({1,2})do
        local actor=data:AddPartyActor(i,id);adventure.characterAppearances:Party(actor,20261101)
        adventure.growth:PrepareActor(actor);actor:SetMaxHP(stats:MaximumHP(actor));actor:Restore()
    end
    adventure.equipment:Start();adventure.equipment:StartPartyLoadouts()
    local state,reputation=CS.ProjectY.Data.TitleState,CS.ProjectY.Data.ReputationState
    local actor=data:GetPartyAt(0)
    local adapter={LastError='',snapshots=0,equips=0}
    function adapter:SetGrowthOpen(value)self.growthOpen=value end
    function adapter:SendCommand(command,a,b)
        if command=='snapshot' then self.snapshots=self.snapshots+1;return end
        assert(command=='title_equip','Unexpected title UI command')
        local success,reason=adventure.titles:Equip(a,b)
        self.LastError=success and '' or reason;assert(success,reason);self.equips=self.equips+1
    end
    local growth=ui:Open('CharacterGrowth',{demo=adapter,tab='Titles'})
    growth.view.TitleForge.onClick:Invoke();assert(ui:IsOpen('TitleForge'),'Journal entry did not open forge')
    local forge=ui.panels.TitleForge.ctrl
    assert(not forge.view.Craft.interactable and next(forge.ranks)==nil,'A new draft must start empty and disabled')
    forge.view.Name.text='负誓守望者'
    local effectIndices,attributeCount={},0
    local effects=adventure.config:GetTable('TitleForgeEffectTable')
    for index,row in ipairs(forge.rows)do if not row.header then
        effectIndices[row.id]=index
        if effects:Get(row.id).kind=='attribute' and not row.negative then attributeCount=attributeCount+1 end
    end end
    assert(attributeCount==20,'Forge must expose all twenty positive attribute controls')
    for _,category in ipairs({'primary','combat','life','special','negative'})do
        forge.view['Group_'..category].onClick:Invoke()
        local first,last=forge.list:GetVisibleRange()
        assert(forge.firstInCategory[category]>=first and forge.firstInCategory[category]<=last,'Category jump missed header: '..category)
    end
    local function adjust(id,plus)
        local index=assert(effectIndices[id]);forge.list:ScrollTo(index,.5)
        local cell=assert(forge.list:GetVisibleCell(index),'Scrolled effect must have an active cell')
        local before=forge.ranks[id] or 0
        cell.view[plus and 'Plus' or 'Minus'].onClick:Invoke()
        assert((forge.ranks[id] or 0)==before+(plus and 1 or -1),'Saved effect control did not change its rank')
    end
    for _,row in ipairs(effects:All())do if row.kind=='attribute' and not row.negative then
        adjust(row.id,true);adjust(row.id,false)
    end end
    assert(next(forge.ranks)==nil,'Removing every point must clear the draft')
    local firstPositive,firstSpecial,firstNegative
    for _,row in ipairs(effects:All())do
        if row.category=='primary' and not firstPositive then firstPositive=row end
        if row.category=='special' and not firstSpecial then firstSpecial=row end
        if row.negative and not firstNegative then firstNegative=row end
    end
    adjust(firstPositive.id,true);adjust(firstPositive.id,true);adjust(firstSpecial.id,true);adjust(firstNegative.id,true)
    local quote=adventure.titles:Quote(forge.view.Name.text,forge.ranks)
    assert(quote.valid and quote.positive>0 and quote.discount>0 and quote.cost==quote.positive-quote.discount)
    assert(not forge.view.Craft.interactable,'No reputation must disable crafting')
    reputation.AwardSettlement(data,'mission',900001,1000);forge:Tick()
    assert(forge.view.Craft.interactable and forge.view.TotalCost.text:find(tostring(quote.cost),1,true),'Award did not update affordability and price')
    forge.view.Group_primary.onClick:Invoke();CaptureTitleForgeUI('title-forge',forge.reference)
    local before=reputation.Balance(data);forge.view.Craft.onClick:Invoke()
    assert(not ui:IsOpen('TitleForge') and ui:IsOpen('CharacterGrowth'),'Successful creation must return to title page')
    assert(adapter.snapshots==1 and reputation.Balance(data)==before-quote.cost,'Craft must spend the displayed price once')
    local id=growth.selectedTitle
    assert(id<0 and state.Owns(actor,id) and state.CustomCount(actor)==1 and state.Equipped(actor)==0,'Crafted title must be owned, selected and initially unequipped')
    assert(state.CustomName(actor,id)=='负誓守望者' and growth.view.TitleEquip.interactable
        and growth.view.TitleDetail.text:find(firstPositive.name,1,true),'New title detail or equip state missing')
    growth.view.TitleEquip.onClick:Invoke();assert(state.Equipped(actor)==id and adapter.equips==1,'New title equip failed')
    CaptureTitleForgeUI('title-page',growth.reference)
    growth.view.Party2.onClick:Invoke()
    assert(not state.Owns(data:GetPartyAt(1),id),'Custom title leaked to another actor')
    growth.view.TitleForge.onClick:Invoke();local reopened=ui.panels.TitleForge.ctrl
    assert(reopened==forge and next(reopened.ranks)==nil and reopened.view.Name.text=='' and not reopened.view.Craft.interactable,'Cached forge retained the previous draft')
    assert(reopened.actorId==data:GetPartyAt(1).Id,'Forge did not target the selected party member')
    assert(reopened.view.Balance.text:find(tostring(reputation.Balance(data)),1,true),'Party members must share one reputation balance')
    ui:Close('TitleForge');growth.view.Party1.onClick:Invoke()
    assert(state.Equipped(actor)==id and state.CustomCount(actor)==1,'Switching or reopening changed title ownership')
    ui:Close('CharacterGrowth')
    assert(not adapter.growthOpen and not Services.UI.IsWorldPaused,'Nested panels did not release pause state')
    return 'PASS real title forge UI: all 20 attribute +/- controls; five category jumps; blank-draft and affordability guards; live shared reputation; quote and negative discount; single charge; permanent personal ownership; return selection and equip; actor switching; cached draft reset; pause cleanup. Captured title-forge.png and title-page.png.'
end,debug.traceback)
registry:Shutdown();if not ok then error(result,0)end
return result
