package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name) local f=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local s=f:read('*a');f:close();return s end}})
local motion=require('Game.Equipment.EquipmentMotion').New(config)
local weapons=config:GetTable('EquipmentWeaponTable')
assert(motion:Resolve(nil,nil,nil).code=='unarmed')
assert(motion:Resolve(weapons:Get(40),nil,nil).code=='single')
assert(motion:Resolve(weapons:Get(40),nil,{}).code=='sword_shield')
assert(motion:Resolve(weapons:Get(40),weapons:Get(41),nil).code=='dual')
assert(motion:Resolve(weapons:Get(42),nil,nil).code=='two_hand')
assert(motion:Resolve(weapons:Get(44),nil,nil).code=='two_hand')
assert(motion:Resolve(weapons:Get(1),nil,nil).code=='staff')
assert(motion:Resolve(weapons:Get(2),nil,nil).code=='gun_rifle')
assert(motion:Resolve({kind='bow',hands=2,gunClass=''},nil,nil).code=='bow')
assert(motion:Resolve(nil,weapons:Get(40),nil).code=='single')
assert(not pcall(function() motion:Resolve(weapons:Get(42),nil,{}) end),'Invalid two-hand/shield loadout matched')
assert(not pcall(function() motion:Resolve({kind='gun',hands=2,gunClass='unknown'},nil,nil) end),'Unconfigured gun type silently fell back')
for _,weapon in ipairs(weapons:All()) do
    local grip=motion:Grip(weapon)
    for _,key in ipairs({'mainPosition','mainRotation','offPosition','offRotation'}) do assert(#grip[key]==3,'Grip is not a 3D vector') end
end
local rules=require('Game.Equipment.EquipmentRules').New(config)
local weapon={Id=1,ItemId=40,GetRune=function() return 0 end}
local view=rules:WeaponVisual(weapon)
assert(#view.primaryGrip.position==3 and #view.secondaryGrip.rotation==3)
local original=motion.adjustments
motion.adjustments={['40:1:main']={10,20,30},['40:4:main']={0,35,0},['40:4:off']={0,-40,0}}
assert(motion:RotationOffset(40,1,'main')[2]==20)
assert(motion:RotationOffset(40,4,'main')[2]==35)
assert(motion:RotationOffset(40,4,'off')[2]==-40)
assert(motion:RotationOffset(40,2,'main')[2]==0,'Sword-shield must inherit its own module, not single-hand adjustment')
assert(motion:RotationOffset(41,4,'main')[2]==0,'Other weapon models must remain independent')
rules.motion=motion
assert(rules:AssembleVisual(weapon,nil,{},nil).pose.weaponRotationOffset[2]==20)
local second={Id=2,ItemId=40,GetRune=function() return 0 end}
local dual=rules:AssembleVisual(weapon,second,{},nil)
assert(dual.pose.weaponRotationOffset[2]==35 and dual.pose.offWeaponRotationOffset[2]==-40)
motion.adjustments=original
local duplicate={id=1,weaponId=40,moduleId=1,hand='main',rotationOffset={0,0,0}}
local duplicateConfig={GetTable=function(_,name)
    if name=='EquipmentHoldAdjustmentTable' then return {All=function() return {duplicate,duplicate} end} end
    return config:GetTable(name)
end}
local ok,errorMessage=pcall(function() require('Game.Equipment.EquipmentMotion').New(duplicateConfig) end)
assert(not ok and errorMessage:find('Duplicate equipment hold adjustment',1,true),'Duplicate hold adjustment must fail at initialization')
print('PASS hold adjustments: weapon model / motion module / hand isolation, explicit zero inheritance and visual snapshots')
print('PASS equipment modules: two-hand loadout selection, configurable gun classes, per-weapon Vector3 grip markers, invalid combinations rejected')
