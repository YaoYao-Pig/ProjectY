local Class=require('Core.Class')
local Base=require('UI.UIWidgetCtrl')
local Tab=Class('TabButton',Base)
function Tab:Bind() self:Listen(self.view.Button,function() self.activate(self.id) end) end
function Tab:SetData(id,title,selected,font,activate)
    self.id,self.activate=id,activate
    self.view.Label.font=font;self.view.Label.text=title
    self.view.Selected.gameObject:SetActive(selected)
    self.view.Root.localScale=CS.UnityEngine.Vector3(selected and 1.12 or 1,selected and 1.12 or 1,1)
end
return Tab
