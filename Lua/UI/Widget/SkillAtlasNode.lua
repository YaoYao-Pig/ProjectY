local Class=require('Core.Class')
local Base=require('UI.UIWidgetCtrl')
local Node=Class('SkillAtlasNode',Base)
function Node:Bind() self:Listen(self.view.Button,function() if self.node then self.action(self.node.id,self.view.Root) end end) end
function Node:SetData(node,skill,state,label,style,geometry,selected,related,action)
    self.node,self.action=node,action;self.view.Root.gameObject:SetActive(node~=nil)
    if not node then return end
    self.view.Title.font,self.view.State.font=style.Font,style.Font
    self.view.Title.text=skill.name;self.view.State.text=label
    geometry:Place(self.view.Root,node.x,node.y)
    style:SetGlyph(self.view.Icon,skill.proficiency)
    style:Tint(self.view.Background,state=='owned' and '334E40' or state=='eligible' and 'F6EDDA' or 'D5CEBF')
    style:Tint(self.view.Icon,state=='owned' and 'ECDAB2' or '62583F')
    style:Tint(self.view.Border,selected and 'A26C31' or state=='owned' and '8E7955' or 'B8AA8D')
    self.view.Title.color=state=='owned' and CS.UnityEngine.Color(.95,.90,.79) or CS.UnityEngine.Color(.20,.25,.22)
    self.view.State.color=state=='owned' and CS.UnityEngine.Color(.79,.83,.69) or CS.UnityEngine.Color(.38,.38,.31)
    self.view.Group.alpha=related and 1 or .40
end
function Node:Show(args) Base.Show(self,args);self.view.Root.gameObject:SetActive(self.node~=nil) end
return Node
