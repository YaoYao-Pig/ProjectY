-- 表现配置出桥时复制成实体表；视觉时钟由显示层持有，不反写玩法存档。
local Presentation={}
local function copy(row)
    local result={}
    for key,value in pairs(row) do
        if type(value)=='table' then local values={};for i,v in ipairs(value) do values[i]=v end;result[key]=values
        else result[key]=value end
    end
    return result
end
function Presentation.Snapshot(config)
    local row=config:GetTable('MapEnvironmentTable'):Get(1)
    local result={profile=copy(row),keys={},weather={}}
    local previous=-1
    for i,id in ipairs(row.keyIds) do
        local key=config:GetTable('MapLightKeyTable'):Get(id)
        assert(key.hour>previous and key.hour<24,'Light keys must be ordered within a day');previous=key.hour
        result.keys[i]=copy(key)
    end
    assert(#result.keys>=2 and row.cycleSeconds>0,'Visual clock needs a positive duration and multiple keys')
    local found=false
    for i,id in ipairs(row.weatherIds) do
        local weather=config:GetTable('MapWeatherTable'):Get(id)
        assert(weather.fogEnd>weather.fogStart,'Fog end must follow start')
        result.weather[i]=copy(weather);if id==row.defaultWeatherId then found=true end
    end
    assert(found,'Default weather must be allowed')
    return result
end
return Presentation
