local Reader = require('Config.BinaryReader')
local Formula = require('Config.Formula')
local ConfigTable = {}
local function readonly(value)
    return setmetatable({}, {
        __index = value, __newindex = function() error('Configuration is read-only', 2) end,
        __pairs = function() return next, value, nil end, __len = function() return #value end, __metatable = false,
    })
end
function ConfigTable.Load(schema, bytes)
    local reader = Reader(bytes)
    assert(reader:Read(4) == 'YCFG', 'Invalid config magic: ' .. schema.name)
    assert(reader:U16() == 1, 'Unsupported config binary version')
    assert(reader:String() == schema.fingerprint, 'Config schema mismatch: re-export ' .. schema.name)
    local count = reader:U32(); assert(count <= 100000, 'Config row limit exceeded')
    local function read(field, kind)
        kind = kind or field.type
        if kind:sub(-2) == '[]' then
            local length = reader:U32(); assert(length <= 65535, 'Config array limit exceeded')
            local items = {}; for i = 1, length do items[i] = read(field, kind:sub(1, -3)) end
            return readonly(items)
        end
        if kind == 'int' then return reader:Int() end
        if kind == 'float' then return reader:Float() end
        if kind == 'bool' then local byte = reader:U8(); assert(byte <= 1, 'Invalid config boolean'); return byte == 1 end
        if kind == 'enum' and field.enumType == 'int' then return reader:Int() end
        -- text retains its default language value until the i18n export stage is introduced.
        if kind == 'string' or kind == 'text' or kind == 'enum' then return reader:String() end
        if kind == 'formula' then return Formula.Read(reader, field.variables) end
        error('Unsupported config type: ' .. tostring(kind))
    end
    local rows, byId = {}, {}
    for i = 1, count do
        local row = {}
        for _, field in ipairs(schema.fields) do row[field.name] = read(field) end
        local id = assert(row[schema.key], 'Missing primary key')
        assert(not byId[id], 'Duplicate config key')
        row = readonly(row); rows[i] = row; byId[id] = row
    end
    reader:Finish()
    local all = readonly(rows)
    return readonly({
        Count = count,
        Get = function(_, id) return assert(byId[id], schema.name .. ': missing row ' .. tostring(id)) end,
        Find = function(_, id) return byId[id] end,
        All = function() return all end,
    })
end
return ConfigTable
