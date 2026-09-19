local Class = require('Core.Class')
local System = require('Core.LuaSystem')
local Table = require('Config.ConfigTable')
local Config = Class('ConfigSystem', System)
function Config:OnInit(context)
    System.OnInit(self, context); self.tables = {}; self.manifest = {}
    for _, name in ipairs(require('Generated.Manifest')) do self.manifest[name] = true end
end
function Config:GetTable(name)
    assert(self.manifest[name], 'Unknown config table: ' .. tostring(name))
    if not self.tables[name] then
        self.tables[name] = Table.Load(require('Generated.' .. name), self.context.services:ReadConfig(name))
    end
    return self.tables[name]
end
function Config:HasTable(name) return self.manifest[name] == true end
function Config:GetConstant(module, name)
    local values = assert(require('Config.Catalog').Constants[module], 'Unknown constant module: ' .. module)
    local value = values[name]
    assert(value ~= nil, 'Unknown constant: ' .. module .. '.' .. name)
    return value
end
function Config:GetEnum(module, name)
    local values = assert(require('Config.Catalog').Enums[module], 'Unknown enum module: ' .. module)
    return assert(values[name], 'Unknown enum: ' .. module .. '.' .. name)
end
function Config:OnShutdown() self.tables = {}; self.manifest = {} end
return Config
