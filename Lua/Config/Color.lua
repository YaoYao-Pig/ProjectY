local Color={}
function Color.Normalize(value)
    assert(type(value)=='string','Color must be a hex string')
    local hex=value:gsub('^#',''):upper();local length=#hex
    assert((length==3 or length==4 or length==6 or length==8) and hex:match('^%x+$'),'Invalid color: '..value)
    if length<5 then hex=hex:gsub('.',function(c)return c..c end) end
    return '#'..hex
end
return Color
