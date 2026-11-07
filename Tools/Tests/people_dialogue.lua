-- Production person-session routing and existing Dialogue panel; only native state/views are isolated.
package.path='Lua/?.lua;'..package.path
local L=require('Language')
for _,key in ipairs({'PeopleDialogueTalk','PeopleDialogueTalkOwned','PeopleDialogueTalkOther','PeopleDialogueInspectionHint',
    'PeopleDialogueHint','PeopleDialogueBusy','PeopleDialogueUnavailable','PeopleDialogueLivingActor','PeopleDialogueStale',
    'PeopleDialogueLeave','PeopleDialogueNoInterjection'})do
    assert(type(L[key])=='string' and L[key]~='','Missing person dialogue language key: '..key)
end
local data={DialogueOpen=false,DialogueVersion=0,Revision=0,LineCount=0,lines={},key=''}
function data:AddDialogueLine(speaker,text,choice)
    assert(self.DialogueOpen and type(speaker)=='string' and speaker~='' and type(text)=='string' and text~='')
    self.lines[#self.lines+1]={Speaker=speaker,Text=text,IsChoice=choice,ActorId=0,Cue=''}
    self.LineCount=#self.lines;self.Revision=self.Revision+1
end
function data:GetLineAt(index)return assert(self.lines[index+1])end
function data:CloseDialogue()
    self.DialogueOpen=false;self.key='';self.DialogueId=0;self.DialogueNodeId=0;self.DialogueNpcId=0
    self.DialogueLocalNpcId=0;self.DialogueActorId=0;self.lines={};self.LineCount=0
    self.DialogueVersion=self.DialogueVersion+1;self.Revision=self.Revision+1
end
local state={}
function state.Key(value)return value.DialogueId==-2 and value.key or '' end
function state.Begin(value,key,actorId,localId)
    assert(not value.DialogueOpen and key~='' and actorId>0 and localId>=0)
    value.key=key;value.DialogueOpen=true;value.DialogueId=-2;value.DialogueNodeId=0
    value.DialogueNpcId=0;value.DialogueLocalNpcId=localId;value.DialogueActorId=actorId
    value.DialogueVersion=value.DialogueVersion+1;value.Revision=value.Revision+1
end
function state.Touch(value)assert(value.DialogueId==-2);value.DialogueVersion=value.DialogueVersion+1;value.Revision=value.Revision+1 end
CS={ProjectY={Data={PeopleDialogueSession=state}},UnityEngine={VerticalWrapMode={Truncate=0},
    Canvas={ForceUpdateCanvases=function()end},UI={LayoutRebuilder={ForceRebuildLayoutImmediate=function()end}}}}
local area={SiteId=7,InteractionKind=2,InteractionId=3}
local adventure={data={Narrative=data,Phase='area',Areas={Active=area}},allowed=true,living=true,acts=0,ensures=0,syncs=0}
local person={Key='resident:7:30',Actor={Id=500000030},Joined=false,OriginKind='resident'}
function person:Meet()local fresh=not self.Known;self.Known=true;return fresh end
local target={key=person.Key,actor=person.Actor}
adventure.inspection={targets={Find=function(_,key)return key==target.key and target or nil end}}
adventure.events={LivingParty=function()return adventure.living and {{Id=1,HP=10}} or {}end}
adventure.areas={Stop=function()adventure.stopped=true end,CloseInteraction=function()adventure.closedInteraction=true end}
function adventure.areas:Interact(kind,id)assert(kind==2 and id==3);area.InteractionKind=kind;area.InteractionId=id;return true end
adventure.travel={data={SetPaused=function(_,paused)assert(paused);adventure.paused=true end}}
adventure.people={}
function adventure.people:Find(key)return key==person.Key and person or nil end
function adventure.people:CanOpen(key)return key==target.key and adventure.allowed,L.PeopleDialogueUnavailable end
function adventure.people:EnsureTarget(row)assert(row==target);adventure.ensures=adventure.ensures+1;return person end
function adventure.people:EnsureResident(definition,siteId)assert(definition.stableId==30 and siteId==7);return person end
function adventure.people:ResidentDefinition(row)assert(row==person);return {id=3,stableId=30}end
function adventure.people:CanTalk(row)assert(row==person);return adventure.allowed,L.PeopleDialogueUnavailable end
function adventure.people:Describe(row)assert(row==person);return {name='Resident',caption='A life in the border town',opening='A new meeting'}end
function adventure.people:Options(row)
    assert(row==person)
    local rows={{id=1,text='Discuss training',available=true,reason=''},
        {id=2,text='Join the party',available=not person.Joined and adventure.recruitable==true,reason='Resolve the obligation'}}
    if adventure.commissions then rows[#rows+1]={id=12,text='Discuss commission',available=true,reason=''}end
    return rows
end
function adventure.people:Act(row,id)
    if id==12 then assert(row==person and adventure.commissions);return true,nil,'commissions'end
    assert(row==person and (id==1 or id==2));adventure.acts=adventure.acts+1
    if id==2 then person.Joined=true end
    return true,id==2 and 'I will join you' or 'We have a plan'
end
local forbidden={Get=function()error('Person session queried a configured NPC, faction, dialogue, node or choice')end}
local story={adventure=adventure,data=data,npcs={SyncPresence=function()adventure.syncs=adventure.syncs+1 end},
    rules={settings={playerSpeaker='Player'},npcs=forbidden,factions=forbidden,dialogues=forbidden,nodes=forbidden,
        choices=forbidden,interjections=forbidden,cameras={Get=function(_,id)assert(id==1);return {panelWidth=500}end}}}
adventure.narrative=story
adventure.peopleDialogue=require('Game.Narrative.PeopleDialogue').New(adventure)
story.dialogue=require('Game.Narrative.Dialogue').New(story)
local people=adventure.peopleDialogue
local function choose(id)return story.dialogue:Choose(id,data.DialogueVersion)end
assert(not people:OpenTarget('absent') and adventure.ensures==0,'Invalid targets must not create records')
adventure.allowed=false;assert(not people:OpenTarget(person.Key) and adventure.ensures==0)
adventure.allowed=true;adventure.living=false;assert(not people:OpenTarget(person.Key) and not data.DialogueOpen and not person.Known)
adventure.living=true
assert(people:OpenResident({stableId=30},3) and data.DialogueId==-2 and data.DialogueNpcId==0 and data.DialogueLocalNpcId==3)
assert(person.Known and adventure.stopped and people:Title()=='Resident' and people:Caption()=='A life in the border town')
assert(not people:OpenTarget(person.Key) and #story.dialogue:Interjections()==0)
assert(not story.dialogue:Interject(1,1,data.DialogueVersion),'Configured interjections cannot execute in a person session')
assert(not choose(2) and adventure.acts==0,'Unavailable actions preserve the person')
local oldVersion=data.DialogueVersion
assert(choose(1) and adventure.acts==1 and data.LineCount==3)
assert(not story.dialogue:Choose(1,oldVersion) and adventure.acts==1,'Stale callbacks cannot mutate a person twice')
assert(not choose(100) and adventure.acts==1,'Unknown ids cannot enter narrative config actions')
adventure.commissions=true;adventure.closedInteraction=false
assert(choose(12) and not data.DialogueOpen and not adventure.closedInteraction and area.InteractionId==3,
    'Commission navigation closes only the dialogue and preserves the validated publisher interaction')
adventure.commissions=false;assert(people:OpenTarget(person.Key) and data.DialogueLocalNpcId==3)
adventure.recruitable=true;assert(choose(2) and person.Joined and adventure.acts==2)
assert(not choose(2) and adventure.acts==2,'Completed recruitment is no longer actionable')
adventure.allowed=false
local choices=story.dialogue:Choices()
assert(#choices==1 and choices[1].available and choices[1].reason==L.PeopleDialogueUnavailable)
assert(choose(choices[1].id) and not data.DialogueOpen and data.key=='' and adventure.closedInteraction and adventure.syncs==2)
adventure.allowed=true;adventure.data.Phase='map';assert(people:OpenTarget(person.Key) and adventure.paused)
assert(data.DialogueLocalNpcId==0 and data.DialogueActorId==1)

local panel=setmetatable({story=story,pool={},choices={},view={Title={fontSize=25},Caption={},Hint={},Content={},Choices={},ChoiceScroll={},Style={}}},
    require('UI.Panel.DialogueCtr'))
local demo={LastError='',MainHudFont={},BattleHUDRevision=1}
function demo:SetStoryOpen(value)self.storyOpen=value end
function demo:SetDialogueCamera()error('Person session attempted configured NPC camera focus')end
function demo:EndDialogueCamera()self.ended=true end
function demo:SendCommand(command,id,version)assert(command=='dialogue_choose');self.lastResult=story.dialogue:Choose(id,version)end
function panel.view.Style:Prepare(font,width)assert(font==demo.MainHudFont and width==500)end
function panel.view.Style:ScrollToEnd()self.scrolled=true end
function panel:CreateWidget(name,parent)
    assert(name=='DialogueEntry' and (parent==self.view.Content or parent==self.view.Choices))
    return {SetData=function(widget,row,font,action)widget.row=row;widget.action=action end}
end
panel:OnShow({demo=demo})
assert(demo.storyOpen and panel.view.Title.text=='Resident' and panel.view.Hint.text==L.PeopleDialogueHint)
assert(#panel.choices==3 and panel.choices[1].row.kind=='choice' and not panel.choices[2].row.available)
local callback=panel.choices[1].action
callback();assert(demo.lastResult);panel:Tick();assert(panel.view.Style.scrolled and panel.lineCount==data.LineCount)
callback();assert(not demo.lastResult,'Rendered buttons retain the original version')
panel:OnHide();assert(not data.DialogueOpen and not demo.storyOpen and demo.ended)
assert(people:OpenTarget(person.Key));panel:OnShow({demo=demo});panel:OnHide()
assert(not data.DialogueOpen and data.LineCount==0 and state.Key(data)=='','Cached panel reopen and teardown clean all transient state')
person.Joined=false;person.OriginKind='world';adventure.parties={data={ContactId=72}}
assert(people:OpenTarget(person.Key) and data.DialogueLocalNpcId==72,'World conversation retains the validated contact before its panel closes')
adventure.parties.data.ContactId=0
assert(data.DialogueLocalNpcId==72 and people:Active(),'Closing the world panel must not discard the conversation source')
assert(story.dialogue:Close());person.Joined=true;person.OriginKind='resident'

-- The details panel keeps scouting and talking as distinct inputs with the same selected identity.
local inspection=adventure.inspection;local observations=0
person.Actor.Growth={CurrentProfessionId=0};person.Actor.InitialProfessionId=0
target.name='Resident';target.owned=false
function inspection:Targets()return {target}end
function inspection:Observers()return {{id=1,name='Player'}}end
function inspection:Build(key)
    assert(key==target.key)
    return {canObserve=observations==0,owned=target.owned,cost='',result='',reason='',observerName='Player',attributes={},traits={}}
end
function inspection:Observe(key,observerId)assert(key==target.key and observerId==1);observations=observations+1;return true end
adventure.battle={stats={Template=function()return {name='Resident'}end,titles={Equipped=function()return nil end}}}
CS.ProjectY.Samples={UnitInspectionInput={SetOpen=function(host,value)host.inspectionOpen=value end}}
local view={Style={Prepare=function()end}}
for _,key in ipairs({'Close','Talk','TalkText','Observe','PreviousObserver','NextObserver','TargetRows','TargetScroll','AttributeScroll',
    'TraitScroll','TargetName','Cost','Result','Reason','ObserverLabel','Attributes','Traits','Subtitle'})do view[key]={}end
local inspectDemo={SelectedCharacterId=1,MainHudFont={},snapshots=0}
function inspectDemo:SendCommand(command)assert(command=='snapshot');self.snapshots=self.snapshots+1 end
local details=setmetatable({context={systems={Get=function(_,name)assert(name=='Adventure');return adventure end}},view=view,callbacks={}},
    require('UI.Panel.UnitDetailsCtr'))
function details:Listen(button,callback)self.callbacks[button]=callback end
function details:CreateWidget(name,parent)
    assert(name=='InspectionTarget' and parent==view.TargetRows)
    return {SetData=function(widget,row,selected,action)widget.row=row;widget.action=action end}
end
function details:Close()self.closed=true;self:OnHide()end
details:Bind();details:OnShow({demo=inspectDemo,key=target.key})
assert(inspectDemo.inspectionOpen and observations==0 and view.Observe.interactable and view.Talk.interactable)
assert(view.TalkText.DefaultText==L.PeopleDialogueTalkOther and view.Subtitle.DefaultText==L.PeopleDialogueInspectionHint)
details.callbacks[view.Observe]()
assert(observations==1 and not view.Observe.interactable and not data.DialogueOpen,'Scout keeps its original effect and never starts dialogue')
adventure.allowed=false;details:Refresh();assert(not view.Talk.interactable and view.Subtitle.DefaultText==L.PeopleDialogueUnavailable)
details.callbacks[view.Talk]()
assert(not details.closed and not data.DialogueOpen and observations==1,'A stale talk click must remain on details with a reason')
adventure.allowed=true;target.owned=true;details:Refresh()
assert(view.TalkText.DefaultText==L.PeopleDialogueTalkOwned)
details.callbacks[view.Talk]()
assert(details.closed and not inspectDemo.inspectionOpen and data.DialogueOpen and state.Key(data)==person.Key and observations==1)
assert(inspectDemo.snapshots==2,'Successful talk closes details through the original snapshot/input cleanup')
assert(story.dialogue:Close())

-- Exercise the real UISystem close order: details OnHide requests a snapshot, which opens Dialogue.
-- A later SetVisible(details,false) must not hide or close that newly opened conversation.
local ui=require('UI.UISystem')()
local definitions={UnitDetails={Layer='Popup',Modal=true,Cache=true},Dialogue={Layer='Popup',Modal=true,Cache=true}}
local host={SceneVersion=0,visible={}}
function host:GetConfig(name)return assert(definitions[name])end
function host:SetVisible(reference,value)self.visible[reference]=value end
function host:SetOrder()end
function host:SetInteractable()end
local context={services={UI=host},log=function(message)error(message,0)end}
context.systems={Get=function(_,name)return assert(({UI=ui,Adventure=adventure})[name])end}
ui:OnInit(context)
details.context=context;details.panelName='UnitDetails';details.widgets={};details.visible=true;details.Close=nil
panel.context=context;panel.panelName='Dialogue';panel.widgets={};panel.visible=false
local detailEntry={name='UnitDetails',ctrl=details,view=view,definition=definitions.UnitDetails,sequence=1}
ui.panels.UnitDetails=detailEntry
ui.panels.Dialogue={name='Dialogue',ctrl=panel,view=panel.view,definition=definitions.Dialogue}
ui.opened={detailEntry};ui.sequence=1;host.visible[view]=true
inspectDemo.LastError='';inspectDemo.BattleHUDRevision=2
inspectDemo.SetStoryOpen=demo.SetStoryOpen;inspectDemo.SetDialogueCamera=demo.SetDialogueCamera;inspectDemo.EndDialogueCamera=demo.EndDialogueCamera
function inspectDemo:SendCommand(command)
    assert(command=='snapshot')
    if data.DialogueOpen and not ui:IsOpen('Dialogue')then ui:Open('Dialogue',{demo=self})end
end
panel.view.Style.Prepare=function(_,font,width)assert(font==inspectDemo.MainHudFont and width==500)end
details:OnShow({demo=inspectDemo,key=target.key})
details.callbacks[view.Talk]()
assert(not ui:IsOpen('UnitDetails') and ui:IsOpen('Dialogue') and data.DialogueOpen and inspectDemo.storyOpen)
assert(host.visible[view]==false and host.visible[panel.view]==true,'Closing details must leave the freshly opened conversation visible')
ui:Close('Dialogue');assert(not data.DialogueOpen and not inspectDemo.storyOpen)
print('PASS person dialogue: validated identity, locked/repeated/stale choices, NPC-free routing, callbacks, distinct talk/scout controls and real panel close/open ownership')
