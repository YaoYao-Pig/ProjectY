local Class=require('Core.Class')
local Base=require('UI.UIWidgetCtrl')
local L=require('Language')
local Identity=require('Game.Presentation.CharacterIdentity')
local Row=Class('InspectionTarget',Base)
function Row:Bind()
    self.stats=self.context.systems:Get('Battle').stats
    self:Listen(self.view.Button,function()if self.row then self.action(self.row.key)end end)
end
function Row:SetData(row,selected,action)
    self.row,self.action=row,action
    self.view.Root.gameObject:SetActive(row~=nil)
    if not row then return end
    self.view.Title.DefaultText=Identity.Format(Identity.Read(self.stats,row.actor,row.name),20,13,'E3BE73')
    self.view.Body.DefaultText=row.owned and L.InspectionPartyLabel or L.InspectionTargetLabel
    self.view.Selected.gameObject:SetActive(selected)
end
function Row:Show(args)Base.Show(self,args);self.view.Root.gameObject:SetActive(self.row~=nil)end
return Row
