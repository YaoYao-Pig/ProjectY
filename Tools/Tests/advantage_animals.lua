-- Real animal rules and configuration; isolate only the C# state and its owned random stream.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local state={}
function state.Modifier(target)return target.modifier end
function state.Pending(target)return target.pending end
function state.Consume(target)
    target.pending=false;target.modifier=0;target.consumed=target.consumed+1
end
CS={ProjectY={Data={AnimalSpeechState=state,AnimalCompanionState={Bound=function(source)return source.MountedAnimal end}}}}
local animals=require('Game.Animals.AnimalRules').New(config)
local stats={Get=function(_,source,attribute)return source[attribute]end}
local function hero(id)
    local source={Id=id,HP=40,Team=1,animalAffinity=5,charisma=3}
    function source:TameAndRide(target,bond)
        self.MountedAnimal=target;target.AnimalOwnerId=self.Id;target.AnimalBond=bond
    end
    return source
end
local function animal(modifier,draws)
    local target={TemplateId=201,HP=40,MaxHP=40,Team=0,AnimalOwnerId=0,TameRetryTurns=0,
        pending=modifier~=0,modifier=modifier,consumed=0,draws=0}
    function target:RollAnimalPercent()self.draws=self.draws+1;return assert(draws[self.draws],'Unexpected extra animal roll')end
    function target:DelayTaming(turns)self.TameRetryTurns=turns end
    return target
end
local function near(actual,expected)assert(math.abs(actual-expected)<1e-9,tostring(actual)..' ~= '..tostring(expected))end

-- Any legacy positive result denotes the same advantage; it cannot also add percentage points.
for _,modifier in ipairs({15,25,35,100})do
    local target=animal(modifier,{4300,4299})
    local chance,values=animals:TameChance(hero(1),target,stats)
    near(chance,67.51);assert(values.baseChance==43 and values.communication==0)
    assert(#values.advantageSources==1 and values.advantageSources[1]=='animal_speech')
    near(animals:TameChance(hero(2),target,stats),chance)
    assert(target.draws==0 and target.consumed==0 and target.pending,'A preview must preserve the pending result')
    local owner=hero(2)
    local success,settledChance,roll,settledValues,result=animals:Tame(owner,target,stats)
    assert(success and owner.MountedAnimal==target and target.AnimalOwnerId==2)
    near(settledChance,chance);near(roll,42.99)
    assert(settledValues.baseChance==43 and result.chance==43 and result.threshold==57)
    assert(result.rolls[1]==57 and result.rolls[2]==57.01 and result.selectedIndex==2 and result.roll==57.01)
    assert(result.passed and result.rollComparison=='greater' and result.rollConvention=='inclusive' and result.precision==100)
    assert(target.draws==2 and target.consumed==1 and not target.pending and target.modifier==0)
end
print('PASS legacy positive results, party sharing, non-consuming preview and second-roll success without percentage bonus')

local failed=animal(15,{4300,9999})
local ok,chance,roll,values,result=animals:Tame(hero(1),failed,stats)
assert(not ok and failed.TameRetryTurns==3 and failed.draws==2 and failed.consumed==1)
assert(result.selectedIndex==1 and result.roll==57 and not result.passed)
assert(not failed.pending and failed.modifier==0 and not animals:CanTame(hero(2),failed))
assert(animals:TameChance(hero(2),failed,stats)==43,'Failed advantage is consumed instead of persisting through retry delay')
local unrelated=animal(0,{4299})
assert(animals:TameChance(hero(2),unrelated,stats)==43,'Advantage belongs only to the communicated animal')
local plain,plainChance,plainRoll,plainValues,plainResult=animals:Tame(hero(3),unrelated,stats)
assert(plain and plainChance==43 and plainRoll==42.99 and plainValues.baseChance==43 and plainResult==nil and unrelated.draws==1)
assert(#plainValues.advantageSources==0)
print('PASS failed advantage consumption, animal-scoped ownership and unchanged ordinary single-roll semantics')

for _,raw in ipairs({1799,1800})do
    local target=animal(-25,{raw})
    local negativeChance,negativeValues=animals:TameChance(hero(1),target,stats)
    assert(negativeChance==18 and negativeValues.communication==-25 and negativeValues.baseChance==18 and #negativeValues.advantageSources==0)
    local passed,actualChance,actualRoll,_,resolved=animals:Tame(hero(1),target,stats)
    assert(passed==(raw==1799) and actualChance==18 and actualRoll==raw/100 and resolved==nil)
    assert(target.draws==1 and target.consumed==1 and not target.pending)
end
print('PASS failed communication retains additive penalty and exact ordinary percentile boundary')

-- Exercise the dialogue's consumer of the fifth return value, including the option preview.
function state.Target(data)return data.target end
function state.Context()return 'world' end
function state.PartyId()return 1 end
function state.Understood()return true end
function state.Touch(data)data.touched=true end
function stats:Template(target)return config:GetTable('CombatUnitTable'):Get(target.TemplateId)end
local Speech=require('Game.Animals.AnimalSpeech')
local L=require('Language')
for _,willPass in ipairs({true,false})do
    local source=hero(7);source.TemplateId=1
    local target=animal(15,willPass and {4300,4299} or {4300,9999})
    local data={target=target,lines={}}
    function data:AddDialogueLine(speaker,text)self.lines[#self.lines+1]={speaker=speaker,text=text}end
    function data:CloseDialogue()self.closed=true end
    local checks={}
    local adventure={data={PartyCount=1,GetPartyAt=function()return source end},battle={stats=stats,SkillIds=function()return {animals.rule.tameSkillId}end},
        parties={legends={byUnit={}},data={Find=function()return {FactionId=1}end,Close=function()end}},
        factions={Relation=function()return 'friendly'end},travel={data={SetPaused=function()end}},
        events={CheckResolved={Emit=function(_,check)checks[#checks+1]=check end}}}
    local speech=setmetatable({story={data=data},adventure=adventure,animals=animals,
        rules=require('Game.Animals.AnimalSpeechRules').New(config)},Speech)
    local tameChoice
    for _,row in ipairs(speech:Choices())do if row.id==-200000007 then tameChoice=row end end
    assert(tameChoice and tameChoice.available and tameChoice.text==string.format(L.AnimalSpeechTameAdvantageBy,stats:Template(source).name,67.51))
    assert(target.draws==0 and target.consumed==0)
    assert(speech:Tame(source) and #checks==1 and #checks[1].rounds==2 and checks[1].passed==willPass)
    assert(target.draws==2 and target.consumed==1,'The presentation must reuse both settled draws')
    if willPass then assert(data.closed and source.MountedAnimal==target)
    else assert(data.touched and not data.closed and data.lines[1].text==string.format(L.AnimalSpeechTameFailed,67.51,3))end
end
print('PASS world dialogue advantage preview and one settled two-round presentation for success and failure')
