-- Real exported settings and public gameplay query boundary; no Editor or save changes.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local f=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=f:read('*a');f:close();return bytes
end}})
local snapshot=require('Game.Rendering.MapPresentation').Snapshot(config)
local rule=config:GetTable('MapWeatherSystemTable'):Get(1)
assert(#snapshot.weather==3 and snapshot.weather[3].rainIntensity>0)
assert(snapshot.weather[1].rainIntensity==0 and snapshot.weather[2].rainIntensity==0)
assert(snapshot.weatherSystem.maxRainParticles==rule.maxRainParticles)
snapshot.weatherSystem.maxRainParticles=0
assert(rule.maxRainParticles>0,'Presentation settings mutated authoritative config')
assert(config:GetTable('LuaTxt'):Get('EnvironmentWeatherAuto').txt~='')
assert(config:GetTable('LuaTxt'):Get('EnvironmentWeatherHint').txt~='')
local calls=0
CS={ProjectY={Data={WorldWeatherField=function(seed,size,period,windX,windZ)
    calls=calls+1
    assert(seed==4294967295 and size==4*rule.regionHexes and period==rule.evolutionMinutes)
    assert(windX==rule.windX and windZ==rule.windZ)
    return {Sample=function(_,x,z,minutes)return {x=x,z=z,minutes=minutes}end}
end}}}
local weather=require('Game.Adventure.Weather')
local adventure={config=config,data={Seed=4294967295},narrative={data={Minutes=5432.5}},map={hexRadius=4,
    GetCellWorldPosition=function(_,q,r)assert(q==2 and r==-3);return 12,8,-19 end}}
local field=weather.Bind(adventure)
assert(field==adventure.weatherField)
local point=weather.Query(adventure,51,-27)
assert(point.x==51 and point.z==-27 and point.minutes==5432.5)
local cell=weather.QueryCell(adventure,2,-3,9876)
assert(cell.x==12 and cell.z==-19 and cell.minutes==9876,'Query used height or region time instead of world XZ and absolute minutes')
assert(calls==1,'Queries must reuse a bound field')
adventure.narrative.data.Minutes=100000
assert(weather.Query(adventure,0,0).minutes==100000,'Time jumps did not reach weather')
assert(weather.Bind(adventure)~=field,'New world/restore must replace the previous field')
print('PASS weather configuration, localization, snapshot ownership, uint seed, world coordinates, persisted clock and field reuse')
