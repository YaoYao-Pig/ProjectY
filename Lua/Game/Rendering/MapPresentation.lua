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
    local weatherSystem=config:GetTable('MapWeatherSystemTable'):Get(1)
    assert(weatherSystem.regionHexes>0 and weatherSystem.evolutionMinutes>0,'Weather field needs positive spatial and temporal scales')
    assert(weatherSystem.maxRainParticles>=1 and weatherSystem.maxRainParticles<=8192 and
        weatherSystem.maxSplashParticles>=0 and weatherSystem.maxSplashParticles<=1024 and
        weatherSystem.maxClouds>=1 and weatherSystem.maxClouds<=512,'Weather effect budgets are outside supported limits')
    assert(weatherSystem.rainRate>0 and weatherSystem.rainRate<=4096 and weatherSystem.refreshSeconds>=.05 and
        weatherSystem.refreshSeconds<=2 and weatherSystem.cloudSpacingHexes>0,'Weather refresh and emission settings are invalid')
    local torch=config:GetTable('TorchTable'):Get(1)
    assert(config:GetTable('EquipmentItemTable'):Get(torch.itemId).kind=='material','Torch needs a portable inventory stack')
    assert(torch.range>0 and torch.intensity>0 and torch.height>0,'Torch light needs positive range, intensity and height')
    local result={profile=copy(row),torch=copy(torch),weatherSystem=copy(weatherSystem),keys={},weather={}}
    local previous=-1
    for i,id in ipairs(row.keyIds) do
        local key=config:GetTable('MapLightKeyTable'):Get(id)
        assert(key.hour>previous and key.hour<24,'Light keys must be ordered within a day');previous=key.hour
        result.keys[i]=copy(key)
    end
    assert(#result.keys>=2 and row.cycleSeconds>0,'Visual clock needs a positive duration and multiple keys')
    local found=false;local weatherIds={}
    for i,id in ipairs(row.weatherIds) do
        local weather=config:GetTable('MapWeatherTable'):Get(id)
        assert(weather.fogEnd>weather.fogStart,'Fog end must follow start')
        assert(weather.cloudCoverage>=0 and weather.cloudCoverage<=1 and weather.rainIntensity>=0 and weather.rainIntensity<=1,
            'Weather cloud coverage and rain intensity must be within zero and one')
        assert(not weatherIds[id],'Duplicate weather presentation');weatherIds[id]=true
        result.weather[i]=copy(weather);if id==row.defaultWeatherId then found=true end
    end
    assert(found,'Default weather must be allowed')
    assert(weatherIds[1] and weatherIds[2] and weatherIds[3],'Weather requires clear, overcast and rain presentation rows')
    return result
end
return Presentation
