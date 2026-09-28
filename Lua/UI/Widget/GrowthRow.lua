local Class = require('Core.Class')
local Base = require('UI.UIWidgetCtrl')
local Row = Class('GrowthRow', Base)
function Row:Bind()
    self:Listen(self.view.Button,function() if self.action then self.action() end end)
end
function Row:SetData(row, style, action)
    self.row,self.action = row,action
    self.view.Root.gameObject:SetActive(row ~= nil)
    if not row then return end
    self.view.Title.font,self.view.Body.font = style.Font,style.Font
    self.view.Title.text,self.view.Body.text = row.title,row.body
    local color=row.color or 'D1B06E'
    self.view.Title.color=CS.UnityEngine.Color(tonumber(color:sub(1,2),16)/255,tonumber(color:sub(3,4),16)/255,tonumber(color:sub(5,6),16)/255,1)
    self.view.Button.interactable = action ~= nil and row.available ~= false
end
function Row:Show(args)
    Base.Show(self,args); self.view.Root.gameObject:SetActive(self.row ~= nil)
end
return Row
