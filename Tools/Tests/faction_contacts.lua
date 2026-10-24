-- Contact-order regression and bridge-call budgets; no Editor or C# reload required.
package.path='Lua/?.lua;'..package.path
local Conflicts=require('Game.Adventure.WorldConflicts')
local Hex=require('Game.Map.HexGrid')
local function equal(a,b,message)assert(a==b,(message or 'Mismatch')..': '..tostring(a)..' ~= '..tostring(b))end
local function pair(a,b)return math.min(a,b)..':'..math.max(a,b)end
local function coordinate(a,b)return a.q..','..a.r..':'..b.q..','..b.r end

-- Previous implementation is the behavioral oracle, including cheapest-path edge count.
local function oldNear(self,a,b)
    if a.Travel.Progress~=0 or b.Travel.Progress~=0 then return false end
    local range=self.adventure.parties.rule.contactRadius
    if Hex.Distance(a.Travel.Q,a.Travel.R,b.Travel.Q,b.Travel.R)>range then return false end
    local path=self.adventure.parties:Path(self.adventure.map:GetCell(a.Travel.Q,a.Travel.R),self.adventure.map:GetCell(b.Travel.Q,b.Travel.R))
    return path~=nil and #path-1<=range
end
local function oldContacts(self,minute)
    local data=self.adventure.parties.data
    for i=0,data.Count-1 do local a=data:GetAt(i)
        if not a.Defeated and a.BattleSiteId==0 and a.Role~='garrison' and a.Mission~='occupy' and minute>=a.SafeUntil then
            if a.Mission=='raid' and a.TargetSiteId>0 then
                local target=self.data:FindSite(a.TargetSiteId)
                if target and target.OccupierId==0 and minute>=target.ProtectedUntil then
                    local b=assert(data:Find(target.GuardPartyId))
                    if not b.Defeated and b.BattleSiteId==0 and self:Near(a,b) and self.factions:Relation(a.FactionId,b.FactionId)=='hostile' then
                        local home=self.data:FindSite(a.HomeSiteId)
                        local cost=self.factions.rules.policies:Get(a.FactionId).recruitCost
                        if home and home.OccupierId==0 and home:SpendReserve(cost) then self:Begin(a,b,minute,target.SiteId) end
                    end
                end
            end
            if a.BattleSiteId==0 then for j=i+1,data.Count-1 do local b=data:GetAt(j)
                if not b.Defeated and b.BattleSiteId==0 and b.Role~='garrison' and b.Mission~='occupy' and minute>=b.SafeUntil and
                    self.factions:Relation(a.FactionId,b.FactionId)=='hostile' and self:Near(a,b) then
                    self:Begin(a,b,minute);break
                end
            end end
        end
    end
