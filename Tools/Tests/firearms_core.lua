-- Deterministic shot/critical/effect coverage with real exported content and production resolvers.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local f=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local bytes=f:read('*a');f:close();return bytes
end}})
local function copy(row)local result={};for k,v in pairs(row)do result[k]=v end;return result end
local weaponFactory=assert(loadfile('Tools/Tests/equipment_read_fixture.lua'))()
local actor={Id=1,TemplateId=3,Team=1,TraitCount=0,HP=1000,MaxHP=1000}
local inventory={main=nil,WearableCount=0,Equipped=function(self)return self.main end,Offhand=function()end,Worn=function()end}
local rules=require('Game.Equipment.EquipmentRules').New(config,inventory)
local attributes={Get=function()return 30 end}
local itemIds={800,801,802,803,804,805,810,811,812,813,814,815,816,817,818,819,820,821}
for _,id in ipairs(itemIds)do
    assert(config:GetTable('EquipmentItemTable'):Get(id).iconMode=='model')
    assert(config:GetTable('WorldTradePriceTable'):Get(id).price>0)
    assert(config:GetTable('ShopEntryTable'):Get(id).itemId==id)
end
for id=800,805 do
    local weapon=weaponFactory(1,id,actor.Id);inventory.main=weapon
    local definition=rules.weapons:Get(id);assert(#definition.socketIds==4)
    for _,sid in ipairs(definition.skillIds)do
        local skill=rules:Skill(actor,sid,attributes)
        assert(skill.criticalChance>=0 and skill.criticalChance<=100)
        if sid~=9 then assert(skill.actionTemplate>0 and skill.trajectory=='direct')end
    end
    local mag=rules.magazines:Get(definition.magazineItemId)
    assert(mag.spawnRounds==mag.capacity and (mag.id==21 or config:GetTable('ShopEntryTable'):Get(mag.id).chance==100))
end
inventory.main=weaponFactory(1,800,actor.Id)
local precise=rules:Skill(actor,7,attributes);local burst=rules:Skill(actor,8,attributes)
assert(precise.hitChance>burst.hitChance and precise.criticalChance>burst.criticalChance)
local function expected(skill)
    return skill.shots*skill.hitChance/100*skill.damageScale*(1+skill.criticalChance/100*(skill.criticalMultiplier-1))
end
assert(expected(burst)>expected(precise) and burst.shots*burst.ammoPerShot==3 and precise.ammoPerShot==1)
local base=rules.skills:Get(7)
inventory.main.GetRune=function(_,socket)return rules.sockets:Get(socket).kind=='rail' and 813 or 0 end
local scoped=rules:Skill(actor,7,attributes)
assert(scoped.hitChance==100 and scoped.criticalChance==45 and base.criticalChance==35)
assert(rules:Skill(actor,9,attributes).criticalChance==0,'Reload must not inherit firearm modifiers')
local synergy=require('Game.Equipment.SkillSynergies').New(config)
assert(synergy:Applies(config:GetTable('SkillSynergyTable'):Get(813),base))

local Shots=require('Game.Battle.ProjectileCombat')
local effectsTable=config:GetTable('CombatEffectTable');local definitions={}
-- Real instruction defaults; simple amounts isolate critical and proc semantics from body injuries.
local damage=copy(effectsTable:Get(1212));damage.equipmentDamage=0;damage.injuryTypeId=0
local proc=copy(damage);proc.id=9901;proc.chance=35
local heal=copy(damage);heal.id=9902;heal.kind='heal';heal.recipient='source'
local rows={[1212]=damage,[9901]=proc,[9902]=heal}
function definitions:Get(id)return assert(rows[id])end
local stats={equipment={data=inventory},buffs={Find=function()end},Template=function(_,unit)return {name='Unit '..unit.Id,bodyInjuries=false}end,
    EffectVariables=function()return {strength=10,proficiency=4,defense=0,guard=0}end}
local events,values,cursor={}, {},0
local function roll()cursor=cursor+1;return assert(values[cursor],'Unexpected random draw '..cursor)end
local effects=require('Game.Battle.GameEffects').New(stats,definitions,function(kind,_,_,_,amount,_,_,impact)
    events[#events+1]={kind=kind,amount=amount,impact=impact}
end,{roll=roll})
local function unit(id)
    local u={Id=id,HP=1000,MaxHP=1000,Effects={Count=0},Q=id,R=0}
    function u:Damage(amount)self.HP=self.HP-amount;return amount end
    function u:Heal(amount)self.HP=self.HP+amount;return amount end
    return u
end
local source,target=unit(1),unit(2)
local battle={stats=stats,gameEffects=effects,data={RollPercent=roll},board={},Emit=function()end}
local skill=copy(base);skill.trajectory='sight';skill.effectIds={1212,9901,9902};skill.damageScale=1
local function program()
    local p={};for _,id in ipairs(skill.effectIds)do p[#p+1]=effects:Prepare(id,source,target,skill)end
    return Shots.PrepareProgram(battle,source,skill,p)
end
local function reset(sequence)
    values=sequence;cursor=0;events={};target.HP=1000;source.HP=1000
end
reset({0,0,0});Shots.ApplyProgram(battle,source,skill,program(),1)
assert(cursor==3 and target.HP==984 and source.HP==1004,'One hit and one crit draw; both damage instructions double, healing does not')
assert(events[1].impact.critical and events[2].impact.critical and not events[3].impact.critical)
reset({99});Shots.ApplyProgram(battle,source,skill,program(),1)
assert(cursor==1 and #events==0 and target.HP==1000,'A miss must not roll crit, proc or heal')
skill=copy(burst);skill.trajectory='sight';skill.effectIds={1212,9901};skill.damageScale=1
reset({0,99,0, 0,0,99, 99})
local p=program();for shot=1,3 do Shots.ApplyProgram(battle,source,skill,p,shot)end
assert(cursor==7 and target.HP==984 and #events==3,'Three shots independently hit, crit and trigger effects')
assert(not events[1].impact.critical and not events[2].impact.critical and events[3].impact.critical)
assert(events[1].impact.shot==1 and events[3].impact.shot==2)
assert(p[1].amount==4,'Critical application must not mutate prepared effects reused by later shots')
skill.criticalChance=0;skill.hitChance=100;skill.effectIds={1212}
reset({});Shots.ApplyProgram(battle,source,skill,program(),1)
assert(cursor==0 and target.HP==996,'Zero crit preserves existing deterministic actions without an extra draw')
skill.criticalChance=100
reset({});Shots.ApplyProgram(battle,source,skill,program(),1)
assert(cursor==0 and target.HP==992,'Guaranteed crit needs no probability draw')
local periodic=copy(damage);periodic.id=9903;rows[9903]=periodic
reset({});effects:ApplyPrepared(effects:Prepare(9903,source,target,skill),{shot=1,critical=true},true)
assert(target.HP==996 and not events[1].impact.critical,'Periodic effects never inherit crit scaling')
print('PASS 18 items, 6 weapon resolvers, magazine links, scope/caps, expected damage, independent hits/crits/procs, healing/periodic exclusions and shared-plan immutability')
