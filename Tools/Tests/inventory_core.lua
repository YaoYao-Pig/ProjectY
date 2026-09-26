-- No Editor: real exported configuration and production inventory projections/command guards.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local gear={Id=3,ItemId=53,OwnerActorId=1,Slot='leftRing'}
local data={WearableCount=1,WeaponCount=0,MagazineCount=0,StackCount=0,
    GetWearableAt=function() return gear end,
    CanWear=function() return true end,
    Grid={Find=function() return nil end}}
local stats=require('Game.Battle.CombatStats')(config,data)
local actor={Id=1,Team=1,TemplateId=1,TraitCount=0}
local other={Id=2,Team=1,TemplateId=1,TraitCount=0}
local base=require('Game.Battle.CombatStats')(config)
assert(stats:Get(actor,'strength')==base:Get(actor,'strength')+2)
assert(stats:Get(other,'strength')==base:Get(other,'strength'))
print('PASS real wearable configuration applies attributes only to its owner')
local system={data=data,rules=stats.equipment,adventure={Phase='map'},Actor=function(_,id) return id==1 and actor or nil end}
local model=require('Game.Equipment.InventoryModel').New(system,stats)
local rows=model:Rows(1)
assert(#rows==1 and rows[1].slot=='leftRing' and rows[1].compatible=='ring' and rows[1].equipMask==12)
assert(rows[1].x==-1 and rows[1].y==-1 and rows[1].rotated==false and type(rows[1].detail)=='string')
assert(#model:Rows(2)==0)
assert(not model:Command('equip:head',1,'g3',0,0,false))
assert(not model:Command('equip:missing',1,'g3',0,0,false))
assert(not model:Command('move',2,'g3',0,0,false))
system.adventure.Phase='battle';assert(not model:Command('unequip',1,'g3',0,0,false))
assert(gear.OwnerActorId==1 and gear.Slot=='leftRing')
print('PASS typed snapshots, independent ring slots and invalid-command guards')
for _,path in ipairs({'Lua/Game/Equipment/EquipmentSystem.lua','Lua/Game/Equipment/EquipmentRules.lua','Lua/Game/Equipment/InventoryModel.lua',
    'Lua/UI/Panel/InventoryCtr.lua','Lua/UI/EquipmentUIBridge.lua','Tools/Tests/inventory_integration.lua'}) do assert(loadfile(path)) end
print('PASS changed Lua modules parse')
