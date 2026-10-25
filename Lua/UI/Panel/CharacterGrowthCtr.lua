local LuaLanguage = require('Language')
local Class=require('Core.Class')
local Base=require('UI.UIPanelCtrl')
local Widgets=require('UI.GrowthWidgets')
local ProfessionTree=require('UI.ProfessionTree')
local Growth=Class('CharacterGrowthCtr',Base)
local function place(rect,x,y,width,height)
    rect.anchoredPosition=CS.UnityEngine.Vector2(x,-y);rect.sizeDelta=CS.UnityEngine.Vector2(width,height)
end
function Growth:Bind()
    self.system=self.context.systems:Get('Growth');self.rules=self.system.rules;self.stats=self.system.stats
    self.appearance=require('Game.Adventure.PawnAppearance').New(self.context.systems:Get('Config'))
    self.view.Style:Prepare();self.nodes,self.edges={},{}
    self.courseNodes,self.courseEdges,self.courseHeaders={},{},{}
    self.professionNodes,self.professionEdges,self.professionHeaders={},{},{}
    self:Listen(self.view.Close,function() self:Close() end)
    self:Listen(self.view.Atlas,function()
        local demo=self.demo;local resume={actorIndex=self.actorIndex,tab=self.tab,skillMode=self.skillMode,
            treeIndex=self.treeIndex,selectedNode=self.selectedNode,selectedCourse=self.selectedCourse,
            professionPage=self.professionPage,selectedProfession=self.selectedProfession}
        self:Close();self.context.systems:Get('UI'):Open('SkillAtlas',{demo=demo,actorIndex=resume.actorIndex,returnTo=resume})
    end)
    for i=1,4 do self:Listen(self.view['Party'..i],function()
        self.actorIndex=i-1;self.historyPage=1;self.selectedNode=nil;self.selectedCourse=nil;self.selectedProfession=nil;self.treeIndex=nil;self:Refresh();self:ResetGraph()
    end) end
    for _,key in ipairs({'Overview','Skills','History'}) do self:Listen(self.view[key..'Tab'],function()
        self.tab=key;self:Refresh();if key=='Skills' then self:ResetGraph() end
    end) end
    self:Listen(self.view.PreviousTree,function() self.skillMode='profession';self:SetProfessionPage('courses') end)
    self:Listen(self.view.NextTree,function() self.skillMode='talent';self:Refresh();self:ResetGraph();self.view.SkillRowsScroll.verticalNormalizedPosition=1 end)
    self:Listen(self.view.PreviousHistory,function() self.historyPage=self.historyPage-1;self:Refresh() end)
    self:Listen(self.view.NextHistory,function() self.historyPage=self.historyPage+1;self:Refresh() end)
    self:Listen(self.view.Invest,function()
        if self.skillMode=='talent' and self.selectedNode then self:Command('growth_talent',self.selectedNode)
        elseif self.skillMode=='profession' then
            if self.professionPage=='grid' and self.selectedProfession then self:Command('growth_profession',self.selectedProfession)
            elseif self.professionPage=='tree' then self:SetProfessionPage('grid')
            elseif self.professionPage=='courses' and self.selectedCourse then self:Command('growth_skill',self.selectedCourse) end
        end
    end)
    self.view.OverviewTabText.text=LuaLanguage.UICharacterGrowthOverviewTabTextText;self.view.SkillsTabText.text=LuaLanguage.UICharacterGrowthSkillsTabTextText;self.view.HistoryTabText.text=LuaLanguage.UICharacterGrowthHistoryTabTextText
    self.view.AtlasText.text=LuaLanguage.UICharacterGrowthAtlasTextText;self.view.PreviousTreeText.text=LuaLanguage.UICharacterGrowthPreviousTreeTextText;self.view.NextTreeText.text=LuaLanguage.UICharacterGrowthNextTreeTextText
    place(self.view.PreviousTree.transform,0,0,126,29);place(self.view.NextTree.transform,136,0,126,29)
    place(self.view.PreviousTreeText.rectTransform,8,0,110,29);place(self.view.NextTreeText.rectTransform,8,0,110,29)
    place(self.view.TreeTitle.rectTransform,278,0,292,29)
