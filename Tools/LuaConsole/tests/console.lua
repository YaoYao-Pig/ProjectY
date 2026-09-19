package.path = 'Lua/?.lua;' .. package.path
local registry = { state = 'running' }
package.loaded.Main = registry
Services = { marker = 'CSharpServices' }
local execute = assert(loadfile('Tools/LuaConsole/runtime.lua'))()
local count = 0
local function test(name, run)
    run(); count = count + 1; print('PASS ' .. name)
end

test('injected globals, existing registry and multiple/nil returns', function()
    local ok, output, result = execute('ConsoleFixture = 42; print("确认", ConsoleFixture); return console.systems.state, nil, console.services.marker', 'fixture')
    assert(ok and output == '确认\t42')
    assert(result:find('1: string = "running"', 1, true) and result:find('2: nil = nil', 1, true))
    assert(result:find('3: string = "CSharpServices"', 1, true))
    assert(ConsoleFixture == 42)
    assert(select(3, execute('return ConsoleFixture', 'next')) == '1: number = 42')
end)
test('syntax/runtime failures stay visible and retain earlier side effects', function()
    local ok, output, result, err = execute('local = broken', 'syntax')
    assert(not ok and output == '' and err:find('syntax'))
    ok, output, result, err = execute('ConsoleFixture = 7; print("before"); error("deliberate")', 'runtime')
    assert(not ok and output == 'before' and err:find('deliberate') and err:find('stack traceback'))
    assert(ConsoleFixture == 7)
    ok, output, result, err = execute('error({ reason = "data" })', 'error object')
    assert(not ok and type(err) == 'string' and err:find('stack traceback'))
end)
test('instruction limit breaks Lua loops and restores debugger hook', function()
    local previous = function() end
    debug.sethook(previous, '', 100000)
    local ok, _, _, err = execute('while true do end', 'budget')
    local hook, mask, interval = debug.gethook()
    assert(not ok and err:find('instruction budget exceeded'))
    assert(hook == previous and mask == '' and interval == 100000)
    debug.sethook()
    assert(execute('return 1', 'after budget'))
end)
test('retained injected functions log normally after execution', function()
    local printed
    local original = print
    print = function(value) printed = value end
    assert(execute('function ConsoleFixtureFunction() print("later") end', 'patch'))
    ConsoleFixtureFunction()
    print = original
    assert(printed == 'later')
end)
test('table previews handle cycles and output is bounded', function()
    local ok, output, result = execute('local value={}; value.self=value; print(string.rep("x", 40000)); return value', 'preview')
    assert(ok and #output < 33000 and output:find('output truncated'))
    assert(result:find('<cycle>', 1, true))
end)
print('LuaConsole: ' .. count .. ' focused Lua tests passed.')
