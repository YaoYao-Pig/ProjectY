package.path='Lua/?.lua;'..package.path
local Escort=require('Game.Adventure.EscortMissions')
local Parties=require('Game.Adventure.WorldParties')
local Conflicts=require('Game.Adventure.WorldConflicts')
local Travel=require('Game.Adventure.WorldTravel')
local passed=0
local function test(name,fn)fn();passed=passed+1;print('PASS '..name)end
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function moving(q)
    local t={Q=q,R=0,AnchorQ=q,AnchorR=0,Progress=0,Active=false,Paused=false,Speed=1,RemainingMinutes=0}
    function t:SetPaused(value)self.Paused=value end
    function t:Plan(qs,rs,costs)self.Active=#qs>0;self.endQ=qs[#qs];self.RemainingMinutes=costs[1] or 0;self.TargetSiteId=0 end
    function t:AdvanceRoute(minutes)
        if self.Paused or not self.Active then return 0 end
        self.RemainingMinutes=math.max(0,self.RemainingMinutes-minutes)
        if self.RemainingMinutes==0 then self.Q=self.endQ;self.AnchorQ=self.Q;self.Active=false end
        return minutes
    end
    function t:Follow(leader)
        self.Q=leader.Q;self.R=leader.R;self.AnchorQ=leader.AnchorQ;self.Progress=leader.Progress
        self.Active=leader.Active;self.RemainingMinutes=leader.RemainingMinutes;self.followed=(self.followed or 0)+1
    end
    function t:Report(message)self.Message=message end
    return t
end
local function fixture()
    local record={Id=1,DefinitionId=1,SiteId=1,NpcId=7,PartyId=0,State='active',Progress=0,RequiredCount=1}
    local data={Count=1,Revision=1,AttachedId=0}
    function data:GetAt(i)assert(i==0);return record end
    function data:Find(id)if id==1 then return record end end
    function data:SetEscort(id,party,destination)eq(id,1);record.PartyId=party;record.DestinationSiteId=destination;self.Revision=self.Revision+1 end
    function data:SetAttached(id)self.AttachedId=id;self.Revision=self.Revision+1 end
    function data:AddProgress(id,count)eq(id,1);record.Progress=record.Progress+count;self.Revision=self.Revision+1 end
    function data:Ready(id)eq(record.Progress,record.RequiredCount);record.State='ready';self.Revision=self.Revision+1 end
    function data:Fail(id)record.State='failed';self.Revision=self.Revision+1 end
    local party={Id=9,DefinitionId=1,Travel=moving(0),LivingCount=2,Defeated=false,BattleSiteId=0,Role='caravan'}
    function party:ConfigureFaction(f,q,r,role)self.FactionId=f;self.Role=role end
    function party:SetDestination(id)self.DestinationSiteId=id end
    function party:SetMission(mission,target,site,minute)self.Mission=mission;self.TargetSiteId=site end
    local definition={id=1,kind='caravan',factionId=1,encounterId=401}
    local sites={{id=1,name='起点',q=0,r=0},{id=2,name='终点',q=2,r=0}}
    local states={Count=0,Clock=0,Remainder=0,Initialized=true,IsOpen=false}
    function states:Add()self.Count=self.Count+1;return party end
    function states:Find(id)if id==9 then return party end end
    function states:Close()self.IsOpen=false end
    function states:Target(id)self.TargetId=id end
    function states:ElapsedTicks(now)
        local elapsed=self.Remainder+now-self.Clock;local ticks=math.floor(elapsed+1e-8)
        self.Remainder=math.max(0,elapsed-ticks);self.Clock=now;return ticks
    end
    local adventure={data={Seed=11,Phase='area'},sites=sites,travel={data=moving(0)},
        map={GetCell=function(_,q,r)return {q=q,r=r}end},factions={data={}},context={services={UI={IsWorldPaused=false}}},
        camp={data={IsOpen=false}},fog={Update=function()end}}
    adventure.travel.adventure=adventure
    adventure.factions.PrepareRoster=function()end
    adventure.factions.data.FindConflict=function(_,site)if site==8 then return {SiteId=8,Phase='active',PartyA=9,PartyB=10}end end
    adventure.factions.conflicts={Enter=function(_,conflict,protected)adventure.entered=conflict.SiteId;adventure.protected=protected;adventure.data.Phase='battle';return true end}
    local parties=setmetatable({adventure=adventure,map=adventure.map,sites=sites,data=states,rule={contactRadius=1},
        definitions={Get=function()return definition end},lod={homeParties={},Calibrate=function()end}},Parties)
    adventure.parties=parties
    function parties:TownRoute(site)return {sites[2]},{{q=0,r=0},{q=1,r=0},{q=2,r=0}}end
    function parties:ApplyRoute(p,path)p.Travel:Plan({2},{0},{2},0);return true end
    function parties:Plan(p,target)p.Travel:Plan({target.q},{target.r},{2},0);return true end
    function parties:Restock()end
    function parties:Near(p)return adventure.travel.data.Progress==0 and math.abs(adventure.travel.data.Q-p.Travel.Q)<=1 end
    local rule={escortPartyDefinitionId=1,escortArrivalRadius=1}
    local story={adventure=adventure,data={Minutes=0},rules={config={GetTable=function()return {Get=function()return rule end}end}}}
    adventure.narrative=story
    CS={ProjectY={Data={TownMissionData={For=function()return data end}}}}
    local escort=Escort.New(story);story.townMissions={escort=escort}
    assert(escort:Start(record,assert(escort:Prepare(1))))
    return escort,record,party,adventure
