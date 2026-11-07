package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)local f=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local bytes=f:read('*a');f:close();return bytes end}})
local state,ms={},{}
CS={ProjectY={Data={DeathDoorState=state,MoraleState=ms}}}
function state.Enabled(a)return a.enabled end
function state.Dead(a)return a.dead end
function state.Survived(a)return a.survived end
function state.Survive(a)assert(a.HP==0 and a.entered and not a.dead);a.survived=a.survived+1 end
function state.Kill(a)a.dead=true;a.entered=false end
function ms.Active(a)return a.moraleActive end
function ms.Begin(a,m,c,s)a.maximum=m;a.current=c;a.moraleActive=true end
local stats={Template=function()return {name='Fixture'}end}
stats.morale={Projection=function(_,a)return a.current,a.maximum end,Stage=function()return 0 end,
    Change=function(_,battle,a,delta)a.current=math.max(0,math.min(a.maximum,a.current+delta))end}
local rules=require('Game.Battle.DeathDoor').New(config,stats)
local function actor(current)return {enabled=true,dead=false,entered=true,survived=0,HP=0,maximum=100,current=current,moraleActive=true}end
local checks,rolls,raw={},0,99
local effects={battle={},roll=function()rolls=rolls+1;return raw end,Notify=function(_,kind,message,source,target,amount,hit,data)checks[#checks+1]={kind=kind,impact=data}end}
local a=actor(100)
rules:Resolve(effects,a,5,false,7,2);assert(rolls==0 and checks[1].kind=='death_door_entered','First lethal hit must not roll')
assert(select(2,rules:Odds(100,100))==10 and select(2,rules:Odds(75,100))==30 and select(2,rules:Odds(0,100))==90)
local last=0;for current=100,0,-1 do local _,chance=rules:Odds(current,100);assert(chance>=last and chance%5==0);last=chance end
local deaths=0
for value=0,99 do
    raw=value;a=actor(100);rules:Resolve(effects,a,0,true,1,2)
    if a.dead then deaths=deaths+1 else assert(a.HP==0 and a.current==60 and a.survived==1)end
end
assert(deaths==10 and rolls==100,'Full-morale D20 must represent exactly ten percent death')
raw=99;a=actor(100);rules:Resolve(effects,a,0,true,1,2)
assert(rules:Penalty(a)==10 and rules:Attribute(a,'strength',20)==18 and rules:Attribute(a,'vitality',20)==20 and rules:Attribute(a,'courage',40)==40)
local _,chance=rules:Odds(a.current,a.maximum);assert(chance==45,'Survival morale loss must raise the next death chance')
for i=1,7 do rules:Resolve(effects,a,0,true,1,2)end
assert(a.current==0 and rules:Penalty(a)==50 and not a.dead,'Penalty must cap, while safe D20 faces remain possible')
local before=rolls;rules:Resolve(effects,a,0,true,0,2);a.HP=1;rules:Resolve(effects,a,2,true,1,2)
a.HP=0;a.enabled=false;rules:Resolve(effects,a,5,false,20,2);assert(rolls==before,'Zero damage, nonlethal damage and ordinary enemies must not roll')
local request=require('Game.Presentation.DiceChecks').FromBattleEvent(checks[#checks])
assert(#request.dice==1 and request.dice[1].kind=='D20' and request.dice[1].value==20 and request.passed)
print('death_door_core: first-hit protection, exact D20 odds, monotonic risk, survival penalty, zero-damage guards and settled D20 presentation passed')
