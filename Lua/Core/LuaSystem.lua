local Class = require('Core.Class')
local LuaSystem = Class('LuaSystem')
function LuaSystem:ctor() self.enabled = true end
function LuaSystem:OnInit(context) self.context = context end
function LuaSystem:OnStart() end
function LuaSystem:Tick(dt, unscaledDt) end
function LuaSystem:FixedTick(dt) end
function LuaSystem:LateTick(dt, unscaledDt) end
function LuaSystem:OnPause(paused) end
function LuaSystem:OnShutdown() end
return LuaSystem
