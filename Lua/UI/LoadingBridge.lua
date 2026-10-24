return function(command, ...)
    local loading = require('Main'):Get('Loading')
    if command == 'begin' then return loading:Begin(...) end
    if command == 'report' then return loading:Report(...) end
    if command == 'finish' then return loading:Finish(...) end
    error('Unknown loading command: ' .. tostring(command))
end
