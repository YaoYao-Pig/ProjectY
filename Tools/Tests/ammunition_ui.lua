-- Real ammunition configuration and UI controllers with isolated native-view adapters.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local Language=require('Language')
local Text=require('Game.Equipment.EquipmentPresentation')
local Controller=require('UI.Panel.EquipmentWorkbenchCtr')
local ammunition=require('Game.Equipment.Ammunition').New(config)
local definitions=config:GetTable('EquipmentWeaponTable')
local gun=definitions:Get(2);local magDefinition=config:GetTable('EquipmentMagazineTable'):Get(gun.magazineItemId)
local profiles=ammunition:ForMagazine(magDefinition.id)
assert(#profiles==3)
local magazines={
    {Id=10,ItemId=magDefinition.id,AmmoItemId=profiles[1].id,Rounds=4,Capacity=magDefinition.capacity},
    {Id=11,ItemId=magDefinition.id,AmmoItemId=profiles[2].id,Rounds=magDefinition.capacity,Capacity=magDefinition.capacity}}
local weapon={Id=1,ItemId=gun.id,OwnerActorId=0,MagazineId=10,GetRune=function()return 0 end}
local actor={Id=1,Team=1,HP=40,MaxHP=40,AP=4,Guard=0,Moved=false,MainUsed=false}
local stock={[profiles[1].id]=20,[profiles[2].id]=20,[profiles[3].id]=0}
local data={WeaponCount=1,MagazineCount=2,StackCount=3,WearableCount=0}
function data:GetWeapon(id)assert(id==1);return weapon end
function data:GetWeaponAt(i)assert(i==0);return weapon end
function data:GetMagazine(id)for _,mag in ipairs(magazines)do if mag.Id==id then return mag end end;error('Unknown test magazine')end
function data:GetMagazineAt(i)return assert(magazines[i+1])end
function data:MagazineWeapon(id)return weapon.MagazineId==id and weapon.Id or 0 end
function data:GetStackAt(i)return {Id=100+i,ItemId=profiles[i+1].id,Count=stock[profiles[i+1].id]}end
function data:CountItem(id)return stock[id] or 0 end
function data:Equipped()end
local rules={items=config:GetTable('EquipmentItemTable'),weapons=definitions,sockets=config:GetTable('EquipmentSocketTable'),
    categories=config:GetTable('EquipmentCategoryTable'),runes=config:GetTable('EquipmentRuneTable'),ammunition=ammunition,
    WeaponTags=function()return {}end,CanEquip=function()return true end,
    Loaded=function()return weapon.MagazineId~=0 and data:GetMagazine(weapon.MagazineId) or nil end,
    ItemRequirements=function()return {entries={},met=true}end,Requirements=function()return {met=true}end,
    PreviewWeapon=function()return {SkillIds=function()return {}end}end,WeaponVisual=function()return {}end}
local stats={Template=function()return {name='Actor',actionPoints=4}end}
local calls,fail,snapshots={},false,0
local system={data=data,rules=rules,adventure={PartyCount=1,GetPartyAt=function()return actor end},
    Actor=function()return actor end,HandAllowed=function()return true end,IsCarriedWeapon=function()return true end,IsCarriedMagazine=function()return true end}
function system:Command(command,actorId,weaponId,socketId,value,ammoItemId)
    calls[#calls+1]={command=command,value=value,ammoItemId=ammoItemId}
    assert(actorId==1 and weaponId==1)
    if fail then return false,'No room for returned rounds' end
    if command=='fill' then
        local mag=data:GetMagazine(value)
        assert(ammunition:Compatible(mag.ItemId,ammoItemId))
        mag.AmmoItemId=ammoItemId;mag.Rounds=mag.Capacity
    elseif command=='attach' then weapon.MagazineId=value
    else error('Unexpected UI test command: '..command)end
    return true
end
local function node()
    return {text='',interactable=true,gameObject={activeSelf=true,SetActive=function(self,active)self.activeSelf=active end}}
end
local view={Workbench={Prepare=function()end,ShowWeapon=function()end},InventorySlots={},OptionSlots={}}
for _,key in ipairs({'CategoryPrevious','CategoryNext','Close','Title','Subtitle','EquipText','Equip','Unequip','Status','CategoryText',
    'Requirements','SocketTitle','Remove','Fill','Stats','TagSlots'})do view[key]=node()end
for i=1,4 do view['Actor'..i]=node();view['ActorText'..i]=node();view['Socket'..i]=node();view['SocketText'..i]=node()end
local listeners,inventoryRows,inventoryChoose,options,choose={}
local controller=setmetatable({view=view,context={systems={Get=function(_,name)
    if name=='Equipment' then return system elseif name=='Battle' then return {stats=stats}end
    error('Unexpected test system')
end}}},{__index=Controller})
function controller:Listen(button,callback)listeners[button]=callback end
function controller:Rows(pool,_,rows,callback)
    if pool==self.inventory then inventoryRows=rows;inventoryChoose=callback else options=rows;choose=callback end
end
local originals={}
for _,name in ipairs({'Name','Attributes','Affix','Condition'})do originals[name]=Text[name];Text[name]=function()return 'Equipment'end end
controller:Bind();controller:OnShow({demo={SetEquipmentOpen=function()end,SendCommand=function()snapshots=snapshots+1 end}})
assert(not view.Fill.interactable,'Filling requires an explicit magazine selection')
local function selectMagazine(id)
    for _,row in ipairs(inventoryRows)do if row.magazineId==id then inventoryChoose(row);return end end
    error('Missing magazine row')
end
local function selectAmmo(id)
    for _,row in ipairs(options)do if row.ammoItemId==id then choose(row);return end end
    error('Missing ammunition row')
end
selectMagazine(10)
assert(#calls==0 and #options==3 and controller.fillAmmoItemId==profiles[1].id and view.Fill.interactable)
assert(view.Stats.text:find(ammunition:Get(magazines[1].AmmoItemId).name,1,true))
selectAmmo(profiles[2].id)
assert(#calls==0 and magazines[1].AmmoItemId==profiles[1].id,'Selecting ammunition must not mutate the magazine')
fail=true;listeners[view.Fill]()
assert(#calls==1 and calls[1].value==10 and calls[1].ammoItemId==profiles[2].id and snapshots==0)
assert(controller.fillMagazineId==10 and controller.fillAmmoItemId==profiles[2].id and magazines[1].Rounds==4)
assert(view.Status.text=='No room for returned rounds' and view.Fill.interactable)
fail=false;listeners[view.Fill]()
assert(#calls==2 and magazines[1].AmmoItemId==profiles[2].id and magazines[1].Rounds==magazines[1].Capacity and snapshots==1)
assert(not view.Fill.interactable and controller.fillMagazineId==10)
selectMagazine(11);assert(not view.Fill.interactable)
selectAmmo(profiles[1].id);assert(view.Fill.interactable,'Full magazine can change ammunition type')
selectAmmo(profiles[3].id);assert(not view.Fill.interactable,'Unowned type remains inspectable but cannot be filled')
selectAmmo(profiles[1].id);listeners[view.Fill]()
assert(calls[#calls].value==11 and weapon.MagazineId==10,'Spare-magazine filling must not attach it')
local magazineSocket
for i,id in ipairs(gun.socketIds)do if rules.sockets:Get(id).kind=='magazine' then magazineSocket=i end end
listeners[view['Socket'..assert(magazineSocket)]]()
assert(controller.fillMagazineId==nil and not view.Fill.interactable and view.Remove.interactable)
for _,row in ipairs(options)do if row.value==11 then choose(row);break end end
assert(weapon.MagazineId==11 and controller.fillMagazineId==11 and #options==3,'Attaching a magazine should select it for ammunition inspection')
for name,original in pairs(originals)do Text[name]=original end
print('PASS loaded/spare selection, three types, explicit fill, full-magazine type switch, insufficient stock, failure retention and socket return')

-- Inventory and HUD project the actual loaded ammunition, never the magazine default.
CS=CS or {};CS.ProjectY=CS.ProjectY or {};CS.ProjectY.Data=CS.ProjectY.Data or {}
CS.ProjectY.Data.InventoryStacks={Key=function(stack)return 's'..stack.Id end}
CS.ProjectY.Data.BattleMovement={Remaining=function()return 0 end}
data.WeaponCount=0;data.Grid={Find=function()return {X=0,Y=0,Rotated=false}end}
rules.torch={itemId=-1};stats.diseases={definitions={All=function()return {}end}}
local rows=require('Game.Equipment.InventoryModel').New(system,stats):Rows(actor.Id)
local foundMagazine,foundAmmo=false,false
for _,row in ipairs(rows)do
    if row.key=='m10' then
        assert(row.detail:find(ammunition:Get(magazines[1].AmmoItemId).name,1,true));foundMagazine=true
    elseif row.itemId==profiles[1].id then assert(row.detail:find(Text.AmmoStats(rules,row.itemId),1,true));foundAmmo=true end
end
assert(foundMagazine and foundAmmo)
rules.Weapon=function()return weapon end;stats.equipment=rules
stats.Get=function()return 0 end;stats.MoveRange=function()return 0 end
local battle={stats=stats,board={},data={Winner='',Phase='combat',Round=1,MaxRounds=10,EncounterId=1,TurnCount=0,LogCount=0},
    Active=function()return actor end,Units=function()return {}end,Reachable=function()return {}end,SkillIds=function()return {}end,
    consumables={All=function()return {}end},encounters={Get=function()return {name='Test'}end}}
local hud=require('Game.Battle.BattleHUDModel').Build(battle,{PartyCount=0})
assert(hud.ammo==string.format(Language.BattleAmmoSummary,ammunition:Get(magazines[2].AmmoItemId).name,magazines[2].Rounds,magazines[2].Capacity))
local gear=assert(loadfile('Tools/Tests/equipment_read_fixture.lua'))()(1,gun.id,0)
local realRules=require('Game.Equipment.EquipmentRules').New(config,{})
assert(Text.Attributes(realRules,gear):find(string.format(Language.EquipmentWeaponArmor,gun.armorPenetration,gun.armorDamageMultiplier),1,true))
print('PASS inventory ammunition profiles, actual magazine type in HUD and base weapon armor statistics')

local log=require('Game.Battle.BattleLog')
local originalRandom=math.random;math.random=function()error('Presentation must not roll randomness')end
local armor={slot='body',before=20,after=0,damage=20,absorbed=10,penetrating=3,overflow=4,preserved=false}
local line=log.Format('damage','',nil,nil,7,{armor=armor})
assert(line:find('20→0',1,true) and line:find(Language.BattleArmorBroken,1,true))
assert(armor.before==20 and armor.after==0 and armor.damage==20 and armor.absorbed==10)
armor.after=20;armor.damage=0;armor.preserved=true
line=log.Format('damage','',nil,nil,7,{armor=armor})
assert(line:find(Language.BattleArmorPreserved,1,true) and not line:find(Language.BattleArmorBroken,1,true))
armor.before=0;armor.after=0
assert(not log.Format('damage','',nil,nil,7,{armor=armor}):find(Language.BattleArmorBroken,1,true))
math.random=originalRandom
print('PASS settled armor facts, broken/retained armor labels, unarmored suppression and no presentation RNG')
