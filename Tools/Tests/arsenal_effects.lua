-- Focused arsenal rules: real config/formulas/executors; isolated C# data-interface fixtures only.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local f=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=f:read('*a');f:close();return bytes
end}})
local function copy(row)local result={};for k,v in pairs(row)do result[k]=v end;return result end
local function collection()
    local c={rows={},Count=0,next=1,Revision=0}
    function c:GetAt(i)return assert(self.rows[i+1])end
    function c:Find(id)for _,r in ipairs(self.rows)do if r.EffectId==id then return r end end end
    function c:ById(id)for _,r in ipairs(self.rows)do if r.Id==id then return r end end;error('Missing fixture instance')end
    function c:Add(id,source,name,amount,duration)
        local r={Id=self.next,EffectId=id,SourceId=source,SourceName=name,Amount=amount,Remaining=duration,Elapsed=0,Stacks=1}
        self.next=self.next+1;self.rows[#self.rows+1]=r;self.Count=#self.rows;self.Revision=self.Revision+1;return r
    end
    function c:Refresh(id,source,name,amount,duration,max,stack)
        local r=self:ById(id);r.SourceId=source;r.SourceName=name;r.Amount=amount;r.Remaining=duration;r.Elapsed=0
        r.Stacks=stack and math.min(max,r.Stacks+1) or 1;self.Revision=self.Revision+1
    end
    function c:Advance(id,period)local r=self:ById(id);r.Elapsed=period>0 and (r.Elapsed+1)%period or 0;if r.Remaining>0 then r.Remaining=r.Remaining-1 end;self.Revision=self.Revision+1 end
    function c:Remove(id)for i,r in ipairs(self.rows)do if r.Id==id then table.remove(self.rows,i);self.Count=#self.rows;self.Revision=self.Revision+1;return end end;error('Missing fixture removal')end
    return c
end
local snapshots={}
function snapshots.Configure(row,ids,amounts,expiry,nextTick)row.ids={table.unpack(ids)};row.amounts={table.unpack(amounts)};row.expiry=expiry;row.nextTick=nextTick end
function snapshots.Amount(row,id)for i,value in ipairs(row.ids)do if value==id then return row.amounts[i]end end;error('Missing fixture snapshot')end
function snapshots.Count(row)return #row.ids end
function snapshots.EffectAt(row,i)return row.ids[i+1]end
function snapshots.ExpiresAt(row)return row.expiry end
function snapshots.NextTickAt(row)return row.nextTick end
function snapshots.AdvanceTick(row,period)row.nextTick=row.nextTick+period end
local wear={}
CS={ProjectY={Data={GameBuffState=snapshots,
    EquipmentCombatState={DamageArmor=function(_,id,amount)wear[id]=(wear[id] or 0)+amount end,RefreshMaximum=function()end},
    EquipmentConditionData={Of=function(item)return assert(item.condition)end},
    EquipmentAffixData={Of=function(item)return assert(item.affixId)end}}}}
local stats=require('Game.Battle.CombatStats')(config)
local EmptyGrowth=assert(loadfile('Tools/Tests/growth_empty.lua'))()
local function actor(id,hp)
    local a={Id=id,TemplateId=1,Team=1,AnimalSpeciesId=0,Q=id,R=0,TraitCount=0,Effects=collection(),Growth=EmptyGrowth(),HP=hp or 100,MaxHP=100,Guard=0}
    function a:Damage(amount)local actual=math.min(self.HP,amount);self.HP=self.HP-actual;return actual end
    function a:Heal(amount)if self.HP==0 then return 0 end;local actual=math.min(self.MaxHP-self.HP,amount);self.HP=self.HP+actual;return actual end
    function a:SetGuard(amount)self.Guard=amount end
    function a:SetMaxHP(value)self.HP=self.HP==0 and 0 or math.max(1,math.min(value,self.HP+value-self.MaxHP));self.MaxHP=value end
    return a
end
local events,rolls,random={},{},0
local definitions=config:GetTable('CombatEffectTable')
local effects=require('Game.Battle.GameEffects').New(stats,definitions,function(kind,_,source,target,amount,_,_,impact)
    events[#events+1]={kind=kind,source=source,target=target,amount=amount,impact=impact}
end,{roll=function()return random end,minutes=function()return 0 end})
effects:Validate()
local Battle=require('Game.Battle.BattleSystem')
local battle=setmetatable({gameEffects=effects,stats=stats,board={},data={RollPercent=function()rolls[#rolls+1]=random;return random end},
    Emit=function(_,kind)events[#events+1]={kind=kind}end},{__index=Battle})
-- This executor fixture has an open ray; interception geometry has its own targeted checks.
function battle.board:Find(q,r)return {q=q,r=r,layer=0}end
function battle:ShotOccupancy()return {}end
local function skill(id,ids)
    local s=copy(config:GetTable('CombatSkillTable'):Get(id));s.damageScale=1;s.hitChance=50
    if ids then s.effectIds=ids end;return s
end
local function prepare(s,source,target)
    local plans={};for _,id in ipairs(s.effectIds)do plans[#plans+1]=effects:Prepare(id,source,target,s,0)end;return plans
end
local function cast(s,source,target,shot)battle:ApplyEffectProgram(source,s,prepare(s,source,target),shot or 1)end
local source,target=actor(1,20),actor(2)
effects:Apply(803,source,source)
local attack=skill(1608,{1319,1320,1315,1322,1321})
local program=prepare(attack,source,target)
local before=#events;random=99;battle:ApplyEffectProgram(source,attack,program,1)
assert(source.HP==20 and source.Guard==0 and source.Effects:Find(10003) and target.HP==100 and target.Effects.Count==0)
assert(#rolls==1 and #events==before+1 and events[#events].kind=='miss','One missed victim must gate every source/target instruction')
random=0;battle:ApplyEffectProgram(source,attack,program,2)
assert(source.HP==24 and source.Guard==3 and not source.Effects:Find(10003) and target.HP<100 and target.Effects:Find(10002))
assert(#rolls==2,'Damage, heal, guard, dispel and buff share one attack accuracy roll per victim/shot')
print('PASS original-victim hit gates source heal/guard/cleanse and target status; one accuracy roll')

source,target=actor(3,10),actor(4,1);attack=skill(1608,{1319,1320});random=0
program=prepare(attack,source,target);battle:ApplyEffectProgram(source,attack,program,1)
assert(target.HP==0 and source.HP==14,'A killing hit may complete the same shot source reward')
local rollCount=#rolls;battle:ApplyEffectProgram(source,attack,program,2)
assert(source.HP==14 and #rolls==rollCount,'Later shots cannot farm the dead original victim')
assert(not effects:Apply(1311,source,target) and target.HP==0,'Ordinary healing must never resurrect')
source,target=actor(5,10),actor(6)
local damage=target.Damage;function target:Damage(amount)local dealt=damage(self,amount);source.HP=0;return dealt end
cast(attack,source,target);assert(source.HP==0,'A source killed during the program cannot run later self-healing')
print('PASS killing-hit reward completes once; corpse farming and resurrection are blocked; dead source stops')

source,target=actor(7,20),actor(8)
local conditional=effects:Prepare(1303,source,target)
effects:Apply(1302,source,target);local hp=target.HP;effects:ApplyPrepared(conditional)
assert(target.HP<hp,'Conditions must inspect status at execution, not preparation')
effects:Apply(1304,source,target);hp=target.HP;effects:ApplyPrepared(conditional);assert(target.HP==hp)
effects:Apply(802,source,target);effects:Apply(803,source,target)
local harvest=skill(1615,{1358,1333,1358});cast(harvest,source,target)
assert(source.HP==24 and not target.Effects:Find(10002) and target.Effects:Find(10003),'Bleeding is consumed in order; later reward must see removal')
local forbidden=copy(definitions:Get(1303));forbidden.id=99001;forbidden.requiredTags={};forbidden.forbiddenTags={'wet'}
local filtered=setmetatable({Get=function(_,id)return id==99001 and forbidden or definitions:Get(id)end},{__index=definitions})
local oldDefinitions=effects.definitions;effects.definitions=filtered
hp=target.HP;effects:Apply(99001,source,target);assert(target.HP<hp)
effects:Apply(1302,source,target);hp=target.HP;effects:Apply(99001,source,target);assert(target.HP==hp)
effects.definitions=oldDefinitions
print('PASS live required/forbidden tags and ordered one-time status consumption')

source,target=actor(9,20),actor(10)
effects:Apply(801,source,target);effects:Apply(803,source,target);effects:Apply(806,source,target)
effects:Apply(1310,source,target)
assert(target.Effects:Find(10001) and not target.Effects:Find(10003) and not target.Effects:Find(10006),'Cleanse removes debuff/control and preserves regeneration')
effects:Apply(803,source,target);random=99;effects:Apply(1352,source,target)
assert(target.Effects:Find(10001),'Failed 50 percent dispel must preserve boon')
random=0;effects:Apply(1352,source,target)
assert(not target.Effects:Find(10001) and target.Effects:Find(10003),'Dispel boon must preserve poison')
print('PASS distinct cleanse/dispel categories and independent proc chance')

source,target=actor(11,81),actor(12,85)
attack=skill(1606,{1357,1357});cast(attack,source,target)
assert(target.HP==82,'Missing-health damage must refresh between two instructions: 1 then 2')
local healthPlan=effects:Prepare(1353,source,target);assert(healthPlan.amount==0)
source.HP=40;effects:Apply(1320,source,target);hp=target.HP;effects:ApplyPrepared(healthPlan)
assert(source.HP==44 and target.HP==hp-2,'Source percent damage must refresh after healing')
local values=require('Game.Battle.EffectInstructions').Values(stats,source,target,nil,0)
assert(values.sourceMissingHealth==56 and values.targetMissingHealth==100-target.HP and values.sourceHealthPercent==44 and values.targetHealthPercent==target.HP)
local reader={U16=function()return 1 end,U8=function()return 2 end,String=function()return 'targetHealthPercent' end}
local formula=require('Config.Formula').Read(reader,{'targetHealthPercent'})
assert(formula:Evaluate(values)==target.HP,'The real closed formula interpreter must resolve lazy health variables')
local noHealth=setmetatable({},{__index=function(_,name)if name=='HP' or name=='MaxHP' then error('Unneeded HP read')end end})
local lazy=require('Game.Battle.EffectInstructions').Values({EffectVariables=function()return{}end},noHealth,noHealth,nil,0)
assert(definitions:Get(1350).amount:Evaluate(lazy)==2,'Old constant formulas must remain usable with no-HP query actors')
print('PASS dynamic target/source health, real lazy formula evaluation, and no-HP legacy queries')

source,target=actor(13),actor(14,85)
local originalBuff=stats.buffs.rows[10002];local dynamicBuff=copy(originalBuff)
dynamicBuff.periodicEffectIds={1357};dynamicBuff.componentIds={1357};stats.buffs.rows[10002]=dynamicBuff
local pending=effects:Prepare(802,source,target);assert(pending.amounts[1]==1)
target.HP=76;effects:ApplyPrepared(pending)
assert(snapshots.Amount(target.Effects:Find(10002),1357)==3,'Persistent components snapshot on successful application')
target.HP=20;effects:TickActor(target,'turn_end');assert(target.HP==17,'Periodic ticks keep the saved snapshot')
stats.buffs.rows[10002]=originalBuff
print('PASS Buff application refreshes its snapshot; subsequent periodic damage does not recalculate')

local items,weaponRows,runes=config:GetTable('EquipmentItemTable'),config:GetTable('EquipmentWeaponTable'),config:GetTable('EquipmentRuneTable')
local function weapon(id,itemId,installed)
    return {Id=id,ItemId=itemId,OwnerActorId=31,Hand='weapon',MagazineId=0,affixId=1,
        condition={Current=100,Maximum=100,BaseMaximum=100,Broken=false,Efficiency=1},GetRune=function(_,slot)return installed and installed[slot] or 0 end}
end
local equipment={WearableCount=0,Revision=17}
function equipment:Equipped()return self.main end
function equipment:Offhand()return self.off end
function equipment:Worn()end
local equippedStats=require('Game.Battle.CombatStats')(config,equipment)
local rules=equippedStats.equipment
local previewActor={Id=31,Team=1,TemplateId=1,AnimalSpeciesId=0,TraitCount=0,Effects={Count=0},Growth=EmptyGrowth()}
local function includes(ids,wanted)for _,id in ipairs(ids)do if id==wanted then return true end end;return false end
local cases=0
for id=601,620 do
    local candidate=weapon(id,id);equipment.main=weapon(1,40)
    local view=rules:PreviewWeapon(candidate)
    for _,skillId in ipairs(weaponRows:Get(id).skillIds)do
        local base=config:GetTable('CombatSkillTable'):Get(skillId);local count=#base.effectIds
        local resolved=view:Skill(previewActor,skillId,equippedStats)
        assert(resolved.id==skillId and #base.effectIds==count)
    end
    assert(equipment.main.ItemId==40 and equipment.Revision==17 and candidate.OwnerActorId==31)
    cases=cases+1
end
equipment.main=weapon(2,604,{[108]=715});local spread=rules:Skill(previewActor,7,equippedStats)
assert(spread.maxTargets==2 and spread.splashRadius==1 and config:GetTable('CombatSkillTable'):Get(7).maxTargets==1)
equipment.main=weapon(3,608,{[116]=717});local edged=rules:Skill(previewActor,1608,equippedStats)
assert(includes(edged.effectIds,1358) and includes(edged.effectIds,1333),'Physical edge modifier must match slash')
assert(not includes(config:GetTable('CombatSkillTable'):Get(1608).effectIds,1358),'Attachment effects cannot mutate shared skill')
local off=weapon(4,608,{[116]=717});equipment.off=off;equipment.main=weapon(5,40)
local offSkill=rules:Skill(previewActor,13,equippedStats)
assert(includes(offSkill.effectIds,1358),'Physical edge modifier must match offhand weapon group')
equipment.off=nil;equipment.main=weapon(6,603,{[105]=704,[106]=706})
local support=rules:Skill(previewActor,1603,equippedStats)
assert(not includes(support.effectIds,1347) and not includes(support.effectIds,1349),'Non-damage support spell must not gain on-hit attachments')
for id=701,720 do local kind=items:Get(id).kind;assert((kind=='rune' or kind=='module') and runes:Get(id))end
print('PASS '..cases..' new weapon previews without HP or inventory writes; rail/edge, offhand, support filtering and shared skill immutability')

local Instructions=require('Game.Battle.EffectInstructions')
local Containers=require('Game.Loot.ContainerCombat')
source=actor(40,15)
local physical={Destroyed=false,Unlocked=true,Durability=100,MaxDurability=100,GetCellAt=function()return 1 end}
local container={Id=1,TableId=1,Name='test crate',Looted=false,ItemCount=1,GetCountAt=function()return 1 end}
local area={cells={{index=1,q=0,r=0,layer=0}}}
function area:Find()return self.cells[1]end
function area:CanTrace()return true end
function area:CanSee()return true end
local areaState={Loot=function()error('A nonempty crate should not be auto-looted')end}
local containerAdventure={battle=battle,areas={data={Active=areaState},ActiveLayout=function()return area end}}
local combat=setmetatable({adventure=containerAdventure,loot={rules={containers={Get=function()return{structuralDefense=0}end}},Physical=function()return physical end},Origin=function()return area.cells[1]end},{__index=Containers})
local originalHeight=stats.heightAdvantage
stats.heightAdvantage={HitChance=function()return 100 end}
CS.ProjectY.Data.ContainerState={Hit=function(_,id,amount)assert(id==1);local actual=math.min(physical.Durability,amount);physical.Durability=physical.Durability-actual;physical.Destroyed=physical.Durability==0;return actual end}
local life=skill(10,{config:GetTable('CombatSkillTable'):Get(10).effectIds[1],1320,1315,1322,1357,1358,1333})
local plan=combat:Prepare(source,life,container)
assert(#plan.effects==1,'Container preparation must remove actor-only actions and source rewards')
combat:Apply({plan},source,life,function()return 0 end)
assert(physical.Durability<100 and source.HP==15 and source.Guard==0 and source.Effects.Count==0,'Breaking containers must not farm healing, guard or status effects')
for id=1301,1360 do assert(not Instructions.ContainerDamage(definitions:Get(id)),'New actor-only atom unexpectedly affects containers: '..id)end
for id=1601,1623 do
    local row=config:GetTable('CombatSkillTable'):Get(id)
    assert(not require('Game.Battle.SkillContext')(row,'life') and not row.affectsContainers,'Specialized compound skills must not enter one-effect life handlers')
end
local dispatched=0
local adapter=setmetatable({adventure={battle={SkillIds=function()return{10}end,Skill=function()return life end,stats={equipment={CheckSkillEquipment=function()return true end}}},
    data={Phase='area'},containerCombat={CanArea=function(_,a,s,id)assert(a==source and s==10 and id==1);return true end,Area=function()dispatched=dispatched+1;return true end}},
    skills=config:GetTable('CombatSkillTable'),Actor=function()return source end},{__index=require('Game.Adventure.CharacterSkills')})
assert(adapter:Use(source.Id,10,1) and dispatched==1,'Existing life attack must route to ContainerCombat')
-- Exercise the real container-primary command's actor splash path, including its accuracy gate.
local splashTarget=actor(41);splashTarget.Q=1;splashTarget.R=0
source.Q=0;source.R=0
function source:SpendAction()end
function source:SetCooldown()end
function source:RecordAction()end
areaState.LootCount=1
function areaState:GetLootAt(i)assert(i==0);return container end
function combat:CanBattle()return true,nil,container,area.cells[1]end
life.maxTargets=2;life.splashRadius=1
life.effectIds={config:GetTable('CombatSkillTable'):Get(10).effectIds[1],1320}
function battle:Active()return source end
function battle:Skill()return life end
function battle:Units()return{splashTarget}end
function battle:CanUseSkill(_,id)return id==splashTarget.Id end
function battle:CheckWinner()return false end
local oldConsume=stats.equipment.Consume;stats.equipment.Consume=function()end
random=99;hp=splashTarget.HP
assert(combat:Battle(battle,10,1))
assert(splashTarget.HP==hp and source.HP==15,'A container hit must not bypass accuracy for its actor splash or source reward')
random=0;assert(combat:Battle(battle,10,1))
assert(splashTarget.HP<hp and source.HP==19,'A landed actor splash must run the common hit-gated effect program')
stats.equipment.Consume=oldConsume
stats.heightAdvantage=originalHeight
print('PASS real container damage path filters all actor-only rewards; existing life attacks dispatch correctly')
print('PASS container-primary battle splash shares actor accuracy and grants source rewards only on actor hit')
config:OnShutdown()
print('PASS arsenal_effects complete')
