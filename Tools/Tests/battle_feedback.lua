package.path='Lua/?.lua;'..package.path
local Feedback=require('Game.Battle.BattleFeedback')
local view={rows={},hits={},clears=0}
function view:Clear()self.rows={};self.hits={};self.clears=self.clears+1 end
function view:QueueHealth(...)self.rows[#self.rows+1]={...}end
function view:QueueImpact(...)self.hits[#self.hits+1]={...}end
local actor={Id=12,HP=60,MaxHP=100,Team=2}
Feedback.Changed(view,{kind='damage',amount=40,target=actor,attackHit=true,impact={shot=1}})
assert(view.rows[1][1]==12 and view.rows[1][2]==12 and view.rows[1][3]==.6 and #view.hits==1)
actor.Team=1
Feedback.Changed(view,{kind='damage',amount=4,target=actor,attackHit=true,impact={shot=1}})
assert(#view.hits==2,'Both teams receive hit feedback')
Feedback.Changed(view,{kind='damage',amount=3,target=actor,impact={shot=1}})
assert(#view.hits==2,'Periodic damage must not shake')
Feedback.Changed(view,{kind='heal',amount=3,target=actor})
assert(#view.hits==2,'Healing must not shake')
Feedback.Changed(view,{kind='miss'})
Feedback.Changed(view,{kind='damage',amount=0,target=actor,attackHit=true})
assert(#view.rows==4 and #view.hits==2,'Miss and zero damage must not schedule feedback')
actor.MountedAnimal={Id=90,HP=10,MaxHP=50}
Feedback.Changed(view,{kind='damage',amount=3,target=actor,attackHit=true,impact={shot=1}})
assert(view.rows[5][1]==12 and view.rows[5][2]==90 and view.rows[5][3]==.2,'Mount health uses rider UI identity')
Feedback.Changed(view,{kind='battle_started'})
assert(#view.rows==0 and #view.hits==0 and view.clears==1)
for shot=1,3 do Feedback.Changed(view,{kind='damage',amount=3,target=actor,attackHit=true,impact={shot=shot}}) end
assert(#view.hits==3 and view.hits[1][1]==1 and view.hits[2][1]==2 and view.hits[3][1]==3,'Burst damage must not be merged')
Feedback.Changed(view,{kind='damage',amount=3,target=actor,attackHit=true,impact={shot=1,critical=true}})
assert(view.hits[4][2] and not view.hits[4][3],'Critical presentation hook')
Feedback.Changed(view,{kind='damage',amount=3,target=actor,impact={shot=1,defeated=true}})
assert(view.hits[5][3],'Lethal periodic damage gets death feedback')
Feedback.Changed(view,{kind='defeated',target=actor})
Feedback.Changed(view,{kind='mount_defeated',target=actor})
assert(#view.hits==5,'Death notifications must not duplicate their damage feedback')

-- The gameplay producer distinguishes an instant skill hit from a periodic tick.
local Effects=require('Game.Battle.GameEffects')
local def={id=1,kind='damage',duration='instant',name='test',amount={Evaluate=function()return 5 end}}
local stats={Template=function()return{name='actor'}end,EffectVariables=function()return{}end}
local emitted={}
local effects=Effects.New(stats,{Get=function()return def end},function(...)emitted[#emitted+1]={...}end)
local target={Id=3,HP=20,MaxHP=20,Effects={Count=0},Q=1,R=0}
function target:Damage(value)local loss=math.min(value,self.HP);self.HP=self.HP-loss;return loss end
local source={Id=1,Q=0,R=0}
effects:ApplyPrepared(effects:Prepare(1,source,target,{name='attack',damageScale=1}),{shot=2,critical=true})
assert(emitted[1][7]==true and emitted[1][5]==5 and emitted[1][8].shot==2 and emitted[1][8].critical and not emitted[1][8].defeated)
effects:Execute(def,target,2,1,'source','periodic')
assert(not emitted[2][7] and emitted[2][5]==2)
assert(target.HP==13,'Presentation metadata must not change damage')
effects:Execute(def,target,50,1,'source','fatal',source,true,{shot=3})
assert(emitted[3][8].shot==3 and emitted[3][8].defeated,'Lethal shot carries death strength at its own timing')
local mount={Id=90,HP=2,Effects={Count=0}}
local rider={Id=4,HP=20,MountedAnimal=mount,Effects={Count=0}}
function rider:Damage()mount.HP=0;self.MountedAnimal=nil;return 2 end
effects:Execute(def,rider,5,1,'source','dismount',source,true,{shot=2})
assert(emitted[#emitted][1]=='damage' and emitted[#emitted][8].defeated and emitted[#emitted][8].shot==2,'Mount death upgrades the rider hit once')

-- Exercise the real synchronous shot loop with an intentional missed second bullet.
local battle=require('Game.Battle.BattleSystem')()
local skill={name='burst',shots=3,effectIds={1},maxTargets=1,action='main',cost=1,cooldownTurns=0,actionTemplate=2,hitChance=50,damageScale=1}
stats.animals={rule={tameSkillId=999},bySkill={}};stats.equipment={Consume=function()end}
battle.stats=stats;battle.gameEffects=effects
function battle:CanUseSkill()return true end
function battle:Active()return source end
function battle:FindUnit()return target end
function battle:Skill()return skill end
function battle:CheckWinner()end
function source:SpendAction()end
function source:SetCooldown()end
function source:RecordAction()end
local rolls={0,99,0};local roll=0;battle.data={RollPercent=function()roll=roll+1;return rolls[roll] end}
local misses=0;function battle:Emit(kind)if kind=='miss' then misses=misses+1 end end
target.HP=100;emitted={}
assert(battle:TrySkill(8,3));assert(#emitted==2 and misses==1 and target.HP==90)
assert(emitted[1][8].shot==1 and emitted[2][8].shot==3,'Missing bullet retains its slot rather than squeezing the burst')
print('battle_feedback: per-hit burst/miss/critical/death/periodic/mount/reset passed')
