-- Real generated maps, exported configuration and travel/event rules; only persistent C# containers are replaced.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local Hex=require('Game.Map.HexGrid')
local Travel=require('Game.Adventure.WorldTravel')
local Special=require('Game.Adventure.SpecialEvents')
local Sites=require('Game.Adventure.SpecialEventSites')
local maps=require('Game.Map.MapSystem')()
maps:OnInit({systems={Get=function(_,name)assert(name=='Config');return config end}})
local definitions=config:GetTable('SpecialEventTable'):All();assert(#definitions==2)
local checks=0
local function test(name,run)run();checks=checks+1;print('PASS '..name)end
local function travelData()
    local state={stops={},StopCount=0,route={},StepCount=0,Active=false,Progress=0,Paused=false,Speed=1,TargetSiteId=0,randomCalls=0}
    function state:Reset(seed,q,r,nextId)
        self.Q=q;self.R=r;self.AnchorQ=q;self.AnchorR=r;self.nextId=nextId;self.random=seed
        self.stops={};self.StopCount=0;self.route={};self.StepCount=0;self.Active=false;self.Progress=0;self.TargetSiteId=0;self.Paused=false
    end
    function state:GetStopAt(index)return assert(self.stops[index+1])end
    function state:AddWorldStop(q,r,eventId,encounterId)
        local stop={Id=self.nextId,Q=q,R=r,EventId=eventId,EncounterId=encounterId}
        self.nextId=self.nextId+1;self.stops[#self.stops+1]=stop;self.StopCount=#self.stops;return stop
    end
    function state:AddStop(eventId,encounterId)
        self.Paused=true;return self:AddWorldStop(self.Q,self.R,eventId,encounterId)
    end
    function state:Plan(qs,rs,minutes,target)
        self.route={};for i,q in ipairs(qs)do self.route[i]={Q=q,R=rs[i],Minutes=minutes[i]}end
        self.TargetSiteId=target;self.StepCount=#self.route;self.Active=self.StepCount>0
    end
    function state:SetPaused(value)self.Paused=value end
    function state:Arrived()
        assert(not self.Active);self.TargetSiteId=0;self.route={};self.StepCount=0;self.Progress=0
    end
    function state:Roll(maximum)self.randomCalls=self.randomCalls+1;return maximum end
    return state
end
CS={ProjectY={Data={WorldTravelData={For=function(data)return data.Travel end}}}}
local function fixture(seed,map)
    map=map or maps:Generate(seed,{1,5},384)
    local camp,distance
    for _,cell in ipairs(map:GetCells())do if not cell.waterLevel and not cell.buildingId and not cell.worldTravelBlocked then
        local d=Hex.Distance(0,0,cell.q,cell.r)
        if not distance or d<distance then camp,distance=cell,d end
    end end
    camp=assert(camp,'Generated world needs a land camp')
    local facts,visited,party={},{},{{Id=1,HP=100}}
    local story={GetValue=function(_,key)return facts[key] or 0 end,SetValue=function(_,key,value)facts[key]=value end}
    local data={Seed=seed,Phase='map',Narrative=story,Travel=travelData(),PartyCount=#party,visited=visited}
    function data:GetPartyAt(index)return assert(party[index+1])end
    function data:HasVisited(id)return self.visited[id]==true end
    local events=require('Game.Adventure.EventSystem')();events.data=data;events.events=config:GetTable('AdventureEventTable')
    local campEvent=config:GetTable('AdventureDemoTable'):Get(1).campEventId
    local adventure={config=config,data=data,map=map,events=events,battle={encounters=config:GetTable('CombatEncounterTable')},
        context={services={UI={IsWorldPaused=false}}},parties={data={IsOpen=false}},camp={data={IsOpen=false}},
        sites={{id=1,eventId=campEvent,q=camp.q,r=camp.r,name=events.events:Get(campEvent).name}},entered={}}
    function adventure:EnterSite(id)
        assert(self.sites[id]);self.entered[#self.entered+1]=id;self.data.Phase='event';return true
    end
    adventure.travel=Travel.New(adventure);adventure.travel:Reset(map,adventure.sites)
    adventure.specialEvents=Special.New(adventure)
    return adventure,{map=map,sites=adventure.sites,seed=seed},facts,visited
end
local function tripSignature(state)
    local out={state.Q,state.R,state.AnchorQ,state.AnchorR,state.random,state.randomCalls,tostring(state.Paused),
        tostring(state.Active),state.Progress,state.TargetSiteId,state.StepCount,state.Speed}
    for _,step in ipairs(state.route)do out[#out+1]=step.Q..':'..step.R..':'..step.Minutes end
    return table.concat(out,'|')
end
local worlds={}
test('three generated worlds guarantee one reachable location per special event without town sites',function()
    for _,seed in ipairs({17,431,20261026})do
        local adventure,world=fixture(seed);worlds[#worlds+1]=adventure
        local events,travel,state=adventure.specialEvents,adventure.travel,adventure.travel.data
        local plans=Sites.Plan(events,world)
        assert(#plans==2 and #world.sites==1 and state.StopCount==0,'Planning must not create sites or require a town entrance')
        local first=plans[1];assert(travel:Plan(world.map:GetCell(first.q,first.r),0))
        state.Progress=.25;state.Paused=true;state.Speed=4
        local before,route=tripSignature(state),state.route
        plans=events:PlanWorld(world,adventure.data.Narrative)
        assert(#plans==2 and tripSignature(state)==before and state.route==route)
        assert(events:EnsureGenerated(plans)==2 and #world.sites==3 and state.StopCount==2)
        assert(tripSignature(state)==before and state.route==route,'Applying locations altered the live journey')
        local seen={};local camp=world.map:GetCell(world.sites[1].q,world.sites[1].r)
        for _,row in ipairs(definitions)do
            local site=assert(events:SiteForNpc(row.npcId));local cell=world.map:GetCell(site.q,site.r)
            assert(not seen[site.id] and site.eventId==row.eventId and site.travelStop and not cell.waterLevel and not cell.worldTravelBlocked)
            assert(travel.paths:FindPath(camp,cell,function(a,b)return travel:Cost(a,b)end),'Special event is outside the camp travel component')
            seen[site.id]=true
        end
        assert(events:EnsureGenerated()==0 and state.StopCount==2 and tripSignature(state)==before,'Repeated generation duplicated or moved an event')
    end
end)
test('restored stops retain IDs and only the missing special event is appended',function()
    local adventure,world,facts=fixture(431,worlds[2].map)
    local travel,events=adventure.travel,adventure.specialEvents
    local first,second=definitions[1],definitions[2]
    local selected=Sites.Plan(events,world)[1]
    local old=travel:CreateEventStop(selected.q,selected.r,first.eventId)
    local ordinary=travel:CreateWorldStop(world.sites[1].q,world.sites[1].r,1)
    local oldRecord,ordinaryRecord=travel.data:GetStopAt(0),travel.data:GetStopAt(1)
    travel.data.Paused=true;local before=tripSignature(travel.data)
    assert(events:EnsureGenerated(events:PlanWorld(world,adventure.data.Narrative))==1)
    assert(adventure.sites[old.id]==old and adventure.sites[ordinary.id]==ordinary)
    assert(travel.data:GetStopAt(0)==oldRecord and travel.data:GetStopAt(1)==ordinaryRecord and travel.data.StopCount==3)
    assert(events:SiteForNpc(first.npcId)==old and events:SiteForNpc(second.npcId).id==ordinary.id+1)
    assert(facts['flag:'..first.key..'_site']==old.id and tripSignature(travel.data)==before)
end)
test('resolved and recruited identities without sites are never regenerated or randomly revived',function()
    local adventure,world,facts=fixture(17,worlds[1].map)
    local first,second=definitions[1],definitions[2]
    facts['flag:'..first.key..'_outcome']=2;facts['recruited:'..second.npcId]=10000+second.npcId
    assert(#Sites.Plan(adventure.specialEvents,world,adventure.data.Narrative)==0)
    assert(adventure.specialEvents:EnsureGenerated()==0 and #world.sites==1 and adventure.travel.data.StopCount==0)
    for _,row in ipairs(definitions)do
        assert(not adventure.specialEvents:CanTrigger(row.eventId))
        assert(not adventure.travel:Trigger({eventId=row.eventId,encounterId=0}))
    end
    assert(#adventure.entered==0 and adventure.travel.data.StopCount==0)
end)
test('passing a prepared cell pauses into its existing site and visited cells stay quiet',function()
    local adventure=worlds[1];local travel,events,state=adventure.travel,adventure.specialEvents,adventure.travel.data
    local site=events:SiteForNpc(definitions[1].npcId);local count=state.StopCount
    adventure.data.Phase='map';state.Q=site.q;state.R=site.r;state.Paused=false;state.Progress=0
    local route=state.route
    assert(travel:CheckSpecialStop() and state.Paused and adventure.entered[#adventure.entered]==site.id)
    assert(state.StopCount==count and state.route==route,'Passing a fixed event created another stop or discarded the trip')
    adventure.data.visited[site.id]=true
    adventure.data.Phase='map';state.Paused=false
    local entered=#adventure.entered
    assert(not travel:CheckSpecialStop() and not state.Paused and #adventure.entered==entered)
    state.Active=false;state.TargetSiteId=0
    assert(travel:Arrive() and #adventure.entered==entered,'Ordinary arrival automatically reopened a visited event')
    state.TargetSiteId=site.id
    assert(travel:Arrive() and adventure.entered[#adventure.entered]==site.id,'Explicit arrival cannot continue a known event')
    adventure.data.Phase='map';state.Paused=false
    assert(travel:Trigger({eventId=site.eventId,encounterId=0}) and state.Paused and state.StopCount==count)
    local camp=adventure.sites[1];state.Q=camp.q;state.R=camp.r;adventure.data.Phase='map'
    assert(not travel:Trigger({eventId=site.eventId,encounterId=0}) and state.StopCount==count,'Remote random trigger duplicated a prepared location')
end)
test('ordinary arrival at a new prepared cell enters its existing event exactly once',function()
    local adventure=worlds[3];local travel,state=adventure.travel,adventure.travel.data
    local site=adventure.specialEvents:SiteForNpc(definitions[2].npcId);local count=state.StopCount
    state.Q=site.q;state.R=site.r;state.Progress=0;state.Active=false;state.TargetSiteId=0;state.Paused=false
    assert(travel:Arrive() and state.Paused and #adventure.entered==1 and adventure.entered[1]==site.id)
    assert(state.StopCount==count)
end)
maps:OnShutdown();config:OnShutdown()
print('special_event_world: '..checks..' checks passed')
