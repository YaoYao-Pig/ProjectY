-- Run after exporting the source tables. Uses real equipment rules and scalar gear adapters;
-- it does not start Unity, create a save, or mutate any gameplay data.
package.path='Lua/?.lua;'..package.path
local Gear=assert(loadfile('Tools/Tests/equipment_read_fixture.lua'))()
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local data={main=nil,off=nil,Equipped=function(self)return self.main end,
    Offhand=function(self)return self.off end,Worn=function()end}
local rules=require('Game.Equipment.EquipmentRules').New(config,data)
local actor={Id=1,TemplateId=1,TraitCount=0,AnimalSpeciesId=0,Growth={SkillCount=0}}
local stats={Get=function()return 20 end}
local untrained={Get=function()return 0 end}
local specs={{id=101,source=40,skill=10},{id=102,source=616,skill=2},
    {id=103,source=1,skill=6},{id=104,source=70,skill=10}}
local function contains(values,wanted)
    for _,value in ipairs(values)do if value==wanted then return true end end
    return false
end
local function fileExists(path)
    local file=assert(io.open(path,'rb'),'Missing equipment resource: '..path);file:close()
end
for _,spec in ipairs(specs)do
    local item,weapon=rules.items:Get(spec.id),rules.weapons:Get(spec.id)
    local sourceItem,sourceWeapon=rules.items:Get(spec.source),rules.weapons:Get(spec.source)
    assert(weapon.level==1 and #weapon.socketIds==0 and #weapon.onHitEffectIds==0)
    assert(#weapon.skillIds==1 and weapon.skillIds[1]==spec.skill,'Starter weapon grants an advanced ability')
    assert(item.assetId==sourceItem.assetId and item.iconPath==sourceItem.iconPath and item.iconMode=='file')
    assert(weapon.gripId==sourceWeapon.gripId and item.iconPath~='','Starter model/icon/grip must match')
    local asset=rules.assets:Get(item.assetId)
    fileExists(asset.modelPath);fileExists(asset.prefabPath);fileExists(item.iconPath)
    assert(rules:CanEquip(actor,spec.id,untrained),'An untrained character cannot use a starter weapon')
    for _,module in ipairs(rules.motion.modules:All())do
        for _,hand in ipairs({'main','off'})do
            local expected=rules.motion:RotationOffset(spec.source,module.id,hand)
            local actual=rules.motion:RotationOffset(spec.id,module.id,hand)
            for index=1,3 do assert(actual[index]==expected[index],'Starter weapon lost an authored hold adjustment')end
        end
    end
    data.main=Gear(1,spec.id,actor.Id)
    local basic=rules:Skill(actor,spec.skill,stats)
    assert(rules:CheckSkillEquipment(actor,basic,stats),'Starter basic attack is unavailable')
    data.main=Gear(2,spec.source,actor.Id)
    local upgrade=rules:Skill(actor,spec.skill,stats)
    assert(basic.damageScale>0 and basic.damageScale<upgrade.damageScale,'Starter weapon must leave room for upgrades')
    data.main=Gear(1,spec.id,actor.Id)
    for _,unitId in ipairs({1,2,3,901,902,903,904,905})do
        actor.TemplateId=unitId
        local skills=rules:SkillIds(actor,rules.units:Get(unitId))
        assert(contains(skills,spec.skill),'Starter weapon failed to grant its basic attack')
        for _,id in ipairs({501,502,505,506,507,508,509,1601,1616,1624})do
            assert(not contains(skills,id),'Starter weapon unexpectedly grants an advanced ability: '..id)
        end
    end
end
print('PASS starter weapon eligibility, basic attacks, upgrade progression, existing icons/models and authored grip corrections')

actor.TemplateId=3;data.main=Gear(3,103,actor.Id)
local spell=rules.skills:Get(3)
assert(spell.catalystKind=='arcane' and rules:CheckSkillEquipment(actor,spell,stats))
assert(contains(rules:SkillIds(actor,rules.units:Get(3)),3),'Starter staff erased a known spell')
data.main.condition.Broken=true
assert(not rules:CheckSkillEquipment(actor,spell,stats),'Broken starter staff must stop providing a catalyst')
data.main=Gear(4,104,actor.Id)
assert(rules:HasWeaponTag(104,'axe') and rules:IsUtilityWeapon(104),'Starter axe lost its exploration tool ability')
print('PASS starter staff preserves known spells/catalyst durability and starter axe retains exploration utility')

data.main=Gear(5,101,actor.Id);data.off=Gear(6,104,actor.Id)
local skills=rules:SkillIds(actor,rules.units:Get(actor.TemplateId))
assert(contains(skills,13),'Single-handed starter axe cannot provide its offhand attack')
local offhand=rules:Skill(actor,13,stats)
assert(offhand.action=='secondary' and offhand.damageScale>0 and rules:CheckSkillEquipment(actor,offhand,stats))
print('PASS single-handed starter sword and axe retain dual-wield/offhand behavior')
