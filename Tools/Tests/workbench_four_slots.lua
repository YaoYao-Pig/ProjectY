-- Actual workbench controller and weapon visual projection with isolated native-view adapters.
package.path='Lua/?.lua;'..package.path
local Controller=require('UI.Panel.EquipmentWorkbenchCtr')
local EquipmentRules=require('Game.Equipment.EquipmentRules')
local actor={Id=1}
local items,sockets,definitions,weapons={},{},{},{}
for index,count in ipairs({4,2,3,0})do
    local itemId=1000+index;items[itemId]={id=itemId,name='Weapon '..index,kind='weapon',iconPath='',assetId=itemId}
    local ids={}
    for slot=1,count do
        local id=index*100+slot;ids[slot]=id
        sockets[id]={id=id,name='Slot '..slot,kind=slot==4 and 'edge' or 'rail',calloutSide=slot%2==0 and 'right' or 'left',
            position={slot*.1,0,0},rotation={0,0,0}}
    end
    definitions[itemId]={id=itemId,socketIds=ids,categoryId=1,level=1,kind='melee',previewRotation={0,0,0},previewZoom=1}
    local weapon={Id=index,ItemId=itemId,OwnerActorId=0,MagazineId=0,runes={}}
    function weapon:GetRune(id)return self.runes[id] or 0 end
    weapons[index]=weapon
