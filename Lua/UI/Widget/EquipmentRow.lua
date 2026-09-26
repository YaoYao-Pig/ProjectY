local Class=require('Core.Class')
local Widget=require('UI.UIWidgetCtrl')
local Row=Class('EquipmentRow',Widget)
function Row:Bind()
    self:Listen(self.view.Button,function() if self.row then self.callback(self.row) end end)
end
function Row:Initialize(workbench,callback)
    self.workbench=workbench;self.callback=callback
    self.view.Title.font=workbench.Font;self.view.Detail.font=workbench.Font
end
function Row:SetData(row)
    self.row=row;self.view.Group.alpha=row and 1 or 0
    self.view.Layout.ignoreLayout=row==nil
    self.view.Group.blocksRaycasts=row~=nil;self.view.Group.interactable=row~=nil
    if not row then return end
    self.view.Title.text=row.title;self.view.Detail.text=row.detail
    self.view.Button.interactable=row.enabled~=false
    self.view.Selected.gameObject:SetActive(row.selected==true)
    self.workbench:SetItemIcon(self.view.Icon,row.itemId,row.iconPath)
end
return Row
