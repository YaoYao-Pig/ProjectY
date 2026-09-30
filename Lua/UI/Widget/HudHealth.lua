local Class=require('Core.Class')
local Base=require('UI.UIWidgetCtrl')
local Health=Class('HudHealth',Base)
function Health:Bind()
    self.effects={};self.icons=self.context.systems:Get('Config'):GetTable('BattleIconTable')
end
function Health:SetData(row,style,demo,iconStyle,feedback)
    self.retiring=false
    self.row=row;self.view.Root.gameObject:SetActive(row~=nil)
    if not row then
        if self.style then self.style:Untrack(self.view.Follower) end
        if self.feedback then self.feedback:UnbindHealth(self.view.HealthAnimation) end
        return
    end
    self.style,self.demo,self.feedback=style,demo,assert(feedback)
    self.view.Name.font,self.view.HealthText.font,self.view.APText.font=style.Font,style.Font,style.Font
    self.view.Name.text=row.name
    self.view.HealthText.text=row.riderHP and ('骑'..row.hp..'/'..row.maxHP..' 人'..row.riderHP..'/'..row.riderMaxHP)
        or (row.hp..' / '..row.maxHP)
    self.view.Team.color=row.team==1 and CS.UnityEngine.Color(.38,.74,.53,1) or row.team==0 and CS.UnityEngine.Color(.96,.78,.22,1) or CS.UnityEngine.Color(.87,.36,.27,1)
    feedback:BindHealth(self.view.HealthAnimation,row.id,row.healthId,row.hp/row.maxHP)
    self.view.APText.text=row.ap..' / '..row.maxAP..' AP';style:SetHealth(self.view.AP,row.ap/row.maxAP)
    for i,effect in ipairs(row.effects) do
        if not self.effects[i] then self.effects[i]=self:CreateWidget('HudStatusEffect',self.view.EffectSlots) end
        self.effects[i]:SetData(effect,iconStyle,self.icons:Get(effect.iconId))
    end
    for i=#row.effects+1,#self.effects do self.effects[i]:SetData(nil) end
    local rows=math.ceil(#row.effects/6)
    self.view.Root.sizeDelta=CS.UnityEngine.Vector2(160,50+rows*24)
    self.view.EffectSlots.sizeDelta=CS.UnityEngine.Vector2(152,rows*24)
    if row.screen then style:TrackScreen(self.view.Follower,demo:HealthScreenPosition(row.id))
    else style:Track(self.view.Follower,demo.WorldCamera,demo:HealthTarget(row.id)) end
end
function Health:HoveredEffect()
    if not self.row or not self.view.Root.gameObject.activeInHierarchy or not self.view.Follower.ProjectedVisible then return end
    for _,widget in ipairs(self.effects) do if widget.row and widget:IsHovered() then return widget end end
end
function Health:Show(args) Base.Show(self,args);self.view.Root.gameObject:SetActive(self.row~=nil) end
function Health:OnShow()
    if self.row and self.style then
        self.feedback:BindHealth(self.view.HealthAnimation,self.row.id,self.row.healthId,self.row.hp/self.row.maxHP)
        if self.row.screen then self.style:TrackScreen(self.view.Follower,self.demo:HealthScreenPosition(self.row.id))
        else self.style:Track(self.view.Follower,self.demo.WorldCamera,self.demo:HealthTarget(self.row.id)) end
    end
end
function Health:Retire()
    self.retiring=true;self.view.HealthText.text='0 / '..self.row.maxHP
end
function Health:Tick()
    if self.retiring and not self.view.HealthAnimation.IsAnimating then self:SetData(nil);return end
    if self.row and self.row.screen then self.view.Follower:SetScreenPoint(self.demo:HealthScreenPosition(self.row.id)) end
end
function Health:OnHide()
    if self.style then self.style:Untrack(self.view.Follower) end
    if self.feedback then self.feedback:UnbindHealth(self.view.HealthAnimation) end
end
return Health
