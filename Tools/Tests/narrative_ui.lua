local registry=require('Core.SystemRegistry')(Services)
require('Game.Systems')(registry)
function CloseNarrativePreview() registry:Shutdown();PreviewNarrativePage=nil;NarrativePreviewActors=nil end
registry:Start()
local adventure,story,ui=registry:Get('Adventure'),registry:Get('Narrative'),registry:Get('UI')
adventure:Start(nil,story.rules.settings.demoRecipeId)
assert(adventure:EnterSite(story.npcs.locations[1]))
local localId
for _,npc in ipairs(adventure.areas:ActiveLayout().npcs) do if npc.narrativeId==1 then localId=npc.id end end
assert(localId)
local adapter={MainHudFont=PreviewNarrativeFont,LastError='',BattleHUDRevision=0,cameraCalls=0}
function adapter:SetStoryOpen(value) self.open=value end
function adapter:SetDialogueCamera(actor,npc,shot) assert(actor>0 and npc==localId);self.cameraCalls=self.cameraCalls+1;self.shot=shot end
function adapter:EndDialogueCamera() self.returned=true end
function adapter:SendCommand(command,a,b,c)
    local ok,reason
    if command=='dialogue_choose' then ok,reason=story.dialogue:Choose(a,b)
    elseif command=='dialogue_interject' then ok,reason=story.dialogue:Interject(a,b,c)
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
local firstCount=story.data.LineCount
assert(panel.choices[1].view.Button.interactable)
panel.choices[1].view.Button.onClick:Invoke();panel:Tick()
assert(story.data:Status('mission',100)=='active' and story.data.DialogueNodeId==2 and story.data.LineCount==firstCount+2)
ui:Close('Dialogue');assert(not Services.UI.IsWorldPaused and not story.data.DialogueOpen and adapter.returned)
panel=openDialogue();assert(story.data.LineCount==firstCount,'Cached panel must not retain old transcript')
ui:Close('Dialogue')
local second=adventure.data:GetPartyAt(1);second:AddTrait(3)
adventure.data:Record('battle','预览中的共同战斗','仅用于独立验证的经历','验证场景',0,0,0,true)
panel=openDialogue()
assert(story.data.LineCount==3 and story.data:GetLineAt(1).ActorId==adventure.data:GetPartyAt(0).Id and story.data:GetLineAt(2).ActorId==second.Id)
assert(panel.choices[2].row.kind=='invite' and panel.choices[2].view.Button.interactable)
local oldAction=panel.choices[1].action
panel.choices[2].view.Button.onClick:Invoke();panel:Tick()
assert(story.data.DialogueNodeId==4156 and story.data:GetLineAt(3).ActorId==second.Id and story.data:GetLineAt(3).Cue~='')
local afterCount=story.data.LineCount;oldAction();assert(story.data.LineCount==afterCount,'Stale invite must not append dialogue')
adapter.LastError=''
panel.view.Scroll.verticalNormalizedPosition=1
local scrollBefore=panel.view.Scroll.verticalNormalizedPosition
adapter.BattleHUDRevision=adapter.BattleHUDRevision+1;panel:Tick()
assert(math.abs(panel.view.Scroll.verticalNormalizedPosition-scrollBefore)<.001,'Unrelated refresh must preserve history scroll')
ui:Close('Dialogue');assert(story.data.LineCount==0 and not story.data:HasDialogueInterjection(2),'Session state must clear')
local journal=ui:Open('MissionJournal',{demo=adapter})
assert(journal.selected==100 and journal.missionRows[1].view.Body.DefaultText:find('进行中',1,true))
journal.tabs[1].view.Button.onClick:Invoke()
assert(journal.selected==nil and journal.view.DetailTitle.DefaultText=='暂无任务')
journal.tabs[3].view.Button.onClick:Invoke();assert(journal.selected==100)
story.data:Ready('quest',101);story.data:Complete('quest',101);journal:Tick()
local completed
for _,entry in ipairs(journal.pool) do if entry.row and entry.view.Title.DefaultText:find('<s>',1,true) then completed=entry;break end end
assert(completed and not completed.view.Body.gameObject.activeSelf,'Completed quest uses TMP strike-through and collapses its details')
journal.view.Companions.onClick:Invoke();assert(journal.showCompanions and journal.pool[1].row.title:find('莱雅',1,true))
ui:Close('MissionJournal')
function PreviewNarrativePage(mode)
    ui:Close('Dialogue');ui:Close('MissionJournal')
    if mode=='dialogue' then second:RemoveTrait(3);openDialogue()
    else ui:Open('MissionJournal',{demo=adapter}) end
end
function NarrativePreviewPanelFraction()return ui.panels.Dialogue.ctrl.view.Style.PanelFraction end
function NarrativePreviewActors()
    local player=adventure:Snapshot().party[1]
    local template=adventure.config:GetTable('MapAreaTownNpcTable'):Get(story.rules.npcs:Get(1).townTemplateId)
    return {player.appearance,{templateId=template.id,parts=adventure.appearances:Resolve(template.partIds)}}
end
return 'PASS real narrative panels: bindings, choices, transcript, four category tabs, empty state, completed quest presentation, companions, pause release, cached reopen and camera lifecycle calls'
