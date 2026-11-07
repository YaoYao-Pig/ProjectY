-- Production layouts and exported environment configuration; no expedition, save or gameplay mutation.
local config=require('Config.ConfigSystem')()
config:OnInit({services=Services})
local generator=require('Game.MapArea.MapAreaGenerator')(config)
generator:Register(1,require('Game.MapArea.DungeonGenerator'),'MapAreaDungeonTable')
generator:Register(2,require('Game.MapArea.TownGenerator'),'MapAreaTownTable','MapAreaTownThemeTable')
generator:Register(6,require('Game.MapArea.MineGenerator'),'MapAreaMineTable','MapAreaMineThemeTable')
local id=PreviewArea=='dungeon' and 1 or PreviewArea=='mine' and 50 or 3
local area=generator:Generate(id,20260925,11,{regionId=7,regionType=1,regionConfigId=1,q=0,r=0,height=1,biomeWeights={{regionType=1,weight=1}}})
local reader={config=config,appearance=require('Game.Adventure.PawnAppearance').New(config),ActiveLayout=function()return area end}
return require('Game.MapArea.MapAreaSystem').LayoutSnapshot(reader),require('Game.Rendering.MapPresentation').Snapshot(config)
