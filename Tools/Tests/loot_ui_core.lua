package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local bytes=file:read('*a');file:close();return bytes
end}})
local entries={
    {Key='loot:1:0',ItemId=40,ContainerId=1,Count=1,Revealed=false},
    {Key='loot:1:1',ItemId=31,ContainerId=1,Count=7,Revealed=false}}
local session={Count=2,SelectedContainerId=0,GetAt=function(_,i) return entries[i+1] end,Area={GetLootAt=function() return {Name='测试宝箱'} end}}
local model=require('Game.Loot.LootModel').New({session=session,equipment={rules={items=config:GetTable('EquipmentItemTable')}}})
local rows,width,height=model:Rows()
assert(width==6 and height>=6 and #rows==2)
for _,row in ipairs(rows) do assert(row.displayWidth==row.width and row.displayHeight==row.height) end
assert(rows[1].name=='未搜索的物品' and not rows[1].detail:find('测试宝箱',1,true))
assert(model:Searching()==entries[1] and rows[1].rotated==false and rows[1].equipMask==0)
entries[1].Revealed=true;rows=model:Rows()
assert(rows[1].name==config:GetTable('EquipmentItemTable'):Get(40).name and model:Searching()==entries[2])
local x,y=rows[2].x,rows[2].y;entries[1].Count=0;rows=model:Rows()
assert(rows[2].x==x and rows[2].y==y,'Taking another item must not move the current search/drag target')
entries[2].Revealed=true;assert(model:Searching()==nil)
session.SelectedContainerId=1
session.Grid={Width=6,Height=6,Find=function(_,key) assert(key==entries[2].Key);return {X=4,Y=3,Rotated=true} end}
local stored=model:Rows();assert(stored[2].x==4 and stored[2].y==3 and stored[2].rotated,'Container projection must use persistent placement data')
session.SelectedContainerId=0
session.Count=0;local empty,emptyWidth,emptyHeight=model:Rows()
assert(#empty==0 and emptyWidth==6 and emptyHeight>=6,'Empty containers still need a complete visible grid')
for _,path in ipairs({'Lua/Game/Loot/MapLoot.lua','Lua/Game/Loot/LootModel.lua','Lua/Game/Adventure/AdventureSystem.lua',
    'Lua/UI/Panel/LootCtr.lua','Lua/UI/AdventureUIBridge.lua','Lua/UI/EquipmentUIBridge.lua',
    'Tools/Tests/loot_integration.lua','Tools/Tests/loot_helpers.lua','Tools/Tests/equipment_integration.lua',
    'Tools/Tests/inventory_integration.lua','Tools/Tests/exploration_story_integration.lua'}) do assert(loadfile(path)) end
print('PASS hidden item details, search order, stable drop positions, typed snapshots and changed Lua syntax')
