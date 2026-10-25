-- Named legendary equipment: real exported tables and production battle/effect rules; isolate only C# state.
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
local Legendary=require('Game.Battle.LegendaryEquipment')
local legendary=Legendary.New(config,battle);battle.legendary=legendary;effects.legendary=legendary
battle.beasts=require('Game.Battle.ProfessionBeasts').New(config,battle)
local animals=CS.ProjectY.Data.AnimalCompanionState
function animals.Partner(owner)return owner.pet end
function animals.CanMove(owner,round)return owner.moveRound~=round end
function animals.CanAttack(owner,round)return owner.attackRound~=round and owner.rescueRound~=round end
function animals.Moved(owner,round)assert(animals.CanMove(owner,round));owner.moveRound=round end
function animals.Attacked(owner,round)assert(animals.CanAttack(owner,round));owner.attackRound=round end
function animals.ReleaseDefeated()end
function animals.Scent()return 0 end
function battle:CheckWinner()return false end
function battle:ApplyEffectProgram(a,s,p,n)Shots.ApplyProgram(self,a,s,p,n)end
function battle:Skill(a,id)return legendary:Skill(a,rules:Skill(a,stats.equipment:Skill(a,id,stats)))end
function battle:SkillIds(a)return legendary:AddSkills(a,stats.equipment:SkillIds(a,stats:Template(a)))end
local serial=100
local function equip(a,kind)
    serial=serial+1
    local item={Id=serial,ItemId=legendary.byKind[kind].id,affixId=1,condition={Current=100,Broken=false,Efficiency=1},GetRune=function()return 0 end,GetAttachment=function()return 0 end}
    if kind=='homecoming'then inventory.shields[a.Id]=item else inventory.hands[a.Id]=item end
    legendary:Sync(a);return item
end
local oldReset=reset
reset=function()
    inventory.hands={};inventory.shields={};battle.data.Winner='';battle.board=require('Game.Battle.BattleBoard').Create(7,1,0)
    return oldReset()
