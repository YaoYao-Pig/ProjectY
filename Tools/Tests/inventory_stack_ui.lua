-- Read-only UI projections with a minimal adapter for the native per-pile key bridge.
-- Does not compile C#, run Unity or mutate a real inventory/save.
package.path='Lua/?.lua;'..package.path
local definitions={
    [81]={id=81,name='营造木料',kind='material',width=2,height=1,iconPath=''},
    [31]={id=31,name='弹药',kind='ammo',width=1,height=1,iconPath=''},
}
local itemTable={Get=function(_,id)return assert(definitions[id])end}
local piles={
    {ItemId=81,Count=3,key='s81'},
    {ItemId=81,Count=7,key='p17'},
    {ItemId=81,Count=0,key='p18'},
    {ItemId=31,Count=9,key='s31'},
}
local places={
    s81={X=0,Y=0,Rotated=false},
    p17={X=3,Y=1,Rotated=true},
    s31={X=5,Y=2,Rotated=false},
}
local reads={}
CS={ProjectY={Data={InventoryStacks={Key=function(row)
    reads[row.key]=(reads[row.key] or 0)+1
    return assert(row.key)
end}}}}
local actor={Id=1}
local data={WeaponCount=0,MagazineCount=0,WearableCount=0,StackCount=#piles,
    GetStackAt=function(_,i)return assert(piles[i+1])end,
    CountItem=function()error('UI rows must use the selected pile count, not aggregate ItemId totals')end,
    Grid={Find=function(_,key)return places[key]end}}
local moved
function data:Move(key,x,y,rotated)moved={key,x,y,rotated};return key=='p17'end
local system={data=data,rules={items=itemTable,torch={itemId=94,description='火炬'}},
    adventure={Phase='area'},Actor=function(_,id)return id==1 and actor or nil end}
