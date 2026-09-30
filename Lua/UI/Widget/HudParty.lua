local Class=require('Core.Class')
local Base=require('UI.UIWidgetCtrl')
local Party=Class('HudParty',Base)
function Party:Bind()
    self:Listen(self.view.Button,function() if self.row and self.activate then self.activate(self.row.id) end end)
end
function Party:SetData(row,style,selected,activate,feedback)
    self.activate=activate
    self.row=row;self.view.Root.gameObject:SetActive(row~=nil)
    if not row or not self.view.Root.gameObject.activeInHierarchy then
        if self.feedback then self.feedback:UnbindHealth(self.view.HealthAnimation) end
        self.portraitKey=nil;return
    end
    self.feedback=assert(feedback)
    self.view.Name.font,self.view.HealthText.font,self.view.APText.font=style.Font,style.Font,style.Font
    self.view.Name.text=row.name
    self.view.HealthText.text=row.riderHP and ('骑'..row.hp..'/'..row.maxHP..' 人'..row.riderHP..'/'..row.riderMaxHP)
        or (row.hp..' / '..row.maxHP)
    feedback:BindHealth(self.view.HealthAnimation,row.id,row.healthId,row.hp/row.maxHP)
    self.view.APText.text=row.ap..' / '..row.maxAP..' AP';style:SetHealth(self.view.AP,row.ap/row.maxAP)
    if self.portraitKey~=row.portraitKey then self.view.Portrait:Show(row.appearance);self.portraitKey=row.portraitKey end
    self.view.Selected.gameObject:SetActive(selected==true)
end
function Party:OnHide()
    self.view.Portrait:ReleasePreview();self.portraitKey=nil
    if self.feedback then self.feedback:UnbindHealth(self.view.HealthAnimation) end
end
function Party:OnShow()
    if self.row and self.feedback and self.view.Root.gameObject.activeInHierarchy then
        self.feedback:BindHealth(self.view.HealthAnimation,self.row.id,self.row.healthId,self.row.hp/self.row.maxHP)
    end
end
function Party:Show(args) Base.Show(self,args);self.view.Root.gameObject:SetActive(self.row~=nil) end
return Party
