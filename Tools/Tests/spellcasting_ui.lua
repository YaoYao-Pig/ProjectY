-- Real HUD controller; resource/selection adapters are boundary doubles, no Editor activity.
package.path='Lua/?.lua;'..package.path
local Model=require('Game.Battle.BattleHUDModel')
package.loaded['UI.SkillTipPresenter']={New=function()return {Hide=function()end}end}
local model={actorId=1,phase='combat',player=true,round=1,maxRounds=18,encounter='Test',moveRemaining=3,
    moved=false,moveAvailable=true,castingPoints=4,castingPointMax=6,castingPointRegen=1,skills={},items={},party={},turns={},logs={}}
local skill={id=511,name='Test spell',castingCost=2,castingBoost=0,castingBoostLimit=3}
model.skills={{id=511,skill=skill,iconId=1,available=true}}
Model.Build=function()return model end
CS={ProjectY={Samples={BattleTargetSelection={Active=function()return false end,NeedsLanding=function()return false end,
    NeedsBodyPart=function()return false end,ChoosingBodyPart=function()return false end,Hint=function()return ''end}},
    UI={BattleLogPresentation={Set=function()end}}}}
local function node()return {text='',gameObject={activeSelf=true,SetActive=function(self,value)self.activeSelf=value end}}end
local view={HUD={Prepare=function()end},SkillSlots={},ItemSlots={},PartySlots={},TurnList={},TurnTemplate={}}
for _,key in ipairs({'EndTurn','Move','Focus','Auto','LogToggle','LogOpen','LogClose','Previous','Next','Encounter','Round','SkillTitle','ItemTitle',
    'EndTurnText','MoveText','FocusText','AutoText','LogToggleText','Hint','Tooltip',
    'CastingPanel','CastingStatus','CastingDetail','CastingLess','CastingMore','CastingLessText','CastingMoreText',
    'AnatomyPanel','AnatomyTitle','AnatomyHelp','SkillControls','ItemControls'})do view[key]=node()end
for part=0,5 do view['AnatomyPart'..part]=node();view['AnatomyPart'..part..'Text']=node()end
local calls,commands,fail=0,0,false
local battle={Changed={Subscribe=function()return{}end},SetCastingBoost=function(_,id,extra)
    assert(id==511);calls=calls+1
    if fail then return false,'Unavailable' end
    skill.castingBoost=extra;skill.castingCost=2+extra;return true
end}
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
local demo={BattleHUDRevision=1,LastError='',SelectedBattleSkill=511,IsBattleMoveSelected=false,BattleAutoAI=false,
    SendCommand=function(_,command)assert(command=='snapshot');commands=commands+1 end}
controller:Bind();controller:OnShow({demo=demo})
assert(view.CastingPanel.gameObject.activeSelf and not view.CastingLess.interactable and view.CastingMore.interactable)
callbacks[view.CastingMore]();controller:Refresh()
assert(calls==1 and commands==1 and skill.castingCost==3 and model.castingPoints==4,'Selection must refresh snapshot without spending resources')
callbacks[view.CastingMore]();controller:Refresh()
assert(not view.CastingMore.interactable and view.CastingLess.interactable,'Cannot strengthen above available resource')
fail=true;callbacks[view.CastingLess]();controller:Refresh()
assert(view.Hint.text=='Unavailable' and commands==2 and skill.castingBoost==2,'Rule rejection must preserve strength and display its reason')
fail=false;callbacks[view.CastingLess]();controller:Refresh();assert(skill.castingBoost==1 and controller.castingError==nil)
model.player=false;controller:Refresh();assert(not view.CastingLess.interactable and not view.CastingMore.interactable)
local before=calls;controller:AdjustCasting(1);assert(calls==before,'Enemy turns must not change strength')
model.player=true;demo.SelectedBattleSkill=0;controller:Refresh();assert(not view.CastingLess.interactable and not view.CastingMore.interactable)
demo.SelectedBattleSkill=511;skill.castingCost=nil;controller:Refresh();assert(controller.castingSkill==nil,'Non-spell skills must not expose strength controls')
model.phase='deployment';controller:Refresh();assert(not view.CastingPanel.gameObject.activeSelf)
model.phase='combat';model.castingPointMax=0;model.castingPoints=0;controller:Refresh();assert(not view.CastingPanel.gameObject.activeSelf)
print('PASS casting strength selection, no premature spend, affordability, rule rejection, enemy/selection gating and non-caster/deployment hiding')
