local Class=require('Core.Class')
local Base=require('UI.UIPanelCtrl')
local Widgets=require('UI.GrowthWidgets')
local L=require('Language')
local Growth=Class('CharacterGrowthCtr',Base)
local function place(rect,x,y,width,height)
    rect.anchoredPosition=CS.UnityEngine.Vector2(x,-y);rect.sizeDelta=CS.UnityEngine.Vector2(width,height)
end
function Growth:Bind()
    self.system=self.context.systems:Get('Growth');self.rules=self.system.rules;self.stats=self.system.stats
    self.appearance=require('Game.Adventure.PawnAppearance').New(self.context.systems:Get('Config'))
    self.view.Style:Prepare();self.nodes,self.edges={},{}
    self:Listen(self.view.Close,function() self:Close() end)
    self:Listen(self.view.Atlas,function()
        local demo=self.demo;local resume={actorIndex=self.actorIndex,tab=self.tab,skillMode=self.skillMode,
            treeIndex=self.treeIndex,selectedNode=self.selectedNode,selectedCourse=self.selectedCourse}
        self:Close();self.context.systems:Get('UI'):Open('SkillAtlas',{demo=demo,actorIndex=resume.actorIndex,returnTo=resume})
    end)
    for i=1,4 do self:Listen(self.view['Party'..i],function()
        self.actorIndex=i-1;self.historyPage=1;self.selectedNode=nil;self.selectedCourse=nil;self.treeIndex=nil;self.choosingProfession=false;self:Refresh()
    end) end
    for _,key in ipairs({'Overview','Skills','History'}) do self:Listen(self.view[key..'Tab'],function() self.tab=key;self:Refresh() end) end
    self:Listen(self.view.PreviousTree,function() self.skillMode='profession';self:Refresh();self.view.SkillRowsScroll.verticalNormalizedPosition=1 end)
    self:Listen(self.view.NextTree,function() self.skillMode='talent';self:Refresh();self.view.SkillRowsScroll.verticalNormalizedPosition=1 end)
    self:Listen(self.view.PreviousHistory,function() self.historyPage=self.historyPage-1;self:Refresh() end)
    self:Listen(self.view.NextHistory,function() self.historyPage=self.historyPage+1;self:Refresh() end)
    self:Listen(self.view.Invest,function()
        if self.skillMode=='talent' and self.selectedNode then self:Command('growth_talent',self.selectedNode)
        elseif self.skillMode=='profession' and not self.choosingProfession and self.selectedCourse then self:Command('growth_skill',self.selectedCourse) end
    end)
    self.view.OverviewTabText.text='属性加点';self.view.SkillsTabText.text='职业与天赋';self.view.HistoryTabText.text='旅途经历'
    self.view.AtlasText.text='技能图鉴';self.view.PreviousTreeText.text='职业技能';self.view.NextTreeText.text='被动天赋'
    place(self.view.PreviousTree.transform,0,0,126,29);place(self.view.NextTree.transform,136,0,126,29)
    place(self.view.TreeTitle.rectTransform,278,0,292,29)
end
function Growth:OnShow(args)
    self.demo=assert(args.demo);self.demo:SetGrowthOpen(true)
    self.actorIndex,self.treeIndex,self.historyPage,self.tab,self.selectedNode=args.actorIndex or 0,args.treeIndex,1,args.tab or 'Overview',args.selectedNode
    self.skillMode,self.selectedCourse=args.skillMode or 'profession',args.selectedCourse
    self.choosingProfession=false
    self:Refresh()
    self.view.SkillRowsScroll.verticalNormalizedPosition=1
