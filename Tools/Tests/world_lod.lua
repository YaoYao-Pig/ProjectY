-- Pure Lua checks for LOD dispatch, coarse travel and deferred battle materialization.
-- C# Due persistence/frame-splitting is tested by the Data suite; fixtures supply committed batches here.
package.path='Lua/?.lua;'..package.path
local LOD=require('Game.Adventure.WorldLOD')
local Conflicts=require('Game.Adventure.WorldConflicts')
local Factions=require('Game.Adventure.WorldFactions')
local Map=require('Game.Map.Map');local Hex=require('Game.Map.HexGrid')
local passed,failures=0,{}
local function test(name,fn)
    local ok,err=xpcall(fn,debug.traceback)
    if ok then passed=passed+1;print('PASS '..name)else failures[#failures+1]=name..': '..err;print('FAIL '..name..': '..err)end
end
local function eq(a,b,message)assert(a==b,(message or 'Unexpected value')..': '..tostring(a)..' ~= '..tostring(b))end
local lodRule={nearRadius=8,mediumRadius=24,hysteresis=2,mediumMinutes=10,farMinutes=60,coarseTravelMultiplier=1.4,farWinnerLoss=.22,farLoserLoss=.85}
local settings={roamRadius=10,siteSearchRadius=30,minimumActionScore=.04,reserveFraction=.4,thinkMinutes=30,reserveCapacity=1000,
    retreatMinutes=360,conflictMinimumMinutes=45,conflictMaximumMinutes=150,conflictTickMinutes=10,ruinMinutes=1440,attrition=.09,retreatHealth=.25}
local function unit(hp)
    return {HP=hp or 100,MaxHP=100,AnimalOwnerId=0,Damage=function(self,n)self.HP=math.max(0,self.HP-n)end,
        Restore=function(self)self.HP=self.MaxHP end,Deploy=function()error('Resolved conflict must never redeploy actors')end}
end
local function party(id,q,role)
    local p={Id=id,DefinitionId=1,FactionId=id==1 and 4 or 1,Role=role or 'patrol',HomeQ=q,HomeR=0,HomeSiteId=0,
        Defeated=false,BattleSiteId=0,SafeUntil=0,DecisionAt=1000,Mission='patrol',TargetPartyId=0,TargetSiteId=0,
        DestinationSiteId=0,CargoCount=0,MemberCount=1,StrengthReady=true,StrategicPower=100,AbstractTravel=false,Lod=3,unit=unit()}
    p.Travel={Q=q,R=0,AnchorQ=q,AnchorR=0,Progress=0,Active=false,RemainingMinutes=300,advanceCalls=0,advanced=0,
        AdvanceRoute=function(self,minutes)
            self.advanceCalls=self.advanceCalls+1;self.advanced=self.advanced+minutes
            self.RemainingMinutes=math.max(0,self.RemainingMinutes-minutes);self.Active=self.RemainingMinutes>0;self.Progress=self.Active and .5 or 0
        end,
        Plan=function(self,qs,rs)self.Active=#qs>0;self.Progress=0 end,
        Roll=function(_,maximum)return maximum//2+1 end}
    function p:GetMemberAt(i)assert(i==0);return self.unit end
    function p:SetMemberStrength(i,value)assert(i==0);self.StrengthReady=true;self.StrategicPower=value*self.unit.HP/self.unit.MaxHP end
    function p:SetMission(mission,target,site,minute)self.Mission=mission;self.TargetPartyId=target;self.TargetSiteId=site;self.DecisionAt=minute end
    function p:SetDestination(site)self.DestinationSiteId=site end
    function p:BeginAbstractTravel(q,r,minute,arrival,minStep)
        assert(not self.Travel.Active and not self.AbstractTravel and arrival>minute)
        self.AbstractTravel=true;self.AbstractQ=q;self.AbstractR=r;self.AbstractStartedAt=minute;self.AbstractArrivalAt=arrival
    end
    function p:CancelAbstractTravel()self.cancelCalls=(self.cancelCalls or 0)+1;self.AbstractTravel=false end
    function p:CompleteAbstractTravel(minute)
        self.completeCalls=(self.completeCalls or 0)+1
        if not self.AbstractTravel or minute<self.AbstractArrivalAt then return false end
        self.Travel.Q=self.AbstractQ;self.Travel.R=self.AbstractR;self.Travel.AnchorQ=self.AbstractQ;self.Travel.AnchorR=self.AbstractR
        self:CancelAbstractTravel();return true
    end
    return p
end
local function fixture(rows)
    local map=Map(7,1)
    for q=0,80 do local cell={q=q,r=0,height=q==73 and 10 or 0,waterLevel=q==70 and 1 or nil}
        map.cells[#map.cells+1]=cell;map.cellsByKey[Hex.Key(q,0)]=cell
    end
    local metrics={due=0,near=0,nearMinutes=0,coarse=0,plans=0,thinks=0,recover=0,contacts=0,coarseContacts=0,conflicts=0,restock=0}
    local data={Count=#rows,Clock=0,ScheduleInitialized=true,batch={},GetAt=function(_,i)return rows[i+1]end}
    function data:Find(id)for _,p in ipairs(rows)do if p.Id==id then return p end end end
    function data:Due(now,q,r,near,medium,hysteresis,mediumMinutes,farMinutes)
        eq(near,8);eq(medium,24);eq(hysteresis,2);eq(mediumMinutes,10);eq(farMinutes,60)
        metrics.due=metrics.due+1;self.ScheduleInitialized=true
        local batch=self.batch;self.batch={}
        for _,entry in ipairs(batch)do entry.Party.Lod=entry.Lod end -- Due commits classification before Lua receives the batch.
        return {Count=#batch,GetAt=function(_,i)return batch[i+1]end}
    end
    function data:NearbyMobile()return {Length=0}end
    local factions={rules={settings=settings,policies={Get=function()return {role='guardian',raidPreference=1,recruitCost=40,income=4}end},
        FullPower=function(_,actor)return actor.MaxHP end,Score=function()return 0 end},
        data={SiteCount=0,ConflictCount=0,FindSite=function()return nil end,UnexpiredConflicts=function()return {Length=0}end}}
    function factions:InvalidatePower()end
    function factions:Think()metrics.thinks=metrics.thinks+1 end
    function factions:Recover()metrics.recover=metrics.recover+1 end
    function factions:Relation(a,b)return a==b and 'allied' or (a==4 or b==4)and 'hostile' or 'neutral'end
    function factions:CanRoam()return true end
    function factions:ServiceAllowed()return true end
    factions.conflicts={Contacts=function(_,minute,maximum,participants)metrics.contacts=metrics.contacts+1;metrics.nearParticipants=participants end,
        CoarseContacts=function()metrics.coarseContacts=metrics.coarseContacts+1 end,
        TickConflict=function(_,conflict,minute,level)metrics.conflicts=metrics.conflicts+1;metrics.conflictLevel=level end}
    local adventure={map=map,sites={},factions=factions,config={GetTable=function(_,name)eq(name,'WorldSimulationLodTable');return {Get=function()return lodRule end}end},
        battle={stats={}},travel={map=map,maxStep=1.2,rule={minutesPerCell=8,roadMultiplier=.6},terrains={{costMultiplier=1}},data={AnchorQ=0,AnchorR=0}}}
    local parties={adventure=adventure,map=map,data=data,paths=require('Game.Map.MapPathfinder')(map),towns={},
        definitions={Get=function()return {speed=1,detectRadius=6,encounterId=404}end},rule={contactRadius=1}}
    adventure.parties=parties
    factions.adventure=adventure
    function parties:TickParty(p,minute,minutes)metrics.near=metrics.near+1;metrics.nearMinutes=metrics.nearMinutes+minutes end
    function parties:Path()error('Coarse update must not invoke Dijkstra')end
    function parties:Plan(p,target)metrics.plans=metrics.plans+1;p.Travel.Active=true;p.Travel.RemainingMinutes=200;return true end
    function parties:Restock()metrics.restock=metrics.restock+1 end
    local lod=LOD.New(parties);parties.lod=lod
    local coarse=lod.CoarseStep
    function lod:CoarseStep(...)metrics.coarse=metrics.coarse+1;return coarse(self,...)end
    lod:Initialize()
    return lod,parties,adventure,metrics
end
local function due(p,elapsed,level,previous,to)return {Party=p,Elapsed=elapsed,FromMinute=to-elapsed,ToMinute=to,Lod=level,PreviousLod=previous or level}end

test('LOD topology and radii preserve real land restrictions',function()
    local lod=fixture({})
    assert(lod:Connected(30,0,60,0));assert(not lod:Connected(69,0,71,0));assert(not lod:Connected(72,0,74,0))
    assert(not lod:Connected(1,0,100,0));eq(lod:Level(8,0),1);eq(lod:Level(9,0),2);eq(lod:Level(24,0),2);eq(lod:Level(25,0),3)
end)

test('far and medium due batches advance a stored route once without minute replay',function()
    for _,row in ipairs({{3,60,40},{2,10,16}})do
        local p=party(1,row[3]);p.Travel.Active=true
        local lod,parties,_,m=fixture({p});parties.data.batch={due(p,row[2],row[1],row[1],row[2])}
        lod:Advance(row[2]);eq(m.coarse,1);eq(m.near,0);eq(p.Travel.advanceCalls,1);eq(p.Travel.advanced,row[2]);eq(m.plans,0)
        lod:Advance(row[2]);eq(m.coarse,1,'No committed work must not replay the batch')
    end
end)

test('coarse abstract travel remains pending before arrival and chooses no path',function()
    local p=party(1,40);p:BeginAbstractTravel(50,0,0,120,4.8)
    local lod,parties,_,m=fixture({p});parties.data.batch={due(p,60,3,3,60)};lod:Advance(60)
    eq(p.completeCalls,1);eq(p.AbstractTravel,true);eq(p.Travel.Q,40);eq(p.Travel.advanceCalls,0);eq(m.plans,0);eq(m.thinks,0)
end)

test('far caravan decisions create one connected abstract journey without Dijkstra',function()
    local p=party(1,40,'caravan');p.DecisionAt=0;p.DestinationSiteId=1
    local lod,parties,adventure,m=fixture({p})
    adventure.sites[1]={id=1,q=40,r=0};adventure.sites[2]={id=2,q=50,r=0};adventure.sites[3]={id=3,q=75,r=0}
    parties.towns={adventure.sites[1],adventure.sites[3],adventure.sites[2]}
    parties.data.batch={due(p,60,3,3,60)};lod:Advance(60)
    eq(m.restock,1);eq(m.plans,0);eq(p.Mission,'trade');eq(p.DestinationSiteId,2);eq(p.AbstractTravel,true);eq(p.AbstractQ,50)
    eq(p.AbstractStartedAt,60);eq(p.AbstractArrivalAt,172)
end)

test('promotion materializes abstract progress once without adding elapsed movement twice',function()
    local p=party(1,40);p:BeginAbstractTravel(50,0,0,120,4.8)
    local lod,parties,_,m=fixture({p});parties.data.batch={due(p,10,1,3,60)};lod:Advance(60)
    eq(p.cancelCalls,1);eq(p.AbstractTravel,false);eq(m.plans,1);eq(p.Travel.advanceCalls,1);eq(p.Travel.advanced,100)
    eq(m.near,0,'Materialized progress already includes elapsed time')
    lod:Advance(60);eq(p.cancelCalls,1);eq(m.plans,1);eq(p.Travel.advanced,100)
end)

test('coarse promotion catches up a normal route once and shared conflict work is deduplicated',function()
    local p=party(1,40);p.Travel.Active=true
    local lod,parties,adventure,m=fixture({p});parties.data.batch={due(p,25,1,3,60)};lod:Advance(60)
    eq(p.Travel.advanceCalls,1);eq(p.Travel.advanced,25);eq(m.near,0)
    local other=party(2,40);p.BattleSiteId=99;other.BattleSiteId=99
    local record={SiteId=99,Phase='active'}
    adventure.factions.data.FindConflict=function(_,id)eq(id,99);return record end
    parties.data.batch={due(p,10,2,2,70),due(other,60,3,3,70)};lod:Advance(70)
    eq(m.conflicts,1);eq(m.conflictLevel,2,'The more detailed participating LOD wins')
end)

test('empty due batches still expire unoccupied ruins and never remove the active area',function()
    local lod,_,adventure,m=fixture({});local expires,queries=0,0
    local record={SiteId=99,Phase='resolved',Materialized=true,ExpiresAt=30,
        Expire=function(self)expires=expires+1;self.Phase='expired'end}
    adventure.data={Areas={ActiveSiteId=99}};adventure.sites[99]={q=40,r=0}
    adventure.factions.conflicts=Conflicts.New(adventure.factions)
    function adventure.factions.data:UnexpiredConflicts()
        queries=queries+1;return record.Phase=='expired' and {Length=0} or {Length=1,[0]=record}
    end
    lod:Advance(0);eq(queries,1);lod:Advance(59);eq(queries,1,'Do not scan historical conflicts each minute')
    lod:Advance(60);eq(queries,2);eq(record.Phase,'resolved');eq(expires,0,'The active ruin must remain usable')
    adventure.data.Areas.ActiveSiteId=0;adventure.travel.data.AnchorQ=1
    lod:Advance(61);eq(record.Phase,'expired');eq(expires,1,'Leaving must clean an expired ruin even without party work')
    lod:Advance(121);eq(expires,1);eq(m.near,0);eq(m.coarse,0)
end)

test('near garrisons only schedule recovery instead of movement or contacts',function()
    local p=party(1,3,'garrison');p.HomeSiteId=1
    local lod,parties,_,m=fixture({p});parties.data.batch={due(p,1,1,1,1)};lod:Advance(1)
    eq(m.recover,1);eq(m.near,0);eq(m.coarse,0);eq(m.contacts,0);eq(p.Travel.advanceCalls,0)
end)

test('near contact queries receive only the cached near mobile subset',function()
    local first,second,far,guard=party(1,3),party(2,5),party(3,40),party(4,2,'garrison')
    first.Lod=1;second.Lod=1;guard.Lod=1
    local lod,parties,_,m=fixture({first,second,far,guard})
    parties.data.batch={due(first,1,1,1,1),due(guard,1,1,1,1)};lod:Advance(1)
    eq(m.contacts,1);eq(#m.nearParticipants,2)
    eq(m.nearParticipants[1],first);eq(m.nearParticipants[2],second,'Near participants without a due step must remain in contact queries')
    for _,p in ipairs(m.nearParticipants)do assert(p~=far and p~=guard,'Far parties and static garrisons must not enter the near mobile scan')end
    eq(lod.nearParties[far.Id],nil);eq(lod.nearParties[guard.Id],nil)
end)

local previousCS=CS
CS={ProjectY={Data={FactionPersistence={
    Find=function(areas,id)return areas.states[id]end,
    Ensure=function(areas,id)
        local state={groups={},EncounterCount=0,loot={}}
        function state:AddEncounter(index,encounter)local group={PartyId=0,Detached=false};self.groups[index]=group;self.EncounterCount=#self.groups;return group end
        function state:GetEncounterAt(i)return self.groups[i+1]end
        function state:CompleteEncounterInitialization()self.EncountersInitialized=true end
        function state:CompleteLootInitialization()self.LootInitialized=true end
        areas.states[id]=state;return state
    end,
    AttachParty=function(group,p)group.PartyId=p.Id;group.actors={p.unit}end,
    DetachParty=function(group)group.Detached=true;group.actors={}end,
    PartyId=function(group)return group.PartyId end},ExpeditionPersistence={Definition=function(state,id)state.configId=id end}}}}

local function conflictFixture()
    local a,b=party(1,40),party(2,40);a.StrategicPower=200;b.StrategicPower=50
    local m={generated=0,releases=0,resolves=0,deferred=0,drops=0,rolls=0};local rows={a,b}
    local factions={rules={settings=settings},data={},InvalidatePower=function()end,Power=function(_,p)return p.StrategicPower end,
        Relation=function(_,x,y)return x==y and 'allied' or (x==4 or y==4)and 'hostile' or 'neutral'end}
    local pd={Find=function(_,id)return rows[id]end,
        EngageParty=function(_,id,site)rows[id].BattleSiteId=site end,
        ReleaseParty=function(_,id,dead,safe)m.releases=m.releases+1;rows[id].BattleSiteId=0;rows[id].Defeated=dead;rows[id].SafeUntil=safe end,
        CaptureCargo=function()return false end,
        DeferCargo=function(_,id,c)
            local cargo=rows[id].Cargo;if not cargo then return false end
            c.pending[#c.pending+1]=cargo;c.PendingCargoCount=#c.pending;rows[id].Cargo=nil;m.deferred=m.deferred+1;return true
        end,
        DropPartyCargo=function()error('Remote resolution must not require a local loot container')end,
        DropDeferredCargo=function(_,c,state,index)
            eq(index,1);assert(c.Materialized)
            for _,cargo in ipairs(c.pending)do state.loot[#state.loot+1]=cargo;m.drops=m.drops+1 end
            c.pending={};c.PendingCargoCount=0
        end}
    local adventure={data={Seed=71,Areas={states={},ActiveSiteId=0}},sites={},
        parties={data=pd,definitions={Get=function()return {encounterId=404}end},lod={rule=lodRule}},
        areas={layouts={},battlefieldAreaId=1001,generator={Generate=function()m.generated=m.generated+1;return {cells={{q=0,r=0,index=1}},entryIndex=1,configId=1001}end}},
        travel={},equipment={worldLoot={ActorDrops=function()error('Remote resolution must not generate actor drops')end}},battle={stats={}}}
    function adventure.travel:CreateWorldStop(q,r)adventure.sites[99]={id=99,q=q,r=r};return adventure.sites[99]end
    function factions.data:AddAbstractConflict(site,first,second,created,minimum,expires)
        local c={SiteId=site,PartyA=first,PartyB=second,Phase='active',Materialized=false,PlayerEngaged=false,TargetSiteId=0,
            MinimumEndAt=minimum,NextTickAt=created,ExpiresAt=expires,pending={},PendingCargoCount=0}
        function c:SetTargetSite(id)self.TargetSiteId=id end
        function c:Roll()m.rolls=m.rolls+1;return 10 end
        function c:TickAt(time)self.NextTickAt=time end
        function c:Engage(value)self.PlayerEngaged=value end
        function c:Resolve(winner,expires)m.resolves=m.resolves+1;self.Phase='resolved';self.WinnerPartyId=winner;self.ExpiresAt=expires end
        function c:Expire()self.Phase='expired'end
        function c:MarkMaterialized()self.Materialized=true end
        return c
    end
    factions.adventure=adventure
    local conflicts=Conflicts.New(factions);function conflicts:Source()return {}end
    return conflicts,a,b,m,adventure
end

test('far conflicts settle once with persistent cargo and no battlefield generation',function()
    local c,a,b,m=conflictFixture();local cargo={identity=123};b.Cargo=cargo
    local conflict=c:Begin(a,b,0,nil,true);eq(m.generated,0);eq(conflict.Materialized,false)
    conflict.PlayerEngaged=true;c:TickConflict(conflict,60,3);eq(m.resolves,0);eq(a.unit.HP,100)
    conflict.PlayerEngaged=false;c:TickConflict(conflict,60,3)
    eq(conflict.Phase,'resolved');eq(m.generated,0);eq(m.resolves,1);eq(m.releases,2);eq(m.rolls,1)
    eq(conflict.PendingCargoCount,1);eq(conflict.pending[1],cargo);eq(b.Cargo,nil);eq(m.deferred,1)
    assert(a.unit.HP<100 and b.unit.HP<100,'Summary casualties must affect the original actors')
    c:TickConflict(conflict,120,3);eq(m.resolves,1);eq(m.deferred,1)
    local _,state=c:Prepare(conflict)
    eq(m.generated,1);eq(conflict.Materialized,true);eq(conflict.PendingCargoCount,0);eq(state.loot[1],cargo);eq(m.drops,1)
    for _,group in ipairs(state.groups)do assert(group.Detached and #group.actors==0,'A resolved ruin must not respawn a party')end
    c:Prepare(conflict);eq(m.generated,1);eq(m.drops,1)
end)

test('medium and near conflict relations use the same diplomacy authority',function()
    local c,a,b,m=conflictFixture();b.FactionId=6
    local conflict=c:Begin(a,b,0,nil,true)
    local before,primary=c:Relations(conflict);eq(primary,2);eq(before[1][2],'hostile');eq(before[1][3],'neutral');eq(before[2][3],'hostile')
    c:TickConflict(conflict,45,2);eq(m.generated,0);eq(conflict.Phase,'active')
    local after,again=c:Relations(conflict);eq(again,primary)
    for first,row in pairs(before)do for second,relation in pairs(row)do eq(after[first][second],relation)end end
end)

test('batched recovery preserves strategic income periods and cap-before-spend order',function()
    local function economy()
        local actors={unit(50),unit(50)}
        local guard={Id=1,HomeSiteId=1,FactionId=1,Role='garrison',CargoCount=0,BattleSiteId=0,SafeUntil=0,MemberCount=2,
            GetMemberAt=function(_,i)return actors[i+1]end,SetDefeated=function(_,v)eq(v,false)end}
        local site={SiteId=1,FactionId=1,GuardPartyId=1,OccupierId=0,LiberatedAt=-1,LastRecoveryAt=0,Reserve=1000,
            AddReserve=function(self,n)assert(n>=0);self.Reserve=self.Reserve+n end,
            SpendReserve=function(self,n)assert(n<=self.Reserve);self.Reserve=self.Reserve-n;return true end,
            SetRecoveryAt=function(self,n)self.LastRecoveryAt=n end}
        local f=setmetatable({sites={[1]={q=0,r=0}},data={SiteCount=1,GetSiteAt=function()return site end},
            rules={settings=settings,policies={Get=function()return {income=4,recruitCost=40}end}},
            adventure={parties={data={Count=1,GetAt=function()return guard end,Find=function()return guard end}}}},Factions)
        return f,site,actors
    end
    local batch,site,actors=economy();batch:Recover(60)
    eq(site.Reserve,924);eq(site.LastRecoveryAt,60);eq(actors[1].HP,100);eq(actors[2].HP,100)
    local split,other=economy();split:Recover(30);split:Recover(60);eq(other.Reserve,site.Reserve)
    batch:Recover(60);eq(site.Reserve,924,'Same period must not pay income or heal twice')
end)
CS=previousCS
print(string.format('World LOD: %d passed; %d failed',passed,#failures))
assert(#failures==0,table.concat(failures,'\n'))
