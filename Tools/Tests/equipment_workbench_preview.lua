-- Read-only workbench queries against actual configuration; no Editor or player inventory.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local function weapon(id,itemId,runes)
    return {Id=id,ItemId=itemId,OwnerActorId=0,Hand='',MagazineId=0,GetRune=function(_,slot)return runes and runes[slot] or 0 end}
end
local main,off,staff=weapon(1,40),weapon(2,41),weapon(3,1,{[1]=11,[2]=12})
main.OwnerActorId=7;main.Hand='weapon';off.OwnerActorId=7;off.Hand='offhand'
local shield={Id=4,ItemId=57,OwnerActorId=7,Slot='offhand'}
local data={main=main,shield=shield,Revision=19,WearableCount=1}
function data:Equipped(id)assert(id==7);return self.main end
function data:Offhand(id)assert(id==7);return self.off end
function data:Worn(id,slot)assert(id==7);return slot=='offhand' and self.shield or nil end
function data:GetWearableAt(i)assert(i==0 and self.shield);return self.shield end
function data:Equip()error('Preview must not equip or unequip')end
function data:EquipOffhand()error('Preview must not mutate the offhand')end
function data:Wear()error('Preview must not unequip the shield')end
local EmptyGrowth=assert(loadfile('Tools/Tests/growth_empty.lua'))()
local actor={Id=7,Team=1,TemplateId=1,TraitCount=0,Effects={Count=0},Growth=EmptyGrowth()}
local stats=require('Game.Battle.CombatStats')(config,data);local rules=stats.equipment
local heavyTags=rules:WeaponTags(45)
assert(#heavyTags==2 and heavyTags[1].id=='two_handed_sword' and heavyTags[1].name=='双手剑' and heavyTags[2].id=='greatsword')
assert(rules:HasWeaponTag(45,'two_handed_sword') and rules:HasWeaponTag(42,'two_handed_sword'))
assert(not rules:HasWeaponTag(40,'two_handed_sword') and not rules:HasWeaponTag(45,'axe'))
assert(not pcall(function() rules:HasWeaponTag(45,'missing_tag') end),'Misspelled gameplay tags must fail')
for _,definition in ipairs(rules.weapons:All()) do
    local seen={}
    for _,tag in ipairs(rules:WeaponTags(definition.id)) do assert(not seen[tag.id]);seen[tag.id]=true end
end
local function resolve(query)
    local rows={}
    for _,id in ipairs(query:SkillIds(actor,stats:Template(actor))) do rows[id]=query:Skill(actor,id,stats) end
    return rows
end
-- Reproduce the old controller's virtual main-hand override while the actor wears a shield.
local old=setmetatable({Weapon=function()return staff end},{__index=rules})
local ok,err=pcall(function()resolve(old)end)
assert(not ok and err:find('No motion module for staff/2/shield/',1,true),tostring(err))
local preview=rules:PreviewWeapon(staff);local skills=resolve(preview)
assert(preview:MotionModule(actor).code=='staff' and skills[6] and skills[6].maxTargets==3)
assert(rules:MotionModule(actor).code=='sword_shield')
assert(data.main==main and data.shield==shield and data.Revision==19 and shield.OwnerActorId==7 and main.Hand=='weapon')
print('PASS reproduced staff/2/shield crash; isolated staff preview resolves without changing the real sword/shield loadout')

-- Rune, requirement and support-skill values match the already valid single-weapon context.
local baseline=setmetatable({Weapon=function()return staff end,Offhand=function()return nil end,
    MotionModule=function()return rules.motion:Resolve(rules.weapons:Get(1),nil,nil)end},{__index=rules})
local expected=resolve(baseline)
for id,row in pairs(skills)do for _,key in ipairs({'cost','range','maxTargets','hitChance','damageScale','cooldownTurns','actionTemplate'})do
    assert(row[key]==expected[id][key],'Weapon preview changed '..key)
end end
assert(not pcall(function()rules.motion:Resolve(rules.weapons:Get(1),nil,shield)end),'Invalid real equipment must still fail')

data.shield=nil;data.WearableCount=0;data.off=off
assert(rules:MotionModule(actor).code=='dual' and resolve(rules)[13])
local count=0
for _,definition in ipairs(rules.weapons:All())do
    local candidate=weapon(100+definition.id,definition.id)
    for _,shielded in ipairs({true,false})do
        data.shield=shielded and shield or nil;data.off=not shielded and off or nil;data.WearableCount=shielded and 1 or 0
        local query=rules:PreviewWeapon(candidate);local rows=resolve(query)
        assert(query:Weapon(actor)==candidate and query:Offhand(actor)==nil and not rows[13])
        assert(query:MotionModule(actor)==rules.motion:Resolve(definition,nil,nil))
        for _,id in ipairs(definition.skillIds)do assert(rows[id],'Selected weapon lost a granted skill')end
        assert(data.main==main and data.shield==(shielded and shield or nil) and data.off==(not shielded and off or nil) and data.Revision==19)
        assert(candidate.OwnerActorId==0 and candidate.Hand=='')
        count=count+1
    end
end
data.shield=nil;data.off=off;data.WearableCount=0
assert(not resolve(rules:PreviewWeapon(off))[13],'Previewing the real offhand must not duplicate it in both hands')
assert(resolve(rules)[13] and rules:MotionModule(actor).code=='dual' and off.Hand=='offhand')
assert(loadfile('Lua/UI/Panel/EquipmentWorkbenchCtr.lua'))
assert(loadfile('Lua/UI/Widget/EquipmentTag.lua'))
config:OnShutdown()
print('PASS '..count..' configured weapon/shield-or-dual preview cases; runes, current attributes and actual offhand combat remain intact')
