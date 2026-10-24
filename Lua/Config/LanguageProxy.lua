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
-- Store language keys in module-level label maps; resolve after Localization has loaded its table.
function Proxy.Map(language, keys)
    return setmetatable({}, {
        __index = function(_, key)
            local id = keys[key]
            return id and language[id] or nil
        end,
        __pairs = function()
            local key
            return function()
                key = next(keys, key)
                if key ~= nil then return key, language[keys[key]] end
            end
        end,
        __newindex = function() error('Localized label maps are read-only', 2) end,
        __metatable = false,
    })
end
return Proxy
