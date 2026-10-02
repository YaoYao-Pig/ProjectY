local Class=require('Core.Class')
local Base=require('UI.UIWidgetCtrl')
local Edge=Class('SkillAtlasEdge',Base)
function Edge:SetData(from,to,style,active,related)
    self.shown=from~=nil;self.view.Root.gameObject:SetActive(self.shown)
    if not from then return end
    style:SetLine(self.view.Line,from.x,from.y+54,to.x,to.y-54,active)
    self.view.Arrow.font=style.Font;self.view.Group.alpha=related and 1 or .25
end
function Edge:Show(args) Base.Show(self,args);self.view.Root.gameObject:SetActive(self.shown==true) end
return Edge
