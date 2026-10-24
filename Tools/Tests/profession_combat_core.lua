-- Real exported definitions and production effect/projectile/profession rules; only the C# boundary is isolated.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)local f=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local b=f:read('*a');f:close();return b end}})
local function copy(row)local t={};for k,v in pairs(row)do t[k]=v end;return t end
local function collection()
    local c={rows={},Count=0,next=1,Revision=0}
    function c:GetAt(i)return assert(self.rows[i+1])end
    function c:Find(id)for _,r in ipairs(self.rows)do if r.EffectId==id then return r end end end
    function c:ById(id)for _,r in ipairs(self.rows)do if r.Id==id then return r end end;error('Missing instance')end
    function c:Add(id,source,name,amount,duration)
        local r={Id=self.next,EffectId=id,SourceId=source,SourceName=name,Amount=amount,Remaining=duration,Elapsed=0,Stacks=1}
        self.next=self.next+1;self.rows[#self.rows+1]=r;self.Count=#self.rows;self.Revision=self.Revision+1;return r
    end
    function c:Refresh(id,source,name,amount,duration,max,stack)
        local r=self:ById(id);r.SourceId=source;r.SourceName=name;r.Amount=amount;r.Remaining=duration;r.Elapsed=0;r.Stacks=stack and math.min(max,r.Stacks+1)or 1;self.Revision=self.Revision+1
    end
    function c:Advance(id,period)local r=self:ById(id);r.Elapsed=period>0 and (r.Elapsed+1)%period or 0;if r.Remaining>0 then r.Remaining=r.Remaining-1 end;self.Revision=self.Revision+1 end
    function c:Remove(id)for i,r in ipairs(self.rows)do if r.Id==id then table.remove(self.rows,i);self.Count=#self.rows;self.Revision=self.Revision+1;return end end;error('Missing removed instance')end
    return c
end
local snapshots={}
function snapshots.Configure(row,ids,amounts,expiry,nextTick)row.ids={table.unpack(ids)};row.amounts={table.unpack(amounts)};row.expiry=expiry;row.nextTick=nextTick end
function snapshots.Amount(row,id)for i,value in ipairs(row.ids)do if value==id then return row.amounts[i]end end;error('Missing snapshot')end
function snapshots.Count(row)return #row.ids end
function snapshots.EffectAt(row,i)return row.ids[i+1]end
function snapshots.ExpiresAt(row)return row.expiry end
function snapshots.NextTickAt(row)return row.nextTick end
local state={}
function state.Mark(a,k)return a.marks[k]or 0 end
function state.SetMark(a,k,v)a.marks[k]=v end
function state.Once(a,k,v)if state.Mark(a,k)==v then return false end;state.SetMark(a,k,v);return true end
function state.SetLifetime(item,n)item.Remaining=n end
function state.Move(a,q,r)a.Q=q;a.R=r;a.Moved=true end
function state.StopMovement(a)a.Moved=true end
function state.Transfer(source,target,id,max)
    local old=source:ById(id);local prior=target:Find(old.EffectId);local count=math.min(max,old.Stacks+(prior and prior.Stacks or 0))
    if prior then target:Remove(prior.Id)end
    local next=target:Add(old.EffectId,old.SourceId,old.SourceName,old.Amount,old.Remaining);next.Stacks=count;next.Elapsed=old.Elapsed
    snapshots.Configure(next,old.ids,old.amounts,old.expiry,old.nextTick);source:Remove(id);return next
end
function state.Trap(data,q,r)for _,t in ipairs(data.traps)do if t.Q==q and t.R==r then return t end end end
function state.PlaceTrap(data,q,r,source,effect)data.traps[#data.traps+1]={Q=q,R=r,SourceId=source,EffectId=effect}end
function state.RemoveTrap(data,q,r)for i,t in ipairs(data.traps)do if t.Q==q and t.R==r then table.remove(data.traps,i);return end end end
local wear={};local armor={}
CS={ProjectY={Data={GameBuffState=snapshots,ProfessionCombatState=state,
    BodyHealth={Revision=function()return 0 end,MaximumHP=function(a)return a.MaxHP end,HP=function(a)return a.MaxHP end,Damage=function()return 0 end,Permanent=function()return false end,
        Hit=function(a,_,amount)return a:Damage(amount)end,Injure=function()return false end,RecoverableHP=function(a)return a.MaxHP end},
    EquipmentCombatState={DamageArmor=function(_,id,n)armor[id]=(armor[id]or 0)+n;return n end,RefreshMaximum=function()end,DamageWeapon=function(_,id,n)wear[id]=(wear[id]or 0)+n end},
    EquipmentConditionData={Of=function(item)return item.condition end},EquipmentAffixData={Of=function(item)return item.affixId end},
    AnimalCompanionState={Independent=function(a)return a.independent==true end,Bound=function(a)return a.MountedAnimal end}}}}
local inventory={WearableCount=0,material={[8013]=10,[8014]=10,[8015]=10,[8016]=10,[82]=10},hands={},shields={}}
function inventory:Equipped(id)return self.hands[id]end
function inventory:Offhand()end
function inventory:Worn(id)return self.shields[id]end
function inventory:CountItem(id)return self.material[id]or 0 end
function inventory:ConsumeStack(id,n)assert(self:CountItem(id)>=n);self.material[id]=self:CountItem(id)-n end
local stats=require('Game.Battle.CombatStats')(config,inventory)
local actors={};local roll=0;local events={}
local battle={stats=stats,skills=config:GetTable('CombatSkillTable'),effects=config:GetTable('CombatEffectTable'),data={Round=1,Phase='combat',ActiveId=1,traps={},RollPercent=function()return roll end}}
battle.board=require('Game.Battle.BattleBoard').Create(4,1,0)
function battle:Units()return actors end
function battle:FindUnit(id)for _,a in ipairs(actors)do if a.Id==id then return a end end end
function battle:IsHostile(a,b)return a.Team~=b.Team end
function battle:IsAllied(a,b)return a.Team==b.Team end
function battle:Emit(kind,message,source,target,amount,actor,attackHit,impact)events[#events+1]={kind=kind,target=target,amount=amount,impact=impact}end
function battle:Occupied(except)local occupied={};for _,a in ipairs(actors)do if a.Id~=except and a.HP>0 then stats.animals:Occupy(a,self.board,occupied)end end;return occupied end
function battle:ShotOccupancy()return{}end
battle.gameEffects=require('Game.Battle.GameEffects').New(stats,battle.effects,function(...)battle:Emit(...)end,{roll=function()return roll end,minutes=function()return 0 end})
battle.gameEffects:Validate()
battle.professions=require('Game.Battle.ProfessionCombat').New(config,battle);battle.gameEffects.professions=battle.professions
local rules,effects=battle.professions,battle.gameEffects
local function actor(id,team,q,r,talents)
    local learned=talents or {};local growth={TalentCount=#learned,SkillCount=0,GetTalentAt=function(_,i)return learned[i+1]end,GetRank=function(_,id)for _,n in ipairs(learned)do if n==id then return 1 end end;return 0 end,
        GetAttribute=function(_,name)return name=='strength' and 20 or name=='intellect' and 12 or 0 end}
    local a={Id=id,TemplateId=1,Team=team,Q=q,R=r,AnimalSpeciesId=0,AnimalOwnerId=0,TraitCount=0,Effects=collection(),Growth=growth,HP=200,MaxHP=200,Guard=0,AP=10,MainUsed=false,marks={}}
    function a:Damage(n)local actual=math.min(self.HP,n);self.HP=self.HP-actual;return actual end
    function a:Heal(n)local actual=math.min(self.MaxHP-self.HP,n);if self.HP==0 then return 0 end;self.HP=self.HP+actual;return actual end
    function a:SetGuard(n)self.Guard=math.max(self.Guard,n)end
    function a:SetMaxHP(n)self.HP=self.HP==0 and 0 or math.max(1,self.HP+n-self.MaxHP);self.MaxHP=n end
    function a:SpendAction(kind,cost)assert(cost<=self.AP and (kind~='main'or not self.MainUsed));self.AP=self.AP-cost;if kind=='main'then self.MainUsed=true end;self.Moved=true end
    a.cooldowns={}
    function a:GetCooldown(id)return self.cooldowns[id]or 0 end
    function a:SetCooldown(id,turns)self.cooldowns[id]=turns end
    function a:RecordAction()end
    actors[#actors+1]=a;return a
end
local function reset(talents)
    actors={};events={};wear={};armor={};battle.data.Round=1;battle.data.ActiveId=1;battle.data.Phase='combat';battle.data.Winner='';battle.data.traps={};roll=0
    return actor(1,1,0,0,talents),actor(2,2,1,0)
end
local function skill(id)
    local s=copy(battle.skills:Get(id));s.hitChance=100;s.criticalChance=0;s.criticalMultiplier=1;s.maxTargets=s.maxTargets or 1;return s
end
local Shots=require('Game.Battle.ProjectileCombat')
local function cast(s,source,target)
    local program={};for _,id in ipairs(s.effectIds)do program[#program+1]=effects:Prepare(id,source,target,s)end
    rules:PrepareProgram(source,s,target,program);Shots.PrepareProgram(battle,source,s,program)
    for shot=1,s.shots do Shots.ApplyProgram(battle,source,s,program,shot)end
end
local function damageTotal(target)
    local n=0;for _,event in ipairs(events)do if event.kind=='damage' and event.target==target.Id then n=n+event.amount end end;return n
end
local source,target=reset({1845})
effects:Apply(20001,source,target);effects:Apply(20002,source,target)
local attack=skill(1844);attack.shots=2
local base=effects:Prepare(20201,source,target,attack).amount
cast(attack,source,target)
assert(not target.Effects:Find(12001)and not target.Effects:Find(12002),'The first hit consumes exposure and curse exactly once')
local hits={};for _,e in ipairs(events)do if e.kind=='damage'then hits[#hits+1]=e end end
assert(#hits==2 and hits[1].amount<=math.floor(base*1.5)and hits[2].amount==base,'Conditional bonuses are capped and never duplicate over shots')
assert(armor[target.Id]==4,'Mercy preserves armor only for the hit whose pre-hit snapshot had exposure')
print('PASS shared one-hit states, bonus cap, multishot consumption and selective armor preservation')

source,target=reset({1805})
for i=1,3 do effects:Apply(803,source,target)end
local poison=target.Effects:Find(10003);assert(poison.Stacks==3)
target.HP=1;cast(skill(1862),source,target)
assert(target.HP==0 and source.Effects:Find(12012),'Lethal cleanup cannot erase the successful distillation snapshot/passive')
local reduced=rules:Skill(source,skill(1803));assert(reduced.cost==1)
local before=inventory:CountItem(8015);rules:Commit(source,reduced)
assert(inventory:CountItem(8015)==before-1 and not source.Effects:Find(12012),'A legal action consumes one material and the AP voucher once')
target=actor(3,2,2,0);effects:Apply(803,source,target);cast(skill(1862),source,target)
assert(not source.Effects:Find(12012),'Recovery triggers once per encounter, not once per target or round')
inventory.material[8015]=0;local ap=source.AP
assert(not rules:Budget(source,skill(1803))and source.AP==ap,'Prevalidation never consumes AP or inventory')
inventory.material[8015]=10
print('PASS lethal poison snapshot, per-encounter recovery, AP/material consumption and failed prevalidation')

source,target=reset({1815})
cast(skill(1813),source,target)
assert(not source.Effects:Find(12003),'Reply cannot trigger from a debuff that this same hit just created')
cast(skill(1813),source,target)
local resonance=assert(source.Effects:Find(12003));assert(resonance.Remaining==2)
effects:Remove(source,resonance.Id);cast(skill(1813),source,target)
assert(not source.Effects:Find(12003),'Reply triggers at most once in a round')
battle.data.Round=2;cast(skill(1813),source,target);assert(source.Effects:Find(12003))
local ally=actor(3,1,-1,0);effects:Apply(20003,source,ally)
assert(rules:CanUse(source,skill(1814),ally));cast(skill(1814),source,ally)
assert(not ally.Effects:Find(12003)and ally.Effects:Find(12010).Remaining==1)
effects:Apply(20003,source,ally);assert(not rules:CanUse(source,skill(1814),ally),'Encore beneficiary cannot be credited twice in a round')
local nextSkill=rules:Skill(ally,skill(1824));assert(nextSkill.cost==1)
local main=ally.MainUsed;rules:Commit(ally,nextSkill);assert(ally.MainUsed==main and not ally.Effects:Find(12010))
print('PASS source resonance, pre-action debuff qualification, per-round reply/encore and no action-budget reset')

source,target=reset({1825,1835})
effects:Apply(20013,source,source);local beforeInt=stats:Get(source,'intellect')
rules:BeginTurn(source);assert(stats:Get(source,'intellect')==beforeInt+2)
cast(skill(1824),source,target)
assert(not source.Effects:Find(12013)and source.Guard==4,'Judgement consumes source weakness and grants Grace once')
source.Guard=0;effects:Apply(20013,source,source);cast(skill(1824),source,target);assert(source.Guard==0,'Grace does not retrigger in the same round')
effects:TickActor(source,'turn_end');assert(not source.Effects:Find(12017),'Suffering intellect expires at the actual owner turn end')
effects:Apply(803,source,source);effects:TickActor(source,'turn_end')
local transferred=assert(source.Effects:Find(10003));local remaining,elapsed,stacks=transferred.Remaining,transferred.Elapsed,transferred.Stacks
cast(skill(1834),source,target)
local received=assert(target.Effects:Find(10003));assert(not source.Effects:Find(10003)and received.Remaining==remaining and received.Elapsed==elapsed and received.Stacks==stacks)
effects:Apply(803,source,source)
local immunity=stats.growth.Immunity;stats.growth.Immunity=function(_,a,tag)if a==target and tag=='poison'then return{name='fixture'}end;return immunity(stats.growth,a,tag)end
assert(not rules:CanUse(source,skill(1834),target)and source.Effects:Find(10003),'Known immunity rejects transfer before removing the source instance')
stats.growth.Immunity=immunity
print('PASS owner-state judgement, Grace/Suffering counters, precise transfer lifetime and immunity precheck')

source,target=reset()
cast(skill(1801),source,source)
local double=skill(1844);double.shots=2;cast(double,source,target)
assert(not source.Effects:Find(12004)and target.Effects:Find(12019),'One coating applies to the first direct weapon hit')
effects:Apply(20009,source,target)
local ward=target.Effects:Find(12009);local hp=target.HP
effects:Apply(803,source,target);effects:TickActor(target,'turn_end')
assert(target.HP<hp and target.Effects:Find(12009)==ward,'Periodic damage never consumes the ward')
cast(skill(1844),source,target);assert(not target.Effects:Find(12009))
local ally=actor(3,2,2,0);effects:Apply(20018,target,ally)
local allyHP=ally.HP;local targetHP=target.HP;cast(skill(1844),source,ally)
assert(ally.HP==allyHP and target.HP<targetHP and not ally.Effects:Find(12018),'Oath moves the actual single-hit program once to the adjacent defender')
print('PASS one-use coating, direct-only ward and single-target oath redirection')

source,target=reset();local retreat=skill(1843)
local cells=rules:LandingCells(source,retreat,target);assert(#cells>0)
for _,cell in ipairs(cells)do assert(require('Game.Map.HexGrid').Distance(cell.q,cell.r,target.Q,target.R)>1)end
local pushed=assert(rules:ForcedLanding(source,target,'push'));assert(pushed.q==2 and pushed.r==0)
state.PlaceTrap(battle.data,pushed.q,pushed.r,source.Id,20016);rules:Move(target,pushed)
assert(target.Moved and target.Effects:Find(12016)and not state.Trap(battle.data,pushed.q,pushed.r))
local ally=actor(3,1,-1,0);assert(rules:CanSwap(source,ally))
battle.SkillIds=function()return{}end;battle.CheckWinner=function()return false end
cast(skill(1909),source,ally);assert(source.Q==-1 and ally.Q==0 and source.Moved and ally.Moved)
battle.SkillIds=nil
assert(rules.rows:Get(1907).materialId==82,'Tripwire must consume rope, not iron fittings')
local missing=inventory.material[82];inventory.material[82]=0;assert(not rules:Budget(source,skill(1907)));inventory.material[82]=missing
print('PASS legal retreat/forced footprint cells, one-shot trap interruption, ally swap and material validation')

source,target=reset();battle.data.Phase='deployment';cast(skill(1821),source,source)
assert(source.Guard==3 and source.Effects:Find(12022));source.Guard=0;battle.data.Phase='combat';rules:BeginTurn(source)
assert(source.Guard==3,'Preparation guard survives the formal BeginTurn reset')
effects:TickActor(source,'turn_end');assert(not source.Effects:Find(12022))
cast(skill(1811),source,source);assert(source.Effects:Find(12003).Remaining==1)
print('PASS preparation benefit has exactly the first formal-turn lifetime')
source,target=reset();local water=skill(1802);water.hitChance=90;roll=99
cast(water,source,target);assert(not target.Effects:Find(12019),'Water bottle must roll accuracy against a non-allied recipient')
cast(water,source,source);assert(source.Effects:Find(12019),'Water bottle is guaranteed for an allied recipient')
local plan=effects:Prepare(20013,source,target,skill(1813));plan.definition=copy(plan.definition);plan.definition.sourceRequiredTags={'resonance'}
effects:ApplyPrepared(plan);assert(not target.Effects:Find(12013),'Source status conditions cannot accidentally inspect the selected enemy')
effects:Apply(20003,source,source);effects:ApplyPrepared(plan);assert(target.Effects:Find(12013))
print('PASS mixed-team water-bottle accuracy and source-status effect filters')
source,target=reset({1825});effects:Apply(801,source,source);roll=0
effects:Apply(1352,source,source);assert(source.Guard==0,'Removing a boon must not trigger Grace')
effects:Apply(803,source,source);effects:Apply(20205,source,source);assert(source.Guard==4,'Actual skill-cleansed debuffs trigger Grace')
print('PASS Grace distinguishes cleansed debuffs from removed beneficial statuses')
local Battle=require('Game.Battle.BattleSystem');setmetatable(battle,{__index=Battle})
battle.beasts=require('Game.Battle.ProfessionBeasts').New(config,battle)
function battle:CheckWinner()return false end -- This fixture owns no expedition lifecycle.
source,target=reset();source.Growth.SkillCount=1;source.Growth.GetSkillAt=function()return 1803 end
source.AP=4;roll=99;local materials=inventory:CountItem(8015)
assert(battle:TrySkill(1803,target.Id))
assert(source.AP==2 and source.MainUsed and source:GetCooldown(1803)==2 and inventory:CountItem(8015)==materials-1 and not target.Effects:Find(10003),
    'A real missed battle command must still spend exactly one main action, AP, material and cooldown')
source.MainUsed=false;source.AP=4
assert(not battle:TrySkill(1803,target.Id)and source.AP==4 and inventory:CountItem(8015)==materials-1,'Cooldown prevalidation must be free')
source:SetCooldown(1803,0);inventory.material[8015]=0
assert(not battle:TrySkill(1803,target.Id)and source.AP==4 and source:GetCooldown(1803)==0,'Material prevalidation must be free')
inventory.material[8015]=10
print('PASS real Battle.TrySkill transaction: misses pay once; cooldown/material rejection is mutation-free')
for _,path in ipairs({'Lua/Game/Battle/ProfessionCombat.lua','Lua/Game/Battle/BattleSystem.lua','Lua/Game/Battle/GameEffects.lua','Lua/Game/Battle/ProjectileCombat.lua','Lua/Game/Battle/EffectInstructions.lua'})do assert(loadfile(path))end
