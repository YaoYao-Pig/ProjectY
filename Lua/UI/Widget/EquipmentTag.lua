local Class=require('Core.Class')
local Widget=require('UI.UIWidgetCtrl')
local Tag=Class('EquipmentTag',Widget)
function Tag:Initialize(workbench)
    self.view.Label.font=workbench.Font
end
function Tag:SetData(tag)
    self.view.Group.alpha=tag and 1 or 0
    self.view.Layout.ignoreLayout=tag==nil
    self.view.Label.text=tag and tag.name or ''
end
return Tag
