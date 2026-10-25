-- Actual production generators and render snapshots, without changing a live expedition.
package.path='Lua/?.lua;'..package.path
local registry=require('Core.SystemRegistry')({ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end,LogError=error})
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('Map',require('Game.Map.MapSystem'),{'Config'});registry:Start()
local config=registry:Get('Config')
local map=registry:Get('Map'):Generate(42,{1,12,13,5,1,5},6000)
local result={world=require('Game.Map.MapRenderSnapshot')(map),areas={}}
local generator=require('Game.MapArea.MapAreaGenerator')(config)
for _,entry in ipairs({{70,9,'HighMountain',12},{71,10,'Canyon',13},{72,11,'GiantTree',5}}) do
    generator:Register(entry[2],require('Game.MapArea.'..entry[3]..'Generator'),'MapArea'..entry[3]..'Table','MapArea'..entry[3]..'ThemeTable')
    local area=generator:Generate(entry[1],42,300000+entry[1],{regionType=entry[4],biomeWeights={{regionType=entry[4],weight=1}}})
    local wrapper=setmetatable({config=config,ActiveLayout=function() return area end},{__index=require('Game.MapArea.MapAreaSystem')})
    result.areas[#result.areas+1]={name=entry[3],layout=wrapper:LayoutSnapshot(),entry=area.entryIndex,goal=area.goalIndex}
end
registry:Shutdown()
return result
