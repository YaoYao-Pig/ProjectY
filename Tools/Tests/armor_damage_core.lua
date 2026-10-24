package.path='Lua/?.lua;'..package.path
local Armor=require('Game.Battle.ArmorDamage')
local function profile(p,a,f)return {skillGroup='weapon',armorPenetration=p,armorDamageMultiplier=a,fleshDamageMultiplier=f}end
local function split(durability,p,a,f,health,wear,absorbed,preserve)
    local actual,details=Armor.Split(100,durability,profile(p,a,f),preserve)
    assert(actual==health and details.damage==wear and math.abs(details.absorbed-absorbed)<0.00001)
    return details
end
split(100,30,1,1,30,70,70)
split(20,30,1,1,80,20,20)
split(20,30,2,1,90,20,10)
split(100,30,1,1.5,45,70,70)
split(0,30,1,1.5,150,0,0)
split(100,100,1,1,100,0,0)
split(100,30,0,1,30,0,70)
split(0,30,0,1,100,0,0)
split(100,30,1,1,100,0,0,true)
split(100,0,1,1,0,100,100)
local health,details=Armor.Split(17,3,profile(30,.4,1.3))
assert(health==12 and details.damage==3)
health,details=Armor.Split(1,10,profile(0,.1,1))
assert(health==0 and details.damage==1,'Positive armor damage must not round to permanent immunity')
assert(not pcall(function()Armor.Split(10,100,{armorPenetration=30})end),'A partial production profile must fail visibly')
print('PASS armor split: penetration, armor/flesh multipliers, no armor, overflow, preservation and integer rounding')

local rolls,legacyCalls,refreshes=0,0,0
local equipment={actors={}}
function equipment:Worn(id,slot)return assert(self.actors[id])[slot]end
local bridge={}
CS={ProjectY={Data={EquipmentCombatState=bridge,EquipmentConditionData={Of=function(item)return item.condition end},BodyHealth={}}}}
function bridge.DamageArmorAt(data,id,slot,amount)
    assert(slot=='head' or slot=='body')
    local item=assert(data:Worn(id,slot));local actual=math.min(item.condition.Current,amount)
    item.condition.Current=item.condition.Current-actual;return actual
end
function bridge.DamageArmor(_,_,amount)legacyCalls=legacyCalls+1;return amount end
function bridge.RefreshMaximum()refreshes=refreshes+1 end
local body=CS.ProjectY.Data.BodyHealth
function body.MaximumHP(target,index)return target.parts[index+1].maximum end
function body.HP(target,index)return target.parts[index+1].health end
function body.Permanent()return false end
function body.Hit(target,index,amount)
    target.lastPart=index;local applied=math.min(target.HP,amount)
    target.HP=target.HP-applied;target.parts[index+1].health=math.max(0,target.parts[index+1].health-applied)
    return applied
end
local InjuryRules=require('Game.Battle.InjuryRules')
local parts={}
for i,weight in ipairs({10,30,15,15,15,15})do parts[i]={index=i-1,weight=weight,name='part'..i}end
local injuries=setmetatable({parts=parts,settings={defaultInjuryTypeId=1}},InjuryRules)
local nextRoll=0
local function roll()rolls=rolls+1;return nextRoll end
local function actor(id,humanoid)
    local result={Id=id,HP=1200,MaxHP=1200,humanoid=humanoid,Effects={Count=0},parts={}}
    for i=1,6 do result.parts[i]={health=200,maximum=200}end
    function result:Damage(amount)
        if self.MountedAnimal then return self.MountedAnimal:Damage(amount)end
        local actual=math.min(amount,self.HP);self.HP=self.HP-actual;return actual
    end
    equipment.actors[id]={}
    for i,slot in ipairs({'head','body','offhand','pants','boots'})do
        equipment.actors[id][slot]={Id=id*10+i,ItemId=i,condition={Current=100}}
    end
    return result
end
local source=actor(1,true)
local stats={equipment={data=equipment},injuries=injuries,buffs={},
    Template=function(_,target)return {name='fixture',bodyInjuries=target.humanoid}end,
    MaximumHP=function(_,target)return target.MaxHP end,
    EffectVariables=function()return {defense=0,guard=0}end}
local effect={id=1,kind='damage',duration='instant',recipient='target',damageType='physical',damageColor='',
    equipmentDamage=9,killEquipmentDamage=10,injuryTypeId=0,requiredTags={},forbiddenTags={},chance=100,
    amount={Evaluate=function()return 40 end}}
local emitted
local runtime=require('Game.Battle.GameEffects').New(stats,{},function(kind,_,_,_,amount,_,_,impact)
    if kind=='damage' then emitted={amount=amount,impact=impact}end
end,{roll=roll})
local function hit(target,skill,amount,impact,periodic,attacker)
    runtime:Execute(effect,target,amount,1,'source','hit',attacker or source,true,impact,periodic,skill)
