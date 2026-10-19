-- Real exported tables and production rules, without an Editor or user saves.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
CS={ProjectY={Data={EquipmentAffixData={Of=function(item)return assert(item.affixId)end},
    EquipmentConditionData={Of=function(item)return assert(item.condition)end}}}}
local function gear(id,itemId,affix)
    return {Id=id,ItemId=itemId,affixId=affix,OwnerActorId=1,Hand='weapon',MagazineId=0,
        condition={Current=100,Maximum=100,BaseMaximum=100,Efficiency=1,Broken=false},GetRune=function()return 0 end}
end
local sword,off,staff,armor=gear(1,40,1),gear(2,41,1),gear(3,1,1),gear(4,52,8)
local data={main=sword,off=off,WearableCount=0}
function data:Equipped()return self.main end
function data:Offhand()return self.off end
function data:Worn()return nil end
function data:GetWearableAt()return armor end
local actor={Id=1,TemplateId=3,Team=1,Growth={SkillCount=0,GetRank=function()return 0 end}}
local stats={Get=function()return 100 end}
local rules=require('Game.Equipment.EquipmentRules').New(config,data)
local affixes=rules.affixes
local Affixes=require('Game.Equipment.EquipmentAffixes')
assert(Affixes.NormalizeColor('FFFF')=='#FFFFFFFF' and Affixes.NormalizeColor('#abc')=='#AABBCC')
assert(Affixes.NormalizeColor('12abEF')=='#12ABEF' and Affixes.NormalizeColor('#12345678')=='#12345678')
for _,value in ipairs({'FF','12345','red','<color=red>','#GGGG'}) do assert(not pcall(Affixes.NormalizeColor,value)) end
for itemId,pool in pairs(affixes.pools) do
    local total=0
    for i,id in ipairs(pool.ids) do assert(affixes.allowed[itemId][id]);total=total+pool.weights[i] end
    assert(total>0 and affixes.allowed[itemId][1])
end
assert(not affixes.allowed[53][6] and not affixes.allowed[2][3] and affixes.allowed[40][3])
assert(affixes:Name(sword)==rules.items:Get(40).name)
sword.affixId=6;assert(affixes:Name(sword)=='传奇的'..rules.items:Get(40).name)
assert(affixes:Text(sword):find('伤害 +20%',1,true) and affixes:Text(sword):find('命中 +10',1,true))
sword.affixId=7;assert(not pcall(function()affixes:Of(sword)end));sword.affixId=1
print('PASS applicable pools, ordinary names, affix display and incompatible IDs')

local mainBase,offBase=rules:Skill(actor,10,stats),rules:Skill(actor,13,stats)
sword.affixId=6;off.affixId=12
local main,secondary=rules:Skill(actor,10,stats),rules:Skill(actor,13,stats)
assert(math.abs(main.damageScale-mainBase.damageScale*1.2)<1e-9 and main.hitChance==100)
assert(math.abs(secondary.damageScale-offBase.damageScale*.85)<1e-9 and secondary.hitChance==offBase.hitChance)
sword.affixId=5;assert(rules:Skill(actor,10,stats).hitChance==mainBase.hitChance-10)
local support=rules:Skill(actor,4,stats)
assert(support.damageScale==rules.skills:Get(4).damageScale and support.hitChance==rules.skills:Get(4).hitChance)
data.main=gear(5,2,5);data.off=nil
local reload=rules:Skill(actor,9,stats)
assert(reload.damageScale==rules.skills:Get(9).damageScale and reload.hitChance==rules.skills:Get(9).hitChance)
print('PASS main/offhand separation, signed attack modifiers, hit cap and unchanged support/reload')

data.main=sword;data.off=staff;sword.affixId=12
local spellBase=rules:Skill(actor,103,stats);staff.affixId=6
assert(math.abs(rules:Skill(actor,103,stats).damageScale-spellBase.damageScale*1.2)<1e-9)
data.main=staff;data.off=nil
local granted=rules:Skill(actor,6,stats)
staff.affixId=1;local grantedBase=rules:Skill(actor,6,stats)
assert(math.abs(granted.damageScale-grantedBase.damageScale*1.2)<1e-9,'Native staff spell must apply the affix only once')
staff.affixId=10;assert(rules:AttributeBonus(actor,'intellect')==1)
staff.condition.Efficiency=0;staff.condition.Broken=true
assert(rules:AttributeBonus(actor,'intellect')==0 and not rules:Catalyst(actor,'arcane'))
data.main=nil;data.off=nil
print('PASS selected catalyst, no double scaling, weapon attributes and broken catalyst')

