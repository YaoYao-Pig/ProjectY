local registry=require('Core.SystemRegistry')(Services)
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('Battle',require('Game.Battle.BattleSystem'),{'Config'})
registry:Register('Equipment',require('Game.Equipment.EquipmentSystem'),{'Config'})
registry:Register('UI',require('UI.UISystem'),{'Config'})
EquipmentPreviewRegistry=registry;registry:Start()
local data=Services.Adventure;data:Reset(123)
local battle,eq=registry:Get('Battle'),registry:Get('Equipment')
for i,id in ipairs({1,2,3,6}) do local a=data:AddPartyActor(i,id);a:SetMaxHP(battle.stats:MaximumHP(a));a:Restore() end
eq:Start();eq:Grant(11,1);eq:Grant(12,1)
local staff,gun=eq.data:GetWeaponAt(0),eq.data:GetWeaponAt(1)
assert(eq:Command('equip',3,staff.Id,0,0));assert(eq:Command('equip',2,gun.Id,0,0))
assert(eq:Command('attach',2,gun.Id,3,eq.data:GetMagazineAt(0).Id))
local adapter={};function adapter:SetEquipmentOpen(value) self.open=value end;function adapter:SendCommand(command) assert(command=='snapshot') end
EquipmentPreviewPanel=registry:Get('UI'):Open('EquipmentWorkbench',{demo=adapter})
EquipmentPreviewPanel.actorId=3;EquipmentPreviewPanel:Refresh()
function EquipmentPreviewModify()
    assert(eq:Command('attach',3,staff.Id,1,11));assert(eq:Command('attach',3,staff.Id,2,12));EquipmentPreviewPanel:Refresh()
end
function EquipmentPreviewGun()
    EquipmentPreviewPanel.actorId=2;EquipmentPreviewPanel.weaponId=gun.Id;EquipmentPreviewPanel.socketId=3;EquipmentPreviewPanel:Refresh()
end
function EquipmentPreviewAppearance(id)
    local actor=eq:Actor(id)
    return require('Game.Adventure.PawnAppearance').New(registry:Get('Config')):Template(actor.TemplateId,eq.rules:ActorVisual(actor))
end
function EquipmentPreviewMelee(itemId,boost,actorId)
    local weapon
    for i=0,eq.data.WeaponCount-1 do local w=eq.data:GetWeaponAt(i);if w.ItemId==itemId then weapon=w end end
    assert(weapon);local id=actorId or 4
    assert(eq:Command('equip',id,weapon.Id,0,0))
    local definition=eq.rules.weapons:Get(itemId)
    if boost then eq:Grant(13,1);assert(eq:Command('attach',id,weapon.Id,definition.socketIds[1],13)) end
    EquipmentPreviewPanel.actorId=id;EquipmentPreviewPanel.weaponId=weapon.Id;EquipmentPreviewPanel.socketId=0;EquipmentPreviewPanel.categoryIndex=definition.categoryId;EquipmentPreviewPanel:Refresh()
end
