local Class=require('Core.Class')
local Base=require('UI.UIPanelCtrl')
local Widgets=require('UI.GrowthWidgets')
local L=require('Language')
local Growth=Class('CharacterGrowthCtr',Base)
function Growth:Bind()
    self.system=self.context.systems:Get('Growth');self.rules=self.system.rules;self.stats=self.system.stats
    self.appearance=require('Game.Adventure.PawnAppearance').New(self.context.systems:Get('Config'))
    self.view.Style:Prepare();self.nodes,self.edges={},{}
    self:Listen(self.view.Close,function() self:Close() end)
    for i=1,4 do self:Listen(self.view['Party'..i],function() self.actorIndex=i-1;self.historyPage=1;self.selectedNode=nil;self:Refresh() end) end
    for _,key in ipairs({'Overview','Skills','History'}) do self:Listen(self.view[key..'Tab'],function() self.tab=key;self:Refresh() end) end
    self:Listen(self.view.PreviousTree,function() self.treeIndex=self.treeIndex-1;self.selectedNode=nil;self:Refresh() end)
    self:Listen(self.view.NextTree,function() self.treeIndex=self.treeIndex+1;self.selectedNode=nil;self:Refresh() end)
    self:Listen(self.view.PreviousHistory,function() self.historyPage=self.historyPage-1;self:Refresh() end)
    self:Listen(self.view.NextHistory,function() self.historyPage=self.historyPage+1;self:Refresh() end)
    self:Listen(self.view.Invest,function() if self.selectedNode then self:Command('growth_talent',self.selectedNode) end end)
end
function Growth:OnShow(args)
    self.demo=assert(args.demo);self.demo:SetGrowthOpen(true)
    self.actorIndex,self.treeIndex,self.historyPage,self.tab,self.selectedNode=0,1,1,'Overview',nil
    self:Refresh()
end
function Growth:Command(command,id) self.demo:SendCommand(command,self.actor.Id,id);if self.visible then self:Refresh() end end
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
    local name,role=self.stats:Template(actor).name:match('^(.-)%s*·%s*(.+)$')
    self.view.Title.text=name or self.stats:Template(actor).name;self.view.Role.text=role or '远行者'
    self.view.HeroLevel.text='旅人  ·  等级 '..growth.Level
    self.view.HeroHealth.text='生命  '..actor.HP..' / '..actor.MaxHP
    self.view.HeroExperience.text=nextLevel and ('经验 '..growth.Experience..' / '..nextLevel.experience) or '已到达本阶段的顶点'
    self.view.ExperienceFill.sizeDelta=CS.UnityEngine.Vector2(210*(nextLevel and math.min(1,growth.Experience/nextLevel.experience) or 1),3)
    self.view.Summary.text='可用属性点 '..growth.AttributePoints..'    /    被动天赋点 '..growth.TalentPoints..'    /    尚未觉醒的潜力 '..growth.LockedPotential
    self.view.Character:Show(self.appearance:Template(actor.TemplateId,self.stats.equipment:ActorVisual(actor)))
    for _,key in ipairs({'Overview','Skills','History'}) do
        self.view[key].gameObject:SetActive(self.tab==key);self.view.Style:Highlight(self.view[key..'Tab'],self.tab==key)
        self.view[key..'TabText'].color=self.tab==key and CS.UnityEngine.Color(.91,.87,.77,1) or CS.UnityEngine.Color(.20,.24,.21,1)
    end
    if self.tab=='Overview' then self:Overview() elseif self.tab=='Skills' then self:Skills() else self:History() end
    self.view.Hint.text=self.demo.LastError~='' and (self.demo.LastError or '') or L.GrowthJourneyHint
    self.revision,self.count=growth.Revision,data.JournalCount
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
    self.view.TraitDetail.text=traits[1].body
    Widgets.Rows(self,'Traits','TraitTag',traits,function(row) self.view.TraitDetail.text=row.title..'\n\n'..row.body end)
end
function Growth:Skills()
    local actor=self.actor;local all=self.rules.trees:All();self.treeIndex=math.min(#all,math.max(1,self.treeIndex))
    local tree=all[self.treeIndex];local open=actor.Growth:HasTree(tree.id)
    if not self.selectedNode then self.selectedNode=tree.rootIds[1] end
    self.view.TreeTitle.text=tree.name..(open and '' or L.GrowthLockedTree)..'  /  '..(tree.unlockRule=='adjacent_any' and L.GrowthAdjacent or L.GrowthPrerequisites)
    self.view.PreviousTree.interactable=self.treeIndex>1;self.view.NextTree.interactable=self.treeIndex<#all
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
    self.view.Invest.interactable=available;self.view.InvestText.text=node and ('投入 '..node.pointCost..' 点') or L.GrowthChooseNode
    self.view.TalentName.text=node and self.rules.passives:Get(node.passiveId).name or '星火成途'
    self.view.TalentDetail.text=node and (self.rules.passives:Get(node.passiveId).description..'\n'..(available and '可以投入' or reason)) or tree.description
    local rows={};local growth=actor.Growth
    self.view.SkillTitle.text=growth.OfferCount>0 and (L.GrowthLearnAvailable..growth.PendingLevel) or L.GrowthKnownSkills
    for i=0,growth.OfferCount-1 do
        local row=self.rules.skills:Get(growth:GetOfferAt(i));rows[#rows+1]={id=row.id,offer=true,title=L.GrowthStudy..row.name,body=row.description,color='805723'}
    end
    for _,id in ipairs(self.stats.equipment:SkillIds(actor,self.stats:Template(actor))) do
        local row=self.rules.skills:Get(id);rows[#rows+1]={id=id,offer=false,title=(growth:HasSkill(id) and L.GrowthLearned or L.GrowthInnate)..row.name,body=row.description,available=false,color='354739'}
    end
    Widgets.Rows(self,'SkillRows','JournalSkill',rows,function(row) if row.offer then self:Command('growth_skill',row.id) end end)
end
function Growth:History()
    local all=self.system.chronicle:Rows(self.actor.Id);local pages=math.max(1,math.ceil(#all/8))
    self.historyPage=math.min(pages,math.max(1,self.historyPage));local rows={}
    for i=(self.historyPage-1)*8+1,math.min(#all,self.historyPage*8) do
        local row=all[i];rows[#rows+1]={title='#'..row.sequence..'  【'..row.label..'】'..row.title..'  ·  '..row.location,body=row.body,color='805723'}
    end
    self.view.HistorySummary.text='留下 '..#all..' 段经历  ·  '..self.historyPage..' / '..pages
    self.view.PreviousHistory.interactable=self.historyPage>1;self.view.NextHistory.interactable=self.historyPage<pages
    Widgets.Rows(self,'HistoryRows','JournalEntry',rows)
end
function Growth:Tick() if self.revision~=self.actor.Growth.Revision or self.count~=self.system.data.JournalCount then self:Refresh() end end
function Growth:OnHide() self.view.Character:ReleasePreview();if self.demo then self.demo:SetGrowthOpen(false);self.demo=nil end end
return Growth
