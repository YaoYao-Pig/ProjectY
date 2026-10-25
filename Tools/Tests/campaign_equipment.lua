package.path='Lua/?.lua;'..package.path
local Starter=require('Game.Equipment.StarterWeapons')
local recipe={equipUnitIds={1,2},equipWeaponIds={40,46}}
local actors={{Id=1,TemplateId=1},{Id=2,TemplateId=2}}
local party={PartyCount=2,GetPartyAt=function(_,i)return actors[i+1]end}
local weapons={{Id=101,ItemId=40,OwnerActorId=0},{Id=102,ItemId=46,OwnerActorId=0}}
local equipped,changes={},0
local data={WeaponCount=2,GetWeaponAt=function(_,i)return weapons[i+1]end,
    Grid={Find=function(_,key)return key=='w101' or key=='w102' end},
    Equipped=function(_,id)return equipped[id]end,Offhand=function()end,Worn=function()end,
    Equip=function(_,actorId,weaponId)equipped[actorId]=weaponId;changes=changes+1;return true end}
local allowed=true
local rules={weapons={Get=function(_,id)assert(id==40 or id==46);return {}end},CanEquip=function()return allowed,'attribute requirement'end}
local loadouts={Items=function()return {}end}
local function prepare()return Starter.Plan(recipe,data,party,rules,{},loadouts)end
local plan=prepare();assert(changes==0 and #plan==2)
allowed=false;assert(#prepare()==2 and changes==0 and not rules:CanEquip(),'Low attributes retain starter plan without allowing manual equip');allowed=true
weapons[2].OwnerActorId=99;assert(not pcall(prepare) and changes==0);weapons[2].OwnerActorId=0
recipe.equipUnitIds[2]=1;assert(not pcall(prepare) and changes==0);recipe.equipUnitIds[2]=2
loadouts.Items=function()return {40}end;assert(not pcall(prepare) and changes==0);loadouts.Items=function()return {}end
Starter.Apply(data,plan)
assert(changes==2 and equipped[1]==101 and equipped[2]==102 and #weapons==2,'Starter setup must reuse original instances')
print('PASS starter preflight, low-attribute grant/manual gate, absent ownership, duplicate templates, conflicting loadouts and original-instance equipment')

local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local bytes=file:read('*a');file:close();return bytes
end}})
local campaign=config:GetTable('AdventureDemoTable'):Get(3)
local starter=config:GetTable('EquipmentDemoTable'):Get(campaign.equipmentRecipeId)
local carried={};local cells=0
for i,id in ipairs(starter.starterItemIds) do
    carried[id]=starter.starterCounts[i]
    local item=config:GetTable('EquipmentItemTable'):Get(id)
    local instance=item.kind=='weapon' or item.kind=='wearable' or item.kind=='magazine'
    cells=cells+item.width*item.height*(instance and starter.starterCounts[i] or 1)
end
assert(#campaign.partyIds==3 and campaign.maxPartySize==4,'Campaign must leave a recruit slot')
assert(cells<starter.bagWidth*starter.bagHeight/2,'Campaign must leave room for loot')
for _,id in ipairs({41,42,43,44,45,53,54,93})do assert(not carried[id],'Upgrade equipment should be earned: '..id)end
for i,id in ipairs(starter.equipWeaponIds)do assert(carried[id] and starter.equipUnitIds[i]==campaign.partyIds[i])end
assert(carried[94]==1 and carried[91]>=2,'Campaign requires light and healing supplies')
local loot=require('Game.Loot.LootRules').New(config)
local items=config:GetTable('EquipmentItemTable')
local upgrades,observed={},{}
for _,entry in ipairs(config:GetTable('LootEntryTable'):All())do
    if entry.poolId==5 then upgrades[entry.itemId]=true;assert(not carried[entry.itemId],'Guarded treasure should provide a new equipment option')end
end
for seed=1,128 do
    for _,container in ipairs({10,11,200,206})do
        local ids,counts=loot:Roll(container,seed)
        assert(#ids>0,'Exploration supplies should not be entirely empty')
        for i,id in ipairs(ids)do assert(counts[i]>0);items:Get(id)end
    end
    local ids,counts=loot:Roll(204,seed);local total=0
    for i,id in ipairs(ids)do assert(upgrades[id]);total=total+counts[i];observed[id]=true end
    assert(total==2,'Guarded treasure should yield two upgrade draws')
end
assert(observed[41] and observed[45] and observed[54],'Treasure sample lacks its common, rare or accessory upgrade')
local torchStock=false
for _,entry in ipairs(config:GetTable('ShopEntryTable'):All())do if entry.itemId==94 and entry.chance==100 then torchStock=true end end
assert(torchStock,'Torch needs a reliable replacement source')
print('PASS campaign capacity/recruit slot, progression rewards, 128 deterministic loot samples and reliable torch stock')
