-- 最小启动/回收回归：只有外部服务与配置读取故障注入，不模拟战斗规则。
package.path = 'Lua/?.lua;' .. package.path
local Class = require('Core.Class')
local System = require('Core.LuaSystem')
local Registry = require('Core.SystemRegistry')
local Battle = require('Game.Battle.BattleSystem')
local Adventure = require('Game.Adventure.AdventureSystem')
local appearances={HasRace=function()return true end}
local realConfig=require('Config.ConfigSystem')()
realConfig:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local appearanceTables={CharacterAppearancePoolTable=true,CharacterLoadoutTable=true,PawnTemplateTable=true}
local checks = 0
local function test(name, run)
    run(); checks = checks + 1; print('PASS ' .. name)
end
local function configType(getTable)
    local Config = Class('LifecycleConfigFixture', System)
    function Config:GetTable(name)
        if appearanceTables[name] then return realConfig:GetTable(name) end
        return getTable(name) or realConfig:GetTable(name)
    end
    return Config
end
local function startBattle(services, config)
    local errors, instance = {}, Battle()
    services.Appearances=appearances
    services.LogError = function(_, message) errors[#errors + 1] = message end
    local registry = Registry(services)
    registry:Register('Config', config)
    registry:Register('Battle', function() return instance end, {'Config'})
    local ok, err = pcall(function() registry:Start() end)
    return ok, err, registry, instance, errors
end
local function assertOriginalFailure(ok, err, registry, errors, pattern)
    assert(not ok, 'Startup must fail')
    assert(#errors == 0, 'Rollback added a secondary error: ' .. table.concat(errors, '\n'))
    assert(tostring(err):find(pattern), tostring(err))
    assert(registry.state == 'stopped' and next(registry.instances) == nil)
end
test('missing Adventure bridge reports the required generation step without cleanup errors', function()
    local ok, err, registry, instance, errors = startBattle({}, configType(function() error('Should not load config') end))
    assertOriginalFailure(ok, err, registry, errors, 'XLua/Generate Code')
    instance:OnShutdown(); registry:Shutdown()
end)
test('missing Battle data is a clear startup error with safe rollback', function()
    local ok, err, registry, instance, errors = startBattle({Adventure = {}}, configType(function() error('Should not load config') end))
    assertOriginalFailure(ok, err, registry, errors, 'Adventure.Battle')
    instance:OnShutdown()
end)
test('config failure after acquiring battle state clears acquired resources only once', function()
    local clears = 0
    local services = {Adventure = {Equipment={},Battle = {Clear = function() clears = clears + 1 end}}}
    local ok, err, registry, instance, errors = startBattle(services, configType(function() error('fixture config read failure') end))
    assertOriginalFailure(ok, err, registry, errors, 'fixture config read failure')
    assert(clears == 1)
    instance:OnShutdown(); registry:Shutdown(); assert(clears == 1)
end)
test('normal Battle shutdown releases listeners and state once', function()
    local clears, calls = 0, 0
    local services = {Adventure = {Equipment={},Battle = {Clear = function() clears = clears + 1 end}}}
    function services:ReadConfig(name)
        local file = assert(io.open('Assets/GameFramework/Resources/_Gen/Config/' .. name .. '.bytes', 'rb'))
        local bytes = file:read('*a'); file:close(); return bytes
    end
    local ok, err, registry, instance, errors = startBattle(services, require('Config.ConfigSystem'))
    assert(ok, tostring(err))
    local changed = instance.Changed
    changed:Subscribe(function() calls = calls + 1 end)
    changed:Emit(); assert(calls == 1)
    registry:Shutdown(); instance:OnShutdown(); changed:Emit()
    assert(calls == 1 and clears == 1 and #errors == 0)
end)
test('Adventure rollback before acquiring state preserves the original config failure', function()
    local errors, instance = {}, Adventure()
    local registry = Registry({Appearances=appearances,CharacterSaves={},LogError = function(_, err) errors[#errors + 1] = err end})
    registry:Register('Config', configType(function() error('fixture adventure recipe failure') end))
    registry:Register('Adventure', function() return instance end, {'Config'})
    local ok, err = pcall(function() registry:Start() end)
    assertOriginalFailure(ok, err, registry, errors, 'fixture adventure recipe failure')
    instance:OnShutdown()
end)
test('Adventure rollback after acquiring state resets it only once', function()
    local resets, errors, instance = 0, {}, Adventure()
    local services = {Appearances=appearances,CharacterSaves={},Adventure = {Reset = function() resets = resets + 1 end}, Player = {}}
    services.LogError = function(_, err) errors[#errors + 1] = err end
    local registry = Registry(services)
    registry:Register('Config', configType(function(name)
        -- First config read after Adventure takes its Data; no native subsystem stubs are needed.
        if name=='MapAreaObstacleTable' then error('fixture acquired adventure config failure') end
    end))
    for _, name in ipairs({'Map', 'MapArea', 'Battle', 'AdventureEvents','Equipment','Growth'}) do registry:Register(name, System) end
    registry:Register('Adventure', function() return instance end, {'Config', 'Map', 'MapArea', 'Battle', 'AdventureEvents','Equipment','Growth'})
    local ok, err = pcall(function() registry:Start() end)
    assertOriginalFailure(ok, err, registry, errors, 'fixture acquired adventure config failure')
    assert(resets == 1)
    instance:OnShutdown(); registry:Shutdown(); assert(resets == 1)
end)
realConfig:OnShutdown()
print('Adventure lifecycle: ' .. checks .. ' checks passed')