data.WearableCount=1
assert(rules:AttributeBonus(actor,'defense')==5 and rules:AttributeBonus(actor,'speed')==-1)
armor.condition.Efficiency=.5
assert(rules:AttributeBonus(actor,'defense')==3 and rules:AttributeBonus(actor,'speed')==-1,'Negative half points must not round to a free bonus')
armor.affixId=13;armor.condition.Efficiency=1
assert(rules:AttributeBonus(actor,'defense')==2 and affixes:Name(armor):find('破损'))
armor.condition.Efficiency=0;armor.condition.Broken=true
assert(rules:AttributeBonus(actor,'defense')==0 and rules:ConditionText(armor):find('已损毁'))
assert(affixes:Of(armor).id==13,'Durability does not replace the affix')
print('PASS wearable sums, negative rounding, broken equipment and distinct durability labels')

-- Final inventory projection shows both the resolved attributes and their affix source.
armor.condition.Efficiency=1;armor.condition.Broken=false;armor.Slot='body';armor.affixId=8
data.WeaponCount=0;data.MagazineCount=0;data.StackCount=0
data.Grid={Find=function()return nil end};data.GetWearable=function()return armor end;data.CanWear=function()return true end
local system={data=data,rules=rules,adventure={Phase='map'},Actor=function()return actor end,
    RepairQuote=function()return {materials=0,coins=0}end}
local rows=require('Game.Equipment.InventoryModel').New(system,stats):Rows(1)
local plain=rows[1].detail:gsub('<[^>]+>','')
assert(#rows==1 and rows[1].name:find('厚重') and plain:find('防御%s+%+5') and plain:find('速度%s+%-1'))
assert(not rows[1].name:find('<',1,true) and rows[1].displayName:find('<color=',1,true) and rows[1].displayName:find('●',1,true))
assert(rows[1].detail:find('<size=16>',1,true) and rows[1].detail:find('#F19A96',1,true))
local loot=gear(6,40,6);loot.Kind='weapon';loot.Count=1;loot.Revealed=false;loot.ContainerId=1;loot.Key='loot:1:0'
local session={Count=1,SelectedContainerId=0,Area={GetLootAt=function()return {Name='宝箱'}end},GetAt=function()return loot end}
local model=require('Game.Loot.LootModel').New({session=session,equipment={rules=rules}})
assert(model:Rows()[1].name=='未搜索的物品')
assert(model:Rows()[1].displayName=='未搜索的物品','Unsearched loot cannot reveal its quality color')
loot.Revealed=true;assert(model:Rows()[1].name:find('传奇'))
loot.Count=0;loot.affixId=nil;assert(model:Rows()[1].count==0,'Taken items must not query released physical state')
print('PASS inventory final values, concealed loot and safe projection after transfer')

-- Materializing chest equipment must not let the combat pickup action bypass its container.
local groundId,chestId
local containers=config:GetTable('EquipmentLootTable')
for _,row in ipairs(containers:All()) do if row.kind=='ground' then groundId=row.id else chestId=row.id end end
assert(groundId and chestId)
local container={TableId=chestId,CellIndex=1,CanSearch=true}
local cell={index=1,q=0,r=0,layer=1};local area={cells={cell},Find=function()return cell end,CanSee=function()return true end}
local state={LootCount=1,GetLootAt=function()return container end}
local areas={data={Active=state},ActiveLayout=function()return area end}
local calls=0
CS.ProjectY.Data.EquipmentCombatState={GroundWeapon=function()calls=calls+1;return sword end}
local world=setmetatable({rules={containers=containers},equipment={data=data,rules=rules}},{__index=require('Game.Loot.MapLoot')})
actor.Q=0;actor.R=0;sword.affixId=1
assert(not world:Recoverable(areas,actor,stats) and calls==0,'A chest cannot be looted through the combat pickup action')
container.TableId=groundId;container.CanSearch=false
assert(not world:Recoverable(areas,actor,stats) and calls==0,'Locked ground loot cannot be picked up')
container.CanSearch=true
assert(world:Recoverable(areas,actor,stats)==container and calls==1)
print('PASS combat pickup cannot bypass closed containers after physical loot generation')
for _,path in ipairs({'Lua/Game/Equipment/EquipmentAffixes.lua','Lua/Game/Equipment/EquipmentRules.lua',
    'Lua/Game/Equipment/EquipmentSystem.lua','Lua/Game/Equipment/InventoryModel.lua','Lua/Game/Loot/MapLoot.lua',
    'Lua/Game/Loot/LootModel.lua','Lua/Game/Shop/ShopModel.lua','Lua/Game/Adventure/CharacterSave.lua','Lua/UI/Panel/EquipmentWorkbenchCtr.lua'}) do assert(loadfile(path)) end
config:OnShutdown()
