local Class=require('Core.Class')
local Base=require('UI.UIWidgetCtrl')
local Prompt=Class('HudInteraction',Base)
function Prompt:SetData(row,style,demo)
    self.row=row;self.style=style;self.demo=demo;self.view.Root.gameObject:SetActive(row~=nil)
    if not row then style:Untrack(self.view.Follower);return end
    self.view.Key.font=style.Font;self.view.Label.font=style.Font
    self.view.Key.text='E';self.view.Label.text=row.action..' · '..row.title
    CS.ProjectY.Samples.InteractionPromptBridge.Track(style,self.view.Follower,demo,row.kind,row.id,row.cellIndex)
end
function Prompt:Tick()
    if self.row then CS.ProjectY.Samples.InteractionPromptBridge.Track(self.style,self.view.Follower,self.demo,self.row.kind,self.row.id,self.row.cellIndex) end
end
function Prompt:OnHide() if self.style then self.style:Untrack(self.view.Follower) end end
return Prompt
