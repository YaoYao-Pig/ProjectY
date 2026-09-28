local Class=require('Core.Class')
local Base=require('UI.UIWidgetCtrl')
local Edge=Class('TalentEdge',Base)
function Edge:SetData(edge,from,to,actor,style,directed)
    self.edge=edge;self.view.Root.gameObject:SetActive(edge~=nil)
    if not edge then return end
    style:SetLine(self.view.Line,from.x,from.y,to.x,to.y,actor.Growth:GetRank(from.id)>0 and actor.Growth:GetRank(to.id)>0)
    self.view.Arrow.font=style.Font;self.view.Arrow.gameObject:SetActive(directed)
end
function Edge:Show(args) Base.Show(self,args);self.view.Root.gameObject:SetActive(self.edge~=nil) end
return Edge