end
local function action(id,a,targets,commit)
    local s=battle:Skill(a,id);s.hitChance=100;s.criticalChance=0;s.criticalMultiplier=1
    local program={}
    for _,target in ipairs(targets)do for _,effect in ipairs(s.effectIds)do program[#program+1]=effects:Prepare(effect,a,target,s)end end
    rules:PrepareProgram(a,s,targets[1],program);assert(legendary:PrepareAction(a,s,targets,program))
    Shots.PrepareProgram(battle,a,s,program)
    if commit~=false then rules:Commit(a,s)end
    for shot=1,s.shots do Shots.ApplyProgram(battle,a,s,program,shot)end
    legendary:AfterAction(a,s);return s
end
local function clearEvents()events={}end
local source,target=reset();equip(source,'bulwark');actor(3,2,0,1)
action(2201,source,{target});assert(source.Guard==4 and target.Q==2,'Bulwark guard and real push')
source.Guard=0;target.Q=1;action(2201,source,{target});assert(source.Guard==0,'Guard once per round')
print('PASS bulwark guard counter and legal push')

source,target=reset();equip(source,'hunt');target.Q=3
legendary:Moved(source,{battle.board:Find(-2,0),battle.board:Find(-1,0),battle.board:Find(0,0)},true)
local s=battle:Skill(source,2202);assert(s.legendaryHunt and s.hitChance>=90)
local retreat=legendary:LandingCells(source,s,target);local two
for _,cell in ipairs(retreat)do if require('Game.Map.HexGrid').Distance(0,0,cell.q,cell.r)==2 then two=cell;break end end
assert(two,'Retreat exposes actual two-cell paths');local path=legendary:SelectedPath(source,s,target,two)
assert(legendary:Walk(source,path,false));assert(source.Q==two.q and source.R==two.r and source.Moved)
print('PASS ranger ordinary movement bonus and two-cell retreat')

source,target=reset();equip(source,'theorem')
-- Use true spell definitions to alternate damage types irrespective of learned curriculum.
local function hitSpell(effectType)
    local spell=skill(2203);spell.id=3;spell.skillGroup='spell';spell.effectIds={effectType};spell.legendaryKind=nil
    cast(spell,source,target)
end
target.HP=200;hitSpell(23021);hitSpell(23022)
local refraction=legendary:Status(source,'theorem')
assert(refraction,'Alternating successful spell types accumulates refraction')
local terminal=battle:Skill(source,2203);assert(terminal.legendaryRefraction>0);rules:Commit(source,terminal)
assert(not legendary:Status(source,'theorem'),'Refraction consumed on legal submission, before hit')
print('PASS theorem alternating-hit resource and commit consumption')

source,target=reset();equip(source,'oath');equip(source,'homecoming');local ally=actor(3,1,0,1)
action(2205,source,{ally});assert(source.Guard==4 and rules:Status(ally,'interpose'))
target.Q=1;target.R=1;local hp=ally.HP;action(1844,target,{ally})
assert(ally.HP==hp and source.HP<200 and legendary:Status(source,'oath')and legendary:Status(ally,'homecoming'),'Real interposition earns retaliation and shield ward')
local ward=legendary:Status(ally,'homecoming');state.SetLifetime(ward,2);effects:Apply(803,target,ally);effects:TickActor(ally,'turn_end');assert(legendary:Status(ally,'homecoming')==ward,'Periodic damage preserves ward before its scheduled expiry')
local stanceBonus=battle:Skill(source,2205);local context=rules:BeforeHit(source,skill(1844),target);assert(context.legendaryBonus==20)
print('PASS sword/shield coactivation, actual oath interception, retaliation and direct-only ward')

source,target=reset();equip(source,'distill');effects:Apply(803,source,target)
action(1862,source,{target});assert(legendary:Status(source,'distill',2),'Successful poison consumption leaves sample')
assert(legendary:Budget(source,battle:Skill(source,2226)));action(2226,source,{target});assert(not legendary:Status(source,'distill',2))
assert(not legendary:Budget(source,battle:Skill(source,2226)),'A sample cannot reproduce itself')
effects:Apply(803,source,target);action(1862,source,{target});assert(legendary:Status(source,'distill',2));legendary:Remove(source,'distill',2)
effects:Apply(803,source,target);action(1862,source,{target});assert(not legendary:Status(source,'distill',2),'Two samples per battle')
print('PASS distillation, residue variant gating, no recursive sample and encounter cap')

source,target=reset();equip(source,'chorus');local ally=actor(3,1,0,1)
rules:ApplyStatus(source,ally,'resonance');action(1814,source,{ally});assert(legendary:Status(source,'chorus').Stacks==1)
battle.data.Round=2;rules:ApplyStatus(source,source,'resonance');action(1813,source,{target})
assert(legendary:Status(source,'chorus').Stacks==2);action(2207,source,{source,ally})
assert(not legendary:Status(source,'chorus')and rules:Status(source,'resonance')and rules:Status(ally,'resonance'))
print('PASS chorus resource, two-beneficiary resonance and no feedback loop')

source,target=reset();equip(source,'dawn');local ally=actor(3,1,0,1);ally.HP=100;source.HP=100
effects:Apply(20013,source,source);assert(legendary:Budget(source,battle:Skill(source,2208)));local sourceBefore=source.HP
action(2208,source,{source,ally});assert(#rules:Tagged(source,'weakness')==0 and ally.HP>100 and source.HP>sourceBefore and source.Guard==6)
assert(not legendary:Budget(source,battle:Skill(source,2208)))
print('PASS dawn real weakness consumption, wounded-ally healing and guard cap')

source,target=reset();equip(source,'debt');local second=actor(3,2,2,0)
local contract=battle:Skill(source,2209);assert(not legendary:PrepareAction(source,contract,{target},{}))
action(2209,source,{target,second});assert(legendary:Status(target,'debt')and legendary:Status(second,'debt'))
local attacker=actor(4,1,0,1);local before=second.HP;action(1844,attacker,{target})
assert(second.HP<before and not legendary:Status(target,'debt')and not legendary:Status(second,'debt'))
assert(before-second.HP<=second.MaxHP*.1,'Debt respects target maximum and remaining conditional budget')
action(2209,source,{target,second})
legendary:EndTurn(source)
for _=1,2 do
    legendary:BeginTurn(second);legendary:EndTurn(second);effects:TickActor(second,'turn_end')
    legendary:BeginTurn(target);legendary:EndTurn(target);effects:TickActor(target,'turn_end')
end
assert(legendary:Status(target,'debt')and legendary:Status(second,'debt'),'Receiver order/count must not advance caster-owned expiry')
legendary:BeginTurn(source);assert(legendary:Status(target,'debt'),'Debt is still usable throughout the caster next turn')
local before=second.HP;action(1844,source,{target});assert(second.HP<before,'Caster can trigger debt on their next turn')
action(2209,source,{target,second});legendary:EndTurn(source);assert(legendary:Status(target,'debt'))
legendary:BeginTurn(source);assert(legendary:Status(target,'debt'));legendary:EndTurn(source)
assert(not legendary:Status(target,'debt')and not legendary:Status(second,'debt'))
print('PASS exact two-target debt, capped splash and caster-next-turn-end expiry independent of receiver order')

source,target=reset();equip(source,'duel');action(2210,source,{source});assert(legendary:Status(source,'duel'))
local before=source.HP;action(1844,target,{source});assert(not legendary:Status(source,'duel')and rules:Status(target,'exposed')and source.HP<before)
clearEvents();armor[target.Id]=0;action(1844,source,{target});assert((armor[target.Id]or 0)==0,'Exposed target armor is preserved')
print('PASS duel stance consumption, exposed attacker and armor preservation')

source,target=reset();equip(source,'harvest');target.MaxHP=300;target.HP=300
local ctx=rules:BeforeHit(source,skill(1844),target);assert(ctx.legendaryBonus==20)
action(2212,source,{target});assert(legendary:Status(target,'harvest'))
local later=actor(3,2,0,1);later.HP=1000;later.MaxHP=1000
assert(rules:BeforeHit(source,skill(1844),later).legendaryBonus==0,'A later qualifying target cannot repeat the first-hit bonus')
source,target=reset();equip(source,'harvest');target.HP=1000;target.MaxHP=1000
local second=actor(3,2,0,1);second.HP=1000;second.MaxHP=1000
local harvest=battle:Skill(source,2212);local base=effects:Prepare(harvest.effectIds[1],source,second,harvest).amount
action(2212,source,{target,second});assert(damageTotal(target)==base+math.floor(base*.2)and damageTotal(second)==base,'Sweep gives the bonus to only the first actual hit')
source,target=reset();equip(source,'harvest');target.HP=1000;target.MaxHP=1000
local miss=skill(2212);miss.id=1844;miss.hitChance=0;roll=99;cast(miss,source,target)
assert(state.Mark(source,'legendary_harvest_round')==0,'A miss does not consume the first-hit eligibility')
miss.hitChance=100;miss.shots=2;roll=0;local base=effects:Prepare(miss.effectIds[1],source,target,miss).amount
cast(miss,source,target);local hits={};for _,event in ipairs(events)do if event.kind=='damage'then hits[#hits+1]=event.amount end end
assert(hits[1]==base+math.floor(base*.2)and hits[2]==base,'Multiple shots cannot repeat the first-hit bonus')
battle.data.Round=2;assert(rules:BeforeHit(source,skill(1844),target).legendaryBonus==20,'Eligibility resets with the authoritative battle round')
print('PASS harvest larger-target first-hit gate, multi-target/multishot limit, misses and timed weakness')

source,target=reset();equip(source,'banner');local ally=actor(3,1,-3,0);local second=actor(4,1,-2,1)
local plan=assert(legendary:BannerPlan(source,{ally,second}));assert(#plan==2)
action(2213,source,{ally,second});assert(legendary:Status(ally,'banner')and legendary:Status(second,'banner'))
local aimed=battle:Skill(ally,1844);assert(aimed.legendaryAim);rules:Commit(ally,aimed);assert(not legendary:Status(ally,'banner'))
print('PASS banner complete occupancy plan, ally movement and one-use accuracy')

source,target=reset();equip(source,'beast');local pet=actor(3,1,-2,1);pet.independent=true;pet.AnimalOwnerId=source.Id;source.pet=pet
local hunt=battle:Skill(source,2211);local landings=legendary:LandingCells(source,hunt,target);assert(#landings>0)
assert(legendary:Budget(source,hunt));source.rescueRound=1;assert(not legendary:Budget(source,hunt));source.rescueRound=nil
assert(legendary:CommandRange(source,{commandRange=3})==4)
local opportunity=require('Game.Battle.OpportunityAttacks');local resolve=opportunity.Resolve;local calls=0
opportunity.Resolve=function(...)calls=calls+1;return resolve(...)end
local used=legendary:UseMovement(source,hunt,target,landings[1]);opportunity.Resolve=resolve
assert(used and source.moveRound==1 and source.attackRound==1 and target.HP<200 and calls==2,'Animal movement retains per-step opportunity checks')
print('PASS companion range, rescue prohibition, real movement and shared command budgets')

source,target=reset();equip(source,'lance');target.Q=5
assert(not legendary:Budget(source,battle:Skill(source,2215)));source.MountedAnimal={AnimalSpeciesId=1}
-- Isolate the mount footprint, while still exercising the real movement route and hit program.
local originalCells,originalPlace,originalDistance=stats.animals.Cells,stats.animals.CanPlace,stats.animals.Distance
stats.animals.Cells=function(_,a,b,q,r)return {assert(b:Find(q or a.Q,r or a.R))}end
stats.animals.CanPlace=function(_,a,b,q,r,occupied)return b:Find(q,r)~=nil and not occupied[require('Game.Map.HexGrid').Key(q,r)]end
stats.animals.Distance=function(_,a,b)return require('Game.Map.HexGrid').Distance(a.Q,a.R,b.Q,b.R)end
local charge=battle:Skill(source,2215);local landings=legendary:LandingCells(source,charge,target);assert(#landings==1 and landings[1].q==3)
legendary:Moved(source,{battle.board:Find(0,0),battle.board:Find(1,0)},false);assert(legendary:Status(source,'lance').Stacks==1)
legendary:Moved(source,{battle.board:Find(1,0),battle.board:Find(1,1)},false);assert(legendary:Status(source,'lance').Stacks==1,'Turning resets momentum')
legendary:Remove(source,'lance');local resolve=opportunity.Resolve;local calls=0
opportunity.Resolve=function(...)calls=calls+1;return resolve(...)end
assert(legendary:UseMovement(source,charge,target,landings[1]));opportunity.Resolve=resolve
assert(source.Q==3 and target.HP<200 and not legendary:Status(source,'lance')and calls==1,'Lance only checks opportunity at the starting position')
source,target=reset();equip(source,'lance');source.MountedAnimal={AnimalSpeciesId=1};target.Q=5
local interrupted=battle:Skill(source,2215);local landing=legendary:LandingCells(source,interrupted,target)[1]
opportunity.Resolve=function(_,rider)rider.MountedAnimal=nil;return 1 end
assert(legendary:UseMovement(source,interrupted,target,landing));opportunity.Resolve=resolve
assert(source.Q==0 and source.R==0 and source.AP==7 and target.HP==200,'A mount lost in the starting reaction cancels both travel and attack without refund')
stats.animals.Cells,stats.animals.CanPlace,stats.animals.Distance=originalCells,originalPlace,originalDistance
print('PASS mounted-only lance, straight charge, turning reset and commit consumption')

source,target=reset();local item=equip(source,'theorem');legendary:Apply(source,source,'theorem');assert(legendary:Status(source,'theorem'))
state.SetMark(source,'legendary_samples',2);inventory.hands[source.Id]=nil;legendary:Sync(source)
assert(not legendary:Status(source,'theorem')and state.Mark(source,'legendary_samples')==2,'Unequip clears resources but cannot reset encounter limits')
inventory.hands[source.Id]=item;legendary:Sync(source);item.condition.Broken=true
assert(not legendary:Budget(source,battle:Skill(source,2203)),'Broken legendary cannot activate')
print('PASS unequip cleanup, non-resettable counters and broken-item gating')

source,target=reset();equip(source,'carpenter');target.Q=4
assert(legendary:StructureDamage(source,20)==30)
local board=battle.board;local rawKeys=copy(board.byKey)
for key,cell in pairs(rawKeys)do board.byKey[key..':0']=cell;cell.layer=0;cell.height=0;cell.kind='floor'end
board.originLayer=0
local constructionCell=board:Find(1,0);local record={CellIndex=constructionCell.index,SiteId=1,SkillId=301,MaxHP=20,HP=7,Author=source.Id,PaidMaterialIds={82},PaidMaterialCounts={2}}
board.area={constructionSite=1,CanSee=function()return true end,entryIndex=board:Find(-7,0).index,goalIndex=board:Find(7,0).index}
CS.ProjectY.Data.LegendaryEquipmentState={ConstructionAuthor=function(r)return r.Author end,
    MoveConstruction=function(_,r,cell,id)assert(r.Author==id);r.CellIndex=cell end}
battle.construction={definitions=config:GetTable('ConstructionTable'),data={},Record=function(_,_,index)return index==record.CellIndex and record or nil end,
    adventure={data={Areas={Active={IsNpcOccupied=function()return false end}}},equipment={LootSnapshot=function()return{}end},areas={}}}
local hammer=battle:Skill(source,2204);assert(legendary:CanUseAt(source,hammer,constructionCell))
local destinations=legendary:ConstructionLandings(source,hammer,constructionCell);assert(#destinations>0)
record.Author=999;assert(not legendary:CanUseAt(source,hammer,constructionCell));record.Author=source.Id
local ap=source.AP;assert(legendary:UseAtWithLanding(source,hammer,constructionCell,destinations[1]))
assert(record.CellIndex==destinations[1].index and record.HP==7 and record.PaidMaterialCounts[1]==2 and source.AP==ap-2)
battle.construction=nil
print('PASS carpenter authored-structure validation, legal relocation, health/material preservation and structure damage')

local Battle=require('Game.Battle.BattleSystem');setmetatable(battle,{__index=Battle});battle.Skill=nil;battle.SkillIds=nil
source,target=reset();equip(source,'theorem');legendary:Apply(source,source,'theorem');source.AP=5;roll=99
assert(battle:TrySkill(2203,target.Id));assert(source.AP==2 and source.MainUsed and not legendary:Status(source,'theorem')and target.HP==200)
assert(source:GetCooldown(2203)==3 and source:GetCooldown(2223)==3,'Element variants share the same active cooldown')
source.MainUsed=false;source.AP=5;assert(not battle:TrySkill(2223,target.Id)and source.AP==5)
source,target=reset();equip(source,'debt');source.AP=4;local second=actor(3,2,2,0);roll=0
assert(not battle:TrySkillTargets(2209,{target.Id})and source.AP==4,'Two-target validation is complete before spending')
assert(battle:TrySkillTargets(2209,{target.Id,second.Id})and source.AP==2 and not source.MainUsed)
print('PASS real battle transaction: miss spends resources once, variants share cooldown, incomplete debt is free')
source,target=reset();equip(source,'distill');effects:Apply(803,source,target);target.HP=1
action(1862,source,{target});assert(target.HP==0 and legendary:Status(source,'distill',2),'Lethal cleanup preserves the distillation consumption snapshot')
source,target=reset();equip(source,'debt');local second=actor(3,2,2,0);action(2209,source,{target,second})
local context=rules:BeforeHit(source,skill(1844),target);context.bonus=10000
local plan=effects:Prepare(20201,source,target,skill(1844));local values=require('Game.Battle.EffectInstructions').Values(stats,source,target,plan.skill)
rules:Damage(context,plan,plan.amount,values);assert(context.conditionalBudget==0)
context.legendaryLost=100;context.legendaryCritical=1;local hp=second.HP;legendary:DebtDamage(context)
assert(second.HP==hp and not legendary:Status(second,'debt'),'Debt cannot borrow an already consumed bonus budget')
local originalImmunity=stats.growth.Immunity
for _,kind in ipairs({{name='fire',effect=23022,other='arcane'},{name='arcane',effect=23021,other='fire'}})do
    source,target=reset();equip(source,'debt');target.HP=1000;target.MaxHP=1000
    local partner=actor(3,2,2,0);partner.HP=1000;partner.MaxHP=1000
    local caster=actor(4,1,0,1);local spell=skill(2203);spell.id=3;spell.effectIds={kind.effect};spell.criticalChance=100;spell.criticalMultiplier=2
    action(2209,source,{target,partner});rules:ApplyStatus(source,partner,'curse_mark')
    stats.growth.Immunity=function(self,a,tag)if a==partner and tag=='damage_'..kind.name then return{name='fixture'}end;return originalImmunity(self,a,tag)end
    local before=partner.HP;cast(spell,caster,target)
    assert(partner.HP==before and rules:Status(partner,'curse_mark'),'Debt must inherit the original damage type immunity without consuming another curse')
    action(2209,source,{target,partner})
    stats.growth.Immunity=function(self,a,tag)if a==partner and tag=='damage_'..kind.other then return{name='fixture'}end;return originalImmunity(self,a,tag)end
    clearEvents();cast(spell,caster,target)
    assert(partner.HP<before and rules:Status(partner,'curse_mark'))
    local splash
    for _,event in ipairs(events)do if event.kind=='damage'and event.target==partner.Id then assert(not splash,'Debt must not recurse');splash=event end end
    assert(splash and splash.impact.damageType==kind.name and not splash.impact.critical and not splash.impact.professionContext,'Debt is one uncopied hit without critical/context replay')
    assert(battle.effects:Get(legendary.byKind.debt.effectIds[2]).damageType=='physical','Original shared damage template must remain immutable')
    stats.growth.Immunity=originalImmunity
end
source,target=reset();equip(source,'debt');local second=actor(3,2,2,0);action(2209,source,{target,second})
effects:Remove(target,legendary:Status(target,'debt').Id);assert(not legendary:Status(second,'debt'),'Dispelling one end clears the paired link')
action(2209,source,{target,second});inventory.hands[source.Id]=nil;legendary:Sync(source)
assert(not legendary:Status(target,'debt')and not legendary:Status(second,'debt'),'Unequipping the source clears outgoing links')
equip(source,'debt');action(2209,source,{target,second});source.HP=0;legendary:OnDefeated(source)
assert(not legendary:Status(target,'debt')and not legendary:Status(second,'debt'),'Defeated caster clears outgoing links')
source,target=reset();equip(source,'duel');rules:ApplyStatus(source,target,'exposed')
local oldOffhand=inventory.Offhand;local off={Id=999,ItemId=40,condition={Current=100,Broken=false,Efficiency=1},GetRune=function()return 0 end}
inventory.Offhand=function(_,id)if id==source.Id then return off end end
local offSkill=skill(stats.equipment.weapons:Get(off.ItemId).offhandSkillId)
local offContext=rules:BeforeHit(source,offSkill,target);assert(not offContext.preserveArmor,'Main-hand legendary cannot grant its passive to an offhand attack')
inventory.Offhand=oldOffhand
print('PASS lethal residue, shared bonus budget, inherited fire/arcane immunity, link cleanup and attacking-hand isolation')
for _,path in ipairs({'Lua/Game/Battle/LegendaryEquipment.lua','Lua/Game/Battle/BattleSystem.lua','Lua/Game/Battle/ProfessionCombat.lua','Lua/Game/Battle/ProjectileCombat.lua','Lua/Game/Battle/GameEffects.lua','Lua/Game/Battle/Construction.lua','Lua/Game/Battle/ProfessionBeasts.lua'})do assert(loadfile(path))end
