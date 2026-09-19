local Proxy = {}
local resolver
function Proxy.Bind(lookup) resolver = lookup end
function Proxy.Create(defaults)
    return setmetatable({}, {
        __index = function(_, id)
            local value = resolver and resolver(id)
            if value ~= nil then return value end -- Empty text is a valid override.
            return defaults[id]
        end,
        __newindex = function() error('Language is read-only; edit Language.lua defaults', 2) end,
        __metatable = false,
    })
end
return Proxy
