-- LuaReference remains the serialized View. This proxy enables self.view.Key syntax.
local View = {}
function View.Create(reference)
    assert(reference, 'LuaReference is required')
    local values = {}
    return setmetatable({}, {
        __index = function(_, key)
            if values[key] == nil then values[key] = reference:Get(key) end
            return values[key]
        end,
        __newindex = function() error('UI view bindings are read-only', 2) end,
        __metatable = false,
    })
end
return View
