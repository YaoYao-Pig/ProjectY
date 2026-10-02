local Class=require('Core.Class')
local Base=require('UI.UIWidgetCtrl')
local Row=Class('SkillAtlasCategory',Base)
function Row:Bind() self:Listen(self.view.Button,function() if self.action then self.action() end end) end
function Row:SetData(text,detail,style,selected,action)
    self.action=action;self.shown=text~=nil;self.view.Root.gameObject:SetActive(self.shown)
    if not text then return end
    self.view.Title.font,self.view.Detail.font=style.Font,style.Font
    self.view.Title.text=text;self.view.Detail.text=detail or ''
    style:Highlight(self.view.Button,selected)
    self.view.Title.color=selected and CS.UnityEngine.Color(.94,.88,.74) or CS.UnityEngine.Color(.20,.25,.22)
    self.view.Detail.color=selected and CS.UnityEngine.Color(.79,.82,.70) or CS.UnityEngine.Color(.42,.43,.36)
end
function Row:Show(args) Base.Show(self,args);self.view.Root.gameObject:SetActive(self.shown==true) end
return Row