end
function Growth:ResetGraph()
    self.view.GraphScroll:StopMovement();self.view.Graph.anchoredPosition=CS.UnityEngine.Vector2(math.min(0,(570-self.view.Graph.sizeDelta.x)/2),0)
end
function Growth:OnShow(args)
    self.demo=assert(args.demo);self.demo:SetGrowthOpen(true)
    self.actorIndex,self.treeIndex,self.historyPage,self.tab,self.selectedNode=args.actorIndex or 0,args.treeIndex,1,args.tab or 'Overview',args.selectedNode
    self.skillMode,self.selectedCourse=args.skillMode or 'profession',args.selectedCourse
    self.professionPage,self.selectedProfession=args.professionPage or 'courses',args.selectedProfession
    self.choosingProfession=self.professionPage~='courses';self.previewSkill=nil
    self:Refresh();self:ResetGraph()
    self.view.SkillRowsScroll.verticalNormalizedPosition=1
end
function Growth:SetProfessionPage(page)
    assert(page=='courses' or page=='tree' or page=='grid','Invalid profession page')
    self.professionPage=page;self.choosingProfession=page~='courses';self.selectedProfession=nil
    self:Refresh();self:ResetGraph();self.view.SkillRowsScroll.verticalNormalizedPosition=1
end
function Growth:OpenProfession(id)
    assert(self.actor.Growth:HasProfession(id),'Profession must be joined before opening its branch')
    if self.actor.Growth.CurrentProfessionId==id then self:SetProfessionPage('courses')
    else self:Command('growth_profession',id) end
end
function Growth:SelectCourse(id)
    self.selectedCourse=id;self.previewSkill=id;self:Refresh()
end
function Growth:Command(command,id)
    self.demo:SendCommand(command,self.actor.Id,id)
    if command=='growth_profession' and self.actor.Growth.CurrentProfessionId==id then
        self.treeIndex=nil;self.selectedNode=nil;self.selectedCourse=nil;self.selectedProfession=nil
        self.professionPage='courses';self.choosingProfession=false
    end
    if self.visible then self:Refresh();if command=='growth_profession' then self:ResetGraph() end end
