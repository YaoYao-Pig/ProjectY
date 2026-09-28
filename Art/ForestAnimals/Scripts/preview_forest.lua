local config=require('Config.ConfigSystem')()
config:OnInit({services=Services})
local generator=require('Game.MapArea.MapAreaGenerator')(config)
generator:Register(3,require('Game.MapArea.ForestGenerator'),'MapAreaForestTable','MapAreaForestThemeTable')
local area=generator:Generate(20,20260928,100005,{regionId=5,regionType=5,regionConfigId=5,q=0,r=0,height=0,biomeWeights={{regionType=5,weight=1}}})
local reader={config=config,ActiveLayout=function()return area end}
return require('Game.MapArea.MapAreaSystem').LayoutSnapshot(reader)
