package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local bytes=file:read('*a');file:close();return bytes
end}})
local Language=require('Language')
local items=config:GetTable('EquipmentItemTable')
local data={available=true,Revision=0,WeaponCount=0,WearableCount=0}
function data:CanGrant(ids,counts,kinds)
    assert(#ids==1 and #counts==1 and counts[1]==1 and kinds[1]==items:Get(ids[1]).kind)
    return self.available
end
function data:AddWeapon(id)assert(items:Get(id).kind=='weapon');self.WeaponCount=self.WeaponCount+1;self.Revision=self.Revision+1 end
function data:AddWearable(id)assert(items:Get(id).kind=='wearable');self.WearableCount=self.WearableCount+1;self.Revision=self.Revision+1 end
local facts={};local narrative={GetValue=function(_,key)return facts[key] or 0 end,SetValue=function(_,key,value)facts[key]=value end}
local equipment=setmetatable({data=data,rules={items=items},adventure={Narrative=narrative}},require('Game.Equipment.EquipmentSystem'))
equipment.acquisition=setmetatable({equipment=equipment,definitions=config:GetTable('LegendaryEquipmentTable')},require('Game.Equipment.LegendaryAcquisition'))
local adventure={equipment=equipment,map={}}
local gm=require('Game.GM.EquipmentCommands').New(adventure)
local tests=0;local function test(name,run)run();tests=tests+1;print('PASS '..name)end
local weapon,wearable,unsupported,legendary
for _,item in ipairs(items:All())do
    if item.kind=='weapon' and not equipment.acquisition.definitions:Find(item.id) then weapon=weapon or item end
    if item.kind=='wearable' and not equipment.acquisition.definitions:Find(item.id) then wearable=wearable or item end
    if item.kind~='weapon' and item.kind~='wearable' then unsupported=unsupported or item end
end
legendary=equipment.acquisition.definitions:All()[1]
assert(weapon and wearable and unsupported and legendary)
test('catalog lists every weapon and wearable in stable ID order without granting anything',function()
    local rows=gm:Search('');local seen={};local previous=0;local expected=0
    for _,item in ipairs(items:All())do if item.kind=='weapon' or item.kind=='wearable' then expected=expected+1 end end
    assert(#rows==expected)
    for _,row in ipairs(rows)do assert(row.id>previous and not seen[row.id]);seen[row.id]=true;previous=row.id end
    assert(seen[legendary.id] and not seen[unsupported.id] and data.Revision==0)
    local byName=gm:Search('  '..weapon.name..'  ');local found=false
    for _,row in ipairs(byName)do if row.id==weapon.id then found=true end end;assert(found)
    for _,row in ipairs(gm:Search(tostring(weapon.id)))do assert(tostring(row.id):find(tostring(weapon.id),1,true) or row.name:find(tostring(weapon.id),1,true))end
    assert(#gm:Search('no-such-equipment-123456')==0)
end)
test('bad IDs, unsupported item kinds and absent worlds reject before mutation',function()
    for _,id in ipairs({0,-1,1.5,'1',true,99999999,unsupported.id})do assert(not gm:Grant(id))end
    assert(not gm:Grant(nil) and data.Revision==0)
    adventure.map=nil;assert(not gm:Grant(weapon.id));adventure.map={};assert(data.Revision==0)
end)
test('weapon and wearable selections use the normal grant path and give exactly one item',function()
    assert(gm:Grant(weapon.id) and data.WeaponCount==1 and data.WearableCount==0)
    assert(gm:Grant(wearable.id) and data.WeaponCount==1 and data.WearableCount==1)
end)
test('full bags return the localized message without items, revisions or legendary issuance',function()
    data.available=false;local revision=data.Revision
    for _,id in ipairs({weapon.id,wearable.id,legendary.id})do
        local ok,reason=gm:Grant(id);assert(not ok and reason==Language.EquipmentGrantBagFull)
        assert(data.Revision==revision)
    end
    assert(not equipment.acquisition:Issued(legendary.id))
    data.available=true;assert(gm:Grant(weapon.id) and data.WeaponCount==2)
end)
test('legendary grants retain the existing world-uniqueness rule',function()
    assert(gm:Grant(legendary.id));local revision=data.Revision
    assert(equipment.acquisition:Issued(legendary.id))
    local ok,reason=gm:Grant(legendary.id)
    assert(not ok and reason==Language.LegendaryAlreadyIssued and data.Revision==revision)
end)
config:OnShutdown();print('GM equipment: '..tests..' checks passed')
