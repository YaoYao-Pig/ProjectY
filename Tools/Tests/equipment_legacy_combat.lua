-- Real equipment skill resolution and GameEffects execution; C# ownership is represented by isolated fixtures.
package.path='Lua/?.lua;'..package.path
local function tableOf(rows)
    local byId={};for _,row in ipairs(rows)do byId[row.id]=row end
    return {All=function()return rows end,Get=function(_,id)return assert(byId[id],'Missing fixture row '..tostring(id))end,Find=function(_,id)return byId[id]end}
end
local function legacy(forged)
    local value={Forged=forged,PathId=0,WishState=0,deeds={},DeedCount=0}
    function value:RecordDeed(rule,actor,target,site,minutes)
        for _,old in ipairs(self.deeds)do if old.RuleId==rule and old.TargetId==target then return false end end
        self.deeds[#self.deeds+1]={RuleId=rule,ActorId=actor,TargetId=target,SiteId=site,Minutes=minutes};self.DeedCount=#self.deeds;return true
    end
    function value:FulfillWish()if self.WishState~=1 then return false end;self.WishState=2;return true end
    return value
end
local function evidence()
    local data={}
    function data:Reset()self.entries={};self.Count=0;self.Active=false;self.wishes={};self.defeated={}end
    function data:Begin()self:Reset();self.Active=true end
    function data:AdmitWish(weapon)if self.Active and weapon.legacy.WishState==1 then self.wishes[weapon]=true end end
    function data:IsWishEligible(weapon)return self.wishes[weapon]==true end
    function data:Record(weapon,actor,target,legend,wish)
        if not self.Active then return false end
        for _,row in ipairs(self.entries)do if row.Weapon==weapon and row.Actor==actor and row.Target==target then return false end end
        self.entries[#self.entries+1]={Weapon=weapon,Actor=actor,Target=target,LegendaryTargetId=legend,WishEligible=wish};self.Count=#self.entries;return true
    end
    function data:GetAt(i)return self.entries[i+1]end
    function data:MarkDefeated(target)if self.Active and target.HP==0 then self.defeated[target]=true end end
    function data:WasDefeated(target)return self.defeated[target]==true end
    function data:Finish()if not self.Active then return false end;self.Active=false;return true end
    data:Reset();return data
end
CS={ProjectY={Data={EquipmentLegacyData={Of=function(weapon)return weapon.legacy end},
    EquipmentConditionData={Of=function(weapon)return weapon.condition end},
    EquipmentLegacyBattleData={For=function(adventure)return adventure.evidence end}}}}
local Rules=require('Game.Equipment.EquipmentRules')
local Effects=require('Game.Battle.GameEffects')
local Combat=require('Game.Equipment.EquipmentLegacyCombat')
local function actor(id,template,team)
    local value={Id=id,TemplateId=template,Team=team,HP=500,MaxHP=500,AnimalOwnerId=0,Guard=0,TraitCount=0,Effects={Count=0}}
    function value:Damage(amount)local actual=math.min(self.HP,amount);self.HP=self.HP-actual;return actual end
    function value:SetGuard(amount)self.Guard=math.max(self.Guard,amount)end
    return value
end
local function fixture()
    local paths=tableOf({{id=1,damageBonus=.1,guardValue=0,wishDamageBonus=.05},{id=2,damageBonus=0,guardValue=2,wishDamageBonus=.05}})
    local recipe={id=1,weaponIds={101,40},damageBonus=.2}
    local definitions={EquipmentForgeTable=tableOf({recipe}),EquipmentDeedTable=tableOf({{id=1,kind='legendary_kill',targetIds={701}}}),
        EquipmentLegacyPathTable=paths,LegendaryEncounterTable=tableOf({{id=11,npcId=101}}),NpcTable=tableOf({{id=101,actorTemplateId=701}})}
    local config={GetTable=function(_,name)return assert(definitions[name],name)end}
    local first,second,finisher=actor(1,1,1),actor(2,1,1),actor(3,1,1)
    local enemy,copy,ordinary=actor(1001,701,2),actor(1002,701,2),actor(1003,3,2)
    local participants={first,second,finisher};local units={first,second,finisher,enemy,copy,ordinary}
    local one={Id=1,ItemId=101,legacy=legacy(true),condition={Broken=false,Efficiency=1}}
    local two={Id=2,ItemId=40,legacy=legacy(true),condition={Broken=false,Efficiency=1}}
    local spare={Id=3,ItemId=101,legacy=legacy(true),condition={Broken=false,Efficiency=1}}
    local plain={Id=4,ItemId=101,legacy=legacy(false),condition={Broken=false,Efficiency=1}}
    local worn={[1]=one,[2]=two,[3]=plain};local off={}
    local weaponList={one,two,spare,plain}
    local itemData={Equipped=function(_,id)return worn[id]end,Offhand=function(_,id)return off[id]end,
        WeaponCount=#weaponList,GetWeaponAt=function(_,index)return weaponList[index+1]end,Worn=function()end}
    local base={id=1,name='attack',action='main',cost=1,range=1,minRange=0,target='enemy',effectIds={1},skillGroup='weapon',
        damageScale=1,hitChance=100,criticalChance=0,criticalMultiplier=2,cooldownTurns=0,shots=1,ammoPerShot=0,actionTemplate=0,
        catalystKind='none',skillKind='attack',maxTargets=1,splashRadius=0,weaponWear=1}
    local spell={};for k,v in pairs(base)do spell[k]=v end;spell.id=2;spell.skillGroup='arcane'
    local secondary={};for k,v in pairs(base)do secondary[k]=v end;secondary.id=3;secondary.action='secondary'
    local damage={id=1,kind='damage',duration='instant',damageType='physical',damageColor='',equipmentDamage=0,killEquipmentDamage=0}
    local weapons=tableOf({{id=101,skillIds={1},offhandSkillId=3,damageMultiplier=1,onHitEffectIds={},socketIds={},armorPenetration=100,armorDamageMultiplier=0},
        {id=40,skillIds={1},offhandSkillId=3,damageMultiplier=1,onHitEffectIds={},socketIds={},armorPenetration=100,armorDamageMultiplier=0}})
    local equipment=setmetatable({data=itemData,weapons=weapons,skills=tableOf({base,spell,secondary}),effects=tableOf({damage}),
        affixes={Of=function()return {damageMultiplier=1,hitBonus=0}end},forge={Recipe=function()return recipe end,paths=paths},
        Requirements=function()return {damageScale=1,hitLoss=0}end},Rules)
    local stats={equipment=equipment,buffs={},Template=function(self,target)return {name='fixture',bodyInjuries=self.armored==target}end,
        MaximumHP=function(_,target)return target.MaxHP end,injuries={SelectHit=function()return {part={index=0}}end,
            DamageHit=function(_,source,target,row,amount)return target:Damage(amount)end}}
    CS.ProjectY.Data.EquipmentCombatState={RefreshMaximum=function()end,DamageArmorAt=function(data,id,slot,amount)
        local item=data:Worn(id,slot);item.condition.Current=item.condition.Current-amount;return amount end}
    local battle={stats=stats,data={Phase='combat',Round=1},Changed=require('Core.Signal')(function(message)error(message)end),
        Units=function()return units end,FindUnit=function(_,id)for _,unit in ipairs(units)do if unit.Id==id then return unit end end end,
        IsHostile=function(_,a,b)local left=type(a)=='number' and a or a.Team;local right=type(b)=='number' and b or b.Team;return left~=right and left~=0 and right~=0 and left~=4 and right~=4 end}
    local data={PartyCount=#participants,SiteId=12,evidence=evidence(),GetPartyAt=function(_,i)return participants[i+1]end}
    local party={DefinitionId=11,MemberCount=1,GetMemberAt=function()return enemy end}
    local adventure={data=data,battle=battle,config=config,narrative={data={Minutes=4321}},parties={data={Count=1,GetAt=function()return party end}}}
    local effects=Effects.New(stats,tableOf({damage}),function()end);battle.gameEffects=effects
    local combat=Combat.New(adventure);combat:Start()
    local function start()battle.data.Phase='combat';battle.Changed:Emit({kind='battle_started'})end
    local function skill(source,id)return equipment:Skill(source,id or 1,stats)end
    local function hit(source,target,action,amount,periodic,attackHit)
        local value=math.floor((amount or 10)*(action and action.damageScale or 1)+0.000000001)
        effects:Execute(damage,target,value,source and source.Id or 1,'fixture','fixture',source,attackHit~=false,
            nil,periodic==true,action)
    end
    start()
    return {combat=combat,battle=battle,first=first,second=second,finisher=finisher,enemy=enemy,copy=copy,ordinary=ordinary,
        one=one,two=two,spare=spare,plain=plain,worn=worn,off=off,skill=skill,hit=hit,start=start,data=data,effects=effects,damage=damage,stats=stats,itemData=itemData}
end
local f=fixture()
assert(f.skill(f.first).weaponInstance==f.one and f.skill(f.first).damageScale==1.2)
f.one.legacy.WishState=2;f.one.legacy.PathId=1
assert(f.skill(f.first).damageScale==1.25,'Completed wish must increase the actual weapon skill')
f.hit(f.first,f.enemy,f.skill(f.first),100);assert(f.enemy.HP==363,'Hunter must multiply the real damage against the named world individual')
f.hit(f.first,f.copy,f.skill(f.first),100);assert(f.copy.HP==375,'A copied legendary template is not the named legend')
local spell=f.skill(f.first,2);assert(not spell.weaponInstance and spell.damageScale==1,'Holding a sword must not empower unrelated magic')
f.one.condition.Broken=true;local broken=f.skill(f.first);assert(not broken.weaponInstance and broken.damageScale==1,'Already broken equipment has no legacy bonus')
f.one.condition.Broken=false;f.off[1]=f.two
assert(f.skill(f.first,3).weaponInstance==f.two,'Secondary attack must retain the actual offhand item')

f=fixture();f.hit(f.first,f.enemy,f.skill(f.first));f.hit(f.second,f.enemy,f.skill(f.second))
local original=f.one;f.worn[1]=f.spare -- The used physical item may now lie on the ground.
f.hit(f.finisher,f.enemy,f.skill(f.finisher),1000)
assert(f.combat:Settle('victory','fixture') and not f.combat:Settle('victory','fixture'))
assert(original.legacy.DeedCount==1 and f.two.legacy.DeedCount==1 and f.spare.legacy.DeedCount==0,'Every contributing physical item earns its own deed without a last-hit requirement')
local deed=original.legacy.deeds[1];assert(deed.ActorId==1 and deed.TargetId==701 and deed.SiteId==12 and deed.Minutes==4321)

for _,kind in ipairs({'copy','neutral','allied','friendly','periodic','non_attack','zero','backpack','deployment','tamed','gm','third_party','defeat','draw','alive'})do
    f=fixture();local target=f.enemy;local action=f.skill(f.first)
    if kind=='copy' then target=f.copy elseif kind=='neutral' then target.Team=0 elseif kind=='allied' then target.Team=4
    elseif kind=='friendly' then target.Team=1 elseif kind=='backpack' then action=f.skill(f.finisher)
    elseif kind=='deployment' then f.battle.data.Phase='deployment' elseif kind=='tamed' then target.AnimalOwnerId=1 end
    f.hit(f.first,target,action,kind=='zero' and 0 or 10,kind=='periodic',kind~='non_attack')
    if kind=='gm' then
        target:Damage(target.HP)
        f.effects:Notify('damage','GM fixture',0,target,500,false,{hpBefore=500,hpAfter=0})
    elseif kind=='third_party' then f.finisher.Team=3;f.hit(f.finisher,target,f.skill(f.finisher),1000)
    elseif kind~='alive' then f.hit(f.finisher,target,f.skill(f.finisher),1000)end
    f.combat:Settle((kind=='defeat' or kind=='draw') and kind or 'victory','fixture')
    assert(f.one.legacy.DeedCount==0,'Invalid contribution or outcome counted: '..kind)
end

f=fixture();local armor={condition={Current=100}};f.stats.armored=f.enemy
f.itemData.Worn=function(_,id,slot)if id==f.enemy.Id and slot=='head' then return armor end end
local armorAction=f.skill(f.first);armorAction.armorPenetration=0;armorAction.armorDamageMultiplier=1
f.hit(f.first,f.enemy,armorAction,10);assert(f.enemy.HP==500 and armor.condition.Current==88,'Actual armor loss must be observed without inventing health loss')
f.hit(f.finisher,f.enemy,f.skill(f.finisher),1000);f.combat:Settle('victory','fixture')
assert(f.one.legacy.DeedCount==1,'A real direct armor hit is a valid contribution')

f=fixture();local finalAction=f.skill(f.first);f.one.condition.Broken=true;f.hit(f.first,f.enemy,finalAction,1000)
f.combat:Settle('victory','fixture');assert(f.one.legacy.DeedCount==1,'A legal final use remains owned by the weapon when use wear breaks it')

for _,kind in ipairs({'success','dead_holder','switched','late_accept','no_contribution','defeat','periodic'})do
    f=fixture();f.one.legacy.PathId=1;f.one.legacy.WishState=kind=='late_accept' and 0 or 1;f.start()
    if kind=='late_accept' then f.one.legacy.WishState=1 end
    if kind~='no_contribution' then f.hit(f.first,f.ordinary,f.skill(f.first),10,kind=='periodic')end
    if kind=='dead_holder' then f.first.HP=0 elseif kind=='switched' then f.worn[1]=f.spare end
    f.combat:Settle(kind=='defeat' and 'defeat' or 'victory','fixture')
    assert(f.one.legacy.WishState==(kind=='success' and 2 or 1),'Invalid spirit wish outcome: '..kind)
end

f=fixture();f.one.legacy.PathId=1;f.one.legacy.WishState=1;f.worn[1]=f.plain;f.start();f.worn[1]=f.one
f.hit(f.first,f.ordinary,f.skill(f.first));f.combat:Settle('victory','fixture')
assert(f.one.legacy.WishState==2,'A wish accepted before combat can be fulfilled after genuinely using a weapon equipped during combat')

f=fixture();f.one.legacy.PathId=2;f.combat:BeginTurn(f.first);assert(f.first.Guard==2)
f.two.legacy.PathId=1;f.off[1]=f.two;f.combat:BeginTurn(f.first);assert(f.first.Guard==2,'A hunter offhand must not clear the guardian opening guard')
f.first.Guard=0;f.battle.data.Round=2;f.combat:BeginTurn(f.first);assert(f.first.Guard==0,'Guardian is an opening benefit, not every round')
f.battle.data.Round=1;f.one.condition.Broken=true;f.combat:BeginTurn(f.first);assert(f.first.Guard==0,'Broken guardian weapon gives no guard')
f.one.condition.Broken=false;f.worn[1]=f.plain;f.combat:BeginTurn(f.first);assert(f.first.Guard==0,'Backpack guardian weapon gives no guard')
f.combat:Dispose();assert(not f.battle.legacyCombat and not f.effects.legacyCombat and not f.data.evidence.Active and #f.battle.Changed.listeners==0)
print('PASS legacy combat: actual weapon identity, real legendary identity, contribution and death attribution, multipliers, wishes, guardian and lifecycle')
