-- Real C# actors, equipment, body HP and damage effects in an isolated FrameworkServices host.
local registry=require('Core.SystemRegistry')(Services)
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('Battle',require('Game.Battle.BattleSystem'),{'Config'})
registry:Register('Equipment',require('Game.Equipment.EquipmentSystem'),{'Config'})
local results={}
local ok,err=xpcall(function()
    registry:Start()
    local battle,equipment=registry:Get('Battle'),registry:Get('Equipment')
    local stats= battle.stats
    local native=CS.ProjectY.Data.EquipmentCombatState
    local body=CS.ProjectY.Data.BodyHealth
    local source=CS.ProjectY.Data.CombatActorData(801,1);source:Deploy(1,0,0)
    source:SetMaxHP(stats:MaximumHP(source));source:Restore()
    local area=CS.ProjectY.Data.MapAreaStateData(1,7,1)
    local areas={data={Active=area},ActiveLayout=function()return {Find=function()return {index=1}end}end}
    local effects=require('Game.Battle.GameEffects').New(stats,battle.effects,function()end,{roll=function()return 99 end,
        battle={DropInjuredEquipment=function(_,actor)equipment.worldLoot:DropInjuredHands(areas,actor,stats)end}})
    local skill={skillGroup='weapon',armorPenetration=100,armorDamageMultiplier=1,fleshDamageMultiplier=1,
        preserveArmor=false,targetBodyPartIndex=2}
    local target=CS.ProjectY.Data.CombatActorData(802,1);target:Deploy(2,1,0)
    native.Initialize(equipment.data,target.Id,40,0,{57},{'offhand'})
    target:SetMaxHP(stats:MaximumHP(target));target:Restore()
    local blade=equipment.data:Equipped(target.Id);local shield=equipment.data:Worn(target.Id,'offhand')
    local before=body.HP(target,2);local amount=math.ceil(before/2)
    effects:Execute(battle.effects:Get(1),target,amount,source.Id,'source','precision',source,true,{},false,skill)
    assert(body.HP(target,2)<before and stats.injuries:HandDisabled(target,2))
    assert(not equipment.data:Worn(target.Id,'offhand') and equipment.data:Equipped(target.Id).Id==blade.Id)
    assert(shield.OwnerActorId==0 and area.LootCount==1 and area:GetLootAt(0):GetItemIdAt(0)==shield.ItemId)
    assert(not equipment.rules:CanEquip(target,57,stats,'offhand') and equipment.rules:CanEquip(target,40,stats,'weapon'))
    local count=area.LootCount
    equipment.worldLoot:DropInjuredHands(areas,target,stats);assert(area.LootCount==count)
    results[#results+1]='PASS actual targeted damage disables left arm and drops the original shield once while main hand remains usable'

    target:Heal(target.MaxHP)
    assert(equipment.rules:CanEquip(target,57,stats,'offhand'),'Recovered body HP must allow re-equipping when trauma stayed below threshold')
    local two=CS.ProjectY.Data.CombatActorData(803,1);two:Deploy(2,1,0)
    native.Initialize(equipment.data,two.Id,42,0,{},{})
    two:SetMaxHP(stats:MaximumHP(two));two:Restore()
    local twoHand=equipment.data:Equipped(two.Id)
    effects:Execute(battle.effects:Get(1),two,math.ceil(body.HP(two,2)/2),source.Id,'source','precision',source,true,{},false,skill)
    assert(not equipment.data:Equipped(two.Id) and native.GroundWeapon(area:GetLootAt(area.LootCount-1)).Id==twoHand.Id)
    assert(not equipment.rules:CanEquip(two,42,stats,'weapon'))
    assert(equipment.rules.injuries:HandsAllowed(two,'weapon',1),'Left-arm injury must still allow single-handed recovery')
    results[#results+1]='PASS real two-handed weapon drops on either required arm, and normal healing restores hand availability'
end,debug.traceback)
registry:Shutdown()
if not ok then error(err)end
return table.concat(results,'\n')
