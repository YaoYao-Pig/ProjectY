-- Actual HUD controller callbacks; presentation adapters only, no game state or Unity activity.
package.path='Lua/?.lua;'..package.path
local Model=require('Game.Battle.BattleHUDModel')
local originalPresenter=package.loaded['UI.SkillTipPresenter']
package.loaded['UI.SkillTipPresenter']={New=function()return {Hide=function()end}end}
local original=Model.Build
local model={actorId=1,phase='combat',player=true,round=1,maxRounds=18,encounter='Test',moveRemaining=3,
    moved=false,moveAvailable=true,skills={},items={},party={},turns={},logs={}}
for i=1,80 do model.logs[i]='<color=#70B8E8><size=16>Actor '..i..'</size></color> → <color=#EF8D85>Target</color> <b>12</b> · 75%' end
Model.Build=function()return model end
local projection
CS={ProjectY={Samples={BattleTargetSelection={Active=function()return false end,NeedsLanding=function()return false end,Hint=function()return ''end}},
    UI={BattleLogPresentation={Set=function(view,expanded,recent,full,count)
        projection={view=view,expanded=expanded,recent=recent,full=full,count=count}
    end}}}}
local function node()
    return {text='',gameObject={activeSelf=true,SetActive=function(self,value)self.activeSelf=value end}}
end
local view={HUD={Prepare=function()end,Compact=false},SkillSlots={},ItemSlots={},PartySlots={},TurnSlots={}}
for _,key in ipairs({'EndTurn','Move','Focus','Auto','LogToggle','LogOpen','LogClose','Previous','Next','Encounter','Round','SkillTitle','ItemTitle',
    'EndTurnText','MoveText','FocusText','AutoText','LogToggleText','Hint','Tooltip'})do view[key]=node()end
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
function controller:AddWidget()
    return {Configure=function()end,SetItemCount=function()end,GetVisibleRange=function()return 1,0 end}
end
local demo={BattleHUDRevision=1,LastError='',SelectedBattleSkill=0,IsBattleMoveSelected=true,BattleAutoAI=false}
controller:Bind();controller:OnShow({demo=demo})
assert(not projection.expanded and projection.count==80)
assert(projection.full==table.concat(model.logs,'\n\n') and projection.recent==table.concat({model.logs[78],model.logs[79],model.logs[80]},'\n\n'))
assert(view.LogToggleText.text=='展开战斗记录')
callbacks[view.LogOpen]();assert(controller.dirty);controller:Refresh()
assert(projection.expanded and projection.full:find(model.logs[1],1,true) and view.LogToggleText.text=='收起战斗记录')
callbacks[view.LogClose]();controller:Refresh();assert(not projection.expanded)
callbacks[view.LogToggle]();controller:Refresh();assert(projection.expanded)
local oldFirst=model.logs[1];table.remove(model.logs,1);model.logs[80]='<size=18><color=#79D9A7>New result</color></size> · 35%'
controller:Refresh()
assert(projection.expanded and projection.count==80 and not projection.full:find(oldFirst,1,true) and projection.full:find(model.logs[80],1,true))
assert(projection.recent==table.concat({model.logs[78],model.logs[79],model.logs[80]},'\n\n'),'UI must preserve supplied rich text verbatim')
view.HUD.Compact=true;controller:Refresh();assert(projection.expanded,'Compact layout must not force an explicitly opened log closed')
controller:OnHide();controller:OnShow({demo=demo});assert(not projection.expanded,'Cached reopen should start compact')
Model.Build=original
package.loaded['UI.SkillTipPresenter']=originalPresenter
print('PASS log card/toggle expand and close callbacks; all 80 rich-text records, three-row summary, small-screen expansion and cached reopen')
