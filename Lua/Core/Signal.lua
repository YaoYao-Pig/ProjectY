local Class = require('Core.Class')
local Signal = Class('Signal')
function Signal:ctor(log) self.listeners = {}; self.log = log or print end
function Signal:Subscribe(callback)
    local entry = { callback = callback, active = true }
    self.listeners[#self.listeners + 1] = entry
    return function()
        if not entry.active then return end
        entry.active = false
        for i, value in ipairs(self.listeners) do
            if value == entry then table.remove(self.listeners, i); break end
        end
    end
end
function Signal:Emit(...)
    local snapshot = {}
    for i, listener in ipairs(self.listeners) do snapshot[i] = listener end
    for _, listener in ipairs(snapshot) do
        if listener.active then
            local ok, err = xpcall(listener.callback, debug.traceback, ...)
            if not ok then self.log(err) end
        end
    end
end
function Signal:Clear()
    for _, listener in ipairs(self.listeners) do listener.active = false end
    self.listeners = {}
end
return Signal
