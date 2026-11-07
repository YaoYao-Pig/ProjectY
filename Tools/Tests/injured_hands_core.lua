-- Exercises production hand rules and loot routing with isolated native state boundaries.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local body={}
CS={ProjectY={Data={BodyHealth=body,EquipmentCombatState={}}}}
function body.MaximumHP(actor,index)return actor.parts[index+1].maximum end
function body.HP(actor,index)return actor.parts[index+1].health end
function body.Damage(actor,index)return actor.parts[index+1].trauma end
function body.Permanent(actor,index)return actor.parts[index+1].permanent end
local injuries=require('Game.Battle.InjuryRules').New(config)
local actor={Id=1,TemplateId=1,HP=600,Q=2,R=3,parts={}}
for i=1,6 do actor.parts[i]={maximum=100,health=100,trauma=0,permanent=false}end
local function reset()
    for _,part in ipairs(actor.parts)do part.health=100;part.trauma=0;part.permanent=false end
end
assert(injuries:HandsAllowed(actor,'weapon',2))
actor.parts[3].health=51;assert(injuries:HandsAllowed(actor,'offhand',1))
actor.parts[3].health=50
assert(not injuries:HandsAllowed(actor,'offhand',1) and not injuries:HandsAllowed(actor,'weapon',2))
assert(injuries:HandsAllowed(actor,'weapon',1),'A left-arm injury must leave the right hand usable')
reset();actor.parts[4].trauma=50
assert(not injuries:HandsAllowed(actor,'weapon',1) and injuries:HandsAllowed(actor,'offhand',1))
actor.parts[4].trauma=49;assert(injuries:HandsAllowed(actor,'weapon',1),'Both trauma and health must permit recovered use')
actor.parts[4].permanent=true;assert(not injuries:HandsAllowed(actor,'weapon',1))
reset();actor.parts[1].trauma=100;actor.parts[5].health=0
assert(injuries:HandsAllowed(actor,'weapon',2),'Head and leg injuries must not disable hand slots')
local nonhuman
for _,unit in ipairs(config:GetTable('CombatUnitTable'):All())do if not unit.bodyInjuries then nonhuman=unit.id;break end end
local old=actor.TemplateId;actor.TemplateId=assert(nonhuman);actor.parts[3].trauma=100
assert(injuries:HandsAllowed(actor,'weapon',2));actor.TemplateId=old;reset()
print('PASS injury thresholds, independent hands, two-handed requirements, healing and nonhumanoid exemption')

local rolls=0
for index=0,5 do
    local hit=injuries:SelectHit(actor,function()rolls=rolls+1;return 99 end,index)
    assert(hit.part.index==index and hit.locationRoll==nil)
end
assert(rolls==0,'A selected body part must not roll a random location')
assert(not pcall(function()injuries:SelectHit(actor,function()return 0 end,6)end))
actor.parts[4].maximum=0
assert(not pcall(function()injuries:SelectHit(actor,function()return 0 end,3)end))
actor.parts[4].maximum=100
assert(injuries:SelectHit(actor,function()return 0 end).part.index==0)
print('PASS targeted selection uses exact parts without consuming location RNG, with normal random attacks unchanged')

local EquipmentRules=require('Game.Equipment.EquipmentRules')
local rules=setmetatable({injuries=injuries,items=config:GetTable('EquipmentItemTable'),
    weapons=config:GetTable('EquipmentWeaponTable'),wearables=config:GetTable('EquipmentWearableTable')},EquipmentRules)
local blade={Id=11,ItemId=40,Hand='weapon'}
local off={Id=12,ItemId=40,Hand='offhand'}
local shield={Id=13,ItemId=57,Slot='offhand'}
local data={main=blade,off=off}
function data:Equipped()return self.main end
function data:Offhand()return self.off end
function data:Worn()return self.shield end
rules.data=data;rules.affixes={Name=function(_,item)return 'item-'..item.Id end}
function rules:Condition()return {Broken=false}end
function rules:ItemRequirements()return {met=true}end
actor.parts[4].trauma=50
assert(not rules:CanEquip(actor,40,{},'weapon') and rules:CanEquip(actor,40,{},'offhand'))
local offSkill=config:GetTable('EquipmentWeaponTable'):Get(40).offhandSkillId
assert(rules:CheckSkillEquipment(actor,{id=offSkill,skillGroup='weapon',catalystKind='none'},{}))
assert(not rules:CheckSkillEquipment(actor,{id=1,skillGroup='weapon',catalystKind='none'},{}))
reset();actor.parts[3].health=50
assert(not rules:CanEquip(actor,57,{},'offhand') and not rules:CanEquip(actor,42,{},'weapon'))
print('PASS equip and actual main/offhand attacks enforce the same limb requirements')

local containers={};local state={LootCount=0}
function state:AddLoot(index,id,name)
    assert(index==9 and id==102 and name~='');self.LootCount=self.LootCount+1
    containers[self.LootCount]={Id=self.LootCount,items={}}
end
function state:GetLootAt(index)return assert(containers[index+1])end
local areas={data={Active=state},ActiveLayout=function()return {Find=function(_,q,r)assert(q==2 and r==3);return {index=9}end}end}
local native=CS.ProjectY.Data.EquipmentCombatState
local refreshes=0
function native.DropWeapon(bag,_,id,owner,weaponId)
    assert(owner==actor.Id)
    local item=bag.main and bag.main.Id==weaponId and bag.main or assert(bag.off)
    assert(item.Id==weaponId)
    containers[id].items[#containers[id].items+1]=item
    if item==bag.main then bag.main=nil else bag.off=nil end
end
function native.DropWearable(bag,_,id,owner,wearableId)
    assert(owner==actor.Id and bag.shield.Id==wearableId)
    containers[id].items[#containers[id].items+1]=bag.shield;bag.shield=nil
end
function native.RefreshMaximum()refreshes=refreshes+1 end
local loot=setmetatable({equipment={rules=rules,data=data},Prepare=function()end},{__index=require('Game.Loot.MapLoot')})
local stats={injuries=injuries,MaximumHP=function()return 600 end}
local names=loot:DropInjuredHands(areas,actor,stats)
assert(#names==1 and data.main==blade and not data.off and containers[1].items[1]==off)
assert(#loot:DropInjuredHands(areas,actor,stats)==0 and state.LootCount==1 and refreshes==1)
data.shield=shield
names=loot:DropInjuredHands(areas,actor,stats)
assert(#names==1 and not data.shield and containers[2].items[1]==shield and data.main==blade)
data.main={Id=14,ItemId=42,Hand='weapon'};local twoHand=data.main
names=loot:DropInjuredHands(areas,actor,stats)
assert(#names==1 and not data.main and containers[3].items[1]==twoHand)
actor.parts[4].trauma=50
local container,reason=loot:Recoverable(areas,actor,stats)
assert(not container and reason==require('Language').BodyRightArmUnavailable)
print('PASS original weapon/shield objects move once to the actor cell, two-handed drops and injured recovery denial')

reset();actor.parts[3].trauma=50;actor.parts[4].trauma=50;data.main=blade;data.off=off
names=loot:DropInjuredHands(areas,actor,stats)
assert(#names==2 and state.LootCount==5 and containers[4].items[1]==blade and containers[5].items[1]==off)
assert(#containers[4].items==1 and #containers[5].items==1,'Simultaneous hand drops must remain independently recoverable')
print('PASS both injured hands create independent one-weapon drops so pickup can inspect each weapon')
