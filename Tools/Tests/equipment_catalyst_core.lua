-- Real configuration and production equipment rules; no Editor or player save mutations.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
CS={ProjectY={Data={EquipmentConditionData={Of=function(item)return assert(item.condition,'Fixture equipment requires durability')end},
    EquipmentAffixData={Of=function(item)return assert(item.affixId,'Fixture equipment requires an affix')end},
    EquipmentCombatState={RepairMaterials=function(value)return math.ceil((value.Maximum-value.Current)/25)end,
        RepairCoins=function(value)return value.Maximum-value.Current end}}}}
local function condition()return {Current=100,Maximum=100,BaseMaximum=100,Broken=false,Efficiency=1}end
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local function weapon(id,item,runes)
    return {Id=id,ItemId=item,OwnerActorId=0,Hand='',MagazineId=0,affixId=1,condition=condition(),GetRune=function(_,socket)return runes and runes[socket] or 0 end}
end
local sword=weapon(1,40);local adapted=weapon(2,41,{[7]=93});local staff=weapon(3,1,{[1]=11,[2]=12})
local rank,investment=0,0
local growth={SkillCount=1,TalentCount=0,GetSkillAt=function()return 103 end,GetRank=function(_,id)assert(id==301);return rank end,
    GetAttribute=function(_,name)return name=='strength' and investment or 0 end}
local actor={Id=1,TemplateId=3,Team=1,Growth=growth,TraitCount=0,Effects={Count=0}}
local ring={Id=4,ItemId=53,OwnerActorId=1,Slot='leftRing',affixId=1,condition=condition()}
local data={main=sword,enemies={},WearableCount=0,Revision=17,WeaponCount=1,MagazineCount=0,StackCount=0,Grid={Find=function()return nil end}}
function data:Equipped(id)return id==1 and self.main or self.enemies[id] end
function data:Offhand(id)return id==1 and self.off or nil end
function data:Worn()return nil end
function data:GetWearableAt()return ring end
function data:GetWeaponAt()return sword end
function data:Equip()error('Rejected equipment must not mutate inventory')end
local stats=require('Game.Battle.CombatStats')(config,data);local rules=stats.equipment
local spell=rules:Skill(actor,103,stats)
assert(spell.catalystKind=='arcane' and spell.skillKind=='active')
local allowed,reason=rules:CheckSkillEquipment(actor,spell,stats)
assert(not allowed and reason:find('触媒'))
local learned=false;for _,id in ipairs(rules:SkillIds(actor,stats:Template(actor))) do if id==103 then learned=true end end
assert(learned,'Missing equipment cannot erase a learned spell')
assert(rules:CheckSkillEquipment(actor,rules:Skill(actor,4,stats),stats),'Ordinary defensive action does not need a catalyst')
print('PASS learned spells remain visible and ordinary actions remain usable without a catalyst')

data.main=adapted
allowed,reason=rules:CheckSkillEquipment(actor,spell,stats)
assert(not allowed and reason:find('奥术兵装'),'Adapter without specialization must explain the missing talent')
local selected
rank=1;allowed,reason,selected=rules:CheckSkillEquipment(actor,spell,stats)
assert(allowed and selected==adapted)
data.main=sword;assert(not rules:CheckSkillEquipment(actor,spell,stats),'Talent alone cannot replace a catalyst')
data.off=adapted;local ok,_,selected=rules:CheckSkillEquipment(actor,spell,stats);assert(ok and selected==adapted)
data.main=staff;assert(select(3,rules:CheckSkillEquipment(actor,spell,stats))==staff,'Main-hand catalyst takes precedence')
print('PASS adapter and specialization are both required; offhand support and main-hand precedence are deterministic')

