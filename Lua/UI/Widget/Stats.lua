local Class = require('Core.Class')
local LuaLanguage = require('Language')
local Widget = require('UI.UIWidgetCtrl')
---@class Stats : UIWidgetCtrl
---@field view StatsWidgetView
local Stats = Class('Stats', Widget)
function Stats:Bind()
    self.model = self.context.systems:Get('PlayerModel')
    self.label = self.view.Stats
end
function Stats:OnShow()
    local function refresh()
        self.label.text = string.format(LuaLanguage.DemoStatsTemplate, self.model.data.Level, self.model.data.Coins)
    end
    self.visibleScope:Add(self.model.Changed:Subscribe(refresh)); refresh()
end
return Stats
