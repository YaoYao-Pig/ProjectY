local Class = require('Core.Class')
local System = require('Core.LuaSystem')
local Conditions = Class('ConditionSystem', System)

function Conditions:OnInit(context)
    System.OnInit(self, context)
    self.evaluator = require('Game.Condition.ConditionEvaluator').New(context.systems:Get('Config'):GetTable('ConditionTable'))
    self:Register('always', function() return true end, function() end)
    self:Register('never', function() return false end, function() end)
end

function Conditions:Register(kind, evaluate, validate)
    self.evaluator:Register(kind, evaluate, validate)
end

-- 注册器先执行全部 OnInit，再执行 OnStart；业务适配器在 OnInit 注册叶子类型。
function Conditions:OnStart() self.evaluator:Validate() end
function Conditions:Check(id, context) return self.evaluator:Check(id, context) end
function Conditions:OnShutdown() self.evaluator = nil end

return Conditions