data.main=sword;data.off=adapted
local adapterOnly=rules:Skill(actor,103,stats)
assert(adapterOnly.damageScale==config:GetTable('CombatSkillTable'):Get(103).damageScale)
-- A one-hand native catalyst is represented by a read-only config view to exercise the general offhand rule.
local originalWeapons=rules.weapons
local offStaffDefinition={};for key,value in pairs(originalWeapons:Get(1))do offStaffDefinition[key]=value end
offStaffDefinition.hands=1
rules.weapons={Get=function(_,id)return id==1 and offStaffDefinition or originalWeapons:Get(id) end}
data.off=staff
local resolved=rules:Skill(actor,103,stats);local base=config:GetTable('CombatSkillTable'):Get(103)
assert(resolved.range==base.range+2 and resolved.maxTargets==3 and resolved.cooldownTurns==base.cooldownTurns+1)
assert(math.abs(resolved.damageScale-base.damageScale*.7*1.25)<.000001,'Spell modifiers must come from the actual offhand catalyst')
rules.weapons=originalWeapons;data.off=nil;data.main=staff
assert(rules:Skill(actor,103,stats).range==resolved.range)
print('PASS learned spells use modifiers from the selected catalyst instead of an unrelated main-hand weapon')

local enemy={Id=101,TemplateId=3,Team=2,Growth=growth}
data.enemies[101]=weapon(5,1)
assert(rules:CheckSkillEquipment(enemy,spell,stats),'Actual enemy staff must remain a valid native catalyst')
data.enemies[101]=nil;assert(not rules:CheckSkillEquipment(enemy,spell,stats),'Disarmed enemy cannot cast from a template staff')
data.enemies[101]=weapon(6,40);assert(not rules:CheckSkillEquipment(enemy,spell,stats))
print('PASS enemies require their actual owned catalyst and lose spell access after disarm')

data.main=sword;data.WearableCount=1
assert(stats:Get(actor,'strength')==4 and stats:Get(actor,'strength',true)==2)
assert(rules:Requirements(actor,sword,stats).met,'Post-equip effectiveness still includes wearable attributes')
allowed,reason=rules:CanEquip(actor,40,stats);assert(not allowed and reason:find('不计装备加成'))
investment=2;assert(rules:CanEquip(actor,40,stats),'Exact threshold must accept genuine growth points')
investment=1;assert(not rules:CanEquip(actor,40,stats),'One point below the threshold must reject')
assert(rules:CanEquip(actor,53,stats),'An equipment requirement row may explicitly have no constraints')
print('PASS attribute hard gate excludes wearable boosts and accepts the exact trained threshold')

investment=0
local System=require('Game.Equipment.EquipmentSystem')
local system=setmetatable({data=data,rules=rules,adventure={Phase='map'},Actor=function()return actor end,
    context={systems={Get=function(_,name)assert(name=='Battle');return {stats=stats}end}}},{__index=System})
allowed,reason=system:Command('equip',1,sword.Id,0,0)
assert(not allowed and reason:find('属性不足') and data.Revision==17)
local Model=require('Game.Equipment.InventoryModel')
local originalWearables=rules.wearables
local wearableRule={};for key,value in pairs(originalWearables:Get(53))do wearableRule[key]=value end
wearableRule.requirementId=41
rules.wearables={Get=function(_,id)return id==53 and wearableRule or originalWearables:Get(id)end}
local wearableRows={WeaponCount=0,MagazineCount=0,StackCount=0,WearableCount=1,Grid=data.Grid,GetWearableAt=function()return ring end,
    GetWearable=function(_,id)assert(id==ring.Id);return ring end,
    CanWear=function()return true end,Wear=function()error('Rejected wear must be transactional')end}
system.data=wearableRows
local model=Model.New(system,stats);local rows=model:Rows(1)
assert(rows[1].equipMask==0 and rows[1].detail:find('属性不足'))
assert(not model:Command('equip:rightRing',1,'g4',0,0,false))
rules.wearables=originalWearables
print('PASS weapon commands and wearable drag previews reject unmet requirements before any mutation')

for _,id in ipairs({40,41})do
    local definition=rules.weapons:Get(id);assert(#definition.socketIds==1)
    local socket=rules.sockets:Get(definition.socketIds[1]);assert(socket.kind=='catalyst' and socket.weaponItemId==id)
end
local adapter=rules.items:Get(93);assert(adapter.assetId==3 and adapter.iconMode=='file')
local icon=assert(io.open(adapter.iconPath,'rb'));icon:close()
assert(rules.runes:Get(93).requiredTalentId==301)
assert(loadfile('Lua/UI/Panel/EquipmentWorkbenchCtr.lua'))
config:OnShutdown()
print('PASS real adapter configuration, model/icon reuse and both sword socket definitions')
