local Class=require('Core.Class')
local Base=require('UI.UIWidgetCtrl')
local Party=Class('HudParty',Base)
function Party:Bind()
    self:Listen(self.view.Button,function() if self.row and self.activate then self.activate(self.row.id) end end)
end
function Party:SetData(row,style,selected,activate)
    self.activate=activate
    self.row=row;self.view.Root.gameObject:SetActive(row~=nil);if not row then return end
    self.view.Name.font,self.view.HealthText.font=style.Font,style.Font
    self.view.Name.text=row.name
    self.view.HealthText.text=row.riderHP and ('骑'..row.hp..'/'..row.maxHP..' 人'..row.riderHP..'/'..row.riderMaxHP)
        or (row.hp..' / '..row.maxHP)
    style:SetHealth(self.view.Health,row.hp/row.maxHP)
    self.view.Selected.gameObject:SetActive(selected==true)
end
function Party:Show(args) Base.Show(self,args);self.view.Root.gameObject:SetActive(self.row~=nil) end
return Party
