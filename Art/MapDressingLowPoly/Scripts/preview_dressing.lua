-- 原生 Lua 生成器与实际快照入口；仅构造静态布局，不创建游戏会话或修改探索数据。
local config=require('Config.ConfigSystem')()
config:OnInit({services=Services})
local generator=require('Game.MapArea.MapAreaGenerator')(config)
generator:Register(1,require('Game.MapArea.DungeonGenerator'),'MapAreaDungeonTable')
generator:Register(2,require('Game.MapArea.TownGenerator'),'MapAreaTownTable','MapAreaTownThemeTable')
local kind=PreviewRegion
local area=generator:Generate(PreviewArea,20260925,11,{regionId=7,regionType=kind,regionConfigId=kind,q=0,r=0,height=1,biomeWeights={{regionType=kind,weight=1}}})
local reader={config=config,appearance=require('Game.Adventure.PawnAppearance').New(config),ActiveLayout=function()return area end}
return require('Game.MapArea.MapAreaSystem').LayoutSnapshot(reader)
