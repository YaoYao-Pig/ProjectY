-- Detached real equipment fixture for export and wearable acceptance; no live game mutation.
local registry=require('Core.SystemRegistry')(Services)
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('Battle',require('Game.Battle.BattleSystem'),{'Config'})
registry:Register('Equipment',require('Game.Equipment.EquipmentSystem'),{'Config'})
registry:Start()
local data=Services.Adventure;data:Reset(412)
local actor=data:AddPartyActor(1,1);local equipment=registry:Get('Equipment');equipment:Start()
actor:SetMaxHP(registry:Get('Battle').stats:MaximumHP(actor));actor:Restore()
local appearances=require('Game.Adventure.PawnAppearance').New(registry:Get('Config'))
local snapshot=require('Game.Battle.CombatSnapshot')
function CharacterEquipmentSnapshot() return snapshot(actor,registry:Get('Battle').stats,appearances) end
function CharacterLegacyAppearance(unitId) return appearances:Template(unitId,nil,actor.CustomizationJson) end
function CharacterEquipmentLoadout(index,wear)
    assert(equipment:Command('unequip_offhand',1,0,0,0));assert(data.Equipment:Wear(1,'offhand',0));assert(equipment:Command('unequip',1,0,0,0))
    if index>=0 then assert(equipment:Command('equip',1,data.Equipment:GetWeaponAt(math.min(index,7)).Id,0,0)) end
    if index==8 or index==9 then
        assert(equipment:Command('equip',1,data.Equipment:GetWeaponAt(2).Id,0,0))
        if index==8 then assert(equipment:Command('equip_offhand',1,data.Equipment:GetWeaponAt(3).Id,0,0)) end
    end
    if index==10 then assert(equipment:Command('equip',1,data.Equipment:GetWeaponAt(8).Id,0,0)) end
    for i=0,data.Equipment.WearableCount-1 do
        local row=data.Equipment:GetWearableAt(i)
        local slot=({[51]='head',[52]='body',[53]='rightRing',[54]='leftRing',[55]='legs',[56]='feet',[57]='offhand'})[row.ItemId]
        local enabled=slot=='offhand' and index==9 or slot~='offhand' and wear
        assert(data.Equipment:Wear(1,slot,enabled and row.Id or 0))
    end
    local main=data.Equipment:Equipped(1)
    if main and main.ItemId==2 and main.MagazineId==0 then assert(equipment:Command('attach',1,main.Id,3,data.Equipment:GetMagazineAt(0).Id)) end
    if main then
        local sockets=equipment.rules.weapons:Get(main.ItemId).socketIds
        for _,socketId in ipairs(sockets) do
            local socket=equipment.rules.sockets:Get(socketId)
            local part=({head=11,shaft=12,thruster=13})[socket.kind]
            if part and main:GetRune(socketId)==0 then
                if data.Equipment:CountItem(part)==0 then assert(equipment:Grant(part,1)) end
                assert(equipment:Command('attach',1,main.Id,socketId,part))
            end
        end
    end
    actor:SetMaxHP(registry:Get('Battle').stats:MaximumHP(actor));actor:Restore()
    return CharacterEquipmentSnapshot()
end
function CharacterEquipmentGripIds()
    local main=equipment.rules:Weapon(actor);local off=equipment.rules:Offhand(actor)
    return main and main.ItemId or 0,main and equipment.rules.weapons:Get(main.ItemId).gripId or 0,
        off and off.ItemId or 0,off and equipment.rules.weapons:Get(off.ItemId).gripId or 0
end
function CloseCharacterEquipmentFixture() registry:Shutdown() end
return actor
