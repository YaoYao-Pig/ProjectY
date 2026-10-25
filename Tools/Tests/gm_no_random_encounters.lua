package.path='Lua/?.lua;'..package.path
local Travel=require('Game.Adventure.WorldTravel')
local GM=require('Game.GM.GMSystem')
local rows={{id=1,eventId=0,encounterId=204,regionTypes={},weight=3},
    {id=2,eventId=201,encounterId=0,regionTypes={},weight=7},
    {id=3,eventId=0,encounterId=205,regionTypes={2},weight=100}}
local state={Q=0,R=0,selection=1,draws=0,chance=1}
function state:Roll(maximum)
    self.draws=self.draws+1
    if maximum==100 then return self.chance end
    assert(maximum==10,'GM must preserve the eligible event pool and weights')
    return self.selection
end
local adventure={sites={{id=1}},data={Phase='map'},events={LivingParty=function()return {1}end,CanVisit=function()return true end},
    specialEvents={CanTrigger=function()return true end}}
local travel=setmetatable({adventure=adventure,data=state,rule={eventChance=100,minutesPerSecond=1,checkMinutes=1},
    map={GetCell=function()return {regionId=1}end,GetRegion=function()return {regionType=1}end},
    events={All=function()return rows end},randomEncountersDisabled=false},Travel)
adventure.travel=travel
local selected
function travel:Trigger(row)selected=row;return true end
local gm=setmetatable({adventure=adventure},GM)
local tests=0;local function test(name,run)run();tests=tests+1;print('PASS '..name)end
test('GM accepts explicit on/off only and rejects invalid values without changing state',function()
    assert(gm:SetNoRandomEncounters(1) and travel.randomEncountersDisabled)
    for _,value in ipairs({-1,2,1.5,'1',true})do assert(not gm:SetNoRandomEncounters(value) and travel.randomEncountersDisabled)end
    assert(not gm:SetNoRandomEncounters(nil));assert(gm:SetNoRandomEncounters(1))
    assert(gm:SetNoRandomEncounters(0) and not travel.randomEncountersDisabled)
    local map=travel.map;travel.map=nil;assert(not gm:SetNoRandomEncounters(1) and not travel.randomEncountersDisabled);travel.map=map
end)
test('only random battles are suppressed, preserving normal event outcomes and random draws',function()
    for _,enabled in ipairs({0,1})do
        assert(gm:SetNoRandomEncounters(enabled))
        for roll=1,10 do
            selected=nil;state.selection=roll;state.draws=0
            local fired=travel:Check()
            if enabled==1 and roll<=3 then assert(not fired and selected==nil)
            else assert(fired and selected==rows[roll<=3 and 1 or 2])end
            assert(state.draws==2,'The override must not reroll, consume extra draws or change weights')
        end
    end
    state.chance=100;travel.rule.eventChance=0;state.draws=0;selected=nil
    assert(not travel:Check() and selected==nil and state.draws==1)
    state.chance=1;travel.rule.eventChance=100
end)
test('suppressed battles do not pause travel, stop world time or leave deferred checks',function()
    assert(gm:SetNoRandomEncounters(1));state.selection=1;selected=nil
    state.Active=true;state.Paused=false;state.Speed=1;state.Progress=0;state.pending=0;state.steps=0
    function state:Step(budget)assert(budget==1);self.steps=self.steps+1;self.Active=self.steps<2;self.pending=self.pending+1;return 1 end
    function state:CheckDue()if self.pending==0 then return false end;self.pending=self.pending-1;return true end
    function state:Report()end
    local minutes,contacts,arrivals=0,0,0
    adventure.context={services={UI={IsWorldPaused=false}}};adventure.camp={data={IsOpen=false}}
    adventure.fog={Update=function()end};adventure.narrative={AdvanceMinutes=function(_,value)minutes=minutes+value end}
    adventure.factions={ObserveWorld=function()end}
    adventure.parties={data={IsOpen=false},SyncClock=function()end,ReplanPursuit=function()end,
        CheckContact=function()contacts=contacts+1;return false end}
    function travel:Arrive()arrivals=arrivals+1;return true end
    travel:Tick(2)
    assert(state.steps==2 and not state.Active and not state.Paused and minutes==2 and arrivals==1)
    assert(selected==nil and state.draws==3 and contacts==2,'Visible-party contact checks must still run')
    assert(state.pending==1,'Only the destination edge is exempt from normal encounter checks')
end)
test('turning the GM off immediately restores the next normally selected battle',function()
    assert(gm:SetNoRandomEncounters(0));state.selection=1;selected=nil
    assert(travel:Check() and selected==rows[1])
end)
print('GM no-random-encounters: '..tests..' checks passed')
