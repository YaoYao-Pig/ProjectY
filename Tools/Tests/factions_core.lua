-- Pure Lua regression checks for diplomacy, strategic decisions and persistent conflicts.
-- Deliberately uses small contract fixtures: no Editor, generated config or game startup.
package.path='Lua/?.lua;'..package.path
local Rules=require('Game.Adventure.FactionRules')
local Factions=require('Game.Adventure.WorldFactions')
local Conflicts=require('Game.Adventure.WorldConflicts')
local Parties=require('Game.Adventure.WorldParties')
local previousCS=CS
CS={ProjectY={Data={WorldFactionsData={For=function(data)return assert(data.factionData)end},FactionPersistence={
    Find=function(areas,id)return areas:Find(id)end,
    PartyId=function(group)return group.PartyId end,
    DetachParty=function(group)group:DetachParty()end}}}}
local passed,failures=0,{}
local function test(name,run)
    local ok,reason=xpcall(run,debug.traceback)
    if ok then passed=passed+1;print('PASS '..name)
    else failures[#failures+1]=name..': '..reason;print('FAIL '..name..': '..reason) end
end
local function equal(actual,expected,message)
    assert(actual==expected,(message or 'Unexpected value')..': '..tostring(actual)..' ~= '..tostring(expected))
end
local function tableOf(rows)
    local byId={};for _,row in ipairs(rows) do byId[row.id]=row end
    return {All=function()return rows end,Get=function(_,id)return assert(byId[id],'Unknown fixture row '..id)end}
end
local settings={id=1,hostileThreshold=-30,alliedThreshold=40,thinkMinutes=30,raidAdvantage=1.15,siegeAdvantage=1.6,
    maximumExpeditionMinutes=480,distanceScale=120,rewardScale=100,reserveFraction=.4,switchMultiplier=1.25,
    roamRadius=10,siteSafeRadius=8,siteSpacing=12,siteSearchRadius=30,retreatMinutes=360,
    occupationProtectionMinutes=1440,recoveryInitial=.35,recoveryMinutes=4320,
    conflictMinimumMinutes=45,conflictMaximumMinutes=150,conflictTickMinutes=10,ruinMinutes=1440,
    attrition=.09,retreatHealth=.25,aidReputation=8,attackReputation=-30,maximumRouteThreat=1.25,minimumActionScore=.04,reserveCapacity=1000}
local policies={
    {id=1,role='civilized',regionTypes={1},playerRelation=55,encounterId=408,reserve=160,income=4,recruitCost=40,defenseMultiplier=1.5,raidPreference=.65},
    {id=2,role='organization',regionTypes={},playerRelation=45,encounterId=0,reserve=0,income=0,recruitCost=40,defenseMultiplier=1,raidPreference=0},
    {id=4,role='raider',regionTypes={1,2},playerRelation=-65,encounterId=404,reserve=100,income=2,recruitCost=35,defenseMultiplier=1.25,raidPreference=1.2},
    {id=6,role='guardian',regionTypes={5},playerRelation=45,encounterId=407,reserve=120,income=3,recruitCost=40,defenseMultiplier=1.4,raidPreference=.55}}
local tables={WorldFactionTable=tableOf(policies),WorldFactionRuleTable=tableOf({settings}),
    WorldFactionRelationTable=tableOf({{id=1,first=1,second=2,value=60},{id=2,first=2,second=6,value=60},{id=3,first=1,second=4,value=-80}}),
    FactionTable=tableOf(policies),CombatEncounterTable=tableOf({{id=408},{id=404},{id=407}})}
local config={GetTable=function(_,name)return assert(tables[name],name)end}
local rules=Rules.New(config)

test('diplomacy is symmetric, explicit and non-transitive',function()
    equal(rules:Relation(1,2),'allied');equal(rules:Relation(2,1),'allied')
    equal(rules:Relation(2,6),'allied');equal(rules:Relation(1,6),'neutral','Allies of allies must not merge')
    equal(rules:Relation(4,1),'hostile');equal(rules:Relation(4,4),'allied')
    equal(rules:Relation(0,4, nil,100),'neutral');equal(rules:Value(0,4,nil,1000),100)
    equal(rules:Relation(1,4,{FindRelation=function()return {Value=50}end}),'allied')
    assert(rules:Suitable(6,5) and not rules:Suitable(6,1),'Wood elves must use their configured terrain')
end)

test('strength cannot bypass diplomacy, reachability, reserves or expedition limits',function()
    local input={attack=10000,defense=10,minutes=1,threat=0,reserve=100,minimumReserve=40,value=10000,hostile=true,reachable=true,siege=true}
    assert(rules:Score(input)>0)
    for _,change in ipairs({{'hostile',false},{'reachable',false},{'cooldown',true},{'reserve',39},{'minutes',481},{'attack',15}}) do
        local copy={};for k,v in pairs(input) do copy[k]=v end;copy[change[1]]=change[2]
        equal(rules:Score(copy),0,'Hard gate '..change[1])
    end
    local full={HP=100,MaxHP=100};local injured={HP=25,MaxHP=100}
    local stats={Template=function()return {actionPoints=4}end,Get=function()return 10 end}
    equal(rules:Power(injured,stats),rules:Power(full,stats)*.25,'Wounds must reduce actual strength')
end)

test('occupied services stay blocked and liberation recovery is time based',function()
    equal(rules:Recovery({OccupierId=4,LiberatedAt=-1},10000),0)
    equal(rules:Recovery({OccupierId=0,LiberatedAt=-1},0),1)
    local site={OccupierId=0,LiberatedAt=100}
    equal(rules:Recovery(site,100),.35);equal(rules:Recovery(site,4420),1);equal(rules:Recovery(site,99999),1)
    assert(math.abs(rules:Recovery(site,2260)-.675)<1e-8)
    site.OccupierId=4
    local faction=setmetatable({data={FindSite=function()return site end}},Factions)
    equal(faction:ServiceAllowed(1),false)
end)

local function actor(hp)
    return {HP=hp or 100,MaxHP=100,Damage=function(self,n)self.HP=math.max(0,self.HP-n)end,
        Restore=function()error('Unexpected healing or roster reset')end}
end
local function party(id,faction,q,role)
    local unit=actor()
    local travel={Q=q,R=0,AnchorQ=q,AnchorR=0,Progress=0,Active=false,Paused=false,
        Plan=function(self,qs,rs)self.Active=#qs>0;self.goalQ=qs[#qs];self.goalR=rs[#rs]end,
        SetPaused=function(self,value)self.Paused=value end}
    return {Id=id,FactionId=faction,DefinitionId=faction,Role=role or 'raider',Travel=travel,
        HomeQ=0,HomeR=0,HomeSiteId=11,SafeUntil=0,DecisionAt=0,BattleSiteId=0,Defeated=false,
        Mission='patrol',TargetSiteId=0,TargetPartyId=0,MemberCount=1,CargoCount=0,testPower=300,unit=unit,
        GetMemberAt=function(self,i)assert(i==0);return self.unit end,
        SetDefeated=function(self,value)assert(value==(self.unit.HP==0));self.Defeated=value end,
        SetMission=function(self,mission,target,site,minute)self.Mission=mission;self.TargetPartyId=target;self.TargetSiteId=site;self.DecisionAt=minute end}
end
local function strategy()
    local a=party(1,4,2);local guard=party(2,1,5,'garrison');guard.testPower=100
    local homeGuard=party(3,4,0,'garrison');homeGuard.testPower=250
    local list={a,guard,homeGuard}
    local target={SiteId=12,FactionId=1,GuardPartyId=2,OccupierId=0,ProtectedUntil=0,Reserve=160}
    local home={SiteId=11,FactionId=4,GuardPartyId=3,OccupierId=0,ProtectedUntil=0,Reserve=100}
    local world={home,target}
    for _,site in ipairs(world) do
        site.LastRecoveryAt=0;site.LiberatedAt=-1
        function site:AddReserve(amount)assert(amount>=0);self.Reserve=self.Reserve+amount end
        function site:SetRecoveryAt(minute)assert(minute>=self.LastRecoveryAt);self.LastRecoveryAt=minute end
        function site:SpendReserve(amount)
            assert(amount>=0);if amount>self.Reserve then return false end
            self.Reserve=self.Reserve-amount;return true
        end
    end
    local data={SiteCount=2,GetSiteAt=function(_,i)return world[i+1]end,FindSite=function(_,id)return id==11 and home or id==12 and target end}
    local pd={Count=3,GetAt=function(_,i)return list[i+1]end,Find=function(_,id)return list[id]end}
    local map={GetCell=function(_,q,r)return {q=q,r=r}end}
    local parties=setmetatable({data=pd,map=map,definitions={Get=function()return {detectRadius=20,speed=1}end},route=true,pathCalls=0},Parties)
    function parties:Path(from,to)
        self.pathCalls=self.pathCalls+1
        if not self.route then return nil end
        local path={from};local step=from.q<to.q and 1 or -1
        for q=from.q+step,to.q,step do path[#path+1]={q=q,r=0}end
        self.lastPath=path
        return path
    end
    function parties:ApplyRoute(p,path)
        self.appliedPath=path
        assert(path[1].q==p.Travel.AnchorQ and path[1].r==p.Travel.AnchorR)
        return Parties.ApplyRoute(self,p,path)
    end
    function parties:Roam(p)p.Travel:Plan({p.Travel.Q-1},{0})end
    local adventure={parties=parties,travel={Cost=function()return 1 end},map=map}
    parties.adventure=adventure
    local factions=setmetatable({rules=rules,adventure=adventure,data=data,map=map,
        sites={[11]={q=0,r=0},[12]={q=5,r=0}},hostile=true,threat=0},Factions)
    function factions:Power(p)return p.testPower end
    function factions:Relation(x,y)return x==y and 'allied' or self.hostile and 'hostile' or 'neutral' end
    function factions:Threat()return self.threat end
    return factions,a,home,guard,parties
end

test('strategy excludes unreachable and friendly sites before planning',function()
    local f,a,_,_,p=strategy();p.route=false;f:Think(a,100);equal(a.Mission,'patrol');equal(a.Travel.Active,false)
    f,a=strategy();f.hostile=false;f:Think(a,100);equal(a.Mission,'patrol');equal(a.Travel.Active,false)
    f,a=strategy();a.testPower=100;f:Think(a,100);equal(a.Mission,'patrol','Insufficient local siege advantage')
end)

test('a guarded, supplied raider can choose a weaker reachable hostile site',function()
    local f,a,_,_,p=strategy();f:Think(a,100);equal(a.Mission,'raid');equal(a.TargetSiteId,12)
    equal(p.pathCalls,1,'The selected candidate must not search again while applying its route')
    equal(p.appliedPath,p.lastPath,'ApplyRoute must receive the exact candidate path')
end)

test('the two-argument Plan ignores the extra value returned by Map.GetCell',function()
    local Map=require('Game.Map.Map');local Hex=require('Game.Map.HexGrid')
    local map=Map(1,1)
    for q=0,2 do
        local cell={q=q,r=0};map.cells[#map.cells+1]=cell;map.cellsByKey[Hex.Key(q,0)]=cell
    end
    local goal,message=map:GetCell(2,0)
    equal(message,'Cell is outside this map','Regression requires the real assert multi-return contract')
    local p=party(1,4,0);local planned
    function p.Travel:Plan(qs,rs,costs,site)planned={qs=qs,rs=rs,costs=costs,site=site}end
    local parties=setmetatable({map=map,paths=require('Game.Map.MapPathfinder')(map),
        definitions={Get=function()return {speed=.5}end},adventure={travel={Cost=function()return 2.5 end}}},Parties)
    -- Do not parenthesize GetCell: its second return must expand at the call boundary.
    assert(parties:Plan(p,map:GetCell(2,0)))
    equal(#planned.qs,2);equal(planned.qs[1],1);equal(planned.qs[2],goal.q)
    equal(planned.rs[1],0);equal(planned.rs[2],0);equal(planned.costs[1],5);equal(planned.costs[2],5);equal(planned.site,0)
end)

test('ineligible and distant targets are rejected before path or defender strength work',function()
    local f,a,_,guard,p=strategy();guard.testPower=10000
    function f:Threat()error('Rejected local advantage must not inspect route threat')end
    f:Think(a,100);equal(a.Mission,'patrol');equal(p.pathCalls,0,'Insufficient local advantage must skip Dijkstra')
    local home
    f,a,home,guard,p=strategy();home.Reserve=0
    f:Think(a,100);equal(p.pathCalls,0,'Insufficient supplies must skip Dijkstra')
    f,a,home,guard,p=strategy();p.data:Find(3).testPower=1
    f:Think(a,100);equal(p.pathCalls,0,'Insufficient home defense must skip Dijkstra')
    f,a,home,guard,p=strategy();f.sites[12].q=100
    local queried={}
    function f:Power(row)queried[row.Id]=(queried[row.Id] or 0)+1;return row.testPower end
    f:Think(a,100);equal(p.pathCalls,0);equal(queried[guard.Id],nil,'Distant defender power must not be queried')
end)

test('equal scoring targets still prefer the lower party ID',function()
    local f,a,_,guard,p=strategy();guard.Role='caravan'
    local higher=party(4,1,5,'caravan');higher.testPower=guard.testPower
    local homeGuard=p.data:Find(3)
    local rows={a,higher,guard,homeGuard};local indexed={[1]=a,[2]=guard,[3]=homeGuard,[4]=higher}
    p.data.Count=#rows
    function p.data:GetAt(i)return rows[i+1]end
    function p.data:Find(id)return indexed[id]end
    f:Think(a,100);equal(a.Mission,'intercept');equal(a.TargetPartyId,guard.Id)
end)

test('player and faction strength caches share explicit invalidation',function()
    local a,b,dead=party(1,4,0),party(2,1,1),party(3,4,2)
    dead.Defeated=true;dead.unit.HP=0
    local player=actor(50);local rows={a,b,dead};local reads,livingCalls,actorQueries=0,0,0
    local data={Count=#rows,GetAt=function(_,i)reads=reads+1;return rows[i+1]end}
    local stats={Template=function()actorQueries=actorQueries+1;return {actionPoints=4}end,Get=function()return 10 end}
    local events={LivingParty=function()livingCalls=livingCalls+1;return {player}end}
    local f=setmetatable({rules=rules,adventure={parties={data=data},battle={stats=stats},events=events}},Factions)
    local first=f:Strength(4);equal(f:Strength(1),first);equal(f:Strength(99),0)
    equal(reads,3,'All faction totals must share one roster traversal');equal(actorQueries,2,'Defeated parties must not contribute')
    local playerBefore=f:PlayerPower();equal(f:PlayerPower(),playerBefore);equal(livingCalls,1)
    a.unit.HP=50;player.HP=25;f:InvalidatePower()
    equal(f:Strength(4),first*.5);equal(f:Strength(1),first);equal(reads,6)
    equal(f:PlayerPower(),playerBefore*.5);equal(livingCalls,2)
    function events:LivingParty()livingCalls=livingCalls+1;return {}end
    f:InvalidatePower();equal(f:PlayerPower(),0);equal(f:PlayerPower(),0);equal(livingCalls,3,'Zero player strength must also be cached')
end)

test('strong attackers still need reserves and a safe route',function()
    local f,a,home=strategy();home.Reserve=0;f:Think(a,100);equal(a.Mission,'patrol','Insufficient supplies')
    f,a=strategy();f.adventure.parties.data:Find(3).testPower=1;f:Think(a,100);equal(a.Mission,'patrol','Do not leave the home undefended')
    f,a=strategy();f.threat=10000;f:Think(a,100);equal(a.Mission,'patrol','A strong target-area threat must veto the attack')
end)

test('returning mobile parties pay for recovery and deliver captured cargo before raiding',function()
    local f,a,home=strategy();a.Travel.Q=0;a.Travel.AnchorQ=0;a.unit.HP=25
    local healed=0
    function a.unit:Restore()healed=healed+1;self.HP=self.MaxHP end
    f.Power=nil -- Exercise the real cached strength query, including recovery invalidation.
    f.adventure.battle={stats={Template=function()return {actionPoints=4}end,Get=function()return 10 end}}
    local woundedPower=f:Power(a)
    local policy=rules.policies:Get(home.FactionId)
    home.Reserve=policy.recruitCost-policy.income-1
    f:Recover(30);equal(a.unit.HP,25);equal(healed,0);equal(home.Reserve,policy.recruitCost-1)
    home.Reserve=100
    f:Recover(60);equal(a.unit.HP,100);equal(healed,1)
    equal(home.Reserve,100+policy.income-policy.recruitCost,'Mobile recovery must debit actual home supplies')
    assert(f:Power(a)>woundedPower,'Recovery must invalidate cached wounded strength')
    f:Recover(60);equal(healed,1,'Same strategic minute cannot recover twice')
    equal(home.Reserve,100+policy.income-policy.recruitCost)

    f,a,home=strategy();a.CargoCount=1
    local delivered=0
    function a:GetCargoAt(i)assert(i==0 and self.CargoCount==1);return {ItemId=900,Count=6}end
    function a:SetCargo(_,items,counts,kinds,widths,heights)
        assert(#items==0 and #counts==0 and #kinds==0 and #widths==0 and #heights==0)
        delivered=delivered+1;self.CargoCount=0
    end
    f.adventure.parties.prices={[900]=200}
    f:Think(a,100);equal(a.Mission,'return');equal(a.TargetSiteId,0);equal(a.TargetPartyId,0)
    equal(a.Travel.goalQ,a.HomeQ,'A loaded raider must head home rather than the weaker hostile site')
    a.Travel.Q=a.HomeQ;a.Travel.AnchorQ=a.HomeQ;a.Travel.Active=false
    home.Reserve=settings.reserveCapacity-10
    f:Recover(120);equal(home.Reserve,settings.reserveCapacity);equal(a.CargoCount,0);equal(delivered,1)
    f:Recover(150);equal(home.Reserve,settings.reserveCapacity);equal(delivered,1,'Delivered cargo cannot be converted twice')
end)

test('cancelling a raid removes its obsolete attack route',function()
    local f,a=strategy();a.Mission='raid';a.TargetSiteId=12;a.Travel.Active=true;a.Travel.goalQ=5
    f.hostile=false;f:Think(a,100)
    assert(a.Mission~='raid','Diplomacy change must cancel the raid')
    assert(not a.Travel.Active or a.Travel.goalQ~=5,'Cancelled raid must not keep moving into the old target')
end)

test('existing roster reads preserve wounds without allocating or restoring actors',function()
    local f=setmetatable({adventure={}},Factions);local a=party(1,4,0);a.unit.HP=23
    f:PrepareRoster(a,404);f:PrepareRoster(a,404);equal(a.unit.HP,23);equal(a.MemberCount,1)
    local initialized=setmetatable({adventure={data={factionData={Initialized=true,SiteCount=0}}}},Factions)
    initialized:Initialize() -- Reload must not require generation services or create parties.
end)

test('garrisons and occupying parties do not resume roaming',function()
    local p=setmetatable({},Parties)
    local garrison=party(1,4,0,'garrison');p:TickParty(garrison,100)
    local occupier=party(2,4,0);occupier.Mission='occupy';p:TickParty(occupier,100)
    equal(garrison.Travel.Active,false);equal(occupier.Travel.Active,false)
end)

local function contactFixture()
    local a,b=party(1,4,0),party(2,1,1,'caravan');local list={a,b}
    local pd={Count=2,GetAt=function(_,i)return list[i+1]end,Find=function(_,id)return list[id]end}
    local adventure={parties={data=pd,rule={contactRadius=1},reachable=true},map={GetCell=function(_,q,r)return {q=q,r=r}end},travel={Cost=function()return 1 end}}
    function adventure.parties:Path(from,to)if self.reachable then return {from,to}end end
    local factions={adventure=adventure,data={SiteCount=0},hostile=true,rules=rules}
    function factions:Relation()return self.hostile and 'hostile' or 'neutral'end
    local c=Conflicts.New(factions);c.started=0
    function c:Begin(first,second,minute,target)
        assert(not first.Defeated and (not second or not second.Defeated),'Defeated party cannot engage')
        self.started=self.started+1;first.BattleSiteId=99;if second then second.BattleSiteId=99 end
    end
    return c,a,b,adventure,factions
end

test('hostile NPC contact is reachable, protected, tile-aligned and deduplicated',function()
    local c,a,b,adv,f=contactFixture()
    adv.parties.reachable=false;c:Contacts(100);equal(c.started,0)
    adv.parties.reachable=true;b.Travel.Progress=.5;c:Contacts(100);equal(c.started,0)
    b.Travel.Progress=0;b.SafeUntil=101;c:Contacts(100);equal(c.started,0)
    b.SafeUntil=0;f.hostile=false;c:Contacts(100);equal(c.started,0)
    f.hostile=true;c:Contacts(100);c:Contacts(100);equal(c.started,1)
end)

test('dead garrisons cannot be engaged during recovery',function()
    local c,a,b=contactFixture();a.Mission='raid';a.TargetSiteId=5;b.Role='garrison';b.Defeated=true;b.unit.HP=0
    c.data.FindSite=function()return {SiteId=5,GuardPartyId=2,OccupierId=0,ProtectedUntil=0}end
    c:Contacts(100);equal(c.started,0)
end)

test('revisiting a prepared battlefield does not regenerate enemies or heal wounds',function()
    local layout={};local a=party(1,4,0);a.unit.HP=17
    local group={GetEnemyAt=function(_,i)assert(i==0);return a.unit end}
    local marker={GetEncounterAt=function(_,i)assert(i==0);return group end}
    local adventure={sites={[99]={id=99}},areas={layouts={[99]=layout}},data={Areas={Find=function()return marker end}}}
    local c=Conflicts.New({adventure=adventure,data={}})
    local first,state=c:Prepare({SiteId=99});equal(first,layout);equal(state,marker)
    equal(state:GetEncounterAt(0):GetEnemyAt(0),a.unit);equal(a.unit.HP,17)
    local again,stateAgain=c:Prepare({SiteId=99});equal(again,first);equal(stateAgain,state)
    equal(stateAgain:GetEncounterAt(0):GetEnemyAt(0).HP,17)
end)

test('conflicts pause for the player, retain damage, settle once and expire after leaving',function()
    local a,b=party(1,4,0),party(2,1,1);a.BattleSiteId=99;b.BattleSiteId=99
    local list={a,b};local releases=0
    local pd={Find=function(_,id)return list[id]end,DropPartyCargo=function()error('Survivor cargo must stay with its party')end,
        ReleaseParty=function(_,id,dead,safe)releases=releases+1;list[id].BattleSiteId=0;list[id].Defeated=dead;list[id].SafeUntil=safe end}
    local conflict={PartyA=1,PartyB=2,SiteId=99,TargetSiteId=0,Phase='active',Materialized=true,PlayerEngaged=false,MinimumEndAt=45,NextTickAt=0,ExpiresAt=50,
        Roll=function()return 15 end,TickAt=function(self,t)self.NextTickAt=t end,
        Engage=function(self,v)self.PlayerEngaged=v end,
        Resolve=function(self,w,t)self.Phase='resolved';self.WinnerPartyId=w;self.ExpiresAt=t end,
        Expire=function(self)self.Phase='expired'end}
    local fd={ConflictCount=1,GetConflictAt=function()return conflict end}
    local adventure={parties={data=pd},data={Areas={ActiveSiteId=99}},equipment={worldLoot={ActorDrops=function()end}},battle={stats={}}}
    local factions=setmetatable({adventure=adventure,data=fd,rules=rules,Power=function(_,p)return p.unit.HP end},Factions)
    local c=Conflicts.New(factions)
    local groups={{PartyId=1},{PartyId=2}};for _,group in ipairs(groups)do group.DetachParty=function(self)self.Detached=true end end
    local state={EncounterCount=2,GetEncounterAt=function(_,i)return groups[i+1]end}
    function c:Prepare()return {entryIndex=1},state end
    function c:Contacts()end
    c:Tick(44);equal(a.unit.HP,100)
    conflict.PlayerEngaged=true;c:Tick(50);equal(a.unit.HP,100);equal(releases,0)
    conflict.PlayerEngaged=false;c:Tick(50);equal(conflict.Phase,'resolved');equal(releases,2)
    equal(a.Mission,'return');equal(b.Mission,'return');equal(a.Travel.Active,false);equal(b.Travel.Active,false)
    assert(a.unit.HP<100 and b.unit.HP<100,'Offscreen attrition must persist on the same actors')
    assert(groups[1].Detached and groups[2].Detached,'Resolved battlefield must detach surviving world parties')
    c:Tick(conflict.ExpiresAt);equal(conflict.Phase,'resolved','Occupied ruin cannot disappear');equal(releases,2)
    adventure.data.Areas.ActiveSiteId=0;c:Tick(conflict.ExpiresAt);equal(conflict.Phase,'expired');equal(releases,2)
end)

test('player intervention preserves an independent third faction',function()
    local a,b=party(1,4,0),party(2,6,1)
    local factions={adventure={parties={data={Find=function(_,id)return id==1 and a or b end}}},data={}}
    function factions:Relation(x,y)
        if x==y then return 'allied' end
        if x==4 or y==4 then return 'hostile' end
        return 'neutral'
    end
    local c=Conflicts.New(factions);local matrix,primary=c:Relations({PartyA=1,PartyB=2})
    equal(primary,2);equal(matrix[1][2],'hostile');equal(matrix[1][3],'neutral');equal(matrix[2][3],'hostile')
end)
CS=previousCS

for _,path in ipairs({'Lua/Game/Adventure/WorldParties.lua','Lua/Game/Adventure/WorldFactions.lua','Lua/Game/Adventure/WorldConflicts.lua'})do assert(loadfile(path))end
print(string.format('Faction core: %d passed; %d failed',passed,#failures))
assert(#failures==0,table.concat(failures,'\n'))
