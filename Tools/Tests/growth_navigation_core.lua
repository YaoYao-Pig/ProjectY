-- Controller navigation with real exported progression rules; no Unity Editor or business mutations.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local bytes=file:read('*a');file:close();return bytes
end}})
local rules=require('Game.Progression.GrowthRules').New(config)
CS={UnityEngine={Vector2=function(x,y)return {x=x,y=y}end,Color=function(...)return {...}end,TextAnchor={MiddleCenter=4}}}
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
            result[key]={gameObject=rect().gameObject,transform=rect(),rectTransform=rect(),viewport=rect(),sizeDelta={x=0,y=0},onClick=signal(),onEndEdit=signal(),StopMovement=function(self)self.stops=(self.stops or 0)+1 end}
        end
    end
    file:close()
    result.Style={Prepare=function()end,Highlight=function()end}
    return setmetatable(result,{__index=function(_,key)error('Controller requires undeclared binding '..key)end})
end
local learned={[401]=true};local state={CurrentProfessionId=1,ProfessionCount=1,professions={1},Level=1,PendingCount=2,TalentPoints=2,Revision=0,learned=learned}
function state:HasSkill(id)return self.learned[id]==true end
function state:GetProfessionAt(index)return assert(self.professions[index+1])end
function state:HasProfession(id)for _,joined in ipairs(self.professions)do if joined==id then return true end end;return false end
function state:HasTree(id)return id==1 or (id==3 and self:HasProfession(3))end
function state:GetRank()return 0 end
local actor={Id=9,Growth=state}
local other={Id=10,Growth=setmetatable({CurrentProfessionId=3,ProfessionCount=1,professions={3},learned={[403]=true}},{__index=state})}
local stats={growth=rules,Template=function()return {skillIds={}}end,Get=function()return 0 end,
    equipment={SkillIds=function(_,owner)local ids={};for id in pairs(owner.Growth.learned)do ids[#ids+1]=id end;table.sort(ids);return ids end,
        CheckSkillEquipment=function()return false,'缺少触媒' end}}
local data={Equipment={Revision=0},GetPartyAt=function(_,index)return index==0 and actor or other end}
local system={rules=rules,stats=stats,data=data}
local ui={Close=function(self,name)self.closed=name end,Open=function(self,name,args)self.opened,self.args=name,args end}
local context={systems={Get=function(_,name)return assert(({Growth=system,Config=config,UI=ui})[name])end}}
local Growth=require('UI.Panel.CharacterGrowthCtr')
local panel=setmetatable({context=context,view=view('CharacterGrowth'),visible=true,panelName='CharacterGrowth',
    lifetime={Add=function()end},actor=actor,actorIndex=0,skillMode='profession',tab='Skills'},Growth)
function panel:Listen(button,callback)button.onClick:AddListener(callback)end
function panel:CreateWidget(name)
    local widget={name=name,view={Root=rect(),Button={},Title={rectTransform=rect()},Detail={gameObject=rect().gameObject}}}
    function widget:SetData(row,...)
        self.row=row;self.view.Root.gameObject:SetActive(row~=nil)
        local args={...};self.action=name=='TalentNode' and args[6] or ((name=='SkillAtlasCategory' or name=='ProfessionNode') and args[4] or args[2])
    end
    function widget:SetSkillData(node,skill,nodeState,label,style,selected,action)
        self.row,self.skill,self.state,self.action=node,skill,nodeState,action;self.view.Root.gameObject:SetActive(node~=nil)
    end
    function widget:SetBranch(from,to,style,active,directed)
        self.row,self.to,self.directed=from,to,directed;self.view.Root.gameObject:SetActive(from~=nil)
    end
    return widget
end
function panel:Refresh()self.actor=data:GetPartyAt(self.actorIndex);self.view.Title.text='Fixture';self:Skills()end
local commands={}
local demo={LastError='',SetGrowthOpen=function()end,SendCommand=function(_,command,a,b)
    commands[#commands+1]={command,a,b}
    if command=='growth_profession' then
        local growth=panel.actor.Growth
        if not growth:HasProfession(b) then growth.professions[#growth.professions+1]=b;growth.ProfessionCount=#growth.professions end
        growth.CurrentProfessionId=b
    end
end}
panel:Bind();panel:OnShow({demo=demo,tab='Skills'})
local function click(command,id)
    if command=='select_course' then
        for _,widget in ipairs(panel.courseNodes)do
            if widget.row and widget.row.id==id then assert(widget.action and widget.view.Root.gameObject.activeSelf);widget.action(id);return end
        end
    end
    for _,widget in ipairs(panel.pools.SkillRows)do
        if widget.row and widget.row.command==command and widget.row.id==id then assert(widget.action);widget.action();return end
    end
    error('Missing course row '..command..':'..tostring(id))
end
local function profession(id)
    for _,widget in ipairs(panel.professionNodes)do
        if widget.row and widget.row.id==id then return widget end
    end
    error('Missing profession node '..id)
end
local function chooseProfession(id)
    local widget=profession(id);assert(widget.action and widget.view.Root.gameObject.activeSelf);widget.action(id)
end
local function openGrid()
    assert(panel.courseProfessionRoot.row and panel.courseProfessionRoot.action)
    panel.courseProfessionRoot.action();assert(panel.professionPage=='tree')
    chooseProfession(0);assert(panel.professionPage=='grid')
end
local function hidden(pool)
    for _,widget in ipairs(pool)do
        assert(not widget.view.Root.gameObject.activeSelf,'Inactive widget pool remained visible: '..widget.name)
        assert(widget.row==nil,'Inactive pool retained data that would reappear on cached Show: '..widget.name)
    end
end
local function shown(pool)
    local count=0;for _,widget in ipairs(pool)do if widget.view.Root.gameObject.activeSelf then count=count+1 end end
    assert(count>0,'Expected a visible widget pool')
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
    openGrid();assert(not panel.view.Invest.interactable and panel.selectedProfession==nil)
    assert(panel.view.GraphScroll.gameObject.activeSelf and not panel.view.GraphScroll.horizontal)
    hidden(panel.courseNodes);hidden(panel.courseEdges);hidden(panel.courseHeaders)
    assert(panel.courseProfessionRoot.row==nil and not panel.courseProfessionRoot.view.Root.gameObject.activeSelf)
    panel.view.Invest.onClick:Invoke();assert(#commands==1)
    chooseProfession(3);assert(panel.selectedProfession==3 and state.CurrentProfessionId==1 and state.ProfessionCount==1 and #commands==1)
    panel.professionHeaders[1].action();assert(panel.professionPage=='tree' and panel.selectedProfession==nil)
    panel.professionHeaders[1].action();assert(panel.professionPage=='courses' and not panel.choosingProfession)
    hidden(panel.professionNodes);hidden(panel.professionEdges);hidden(panel.professionHeaders)
    learned[103]=true;panel:Refresh();click('select_course',103)
    assert(panel.selectedCourse==103 and not panel.view.Invest.interactable and panel.view.TalentDetail.text:find('缺少触媒',1,true))
end)
test('mode changes route to the correct resource and restore matching scroll viewport',function()
    panel.view.NextTree.onClick:Invoke()
    assert(panel.skillMode=='talent' and panel.view.GraphScroll.gameObject.activeSelf)
    hidden(panel.courseNodes);hidden(panel.courseEdges);hidden(panel.courseHeaders);shown(panel.nodes);shown(panel.edges)
    assert(panel.view.SkillRowsScroll.viewport.sizeDelta.x==panel.view.SkillRowsScroll.transform.sizeDelta.x)
    panel.view.Invest.onClick:Invoke();assert(commands[2][1]=='growth_talent')
    panel.view.PreviousTree.onClick:Invoke()
    assert(panel.skillMode=='profession' and panel.view.GraphScroll.gameObject.activeSelf)
    hidden(panel.nodes);hidden(panel.edges);shown(panel.courseNodes);shown(panel.courseEdges);shown(panel.courseHeaders)
    assert(panel.view.SkillRowsScroll.viewport.sizeDelta.y==panel.view.SkillRowsScroll.transform.sizeDelta.y)
end)
test('profession root and add node open the grid; only confirmation joins and changes curriculum',function()
    local before=#commands;openGrid();assert(panel.choosingProfession and panel.view.GraphScroll.gameObject.activeSelf)
    chooseProfession(3);assert(#commands==before and state.CurrentProfessionId==1 and state.ProfessionCount==1)
    assert(panel.selectedProfession==3 and panel.view.Invest.interactable);panel.view.Invest.onClick:Invoke()
    assert(#commands==before+1 and commands[#commands][1]=='growth_profession' and commands[#commands][2]==actor.Id and commands[#commands][3]==3)
    assert(state.CurrentProfessionId==3 and state.ProfessionCount==2 and state:HasProfession(1) and state:HasProfession(3))
    assert(panel.courseTree.byId[103] and not panel.courseTree.byId[101] and panel.professionPage=='courses' and not panel.choosingProfession)
    assert(panel.view.GraphScroll.gameObject.activeSelf and state.PendingCount==2 and learned[103])
    hidden(panel.nodes);hidden(panel.edges);shown(panel.courseNodes);hidden(panel.professionNodes);hidden(panel.professionEdges);hidden(panel.professionHeaders)
end)
test('joined branches retain previous professions and exclude them from the add grid',function()
    local before=#commands;panel.courseProfessionRoot.action()
    assert(profession(1) and profession(3) and profession(0));shown(panel.professionEdges)
    chooseProfession(3);assert(panel.professionPage=='courses' and #commands==before)
    panel.courseProfessionRoot.action();chooseProfession(0)
    local available=0
    for _,widget in ipairs(panel.professionNodes)do
        if widget.row then assert(not state:HasProfession(widget.row.id));available=available+1 end
    end
    assert(available==rules.professions.professions.Count-state.ProfessionCount)
    panel.view.NextTree.onClick:Invoke();hidden(panel.professionNodes);hidden(panel.professionEdges);hidden(panel.professionHeaders)
    panel.view.PreviousTree.onClick:Invoke();assert(panel.professionPage=='courses');hidden(panel.professionNodes)
end)
test('party changes rebuild the tree for that actor and discard stale selection and scroll',function()
    click('select_course',104);local before=#commands
    panel.view.Graph.anchoredPosition={x=-300,y=90}
    panel.view.Party2.onClick:Invoke()
    assert(panel.actor==other and panel.actorIndex==1 and panel.selectedCourse~=104)
    assert(panel.courseTree.byId[103] and not panel.courseTree.byId[101] and #commands==before)
    assert(panel.view.Graph.anchoredPosition.x==0 and panel.view.Graph.anchoredPosition.y==0)
    click('select_course',103);assert(panel.view.Invest.interactable and other.Growth.PendingCount==2)
end)
test('candidate selection is reset on actor change and cached show returns to courses',function()
    local before=#commands;openGrid();chooseProfession(2)
    panel.view.Party1.onClick:Invoke()
    assert(panel.actor==actor and panel.professionPage=='grid' and panel.selectedProfession==nil and not panel.view.Invest.interactable)
    for _,widget in ipairs(panel.professionNodes)do if widget.row then assert(not actor.Growth:HasProfession(widget.row.id))end end
    assert(#commands==before)
    panel:OnShow({demo=demo,tab='Skills',actorIndex=1})
    assert(panel.actor==other and panel.professionPage=='courses' and panel.selectedProfession==nil)
    hidden(panel.professionNodes);hidden(panel.professionEdges);hidden(panel.professionHeaders)
    click('select_course',103)
end)
test('journal atlas handoff preserves actor and the selected learning section',function()
    panel.view.Atlas.onClick:Invoke()
    assert(ui.closed=='CharacterGrowth' and ui.opened=='SkillAtlas' and ui.args.actorIndex==1)
    assert(ui.args.returnTo.skillMode=='profession' and ui.args.returnTo.selectedCourse==103 and ui.args.returnTo.professionPage=='courses')
end)
test('journal atlas handoff preserves the profession grid and previewed candidate',function()
    openGrid();chooseProfession(2);panel.view.Atlas.onClick:Invoke()
    assert(ui.args.returnTo.professionPage=='grid' and ui.args.returnTo.selectedProfession==2 and ui.args.actorIndex==1)
    panel:OnShow({demo=demo,tab='Skills',actorIndex=1,selectedCourse=103});panel.view.Atlas.onClick:Invoke()
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
    panel:OnShow(ui.args)
    assert(panel.actor==other and panel.selectedCourse==103 and panel.view.GraphScroll.gameObject.activeSelf)
    hidden(panel.nodes);hidden(panel.edges);shown(panel.courseNodes)
    atlasPanel:OnShow({demo=demo});assert(atlasPanel.returnTo==nil and atlasPanel.categoryId==rules.atlas.nodes:Get(403).categoryId)
end)
print('Growth navigation: '..count..' checks passed')
