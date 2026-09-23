-- 复用 GameBootstrap 的常驻 LuaEnv；返回值为调用方须立即读取并释放的显示快照。
return function(command, a, b)
    local adventure = require('Main'):Get('Adventure')
    if command == 'start' then adventure:Start(a); return adventure:MapSnapshot(), adventure:Snapshot() end
    if command == 'area_layout' then return require('Main'):Get('MapArea'):LayoutSnapshot() end
    local ok, reason
    if command == 'visit' then ok, reason = adventure:Visit(a)
    elseif command == 'choose' then ok, reason = adventure:Choose(a)
    elseif command == 'return' then ok, reason = adventure:ReturnToMap()
    elseif command == 'snapshot' then ok = true
    elseif command:sub(1,5)=='area_' then ok,reason=adventure:AreaCommand(command,a,b)
    else ok, reason = adventure:BattleCommand(command, a, b) end
    local snapshot = adventure:Snapshot()
    snapshot.error = ok and '' or reason
    return snapshot
end
