local Class=require('Core.Class')
local Base=require('UI.UIWidgetCtrl')
local Row=Class('JournalAttribute',Base)
function Row:Bind() self:Listen(self.view.Button,function() if self.action then self.action() end end) end
function Row:SetData(row,style,action)
    self.row,self.action=row,action;self.view.Root.gameObject:SetActive(row~=nil)
    if not row then return end
    for _,key in ipairs({'Title','Body','Plus'}) do self.view[key].font=style.Font end
    self.view.Title.text=row.title;self.view.Body.text=row.body;style:SetGlyph(self.view.Icon,row.icon)
    self.view.Plus.gameObject:SetActive(row.available);self.view.Button.interactable=row.available
end
function Row:Show(args) Base.Show(self,args);self.view.Root.gameObject:SetActive(self.row~=nil) end
return Row
