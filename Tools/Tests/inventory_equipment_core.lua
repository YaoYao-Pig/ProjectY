local EmptyGrowth=assert(loadfile('Tools/Tests/growth_empty.lua'))()
-- Actual configuration, offhand guards, damage resolution and shared pawn appearance; no Editor.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local main={Id=1,ItemId=40,GetRune=function() return 0 end}
local off={Id=2,ItemId=41,GetRune=function() return 0 end}
local large={Id=3,ItemId=42,GetRune=function() return 0 end}
local shield={Id=4,ItemId=57,Slot='offhand',OwnerActorId=1}
local data={WearableCount=0}
function data:Equipped() return self.main end
function data:Offhand() return self.off end
function data:Worn(_,slot) return slot=='offhand' and self.shield or nil end
function data:GetWearableAt() return shield end
local stats=require('Game.Battle.CombatStats')(config,data)
local rules=stats.equipment
local system={data=data,rules=rules,HandAllowed=require('Game.Equipment.EquipmentSystem').HandAllowed}
assert(system:HandAllowed(1,main,'offhand'))
assert(not system:HandAllowed(1,large,'offhand'))
data.main=large;assert(not system:HandAllowed(1,off,'offhand'));assert(not system:HandAllowed(1,nil,'offhand'))
data.main=main;data.off=off;assert(not system:HandAllowed(1,large,'weapon'))
data.off=nil;data.shield=shield;assert(not system:HandAllowed(1,large,'weapon'))
data.shield=nil;assert(system:HandAllowed(1,large,'weapon'));data.off=off
print('PASS single-hand, shield and two-hand conflicts in both directions')
local actor={Id=1,Team=1,Growth=EmptyGrowth(),TemplateId=1,TraitCount=0,ActionTemplateId=1,ActionSequence=0,ActionShots=0,ActionTargetQ=0,ActionTargetR=0}
local ids=rules:SkillIds(actor,stats:Template(actor));local count=0
for _,id in ipairs(ids) do if id==13 then count=count+1 end end
assert(count==1)
local skill=rules:Skill(actor,13,stats);local definition=rules.weapons:Get(41)
local requirement=rules:Requirements(actor,off,stats)
assert(skill.action=='secondary' and skill.cost==2 and skill.actionTemplate==7)
assert(math.abs(skill.damageScale-.7*definition.damageMultiplier*requirement.damageScale)<.000001)
assert(rules.actions:Get(7).kind=='offhand_slash')
print('PASS independent offhand attack uses offhand multipliers, requirements and secondary AP')
local appearance=require('Game.Adventure.PawnAppearance').New(config)
local snapshot=rules:ActorVisual(actor)
assert(snapshot.weapon.id==1 and snapshot.offhand.id==2 and #snapshot.wearables==0)
assert(snapshot.pose.offHandFollowsWeapon==false)
-- Pawn forward is +Z. Anatomical right is +X and projects to screen-left in a front portrait.
for _,pose in ipairs(rules.poses:All()) do
    assert(pose.mainShoulder[1]>0 and pose.offShoulder[1]<0,'Shoulders must use character-relative handedness')
    assert(pose.mainElbow[1]>0 and pose.offElbow[1]<0,'Arm chains must stay on their own side')
    -- mainHand is now the weapon origin; an archer's origin can be at the left-hand bow grip.
    -- Actual palm positions include weapon-local markers and are checked by EquipmentGripValidation.
    assert(#pose.mainHand==3 and #pose.offHand==3,'Weapon origin and pose targets must be 3D vectors')
    -- Free/shared/shield handling is selected by the motion module, not by this legacy pose flag.
end
assert(snapshot.pose.mainHand[1]>0 and snapshot.pose.offHand[1]<0)
assert(snapshot.pose.weaponRotation[3]<0 and snapshot.pose.offWeaponRotation[3]>0,'Sword blades must incline outward on each side')
assert(snapshot.pose.moduleId==4,'Two equipped swords must select the dual-wield module')
print('PASS grip poses use character-relative arm chains and weapon-local markers; dual-wield module selected')
data.off=nil;data.main=nil;data.shield=shield;data.WearableCount=1
local before=stats:Get(actor,'defense');assert(before>=3)
snapshot=rules:ActorVisual(actor)
assert(snapshot.weapon==nil and snapshot.offhand==nil and #snapshot.wearables==1 and snapshot.wearables[1].asset.id==26)
local pawn=appearance:Template(1,snapshot)
for _,part in ipairs(pawn.parts) do assert(part.slot~='mainHand' and part.slot~='offHand' and part.slot~='head' and part.slot~='chest') end
assert(pawn.parts[1].id==19)
data.WearableCount=0;assert(stats:Get(actor,'defense')==before-3)
assert(rules:ActorVisual({Team=2})==nil)
print('PASS empty hands, shield-only appearance, armor replacement and shared attribute rules')
for _,row in ipairs(rules.items:All()) do
    if row.iconMode=='model' then
        assert(#row.iconRotation==3 and row.iconPadding>=1 and row.iconPadding<=2 and row.iconPath:match('%.png$'))
        local file=assert(io.open(rules.assets:Get(row.assetId).prefabPath,'rb'));assert(file:seek('end')>0);file:close()
    elseif row.iconMode=='none' then assert(row.iconPath=='')
    else assert(row.iconMode=='file') end
end
print('PASS all model-icon sources exist and render parameters are valid')