end
function Growth:Command(command,id)
    self.demo:SendCommand(command,self.actor.Id,id)
    if command=='growth_profession' then self.treeIndex=nil;self.selectedNode=nil;self.selectedCourse=nil end
    if self.visible then self:Refresh() end
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
    self.view.HeroLevel.text='旅人  ·  等级 '..growth.Level
    self.view.HeroHealth.text='生命  '..actor.HP..' / '..actor.MaxHP
    self.view.HeroExperience.text=nextLevel and ('经验 '..growth.Experience..' / '..nextLevel.experience) or '已到达本阶段的顶点'
    self.view.ExperienceFill.sizeDelta=CS.UnityEngine.Vector2(210*(nextLevel and math.min(1,growth.Experience/nextLevel.experience) or 1),3)
    self.view.Summary.text='属性点 '..growth.AttributePoints..'  /  天赋点 '..growth.TalentPoints..'  /  学习机会 '..growth.PendingCount..'  /  潜力 '..growth.LockedPotential
    self.view.Character:Show(self.appearance:Template(actor.TemplateId,self.stats.equipment:ActorVisual(actor)))
    for _,key in ipairs({'Overview','Skills','History'}) do
        self.view[key].gameObject:SetActive(self.tab==key);self.view.Style:Highlight(self.view[key..'Tab'],self.tab==key)
        self.view[key..'TabText'].color=self.tab==key and CS.UnityEngine.Color(.91,.87,.77,1) or CS.UnityEngine.Color(.20,.24,.21,1)
    end
    if self.tab=='Overview' then self:Overview() elseif self.tab=='Skills' then self:Skills() else self:History() end
    local hints={Overview='属性点用于 + 加点；旅途印记中可查看特质、关系和荣誉。',
        Skills=self.skillMode=='talent' and '被动天赋消耗天赋点；右侧目录切换天赋树，选中节点后投入。' or '选择课程查看详情，再点击学习；转职免费，已学能力保留。技能图鉴可查看全部前置。',
        History='每段经历记录发生日期、地点与同行者。'}
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
    if #traits==0 then traits[1]={title=L.GrowthNoTraits,body=L.GrowthTraitHint,color='354739'} end
    local story=self.context.systems:Get('Adventure').partyStory
    for _,row in ipairs(story:OverviewRows(actor)) do traits[#traits+1]=row end
    self.view.TraitDetail.text=traits[1].body
    Widgets.Rows(self,'Traits','TraitTag',traits,function(row) self.view.TraitDetail.text=row.title..'\n\n'..row.body end)
end
function Growth:Skills()
    local passive=self.skillMode=='talent'
    self.view.Style:Highlight(self.view.PreviousTree,not passive);self.view.Style:Highlight(self.view.NextTree,passive)
    self.view.PreviousTreeText.color=not passive and CS.UnityEngine.Color(.91,.87,.77,1) or CS.UnityEngine.Color(.20,.24,.21,1)
    self.view.NextTreeText.color=passive and CS.UnityEngine.Color(.91,.87,.77,1) or CS.UnityEngine.Color(.20,.24,.21,1)
    self.view.GraphScroll.gameObject:SetActive(passive);self.view.SkillTitle.gameObject:SetActive(passive)
    local scroll=self.view.SkillRowsScroll
    place(scroll.transform,passive and 607 or 0,passive and 207 or 40,passive and 267 or 570,passive and 170 or 337)
    place(scroll.viewport,0,0,passive and 267 or 570,passive and 170 or 337)
    self.view.SkillRows.sizeDelta=CS.UnityEngine.Vector2(passive and 267 or 570,self.view.SkillRows.sizeDelta.y)
    place(self.view.TalentDetail.rectTransform,607,39,268,passive and 68 or 255)
    place(self.view.Invest.transform,607,passive and 116 or 332,267,35)
    if passive then self:Talents() else self:Courses() end
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
    self.view.TreeTitle.text=tree.name..(open and '' or L.GrowthLockedTree)
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
    self.view.Invest.interactable=available;self.view.InvestText.text=node and ('投入 '..node.pointCost..' 天赋点') or L.GrowthChooseNode
    self.view.TalentName.text=node and self.rules.passives:Get(node.passiveId).name or '星火成途'
    self.view.TalentDetail.text=node and (self.rules.passives:Get(node.passiveId).description..'\n'..(available and '可以投入' or reason)) or tree.description
    self.view.SkillTitle.text='天赋树目录 · '..actor.Growth.TalentPoints..' 点可用'
    local rows={}
    for i,row in ipairs(all) do rows[#rows+1]={id=i,title=(i==self.treeIndex and '当前 · ' or '')..row.name,
        body=(actor.Growth:HasTree(row.id) and '已开放 · ' or '尚未解锁 · ')..(row.unlockRule=='adjacent_any' and L.GrowthAdjacent or L.GrowthPrerequisites),color='354739'} end
    Widgets.Rows(self,'SkillRows','JournalSkill',rows,function(row) self.treeIndex=row.id;self.selectedNode=nil;self:Refresh() end)
end
function Growth:Courses()
    local actor=self.actor;local rows={};local growth=actor.Growth
    local professions=self.rules.professions
    local current=professions.professions:Get(growth.CurrentProfessionId)
    self.view.TreeTitle.text=current.name..' · 学习机会 '..growth.PendingCount
    rows[#rows+1]={command='choose_profession',title=self.choosingProfession and '返回当前职业技能' or '切换研习职业',
        body='探索期间免费转职；已学能力永久保留，装备仍由属性与触媒要求决定。',color='354739'}
    if self.choosingProfession then
    self.view.TalentName.text='选择研习职业';self.view.TalentDetail.text='转职后开放对应课程和天赋树。\n\n已掌握的技能与天赋保留，可自由组合。\n\n转职不消耗学习机会，也不赠送新技能。'
    self.view.Invest.interactable=false;self.view.InvestText.text='在左侧选择职业'
    for _,profession in ipairs(professions.professions:All()) do
        local selected=profession.id==growth.CurrentProfessionId
        rows[#rows+1]={id=profession.id,command='growth_profession',title=(selected and '正在研习 · ' or '转入职业 · ')..profession.name,
            body=profession.description..' 转职不赠送新技能。',available=not selected,color='354739'}
    end
    else
    local courses={}
    for _,course in ipairs(professions.courses:All()) do if course.professionId==growth.CurrentProfessionId then
        local row=self.rules.skills:Get(course.skillId);local available,reason=professions:CanLearn(actor,row.id,self.stats,self.rules.atlas)
        local owned=growth:HasSkill(row.id)
        for _,id in ipairs(self.stats:Template(actor).skillIds) do if id==row.id then owned=true end end
        courses[#courses+1]={id=row.id,command='select_course',title=(owned and '已掌握 · ' or (available and '可学习 · ' or '未满足 · '))..row.name,
            body=(row.skillKind=='preparation' and '战前准备 · ' or '主动技能 · ')..reason..'\n'..row.description,
            order=owned and 3 or (available and 1 or 2),color=available and '805723' or '354739'}
    end end
    table.sort(courses,function(a,b) return a.order==b.order and a.id<b.id or a.order<b.order end)
    for _,row in ipairs(courses) do rows[#rows+1]=row end
    local shown={};for _,row in ipairs(courses) do shown[row.id]=true end
    local owned=self.rules.atlas:Owned(actor,self.stats)
    for _,id in ipairs(self.stats.equipment:SkillIds(actor,self.stats:Template(actor))) do if not shown[id] then
        local row=self.rules.skills:Get(id);local _,source=self.rules.atlas:State(id,actor,self.stats,owned)
        rows[#rows+1]={id=id,command='select_course',title=source..' · '..row.name,body=row.description,color='354739'}
    end
    end
    local found=false;for _,row in ipairs(rows) do if row.command=='select_course' and row.id==self.selectedCourse then found=true end end
    if not found then self.selectedCourse=rows[2] and rows[2].id end
    for _,row in ipairs(rows) do if row.command=='select_course' and row.id==self.selectedCourse then row.title='› '..row.title end end
    if self.selectedCourse then
        local skill=self.rules.skills:Get(self.selectedCourse);local available,reason=professions:CanLearn(actor,skill.id,self.stats,self.rules.atlas)
        self.view.TalentName.text=skill.name
        local kind=skill.skillKind=='preparation' and '战前准备技能' or '主动技能'
        local condition=self.rules.atlas:EquipmentCondition(skill,actor,self.stats)
        self.view.TalentDetail.text=kind..' · '..reason..'\n\n'..skill.description..(condition and '\n\n'..condition or '')..'\n\n详细效果与前置可在技能图鉴中查看。'
        self.view.Invest.interactable=available;self.view.InvestText.text=available and '学习 · 消耗 1 次机会' or (growth:HasSkill(skill.id) and '已经掌握' or '暂不可学习')
    else
        self.view.TalentName.text='当前职业暂无课程';self.view.TalentDetail.text='可切换研习职业，查看其他职业的课程。'
        self.view.Invest.interactable=false;self.view.InvestText.text='无可选课程'
    end
    end
    Widgets.Rows(self,'SkillRows','JournalSkill',rows,function(row)
        if row.command=='choose_profession' then self.choosingProfession=not self.choosingProfession;self:Refresh();self.view.SkillRowsScroll.verticalNormalizedPosition=1
        elseif row.command=='select_course' then self.selectedCourse=row.id;self:Refresh()
        elseif row.command then self.choosingProfession=false;self:Command(row.command,row.id) end
    end)
end
function Growth:History()
    local all=self.system.chronicle:Rows(self.actor.Id);local pages=math.max(1,math.ceil(#all/8))
    self.historyPage=math.min(pages,math.max(1,self.historyPage));local rows={}
    for i=(self.historyPage-1)*8+1,math.min(#all,self.historyPage*8) do
        local row=all[i];rows[#rows+1]={title=row.date..'  【'..row.label..'】'..row.title..'  ·  '..row.location,body=row.body,color='805723'}
    end
    self.view.HistorySummary.text='留下 '..#all..' 段经历  ·  '..self.historyPage..' / '..pages
    self.view.PreviousHistory.interactable=self.historyPage>1;self.view.NextHistory.interactable=self.historyPage<pages
    Widgets.Rows(self,'HistoryRows','JournalEntry',rows)
end
function Growth:Tick() if self.revision~=self.actor.Growth.Revision or self.count~=self.system.data.JournalCount or self.socialRevision~=self.system.data.PartyBonds.Revision then self:Refresh() end end
function Growth:OnHide() self.view.Character:ReleasePreview();if self.demo then self.demo:SetGrowthOpen(false);self.demo=nil end end
return Growth
