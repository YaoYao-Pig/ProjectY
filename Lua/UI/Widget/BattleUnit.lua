local Class = require('Core.Class')
local Widget = require('UI.UIWidgetCtrl')
local L = require('Language')
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
    self.view.Group.alpha = row and (row.hp <= 0 and .4 or (row.acted and .55 or 1)) or 0
    self.view.Group.blocksRaycasts = row ~= nil
    self.view.Button.interactable = row ~= nil and row.hp > 0
    if not row then return end
    self.view.Name.text = row.name
    self.view.Detail.text = self.compact and (row.active and L.BattleActing or string.format(L.BattleSpeed, row.speed))
        or (row.hp <= 0 and L.BattleDown or string.format(L.BattleHP, row.hp, row.maxHP))
    self.view.Active.gameObject:SetActive(row.active)
    local color = row.team == 1 and CS.UnityEngine.Color(.36, .61, .49, 1) or CS.UnityEngine.Color(.72, .36, .30, 1)
    self.view.Side.color = color; self.view.Health.color = color
    self.hud:SetHealth(self.view.Health, row.hp / row.maxHP)
end
function Unit:OnHide() self.row = nil end
return Unit
