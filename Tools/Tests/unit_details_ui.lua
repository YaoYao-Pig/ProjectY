-- Called by unit_details_editmode.cs: real saved UI, native actors/state, real inspection and battle budget.
-- The target index is an isolated visible-world fixture; the input demo suppresses snapshot rendering only.
local L=require('Language')
local config=require('Config.ConfigSystem')()
local battle=require('Game.Battle.BattleSystem')()
local ui=require('UI.UISystem')()
local adventure={data=Services.Adventure,config=config,battle=battle}
adventure.people={CanOpen=function()return false,''end}
local context={services=Services,log=function(message)error(message,0)end}
context.systems={Get=function(_,name)
    return assert(({Config=config,Battle=battle,UI=ui,Adventure=adventure})[name],'Unexpected test system '..name)
end}
config:OnInit(context);battle:OnInit(context);ui:OnInit(context)
local messages={}
local ok,err=xpcall(function()
    local data=adventure.data;data:Reset(20261031)
    local actor=data:AddPartyActor(1,1);actor:SetMaxHP(80);actor:Restore();actor:Deploy(1,0,0)
    local second=data:AddPartyActor(2,2);second:SetMaxHP(70);second:Restore();second:Deploy(1,1,0)
    local allTraits=config:GetTable('CombatTraitTable'):All()
    for i=1,math.min(10,#allTraits)do actor:AddTrait(allTraits[i].id)end
    local rows={{key='actor:1',name=battle.stats:Template(actor).name,actor=actor,owned=true,kind='party'},
        {key='actor:2',name=battle.stats:Template(second).name,actor=second,owned=true,kind='party'}}
    for i=1,12 do
        local target=CS.ProjectY.Data.CombatActorData(2000+i,4)
        target:SetMaxHP(60);target:Restore();target:Deploy(2,i+2,0)
        for t=1,math.min(10,#allTraits)do target:AddTrait(allTraits[t].id)end
        rows[#rows+1]={key='actor:'..target.Id,name=battle.stats:Template(target).name,actor=target,owned=false,kind='unit'}
    end
    local index={}
    function index:Rows()return rows end
    function index:Name(unit)return battle.stats:Template(unit).name end
    function index:Find(key)for _,row in ipairs(rows)do if row.key==key then return row end end end
    function index:Identity(unit)for _,row in ipairs(rows)do if row.actor==unit then return row.key,row.owned end end end
    adventure.inspection=require('Game.Adventure.UnitInspection').New(adventure)
    adventure.inspection.targets=index
    adventure.narrative={AdvanceMinutes=function(_,minutes)data.Narrative:AdvanceMinutes(minutes)end}
    local records=CS.ProjectY.Data.UnitInspections.Get(data)
    local target=rows[3]
    local beforeTime=data.Narrative.Minutes;local beforeAP=actor.AP;local beforeRevision=records.Revision
    local panel=ui:Open('UnitDetails',{demo=InspectionDemo,key=target.key})
    assert(Services.UI.IsWorldPaused and InspectionInputOpen())
    local encounteredCount=#rows-2
    assert(records.Count==encounteredCount and records.Revision==beforeRevision+encounteredCount,
        'Visible non-owned units must gain one passive knowledge record each')
    assert(data.Narrative.Minutes==beforeTime and actor.AP==beforeAP,'Opening details consumed resources')
    for i=3,#rows do
        local record=assert(records:Find(rows[i].key))
        assert(not record.Observed and record.ObserverId==0 and record.ObserverRoll==0 and record.TargetRoll==0 and record.FieldCount==4)
        for _,field in ipairs({'health','actionPoints','guard','casting'})do assert(record:HasField(field))end
    end
    beforeRevision=records.Revision
    local initial=assert(adventure.inspection:Build(target.key,actor.Id))
    assert(initial.revealedCount==4 and initial.canObserve)
    for _,skill in ipairs(initial.skills)do assert(not skill.known and skill.title==L.InspectionUnknown)end
    assert(panel.view.Attributes.DefaultText:find(L.InspectionUnknown,1,true) and panel.view.Traits.DefaultText:find(L.InspectionUnknown,1,true))
    assert(panel.view.Observe.interactable and #panel.rows==#rows)
    CaptureUnitDetails(panel.reference,'unknown')
    InspectUnitDetails(panel.reference,'unknown')
    panel.view.NextObserver.onClick:Invoke();assert(panel.observerId==2)
    panel.view.PreviousObserver.onClick:Invoke();assert(panel.observerId==1)
    assert(records.Revision==beforeRevision and data.Narrative.Minutes==beforeTime,'Changing observer mutated knowledge/time')
    panel.view.Observe.onClick:Invoke()
    assert(records.Count==encounteredCount and records:Find(target.key).Observed
        and data.Narrative.Minutes==beforeTime+5 and actor.AP==beforeAP)
    assert(not records:Find(rows[4].key).Observed,'Observing one target consumed another target\'s attempt')
    assert(not panel.view.Observe.interactable and panel.view.Result.DefaultText~=L.InspectionUnobserved)
    local revision=records.Revision
    panel.view.Observe.onClick:Invoke()
    assert(records.Revision==revision and data.Narrative.Minutes==beforeTime+5,'Duplicate callback rerolled or charged')
    panel.view.Close.onClick:Invoke()
    assert(not ui:IsOpen('UnitDetails') and not Services.UI.IsWorldPaused and not InspectionInputOpen())
    panel=ui:Open('UnitDetails',{demo=InspectionDemo,key=target.key})
    assert(not panel.view.Observe.interactable and records.Revision==revision and data.Narrative.Minutes==beforeTime+5)
    CaptureUnitDetails(panel.reference,'observed')
    messages[#messages+1]='PASS native resource discovery, masked unused skills, free open/observer selection, real exploration clock cost, duplicate callback and cached reopen'
    panel.rows[1].view.Button.onClick:Invoke()
    assert(panel.targetKey==rows[1].key and not panel.view.Observe.interactable)
    assert(not panel.view.Attributes.DefaultText:find(L.InspectionUnknown,1,true) and not panel.view.Traits.DefaultText:find(L.InspectionUnknown,1,true))
    CaptureUnitDetails(panel.reference,'owned');InspectUnitDetails(panel.reference,'owned')
    panel.view.Close.onClick:Invoke()
    assert(not Services.UI.IsWorldPaused and not InspectionInputOpen())
    messages[#messages+1]='PASS real target widget selection, owned full details, independently scrollable attributes/traits and input/pause release'
    data:BeginEvent(1,1);data:ResolveChoice(1);data:BeginBattle()
    battle.data:Reset(1,10);battle.data:AddUnit(actor,1,0,0);battle.data:AddUnit(second,1,1,0)
    battle.data:AddUnit(rows[4].actor,2,3,0);battle.data:AddUnit(rows[5].actor,2,4,0)
    battle.data:BeginDeployment();battle.data:AddTurn(actor.Id);battle.data:SelectTurn(0);actor:BeginDeploymentTurn(4)
    panel=ui:Open('UnitDetails',{demo=InspectionDemo,key=rows[4].key})
    beforeTime=data.Narrative.Minutes;beforeAP=actor.AP;beforeRevision=records.Revision
    assert(not panel.view.PreviousObserver.interactable and not panel.view.NextObserver.interactable and panel.view.Observe.interactable)
    assert(records.Revision==beforeRevision and actor.AP==beforeAP,'Deployment open consumed resources')
    panel.view.Observe.onClick:Invoke()
    assert(actor.AP==beforeAP-1 and actor.Moved and not actor.MainUsed and data.Narrative.Minutes==beforeTime
        and records.Count==encounteredCount and records:Find(rows[4].key).Observed)
    panel.view.Close.onClick:Invoke()
    battle.data:BeginRound();battle.data:AddTurn(actor.Id);battle.data:SelectTurn(0);actor:BeginTurn(4)
    panel=ui:Open('UnitDetails',{demo=InspectionDemo,key=rows[5].key})
    panel.view.Observe.onClick:Invoke()
    assert(actor.AP==3 and actor.Moved and not actor.MainUsed and data.Narrative.Minutes==beforeTime
        and records.Count==encounteredCount and records:Find(rows[5].key).Observed)
    CaptureUnitDetails(panel.reference,'combat')
    local finalRevision=records.Revision
    ui:OnSceneChanged();assert(not Services.UI.IsWorldPaused and not InspectionInputOpen())
    assert(records.Revision==finalRevision)
    messages[#messages+1]='PASS actual deployment/combat secondary 1 AP, no exploration time cost in battle and scene-close cleanup'
end,debug.traceback)
ui:OnShutdown();battle:OnShutdown();config:OnShutdown()
if not ok then error(err,0)end
return table.concat(messages,'\n')
