-- Exercise the actual HUD controller with a bounded four-cell viewport, without Unity.
package.path = 'Lua/?.lua;' .. package.path
local Model = require('Game.Battle.BattleHUDModel')
local originalBuild = Model.Build
local originalPresenter = package.loaded['UI.SkillTipPresenter']
package.loaded['UI.SkillTipPresenter'] = {New=function() return {Hide=function() end} end}
CS = {UnityEngine={Color=function(r,g,b,a) return {r=r,g=g,b=b,a=a} end},
    ProjectY={Samples={BattleTargetSelection={Active=function() return false end,NeedsLanding=function() return false end,Hint=function() return '' end}},
    UI={BattleLogPresentation={Set=function() end}}}}

local function node()
    return {text='',gameObject={activeSelf=true,SetActive=function(self,value) self.activeSelf=value end}}
end
local view = {HUD={Prepare=function() end,SetHealth=function(_,image,value) image.fillAmount=value end,Font='TestFont',Compact=false},
    SkillSlots={},ItemSlots={},PartySlots={},TurnList={},TurnTemplate={}}
for _,key in ipairs({'EndTurn','Move','Focus','Auto','LogToggle','LogOpen','LogClose','Previous','Next','Encounter','Round','SkillTitle','ItemTitle',
    'EndTurnText','MoveText','FocusText','AutoText','LogToggleText','Hint','Tooltip'}) do view[key]=node() end