local model=require('Game.Equipment.InventoryModel').New(system,{})
local rows=model:Rows(1)
assert(#rows==3 and rows[1].key=='s81' and rows[2].key=='p17' and rows[3].key=='s31')
assert(rows[1].itemId==81 and rows[2].itemId==81 and rows[1].count==3 and rows[2].count==7)
assert(rows[1].x==0 and rows[1].y==0 and not rows[1].rotated)
assert(rows[2].x==3 and rows[2].y==1 and rows[2].rotated and rows[2].width==2 and rows[2].height==1)
assert(reads.s81==1 and reads.p17==1 and reads.s31==1 and not reads.p18)
assert(rows[2].detail:find('拖到空格另放一堆',1,true) and rows[2].detail:find('同类物品上合并',1,true))
print('PASS same-item piles keep distinct bridge keys, counts, positions and rotation; zero piles are hidden')

assert(model:Command('move',1,'p17',4,2,false))
assert(moved[1]=='p17' and moved[2]==4 and moved[3]==2 and moved[4]==false)
piles[1].Count=0;places.s81=nil
rows=model:Rows(1)
assert(#rows==2 and rows[1].key=='p17' and rows[1].count==7 and rows[1].x==3)
local ok=model:Command('move',1,'s81',1,1,false)
assert(not ok and moved[1]=='p17','A consumed canonical pile must not redirect a command into another pile')
piles[1].Count=10;places.s81={X=0,Y=0,Rotated=false};piles[2].Count=0;places.p17=nil
rows=model:Rows(1)
assert(#rows==2 and rows[1].key=='s81' and rows[1].count==10)
print('PASS commands preserve pile identity; consuming or merging one pile does not rename or duplicate another')

local area={};local entry={Key='loot:5:0',ItemId=81,Kind='material',ContainerId=5,Count=6,Revealed=true}
local takeArgs
local session={Active=true,Area=area,Find=function(_,key)return key==entry.Key and entry or nil end,
    Take=function(_,inventory,key,x,y,rotated,ammo,capacity,rounds)
        takeArgs={inventory,key,x,y,rotated,ammo,capacity,rounds};return false
    end}
local loot={session=session,equipment=system}
local success,reason=require('Game.Loot.MapLoot').Take(loot,{data={Active=area}},entry.Key,3,2,true)
assert(not success and entry.Count==6)
assert(takeArgs[1]==data and takeArgs[2]==entry.Key and takeArgs[3]==3 and takeArgs[4]==2 and takeArgs[5])
assert(reason:find('位置被占用',1,true) and reason:find('超出背包范围',1,true) and reason:find('物品仍在右侧原位',1,true))
assert(not reason:find('同类物品请拖到已有堆叠上',1,true))
print('PASS rejected loot placement reports collision/bounds and retention without demanding a merge')

local rightEntries={
    {Key='loot:5:0',ItemId=81,Kind='material',ContainerId=5,Count=2,Revealed=true},
    {Key='loot:5:1',ItemId=81,Kind='material',ContainerId=5,Count=8,Revealed=true},
}
local rightPlaces={['loot:5:0']={X=0,Y=0,Rotated=false},['loot:5:1']={X=4,Y=1,Rotated=true}}
local right={Count=2,SelectedContainerId=5,GetAt=function(_,i)return rightEntries[i+1]end,
    Area={GetLootAt=function(_,i)assert(i==4);return {Name='测试容器'}end},
    Grid={Width=6,Height=6,Find=function(_,key)return assert(rightPlaces[key])end}}
local rightRows=require('Game.Loot.LootModel').New({session=right,equipment=system}):Rows()
assert(#rightRows==2 and rightRows[1].key~=rightRows[2].key and rightRows[1].count==2 and rightRows[2].count==8)
assert(rightRows[2].x==4 and rightRows[2].rotated and rightRows[2].displayWidth==1 and rightRows[2].displayHeight==2)
print('PASS existing right-side independent pile projection and rotated footprints remain intact')

-- The workbench is a catalog, so its shared stock groups physical piles by ItemId.
piles[1].Count=3;piles[2].Count=7
definitions[1]={id=1,name='测试法杖',kind='weapon',iconPath=''}
local weapon={Id=1,ItemId=1,OwnerActorId=0}
local workData={WeaponCount=1,MagazineCount=0,StackCount=#piles,
    GetWeapon=function()return weapon end,GetWeaponAt=function()return weapon end,
    GetStackAt=data.GetStackAt,Equipped=function()return nil end,
    CountItem=function(_,id)local count=0;for _,pile in ipairs(piles)do if pile.ItemId==id then count=count+pile.Count end end;return count end}
local requirement={entries={},met=true}
local workRules={items=itemTable,weapons={Get=function()return {socketIds={},categoryId=1,level=1,kind='staff'}end},
    categories={Get=function()return {name='法杖'}end},WeaponTags=function()return {}end,
    CanEquip=function()return true end,WeaponVisual=function()return {}end,
    ItemRequirements=function()return requirement end,Requirements=function()return requirement end,
    Loaded=function()return nil end,PreviewWeapon=function()return {SkillIds=function()return {}end}end}
local workSystem={data=workData,rules=workRules,adventure={PartyCount=1,GetPartyAt=function()return actor end},
    Actor=function()return actor end,HandAllowed=function()return true end,IsCarriedWeapon=function()return true end}
local view={Workbench={ShowWeapon=function()end},InventorySlots={},OptionSlots={}}
local function label()return {gameObject={SetActive=function()end}}end
for _,key in ipairs({'Title','Subtitle','EquipText','Equip','Unequip','Status','CategoryText','Requirements','SocketTitle','Remove','Fill','Stats','TagSlots'})do view[key]=label()end
for i=1,4 do view['Actor'..i]=label();view['ActorText'..i]=label()end
for i=1,4 do view['Socket'..i]=label();view['SocketText'..i]=label()end
local controller={system=workSystem,rules=workRules,stats={Template=function()return {name='队员'}end},view=view,
    weaponId=1,actorId=1,socketId=0,categoryIndex=0,tags={},inventory={},options={},message=''}
local stock
function controller:Rows(pool,_,values)if pool==self.inventory then stock=values end end
local presentation=require('Game.Equipment.EquipmentPresentation');local originals={}
for _,name in ipairs({'Name','Attributes','Affix','Condition'})do originals[name]=presentation[name];presentation[name]=function()return '测试装备'end end
require('UI.Panel.EquipmentWorkbenchCtr').Refresh(controller)
for name,original in pairs(originals)do presentation[name]=original end
assert(#stock==3 and stock[1].weaponId==1)
assert(stock[2].itemId==81 and stock[2].title=='营造木料 ×10' and stock[2].enabled==false)
assert(stock[3].itemId==31 and stock[3].title=='弹药 ×9')
print('PASS actual workbench refresh shows one aggregate catalog row per ItemId, while the backpack keeps separate piles')
