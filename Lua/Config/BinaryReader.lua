local Class = require('Core.Class')
local Reader = Class('BinaryReader')
function Reader:ctor(bytes)
    assert(type(bytes) == 'string', 'Config loader must return a Lua binary string')
    self.bytes = bytes; self.position = 1
end
function Reader:Read(count)
    assert(count >= 0 and self.position + count - 1 <= #self.bytes, 'Truncated config binary')
    local value = self.bytes:sub(self.position, self.position + count - 1)
    self.position = self.position + count
    return value
end
function Reader:Number(format, length)
    local value = string.unpack('<' .. format, self:Read(length))
    assert(value == value and value ~= math.huge and value ~= -math.huge, 'Non-finite config number')
    return value
end
function Reader:U8() return self:Number('I1', 1) end
function Reader:U16() return self:Number('I2', 2) end
function Reader:U32() return self:Number('I4', 4) end
function Reader:Int() return self:Number('i4', 4) end
function Reader:Float() return self:Number('d', 8) end
function Reader:String()
    local length = self:U32()
    assert(length <= 1048576, 'Config string exceeds 1 MiB')
    return self:Read(length)
end
function Reader:Finish() assert(self.position == #self.bytes + 1, 'Unexpected trailing config bytes') end
return Reader
