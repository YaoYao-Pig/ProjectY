local Class = require('Core.Class')
local Widget = require('UI.UIWidgetCtrl')
local L = require('Language')
local Identity=require('Game.Presentation.CharacterIdentity')
local Unit = Class('BattleUnit', Widget)
function Unit:Bind()
    self:Listen(self.view.Button, function() if self.row then self.focus(self.row.id) end end)
end
function Unit:Initialize(hud, compact, focus)
    self.hud, self.compact, self.focus = hud, compact, focus
    self.view.Name.font = hud.Font; self.view.Detail.font = hud.Font
end
function Unit:SetData(row)
    self.row = row
    self.view.Group.alpha = row and (not row.alive and .4 or (row.acted and .55 or 1)) or 0
    self.view.Group.blocksRaycasts = row ~= nil
    self.view.Button.interactable = row ~= nil and row.alive
    if not row then return end
    self.view.Name.text = Identity.Format(row.identity,self.compact and 15 or 17,11,'E3BE73')
    self.view.Detail.text = self.compact and (row.active and L.BattleActing or row.speedKnown==false and L.InspectionUnknown or string.format(L.BattleSpeed, row.speed))
        or (row.dead and L.DeathDoorDied or row.deathDoor and L.DeathDoorStatus or not row.alive and L.BattleDown or row.healthKnown==false and L.InspectionUnknown or string.format(L.BattleHP, row.hp, row.maxHP))
    self.view.Active.gameObject:SetActive(row.active)
    local color = (row.team==1 or row.team==4) and CS.UnityEngine.Color(.36,.61,.49,1)
        or row.team==2 and CS.UnityEngine.Color(.72,.36,.30,1) or CS.UnityEngine.Color(.96,.78,.22,1)
    self.view.Side.color = color; self.view.Health.color = color
    self.hud:SetHealth(self.view.Health, row.hp / row.maxHP)
end
function Unit:OnHide() self.row = nil end
return Unit
