-- 仅用于输出预览 JSON；读表与地图生成仍由工程 Lua 模块负责。
local json = {}
local arrayType = {}
-- 显式标记数组，保证空候选列表编码为 [] 而不是 {}。
function json.array(items) return setmetatable(items or {}, arrayType) end
local escapes = { ['"'] = '\\"', ['\\'] = '\\\\', ['\b'] = '\\b', ['\f'] = '\\f', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }
local function quote(value)
    return '"' .. value:gsub('[%z\1-\31\\"]', function(char)
        return escapes[char] or string.format('\\u%04x', char:byte())
    end) .. '"'
end
function json.encode(value)
    local kind = type(value)
    if kind == 'string' then return quote(value) end
    if kind == 'boolean' then return tostring(value) end
    if kind == 'number' then
        assert(math.abs(value) < math.huge, 'Cannot encode a non-finite preview value')
        return string.format('%.17g', value)
    end
    assert(kind == 'table', 'Unsupported preview JSON type: ' .. kind)
    local parts = {}
    if getmetatable(value) == arrayType then
        for _, item in ipairs(value) do parts[#parts + 1] = json.encode(item) end
        return '[' .. table.concat(parts, ',') .. ']'
    end
    -- 对象键固定排序，方便比较相同种子与版本的导出结果。
    local keys = {}; for key in pairs(value) do assert(type(key) == 'string'); keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do parts[#parts + 1] = quote(key) .. ':' .. json.encode(value[key]) end
    return '{' .. table.concat(parts, ',') .. '}'
end
return json
