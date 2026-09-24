-- 仅验收城市规划与真实模型，不创建远征运行时或替代尚未编译的遭遇接口。
local config=require('Config.ConfigSystem')()
config:OnInit({services=Services})
local generator=require('Game.MapArea.MapAreaGenerator')(config)
generator:Register(2,require('Game.MapArea.TownGenerator'),'MapAreaTownTable','MapAreaTownThemeTable')
local definition=config:GetTable('MapAreaTable'):Get(6)
local seed=2667826519 -- 上次默认大地图王城入口产生的区域种子，便于比较相同城市。
local source={regionId=1,regionType=6,regionConfigId=6,q=0,r=0,height=1,biomeWeights={{regionType=6,weight=1}}}
local area=generator:Generate(6,((seed-definition.seedSalt) ~ 2654435761)&0xffffffff,1,source)
local reader={config=config,appearance=require('Game.Adventure.PawnAppearance').New(config),ActiveLayout=function()return area end}
local snapshot=require('Game.MapArea.MapAreaSystem').LayoutSnapshot(reader)
return snapshot
