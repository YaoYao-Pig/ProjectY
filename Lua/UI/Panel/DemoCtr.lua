local Class = require('Core.Class')
local Panel = require('UI.UIPanelCtrl')
---@class DemoCtr : UIPanelCtrl
---@field view DemoPanelView
local Demo = Class('DemoCtr', Panel)
function Demo:Bind()
    local model = self.context.systems:Get('PlayerModel')
    local row = self.context.systems:Get('Config'):GetTable('Rewards'):Get(1)
    self.view.Title.text = row.title
    self.view.Description.text = row.description
    self:AddWidget('Stats', self.view.StatsWidget)
    self:Listen(self.view.Reward, function() model:GrantReward() end)
    self:Listen(self.view.LevelUp, function() model:AdvanceLevel() end)
    self:Listen(self.view.Info, function() self.context.systems:Get('UI'):Open('Info') end)
end
return Demo
