local Class = require('Core.Class')
local Panel = require('UI.UIPanelCtrl')
---@class InfoCtr : UIPanelCtrl
---@field view InfoPanelView
local Info = Class('InfoCtr', Panel)
function Info:Bind()
    self:Listen(self.view.Close, function() self:Close() end)
end
return Info
