local function readonly(value)
    if type(value) ~= 'table' then return value end
    local data = {}
    for key, item in pairs(value) do data[key] = readonly(item) end
    return setmetatable({}, {
        __index = data, __newindex = function() error('Catalog is read-only', 2) end,
        __pairs = function() return next, data, nil end, __len = function() return #data end,
        __metatable = false,
    })
end
return readonly(require('Generated.Catalog'))
