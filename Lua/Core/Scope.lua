-- Owns event subscriptions and other teardown callbacks. Idempotent; LIFO cleanup.
local Class = require('Core.Class')
local Scope = Class('Scope')
function Scope:ctor(log) self.cleanups = {}; self.log = log or print; self.closed = false end
function Scope:Add(cleanup)
    assert(not self.closed, 'Cannot add a resource to a closed scope')
    self.cleanups[#self.cleanups + 1] = cleanup
    return cleanup
end
function Scope:Dispose()
    if self.closed then return end
    self.closed = true
    for i = #self.cleanups, 1, -1 do
        local ok, err = xpcall(self.cleanups[i], debug.traceback)
        if not ok then self.log(err) end
    end
    self.cleanups = {}
end
return Scope
