local Class = require('Core.Class')
local Registry = Class('SystemRegistry')
function Registry:ctor(services)
    self.services = services; self.definitions = {}; self.order = {}; self.instances = {}; self.state = 'new'
end
function Registry:Register(name, systemType, dependencies)
    assert(self.state == 'new', 'Register systems before startup')
    assert(not self.definitions[name], 'Duplicate system: ' .. name)
    self.definitions[name] = { type = systemType, dependencies = dependencies or {} }
    self.order[#self.order + 1] = name
    return self
end
function Registry:Get(name) return assert(self.instances[name], 'System unavailable: ' .. name) end
function Registry:Start()
    assert(self.state == 'new', 'Registry already started')
    local sorted, marks = {}, {}
    local function visit(name)
        assert(self.definitions[name], 'Missing system dependency: ' .. name)
        assert(marks[name] ~= 'visiting', 'Cyclic system dependency: ' .. name)
        if marks[name] == 'done' then return end
        marks[name] = 'visiting'
        for _, dependency in ipairs(self.definitions[name].dependencies) do visit(dependency) end
        marks[name] = 'done'; sorted[#sorted + 1] = name
    end
    for _, name in ipairs(self.order) do visit(name) end
    self.sorted = sorted; self.initialized = {}; self.state = 'starting'
    local context = { services = self.services, systems = self, log = function(err) self.services:LogError(err) end }
    local ok, err = xpcall(function()
        for _, name in ipairs(sorted) do
            local instance = self.definitions[name].type()
            self.instances[name] = instance
            self.initialized[#self.initialized + 1] = instance
            instance:OnInit(context)
        end
        for _, name in ipairs(sorted) do self.instances[name]:OnStart() end
    end, debug.traceback)
    if not ok then self:Shutdown(); error(err, 0) end
    self.state = 'running'
end
function Registry:Dispatch(method, ...)
    if self.state ~= 'running' then return end
    for _, name in ipairs(self.sorted) do
        local instance = self.instances[name]
        if instance.enabled then
            local ok, err = xpcall(instance[method], debug.traceback, instance, ...)
            if not ok then
                instance.enabled = false -- report once; dependencies stay alive for orderly cleanup
                self.services:LogError('Disabled system ' .. name .. ': ' .. err)
            end
        end
    end
end
function Registry:Shutdown()
    if self.state == 'stopped' then return end
    self.state = 'stopped'
    for i = #(self.initialized or {}), 1, -1 do
        local ok, err = xpcall(function() self.initialized[i]:OnShutdown() end, debug.traceback)
        if not ok then self.services:LogError(err) end
    end
    self.initialized = {}; self.instances = {}
end
return Registry
