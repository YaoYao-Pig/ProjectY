local Class=require('Core.Class')
local Base=require('UI.UIWidgetCtrl')
local Node=Class('ProfessionNode',Base)
local function place(rect,x,y,w,h)
    rect.anchoredPosition=CS.UnityEngine.Vector2(x,-y);rect.sizeDelta=CS.UnityEngine.Vector2(w,h)
end
function Node:Bind()
    self:Listen(self.view.Button,function() if self.row then self.action(self.row.id) end end)
end
function Node:SetData(row,style,selected,label,action,compact)
    self.row,self.action=row,action;self.view.Root.gameObject:SetActive(row~=nil)
    if not row then return end
    local root=self.view.Root
    root.anchorMin,root.anchorMax=CS.UnityEngine.Vector2(0,1),CS.UnityEngine.Vector2(0,1)
    root.pivot=CS.UnityEngine.Vector2(.5,.5)
    place(root,row.x,row.y,compact and 132 or 144,compact and 44 or 132)
    place(self.view.Background.rectTransform,2,2,compact and 128 or 140,compact and 40 or 128)
    place(self.view.Icon.rectTransform,compact and 8 or 32,6,compact and 32 or 80,compact and 32 or 80)
    place(self.view.Title.rectTransform,compact and 48 or 4,compact and 0 or 88,compact and 80 or 136,compact and 44 or 24)
    self.view.Title.font,self.view.State.font,self.view.Plus.font=style.Font,style.Font,style.Font
    self.view.Title.fontSize=compact and 14 or 16
    self.view.Title.text=row.name;self.view.State.text=label
    self.view.State.gameObject:SetActive(not compact)
    self.view.Icon.gameObject:SetActive(row.id~=0);self.view.Plus.gameObject:SetActive(row.id==0)
    if row.id~=0 then style:SetArt(self.view.Icon,row.iconPath);style:Tint(self.view.Icon,'FFFFFF') end
    style:Tint(self.view.Background,selected and '365647' or '2D3932')
    style:Tint(self.view.Border,selected and 'D5AE68' or 'A08B61')
end
function Node:Show(args) Base.Show(self,args);self.view.Root.gameObject:SetActive(self.row~=nil) end
return Node
