package.path='Lua/?.lua;'..package.path
local Feedback=require('Game.Battle.BattleFeedback')
local view={rows={},hits={},damage={},clears=0}
function view:Clear()self.rows={};self.hits={};self.damage={};self.clears=self.clears+1 end
function view:QueueHealth(...)self.rows[#self.rows+1]={...}end
function view:QueueImpact(...)self.hits[#self.hits+1]={...}end
function view:QueueDamage(...)self.damage[#self.damage+1]={...}end
local actor={Id=12,HP=60,MaxHP=100,Team=2}
Feedback.Changed(view,{kind='damage',amount=40,target=actor,attackHit=true,impact={damageColor='',shot=1}})
assert(view.rows[1][1]==12 and view.rows[1][2]==12 and view.rows[1][3]==.6 and #view.hits==1)
assert(#view.damage==1 and view.damage[1][1]==12 and view.damage[1][2]==40 and view.damage[1][3]==1 and view.damage[1][4]==false,'Enemy damage carries settled amount and normal-hit style')
actor.Team=1
Feedback.Changed(view,{kind='damage',amount=4,target=actor,attackHit=true,impact={damageColor='',shot=1}})
assert(#view.hits==2,'Both teams receive hit feedback')
assert(#view.damage==2 and view.damage[2][2]==4,'Friendly damage also receives its own number')
Feedback.Changed(view,{kind='damage',amount=3,target=actor,impact={damageColor='',shot=1}})
assert(#view.hits==2,'Periodic damage must not shake')
assert(#view.damage==3 and view.damage[3][2]==3 and view.damage[3][3]==1,'Periodic damage still receives a number')
Feedback.Changed(view,{kind='heal',amount=3,target=actor})
assert(#view.hits==2,'Healing must not shake')
Feedback.Changed(view,{kind='miss'})
Feedback.Changed(view,{kind='damage',amount=0,target=actor,attackHit=true})
assert(#view.rows==4 and #view.hits==2 and #view.damage==3,'Healing, miss and zero damage must not schedule damage numbers')
actor.MountedAnimal={Id=90,HP=10,MaxHP=50}
Feedback.Changed(view,{kind='damage',amount=3,target=actor,attackHit=true,impact={damageColor='',shot=1}})
assert(view.rows[5][1]==12 and view.rows[5][2]==90 and view.rows[5][3]==.2,'Mount health uses rider UI identity')
assert(#view.damage==4 and view.damage[4][1]==12,'Intercepted mount damage retains the attacked rider identity')
Feedback.Changed(view,{kind='battle_started'})
assert(#view.rows==0 and #view.hits==0 and #view.damage==0 and view.clears==1)
for shot=1,3 do Feedback.Changed(view,{kind='damage',amount=3,target=actor,attackHit=true,impact={damageColor='',shot=shot}}) end
assert(#view.hits==3 and view.hits[1][1]==1 and view.hits[2][1]==2 and view.hits[3][1]==3,'Burst damage must not be merged')
assert(#view.damage==3 and view.damage[1][3]==1 and view.damage[2][3]==2 and view.damage[3][3]==3,'Each settled bullet retains its own number and shot timing')
Feedback.Changed(view,{kind='damage',amount=3,target=actor,attackHit=true,impact={damageColor='',shot=1,critical=true}})
assert(view.hits[4][2] and not view.hits[4][3],'Critical presentation hook')
assert(#view.damage==4 and view.damage[4][4]==true,'Critical metadata selects the special number effect')
Feedback.Changed(view,{kind='damage',amount=3,target=actor,impact={damageColor='',shot=1,defeated=true}})
assert(view.hits[5][3],'Lethal periodic damage gets death feedback')
assert(#view.damage==5 and view.damage[5][4]==false,'Lethal damage does not invent a critical hit')
Feedback.Changed(view,{kind='defeated',target=actor})
Feedback.Changed(view,{kind='mount_defeated',target=actor})
assert(#view.hits==5 and #view.damage==5,'Death notifications must not duplicate their damage feedback')

-- The gameplay producer distinguishes an instant skill hit from a periodic tick.
local Effects=require('Game.Battle.GameEffects')
local def={id=1,kind='damage',duration='instant',name='test',buffId=0,chance=100,recipient='target',requiredTags={},forbiddenTags={},removeTags={},removeCategories={},affectsContainers=true,color='#BDA8E8',damageColor='',equipmentDamage=0,killEquipmentDamage=0,amount={Evaluate=function()return 5 end}}
local stats={Template=function()return{name='actor'}end,EffectVariables=function()return{}end,buffs={Find=function()return nil end}}
local emitted={}
Feedback.Changed(view,{kind='battle_started'})
local effects=Effects.New(stats,{Get=function()return def end},function(kind,message,sourceId,targetId,amount,target,attackHit,impact)
    emitted[#emitted+1]={kind,message,sourceId,targetId,amount,target,attackHit,impact}
    Feedback.Changed(view,{kind=kind,sourceId=sourceId,targetId=targetId,amount=amount,target=target,attackHit=attackHit,impact=impact})
end)
local target={Id=3,HP=20,MaxHP=20,Effects={Count=0},Q=1,R=0}
function target:Damage(value)local loss=math.min(value,self.HP);self.HP=self.HP-loss;return loss end
local source={Id=1,Q=0,R=0,HP=100,MaxHP=100}
effects:ApplyPrepared(effects:Prepare(1,source,target,{name='attack',damageScale=1}),{shot=2,critical=true})
assert(emitted[1][7]==true and emitted[1][5]==5 and emitted[1][8].shot==2 and emitted[1][8].critical and not emitted[1][8].defeated)
effects:Execute(def,target,2,1,'source','periodic')
assert(not emitted[2][7] and emitted[2][5]==2)
assert(target.HP==13,'Presentation metadata must not change damage')
effects:Execute(def,target,50,1,'source','fatal',source,true,{shot=3})
assert(emitted[3][8].shot==3 and emitted[3][8].defeated,'Lethal shot carries death strength at its own timing')
assert(#view.damage==3 and view.damage[1][4] and view.damage[2][2]==2 and view.damage[3][2]==13,'Numbers use real settled damage, including clipped overkill and periodic ticks')
local mount={Id=90,HP=3,MaxHP=3,Effects={Count=0}}
function mount:Damage(value)local loss=math.min(value,self.HP);self.HP=self.HP-loss;return loss end
local rider={Id=4,HP=20,MaxHP=20,MountedAnimal=mount,Effects={Count=0}}
function rider:Damage(value)local loss=mount:Damage(value);if mount.HP==0 then self.MountedAnimal=nil end;return loss end
effects:Execute(def,mount,1,1,'source','mount periodic')
assert(#view.damage==4 and view.damage[4][1]==90 and view.damage[4][2]==1,'A periodic mount target retains its health identity for HUD binding')
effects:Execute(def,rider,5,1,'source','dismount',source,true,{shot=2})
assert(emitted[#emitted][1]=='damage' and emitted[#emitted][8].defeated and emitted[#emitted][8].shot==2,'Mount death upgrades the rider hit once')
assert(#view.damage==5 and view.damage[5][1]==4 and view.damage[5][2]==2 and view.damage[5][3]==2,'Mount defeat produces only its actual absorbed damage on the rider UI')
assert(rider.HP==20 and rider.MountedAnimal==nil,'Damage feedback does not transfer discarded mount overkill to the rider')

-- Exercise the real synchronous shot loop with an intentional missed second bullet.
local battle=require('Game.Battle.BattleSystem')()
local skill={id=8,name='burst',target='enemy',shots=3,effectIds={1},maxTargets=1,action='main',cost=1,cooldownTurns=0,actionTemplate=2,hitChance=50,damageScale=1}
stats.animals={rule={tameSkillId=999},bySkill={}};stats.equipment={Consume=function()end}
battle.stats=stats;battle.gameEffects=effects;battle.board={}
function battle:CanUseSkill()return true end
function battle:Active()return source end
function battle:FindUnit()return target end
function battle:Skill()return skill end
function battle:CheckWinner()end
function source:SpendAction()end
function source:SetCooldown()end
function source:RecordAction()end
local rolls={0,99,0};local roll=0;battle.data={RollPercent=function()roll=roll+1;return rolls[roll] end}
local misses=0;function battle:Emit(kind)if kind=='miss' then misses=misses+1 end;Feedback.Changed(view,{kind=kind})end
target.HP=100;emitted={};Feedback.Changed(view,{kind='battle_started'})
assert(battle:TrySkill(8,3));assert(#emitted==2 and misses==1 and target.HP==90)
assert(emitted[1][8].shot==1 and emitted[2][8].shot==3,'Missing bullet retains its slot rather than squeezing the burst')
assert(#view.damage==2 and view.damage[1][2]==5 and view.damage[2][2]==5 and view.damage[1][3]==1 and view.damage[2][3]==3,'The real burst loop shows only hit bullets and preserves the missed timing slot')
local prepare,apply=effects.Prepare,effects.ApplyPrepared;local applied=0
function effects:Prepare(id,owner,victim,ability,distance)
    if id==800 then return {definition={id=800,kind='apply_buff'},target=victim}end
    return prepare(self,id,owner,victim,ability,distance)
end
function effects:ApplyPrepared(plan,impact)
    if plan.definition.id==800 then applied=applied+1;return true end
    return apply(self,plan,impact)
end
skill.effectIds={1,800};roll=0;misses=0;target.HP=100
assert(battle:TrySkill(8,3) and applied==2 and misses==1 and roll==3,'On-hit buffs must share the hit result and never apply on a missed bullet')
effects.Prepare=prepare;effects.ApplyPrepared=apply
CS=CS or {};CS.ProjectY=CS.ProjectY or {};CS.ProjectY.UI=CS.ProjectY.UI or {}
local statuses={}
CS.ProjectY.UI.StatusFeedback={Queue=function(owner,id,text,color,shot)assert(owner==view);statuses[#statuses+1]={id,text,color,shot}end}
CS.ProjectY.UI.DamageFeedback={Queue=function(owner,id,amount,shot,critical,color)assert(owner==view);owner:QueueDamage(id,amount,shot,critical,color)end}
def.damageColor='#F4A160';target.HP=30
effects:ApplyPrepared(effects:Prepare(1,source,target,{name='fire',damageScale=1}),{shot=2,critical=true})
assert(view.damage[#view.damage][5]=='#F4A160' and view.damage[#view.damage][4],'Direct effect color survives critical presentation')
effects:Execute(def,target,3,1,'source','bleeding',nil,false,{damageColor='#FF3B42'},true)
assert(view.damage[#view.damage][5]=='#FF3B42','Buff color takes precedence over a reused action color')
def.damageColor='';effects:Execute(def,target,2,1,'source','legacy poison',nil,false,nil,true)
assert(view.damage[#view.damage][5]==def.color,'Legacy periodic damage inherits its status color')
effects:Execute(def,target,1,1,'source','normal',nil,true,{shot=1})
assert(view.damage[#view.damage][5]==nil,'Uncolored attacks retain the original normal/critical styles')
local damageCount,hitCount=#view.damage,#view.hits
Feedback.Changed(view,{kind='effect_added',targetId=12,impact={statusName='燃烧',color='#F4A160',stacks=1,shot=1}})
Feedback.Changed(view,{kind='effect_added',targetId=12,impact={statusName='中毒',color='#A6CD65',stacks=2,shot=1}})
Feedback.Changed(view,{kind='effect_removed',targetId=12})
assert(#statuses==2 and statuses[1][2]=='燃烧' and statuses[2][2]=='中毒 ×2' and statuses[2][3]=='#A6CD65')
assert(#view.damage==damageCount and #view.hits==hitCount,'Status text must not create damage numbers or camera shake')
-- The real widget lifecycle waits for the number even after the health trail completes.
local Health=require('UI.Widget.HudHealth')
local retired=false
local widget={retiring=true,view={HealthAnimation={IsAnimating=false},DamageNumbers={IsAnimating=true}},SetData=function(_,row)assert(row==nil);retired=true end}
Health.Tick(widget);assert(not retired,'A pending or active number keeps the dying head bar alive')
widget.view.DamageNumbers.IsAnimating=false
Health.Tick(widget);assert(retired,'The head bar retires after both animations finish')
print('battle_feedback: damage numbers/actual amount/burst/miss/critical/death/periodic/mount/reset passed')
