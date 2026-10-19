-- Event settlement uses the real config, EventSystem, CombatStats and GameEffects.
-- Only native actor/inventory/clock state is adapted; no Editor or persistent saves.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})

local function collection()
    local value={rows={},Count=0,next=1,Revision=0}
    function value:GetAt(index)return assert(self.rows[index+1])end
    function value:Find(id)for _,row in ipairs(self.rows)do if row.EffectId==id then return row end end end
    function value:ById(id)for _,row in ipairs(self.rows)do if row.Id==id then return row end end;error('Missing effect instance')end
    function value:Add(id,source,name,amount,duration)
        local row={Id=self.next,EffectId=id,SourceId=source,SourceName=name,Amount=amount,Remaining=duration,Elapsed=0,Stacks=1}
        self.next=self.next+1;self.rows[#self.rows+1]=row;self.Count=#self.rows;self.Revision=self.Revision+1;return row
    end
    function value:Refresh(id,source,name,amount,duration,max,stack)
        local row=self:ById(id);row.SourceId=source;row.SourceName=name;row.Amount=amount
        row.Remaining=duration;row.Elapsed=0;row.Stacks=stack and math.min(max,row.Stacks+1) or 1;self.Revision=self.Revision+1
    end
    function value:Advance(id,period)
        local row=self:ById(id);row.Elapsed=period>0 and (row.Elapsed+1)%period or 0
        if row.Remaining>0 then row.Remaining=row.Remaining-1 end;self.Revision=self.Revision+1
    end
    function value:Remove(id)
        for index,row in ipairs(self.rows)do
            if row.Id==id then table.remove(self.rows,index);self.Count=#self.rows;self.Revision=self.Revision+1;return end
        end
        error('Missing effect removal')
    end
    return value
end
local state={}
function state.Configure(row,ids,amounts,expiry,nextTick)
    row.ids={table.unpack(ids)};row.amounts={table.unpack(amounts)};row.expiry=expiry;row.nextTick=nextTick
end
function state.Amount(row,id)for i,value in ipairs(row.ids)do if value==id then return row.amounts[i]end end;error('Missing component')end
function state.Count(row)return #row.ids end
function state.EffectAt(row,index)return row.ids[index+1]end
function state.ExpiresAt(row)return row.expiry end
function state.NextTickAt(row)return row.nextTick end
function state.AdvanceTick(row,period)row.nextTick=row.nextTick+period end
CS={ProjectY={Data={GameBuffState=state}}}
local stats=require('Game.Battle.CombatStats')(config)
local emptyGrowth=assert(loadfile('Tools/Tests/growth_empty.lua'))()
local function actor(id,hp)
    local value={Id=id,TemplateId=1,Team=1,TraitCount=0,Guard=0,Effects=collection(),Growth=emptyGrowth(),Experience=0}
    value.MaxHP=stats:MaximumHP(value);value.HP=hp
    function value:HasTrait()return false end
    function value:RemoveTrait()return false end
    function value:Damage(amount)local loss=math.min(amount,self.HP);self.HP=self.HP-loss;return loss end
    function value:Heal(amount)
        if self.HP==0 then return 0 end
        local gain=math.min(amount,self.MaxHP-self.HP);self.HP=self.HP+gain;return gain
    end
    function value:SetMaxHP(maximum)
        self.HP=self.HP==0 and 0 or math.max(1,math.min(maximum,self.HP+maximum-self.MaxHP));self.MaxHP=maximum
    end
    function value:Restore()self.HP=self.MaxHP end
    return value
end
local choices=config:GetTable('AdventureChoiceTable')
local function fingerprint(value,seen)
    if type(value)~='table' then return type(value)..':'..tostring(value) end
    seen=seen or {};if seen[value]then return '<shared>'end;seen[value]=true
    local keys={};for key in pairs(value)do keys[#keys+1]=key end
    table.sort(keys,function(a,b)return type(a)..tostring(a)<type(b)..tostring(b)end)
    local out={'{'};for _,key in ipairs(keys)do out[#out+1]=fingerprint(key,seen)..'='..fingerprint(value[key],seen)end
    out[#out+1]='}';return table.concat(out,'|')
end
local function configSnapshot()
    return fingerprint({choices:All(),config:GetTable('AdventureEventTable'):All(),config:GetTable('CombatEffectTable'):All(),config:GetTable('BuffTable'):All()})
end
local originalConfig=configSnapshot()

local function fixture()
    local env={now=120,clockCalls=0,impacts={},grants={},grantCalls=0,spendCalls=0,records={},room=true}
    env.party={actor(1,20),actor(2,20),actor(3,0)}
    local data={Phase='map',PartyCount=3,resolveCalls=0,visited={}}
    function data:GetPartyAt(index)return assert(env.party[index+1])end
    function data:HasVisited(id)return self.visited[id]==true end
    function data:BeginEvent(site,event)assert(self.Phase=='map');self.Phase='event';self.SiteId=site;self.EventId=event end
    function data:SetEventContext(id,location)self.EventActorId=id;self.EventLocation=location end
    function data:ResolveChoice(id)
        assert(self.Phase=='event');self.Phase='resolving';self.ChoiceId=id;self.resolveCalls=self.resolveCalls+1;self.visited[self.SiteId]=true
    end
    function data:Record(...)env.records[#env.records+1]={...}end
    env.data=data
    local player={Coins=100}
    function player:TrySpendCoins(amount)
        env.spendCalls=env.spendCalls+1;if self.Coins<amount then return false end;self.Coins=self.Coins-amount;return true
    end
    function player:AddCoins(amount)self.Coins=self.Coins+amount end
    env.player=player
    local effects=require('Game.Battle.GameEffects').New(stats,config:GetTable('CombatEffectTable'),function(kind,_,_,target,amount,_,_,impact)
        env.impacts[#env.impacts+1]={kind=kind,target=target,amount=amount,impact=impact}
    end,{roll=function()return 0 end,minutes=function()return env.now end})
    env.effects=effects
    local chronicle=require('Game.Progression.Chronicle').New(config,data,stats)
    local growth={rules=stats.growth,chronicle=chronicle}
    function growth:Actor(id)for _,value in ipairs(env.party)do if value.Id==id then return value end end end
    function growth:AddExperience(value,amount)value.Experience=value.Experience+amount end
    local equipment={rules={items=config:GetTable('EquipmentItemTable')}}
    function equipment:CanGrant()return env.room end
    function equipment:Grant(id,count)
        assert(env.room);env.grantCalls=env.grantCalls+1;env.grants[id]=(env.grants[id] or 0)+count;return true
    end
    local narrative={}
    function narrative:AdvanceMinutes(minutes)
        assert(data.Phase=='resolving','Choice must reject repeated submissions before advancing time')
        env.clockCalls=env.clockCalls+1;env.now=env.now+minutes
        for _,value in ipairs(env.party)do effects:TickWorldActor(value,env.now)end
    end
    local systems={Config=config,Battle={stats=stats,gameEffects=effects},Growth=growth,Equipment=equipment,Adventure={narrative=narrative}}
    local events=require('Game.Adventure.EventSystem')()
    events:OnInit({systems={Get=function(_,name)return assert(systems[name],name)end},services={Adventure=data,Player=player}})
    env.events=events
    function env:Begin(id)assert(events:Begin({id=id,eventId=id,name='测试道路'}))end
    return env
end
local function unchangedBeforeChoice(env,coins,hp)
    assert(env.data.Phase=='event' and env.data.resolveCalls==0 and env.player.Coins==coins)
    assert(env.spendCalls==0 and env.clockCalls==0 and env.grantCalls==0 and #env.records==0 and #env.impacts==0)
    for i,value in ipairs(env.party)do assert(value.HP==hp[i] and value.Effects.Count==0)end
end
local function rejectDuplicate(env,id)
    local before=fingerprint({env.now,env.clockCalls,env.player.Coins,env.spendCalls,env.grants,env.grantCalls,env.records,env.impacts,
        env.data.resolveCalls,env.party[1].HP,env.party[2].HP,env.party[3].HP,env.party[1].Experience,env.party[2].Experience,
        env.party[1].Effects.rows,env.party[2].Effects.rows,env.party[3].Effects.rows})
    local ok,reason=env.events:Choose(id);assert(ok==false and reason~='')
    assert(before==fingerprint({env.now,env.clockCalls,env.player.Coins,env.spendCalls,env.grants,env.grantCalls,env.records,env.impacts,
        env.data.resolveCalls,env.party[1].HP,env.party[2].HP,env.party[3].HP,env.party[1].Experience,env.party[2].Experience,
        env.party[1].Effects.rows,env.party[2].Effects.rows,env.party[3].Effects.rows}),'Duplicate choice changed gameplay state')
end

local env=fixture();env.player.Coins=15;env:Begin(217)
assert(not env.events:Choose(2172));unchangedBeforeChoice(env,15,{20,20,0})
env=fixture();env.room=false;env:Begin(210)
assert(not env.events:Choose(2101));unchangedBeforeChoice(env,100,{20,20,0})
env=fixture();env:Begin(217);env.party[2].TemplateId=2147483647
local ok=pcall(function()env.events:Choose(2172)end)
assert(not ok,'Invalid second target must fail real effect preparation')
unchangedBeforeChoice(env,100,{20,20,0})
print('PASS coin/inventory requirements and effect preparation fail before charging, state transition or partial effects')

for _,sample in ipairs({{201,2011,5},{217,2171,40}})do
    env=fixture();env:Begin(sample[1]);assert(env.events:Choose(sample[2]))
    assert(env.now==120+sample[3] and env.clockCalls==1 and env.data.resolveCalls==1)
    for i=1,2 do
        local value=env.party[i];local buff=assert(value.Effects:Find(10007))
        assert(state.ExpiresAt(buff)==env.now+60 and state.NextTickAt(buff)==env.now+10,'Long buff must start after the event time cost')
        assert(value.HP==20,'Fresh buff must not retroactively heal during the event')
        env.effects:ValidateSaved(value)
    end
    assert(env.party[3].Effects.Count==0 and env.party[3].HP==0,'Dead members must not receive the new buff')
    rejectDuplicate(env,sample[2])
    env.now=env.now+9;env.effects:TickWorldActor(env.party[1],env.now);assert(env.party[1].HP==20)
    env.now=env.now+1;env.effects:TickWorldActor(env.party[1],env.now);assert(env.party[1].HP==24)
end
print('PASS simple/complex event clocks advance once; the full 60-minute regeneration begins after the event cost')

env=fixture();env:Begin(217);assert(env.events:Choose(2172))
assert(env.player.Coins==84 and env.clockCalls==1 and env.now==130 and env.party[1].HP==26 and env.party[2].HP==26 and env.party[3].HP==0)
assert(#env.impacts==2 and env.impacts[1].kind=='heal' and env.impacts[2].kind=='heal')
rejectDuplicate(env,2172)
env=fixture();env:Begin(218);assert(env.events:Choose(2182))
assert(env.party[1].HP==26 and env.party[2].HP==20 and env.party[3].HP==0 and #env.impacts==1)
assert(env.party[1].Experience==choices:Get(2182).experience and env.party[2].Experience==0)
rejectDuplicate(env,2182)
print('PASS party and subject outcomes heal only the intended living recipients and charge once')

env=fixture();env:Begin(210);assert(env.events:Choose(2101))
assert(env.party[1].HP==16 and env.party[2].HP==20 and #env.impacts==1 and env.impacts[1].kind=='damage')
assert(env.now==130 and env.clockCalls==1 and env.grants[506]==1 and env.grantCalls==1)
rejectDuplicate(env,2101)
print('PASS event damage, accessory reward, experience and elapsed time cannot repeat after the choice resolves')

-- Compose existing configured atoms in a private choice copy to exercise lethal ordering.
-- Neither the real choice nor its effect array is changed.
env=fixture();env.party[1].HP=4
local composed={};for key,value in pairs(choices:Get(2011))do composed[key]=value end
composed.effectIds={1212,807}
env.events.choices={Get=function(_,id)if id==2011 then return composed end;return choices:Get(id)end}
env:Begin(201);assert(env.events:Choose(2011))
assert(env.party[1].HP==0 and env.party[1].Effects.Count==0,'Lethal first atom must stop later buffs on that target')
assert(env.party[2].HP==16 and env.party[2].Effects:Find(10007),'Other living party targets must still finish their programs')
assert(env.party[3].HP==0 and env.party[3].Effects.Count==0)
for _,impact in ipairs(env.impacts)do assert(not (impact.target==1 and impact.kind=='effect_added'))end
rejectDuplicate(env,2011)
assert(configSnapshot()==originalConfig,'Event settlement must not mutate shared choice/effect/buff configuration')
print('PASS lethal damage stops subsequent status application per target; all shared config remains unchanged')
config:OnShutdown()
