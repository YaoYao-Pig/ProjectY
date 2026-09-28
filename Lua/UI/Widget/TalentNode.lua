local Class = require('Core.Class')
local Base = require('UI.UIWidgetCtrl')
local Node = Class('TalentNode',Base)
function Node:Bind() self:Listen(self.view.Button,function() if self.action then self.action(self.node.id) end end) end
function Node:SetData(node,passive,actor,style,selected,available,action)
    self.node,self.action=node,action; self.view.Root.gameObject:SetActive(node~=nil)
    if not node then return end
    local rank=actor.Growth:GetRank(node.id)
    self.view.Title.font,self.view.Rank.font=style.Font,style.Font
    self.view.Title.text=passive.name;self.view.Rank.text=rank>0 and (rank..' / '..node.maxRank) or ''
    style:PlaceNode(self.view.Root,node.x,node.y)
    style:SetGlyph(self.view.Icon,passive.attributeNames[1])
    style:Tint(self.view.Background,rank>0 and '394D40' or (available and 'F4ECD7' or 'D5CDBA'))
    style:Tint(self.view.Icon,rank>0 and 'E8D3A7' or (available and '51462F' or '999483'))
    style:Tint(self.view.Ring,selected and '9E682E' or (rank>0 and '94753C' or (available and 'A49571' or 'C0B7A2')))
    self.view.Ring.rectTransform.localScale=CS.UnityEngine.Vector3(selected and 1.12 or 1,selected and 1.12 or 1,1)
end
function Node:Show(args) Base.Show(self,args);self.view.Root.gameObject:SetActive(self.node~=nil) end
return Node
