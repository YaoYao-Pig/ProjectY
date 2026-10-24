-- Settled log facts and probability observation against real formatters/effect/projectile execution.
package.path='Lua/?.lua;'..package.path
local Log=require('Game.Battle.BattleLog')
local originalRandom=math.random;math.random=function()error('Presentation must not roll randomness')end
local sourceView={name='<b>Archer</b>',team=1};local targetView={name='<color=red>Bandit</color>',team=2}
local text=Log.Format('damage','unused',sourceView,targetView,12,{actionName='<i>Fireball</i>',hpBefore=33,hpAfter=21,maxHP=50,
    defense=4,guard=2,shot=3,damageColor='#FF3B42'})
for _,part in ipairs({'#80CFE0','#F09283','#E9C580','#FF3B42','＜b＞Archer＜/b＞','＜i＞Fireball＜/i＞','21/50','（原 33）','防御','护卫','第3发','<size=15>12</size>'})do
    assert(text:find(part,1,true),'Missing formatted fact: '..part)
end
assert(not text:find('<b>Archer',1,true) and not text:find('<i>Fireball',1,true),'Metadata injected rich-text tags')
local check=Log.Format('check','unused',sourceView,targetView,0,{actionName='Fireball',checkName='Burn',chance=40,roll=39,passed=true,successLabel='Triggered'})
assert(check:find('40/100',1,true) and check:find('(40%)',1,true) and check:find('39/100',1,true) and check:find('#76D6AE',1,true))
local guaranteed=Log.Format('check','unused',sourceView,targetView,0,{chance=100,passed=true})
assert(guaranteed:find('100/100',1,true) and not guaranteed:find('掷值',1,true),'Guaranteed result must not invent a draw')
local zero=Log.Format('check','unused',sourceView,targetView,0,{chance=40,roll=0,passed=true})
assert(zero:find('<size=15>0/100</size>',1,true),'A real zero draw must remain visible')
local blocked=Log.Format('effect_blocked','unused',sourceView,targetView,0,{statusName='<size=99>Burn',reason='Wet <b>blocks</b>'})
assert(blocked:find('＜size=99＞Burn',1,true) and blocked:find('Wet ＜b＞blocks＜/b＞',1,true) and blocked:find('未生效',1,true))
assert(Log.Format('unknown','<b>literal</b>',nil,nil,0):find('＜b＞literal＜/b＞',1,true))
math.random=originalRandom
print('PASS role/action/target/result/HP/defense/guard/probability formatting, distinct colors/sizes and literal metadata escaping without RNG')

