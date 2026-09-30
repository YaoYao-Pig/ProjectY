local registry=require('Core.SystemRegistry')(Services)
require('Game.Systems')(registry)
function CloseNarrativePreview() registry:Shutdown();PreviewNarrativePage=nil;NarrativePreviewActors=nil end
registry:Start()
local adventure,story,ui=registry:Get('Adventure'),registry:Get('Narrative'),registry:Get('UI')
adventure:Start(nil,story.rules.settings.demoRecipeId)
assert(adventure:Visit(story.npcs.locations[1]))
local localId
for _,npc in ipairs(adventure.areas:ActiveLayout().npcs) do if npc.narrativeId==1 then localId=npc.id end end
assert(localId)
local adapter={MainHudFont=PreviewNarrativeFont,LastError='',BattleHUDRevision=0,cameraCalls=0}
function adapter:SetStoryOpen(value) self.open=value end
function adapter:SetDialogueCamera(actor,npc,shot) assert(actor>0 and npc==localId);self.cameraCalls=self.cameraCalls+1;self.shot=shot end
function adapter:EndDialogueCamera() self.returned=true end
function adapter:SendCommand(command,a,b)
    local ok,reason
    if command=='dialogue_choose' then ok,reason=story.dialogue:Choose(a,b)
    elseif command=='dialogue_close' then ok,reason=story.dialogue:Close();ui:Close('Dialogue')
    elseif command=='mission_accept' then ok,reason=story:Accept(a)
    elseif command=='mission_claim' then ok,reason=story:Claim('mission',a)
    else error('Unexpected narrative UI command') end
    self.LastError=ok and '' or reason;self.BattleHUDRevision=self.BattleHUDRevision+1
end
local function openDialogue()
    adventure.data.Areas.Active:SetInteraction(2,localId)
    assert(story.dialogue:Open(1,localId));return ui:Open('Dialogue',{demo=adapter})
end
local panel=openDialogue()
assert(adapter.open and Services.UI.IsWorldPaused and panel.view.Title.text=='莱雅' and adapter.cameraCalls>0)
assert(panel.choices[1].view.Button.interactable)
panel.choices[1].view.Button.onClick:Invoke();panel:Tick()
assert(story.data:Status('mission',100)=='active' and story.data.DialogueNodeId==2 and story.data.LineCount==3)
ui:Close('Dialogue');assert(not Services.UI.IsWorldPaused and not story.data.DialogueOpen and adapter.returned)
panel=openDialogue();assert(story.data.LineCount==1,'Cached panel must not retain old transcript')
ui:Close('Dialogue')
local journal=ui:Open('MissionJournal',{demo=adapter})
assert(journal.selected==100 and journal.missionRows[1].view.Body.DefaultText=='进行中')
journal.tabs[1].view.Button.onClick:Invoke()
assert(journal.selected==nil and journal.view.DetailTitle.DefaultText=='暂无任务')
journal.tabs[2].view.Button.onClick:Invoke();assert(journal.selected==100)
story.data:Ready('quest',101);story.data:Complete('quest',101);journal:Tick()
assert(not journal.pool[1].view.Body.gameObject.activeSelf,'Completed quest details collapse')
assert(journal.pool[1].view.Title.DefaultText:find('<s>',1,true),'Completed quest uses TMP strike-through')
journal.view.Companions.onClick:Invoke();assert(journal.showCompanions and journal.pool[1].row.title:find('莱雅',1,true))
ui:Close('MissionJournal')
function PreviewNarrativePage(mode)
    ui:Close('Dialogue');ui:Close('MissionJournal')
    if mode=='dialogue' then openDialogue()
    else ui:Open('MissionJournal',{demo=adapter}) end
end
function NarrativePreviewActors()
    local player=adventure:Snapshot().party[1]
    local template=adventure.config:GetTable('MapAreaTownNpcTable'):Get(story.rules.npcs:Get(1).townTemplateId)
    return {player.appearance,{templateId=template.id,parts=adventure.appearances:Resolve(template.partIds)}}
end
return 'PASS real narrative panels: bindings, choices, transcript, four category tabs, empty state, completed quest presentation, companions, pause release, cached reopen and camera lifecycle calls'
