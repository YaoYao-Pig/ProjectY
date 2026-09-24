local Class = require('Core.Class')
local Widget = require('UI.UIWidgetCtrl')
---@class BattleAction : UIWidgetCtrl
---@field view BattleActionWidgetView
local Action = Class('BattleAction', Widget)
function Action:Bind()
    self:Listen(self.view.Button, function()
        if self.row and self.row.available then self.activate(self.row) end
    end)
end
function Action:Initialize(hud, activate)
    self.hud, self.activate = hud, activate
    self.view.Title.font = hud.Font; self.view.Cost.font = hud.Font; self.view.Shortcut.font = hud.Font
end
function Action:SetData(row, shortcut, selected, icon)
    self.row = row
    self.view.Title.text = row and row.name or ''
    self.view.Cost.text = row and (row.cost .. ' AP') or ''
    self.view.Shortcut.text = row and tostring(shortcut) or ''
    self.view.Button.interactable = row ~= nil and row.available
    self.view.Selected.gameObject:SetActive(row ~= nil and selected)
    if icon then self.hud:SetIcon(self.view.Icon, icon.id, icon.spritePath)
    else self.view.Icon.enabled = false end
end
function Action:IsHovered() return self.view.Pointer.Hovered end
function Action:OnHide() self.row = nil end
return Action
