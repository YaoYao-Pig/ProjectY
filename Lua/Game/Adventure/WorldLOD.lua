-- Distance controls simulation detail, never diplomacy. Persistent due times live in C# Data.
local Hex=require('Game.Map.HexGrid')
local LOD={};LOD.__index=LOD
function LOD.New(parties)
    local self=setmetatable({parties=parties,adventure=parties.adventure,
        rule=parties.adventure.config:GetTable('WorldSimulationLodTable'):Get(1)},LOD)
    assert(self.rule.mediumRadius>self.rule.nearRadius and self.rule.farMinutes>=self.rule.mediumMinutes,'Invalid simulation LOD ranges')
    self.components={};local group=0
    -- Immutable land topology is shared by every coarse query; no distant Dijkstra per update.
    local map=parties.map
    for _,cell in ipairs(map:GetCells()) do
        if not cell.waterLevel and not self.components[cell] then
            group=group+1;self.components[cell]=group
            local queue,head={cell},1
            while head<=#queue do
                local current=queue[head];head=head+1
                for _,other in ipairs(parties.paths.neighbors[current]) do
                    if not other.waterLevel and not self.components[other] and math.abs(current.height-other.height)<=self.adventure.travel.maxStep then
                        self.components[other]=group;queue[#queue+1]=other
                    end
                end
            end
        end
    end
    self.minimumStep=self.adventure.travel.rule.minutesPerCell
    for _,terrain in pairs(self.adventure.travel.terrains) do self.minimumStep=math.min(self.minimumStep,self.adventure.travel.rule.minutesPerCell*terrain.costMultiplier*self.adventure.travel.rule.roadMultiplier) end
    return self
end
function LOD:Connected(q,r,nq,nr)
    local first,last=self.parties.map:FindCell(q,r),self.parties.map:FindCell(nq,nr)
    local component=first and self.components[first]
    return component~=nil and last~=nil and component==self.components[last]
end
function LOD:Level(q,r)
    local player=self.adventure.travel.data
    local distance=Hex.Distance(q,r,player.AnchorQ,player.AnchorR)
    return distance<=self.rule.nearRadius and 1 or distance<=self.rule.mediumRadius and 2 or 3
end
function LOD:Calibrate(party)
    for i=0,party.MemberCount-1 do local actor=party:GetMemberAt(i)
        party:SetMemberStrength(i,self.adventure.factions.rules:FullPower(actor,self.adventure.battle.stats))
    end
end
function LOD:Initialize()
    self.siteRows={};self.homeParties={};self.nearParties={}
    local factions=self.adventure.factions
    for i=0,factions.data.SiteCount-1 do
        local state=factions.data:GetSiteAt(i);local point=self.adventure.sites[state.SiteId]
        self.siteRows[#self.siteRows+1]={state=state,id=state.SiteId,q=point.q,r=point.r,faction=state.FactionId,
            guard=assert(self.parties.data:Find(state.GuardPartyId))}
    end
    for i=0,self.parties.data.Count-1 do local party=self.parties.data:GetAt(i)
        if not party.StrengthReady then self:Calibrate(party) end
        local home=party.HomeSiteId
        if home>0 then
            local members=self.homeParties[home];if not members then members={};self.homeParties[home]=members end
            members[#members+1]=party
        end
    end
    if not self.parties.data.ScheduleInitialized then
        local player=self.adventure.travel.data;local rule=self.rule
        self.parties.data:Due(self.parties.data.Clock,player.AnchorQ,player.AnchorR,rule.nearRadius,rule.mediumRadius,rule.hysteresis,rule.mediumMinutes,rule.farMinutes)
    end
    for i=0,self.parties.data.Count-1 do local party=self.parties.data:GetAt(i)
        if party.Lod==1 and party.Role~='garrison' then self.nearParties[party.Id]=party end
    end
end
function LOD:MaterializeTravel(party,minute)
    if not party.AbstractTravel then return end
    local q,r=party.AbstractQ,party.AbstractR
    local duration=party.AbstractArrivalAt-party.AbstractStartedAt
    local fraction=math.min(1,math.max(0,(minute-party.AbstractStartedAt)/duration))
    party:CancelAbstractTravel()
    assert(self.parties:Plan(party,self.parties.map:GetCell(q,r)),'Abstract route lost its validated land connection')
    party.Travel:AdvanceRoute(party.Travel.RemainingMinutes*fraction)
end
function LOD:MoveCoarse(party,q,r,minute)
    local travel=party.Travel
    if travel.Q==q and travel.R==r then return true end
    if not self:Connected(travel.Q,travel.R,q,r) then return false end
    if self:Level(travel.Q,travel.R)==1 or self:Level(q,r)==1 then
        return self.parties:Plan(party,self.parties.map:GetCell(q,r))
    end
    local definition=self.parties.definitions:Get(party.DefinitionId)
    local minutes=Hex.Distance(travel.Q,travel.R,q,r)*self.adventure.travel.rule.minutesPerCell*self.rule.coarseTravelMultiplier/definition.speed
    party:BeginAbstractTravel(q,r,minute,minute+minutes,self.minimumStep/definition.speed)
    return true
end
function LOD:CoarseDecision(party,minute,level)
    local factions=self.adventure.factions;local policy=factions.rules.policies:Get(party.FactionId)
    local travel=party.Travel;local interval=level==2 and self.rule.mediumMinutes or self.rule.farMinutes
    if party.Role=='caravan' then
        local arrived=self.adventure.sites[party.DestinationSiteId]
        if arrived and travel.Q==arrived.q and travel.R==arrived.r and factions:ServiceAllowed(arrived.id) then self.parties:Restock(party) end
        local selected,best
        for _,town in ipairs(self.parties.towns) do
            if (town.q~=travel.Q or town.r~=travel.R) and factions:ServiceAllowed(town.id) and self:Connected(travel.Q,travel.R,town.q,town.r) then
                local distance=Hex.Distance(travel.Q,travel.R,town.q,town.r)
                if not best or distance<best then selected,best=town,distance end
            end
        end
        if selected then party:SetDestination(selected.id);self:MoveCoarse(party,selected.q,selected.r,minute) end
        party:SetMission('trade',0,0,minute+interval);return
    end
    if party.CargoCount>0 or minute<party.SafeUntil then
        party:SetMission('return',0,0,minute+interval);self:MoveCoarse(party,party.HomeQ,party.HomeR,minute);return
    end
    local power=party.StrategicPower
    local home=party.HomeSiteId>0 and factions.data:FindSite(party.HomeSiteId)
    local radius=level==3 and factions.rules.settings.siteSearchRadius or self.parties.definitions:Get(party.DefinitionId).detectRadius
    local nearby=self.parties.data:NearbyMobile(party.Id,radius,minute)
    local prey,preyQ,preyR,preyScore
    for i=0,nearby.Length-1 do local other=nearby[i]
        local q=other.AbstractTravel and other.AbstractQ or other.Travel.Q
        local r=other.AbstractTravel and other.AbstractR or other.Travel.R
        if factions:Relation(party.FactionId,other.FactionId)=='hostile' and self:Connected(travel.Q,travel.R,q,r) then
            local distance=Hex.Distance(travel.Q,travel.R,q,r)
            local score=factions.rules:Score{hostile=true,reachable=true,attack=power,defense=other.StrategicPower,
                minutes=distance*self.adventure.travel.rule.minutesPerCell/self.parties.definitions:Get(party.DefinitionId).speed,
                threat=0,reserve=0,minimumReserve=0,value=other.Role=='caravan' and 100 or 45,preference=policy.raidPreference>0 and policy.raidPreference or 1}
            if not preyScore or score>preyScore then prey,preyQ,preyR,preyScore=other,q,r,score end
        end
    end
    if prey and preyScore>=factions.rules.settings.minimumActionScore then
        party:SetMission('intercept',prey.Id,0,minute+interval);self:MoveCoarse(party,preyQ,preyR,minute);return
    end
    if policy.role=='raider' and home and home.OccupierId==0 and home.Reserve>=policy.recruitCost then
        local reserve=assert(self.parties.data:Find(home.GuardPartyId)).StrategicPower
        local best,bestScore
        for _,site in ipairs(self.siteRows) do
            local state=site.state
            local distance=Hex.Distance(travel.Q,travel.R,site.q,site.r)
            if distance<=factions.rules.settings.siteSearchRadius and site.faction~=party.FactionId and state.OccupierId==0 and minute>=state.ProtectedUntil and not site.guard.Defeated and site.guard.BattleSiteId==0 and
                factions:Relation(party.FactionId,site.faction)=='hostile' and self:Connected(travel.Q,travel.R,site.q,site.r) then
                if distance<=factions.rules.settings.siteSearchRadius then
                    local score=factions.rules:Score{hostile=true,reachable=true,attack=power,
                        defense=site.guard.StrategicPower*factions.rules.policies:Get(site.faction).defenseMultiplier,
                        minutes=distance*self.adventure.travel.rule.minutesPerCell/self.parties.definitions:Get(party.DefinitionId).speed,
                        threat=0,reserve=reserve,minimumReserve=power*factions.rules.settings.reserveFraction/(1-factions.rules.settings.reserveFraction),value=150,preference=policy.raidPreference,siege=true}
                    if not bestScore or score>bestScore then best,bestScore=site,score end
                end
            end
        end
        if best and bestScore>=factions.rules.settings.minimumActionScore then
            party:SetMission('raid',0,best.id,minute+interval);self:MoveCoarse(party,best.q,best.r,minute);return
        end
    end
    -- Far patrols retain their territory assignment without generating arbitrary per-cell routes.
    party:SetMission('patrol',0,0,minute+interval)
    if Hex.Distance(travel.Q,travel.R,party.HomeQ,party.HomeR)>factions.rules.settings.roamRadius then self:MoveCoarse(party,party.HomeQ,party.HomeR,minute);return end
    local patrol=factions.rules.settings.roamRadius
    for _=1,8 do
        local q,r=party.HomeQ+travel:Roll(patrol*2+1)-patrol-1,party.HomeR+travel:Roll(patrol*2+1)-patrol-1
        local cell=self.parties.map:FindCell(q,r)
        if cell and not cell.waterLevel and not cell.buildingId and (q~=travel.Q or r~=travel.R) and self:Connected(travel.Q,travel.R,q,r) and factions:CanRoam(party,cell) then
            self:MoveCoarse(party,q,r,minute);return
        end
    end
end
function LOD:CoarseStep(party,elapsed,minute,level)
    if party.Defeated or party.Role=='garrison' or party.BattleSiteId>0 or party.Mission=='occupy' then return end
    if party.AbstractTravel then
        if not party:CompleteAbstractTravel(minute) then return end
    elseif party.Travel.Active then
        party.Travel:AdvanceRoute(elapsed)
        if party.Travel.Active then return end
    end
    if party.Mission=='intercept' and party.TargetPartyId>0 then
        local target=self.parties.data:Find(party.TargetPartyId)
        if target and target.AbstractTravel then target:CompleteAbstractTravel(minute) end
        if target and not target.AbstractTravel and not target.Defeated and target.BattleSiteId==0 and minute>=target.SafeUntil and
            Hex.Distance(party.Travel.Q,party.Travel.R,target.Travel.Q,target.Travel.R)<=self.parties.rule.contactRadius and
            self.adventure.factions:Relation(party.FactionId,target.FactionId)=='hostile' and self:Connected(party.Travel.Q,party.Travel.R,target.Travel.Q,target.Travel.R) then
            self.adventure.factions.conflicts:Begin(party,target,minute,nil,self:Level(party.Travel.Q,party.Travel.R)>1);return
        end
    end
    if party.Mission=='raid' and party.TargetSiteId>0 then
        local site=self.adventure.factions.data:FindSite(party.TargetSiteId)
        local point=site and self.adventure.sites[site.SiteId]
        if site and site.OccupierId==0 and minute>=site.ProtectedUntil and point.q==party.Travel.Q and point.r==party.Travel.R then
            local guard=assert(self.parties.data:Find(site.GuardPartyId))
            if not guard.Defeated and guard.BattleSiteId==0 and self.adventure.factions:Relation(party.FactionId,guard.FactionId)=='hostile' then
                local home=self.adventure.factions.data:FindSite(party.HomeSiteId)
                if home and home:SpendReserve(self.adventure.factions.rules.policies:Get(party.FactionId).recruitCost) then
                    self.adventure.factions.conflicts:Begin(party,guard,minute,site.SiteId,self:Level(party.Travel.Q,party.Travel.R)>1);return
                end
            end
        end
    end
    if minute>=party.DecisionAt then self:CoarseDecision(party,minute,level) end
end
function LOD:Cleanup(minute)
    local factions=self.adventure.factions;local player=self.adventure.travel.data
    local moved=self.lastPlayerQ~=player.AnchorQ or self.lastPlayerR~=player.AnchorR
    if not moved and self.lastCleanup and minute-self.lastCleanup<self.rule.farMinutes then return end
    self.lastCleanup=minute;self.lastPlayerQ,self.lastPlayerR=player.AnchorQ,player.AnchorR
    local records=factions.data:UnexpiredConflicts()
    for i=0,records.Length-1 do local conflict=records[i]
        if conflict.Phase=='resolved' then
            factions.conflicts:TickConflict(conflict,minute,3)
            local site=self.adventure.sites[conflict.SiteId]
            if conflict.Phase=='resolved' and not conflict.Materialized and self:Level(site.q,site.r)==1 then factions.conflicts:Prepare(conflict) end
        end
    end
end
function LOD:Advance(minute)
    local player=self.adventure.travel.data;local rule=self.rule
    local batch=self.parties.data:Due(minute,player.AnchorQ,player.AnchorR,rule.nearRadius,rule.mediumRadius,rule.hysteresis,rule.mediumMinutes,rule.farMinutes)
    if batch.Count==0 then self:Cleanup(minute);return end
    local factions=self.adventure.factions;local hasNear=false;local conflicts={};local coarse={};local recoverSites={}
    for i=0,batch.Count-1 do local entry=batch:GetAt(i);local party=entry.Party
        if party.Lod==1 and party.Role~='garrison' then self.nearParties[party.Id]=party else self.nearParties[party.Id]=nil end
        if party.Role=='garrison' then recoverSites[party.HomeSiteId]=true end
        if party.BattleSiteId>0 then
            local conflict=factions.data:FindConflict(party.BattleSiteId)
            if conflict then conflicts[conflict.SiteId]={record=conflict,lod=math.min(entry.Lod,conflicts[conflict.SiteId] and conflicts[conflict.SiteId].lod or 3)} end
        elseif party.Role=='garrison' then
            -- Static defenders only need recovery and their conflict task, not movement/contact work.
        elseif entry.Lod==1 then
            hasNear=true
            if party.AbstractTravel then
                self:MaterializeTravel(party,minute)
                if party.Travel.Progress==0 then factions:InvalidatePower();factions:Think(party,minute) end
            elseif entry.PreviousLod>1 and entry.Elapsed>1 then
                party.Travel:AdvanceRoute(entry.Elapsed)
                factions:InvalidatePower();factions:Think(party,minute)
            else
                factions:InvalidatePower()
                local elapsed=0
                while elapsed<entry.Elapsed do
                    local step=math.min(1,entry.Elapsed-elapsed);elapsed=elapsed+step
                    self.parties:TickParty(party,entry.FromMinute+elapsed,step)
                end
            end
        else
            self:CoarseStep(party,entry.Elapsed,minute,entry.Lod);coarse[#coarse+1]=party
        end
    end
    for _,row in pairs(conflicts) do factions.conflicts:TickConflict(row.record,minute,row.lod) end
    if hasNear then
        local nearby={}
        for id,party in pairs(self.nearParties) do
            if party.Defeated or party.Lod~=1 then self.nearParties[id]=nil else nearby[#nearby+1]=party end
        end
        table.sort(nearby,function(a,b)return a.Id<b.Id end)
        factions.conflicts:Contacts(minute,1,nearby)
    end
    factions.conflicts:CoarseContacts(minute,coarse,self)
    -- Recovery itself uses absolute strategy periods; no minute-by-minute catch-up for distant sites.
    factions:Recover(minute,recoverSites)
    self:Cleanup(minute)
end
return LOD