end
local function fixture(spec,previous)
    local metrics={reads=0,getAt=0,find=0,relations=0,paths=0,costs=0}
    local function bridge(values)
        return setmetatable({}, {__index=function(_,key)metrics.reads=metrics.reads+1;return values[key]end,
            __newindex=function(_,key,value)values[key]=value end})
    end
    local list,byId,sites={},{},{}
    for i,row in ipairs(spec.parties) do
        local party=bridge{Id=row.id or i,FactionId=row.faction or 1,Defeated=row.defeated or false,BattleSiteId=row.battle or 0,
            Role=row.role or 'raider',Mission=row.mission or 'patrol',SafeUntil=row.safe or 0,TargetSiteId=row.target or 0,HomeSiteId=row.home or 10,
            Travel=bridge{Q=row.q or 0,R=row.r or 0,Progress=row.progress or 0}}
        list[i]=party;byId[row.id or i]=party
    end
    for _,row in ipairs(spec.sites or {}) do
        local site={SiteId=row.id,GuardPartyId=row.guard,OccupierId=row.occupier or 0,ProtectedUntil=row.protected or 0,Reserve=row.reserve or 0}
        function site:SpendReserve(cost)if self.Reserve<cost then return false end;self.Reserve=self.Reserve-cost;return true end
        sites[row.id]=site
    end
    local data={Count=#list,GetAt=function(_,index)metrics.getAt=metrics.getAt+1;return list[index+1]end,
        Find=function(_,id)metrics.find=metrics.find+1;return byId[id]end}
    local function route(a,b)
        if spec.route then return spec.route(a,b) end
        local routes=spec.paths or {};return routes[coordinate(a,b)] or {steps=Hex.Distance(a.q,a.r,b.q,b.r)}
    end
    local adventure={parties={data=data,rule={contactRadius=spec.radius or 1}},map={GetCell=function(_,q,r)return {q=q,r=r}end},travel={}}
    function adventure.parties:Path(a,b)
        metrics.paths=metrics.paths+1;local result=route(a,b)
        if result.unreachable then return nil end
        local path={};for i=1,result.steps+1 do path[i]=a end;return path
    end
    function adventure.travel:Cost(a,b)metrics.costs=metrics.costs+1;if route(a,b).blocked then return nil end;return 1 end
    local factions={adventure=adventure,data={FindSite=function(_,id)return sites[id]end},rules={policies={Get=function()return {recruitCost=35}end}}}
    function factions:Relation(a,b)
        metrics.relations=metrics.relations+1
        if spec.relations then return spec.relations[pair(a,b)] or 'neutral' end
        return a==b and 'allied' or 'hostile'
    end
    local conflicts=Conflicts.New(factions);conflicts.events={}
    function conflicts:Begin(a,b,minute,target)
        assert(a.BattleSiteId==0 and b.BattleSiteId==0,'Duplicate engagement')
        self.events[#self.events+1]=a.Id..':'..b.Id..':'..(target or 0)
        a.BattleSiteId=100+#self.events;b.BattleSiteId=a.BattleSiteId
    end
    if previous then conflicts.Near=oldNear;conflicts.Contacts=oldContacts end
    local function signature()
        local values={table.concat(conflicts.events,',')}
        for _,party in ipairs(list)do values[#values+1]=party.Id..'='..party.BattleSiteId end
        for _,row in ipairs(spec.sites or {})do values[#values+1]=row.id..'$'..sites[row.id].Reserve end
        return table.concat(values,';')
    end
    return conflicts,metrics,signature,list
end
local count=0
local function compare(spec,message)
    local before,beforeMetrics,beforeSignature=fixture(spec,true)
    local after,afterMetrics,afterSignature=fixture(spec,false)
    before:Contacts(100);after:Contacts(100)
    equal(afterSignature(),beforeSignature(),message);count=count+1
    return after,afterMetrics,beforeMetrics
end

local separated={parties={}}
for i=1,45 do separated.parties[i]={q=i*4,faction=i%3+1}end
local _,after,before=compare(separated,'Distant parties')
equal(after.getAt,45);equal(after.relations,0);equal(after.paths,0)
assert(before.getAt>900 and after.reads<before.reads/3,'Contact bridge reads must scale with parties, not pairs')
print(string.format('PASS 45 separated parties: GetAt %d -> %d, property reads %d -> %d, diplomacy %d -> %d',before.getAt,after.getAt,before.reads,after.reads,before.relations,after.relations))

local neutral={parties={},relations={}}
for i=1,45 do neutral.parties[i]={q=i%2,faction=1}end
local _,neutralAfter,neutralBefore=compare(neutral,'Neutral nearby parties')
equal(neutralAfter.relations,1);equal(neutralAfter.paths,0)
print(string.format('PASS repeated nearby relation: %d -> %d queries',neutralBefore.relations,neutralAfter.relations))

local contact=compare({parties={{faction=1},{q=1,faction=2},{faction=2},{q=1,faction=1}}},'First qualifying target and same-call engagement order')
equal(table.concat(contact.events,','),'1:2:0,3:4:0')
local siege={parties={{faction=2,mission='raid',target=20},{q=1,faction=1,role='garrison'},
    {faction=1,role='caravan'},{q=1,faction=2,mission='raid',target=20}},sites={{id=10,reserve=50},{id=20,guard=2}}}
contact=compare(siege,'Siege priority, finite reserve and claimed defender')
equal(table.concat(contact.events,','),'1:2:20,3:4:0')
siege.sites[1].reserve=0
contact=compare(siege,'Insufficient siege reserve falls back to original mobile target order')
equal(table.concat(contact.events,','),'1:3:0')
siege.sites[1].reserve=50;siege.parties[2].progress=.5
compare(siege,'Moving defenders cannot engage')
compare({parties={{faction=1},{faction=2,progress=.1},{faction=2,safe=101},{faction=2,role='garrison'},
    {faction=2,mission='occupy'},{faction=2,defeated=true},{faction=2,battle=7},{faction=2}}},'All existing contact exclusions')

local forbidden={parties={{faction=1},{q=1,faction=2}},paths={['0,0:1,0']={blocked=true,steps=2}}}
local _,blockedAfter,blockedBefore=compare(forbidden,'Blocked adjacent edge cannot fit one-step budget')
equal(blockedAfter.paths,0);equal(blockedBefore.paths,1)
forbidden.radius=2
local detour,detourMetrics=compare(forbidden,'Larger contact radius still accepts cheapest detour')
equal(#detour.events,1);equal(detourMetrics.paths,1);equal(detourMetrics.costs,0)
local weighted,weightedMetrics=compare({parties={{faction=1},{q=1,faction=2}},paths={['0,0:1,0']={steps=3}}},
    'Passable direct edge cannot replace the cheaper route edge-count rule')
equal(#weighted.events,0);equal(weightedMetrics.paths,1)

local changed=fixture(neutral,false)
changed:Contacts(100);equal(#changed.events,0)
neutral.relations['1:1']='hostile'
changed:Contacts(101);assert(#changed.events>0,'Relation cache must expire at the end of each Contacts call')
print('PASS contact order, sieges, exclusions, detours and per-call diplomacy cache')

local seed=271828
local function random(maximum)seed=(seed*1103515245+12345)&0x7fffffff;return seed%maximum end
for case=1,96 do
    local spec={radius=case%3+1,parties={},route=function(a,b)
        local distance=Hex.Distance(a.q,a.r,b.q,b.r)
        local code=math.abs(a.q*13+a.r*7+b.q*5+b.r*3)
        return {steps=distance+(code%7==0 and 2 or 0),blocked=code%7==0,unreachable=code%11==0}
    end}
    for i=1,45 do
        local flags=random(20)
        spec.parties[i]={q=random(12)-6,r=random(12)-6,faction=random(5)+1,progress=flags==0 and .5 or 0,
            role=flags==1 and 'garrison' or 'raider',mission=flags==2 and 'occupy' or 'patrol',
            defeated=flags==3,battle=flags==4 and 20 or 0,safe=flags==5 and 101 or 0}
    end
    compare(spec,'Seeded mixed contacts '..case)
end
print('PASS '..count..' contact signatures match the prior implementation')