local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local f=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local b=f:read('*a');f:close();return b
end}})
local function collection()
    local c={Count=0,Revision=0,rows={},next=1}
    function c:GetAt(i)return assert(self.rows[i+1])end
    function c:Find(id)for _,r in ipairs(self.rows)do if r.EffectId==id then return r end end end
    function c:Add(id,source,name,amount,duration)
        local r={Id=self.next,EffectId=id,SourceId=source,SourceName=name,Amount=amount,Remaining=duration,Elapsed=0,Stacks=1}
        self.next=self.next+1;self.rows[#self.rows+1]=r;self.Count=#self.rows;return r
    end
    function c:Refresh(id,source,name,amount,duration,max,stack)
        for _,r in ipairs(self.rows)do if r.Id==id then
            r.SourceId=source;r.SourceName=name;r.Amount=amount;r.Remaining=duration;r.Elapsed=0;r.Stacks=stack and math.min(max,r.Stacks+1) or 1;return
        end end;error('Missing fixture refresh')
    end
    function c:Remove(id)for i,r in ipairs(self.rows)do if r.Id==id then table.remove(self.rows,i);self.Count=#self.rows;return end end;error('Missing fixture removal')end
    return c
end
CS={ProjectY={Data={GameBuffState={Configure=function(row,ids,amounts,expiry,nextTick)
    row.ids={table.unpack(ids)};row.amounts={table.unpack(amounts)};row.expiry=expiry;row.nextTick=nextTick
end,Amount=function(row,id)for i,v in ipairs(row.ids)do if v==id then return row.amounts[i]end end;error('Missing fixture amount')end}}}}
local stats=require('Game.Battle.CombatStats')(config)
local EmptyGrowth=assert(loadfile('Tools/Tests/growth_empty.lua'))()
local function actor(id,hp)
    local row={Id=id,TemplateId=id==1 and 1 or 4,Team=id==1 and 1 or 2,HP=hp or 50,MaxHP=50,Guard=3,TraitCount=0,Growth=EmptyGrowth(),Effects=collection()}
    function row:Damage(amount)local used=math.min(self.HP,amount);self.HP=self.HP-used;return used end
    function row:Heal(amount)if self.HP==0 then return 0 end;local used=math.min(amount,self.MaxHP-self.HP);self.HP=self.HP+used;return used end
    function row:SetMaxHP(value)self.MaxHP=value;self.HP=math.min(self.HP,value)end
    return row
end
local definitions=config:GetTable('CombatEffectTable');local source=actor(1)
local reports,events,draws,nextDraw={},{},0,0
local effects=require('Game.Battle.GameEffects').New(stats,definitions,function(kind,_,sourceId,targetId,amount,target,_,impact)
    events[#events+1]={kind=kind,sourceId=sourceId,targetId=targetId,amount=amount,target=target,impact=impact}
end,{roll=function()draws=draws+1;return nextDraw end,minutes=function()return 0 end,
    report=function(kind,plan,details)reports[#reports+1]={kind=kind,plan=plan,details=details}end})
local skill={name='<Fireball>',damageScale=1,proficiency='intellect'}
for _,value in ipairs({0,39,40,99})do
    local target=actor(2);reports={};events={};draws=0;nextDraw=value
    effects:ApplyPrepared(effects:Prepare(804,source,target,skill),{shot=2})
    assert(draws==1 and #reports==1,'Observation changed the number of chance draws')
    local report=reports[1];local passed=value<40
    assert(report.kind=='check' and report.details.chance==40 and report.details.roll==value and report.details.passed==passed)
    assert(report.details.actionName=='<Fireball>' and report.details.sourceName==stats:Template(source).name and report.details.shot==2)
    assert((target.Effects:Find(10004)~=nil)==passed and #events==(passed and 1 or 0),'Trigger report disagrees with application')
end
local chanceZero={};for k,v in pairs(definitions:Get(804))do chanceZero[k]=v end;chanceZero.id=99001;chanceZero.chance=0
local realDefinitions=effects.definitions
effects.definitions={Get=function(_,id)return id==99001 and chanceZero or definitions:Get(id)end}
reports={};events={};draws=0;effects:Apply(99001,source,actor(2))
assert(draws==0 and #reports==1 and reports[1].details.chance==0 and reports[1].details.roll==nil and reports[1].details.passed==false and #events==0)
effects.definitions=realDefinitions
reports={};events={};draws=0;effects:Apply(1307,source,actor(2))
assert(draws==0 and #reports==1 and reports[1].details.chance==100 and reports[1].details.roll==nil and reports[1].details.passed)
assert(events[1].kind=='effect_added' and events[1].impact.durationTurns==3)
print('PASS actual 40% trigger draws 0/39/40/99, deterministic 0/100 cases and successful status duration metadata')

local wet=actor(2);effects:Apply(1302,source,wet)
reports={};events={};draws=0;nextDraw=39;effects:ApplyPrepared(effects:Prepare(804,source,wet,skill),{shot=3})
assert(draws==1 and #reports==2 and reports[1].kind=='check' and reports[1].details.passed)
assert(reports[2].kind=='effect_blocked' and reports[2].details.statusName==stats.buffs:Get(10004).name)
assert(reports[2].details.reason:find(stats.buffs:Get(10005).name,1,true) and reports[2].details.actionName=='<Fireball>')
assert(not wet.Effects:Find(10004) and wet.Effects:Find(10005) and #events==0)
local Shots=require('Game.Battle.ProjectileCombat')
local dead=actor(2,1);reports={};events={};draws=0
Shots.ApplyActor({gameEffects=effects,stats=stats},source,{effects:Prepare(902,source,dead,skill),effects:Prepare(804,source,dead,skill)},{shot=2})
assert(dead.HP==0 and draws==0 and #reports==1 and reports[1].kind=='effect_blocked' and reports[1].details.reason=='目标已倒地')
for _,event in ipairs(events)do assert(event.kind~='effect_added')end
print('PASS wet-blocked and post-lethal status attempts report precise reasons without extra draws or status popups')

local target=actor(2);reports={};events={};draws=0
effects:ApplyPrepared(effects:Prepare(902,source,target,skill),{shot=3})
local impact=events[1].impact
assert(impact.actionName==skill.name and impact.hpBefore==50 and impact.hpAfter==47 and impact.maxHP==50)
assert(impact.defense==stats:Get(target,'defense') and impact.guard==3 and impact.shot==3 and draws==0)
print('PASS actual damage emits action, committed HP fraction, defense/guard and shot metadata without random observation')
-- Armor wear can change maximum health before the damage notification is published.
local originalMaximum=stats.MaximumHP
stats.MaximumHP=function()return 40 end
CS.ProjectY.Data.EquipmentCombatState={DamageArmor=function()return 8 end,RefreshMaximum=function(victim,maximum)victim:SetMaxHP(maximum)end}
target=actor(2);events={};effects:ApplyPrepared(effects:Prepare(1306,source,target,skill))
assert(target.MaxHP==40 and events[1].impact.maxHP==target.MaxHP,'Damage HP denominator must reflect the committed post-armor-wear maximum')
stats.MaximumHP=originalMaximum
print('PASS damage HP fraction uses committed maximum health after equipment wear')

local Battle=require('Game.Battle.BattleSystem')
local logLines,notices={},{}
local units={source,target}
local battle=setmetatable({stats=stats,data={UnitCount=2,GetUnitAt=function(_,i)return units[i+1]end,AddLog=function(_,line)logLines[#logLines+1]=line end},
    Changed={Emit=function(_,event)notices[#notices+1]=event end}},{__index=Battle})
local function chance(chance,roll,passed,label)
    battle:ChanceLog(source,target,skill,label or '命中',chance,roll,passed,{shot=2,successLabel='命中',failureLabel='落空'})
end
for _,value in ipairs({0,39,40,99})do
    local used=0
    local passed=Shots.Hit({baseHitChance=40,hitChance=20},function()used=used+1;return value end,function(roll,success)chance(40,roll,success)end)
    local notice=notices[#notices]
    assert(used==1 and passed==(value<40) and notice.impact.chance==40 and notice.impact.roll==value and notice.impact.passed==passed)
    assert(logLines[#logLines]:find('40/100',1,true) and logLines[#logLines]:find(value..'/100',1,true),'ChanceLog must show the executed conditional threshold/draw, not effective preview chance')
end
local guaranteedCalls=0
assert(Shots.Hit({baseHitChance=100},function()guaranteedCalls=guaranteedCalls+1;return 99 end,function(roll,passed)chance(100,roll,passed)end))
assert(guaranteedCalls==0 and notices[#notices].impact.roll==nil and not logLines[#logLines]:find('掷值',1,true))
local blockers={{key='zero',chance=0},{key='actor',chance=40},{key='guaranteed',chance=100}}
local used,checked=0,{}
local intercepted=Shots.Intercept({reachable=true,blockers=blockers},function()used=used+1;return 39 end,function(row,roll,passed)
    checked[#checked+1]={row=row,roll=roll,passed=passed};chance(row.chance,roll,passed,'拦截')
end)
assert(intercepted==blockers[2] and used==1 and #checked==2 and checked[1].roll==nil and not checked[1].passed and checked[2].roll==39 and checked[2].passed)
used=0;checked={}
intercepted=Shots.Intercept({reachable=true,blockers={blockers[3]}},function()used=used+1;return 0 end,function(row,roll,passed)chance(row.chance,roll,passed,'拦截')end)
assert(intercepted==blockers[3] and used==0 and notices[#notices].impact.roll==nil and not logLines[#logLines]:find('掷值',1,true))
print('PASS actual projectile hit/interception observers and Battle ChanceLog retain real thresholds/draws, stop at interception and never fabricate guaranteed draws')
local animals=require('Game.Animals.AnimalRules').New(config)
local species
for _,row in pairs(animals.byUnit)do if row.rideable then species=row;break end end
assert(species)
local trainer={HP=40,MaxHP=40};local animal={TemplateId=species.unitId,HP=30,MaxHP=40,Team=2}
local tameStats={Get=function(_,_,name)return name=='animalAffinity' and 20 or 10 end}
local probability=animals:TameChance(trainer,animal,tameStats);local draw=math.floor(probability*100)-1;local rolls=0
function animal:RollAnimalPercent()rolls=rolls+1;return draw end
function animal:DelayTaming(turns)self.delayed=turns end
function trainer:TameAndRide(target,bond)assert(target==animal and bond==species.initialBond);self.mounted=true end
local passed,threshold,actual,comparison=animals:Tame(trainer,animal,tameStats)
assert(passed and rolls==1 and trainer.mounted and threshold==probability and actual==draw/100)
assert(comparison.affinity==20 and comparison.charisma==10 and comparison.difficulty==species.tameDifficulty)
trainer.mounted=false;draw=math.floor(probability*100)
passed,threshold,actual=animals:Tame(trainer,animal,tameStats)
assert(not passed and rolls==2 and not trainer.mounted and animal.delayed==species.tameRetryTurns and actual==draw/100)
print('PASS taming exposes its original roll and contested affinity/charisma/difficulty without another random draw')
config:OnShutdown()
print('PASS battle_log_core complete')
