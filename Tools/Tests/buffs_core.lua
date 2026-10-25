package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)local f=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local b=f:read('*a');f:close();return b end}})
local function collection()
    local c={rows={},Count=0,next=1,Revision=0}
    function c:GetAt(i)return assert(self.rows[i+1])end
    function c:Find(id)for _,r in ipairs(self.rows)do if r.EffectId==id then return r end end end
    function c:ById(id)for _,r in ipairs(self.rows)do if r.Id==id then return r end end;error('Missing fixture instance')end
    function c:Add(id,source,name,amount,duration)
        local row={Id=self.next,EffectId=id,SourceId=source,SourceName=name,Amount=amount,Remaining=duration,Elapsed=0,Stacks=1}
        self.next=self.next+1;self.rows[#self.rows+1]=row;self.Count=#self.rows;self.Revision=self.Revision+1;return row
    end
    function c:Refresh(id,source,name,amount,duration,max,stack)local r=self:ById(id);r.SourceId=source;r.SourceName=name;r.Amount=amount;r.Remaining=duration;r.Elapsed=0;r.Stacks=stack and math.min(max,r.Stacks+1) or 1;self.Revision=self.Revision+1 end
    function c:Advance(id,period)local r=self:ById(id);r.Elapsed=period>0 and (r.Elapsed+1)%period or 0;if r.Remaining>0 then r.Remaining=r.Remaining-1 end;self.Revision=self.Revision+1 end
    function c:Remove(id)for i,r in ipairs(self.rows)do if r.Id==id then table.remove(self.rows,i);self.Count=#self.rows;self.Revision=self.Revision+1;return end end;error('Missing fixture removal')end
    return c
end
local state={}
function state.Configure(row,ids,amounts,expiry,nextTick)row.ids={table.unpack(ids)};row.amounts={table.unpack(amounts)};row.expiry=expiry;row.nextTick=nextTick end
function state.Amount(row,id)for i,value in ipairs(row.ids)do if value==id then return row.amounts[i]end end;error('Missing snapshot')end
function state.Count(row)return #row.ids end
function state.EffectAt(row,i)return row.ids[i+1]end
function state.ExpiresAt(row)return row.expiry end
function state.NextTickAt(row)return row.nextTick end
function state.AdvanceTick(row,period)row.nextTick=row.nextTick+period end
CS={ProjectY={Data={GameBuffState=state,AnimalCompanionState={Bound=function()end}}}}
local stats=require('Game.Battle.CombatStats')(config)
-- This fixture covers effect lifetimes; body injury state is exercised by armor_damage_core.
stats.injuries.ApplyAttribute=function(_,_,_,value)return value end
stats.injuries.ValidateSaved=function()end
stats.injuries.DamageHit=function(_,_,target,_,amount)return target:Damage(amount)end
local EmptyGrowth=assert(loadfile('Tools/Tests/growth_empty.lua'))()
local function actor(id)
    local a={Id=id,TemplateId=1,Team=1,TraitCount=0,Effects=collection(),Growth=EmptyGrowth()}
    a.MaxHP=stats:MaximumHP(a);a.HP=20
    function a:Damage(amount)local loss=math.min(amount,self.HP);self.HP=self.HP-loss;return loss end
    function a:Heal(amount)if self.HP==0 then return 0 end;local gain=math.min(amount,self.MaxHP-self.HP);self.HP=self.HP+gain;return gain end
    function a:SetMaxHP(maximum)self.HP=self.HP==0 and 0 or math.max(1,math.min(maximum,self.HP+maximum-self.MaxHP));self.MaxHP=maximum end
    function a:BeginTurn(ap)self.AP=ap;self.MainUsed=false;self.Moved=false end
    return a
end
local events={};local now,roll=120,99
local effects=require('Game.Battle.GameEffects').New(stats,config:GetTable('CombatEffectTable'),function(kind,_,_,target,_,_,_,impact)
    events[#events+1]={kind=kind,target=target,impact=impact}
end,{roll=function()return roll end,minutes=function()return now end})
effects:Validate()
local source=actor(1);local target=actor(2)
assert(effects:Apply(801,source,target) and target.HP==20)
for i=1,3 do effects:TickActor(target,'turn_start');assert(target.HP==20+4*i)end
assert(target.Effects.Count==0)
print('PASS regeneration ticks on configured turns, not on application, and expires exactly')

target=actor(3);effects:Apply(802,source,target);local first=target.Effects:GetAt(0).Id
effects:Apply(812,source,target)
assert(target.Effects.Count==1 and target.Effects:GetAt(0).Id==first and target.Effects:Find(10002).Stacks==2)
effects:TickActor(target,'turn_end');assert(target.HP==14)
effects:Apply(802,source,target);effects:Apply(802,source,target);assert(target.Effects:Find(10002).Stacks==3)
effects:ValidateSaved(target)
print('PASS distinct effect applications share one buff identity, capped stacks and magnitude snapshots')

for _,sample in ipairs({{802,10002,'#FF3B42'},{803,10003,'#6FCF45'},{804,10004,'#F4A160'}})do
    local victim=actor(30);effects:Apply(sample[1],source,victim);effects:TickActor(victim,'turn_end')
    local event=events[#events]
    assert(event.kind=='damage' and event.impact.damageColor==sample[3] and event.impact.periodic,'Periodic damage must carry its configured Buff color')
end
print('PASS bleeding/poison/burning ticks carry distinct configured damage colors')

target=actor(4);roll=0;local count=#events;effects:Apply(804,source,target)
assert(target.Effects.Count==0 and #events==count,'Failed proc must not emit a status popup')
roll=99;effects:Apply(804,source,target);assert(target.Effects:Find(10004))
effects:Apply(805,source,target);assert(not target.Effects:Find(10004) and target.Effects:Find(10005))
count=#events;effects:Apply(804,source,target);assert(not target.Effects:Find(10004) and #events==count)
local metadata=events[#events].impact;assert(metadata.statusName=='潮湿' and metadata.color=='#74CBE8' and metadata.stacks==1)
effects:Remove(target,target.Effects:Find(10005).Id);effects:Apply(804,source,target);assert(target.Effects:Find(10004))
print('PASS configured wet/burning exclusion, proc failure and successful-application popup metadata')

target=actor(5);effects:Apply(806,source,target)
local skipped,normal=0,0
local battle=setmetatable({data={Phase='combat',SelectTurn=function()end},stats=stats,gameEffects=effects,
    professions={BeginTurn=function()end},beasts={BeginTurn=function()end},
    Active=function()return target end,CheckWinner=function()return false end,
    Emit=function(_,kind)if kind=='turn_skipped' then skipped=skipped+1 elseif kind=='turn_started' then normal=normal+1 end end,
    EndTurn=function()effects:TickActor(target,'turn_end');return true end},{__index=require('Game.Battle.BattleSystem')})
battle:BeginTurn(0);battle:BeginTurn(0);battle:BeginTurn(0)
assert(skipped==2 and normal==1 and not stats.buffs:Skipping(target))
print('PASS stun skips exactly two whole action turns and then releases control')

target=actor(6);effects:Apply(807,source,target);local long=target.Effects:Find(10007)
assert(state.ExpiresAt(long)==180 and state.NextTickAt(long)==130)
effects:TickActor(target,'turn_start');effects:TickActor(target,'turn_end');assert(target.HP==20)
effects:Clear(target,'battle_end');assert(target.Effects:Find(10007))
now=129;effects:TickWorldActor(target,now);assert(target.HP==20)
now=130;effects:TickWorldActor(target,now);assert(target.HP==24)
now=160;effects:TickWorldActor(target,now);assert(target.HP==36)
effects:ValidateSaved(target);local row=effects:Rows(target)[1];assert(row.remaining==20 and row.timerText=='20m')
now=180;effects:TickWorldActor(target,now);assert(target.HP==math.min(target.MaxHP,44) and target.Effects.Count==0)
print('PASS persistent game-minute duration, catch-up ticks, countdown and final expiry')

local poison=stats.buffs.rows[10003];local minutePoison={};for k,v in pairs(poison)do minutePoison[k]=v end
minutePoison.clock='minutes';minutePoison.scope='persistent';minutePoison.duration='infinite';minutePoison.durationMinutes=60;minutePoison.periodMinutes=10;minutePoison.removeOnBattleEnd=false
stats.buffs.rows[10003]=minutePoison
local function catchup(step)
    local a=actor(90);a.HP=a.MaxHP-2;now=200;effects:Apply(807,source,a);effects:Apply(803,source,a)
    for minute=200+step,260,step do now=minute;effects:TickWorldActor(a,now)end
    return a.HP,a.Effects.Count
end
local batch,count=catchup(60);local incremental=catchup(10)
assert(batch==incremental and batch==stats:MaximumHP(actor(91))-2 and count==0,'Clock catch-up must interleave healing and poison in time order')
stats.buffs.rows[10003]=poison
print('PASS world-time catch-up preserves interleaved heal/damage order and health caps')

target=actor(7);local base=stats:Get(target,'strength');effects:Apply(808,source,target)
assert(stats:Get(target,'strength')>base and target.Effects:Find(10008).Remaining==-1)
for _=1,10 do effects:TickActor(target,'turn_end')end
assert(target.Effects:Find(10008));effects:Clear(target,'battle_end')
assert(not target.Effects:Find(10008) and stats:Get(target,'strength')==base)
print('PASS un-timed battle buff reuses modifier effects and clears at battle end')
local regen=stats.buffs.rows[10001];local perpetual={};for k,v in pairs(regen)do perpetual[k]=v end
perpetual.clock='infinite';perpetual.duration='infinite';perpetual.durationTurns=0;stats.buffs.rows[10001]=perpetual
target=actor(8);effects:Apply(801,source,target)
for _=1,5 do effects:TickActor(target,'turn_start')end
assert(target.Effects:Find(10001).Remaining==-1 and target.HP==math.min(target.MaxHP,40))
effects:ValidateSaved(target);effects:Clear(target,'battle_end');assert(target.Effects.Count==0);stats.buffs.rows[10001]=regen
print('PASS no-countdown battle buffs can still execute reusable periodic effects')

CS.ProjectY.Data.EquipmentConditionData={Of=function()return {Broken=false,Efficiency=1}end}
CS.ProjectY.Data.EquipmentAffixData={Of=function()return 1 end}
local giant={Id=1,ItemId=45,OwnerActorId=1,GetRune=function()return 0 end}
local equipment={WearableCount=0,Equipped=function()return giant end,Offhand=function()end,Worn=function()end}
local rules=require('Game.Equipment.EquipmentRules').New(config,equipment)
local attack=rules:Skill(source,12,stats);assert(attack.effectIds[#attack.effectIds]==806)
local learned=rules:Skill(source,101,stats);assert(learned.effectIds[#learned.effectIds]==806,'Learned physical attacks must use the actual weapon triggers too')
local support=rules:Skill(source,4,stats);for _,id in ipairs(support.effectIds)do assert(id~=806)end
assert(#config:GetTable('CombatSkillTable'):Get(12).effectIds==1,'Weapon triggers must not mutate shared skill definitions')
print('PASS weapon on-hit effects attach only to its attacks and preserve shared skill configuration')
for _,path in ipairs({'Lua/Game/Battle/BuffRules.lua','Lua/Game/Battle/BuffEffects.lua','Lua/Game/Battle/GameEffects.lua',
    'Lua/Game/Adventure/InteractionPrompt.lua','Lua/UI/Widget/HudInteraction.lua','Lua/UI/Panel/MainHudCtr.lua','Lua/Game/Narrative/NarrativeSystem.lua'})do assert(loadfile(path))end
config:OnShutdown()