local state = {actorId=1,phase='combat',round=1,ids={}}
for i=1,12 do state.ids[i]=i end
local hp = 25
Model.Build = function()
    local result = {actorId=state.actorId,phase=state.phase,round=state.round,player=true,maxRounds=18,encounter='Test',
        moveRemaining=3,moved=false,moveAvailable=true,skills={},items={},party={},turns={},logs={}}
    for _,id in ipairs(state.ids) do
        result.turns[#result.turns+1]={id=id,name='Actor '..id,hp=hp,maxHP=30,team=id<=2 and 1 or 2,active=id==state.actorId,speed=id}
    end
    return result
end

-- The list owns and reuses four cells. The HUD must supply every row and let the list
-- retain/clamp its viewport position instead of reconstructing it on content refresh.
local list = {calls={},refreshes={},cells={},first=1,last=0,itemCount=0,rangeReads=0,configureCount=0,widgetCount=0}
function list:Configure(options)
    self.configureCount=self.configureCount+1
    assert(self.configureCount==1 and options.templates.turn==view.TurnTemplate,'Configure the bound template once')
    self.options=options
end
local function reference()
    local entries={}
    for _,key in ipairs({'Name','Detail','Group','Button','Active','Side','Health'}) do entries[key]=node() end
    local event={listeners={}}
    function event:AddListener(fn) self.listeners[#self.listeners+1]=fn end
    function event:RemoveListener(fn)
        for i,value in ipairs(self.listeners) do if value==fn then table.remove(self.listeners,i);return end end
        error('Unknown button listener')
    end
    function event:Click() for _,fn in ipairs(self.listeners) do fn() end end
    entries.Button.onClick=event
    return {entries=entries,Get=function(_,key) return assert(entries[key],key) end}
end
function list:RecycleAll()
    for _,cell in ipairs(self.cells) do
        if cell.index then
            local oldIndex=cell.index;cell.index=nil
            self.options.onRecycle(cell,oldIndex)
            assert(not cell.widget.visible and cell.widget.row==nil,'Recycling must hide the actual BattleTurn and release its row')
        end
    end
end
function list:Render()
    self.first=math.max(1,math.min(self.first,math.max(1,self.itemCount-3)))
    self.last=math.min(self.itemCount,self.first+3)
    for index=self.first,self.last do
        local slot=index-self.first+1
        local cell=self.cells[slot]
        if not cell then
            cell={reference=reference()}
            self.cells[slot]=cell
            self.options.onCreate(cell)
            self.widgetCount=self.widgetCount+1
            assert(#cell.reference.entries.Button.onClick.listeners==1,'A real BattleTurn should bind its click once')
        end
        cell.index=index
        self.options.onBind(cell,index)
    end
    for slot=self.last-self.first+2,#self.cells do self.cells[slot].index=nil end
end
function list:SetItemCount(count,keepPosition)
    self.calls[#self.calls+1]={count=count,keepPosition=keepPosition==true}
    self:RecycleAll()
    self.itemCount=count
    if not keepPosition then self.first=1 end
    self:Render()
end
function list:GetVisibleRange()
    self.rangeReads=self.rangeReads+1
    return self.first,self.last
end
function list:RefreshItem(index)
    assert(index>=self.first and index<=self.last,'Only instantiated rows need a content refresh')
    self.refreshes[#self.refreshes+1]=index
    local cell=self.cells[index-self.first+1]
    self.options.onBind(cell,index)
end
function list:ScrollTo(index)
    assert(index>=1 and index<=self.itemCount)
    self:RecycleAll()
    self.first=index
    self:Render()
end

local battle={Changed={Subscribe=function() return {} end}}
local config={GetTable=function(_,name)
    if name=='BattleHUDTable' then return {Get=function() return {itemIconIds={1,1,1,1}} end} end
    assert(name=='BattleIconTable');return {Get=function() return {} end}
end}
local HUD = require('UI.Widget.BattleHUDContent')
local controller=setmetatable({view=view,context={log=error,services={Adventure={}},systems={Get=function(_,name) return name=='Battle' and battle or config end}},
    visibleScope={Add=function() end}},{__index=HUD})
local callbacks={}
function controller:Listen(button,fn) assert(not callbacks[button]);callbacks[button]=fn end
function controller:CreateWidget(kind)
    assert(kind~='BattleTurn','Turn cards must use the scroll list rather than a fixed number of instances')
    return {Initialize=function() end,SetData=function() end}
end
function controller:AddWidget(kind,reference)
    assert(kind==require('UI.UIScrollList') and reference==view.TurnList)
    return list
end
local focused
local demo={BattleHUDRevision=1,LastError='',SelectedBattleSkill=0,IsBattleMoveSelected=true,BattleAutoAI=false,
    FocusBattleActor=function(_,id) focused=id end}
local function visibleMatches()
    for index=list.first,list.last do
        local cell=list.cells[index-list.first+1]
        assert(cell.widget.row==controller.model.turns[index],'Visible cells must receive the current snapshot row')
        assert(cell.widget.visible and cell.widget.view.Name.text==cell.widget.row.name,'Real BattleTurn must remain visible and populated after binding')
    end
end
local function expectReset(change)
    list:ScrollTo(list.itemCount)
    local calls=#list.calls
    change()
    controller:Refresh()
    assert(#list.calls==calls+1 and not list.calls[#list.calls].keepPosition and list.first==1,'Turn context changes must return to the current actor')
    visibleMatches()
end

controller:Bind();controller:OnShow({demo=demo})
assert(list.itemCount==12 and list.last==4 and not list.calls[1].keepPosition,'The complete queue must be scrollable from its beginning')
visibleMatches()
list:ScrollTo(12)
assert(list.first==9 and list.last==12 and list.cells[4].widget.row.id==12,'The last enemy must be reachable')
list.cells[4].reference.entries.Button.onClick:Click();assert(focused==12,'Reused cells must focus their current actor')
local rebuilds,rangeReads=#list.calls,list.rangeReads
hp=11;controller:Refresh()
assert(#list.calls==rebuilds and list.first==9 and list.rangeReads==rangeReads+1,'Content refresh must preserve the readers position')
assert(#list.refreshes==4 and list.refreshes[1]==9 and list.refreshes[4]==12,'Refresh only the visible range')
assert(list.cells[4].widget.row.hp==11);visibleMatches()
print('PASS 12-row initiative queue, tail access, recycled focus and content refresh preserving scroll position')

expectReset(function() state.actorId=2 end)
expectReset(function() state.round=2 end)
expectReset(function() state.phase='deployment' end)
list:ScrollTo(12)
local previousCalls=#list.calls
state.ids[12]=99;controller:Refresh()
assert(#list.calls==previousCalls+1 and list.calls[#list.calls].keepPosition and list.first==9,'Same-length replacement must rebind while retaining scroll')
assert(list.cells[4].widget.row.id==99);list.cells[4].reference.entries.Button.onClick:Click();assert(focused==99)
state.ids={1,2,3,4,5,6};controller:Refresh()
assert(list.itemCount==6 and list.first==3 and list.last==6 and list.calls[#list.calls].keepPosition,'A shorter queue must clamp the old scroll position')
visibleMatches()
state.ids={1,2};controller:Refresh()
assert(list.itemCount==2 and list.first==1 and list.last==2 and list.cells[3].index==nil and list.cells[4].index==nil,'Removed rows must leave the visible range')
state.ids={};controller:Refresh()
assert(list.itemCount==0 and list.first==1 and list.last==0)
previousCalls=#list.calls;local refreshes=#list.refreshes;controller:Refresh()
assert(#list.calls==previousCalls and #list.refreshes==refreshes,'Empty visible ranges must not request row zero')
print('PASS actor/round/phase reset, same-length replacement, shrinking queues and empty range')

state.ids={1,2,3,4,5,6,7,8,9,10,11,12};controller:Refresh();list:ScrollTo(12)
local widgets=list.widgetCount
list:RecycleAll();controller:OnHide();controller:OnShow({demo=demo})
assert(list.first==1 and list.itemCount==12 and not list.calls[#list.calls].keepPosition,'Cached reopen must show the queue from its beginning')
assert(list.configureCount==1 and list.widgetCount==widgets,'Cached reopen must reuse the configured list and cells')
visibleMatches();list.cells[1].reference.entries.Button.onClick:Click();assert(focused==1)
list:RecycleAll()
for _,cell in ipairs(list.cells) do
    local button=cell.reference.entries.Button
    list.options.onDestroy(cell)
    assert(cell.widget.disposed and #button.onClick.listeners==0,'List destruction must dispose real BattleTurn listeners')
end
Model.Build=originalBuild
package.loaded['UI.SkillTipPresenter']=originalPresenter
print('PASS real BattleTurn hide/rebind, cached reopen, stable focus listeners and disposal')
