local Class = require('Core.Class')
local System = require('Core.LuaSystem')
local Signal = require('Core.Signal')
local Model = Class('PlayerModelSystem', System)
function Model:OnInit(context)
    System.OnInit(self, context)
    self.data = context.services.Player
    self.Changed = Signal(context.log)
    self.onChanged = function() self.Changed:Emit() end
    self.data:AddChangedListener(self.onChanged)
end
function Model:GrantReward()
    local config = self.context.systems:Get('Config'):GetTable('Rewards'):Get(1)
    local amount = config.amount:Evaluate({ level = self.data.Level, base = config.base })
    assert(amount >= 0 and amount <= 2147483647 and amount == math.floor(amount), 'Reward must be a nonnegative int32')
    self.data:AddCoins(amount)
end
function Model:AdvanceLevel() self.data:AdvanceLevel() end
function Model:OnShutdown()
    if self.onChanged then self.data:RemoveChangedListener(self.onChanged); self.onChanged = nil end
    if self.Changed then self.Changed:Clear() end
end
return Model
