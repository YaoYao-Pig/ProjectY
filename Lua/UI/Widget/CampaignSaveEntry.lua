local Class=require('Core.Class')
local Base=require('UI.Widget.NarrativeEntry')
local LuaLanguage=require('Language')
local Entry=Class('CampaignSaveEntry',Base)
function Entry:Bind()
    Base.Bind(self)
    self:Listen(self.view.Delete,function()
        if self.row and self.row.canDelete and self.deleteAction then self.deleteAction() end
    end)
end
function Entry:SetData(row,font,action,deleteAction)
    Base.SetData(self,row,font,action)
    self.deleteAction=deleteAction
    if not row then return end
    self.view.DeleteText.font=font
    self.view.DeleteText.text=row.canDelete and LuaLanguage.MenuDelete or LuaLanguage.MenuInUse
    self.view.Delete.interactable=row.canDelete==true
end
return Entry
