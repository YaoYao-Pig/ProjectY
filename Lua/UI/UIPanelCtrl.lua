local Class = require('Core.Class')
local Widget = require('UI.UIWidgetCtrl')
---@class UIPanelCtrl : UIWidgetCtrl
---@field panel CS.ProjectY.UI.LuaPanel
local Panel = Class('UIPanelCtrl', Widget)
function Panel:Close() self.context.systems:Get('UI'):Close(self.panelName) end
return Panel