end
local target=actor(2,true)
local skill=profile(30,1,1)
hit(target,skill,100)
assert(target.HP==1170 and target.lastPart==0 and rolls==1)
assert(equipment:Worn(2,'head').condition.Current==30 and equipment:Worn(2,'body').condition.Current==100)
assert(equipment:Worn(2,'offhand').condition.Current==100 and emitted.impact.armor.slot=='head')
assert(emitted.impact.equipmentDamage==70 and legacyCalls==0 and refreshes==1)
nextRoll=50;target=actor(3,true);local before=rolls;hit(target,skill,100)
assert(target.lastPart==2 and rolls==before+1 and emitted.impact.armor.slot=='body')
assert(equipment:Worn(3,'body').condition.Current==30 and equipment:Worn(3,'head').condition.Current==100)
assert(equipment:Worn(3,'offhand').condition.Current==100 and equipment:Worn(3,'pants').condition.Current==100)
target=actor(4,true);before=rolls;hit(target,profile(0,1,1),100)
assert(target.HP==1200 and target.lastPart==nil and rolls==before+1 and equipment:Worn(4,'body').condition.Current==0)
target=actor(5,true);skill.preserveArmor=true;hit(target,skill,100)
assert(target.HP==1100 and equipment:Worn(5,'body').condition.Current==100 and emitted.impact.armor.preserved)
skill.preserveArmor=false;target=actor(6,true);hit(target,skill,100,{professionContext={preserveArmor=true}})
assert(target.HP==1100 and equipment:Worn(6,'body').condition.Current==100 and emitted.impact.armor.preserved)
target=actor(17,true);before=rolls;hit(target,skill,100);hit(target,skill,100)
assert(target.HP==1100 and equipment:Worn(17,'body').condition.Current==0 and rolls==before+2)
hit(target,skill,100)
assert(target.HP==1000 and emitted.impact.armor.damage==0,'Following shots must use depleted armor and cannot reapply old fixed wear')
print('PASS head/body selection is shared with injuries; shield/clothing untouched; full absorption and preservation bypass fixed wear')

target=actor(7,false);before=rolls;hit(target,profile(30,1,1.5),100)
assert(target.HP==1050 and rolls==before and emitted.impact.armor.slot==nil and equipment:Worn(7,'body').condition.Current==100)
local rider=actor(8,true);local mount=actor(9,false);rider.MountedAnimal=mount
hit(rider,profile(30,1,1.5),100)
assert(rider.HP==1200 and mount.HP==1050 and rolls==before and equipment:Worn(8,'body').condition.Current==100)
assert(emitted.impact.hpBefore==1200 and emitted.impact.hpAfter==1050)
target=actor(10,true);hit(target,nil,20)
assert(legacyCalls==1 and emitted.impact.armor==nil and target.HP==1180)
local spell=profile(30,1,3);spell.skillGroup='spell';target=actor(11,true);hit(target,spell,20)
assert(legacyCalls==2 and emitted.impact.armor==nil and target.HP==1180)
target=actor(12,true);hit(target,skill,20,nil,true)
assert(legacyCalls==3 and emitted.impact.armor==nil and target.HP==1180)
target=actor(13,true);hit(target,skill,20,nil,false,target)
assert(legacyCalls==4 and emitted.impact.armor==nil and target.HP==1180)
target=actor(14,true);hit(target,skill,20,{damageType='fire'})
assert(legacyCalls==5 and emitted.impact.armor==nil and target.HP==1180)
print('PASS non-body and mounted recipients take flesh damage without rider armor; legacy, spell, periodic and self damage remain separate')

target=actor(15,true);skill=profile(30,1,1);skill.damageScale=1;skill.criticalMultiplier=2;skill.name='fixture'
runtime.professions={Mitigate=function(_,_,amount)return amount-10 end}
runtime.definitions={Get=function(_,id)assert(id==1);return effect end}
local plan=runtime:Prepare(1,source,target,skill,1)
before=rolls;assert(runtime:ApplyPrepared(plan,{critical=true}))
assert(target.HP==1179 and equipment:Worn(15,'body').condition.Current==51 and rolls==before+1)
assert(emitted.impact.critical and emitted.impact.armor.damage==49 and legacyCalls==5)
runtime.professions=nil
runtime.damageLimit=function(recipient,amount)return math.min(recipient.HP-1,amount)end
target=actor(16,false);target.HP=35;hit(target,profile(30,1,3),100)
assert(target.HP==1 and emitted.amount==34,'Final flesh multipliers must respect nonlethal duel limits')
print('PASS prepared critical/mitigation settlement precedes armor splitting, and final flesh damage respects nonlethal limits')