end
function Growth:Refresh()
    local data=self.system.data
    self.actor=assert(data:GetPartyAt(self.actorIndex));local actor=self.actor;local growth=actor.Growth
    for i=1,4 do
        local button=self.view['Party'..i];button.gameObject:SetActive(i<=data.PartyCount)
        if i<=data.PartyCount then self.view['Party'..i..'Text'].text=self.stats:Template(data:GetPartyAt(i-1)).name end
        self.view.Style:Highlight(button,i-1==self.actorIndex)
        self.view['Party'..i..'Text'].color=i-1==self.actorIndex and CS.UnityEngine.Color(.91,.87,.77,1) or CS.UnityEngine.Color(.20,.24,.21,1)
    end
    local nextLevel=self.rules.levels:Find(growth.Level+1)
    local name=self.stats:Template(actor).name:match('^(.-)%s*·%s*(.+)$')
    self.view.Title.text=name or self.stats:Template(actor).name;self.view.Role.text=self.rules.professions.professions:Get(growth.CurrentProfessionId).name
    self.view.HeroLevel.text=string.format(LuaLanguage.UICharacterGrowthHeroLevelText, (growth.Level))
    self.view.HeroHealth.text=string.format(LuaLanguage.UICharacterGrowthHeroHealthText, (actor.HP), (actor.MaxHP))
    self.view.HeroExperience.text=nextLevel and (string.format(LuaLanguage.UICharacterGrowthHeroExperienceText2, (growth.Experience), (nextLevel.experience))) or LuaLanguage.UICharacterGrowthHeroExperienceText
    self.view.ExperienceFill.sizeDelta=CS.UnityEngine.Vector2(210*(nextLevel and math.min(1,growth.Experience/nextLevel.experience) or 1),3)
    self.view.Summary.text=string.format(LuaLanguage.UICharacterGrowthSummaryText, (growth.AttributePoints), (growth.TalentPoints), (growth.PendingCount), (growth.LockedPotential))
    local appearance=self.appearance:Template(actor.TemplateId,self.stats.equipment:ActorVisual(actor))
    if self.previewSkill then
        local id=self.previewSkill;local skill=self.context.systems:Get('Battle'):Skill(actor,id)
        local effects=self.context.systems:Get('Config'):GetTable('VisualEffectTable')
        appearance.skillPreview={id=id,actionTemplate=skill.actionTemplate,shots=skill.shots,trajectory=skill.trajectory,
            selfTarget=skill.target=='self',profile=effects:Get(self.rules.skills:Get(id).visualEffectId)}
        self.previewSkill=nil
    end
    self.view.Character:Show(appearance)
    for _,key in ipairs({'Overview','Skills','History'}) do
        self.view[key].gameObject:SetActive(self.tab==key);self.view.Style:Highlight(self.view[key..'Tab'],self.tab==key)
        self.view[key..'TabText'].color=self.tab==key and CS.UnityEngine.Color(.91,.87,.77,1) or CS.UnityEngine.Color(.20,.24,.21,1)
    end
    if self.tab=='Overview' then self:Overview() elseif self.tab=='Skills' then self:Skills() else self:History() end
    local hints={Overview=LuaLanguage.UICharacterGrowthOverview,
        Skills=self.skillMode=='talent' and LuaLanguage.UICharacterGrowthSkills2 or (self.professionPage=='tree' and LuaLanguage.GrowthProfessionTreeHint or (self.professionPage=='grid' and LuaLanguage.GrowthProfessionGridHint or LuaLanguage.UICharacterGrowthSkills)),
        History=LuaLanguage.UICharacterGrowthHistory}
    self.view.Hint.text=self.demo.LastError~='' and self.demo.LastError or hints[self.tab]
    self.revision,self.count,self.socialRevision=growth.Revision,data.JournalCount,data.PartyBonds.Revision
