package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local Gear=assert(loadfile('Tools/Tests/equipment_read_fixture.lua'))()
local weapon=Gear(1,800,1);weapon.MagazineId=2
local magazine={Id=2,ItemId=810,AmmoItemId=31,Capacity=24,Rounds=24}
local data={Equipped=function()return weapon end,Offhand=function()end,Worn=function()end,GetMagazine=function(_,id)assert(id==2);return magazine end}
local rules=require('Game.Equipment.EquipmentRules').New(config,data)
local actor={Id=1,TemplateId=3,TraitCount=0}
local stats={Get=function()return 30 end}
local definition=rules.weapons:Get(800)
local base=rules.skills:Get(7)
local seen={}
for _,profile in ipairs(rules.ammunition:ForMagazine(810))do
    assert(rules.ammunition:Compatible(810,profile.id));seen[profile.ammoType]=true
    magazine.AmmoItemId=profile.id
    local skill=rules:Skill(actor,7,stats)
    assert(skill.ammoItemId==profile.id)
    assert(skill.armorPenetration==math.max(0,math.min(100,definition.armorPenetration+profile.armorPenetrationBonus)))
    assert(skill.armorDamageMultiplier==definition.armorDamageMultiplier*profile.armorDamageMultiplier)
    assert(skill.fleshDamageMultiplier==profile.fleshDamageMultiplier)
    local penetration,armor,flesh=skill.armorPenetration,skill.armorDamageMultiplier,skill.fleshDamageMultiplier
    rules:ApplyArmorProfile(skill,weapon)
    assert(skill.armorPenetration==penetration and skill.armorDamageMultiplier==armor and skill.fleshDamageMultiplier==flesh,'Re-resolving the selected profession weapon must not stack ammunition bonuses')
end
assert(seen.balanced and seen.armor_piercing and seen.flesh)
assert(not rules.ammunition:Compatible(810,820) and not rules.ammunition:Compatible(811,822))
assert(not rules.ammunition:Compatible(810,40))
assert(base.armorPenetration==nil and base.ammoItemId==nil,'Shared base skills must remain immutable')
assert(rules:Skill(actor,9,stats).armorPenetration==nil,'Reload is not an armor attack')
local magical={target='enemy',catalystKind='arcane',skillGroup='spell',armorPenetration=100,armorDamageMultiplier=9,fleshDamageMultiplier=9}
rules:ApplyArmorProfile(magical,weapon);assert(magical.armorPenetration==nil,'Catalyst spells must not inherit bullet damage')
local unarmed={target='enemy',catalystKind='none',skillGroup='weapon',armorPenetration=100}
rules:ApplyArmorProfile(unarmed,nil);assert(unarmed.armorPenetration==nil)
weapon=Gear(3,40,1)
local melee=rules:Skill(actor,502,stats)
assert(melee.preserveArmor and melee.armorPenetration==rules.weapons:Get(40).armorPenetration,'Precision attacks retain configured armor preservation')
assert(melee.fleshDamageMultiplier==1 and melee.ammoItemId==nil)
print('PASS three ammunition profiles, caliber guards, actual loaded-bullet resolution, nonstacking profession recalculation, immutable config, reload/spell/unarmed exclusions and precise armor preservation')
