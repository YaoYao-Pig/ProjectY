-- Real injury rules and exported event configuration; offline runs substitute only the C# state boundary.
package.path='Lua/?.lua;'..package.path
local native=RECRUIT_REAL_DATA==true
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local bytes=file:read('*a');file:close();return bytes end}})
if not native then
    local function part(actor,index)actor.body=actor.body or {};actor.body[index]=actor.body[index] or {damage=0,kind=0,amount=0,at=0};return actor.body[index]end
    local state={}
    function state.Revision(actor)return actor.bodyRevision or 0 end
    function state.Damage(actor,index)return part(actor,index).damage end
    function state.Kind(actor,index)return part(actor,index).kind end
    function state.Permanent(actor,index)return part(actor,index).damage==100 end
    function state.RecoveryAmount(actor,index)return part(actor,index).amount end
    function state.RecoveryAt(actor,index)return part(actor,index).at end
    function state.Injure(actor,index,kind,amount)local row=part(actor,index);row.damage=math.min(100,row.damage+amount);row.kind=kind;actor.bodyRevision=state.Revision(actor)+1 end
    function state.ScheduleRecovery(actor,index,amount,at)local row=part(actor,index);assert(row.amount==0 and amount<=row.damage);row.amount=amount;row.at=at;actor.bodyRevision=state.Revision(actor)+1 end
    function state.AdvanceRecovery(actor,now)
        local recovered=0
        for _,row in pairs(actor.body or {})do if row.amount>0 and row.at<=now then recovered=recovered+row.amount;row.damage=row.damage-row.amount;row.amount=0;row.at=0;if row.damage==0 then row.kind=0 end end end
        if recovered>0 then actor.bodyRevision=state.Revision(actor)+1 end
        return recovered
    end
    CS={ProjectY={Data={BodyHealth=state}}}
end
local state=CS.ProjectY.Data.BodyHealth
local stats=require('Game.Battle.CombatStats')(config)
local now=10
local effects=require('Game.Battle.GameEffects').New(stats,config:GetTable('CombatEffectTable'),function()end,{minutes=function()return now end,roll=function()return 0 end})
effects:Validate()
local EmptyGrowth=assert(loadfile('Tools/Tests/growth_empty.lua'))()
local function actor(id,template)
    if native then
        local value=CS.ProjectY.Data.CombatActorData(id,template)
        value:Deploy(4,0,0);value:SetMaxHP(stats:MaximumHP(value));value:Damage(value.HP-1)
        return value
    end
    local value={Id=id,TemplateId=template,Team=4,TraitCount=0,Guard=0,Effects={Count=0,Revision=0},Growth=EmptyGrowth()}
    value.MaxHP=stats:MaximumHP(value);value.HP=1
    function value:SetMaxHP(maximum)self.HP=self.HP==0 and 0 or math.max(1,math.min(maximum,self.HP+maximum-self.MaxHP));self.MaxHP=maximum end
    function value:Heal(amount)local gain=math.min(amount,self.MaxHP-self.HP);self.HP=self.HP+gain;return gain end
    return value
end
local recruit=actor(10302,920);local victim=actor(1,1)
local before={speed=stats:Get(recruit,'speed'),strength=stats:Get(recruit,'strength'),defense=stats:Get(recruit,'defense')}
local originalDamage=effects:Prepare(1,recruit,victim).amount
local binding=config:GetTable('SpecialEventTable'):Get(2)
assert(binding.npcId==302 and #binding.initialInjuryPartIds==5)
for i,id in ipairs(binding.initialInjuryPartIds)do state.Injure(recruit,config:GetTable('BodyPartTable'):Get(id).index,binding.initialInjuryTypeIds[i],binding.initialInjuryDamage[i])end
local rows=stats.injuries:Rows(recruit)
assert(rows[1].damage==0)
for i=2,6 do assert(rows[i].damage==30 and rows[i].health==70,'Real body panel must show all five wounded parts')end
assert(stats:Get(recruit,'speed')<before.speed and stats:Get(recruit,'strength')<before.strength and stats:Get(recruit,'defense')<before.defense)
assert(effects:Prepare(1,recruit,victim).amount<originalDamage,'Actual arm injuries must reduce weapon damage')
local adventure={config=config,data={Narrative={Minutes=now},Phase='map',PartyCount=1,GetPartyAt=function()return recruit end},specialEvents={byNpc={[302]=binding}},battle={gameEffects=effects}}
local recovery=require('Game.Narrative.EventRecruitRecovery')
local revision=state.Revision(recruit);local plans=recovery.Prepare(adventure,302,recruit)
assert(state.Revision(recruit)==revision and recruit.HP==1 and recruit.Effects.Count==0,'Preparing recruitment must not start recovery or create buffs')
for part=1,5 do assert(state.RecoveryAmount(recruit,part)==0)end
now=200;adventure.data.Narrative.Minutes=now
if native then recruit:Deploy(1,0,0);recruit.Growth:Initialize(1,0,0,0)
else recruit.Team=1;recruit.Growth.Initialized=true end
recovery.Apply(adventure,recruit,plans)
for _,plan in ipairs(plans)do assert(state.RecoveryAmount(recruit,plan.part)==30 and state.RecoveryAt(recruit,plan.part)==200+plan.minutes)end
print('PASS real body panel wounds, attribute/weapon penalties, read-only preparation and recovery beginning at actual recruitment')
effects:Apply(701,recruit,recruit)
assert(recruit.HP>1 and recruit.Effects.Count==0)
for _,row in ipairs(config:GetTable('CombatEffectTable'):All())do if row.kind=='remove_buffs' then effects:Apply(row.id,recruit,recruit)end end
effects:Clear(recruit,'battle_end');effects:Clear(recruit,'death')
for part=1,5 do assert(state.Damage(recruit,part)==30,'Healing and cleansing cannot erase real body wounds')end
print('PASS ordinary healing, all existing cleanses and battle/death cleanup retain real body injuries')
local story=setmetatable({data=adventure.data.Narrative,adventure=adventure},{__index=require('Game.Narrative.NarrativeSystem')})
local function tick(minute)now=minute;story.data.Minutes=minute;story:TickBuffs()end
tick(1639);assert(state.Damage(recruit,4)==30)
tick(1640);assert(state.Damage(recruit,4)==0 and state.Damage(recruit,5)==0 and state.Damage(recruit,2)==30 and stats:Get(recruit,'speed')==before.speed)
tick(3080);assert(state.Damage(recruit,2)==0 and state.Damage(recruit,3)==0 and state.Damage(recruit,1)==30 and stats:Get(recruit,'strength')==before.strength)
tick(4520);assert(state.Damage(recruit,1)==0 and stats:Get(recruit,'defense')==before.defense)
assert(recruit.Effects.Count==0)
print('PASS production Narrative clock restores legs, arms and torso after one, two and three days')
config:OnShutdown()
return recruit
