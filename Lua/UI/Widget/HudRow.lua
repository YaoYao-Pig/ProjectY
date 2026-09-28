local Class=require('Core.Class')
local Base=require('UI.UIWidgetCtrl')
local Row=Class('HudRow',Base)
function Row:Bind() self:Listen(self.view.Button,function() if self.action then self.action(self.row) end end) end
function Row:SetData(row,style,action)
    self.row,self.action=row,action;self.view.Root.gameObject:SetActive(row~=nil)
    if not row then return end
    self.view.Title.font,self.view.Body.font=style.Font,style.Font
    self.view.Title.text=row.title;self.view.Body.text=row.body or ''
    self.view.Button.interactable=action~=nil and row.available~=false
end
function Row:Show(args) Base.Show(self,args);self.view.Root.gameObject:SetActive(self.row~=nil) end
return Row
