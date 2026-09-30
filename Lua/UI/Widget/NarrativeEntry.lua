local Class=require('Core.Class')
local Base=require('UI.UIWidgetCtrl')
local Entry=Class('NarrativeEntry',Base)
function Entry:Bind() self:Listen(self.view.Button,function() if self.action then self.action() end end) end
function Entry:SetData(row,font,action)
    self.row,self.action=row,action
    self.view.Root.gameObject:SetActive(row~=nil)
    if not row then return end
    self.view.Style:Prepare(font,0)
    self.view.Title.DefaultText=(action~=nil and row.available==false and '     ' or '')..row.title
    self.view.Body.DefaultText=row.body
    self.view.Title.gameObject:SetActive(row.title~='')
    self.view.Body.gameObject:SetActive(row.body~='')
    self.view.Button.interactable=action~=nil and row.available~=false
    self.view.Background.color=row.selected and CS.UnityEngine.Color(.28,.31,.22,1)
        or action and CS.UnityEngine.Color(.16,.23,.19,.95) or CS.UnityEngine.Color(.12,.16,.14,row.plain and 0 or .25)
    self.view.Locked.gameObject:SetActive(action~=nil and row.available==false)
end
function Entry:Show(args) Base.Show(self,args);self.view.Root.gameObject:SetActive(self.row~=nil) end
return Entry
