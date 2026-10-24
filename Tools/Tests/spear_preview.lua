-- Fresh native services only. No live campaign or save file is touched.
local registry=require('Core.SystemRegistry')(Services)
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('MapArea',require('Game.MapArea.MapAreaSystem'),{'Config'})
registry:Register('Battle',require('Game.Battle.BattleSystem'),{'Config'})
registry:Register('Equipment',require('Game.Equipment.EquipmentSystem'),{'Config'})
registry:Start()
local data=Services.Adventure;data:Reset(412)
local actor=data:AddPartyActor(1,1);actor:SetMaxHP(46);actor:Restore()
local equipment=registry:Get('Equipment')
-- Define state through the actual new-game path, then grant the requested weapon.
equipment:Start()
assert(equipment:Grant(742,1))
local weapon=equipment.data:GetWeaponAt(equipment.data.WeaponCount-1)
assert(equipment:Command('equip',1,weapon.Id,0,0))
local appearances=require('Game.Adventure.PawnAppearance').New(registry:Get('Config'))
local snapshot=require('Game.Battle.CombatSnapshot')
function SpearPreviewSnapshot() return snapshot(actor,registry:Get('Battle').stats,appearances) end
function CloseSpearPreview() registry:Shutdown() end
return SpearPreviewSnapshot()
