return function(name, base)
    local cls = { __name = name, super = base }
    cls.__index = cls
    setmetatable(cls, { __index = base, __call = function(c, ...)
        local instance = setmetatable({}, c)
        if instance.ctor then instance:ctor(...) end
        return instance
    end })
    return cls
end
