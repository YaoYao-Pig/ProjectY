-- Editor-only injection runner. Kept outside Lua/ so it never enters a player build.
local pack = table.pack
local concat, insert = table.concat, table.insert
local raw_next, raw_type, raw_tostring = next, type, tostring
local gethook, sethook, traceback = debug.gethook, debug.sethook, debug.traceback
local compile, protected = load, xpcall
local globals = _G
local MAX_OUTPUT = 32768

local function describe(value, depth, visited)
    local kind = raw_type(value)
    if kind == 'string' then return string.format('%q', value:sub(1, 2048)) end
    if kind ~= 'table' then return raw_tostring(value) end
    if visited[value] then return '<cycle>' end
    if depth == 0 then return '<table>' end
    visited[value] = true
    local items, count = {}, 0
    for key, item in raw_next, value do
        count = count + 1
        if count > 12 then insert(items, '...'); break end
        insert(items, '[' .. describe(key, 0, visited) .. '] = ' .. describe(item, depth - 1, visited))
    end
    visited[value] = nil
    return '{ ' .. concat(items, ', ') .. ' }'
end

return function(source, chunkName)
    local messages, length, capturing = {}, 0, true
    local originalPrint = globals.print
    local environment = {
        console = { systems = assert(package.loaded.Main, 'Main registry is not ready'), services = Services },
        print = function(...)
            if not capturing then return originalPrint(...) end
            if length >= MAX_OUTPUT then return end
            local values = pack(...)
            for i = 1, values.n do values[i] = raw_tostring(values[i]) end
            local text = concat(values, '\t', 1, values.n)
            local clipped = text:sub(1, MAX_OUTPUT - length)
            insert(messages, clipped); length = length + #clipped + 1
        end,
    }
    -- Globals assigned in the injected chunk persist; locals retain normal Lua chunk scope.
    setmetatable(environment, { __index = globals, __newindex = globals })
    local chunk, compileError = compile(source, chunkName, 't', environment)
    if not chunk then return false, '', '', compileError end
    local oldHook, oldMask, oldCount = gethook()
    if oldHook ~= nil and raw_type(oldHook) ~= 'function' then
        return false, '', '', 'LuaConsole cannot replace the current native debugger hook'
    end
    local instructions = 0
    sethook(function()
        instructions = instructions + 10000
        if instructions > 2000000 then error('LuaConsole instruction budget exceeded', 0) end
    end, '', 10000)
    local success, result = protected(function()
        local values, lines = pack(chunk()), {}
        for i = 1, values.n do
            insert(lines, i .. ': ' .. raw_type(values[i]) .. ' = ' .. describe(values[i], 2, {}))
        end
        return concat(lines, '\n'):sub(1, MAX_OUTPUT)
    end, function(err) return traceback(raw_tostring(err), 2) end)
    sethook(oldHook, oldMask, oldCount)
    capturing = false
    local output = concat(messages, '\n')
    messages = nil -- Injected functions may outlive this request; don't retain captured output.
    if length >= MAX_OUTPUT then output = output .. '\n[output truncated]' end
    if success then return true, output, result, '' end
    return false, output, '', result
end
