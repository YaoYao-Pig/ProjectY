-- Actual village and its live lighting configuration; no expedition, saves or gameplay clock.
local config=require('Config.ConfigSystem')()
config:OnInit({services=Services})
local generator=require('Game.MapArea.MapAreaGenerator')(config)
generator:Register(2,require('Game.MapArea.TownGenerator'),'MapAreaTownTable','MapAreaTownThemeTable')
local area=generator:Generate(3,20260925,11,{regionId=7,regionType=1,regionConfigId=1,q=0,r=0,height=1,biomeWeights={{regionType=1,weight=1}}})
local reader={config=config,appearance=require('Game.Adventure.PawnAppearance').New(config),ActiveLayout=function()return area end}
return require('Game.MapArea.MapAreaSystem').LayoutSnapshot(reader), require('Game.Rendering.MapPresentation').Snapshot(config)
