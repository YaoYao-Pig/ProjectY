-- The demo supplies a native presentation/input adapter; no long-lived LuaTable crosses into C#.
return function(command, demo)
    local ui = require('Main'):Get('UI')
    if command == 'open' then ui:Open('BattleHUD', { demo = assert(demo) })
    elseif command == 'close' then ui:Close('BattleHUD')
    else error('Unknown Battle HUD command: ' .. tostring(command)) end
end
