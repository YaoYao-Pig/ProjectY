-- Real HUD controller with native selection/input at the boundary; no Editor activity.
package.path='Lua/?.lua;'..package.path
local Model=require('Game.Battle.BattleHUDModel')
package.loaded['UI.SkillTipPresenter']={New=function()return {Hide=function()end}end}
local model={actorId=1,phase='combat',player=true,round=1,maxRounds=18,encounter='Test',moveRemaining=3,
    moved=false,moveAvailable=true,castingPoints=0,castingPointMax=0,castingPointRegen=0,skills={},items={},party={},turns={},logs={}}
Model.Build=function()return model end
local choosing,selected,confirmed,cancelled=false,false,{},0
local names={'Head','Torso','Left arm','Right arm','Left leg','Right leg'}
local selection={Active=function()return selected end,NeedsLanding=function()return false end,NeedsBodyPart=function()return selected end,
    ChoosingBodyPart=function()return choosing end,Hint=function()return ''end,BodyPartTitle=function()return 'Target' end,
    Count=function()return choosing and 1 or 0 end,Limit=function()return 1 end,
    BodyPartName=function(_,part)return names[part+1] end,
    ChooseBodyPart=function(_,part)confirmed[#confirmed+1]=part end,
    Cancel=function()cancelled=cancelled+1;selected=false;choosing=false end}
CS={ProjectY={Samples={BattleTargetSelection=selection},UI={BattleLogPresentation={Set=function()end}}}}
local function node()return {text='',gameObject={activeSelf=true,SetActive=function(self,value)self.activeSelf=value end}}end
local view={HUD={Prepare=function()end},SkillSlots={},ItemSlots={},PartySlots={},TurnList={},TurnTemplate={}}
for _,key in ipairs({'EndTurn','Move','Focus','Auto','LogToggle','LogOpen','LogClose','Previous','Next','Encounter','Round','SkillTitle','ItemTitle',
    'EndTurnText','MoveText','FocusText','AutoText','LogToggleText','Hint','Tooltip',
    'CastingPanel','CastingStatus','CastingDetail','CastingLess','CastingMore','CastingLessText','CastingMoreText',
    'AnatomyPanel','AnatomyTitle','AnatomyHelp','SkillControls','ItemControls'})do view[key]=node()end
for part=0,5 do view['AnatomyPart'..part]=node();view['AnatomyPart'..part..'Text']=node()end
local battle={Changed={Subscribe=function()return{}end}}
local config={GetTable=function(_,name)
    if name=='BattleHUDTable' then return {Get=function()return {itemIconIds={1,1,1,1}}end}end
    assert(name=='BattleIconTable');return {Get=function()return {}end}
end}
local HUD=require('UI.Widget.BattleHUDContent')
local controller=setmetatable({view=view,context={services={Adventure={}},systems={Get=function(_,name)return name=='Battle' and battle or config end}},
    visibleScope={Add=function()end}},{__index=HUD})
local callbacks={}
function controller:Listen(button,fn)assert(not callbacks[button]);callbacks[button]=fn end
function controller:CreateWidget()return {Initialize=function()end,SetData=function()end}end
function controller:AddWidget()return {Configure=function()end,SetItemCount=function()end,GetVisibleRange=function()return 1,0 end}end
local demo={BattleHUDRevision=1,LastError='',SelectedBattleSkill=0,IsBattleMoveSelected=false,BattleAutoAI=false}
controller:Bind();controller:OnShow({demo=demo})
assert(not view.AnatomyPanel.gameObject.activeSelf and view.SkillControls.gameObject.activeSelf)
selected=true;demo.SelectedBattleSkill=2601;controller:Refresh()
assert(not view.EndTurn.interactable and not view.AnatomyPanel.gameObject.activeSelf and #confirmed==0,
    'Choosing a precision skill must wait for a target without committing an attack')
choosing=true;controller:Refresh()
assert(view.AnatomyPanel.gameObject.activeSelf and not view.SkillControls.gameObject.activeSelf and not view.ItemControls.gameObject.activeSelf)
assert(view.AnatomyTitle.text=='Target' and not view.EndTurn.interactable and view.Move.interactable)
for part=0,5 do
    assert(view['AnatomyPart'..part].interactable and view['AnatomyPart'..part..'Text'].text==names[part+1])
    callbacks[view['AnatomyPart'..part]]();assert(confirmed[#confirmed]==part,'Each button must submit its own stable body index')
end
names[3]='';controller:Refresh()
assert(not view.AnatomyPart2.gameObject.activeSelf and not view.AnatomyPart2.interactable,'Unavailable body parts must not be offered')
callbacks[view.Move]();controller:Refresh()
assert(cancelled==1 and not view.AnatomyPanel.gameObject.activeSelf and view.SkillControls.gameObject.activeSelf and view.ItemControls.gameObject.activeSelf)
selected=true;choosing=true;model.player=false;controller:Refresh()
for part=0,5 do assert(not view['AnatomyPart'..part].interactable)end
print('PASS precision target/body stages, six stable indices, unavailable body filtering, cancellation and player-turn gating')
