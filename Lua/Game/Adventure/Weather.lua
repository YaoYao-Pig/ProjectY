-- One immutable weather field is shared by gameplay queries and the visible renderer.
-- Coordinates are world-map X/Z units; time is the persisted absolute game minute.
local Weather={}
function Weather.Bind(adventure)
    local map=assert(adventure.map,'Weather requires an active world map')
    local rule=adventure.config:GetTable('MapWeatherSystemTable'):Get(1)
    adventure.weatherField=CS.ProjectY.Data.WorldWeatherField(adventure.data.Seed,
        map.hexRadius*rule.regionHexes,rule.evolutionMinutes,rule.windX,rule.windZ)
    return adventure.weatherField
end
function Weather.Query(adventure,x,z,minutes)
    local field=assert(adventure.weatherField,'Weather field is not bound to a world')
    if minutes==nil then minutes=adventure.narrative.data.Minutes end
    return field:Sample(x,z,minutes)
end
function Weather.QueryCell(adventure,q,r,minutes)
    local x,_,z=assert(adventure.map,'Weather requires an active world map'):GetCellWorldPosition(q,r)
    return Weather.Query(adventure,x,z,minutes)
end
return Weather
