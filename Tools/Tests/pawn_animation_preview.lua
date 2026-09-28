-- Small Edit Mode fixture: real actor, equipment rules and detached production snapshot.
local registry=require('Core.SystemRegistry')(Services)
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('MapArea',require('Game.MapArea.MapAreaSystem'),{'Config'})
registry:Register('Battle',require('Game.Battle.BattleSystem'),{'Config'})
registry:Register('Equipment',require('Game.Equipment.EquipmentSystem'),{'Config'})
registry:Start()
local data=Services.Adventure;data:Reset(412)
local actor=data:AddPartyActor(1,1);actor:SetMaxHP(46);actor:Restore()
local equipment=registry:Get('Equipment');equipment:Start()
assert(equipment:Command('equip',1,equipment.data:GetWeaponAt(2).Id,0,0))
for i=0,equipment.data.WearableCount-1 do
    local worn=equipment.data:GetWearableAt(i)
    local slot=({[51]='head',[52]='body',[55]='legs',[56]='feet'})[worn.ItemId]
    if slot then assert(equipment.data:Wear(1,slot,worn.Id)) end
end
local appearances=require('Game.Adventure.PawnAppearance').New(registry:Get('Config'))
local snapshot=require('Game.Battle.CombatSnapshot')
function PawnAnimationSnapshot()
    return snapshot(actor,registry:Get('Battle').stats,appearances)
end
function PawnAnimationEquip(index)
    assert(equipment:Command('equip',1,equipment.data:GetWeaponAt(index).Id,0,0))
    return PawnAnimationSnapshot()
end
function ClosePawnAnimationFixture() registry:Shutdown() end
return actor,PawnAnimationSnapshot()
