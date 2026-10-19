-- Controller navigation with real exported progression rules; no Unity Editor or business mutations.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local bytes=file:read('*a');file:close();return bytes
end}})
local rules=require('Game.Progression.GrowthRules').New(config)
CS={UnityEngine={Vector2=function(x,y)return {x=x,y=y}end,Color=function(...)return {...}end}}
local function signal()
    local event={}
    function event:AddListener(fn) self.fn=fn end
    function event:RemoveListener(fn) if self.fn==fn then self.fn=nil end end
    function event:Invoke() assert(self.fn)() end
    return event
end
local function rect()
    return {sizeDelta={x=0,y=0},gameObject={SetActive=function(self,value)self.activeSelf=value end},SetAsFirstSibling=function()end}
end
local function view(name)
    local result={};local file=assert(io.open('Lua/UI/Types/'..name..'PanelView.lua','r'))
    for line in file:lines() do
        local key=line:match('^%-%-%-@field ([%w]+) ')
        if key then
            result[key]={gameObject=rect().gameObject,transform=rect(),rectTransform=rect(),viewport=rect(),sizeDelta={x=0,y=0},onClick=signal(),onEndEdit=signal()}
        end
    end
    file:close()
    result.Style={Prepare=function()end,Highlight=function()end}
    return setmetatable(result,{__index=function(_,key)error('Controller requires undeclared binding '..key)end})
end
local learned={[401]=true};local state={CurrentProfessionId=1,Level=1,PendingCount=2,TalentPoints=2,Revision=0}
function state:HasSkill(id)return learned[id]==true end
function state:HasTree(id)return id==1 or (id==3 and self.CurrentProfessionId==3)end
function state:GetRank()return 0 end
local actor={Id=9,Growth=state}
local other={Id=10,Growth=setmetatable({CurrentProfessionId=3},{__index=state})}
local stats={growth=rules,Template=function()return {skillIds={}}end,Get=function()return 0 end,
    equipment={SkillIds=function()local ids={};for id in pairs(learned)do ids[#ids+1]=id end;table.sort(ids);return ids end,
        CheckSkillEquipment=function()return false,'缺少触媒' end}}
local data={Equipment={Revision=0},GetPartyAt=function(_,index)return index==0 and actor or other end}
local system={rules=rules,stats=stats,data=data}
local ui={Close=function(self,name)self.closed=name end,Open=function(self,name,args)self.opened,self.args=name,args end}
local context={systems={Get=function(_,name)return assert(({Growth=system,Config=config,UI=ui})[name])end}}
local Growth=require('UI.Panel.CharacterGrowthCtr')
local panel=setmetatable({context=context,view=view('CharacterGrowth'),visible=true,panelName='CharacterGrowth',
    lifetime={Add=function()end},actor=actor,actorIndex=0,skillMode='profession',tab='Skills'},Growth)
function panel:Listen(button,callback)button.onClick:AddListener(callback)end
function panel:CreateWidget()
    local widget={view={Root=rect()}}
    function widget:SetData(row,style,callback)self.row,self.action=row,callback end
    return widget
end
function panel:Refresh()self.actor=data:GetPartyAt(self.actorIndex);self:Skills()end
local commands={}
local demo={LastError='',SetGrowthOpen=function()end,SendCommand=function(_,command,a,b)commands[#commands+1]={command,a,b} end}
panel:Bind();panel:OnShow({demo=demo,tab='Skills'})
local function click(command,id)
    for _,widget in ipairs(panel.pools.SkillRows)do
        if widget.row and widget.row.command==command and widget.row.id==id then assert(widget.action);widget.action();return end
    end
    error('Missing course row '..command..':'..tostring(id))
end
local count=0
local function test(name,fn)fn();count=count+1;print('PASS '..name)end
test('eligible and locked course selections preview without spending or sending commands',function()
    click('select_course',101);assert(#commands==0 and state.PendingCount==2 and panel.view.Invest.interactable)
    click('select_course',501);assert(panel.selectedCourse==501 and not panel.view.Invest.interactable and #commands==0)
    assert(panel.view.TalentDetail.text:find('需要角色等级 2',1,true))
end)
test('explicit learning targets the selected actor and selected course',function()
    click('select_course',101);panel.view.Invest.onClick:Invoke()
    assert(#commands==1 and commands[1][1]=='growth_skill' and commands[1][2]==9 and commands[1][3]==101)
end)
test('profession chooser suppresses stale learn action; selected retained skills remain inspectable',function()
    click('choose_profession',nil);assert(not panel.view.Invest.interactable)
    panel.view.Invest.onClick:Invoke();assert(#commands==1)
    click('choose_profession',nil)
    learned[103]=true;panel:Refresh();click('select_course',103)
    assert(panel.selectedCourse==103 and not panel.view.Invest.interactable and panel.view.TalentDetail.text:find('缺少触媒',1,true))
end)
test('mode changes route to the correct resource and restore matching scroll viewport',function()
    panel.view.NextTree.onClick:Invoke()
    assert(panel.skillMode=='talent' and panel.view.GraphScroll.gameObject.activeSelf)
    assert(panel.view.SkillRowsScroll.viewport.sizeDelta.x==panel.view.SkillRowsScroll.transform.sizeDelta.x)
    panel.view.Invest.onClick:Invoke();assert(commands[2][1]=='growth_talent')
    panel.view.PreviousTree.onClick:Invoke()
    assert(panel.skillMode=='profession' and not panel.view.GraphScroll.gameObject.activeSelf)
    assert(panel.view.SkillRowsScroll.viewport.sizeDelta.y==panel.view.SkillRowsScroll.transform.sizeDelta.y)
end)
test('journal atlas handoff preserves actor and the selected learning section',function()
    panel.actorIndex=1;panel.view.Atlas.onClick:Invoke()
    assert(ui.closed=='CharacterGrowth' and ui.opened=='SkillAtlas' and ui.args.actorIndex==1)
    assert(ui.args.returnTo.skillMode=='profession' and ui.args.returnTo.selectedCourse==103)
end)
local Atlas=require('UI.Panel.SkillAtlasCtr')
local atlasPanel=setmetatable({view=view('SkillAtlas'),growth=system,atlas=rules.atlas,context=context,panelName='SkillAtlas'},Atlas)
atlasPanel.view.Geometry={Dismiss=function()end,Focus=function()end}
function atlasPanel:Refresh()self.actor=data:GetPartyAt(self.actorIndex)end
test('atlas selects the entrants profession and explicit close restores the saved journal section',function()
    atlasPanel:OnShow(ui.args)
    assert(atlasPanel.actorIndex==1 and atlasPanel.categoryId==rules.atlas.nodes:Get(403).categoryId)
    assert(atlasPanel.view.CloseText.text=='返回角色手记')
    atlasPanel:Close();assert(ui.opened=='CharacterGrowth' and ui.args.actorIndex==1 and ui.args.skillMode=='profession')
    atlasPanel:OnShow({demo=demo});assert(atlasPanel.returnTo==nil and atlasPanel.categoryId==rules.atlas.nodes:Get(401).categoryId)
end)
print('Growth navigation: '..count..' checks passed')
