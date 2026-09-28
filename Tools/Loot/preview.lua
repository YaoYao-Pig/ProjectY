local registry=require('Core.SystemRegistry')(Services)
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('PlayerModel',require('Game.PlayerModelSystem'),{'Config'})
registry:Register('Map',require('Game.Map.MapSystem'),{'Config'})
registry:Register('MapArea',require('Game.MapArea.MapAreaSystem'),{'Config'})
registry:Register('Battle',require('Game.Battle.BattleSystem'),{'Config'})
registry:Register('Equipment',require('Game.Equipment.EquipmentSystem'),{'Config'})
registry:Register('Growth',require('Game.Progression.GrowthSystem'),{'Battle'})
registry:Register('AdventureEvents',require('Game.Adventure.EventSystem'),{'Battle','PlayerModel','Growth','Equipment'})
registry:Register('Adventure',require('Game.Adventure.AdventureSystem'),{'Map','MapArea','AdventureEvents','Equipment'})
registry:Start()
local adventure=registry:Get('Adventure');adventure:Start(412)
local site
for _,row in ipairs(adventure.sites) do
    if (LootPreviewArea==20 and row.areaConfigId==20) or (LootPreviewArea==30 and row.eventId==1) then site=row;break end
end
assert(site and adventure:Visit(site.id))
if LootPreviewArea==30 then
    assert(adventure:Choose(1))
    for _,actor in ipairs(adventure.battle:Units()) do if actor.Team==2 then actor:Damage(1000000) end end
    assert(adventure.battle:CheckWinner());adventure:SettleBattle()
end
local areas=adventure.areas;local layout=areas:ActiveLayout();local state=adventure.data.Areas.Active
local known={};for i=1,#layout.cells do known[i]=i end;state:Reveal(known)
local result=adventure:Snapshot();result.error=''
local shape=areas:LayoutSnapshot()
registry:Shutdown()
return shape,result
