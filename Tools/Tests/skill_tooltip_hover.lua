-- Actual HUD Tick and presenter; substitute only native view/input and the skill page projection.
package.path='Lua/?.lua;'..package.path
local time,cardHovered,lastInside,queued=0,false,0,''
local samples=0
local function node()
    return {gameObject={activeSelf=false,SetActive=function(self,value)self.activeSelf=value end}}
end
local view=node()
local bridge={}
function bridge.Begin()queued='' end
function bridge.AddTag()end
function bridge.AddStat()end
function bridge.AddSynergy()end
function bridge.SetNavigation()end
function bridge.Show()
    if not view.gameObject.activeSelf then lastInside=time end
    view.gameObject:SetActive(true)
end
function bridge.Hide()view.gameObject:SetActive(false);cardHovered=false end
function bridge.TakeLink()local id=queued;queued='';return id end
function bridge.KeepOpen(_,anchorHovered)
    samples=samples+1
    if not view.gameObject.activeSelf then return false end
    if anchorHovered or cardHovered then lastInside=time;return true end
    return time-lastInside<=.4
end
CS={ProjectY={UI={SkillTooltipPresentation=bridge},Samples={BattleTargetSelection={
    PreviewTitle=function()return ''end,PreviewBody=function()return ''end
}}}}
local Presenter=require('UI.SkillTipPresenter')
local model={Build=function(_,row)return {title=row.name,body='',tags={},stats={},synergies={},breadcrumb='Skill'}end,
    catalog={Term=function(_,id)return {title=id,body='Term description'}end}}
local presenter=setmetatable({view=view,model=model,stack={}},{__index=Presenter})
local function action(id)
    return {row={id=id,name='Skill '..id},view={Root={}},hovered=false,IsHovered=function(self)return self.hovered end}
end
local first,second,item=action(1),action(2),action(3)
local HUD=require('UI.Widget.BattleHUDContent')
local hud=setmetatable({visible=true,context={services={Adventure={Phase='battle'}}},
    demo={BattleHUDRevision=1},revision=1,actions={first,second},items={item},skillTip=presenter,
    view={Group={interactable=true},HUD={ReadShortcut=function()return 0 end},Tooltip=node()}},{__index=HUD})

first.hovered=true;hud:Tick()
assert(view.gameObject.activeSelf and hud.lastTooltip==first and #presenter.stack==1)
local previousSamples=samples
time=2;hud:Tick()
assert(samples>previousSamples,'Anchor hover must update the close deadline on every HUD Tick')
first.hovered=false;time=2.1;hud:Tick()
assert(view.gameObject.activeSelf,'A long skill hover must still allow crossing the gap')
time=2.5;hud:Tick()
assert(not view.gameObject.activeSelf and hud.lastTooltip==nil and #presenter.stack==0,
    'Moving to empty game space must close the card and navigation')

first.hovered=true;time=3;hud:Tick()
first.hovered=false;cardHovered=true;time=3.2;hud:Tick()
queued='term:hit';hud:Tick()
assert(#presenter.stack==2,'Card hover must allow terminology navigation')
time=5;hud:Tick();assert(view.gameObject.activeSelf and #presenter.stack==2)
cardHovered=false;time=5.1;hud:Tick();assert(view.gameObject.activeSelf)
time=5.5;hud:Tick()
assert(not view.gameObject.activeSelf and #presenter.stack==0,'Leaving a terminology card must close it')

first.hovered=true;time=6;hud:Tick()
first.hovered=false;second.hovered=true;hud:Tick()
assert(hud.lastTooltip==second and presenter.stack[1].title==second.row.name)
second.hovered=false;item.hovered=true;hud:Tick()
assert(hud.lastTooltip==item and presenter.stack[1].title==item.row.name,'Items must share the hover lifecycle')
hud.view.Group.interactable=false;hud:Tick()
assert(not view.gameObject.activeSelf and #presenter.stack==0,'Modal blocking must close the tooltip')
hud.view.Group.interactable=true;hud:Tick();assert(view.gameObject.activeSelf)
hud:OnHide()
assert(not view.gameObject.activeSelf and hud.lastTooltip==nil and #presenter.stack==0)
print('PASS HUD hover expiry, long-hover gap, term card exit, skill/item switching, modal blocking and hide')
