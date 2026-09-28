local Class=require('Core.Class')
local Base=require('UI.UIWidgetCtrl')
local Skill=Class('CharacterSkill',Base)
function Skill:Bind()
    self:Listen(self.view.Button,function() if self.row and self.row.available then self.activate(self.row) end end)
end
function Skill:SetData(row,style,selected,activate)
    self.row,self.activate=row,activate;self.view.Root.gameObject:SetActive(row~=nil)
    if not row then return end
    self.view.Title.font=style.Font;self.view.Contexts.font=style.Font;self.view.State.font=style.Font
    self.view.Title.text=row.name;self.view.Contexts.text=row.contexts
    self.view.State.text=selected and '请选择目标' or row.available and '点击使用' or '暂不可用'
    self.view.Button.interactable=row.available;self.view.Selected.gameObject:SetActive(selected)
end
function Skill:IsHovered() return self.view.Pointer.Hovered end
function Skill:Show(args) Base.Show(self,args);self.view.Root.gameObject:SetActive(self.row~=nil) end
function Skill:OnHide() self.row=nil end
return Skill
