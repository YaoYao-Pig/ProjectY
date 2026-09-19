local Registry = require('Core.SystemRegistry')
local registry = Registry(Services)
require('Game.Systems')(registry)
-- Export shutdown before startup, so partially initialized applications can always unwind.
function GameShutdown() registry:Shutdown() end
local ok, err = xpcall(function()
    registry:Start()
    if OpenDemo then registry:Get('UI'):Open('Demo') end
end, debug.traceback)
if not ok then registry:Shutdown(); error(err, 0) end
function GameTick(dt, unscaledDt) registry:Dispatch('Tick', dt, unscaledDt) end
function GameFixedTick(dt) registry:Dispatch('FixedTick', dt) end
function GameLateTick(dt, unscaledDt) registry:Dispatch('LateTick', dt, unscaledDt) end
function GamePause(paused) registry:Dispatch('OnPause', paused) end
function GameBack() registry:Get('UI'):Back() end
-- C# can request a record via LuaFunction.Call; dispose returned LuaTables after use.
function GetConfigRow(name, id) return registry:Get('Config'):GetTable(name):Get(id) end
-- Tooling can inspect the running registry through require('Main'); no second runtime is created.
return registry
