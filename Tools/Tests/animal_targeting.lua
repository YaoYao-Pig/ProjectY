local config=require('Config.ConfigSystem')()
config:OnInit({services=Services})
local generator=require('Game.MapArea.MapAreaGenerator')(config)
generator:Register(3,require('Game.MapArea.ForestGenerator'),'MapAreaForestTable','MapAreaForestThemeTable')
local area=generator:Generate(20,20260928,100005,{regionId=5,regionType=5,regionConfigId=5,q=0,r=0,height=0,biomeWeights={{regionType=5,weight=1}}})
local stats=require('Game.Battle.CombatStats')(config)
local appearance=require('Game.Adventure.PawnAppearance').New(config)
local center=area.cells[area.rooms[1].center];local actors={}
for i=1,3 do
    local actor=CS.ProjectY.Data.CombatActorData(100+i,200+i)
    actor:InitializeAnimal(i,1);actor:SetMaxHP(stats:MaximumHP(actor));actor:Restore()
    local cell=assert(area:Find(center.q+(i-2)*3,center.r))
    assert(not cell.blocked)
    actor:Deploy(0,cell.q,cell.r)
    actors[#actors+1]=require('Game.Battle.CombatSnapshot')(actor,stats,appearance,area)
end
return require('Game.MapArea.MapAreaSystem').LayoutSnapshot({config=config,ActiveLayout=function()return area end}),actors