end
items[501]={id=501,name='Fourth-slot attachment',kind='module',iconPath='',assetId=1501}
local data={WeaponCount=#weapons,MagazineCount=0,StackCount=1}
function data:GetWeapon(id)return assert(weapons[id])end
function data:GetWeaponAt(index)return assert(weapons[index+1])end
function data:GetStackAt(index)assert(index==0);return {ItemId=501,Count=1}end
function data:CountItem(id)return id==501 and 1 or 0 end
function data:Equipped()end
local categories={{id=1,name='Test weapons'}}
local rules={items={Get=function(_,id)return assert(items[id])end},weapons={Get=function(_,id)return assert(definitions[id])end},
    sockets={Get=function(_,id)return assert(sockets[id])end},categories={Get=function()return categories[1]end,All=function()return categories end},
    assets={Get=function(_,id)return {prefabPath='test/'..id}end},
    motion={Grip=function()return {mainPosition={0,0,0},mainRotation={0,0,0},offPosition={0,0,0},offRotation={0,0,0}}end},
    runes={All=function()return {{id=501,slotKind='edge'}}end,Get=function()return {description='Fourth-slot effect'}end},
    WeaponTags=function()return {}end,CanEquip=function()return true end,Loaded=function()end,
    ItemRequirements=function()return {entries={},met=true}end,Requirements=function()return {met=true}end,
    PreviewWeapon=function()return {SkillIds=function()return {}end}end,
    Asset=EquipmentRules.Asset,WeaponVisual=EquipmentRules.WeaponVisual}
rules.visualEffectConfig={GetTable=function(_,name)
    if name=='EquipmentItemTable' then return rules.items end
    if name=='VisualEffectTable' then return {Get=function(_,id)assert(id==0);return {id=0}end}end
    if name=='VisualEffectItemCategoryTable' then return {Get=function()return {visualEffectId=0}end}end
    error('Unexpected visual-effect table: '..name)
end}
for _,item in pairs(items)do item.visualEffectId=0 end
local calls={}
local system={data=data,rules=rules,adventure={PartyCount=1,GetPartyAt=function()return actor end},
    Actor=function()return actor end,HandAllowed=function()return true end,IsCarriedWeapon=function()return true end}
function system:Command(command,actorId,weaponId,socketId,value)
    calls[#calls+1]={command=command,actorId=actorId,weaponId=weaponId,socketId=socketId,value=value}
    assert(command=='attach' and actorId==1 and weaponId==1 and socketId==104)
    weapons[weaponId].runes[socketId]=value~=0 and value or nil
    return true
end
local prepared,shown,snapshots=0,nil,0
local function node()
    local value={text='',interactable=true}
    value.gameObject={activeSelf=true,SetActive=function(self,active)self.activeSelf=active end}
    return value
end
local view={Workbench={Prepare=function()prepared=prepared+1 end,ShowWeapon=function(_,snapshot)shown=snapshot end},InventorySlots={},OptionSlots={}}
for _,key in ipairs({'CategoryPrevious','CategoryNext','Close','Title','Subtitle','EquipText','Equip','Unequip','Status','CategoryText',
    'Requirements','SocketTitle','Remove','Fill','Stats','TagSlots'})do view[key]=node()end
for i=1,4 do view['Actor'..i]=node();view['ActorText'..i]=node();view['Socket'..i]=node();view['SocketText'..i]=node()end
local stats={Template=function()return {name='Actor'}end}
local listeners,inventoryRows,inventoryChoose,optionRows,optionChoose={}
local controller=setmetatable({view=view,context={systems={Get=function(_,name)
    if name=='Equipment' then return system elseif name=='Battle' then return {stats=stats} end
    error('Unexpected test system: '..name)
end}}},{__index=Controller})
function controller:Listen(button,callback)assert(not listeners[button],'Duplicate click listener');listeners[button]=callback end
function controller:Rows(pool,_,rows,callback)
    if pool==self.inventory then inventoryRows=rows;inventoryChoose=callback
    elseif pool==self.options then optionRows=rows;optionChoose=callback else error('Unexpected row pool')end
end
local demo={SetEquipmentOpen=function()end,SendCommand=function(_,command)assert(command=='snapshot');snapshots=snapshots+1 end}
local presentation=require('Game.Equipment.EquipmentPresentation');local originals={}
for _,name in ipairs({'Name','Attributes','Affix','Condition'})do originals[name]=presentation[name];presentation[name]=function()return 'Equipment'end end
controller:Bind();controller:OnShow({demo=demo})
assert(prepared==2 and #shown.sockets==4 and shown.sockets[4].id==104)
for i=1,4 do assert(listeners[view['Socket'..i]] and view['Socket'..i].gameObject.activeSelf)end
listeners[view.Socket4]()
assert(controller.socketId==104 and view.SocketText4.text:find('● ',1,true)==1)
assert(#optionRows==1 and optionRows[1].value==501 and not optionRows[1].selected)
optionChoose(optionRows[1])
assert(#calls==1 and calls[1].socketId==104 and calls[1].value==501 and snapshots==1)
assert(shown.sockets[4].asset.id==1501 and optionRows[1].selected and view.Remove.interactable,'Fourth-slot assembly snapshot did not refresh')
listeners[view.Remove]()
assert(#calls==2 and calls[2].value==0 and shown.sockets[4].asset==nil and snapshots==2)
print('PASS actual fourth-slot click binding, selected label, attachment command and refreshed visual snapshot')
local function selectWeapon(id,expectedCount)
    local selected;for _,row in ipairs(inventoryRows)do if row.weaponId==id then selected=row end end
    inventoryChoose(assert(selected));assert(#shown.sockets==expectedCount and controller.weaponId==id)
    for i=1,4 do
        assert(view['Socket'..i].gameObject.activeSelf==(i<=expectedCount))
        assert(view['Socket'..i].interactable==(i<=expectedCount))
        if i>expectedCount then assert(view['SocketText'..i].text=='','Hidden socket kept stale label')end
    end
    assert(controller.socketId==(expectedCount>0 and id*100+1 or 0))
end
selectWeapon(2,2);selectWeapon(3,3);selectWeapon(4,0)
assert(#optionRows==0 and not view.Remove.interactable and view.SocketTitle.text=='此武器没有改装槽')
selectWeapon(1,4);listeners[view.Socket4]();assert(controller.socketId==104 and #optionRows==1)
for name,original in pairs(originals)do presentation[name]=original end
print('PASS four-to-two-to-three-to-zero-to-four transitions clear stale labels/options and restore fourth-slot selection')
