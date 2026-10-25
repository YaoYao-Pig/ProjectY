local Class=require('Core.Class')
local Base=require('UI.UIPanelCtrl')
local Tree=require('UI.FactionTree')
local Language=require('Language')
local Labels=require('Config.LanguageProxy').Map(Language,{allied='UIFactionAllied',neutral='UIFactionNeutral',hostile='UIFactionHostile'})
local Relations=Class('FactionRelationsCtr',Base)
function Relations:Bind()
    self.adventure=self.context.systems:Get('Adventure')
    self.nodes,self.edges={},{}
    self.view.Style:Prepare()
    self.colors={allied=self.view.Allied.color,neutral=self.view.Neutral.color,hostile=self.view.Hostile.color,unknown=self.view.UnknownTitle.color}
    self:Listen(self.view.Close,function() self:Close() end)
    self:Listen(self.view.Home,function() self:Select(0) end)
end
function Relations:OnShow(args) self:Select(args.rootId or 0) end
function Relations:Select(id)
    local tree=Tree.Build(self.adventure,id);self.rootId=id;self.tree=tree
    self.view.RootName.text=tree.root.name;self.view.RootDetail.text=Language.UIFactionRoot
    self.view.Description.text=tree.root.description
    self.view.Home.interactable=id~=0
    self.view.Graph.sizeDelta=CS.UnityEngine.Vector2(tree.width,tree.height)
    self.view.UnknownTitle.gameObject:SetActive(tree.unknownCount>0)
    self.view.UnknownTitle.text=string.format(Language.UIFactionUnknownCount,tree.unknownCount)
    self.view.UnknownTitle.rectTransform.anchoredPosition=CS.UnityEngine.Vector2(40,-tree.unknownY)
    for i,group in ipairs(tree.groups) do
        self.view['Group'..i].text=string.format(Language.UIFactionGroupCount,Labels[group.relation],#group.nodes)
        self.view['Empty'..i].gameObject:SetActive(#group.nodes==0)
    end
    for i,row in ipairs(tree.edges) do
        if not self.edges[i] then self.edges[i]=self:CreateWidget('TalentEdge',self.view.Graph) end
        local edge=self.edges[i];edge:SetBranch(row.from,row.to,self.view.Style,true,false)
        edge.view.Line.color=self.colors[row.relation];edge.view.Root:SetAsFirstSibling()
    end
    for i=#tree.edges+1,#self.edges do self.edges[i]:SetBranch(nil) end
    for i,row in ipairs(tree.nodes) do
        if not self.nodes[i] then self.nodes[i]=self:CreateWidget('FactionNode',self.view.Graph) end
        self.nodes[i]:SetData(row,self.view.Style,self.colors[row.relation],function(nextId) self:Select(nextId) end)
    end
    for i=#tree.nodes+1,#self.nodes do self.nodes[i]:SetData(nil) end
    self.view.GraphScroll:StopMovement();self.view.GraphScroll.verticalNormalizedPosition=1
end
return Relations
