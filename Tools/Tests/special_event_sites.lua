-- Deterministic event placement against the real map and travel-cost rules; no Unity or saved files.
package.path='Lua/?.lua;'..package.path
local Sites=require('Game.Adventure.SpecialEventSites')
local Map=require('Game.Map.Map')
local Hex=require('Game.Map.HexGrid')
local Travel=require('Game.Adventure.WorldTravel')
local checks=0
local function test(name,run)run();checks=checks+1;print('PASS '..name)end
local function rejects(run)assert(not pcall(run),'Invalid special-event placement was accepted')end
local function fixture(cells)
    local map=Map(17,1);map.regions[1]={regionType=1}
    for _,source in ipairs(cells or {{0,0},{1,0},{2,0},{0,1},{1,1},{2,1}})do
        local cell={q=source[1],r=source[2],height=source.height or 0,regionId=1,roadIds={},
            waterLevel=source.waterLevel,worldTravelBlocked=source.worldTravelBlocked,buildingId=source.buildingId}
        cell.index=#map.cells+1;map.cells[cell.index]=cell;map.cellsByKey[Hex.Key(cell.q,cell.r)]=cell
    end
    local definitions={{id=2,eventId=303,npcId=302,key='deserter',townRadius=0},{id=1,eventId=301,npcId=301,key='trial',townRadius=100}}
    local facts,writes={},0
    local narrative={GetValue=function(_,key)return facts[key] or 0 end}
    local world={map=map,seed=17,sites={{id=1,eventId=1,q=0,r=0}}}
    local data={StopCount=0,stops={},Q=7,R=8,Paused=true,Progress=.25,random=789,clock=41,route={9,10}}
    function data:Roll()error('Placement must not consume the travel RNG')end
    function data:GetStopAt(i)return assert(self.stops[i+1])end
    local liveMap={GetRegion=function()error('Planning must use the supplied world map')end}
    local travel=setmetatable({map=liveMap,data=data,maxStep=2,rule={minutesPerCell=10,slopeMinutes=2,roadMultiplier=.7},
        terrains={[1]={costMultiplier=1}}},Travel)
    local adventure={map=map,sites=world.sites,data={Narrative=narrative},travel=travel,
        config={GetTable=function(_,name)assert(name=='SpecialEventTable');return {All=function()return definitions end}end}}
    function travel:CreateEventStop(q,r,eventId)
        local id=#adventure.sites+1
        local site={id=id,eventId=eventId,q=q,r=r,travelStop=true}
        self.data.StopCount=self.data.StopCount+1
        self.data.stops[#self.data.stops+1]={Id=id,Q=q,R=r,EventId=eventId,EncounterId=0}
        adventure.sites[id]=site
        return site
    end
    local events={adventure=adventure}
    function events:Set(row,suffix,value)writes=writes+1;facts['flag:'..row.key..'_'..suffix]=value end
    local function unchanged()
        assert(data.Q==7 and data.R==8 and data.Paused and data.Progress==.25 and data.random==789 and data.clock==41)
        assert(data.route[1]==9 and data.route[2]==10 and travel.map==liveMap,'Placement changed live travel state')
    end
    return events,world,narrative,facts,data,unchanged,function()return writes end,definitions
end
test('new world guarantees two distinct event sites without towns and leaves planning read-only',function()
    local events,world,story,facts,data,unchanged,writes,definitions=fixture()
    local plans=Sites.Plan(events,world)
    assert(#plans==2 and plans[1].row.id==1 and plans[2].row.id==2 and definitions[1].id==2)
    assert(plans[1].q~=plans[2].q or plans[1].r~=plans[2].r)
    for _,plan in ipairs(plans)do assert(plan.q~=0 or plan.r~=0)end
    assert(#world.sites==1 and data.StopCount==0 and next(facts)==nil and writes()==0);unchanged()
    assert(Sites.Apply(events,plans)==2 and #world.sites==3 and data.StopCount==2)
    assert(facts['flag:trial_site']==2 and facts['flag:deserter_site']==3 and writes()==2);unchanged()
    assert(Sites.Apply(events,plans)==0 and writes()==2,'Reapplying the same plan duplicated an identity')
    assert(Sites.Apply(events,Sites.Plan(events,world,story))==0 and #world.sites==3 and writes()==2)
end)
test('same seed and stable coordinates give identical choices despite source enumeration order',function()
    local a,worldA=fixture();local b,worldB=fixture({{2,1},{1,1},{0,1},{2,0},{1,0},{0,0}})
    local first,second=Sites.Plan(a,worldA),Sites.Plan(b,worldB)
    for i,plan in ipairs(first)do assert(plan.q==second[i].q and plan.r==second[i].r)end
end)
test('water cliffs and blocked cells cannot bridge into disconnected land',function()
    local events,world=fixture({{0,0},{0,-1},{1,0,waterLevel=1},{2,0},{0,1,height=20},{0,2,height=20},{-1,0,worldTravelBlocked=true},{-2,0}})
    local plans=Sites.Plan(events,world)
    assert(#plans==2)
    for _,plan in ipairs(plans)do assert(plan.q==0 and (plan.r==0 or plan.r==-1),'Placement selected land outside the camp component')end
    assert(Sites.Apply(events,plans)==2)
end)
test('one reachable camp cell still creates every event by sharing the safe coordinate',function()
    local events,world=fixture({{0,0}})
    local plans=Sites.Plan(events,world)
    assert(#plans==2)
    for _,plan in ipairs(plans)do assert(plan.q==0 and plan.r==0)end
    assert(Sites.Apply(events,plans)==2 and #world.sites==3)
end)
test('unoccupied land without buildings is preferred over a reachable building',function()
    local events,world=fixture({{0,0},{1,0,buildingId=7},{2,0},{0,1}})
    for _,plan in ipairs(Sites.Plan(events,world))do assert(not world.map:GetCell(plan.q,plan.r).buildingId)end
end)
test('old travel sites keep their IDs and missing narrative site facts are claimed without replacement',function()
    local events,world,story,facts,data,unchanged,writes=fixture()
    local old=events.adventure.travel:CreateEventStop(2,0,301)
    local unrelated=events.adventure.travel:CreateEventStop(0,1,90)
    local plans=Sites.Plan(events,world,story)
    assert(plans[1].site==old and plans[2].row.eventId==303 and writes()==0)
    assert(Sites.Apply(events,plans)==1)
    assert(world.sites[2]==old and world.sites[3]==unrelated and world.sites[4].eventId==303 and data.StopCount==3)
    assert(facts['flag:trial_site']==2 and facts['flag:deserter_site']==4 and writes()==2);unchanged()
    assert(Sites.Apply(events,Sites.Plan(events,world,story))==0 and writes()==2)
end)
test('recorded old sites are preserved and resolved or recruited identities never respawn',function()
    local events,world,story,facts,_,_,writes=fixture()
    facts['flag:trial_outcome']=2;facts['recruited:302']=10302
    assert(#Sites.Plan(events,world,story)==0 and Sites.Apply(events,{})==0 and writes()==0)
    local old=events.adventure.travel:CreateEventStop(1,0,301);facts['flag:trial_site']=old.id
    local plans=Sites.Plan(events,world,story)
    assert(#plans==1 and plans[1].site==old and Sites.Apply(events,plans)==0 and writes()==0)
end)
test('invalid old site flags and duplicate event locations reject without writing',function()
    local events,world,story,facts,_,_,writes=fixture()
    facts['flag:trial_site']=1;rejects(function()Sites.Plan(events,world,story)end)
    facts['flag:trial_site']=999;rejects(function()Sites.Plan(events,world,story)end)
    facts['flag:trial_site']=nil
    events.adventure.travel:CreateEventStop(1,0,301);events.adventure.travel:CreateEventStop(2,0,301)
    rejects(function()Sites.Plan(events,world,story)end);assert(writes()==0)
end)
test('all apply plans are preflighted before the first append or fact write',function()
    local events,world,story,facts,data,_,writes=fixture()
    local plans=Sites.Plan(events,world,story);plans[2].q=999
    rejects(function()Sites.Apply(events,plans)end)
    assert(#world.sites==1 and data.StopCount==0 and next(facts)==nil and writes()==0)
    plans=Sites.Plan(events,world,story);facts['flag:deserter_site']=1
    rejects(function()Sites.Apply(events,plans)end)
    assert(#world.sites==1 and data.StopCount==0 and writes()==0)
end)
test('a resolved identity between planning and application is not created',function()
    local events,world,story,facts=fixture()
    local plans=Sites.Plan(events,world,story);facts['flag:trial_outcome']=1
    assert(Sites.Apply(events,plans)==1 and #world.sites==2 and world.sites[2].eventId==303 and not facts['flag:trial_site'])
end)
test('stop capacity and slot mismatches reject the whole batch',function()
    local events,world,story,_,data,_,writes=fixture()
    local plans=Sites.Plan(events,world,story)
    data.StopCount=10000
    rejects(function()Sites.Apply(events,plans)end);assert(#world.sites==1 and writes()==0)
    data.StopCount=1;data.stops[1]={Id=999}
    rejects(function()Sites.Apply(events,plans)end);assert(#world.sites==1 and writes()==0)
end)
print('special_event_sites: '..checks..' checks passed')