end
test('escort waits inside town, follows fixed real route after returning to map',function()
    local escort,record,party,a=fixture();eq(party.Mission,'escort_wait');assert(escort:HasActive())
    a.parties:TickParty(party,1,1);eq(party.Travel.Q,0);eq(party.Mission,'escort_wait')
    a.data.Phase='map';a.parties:TickParty(party,2,1);eq(party.Mission,'escort');eq(party.Travel.RemainingMinutes,1)
    a.parties:TickParty(party,3,1);eq(party.Travel.Q,2)
    a.parties:TickParty(party,4,1);eq(party.Travel.Q,2);eq(record.State,'active')
end)
test('remote arrival waits for player and rewards are ready only once',function()
    local escort,record,party,a=fixture();a.data.Phase='map';a.parties:TickParty(party,2,2)
    escort:Refresh();eq(record.State,'active')
    a.travel.data.Q=2;escort:Refresh();eq(record.State,'ready');eq(record.Progress,1);eq(party.Mission,'trade')
    escort:Refresh();eq(record.Progress,1);assert(not escort:HasActive())
end)
test('attachment rejects remote access, follows caravan and joins its actual conflict',function()
    local escort,record,party,a=fixture();assert(not escort:Attach(1));a.data.Phase='map'
    a.travel.data.Q=10;assert(not escort:Attach(1));a.travel.data.Q=0;assert(escort:Attach(1))
    eq(escort.data.AttachedId,1);a.parties:TickParty(party,1,1);escort:Refresh();eq(a.travel.data.RemainingMinutes,1)
    party.BattleSiteId=8;escort:Refresh();eq(a.entered,8);eq(a.protected,9);eq(a.data.Phase,'battle')
end)
test('independent escort requires player to travel to the active battle',function()
    local escort,record,party,a=fixture();a.data.Phase='map';party.BattleSiteId=8;a.travel.data.Q=10
    assert(not escort:Join(1));assert(not a.entered);a.travel.data.Q=0;assert(escort:Join(1));eq(a.entered,8)
end)
test('destroyed escort fails and detaches without completing',function()
    local escort,record,party,a=fixture();a.data.Phase='map';assert(escort:Attach(1));party.Defeated=true;party.LivingCount=0
    escort:Refresh();eq(record.State,'failed');eq(record.Progress,0);eq(escort.data.AttachedId,0)
end)
test('time skips simulate every real escort minute before fractional remainder',function()
    local escort,record,party,a=fixture();local times={};a.narrative.data.Minutes=4.25
    a.parties.lod.Advance=function(_,minute)times[#times+1]=minute end
    a.parties:SyncClock();eq(#times,4);for i=1,4 do eq(times[i],i)end
    eq(a.parties.data.Remainder,.25);a.parties:SyncClock();eq(#times,4)
end)
test('mounted player does not step or trigger a separate encounter',function()
    local escort,record,party,a=fixture();a.data.Phase='map';assert(escort:Attach(1))
    a.travel.rule={minutesPerSecond=1};setmetatable(a.travel,Travel)
    a.travel.data.Step=function()error('Attached player must not advance another route')end
    a.parties.CheckContact=function()error('Mounted encounter must include the actual caravan')end
    a.narrative.AdvanceMinutes=function(self,minutes)self.data.Minutes=self.data.Minutes+minutes end
    a.parties.lod.Advance=function(_,minute)a.parties:TickParty(party,minute,1)end
    a.travel:Tick(1);eq(party.Travel.RemainingMinutes,1);eq(a.travel.data.RemainingMinutes,1)
end)
test('protecting neutral caravan changes battle allegiance without changing diplomacy',function()
    local a={Id=9,FactionId=1};local b={Id=10,FactionId=2}
    local c=setmetatable({factions={Relation=function(_,first,second)
        if first==second then return 'allied' end
        return first~=0 and second~=0 and 'hostile' or 'neutral'
    end}},Conflicts)
    function c:Parties()return {a,b}end
    local relations,primary=c:Relations({},9)
    eq(primary,3);eq(relations[1][2],'allied');eq(relations[2][1],'allied');eq(relations[1][3],'hostile')
    eq(c.factions:Relation(0,2),'neutral')
end)
print('PASS '..passed..' escort mission checks')