end
function Growth:Overview()
    local actor=self.actor;local attributes={}
    for _,row in ipairs(self.rules.attributes:All()) do
        local owned=actor.Growth:GetAttribute(row.code)
        attributes[#attributes+1]={id=row.id,title=row.name,icon=row.code,
            body=tostring(self.stats:Get(actor,row.code)),
            available=actor.Growth.AttributePoints>=row.pointCost and owned+row.amount<=row.maximumInvestment}
    end
    Widgets.Rows(self,'Attributes','JournalAttribute',attributes,function(row) self:Command('growth_attribute',row.id) end)
    local traits={}
    for i=0,actor.TraitCount-1 do local row=self.stats.traits:Get(actor:GetTraitAt(i));traits[#traits+1]={title='◆ '..row.name,body=row.description,color='354739'} end
    if #traits==0 then traits[1]={title=LuaLanguage.GrowthNoTraits,body=LuaLanguage.GrowthTraitHint,color='354739'} end
    local story=self.context.systems:Get('Adventure').partyStory
    for _,row in ipairs(story:OverviewRows(actor)) do traits[#traits+1]=row end
    self.view.TraitDetail.text=traits[1].body
    Widgets.Rows(self,'Traits','TraitTag',traits,function(row) self.view.TraitDetail.text=row.title..'\n\n'..row.body end)
end
function Growth:Skills()
    local passive=self.skillMode=='talent'
    self.choosingProfession=self.professionPage~='courses'
    local chooser=not passive and self.choosingProfession
    self.view.Style:Highlight(self.view.PreviousTree,not passive);self.view.Style:Highlight(self.view.NextTree,passive)
    self.view.PreviousTreeText.color=not passive and CS.UnityEngine.Color(.91,.87,.77,1) or CS.UnityEngine.Color(.20,.24,.21,1)
    self.view.NextTreeText.color=passive and CS.UnityEngine.Color(.91,.87,.77,1) or CS.UnityEngine.Color(.20,.24,.21,1)
    self.view.GraphScroll.gameObject:SetActive(true);self.view.GraphScroll.horizontal=not chooser;self.view.SkillTitle.gameObject:SetActive(passive)
    if passive or chooser then
        for _,widget in ipairs(self.courseNodes) do widget:SetSkillData(nil) end
        for _,widget in ipairs(self.courseEdges) do widget:SetBranch(nil) end
        for _,widget in ipairs(self.courseHeaders) do widget:SetData(nil) end
        if self.courseProfessionRoot then self.courseProfessionRoot:SetData(nil) end
    end
    if not chooser then
        for _,widget in ipairs(self.professionNodes) do widget:SetData(nil) end
        for _,widget in ipairs(self.professionEdges) do widget:SetBranch(nil) end
        for _,widget in ipairs(self.professionHeaders) do widget:SetData(nil) end
    end
    if not passive then
        for _,widget in ipairs(self.nodes) do widget:SetData(nil) end
        for _,widget in ipairs(self.edges) do widget:SetData(nil) end
    end
    local scroll=self.view.SkillRowsScroll
    scroll.gameObject:SetActive(not chooser)
    local x,y,width,height=607,293,267,84
    if passive then y,height=207,170 elseif chooser then x,y,width,height=0,40,570,337 end
    place(scroll.transform,x,y,width,height);place(scroll.viewport,0,0,width,height)
    self.view.SkillRows.sizeDelta=CS.UnityEngine.Vector2(width,self.view.SkillRows.sizeDelta.y)
    place(self.view.TalentDetail.rectTransform,607,39,268,passive and 68 or (chooser and 255 or 194))
    place(self.view.Invest.transform,607,passive and 116 or (chooser and 332 or 243),267,35)
    if passive then self:Talents() elseif chooser then self:ProfessionBrowser() else self:Courses() end
end
function Growth:Talents()
    local actor=self.actor;local all=self.rules.trees:All()
    if not self.treeIndex then
        local profession=self.rules.professions.professions:Get(actor.Growth.CurrentProfessionId)
        for i,row in ipairs(all) do if row.id==profession.treeIds[1] then self.treeIndex=i;break end end
        if not self.treeIndex then for i,row in ipairs(all) do if actor.Growth:HasTree(row.id) then self.treeIndex=i;break end end end
    end
    assert(self.treeIndex,'Actor has no talent tree')
    self.treeIndex=math.min(#all,math.max(1,self.treeIndex))
    local tree=all[self.treeIndex];local open=actor.Growth:HasTree(tree.id)
    if not self.selectedNode then self.selectedNode=tree.rootIds[1] end
    self.view.TreeTitle.text=tree.name..(open and '' or LuaLanguage.GrowthLockedTree)
    local edges={}
    for _,row in ipairs(self.rules.edges:All()) do if self.rules.nodes:Get(row.fromId).treeId==tree.id then edges[#edges+1]=row end end
    for i,row in ipairs(edges) do
        if not self.edges[i] then self.edges[i]=self:CreateWidget('TalentEdge',self.view.Graph) end
        self.edges[i]:SetData(row,self.rules.nodes:Get(row.fromId),self.rules.nodes:Get(row.toId),actor,self.view.Style,tree.unlockRule=='prerequisite_all')
        self.edges[i].view.Root:SetAsFirstSibling()
    end
    for i=#edges+1,#self.edges do self.edges[i]:SetData(nil) end
    local nodes={};local width,height=570,342
    for _,row in ipairs(self.rules.nodes:All()) do if row.treeId==tree.id then nodes[#nodes+1]=row;width=math.max(width,row.x+55);height=math.max(height,row.y+53) end end
    self.view.Graph.sizeDelta=CS.UnityEngine.Vector2(width,height)
    for i,row in ipairs(nodes) do
        if not self.nodes[i] then self.nodes[i]=self:CreateWidget('TalentNode',self.view.Graph) end
        self.nodes[i]:SetData(row,self.rules.passives:Get(row.passiveId),actor,self.view.Style,self.selectedNode==row.id,self.rules:CanInvest(actor,row.id),function(id) self.selectedNode=id;self:Refresh() end)
    end
    for i=#nodes+1,#self.nodes do self.nodes[i]:SetData(nil) end
    local node=self.selectedNode and self.rules.nodes:Get(self.selectedNode)
    local available,reason=false,''
    if node then available,reason=self.rules:CanInvest(actor,node.id) end
    self.view.Invest.interactable=available;self.view.InvestText.text=node and (string.format(LuaLanguage.UICharacterGrowthInvestTextText, (node.pointCost))) or LuaLanguage.GrowthChooseNode
    self.view.TalentName.text=node and self.rules.passives:Get(node.passiveId).name or LuaLanguage.UICharacterGrowthTalentNameText
    self.view.TalentDetail.text=node and (self.rules.passives:Get(node.passiveId).description..'\n'..(available and LuaLanguage.UICharacterGrowthTalentDetailText or reason)) or tree.description
    self.view.SkillTitle.text=string.format(LuaLanguage.UICharacterGrowthSkillTitleText, (actor.Growth.TalentPoints))
    local rows={}
    for i,row in ipairs(all) do rows[#rows+1]={id=i,title=(i==self.treeIndex and LuaLanguage.UICharacterGrowthTitle or '')..row.name,
        body=(actor.Growth:HasTree(row.id) and LuaLanguage.UICharacterGrowthBody2 or LuaLanguage.UICharacterGrowthBody)..(row.unlockRule=='adjacent_any' and LuaLanguage.GrowthAdjacent or LuaLanguage.GrowthPrerequisites),color='354739'} end
    Widgets.Rows(self,'SkillRows','JournalSkill',rows,function(row) self.treeIndex=row.id;self.selectedNode=nil;self:Refresh() end)
end
function Growth:Courses()
    local actor=self.actor;local rows={};local growth=actor.Growth
    local professions=self.rules.professions
    local current=professions.professions:Get(growth.CurrentProfessionId)
    self.view.TreeTitle.text=string.format(LuaLanguage.UICharacterGrowthTreeTitleText, (current.name), (growth.PendingCount))
    self.courseTree=ProfessionTree.Build(professions,self.rules.atlas,growth.CurrentProfessionId)
    local shown=self.courseTree.byId
    local owned=self.rules.atlas:Owned(actor,self.stats)
    for _,id in ipairs(self.stats.equipment:SkillIds(actor,self.stats:Template(actor))) do if not shown[id] then
        local row=self.rules.skills:Get(id);local _,source=self.rules.atlas:State(id,actor,self.stats,owned)
        rows[#rows+1]={id=id,command='select_course',title=source..' · '..row.name,body=row.description,color='354739'}
    end
    end
    local found=shown[self.selectedCourse]~=nil;for _,row in ipairs(rows) do if row.command=='select_course' and row.id==self.selectedCourse then found=true end end
    if not found then
        self.selectedCourse=nil
        for _,node in ipairs(self.courseTree.nodes) do
            if node.course and professions:CanLearn(actor,node.id,self.stats,self.rules.atlas) then self.selectedCourse=node.id;break end
        end
        if not self.selectedCourse then self.selectedCourse=self.courseTree.nodes[1] and self.courseTree.nodes[1].id or (rows[1] and rows[1].id) end
    end
    self:CourseGraph(owned)
    for _,row in ipairs(rows) do if row.command=='select_course' and row.id==self.selectedCourse then row.title='› '..row.title end end
    if self.selectedCourse then
        local skill=self.rules.skills:Get(self.selectedCourse);local available,reason=professions:CanLearn(actor,skill.id,self.stats,self.rules.atlas)
        self.view.TalentName.text=skill.name
        local kind=skill.skillKind=='preparation' and LuaLanguage.UICharacterGrowthKind2 or LuaLanguage.UICharacterGrowthKind
        local condition=self.rules.atlas:EquipmentCondition(skill,actor,self.stats)
        self.view.TalentDetail.text=string.format(LuaLanguage.UICharacterGrowthTalentDetailText3, (kind), (reason), (skill.description), (condition and '\n\n'..condition or ''))
        local node=self.rules.atlas.nodes:Get(skill.id)
        if #node.prerequisiteIds>0 then
            local names={};for _,id in ipairs(node.prerequisiteIds) do names[#names+1]=self.rules.skills:Get(id).name end
            local title=node.prerequisiteMode=='all' and LuaLanguage.UISkillAtlasPrerequisiteTitleText2 or LuaLanguage.UISkillAtlasPrerequisiteTitleText
            self.view.TalentDetail.text=self.view.TalentDetail.text..'\n\n'..title..'\n'..table.concat(names,' / ')
        end
        self.view.Invest.interactable=available;self.view.InvestText.text=available and LuaLanguage.UICharacterGrowthInvestTextText5 or (growth:HasSkill(skill.id) and LuaLanguage.UICharacterGrowthInvestTextText4 or LuaLanguage.UICharacterGrowthInvestTextText3)
    else
        self.view.TalentName.text=LuaLanguage.UICharacterGrowthTalentNameText2;self.view.TalentDetail.text=LuaLanguage.UICharacterGrowthTalentDetailText2
        self.view.Invest.interactable=false;self.view.InvestText.text=LuaLanguage.UICharacterGrowthInvestTextText2
    end
    Widgets.Rows(self,'SkillRows','JournalSkill',rows,function(row)
        if row.command=='select_course' then self:SelectCourse(row.id) end
    end)
end
function Growth:ProfessionBrowser()
    local growth=self.actor.Growth;local all=self.rules.professions.professions:All();local grid=self.professionPage=='grid'
    local rows={}
    if grid then
        for _,profession in ipairs(all) do if not growth:HasProfession(profession.id) then rows[#rows+1]=profession end end
        if self.selectedProfession and growth:HasProfession(self.selectedProfession) then self.selectedProfession=nil end
    else
        for i=0,growth.ProfessionCount-1 do rows[#rows+1]=self.rules.professions.professions:Get(growth:GetProfessionAt(i)) end
        if growth.ProfessionCount<#all then rows[#rows+1]={id=0,name=LuaLanguage.GrowthAddProfession} end
    end
    self.view.TreeTitle.text=grid and LuaLanguage.GrowthChooseProfession or string.format(LuaLanguage.GrowthProfessionTreeTitle,growth.ProfessionCount)
    local headers={
        {title=grid and LuaLanguage.GrowthBackProfessionTree or LuaLanguage.GrowthBackSkillTree,detail='',x=68,y=26,width=124,action=function()self:SetProfessionPage(grid and 'tree' or 'courses')end},
    }
    if not grid then headers[2]={title=self.view.Title.text,detail=string.format(LuaLanguage.GrowthStudyingProfession,self.rules.professions.professions:Get(growth.CurrentProfessionId).name),x=285,y=26,width=170} end
    for i,row in ipairs(headers) do
        if not self.professionHeaders[i] then self.professionHeaders[i]=self:CreateWidget('SkillAtlasCategory',self.view.Graph) end
        local widget=self.professionHeaders[i];widget:SetData(row.title,row.detail,self.view.Style,i==2,row.action)
        widget.view.Button.enabled=row.action~=nil
        local rect=widget.view.Root;rect.anchorMin,rect.anchorMax=CS.UnityEngine.Vector2(0,1),CS.UnityEngine.Vector2(0,1);rect.pivot=CS.UnityEngine.Vector2(.5,.5)
        place(rect,row.x,row.y,row.width,row.detail=='' and 44 or 54)
        widget.view.Detail.gameObject:SetActive(row.detail~='')
        place(widget.view.Title.rectTransform,8,0,-16,row.detail=='' and 44 or 28)
        widget.view.Title.alignment=CS.UnityEngine.TextAnchor.MiddleCenter
    end
    for i=#headers+1,#self.professionHeaders do self.professionHeaders[i]:SetData(nil) end
    local edges={};local firstY=grid and 124 or 156;local step=grid and 148 or 166
    for i,profession in ipairs(rows) do
        local rowIndex=math.floor((i-1)/3);local columns=math.min(3,#rows-rowIndex*3)
        local x=285+((i-1)%3-(columns-1)/2)*180;local y=firstY+rowIndex*step
        local row={id=profession.id,name=profession.name,iconPath=profession.iconPath,x=x,y=y}
        if not self.professionNodes[i] then self.professionNodes[i]=self:CreateWidget('ProfessionNode',self.view.Graph) end
        local selected=grid and self.selectedProfession==row.id or (not grid and growth.CurrentProfessionId==row.id)
        local label=row.id==0 and LuaLanguage.GrowthChooseNewProfession or (grid and LuaLanguage.GrowthAvailableProfession or (selected and LuaLanguage.GrowthCurrentProfession or LuaLanguage.GrowthJoinedProfession))
        self.professionNodes[i]:SetData(row,self.view.Style,selected,label,function(id)
            if id==0 then self:SetProfessionPage('grid')
            elseif grid then self.selectedProfession=id;self:Refresh()
            else self:OpenProfession(id) end
        end)
        if not grid then
            local branchStart=#rows<=3 and 285-(columns-1)*90 or 14
            edges[#edges+1]={from={x=branchStart,y=y-80},to={x=x,y=y-80}}
            edges[#edges+1]={from={x=x,y=y-80},to={x=x,y=y-66}}
        end
    end
    for i=#rows+1,#self.professionNodes do self.professionNodes[i]:SetData(nil) end
    if not grid and #rows>0 then
        edges[#edges+1]={from={x=285,y=53},to={x=285,y=76}}
        if #rows>3 then
            edges[#edges+1]={from={x=14,y=76},to={x=285,y=76}}
            edges[#edges+1]={from={x=14,y=76},to={x=14,y=76+math.floor((#rows-1)/3)*step}}
        end
    end
    for i,row in ipairs(edges) do
        if not self.professionEdges[i] then self.professionEdges[i]=self:CreateWidget('TalentEdge',self.view.Graph) end
        self.professionEdges[i]:SetBranch(row.from,row.to,self.view.Style,false,false);self.professionEdges[i].view.Root:SetAsFirstSibling()
    end
    for i=#edges+1,#self.professionEdges do self.professionEdges[i]:SetBranch(nil) end
    self.view.Graph.sizeDelta=CS.UnityEngine.Vector2(570,math.max(342,firstY+math.floor(math.max(0,#rows-1)/3)*step+82))
    local selected=grid and self.selectedProfession and self.rules.professions.professions:Get(self.selectedProfession)
    self.view.TalentName.text=selected and selected.name or (grid and LuaLanguage.GrowthChooseProfession or LuaLanguage.GrowthProfessionOverview)
    self.view.TalentDetail.text=selected and string.format(LuaLanguage.GrowthJoinProfessionDetail,selected.description) or (grid and (#rows==0 and LuaLanguage.GrowthAllProfessionsJoined or LuaLanguage.GrowthProfessionGridDetail) or LuaLanguage.GrowthProfessionTreeDetail)
    self.view.Invest.interactable=grid and self.selectedProfession~=nil or (not grid and growth.ProfessionCount<#all)
    self.view.InvestText.text=grid and LuaLanguage.GrowthJoinProfession or LuaLanguage.GrowthAddProfession
end
function Growth:CourseGraph(owned)
    local tree=self.courseTree;local style=self.view.Style
    self.view.Graph.sizeDelta=CS.UnityEngine.Vector2(tree.width,tree.height)
    local profession=tree.headers[1];profession.iconPath=self.rules.professions.professions:Get(profession.id).iconPath
    if not self.courseProfessionRoot then self.courseProfessionRoot=self:CreateWidget('ProfessionNode',self.view.Graph) end
    self.courseProfessionRoot:SetData(profession,style,true,'',function()self:SetProfessionPage('tree')end,true)
    for i=2,#tree.headers do
        local row=tree.headers[i];local index=i-1
        if not self.courseHeaders[index] then self.courseHeaders[index]=self:CreateWidget('SkillAtlasCategory',self.view.Graph) end
        local widget=self.courseHeaders[index]
        widget:SetData(row.name,'',style,false,nil)
        widget.view.Button.enabled=false
        local rect=widget.view.Root;rect.anchorMin,rect.anchorMax=CS.UnityEngine.Vector2(0,1),CS.UnityEngine.Vector2(0,1)
        rect.pivot=CS.UnityEngine.Vector2(.5,.5);rect.anchoredPosition=CS.UnityEngine.Vector2(row.x,-row.y);rect.sizeDelta=CS.UnityEngine.Vector2(132,44)
        place(widget.view.Title.rectTransform,8,0,-16,44);widget.view.Title.alignment=CS.UnityEngine.TextAnchor.MiddleCenter
        widget.view.Detail.gameObject:SetActive(false)
    end
    for i=#tree.headers,#self.courseHeaders do self.courseHeaders[i]:SetData(nil) end
    for i,row in ipairs(tree.edges) do
        if not self.courseEdges[i] then self.courseEdges[i]=self:CreateWidget('TalentEdge',self.view.Graph) end
        local widget=self.courseEdges[i]
        widget:SetBranch(row.from,row.to,style,row.fromId~=nil and owned[row.fromId] and owned[row.toId] or false,row.fromId~=nil)
        widget.view.Root:SetAsFirstSibling()
    end
    for i=#tree.edges+1,#self.courseEdges do self.courseEdges[i]:SetBranch(nil) end
    for i,node in ipairs(tree.nodes) do
        if not self.courseNodes[i] then self.courseNodes[i]=self:CreateWidget('TalentNode',self.view.Graph) end
        local state,label=self.rules.atlas:State(node.id,self.actor,self.stats,owned)
        if not owned[node.id] and node.course then
            local available=self.rules.professions:CanLearn(self.actor,node.id,self.stats,self.rules.atlas)
            label=available and LuaLanguage.GrowthCourseAvailable or (state=='eligible' and LuaLanguage.GrowthCourseNoOpportunity or LuaLanguage.GrowthCourseLocked)
            state=available and 'eligible' or 'locked'
        elseif not owned[node.id] then label=LuaLanguage.GrowthCourseOtherProfession end
        self.courseNodes[i]:SetSkillData(node,self.rules.skills:Get(node.id),state,label,style,self.selectedCourse==node.id,function(id) self:SelectCourse(id) end)
    end
    for i=#tree.nodes+1,#self.courseNodes do self.courseNodes[i]:SetSkillData(nil) end
end
function Growth:History()
    local all=self.system.chronicle:Rows(self.actor.Id);local pages=math.max(1,math.ceil(#all/8))
    self.historyPage=math.min(pages,math.max(1,self.historyPage));local rows={}
    for i=(self.historyPage-1)*8+1,math.min(#all,self.historyPage*8) do
        local row=all[i];rows[#rows+1]={title=row.date..'  【'..row.label..'】'..row.title..'  ·  '..row.location,body=row.body,color='805723'}
    end
    self.view.HistorySummary.text=string.format(LuaLanguage.UICharacterGrowthHistorySummaryText, (#all), (self.historyPage), (pages))
    self.view.PreviousHistory.interactable=self.historyPage>1;self.view.NextHistory.interactable=self.historyPage<pages
    Widgets.Rows(self,'HistoryRows','JournalEntry',rows)
end
function Growth:Tick() if self.revision~=self.actor.Growth.Revision or self.count~=self.system.data.JournalCount or self.socialRevision~=self.system.data.PartyBonds.Revision then self:Refresh() end end
function Growth:OnHide() self.previewSkill=nil;self.view.Character:ReleasePreview();if self.demo then self.demo:SetGrowthOpen(false);self.demo=nil end end
return Growth
