---@class ConfigFormula
local Formula = {}
local arities = { [3]=2, [4]=2, [5]=2, [6]=2, [7]=2, [8]=2, [9]=1,
    [16]=2, [17]=2, [18]=1, [19]=1, [20]=1, [21]=3 }
local functions = {
    [3]=function(a,b) return a+b end, [4]=function(a,b) return a-b end,
    [5]=function(a,b) return a*b end,
    [6]=function(a,b) assert(b ~= 0, 'Division by zero'); return a/b end,
    [7]=function(a,b) assert(b ~= 0, 'Division by zero'); return a%b end,
    [8]=function(a,b) return a^b end, [9]=function(a) return -a end,
    [16]=math.min, [17]=math.max, [18]=math.floor, [19]=math.ceil, [20]=math.abs,
    [21]=function(a,b,c) assert(b <= c, 'clamp minimum exceeds maximum'); return math.min(math.max(a,b),c) end,
}
local function finite(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end
function Formula.Read(reader, variables)
    local count = reader:U16()
    assert(count > 0 and count <= 256, 'Invalid formula instruction count')
    local allowed = {}; for _, name in ipairs(variables) do allowed[name] = true end
    local program, depth = {}, 0
    for i = 1, count do
        local opcode = reader:U8(); local operand
        if opcode == 1 then operand = reader:Float(); depth = depth + 1
        elseif opcode == 2 then
            operand = reader:String(); assert(allowed[operand], 'Unknown formula variable'); depth = depth + 1
        else
            local arity = assert(arities[opcode], 'Unknown formula opcode')
            assert(depth >= arity, 'Invalid formula stack'); depth = depth - arity + 1
        end
        program[i] = { opcode, operand }
    end
    assert(depth == 1, 'Invalid formula stack result')
    -- Program stays in a closure; configuration consumers cannot mutate instruction data.
    return setmetatable({}, {
        __index = { Evaluate = function(_, values)
            local stack = {}
            for _, instruction in ipairs(program) do
                local opcode, operand = instruction[1], instruction[2]
                if opcode == 1 then stack[#stack + 1] = operand
                elseif opcode == 2 then
                    local value = values[operand]; assert(finite(value), 'Missing/non-finite variable: ' .. operand)
                    stack[#stack + 1] = value + 0.0 -- same IEEE-754 arithmetic as the web preview; avoid Lua integer overflow
                else
                    local arity = arities[opcode]; local start = #stack - arity + 1
                    local result = functions[opcode](table.unpack(stack, start, #stack))
                    assert(finite(result), 'Non-finite formula result')
                    for i = #stack, start, -1 do stack[i] = nil end
                    stack[#stack + 1] = result
                end
            end
            return stack[1]
        end },
        __newindex = function() error('Config formula is read-only', 2) end,
        __metatable = false,
    })
end
return Formula
