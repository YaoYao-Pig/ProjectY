local Class = require('Core.Class')
local Widget = require('UI.UIWidgetCtrl')
---@class BattleAction : UIWidgetCtrl
---@field view BattleActionWidgetView
local Action = Class('BattleAction', Widget)
function Action:Bind()
    self.baseColors = self.view.Button.colors
    local color = CS.UnityEngine.Color
    self.palette = {
        selected = color(.32, .24, .105, 1), selectedHover = color(.46, .35, .16, 1), selectedPress = color(.23, .17, .075, 1),
        selectedDisabled = color(.13, .115, .085, 1), title = self.view.Title.color, detail = self.view.Cost.color,
        selectedTitle = color(1, .89, .60, 1), disabledText = color(.46, .48, .44, 1),
        icon = color(1, 1, 1, 1), disabledIcon = color(.50, .50, .50, .55),
    }
    self:Listen(self.view.Button, function()
        if self.row and self.row.available then self.activate(self.row) end
    end)
end
function Action:ApplyVisual(present, available, selected)
    -- Updating data must not restart the Button's native hover/press transition.
    if self.visualPresent == present and self.visualAvailable == available and self.visualSelected == selected then return end
    self.visualPresent, self.visualAvailable, self.visualSelected = present, available, selected
    local colors, base, palette = self.view.Button.colors, self.baseColors, self.palette
    colors.normalColor = selected and palette.selected or base.normalColor
    colors.highlightedColor = selected and palette.selectedHover or base.highlightedColor
    colors.pressedColor = selected and palette.selectedPress or base.pressedColor
    colors.selectedColor = colors.normalColor -- The model's selected skill owns selection, not EventSystem focus.
    colors.disabledColor = selected and palette.selectedDisabled or base.disabledColor
    colors.colorMultiplier, colors.fadeDuration = base.colorMultiplier, base.fadeDuration
    self.view.Button.colors = colors
    self.view.Title.color = not available and palette.disabledText or selected and palette.selectedTitle or palette.title
    self.view.Cost.color = available and (selected and palette.title or palette.detail) or palette.disabledText
    self.view.Shortcut.color = available and (selected and palette.selectedTitle or palette.detail) or palette.disabledText
    self.view.Icon.color = available and palette.icon or palette.disabledIcon
end
function Action:Initialize(hud, activate)
    self.hud, self.activate = hud, activate
    self.view.Title.font = hud.Font; self.view.Cost.font = hud.Font; self.view.Shortcut.font = hud.Font
end
function Action:SetData(row, shortcut, selected, icon)
    self.row = row
    self.view.Title.text = row and row.name or ''
    self.view.Cost.text = row and (row.cost .. ' AP') or ''
    self.view.Shortcut.text = row and shortcut and tostring(shortcut) or ''
    local present = row ~= nil
    local available = present and row.available
    selected = present and selected == true
    self.view.Button.interactable = available
    self.view.Selected.gameObject:SetActive(selected)
    self:ApplyVisual(present, available, selected)
    if icon then self.hud:SetIcon(self.view.Icon, icon.id, icon.spritePath)
    else self.view.Icon.enabled = false end
end
function Action:IsHovered() return self.view.Pointer.Hovered end
function Action:OnHide()
    self.row = nil
    self.view.Button.interactable = false
    self.view.Selected.gameObject:SetActive(false)
    self:ApplyVisual(false, false, false)
end
return Action
