-- Real configuration/controllers in an isolated PreviewScene; never touches player saves.
local registry=require('Core.SystemRegistry')(Services)
require('Game.Systems')(registry)
local ok,result=xpcall(function()
    registry:Start()
    local ui,adventure=registry:Get('UI'),registry:Get('Adventure')
    local data,stats=Services.Adventure,adventure.battle.stats
    data:Reset(20261031)
    for i,id in ipairs({1,2,3,4})do
        local actor=data:AddPartyActor(i,id);adventure.characterAppearances:Party(actor,20261031);adventure.growth:PrepareActor(actor)
        actor:SetMaxHP(stats:MaximumHP(actor));actor:Restore()
    end
    adventure.equipment:Start();adventure.equipment:StartPartyLoadouts()
    local Identity=require('Game.Presentation.CharacterIdentity')
    local actor=data:GetPartyAt(0);local state=CS.ProjectY.Data.TitleState
    state.Award(actor,1);state.Equip(actor,1)
    local identity=Identity.Read(stats,actor)
    assert(identity.title==adventure.config:GetTable('TitleTable'):Get(1).name)
    local original=actor.Growth.CurrentProfessionId
    actor.Growth:JoinProfession(3)
    assert(Identity.Read(stats,actor).profession==adventure.config:GetTable('ProfessionTable'):Get(3).name,'Identity must follow current profession')
    actor.Growth:JoinProfession(original)
    local plain=Identity.Format(Identity.Read(stats,data:GetPartyAt(1)),18,12,'E3BE73')
    assert(select(2,plain:gsub('\n',''))==1 and not plain:find('<color=',1,true),'No title must produce exactly two lines')
    assert(select(2,Identity.Format(identity,18,12,'E3BE73'):gsub('\n',''))==2)
    local animal=CS.ProjectY.Data.CombatActorData(999,assert(adventure.config:GetTable('AnimalSpeciesTable'):All()[1]).unitId)
    local animalIdentity=Identity.Read(stats,animal)
    assert(animalIdentity.profession==nil and animalIdentity.title==nil,'Untrained animals must not receive a profession or title')
    local adapter={LastError='',SetGrowthOpen=function()end,SetEquipmentOpen=function()end,SendCommand=function()end}
    for _,name in ipairs({'CharacterGrowth','SkillAtlas','Inventory','EquipmentWorkbench'})do
        local panel=ui:Open(name,{demo=adapter,tab='Titles'})
        local first=(name=='Inventory' or name=='EquipmentWorkbench')and panel.view.ActorText1 or panel.view.Party1Text
        assert(first.text:find(identity.title,1,true) and first.text:find(identity.name,1,true))
        CaptureIdentityUI(name,panel.reference)
        if name=='CharacterGrowth' then
            state.Equip(actor,0);panel:Refresh();assert(not panel.view.Party1Text.text:find('<color=',1,true),'Unequipping must remove the title immediately')
            state.Equip(actor,1);panel:Refresh()
        end
        ui:Close(name)
    end
    CaptureIdentityWidgets(Identity.Format(identity,17,11,'E3BE73'),Identity.Format(identity,15,11,'E3BE73'),plain,
        Identity.Format(identity,20,13,'E3BE73'),Identity.Format(identity,25,14,'805723'))
    return 'PASS identity: equipped/unequipped titles, live profession, no-title two lines, animals; four real panels and saved widget layouts'
end,debug.traceback)
registry:Shutdown();if not ok then error(result,0)end
return result
