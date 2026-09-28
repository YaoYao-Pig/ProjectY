local Class=require('Core.Class')
local Base=require('UI.UIWidgetCtrl')
local Health=Class('HudHealth',Base)
function Health:SetData(row,style,demo)
    self.row=row;self.view.Root.gameObject:SetActive(row~=nil)
    if not row then if self.style then self.style:Untrack(self.view.Follower) end;return end
    self.style,self.demo=style,demo
    self.view.Name.font,self.view.HealthText.font=style.Font,style.Font
    self.view.Name.text=row.name
    self.view.HealthText.text=row.riderHP and ('骑'..row.hp..'/'..row.maxHP..' 人'..row.riderHP..'/'..row.riderMaxHP)
        or (row.hp..' / '..row.maxHP)
    self.view.Health.color=row.team==1 and CS.UnityEngine.Color(.38,.74,.53,1) or row.team==0 and CS.UnityEngine.Color(.96,.78,.22,1) or CS.UnityEngine.Color(.87,.36,.27,1)
    style:SetHealth(self.view.Health,row.hp/row.maxHP)
    if row.screen then style:TrackScreen(self.view.Follower,demo:HealthScreenPosition(row.id))
    else style:Track(self.view.Follower,demo.WorldCamera,demo:HealthTarget(row.id)) end
end
function Health:Show(args) Base.Show(self,args);self.view.Root.gameObject:SetActive(self.row~=nil) end
function Health:OnShow()
    if self.row and self.style then
        if self.row.screen then self.style:TrackScreen(self.view.Follower,self.demo:HealthScreenPosition(self.row.id))
        else self.style:Track(self.view.Follower,self.demo.WorldCamera,self.demo:HealthTarget(self.row.id)) end
    end
end
function Health:Tick() if self.row and self.row.screen then self.view.Follower:SetScreenPoint(self.demo:HealthScreenPosition(self.row.id)) end end
function Health:OnHide() if self.style then self.style:Untrack(self.view.Follower) end end
return Health
