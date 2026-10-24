local EmptyGrowth=assert(loadfile('Tools/Tests/growth_empty.lua'))()
local Gear=assert(loadfile('Tools/Tests/equipment_read_fixture.lua'))()
-- No Editor: real exported configuration and production inventory projections/command guards.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local gear=Gear(3,53,1);gear.Slot='leftRing'
local data={WearableCount=1,WeaponCount=0,MagazineCount=0,StackCount=0,
    GetWearableAt=function() return gear end,
    GetWearable=function()return gear end,Equipped=function()return nil end,Offhand=function()return nil end,Worn=function()return nil end,
    CanWear=function() return true end,
    Grid={Find=function() return nil end}}
local stats=require('Game.Battle.CombatStats')(config,data)
local actor={Id=1,Team=1,Growth=EmptyGrowth(),Effects={Count=0},TemplateId=1,TraitCount=0}
local other={Id=2,Team=1,Growth=EmptyGrowth(),Effects={Count=0},TemplateId=1,TraitCount=0}
local base=require('Game.Battle.CombatStats')(config)
assert(stats:Get(actor,'strength')==base:Get(actor,'strength')+2)
assert(stats:Get(other,'strength')==base:Get(other,'strength'))
print('PASS real wearable configuration applies attributes only to its owner')
local system={data=data,rules=stats.equipment,adventure={Phase='map'},Actor=function(_,id) return id==1 and actor or id==2 and other or nil end}
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
-- Cold menu startup must provide the same inventory definitions as new-game startup,
-- without granting starter items or requiring a party/world to exist first.
local shapes,pools={},{}
local grid={Width=0,Height=0,Count=0}
function grid:Configure(width,height) self.Width=width;self.Height=height end
function grid:Define(id,width,height) shapes[id]={width,height} end
local emptyInventory={Grid=grid}
CS.ProjectY.Data.EquipmentAffixData.Define=function(target,id,ids,weights)
    assert(target==emptyInventory);pools[id]={ids=ids,weights=weights}
end
CS.ProjectY.Data.LootSessionData=function()return {} end
local equipment=require('Game.Equipment.EquipmentSystem')()
equipment:OnInit({services={Adventure={Equipment=emptyInventory,PartyCount=0}},systems={Get=function(_,name)
    assert(name=='Config','Cold inventory initialization must not require a running world');return config
end}})
local recipe=config:GetTable('EquipmentDemoTable'):Get(1)
assert(grid.Width==recipe.bagWidth and grid.Height==recipe.bagHeight,'Cold startup leaves the backpack unconfigured for save preparation')
assert(grid.Count==0,'Cold startup must keep the backpack empty')
for _,item in ipairs(config:GetTable('EquipmentItemTable'):All()) do
    assert(shapes[item.id][1]==item.width and shapes[item.id][2]==item.height)
    if item.kind=='weapon' or item.kind=='wearable' then assert(pools[item.id]) end
end
print('PASS cold menu startup configures an empty backpack and all item definitions without starting a campaign')
for _,path in ipairs({'Lua/Game/Equipment/EquipmentSystem.lua','Lua/Game/Equipment/EquipmentRules.lua','Lua/Game/Equipment/InventoryModel.lua',
    'Lua/UI/Panel/InventoryCtr.lua','Lua/UI/EquipmentUIBridge.lua','Tools/Tests/inventory_integration.lua'}) do assert(loadfile(path)) end
print('PASS changed Lua modules parse')
