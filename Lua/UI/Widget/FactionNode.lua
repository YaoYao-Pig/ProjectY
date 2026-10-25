local Class=require('Core.Class')
local Base=require('UI.UIWidgetCtrl')
local Language=require('Language')
local Labels=require('Config.LanguageProxy').Map(Language,{allied='UIFactionAllied',neutral='UIFactionNeutral',hostile='UIFactionHostile'})
local Node=Class('FactionNode',Base)
function Node:Bind()
    self:Listen(self.view.Button,function() if self.row and self.row.discovered then self.select(self.row.id) end end)
end
function Node:SetData(row,style,color,select)
    self.row,self.select=row,select
    self.view.Root.gameObject:SetActive(row~=nil)
    if not row then return end
    self.view.Root.anchoredPosition=CS.UnityEngine.Vector2(row.x,-row.y)
    self.view.Name.font=style.Font;self.view.Detail.font=style.Font
    self.view.Name.text=row.name
    self.view.Button.interactable=row.discovered
    self.view.Detail.text=row.discovered and string.format(Language.UIFactionRelationValue,Labels[row.relation],row.value) or Language.UIFactionUnknownHint
    self.view.Accent.color=color;self.view.Detail.color=color
end
function Node:Show(args)
    Base.Show(self,args);self.view.Root.gameObject:SetActive(self.row~=nil)
end
return Node
