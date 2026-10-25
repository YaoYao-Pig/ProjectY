local Hex=require('Game.Map.HexGrid')
local Discovery=require('Game.Adventure.FactionDiscovery')
local Factions={};Factions.__index=Factions
function Factions.New(adventure)
    return setmetatable({adventure=adventure,rules=require('Game.Adventure.FactionRules').New(adventure.config),
        data=CS.ProjectY.Data.WorldFactionsData.For(adventure.data)},Factions)
end
function Factions:Bind(map,sites)
    self.map=map;self.sites=sites
    self.seenFogRevision,self.seenPartyRevision,self.seenClock=nil,nil,nil
    self.seenArea,self.seenAreaRevision=nil,nil
    self:InvalidatePower()
    self.conflicts=require('Game.Adventure.WorldConflicts').New(self)
    for i=0,self.data.SiteCount-1 do self:ProjectSite(self.data:GetSiteAt(i)) end
end
function Factions:IsDiscovered(id) return Discovery.Known(self,id) end
function Factions:ObserveWorld() Discovery.World(self) end
function Factions:ObserveArea(layout,state) Discovery.Area(self,layout,state) end
function Factions:Relation(a,b)
    local rep=0
    if a==0 or b==0 then rep=self.adventure.narrative.data:GetValue('reputation:'..(a==0 and b or a)) end
    return self.rules:Relation(a,b,self.data,rep)
end
function Factions:Aggress(id)
    if self:Relation(0,id)=='hostile' then return end
    local story=self.adventure.narrative;local definition=story.rules.factions:Get(id)
    local value=math.min(story.data:GetValue('reputation:'..id)+self.rules.settings.attackReputation,
        self.rules.settings.hostileThreshold-self.rules.policies:Get(id).playerRelation)
    story.data:SetValue('reputation:'..id,math.max(definition.minValue,value))
end
function Factions:RewardAid(id)
    local story=self.adventure.narrative;local definition=story.rules.factions:Get(id)
    story.data:SetValue('reputation:'..id,math.min(definition.maxValue,story.data:GetValue('reputation:'..id)+self.rules.settings.aidReputation))
end
function Factions:Power(party)
    if self.adventure.parties.lod and party.StrengthReady and party.Lod>1 then return party.StrategicPower end
    self.powerCache=self.powerCache or {}
    if self.powerCache[party.Id] then return self.powerCache[party.Id] end
    local value=0
    for i=0,party.MemberCount-1 do local actor=party:GetMemberAt(i)
        if actor.AnimalOwnerId==0 then value=value+self.rules:Power(actor,self.adventure.battle.stats) end
    end
    self.powerCache[party.Id]=value
    return value
end
function Factions:InvalidatePower()
    self.powerCache={};self.playerPower=nil;self.strengthCache=nil
end
function Factions:PlayerPower()
    if self.playerPower~=nil then return self.playerPower end
    local value=0
    for _,actor in ipairs(self.adventure.events:LivingParty()) do value=value+self.rules:Power(actor,self.adventure.battle.stats) end
    self.playerPower=value
    return value
end
function Factions:Strength(id)
    if not self.strengthCache then
        local values={};local parties=self.adventure.parties.data
        for i=0,parties.Count-1 do local party=parties:GetAt(i)
            if not party.Defeated then
                local faction=party.FactionId
                values[faction]=(values[faction] or 0)+self:Power(party)
            end
        end
        self.strengthCache=values
    end
    return self.strengthCache[id] or 0
end
function Factions:PrepareRoster(party,encounterId,count)
    local animals=self.adventure.battle.stats.animals
    local function initializeAnimal(actor)
        local species=animals.byUnit[actor.TemplateId]
        if species and actor.AnimalSpeciesId==0 then
            actor:InitializeAnimal(species.id,(self.adventure.data.Seed ~ actor.Id)&0xffffffff)
        end
    end
    if party.MemberCount>0 then
        -- Existing legendary actors keep their identity, injuries, traits and death state.
        for i=0,party.MemberCount-1 do initializeAnimal(party:GetMemberAt(i)) end
        return
    end
    local adventure=self.adventure;local encounter=adventure.battle.encounters:Get(encounterId)
    local appearance=adventure.characterAppearances:Group(encounter.appearancePoolId,(adventure.data.Seed ~ party.Id*65537)&0xffffffff)
    for i,template in ipairs(encounter.enemyIds) do if not count or i<=count then
        local actor=party:AddMember(template)
        initializeAnimal(actor)
        adventure.battle.stats.birth:Initialize(actor,adventure.data.Seed)
        if not adventure.battle.stats.animals:IsStaticBody(actor) then adventure.characterAppearances:Assign(actor,appearance) end
        adventure.equipment:InitializeEnemy(actor)
        actor:SetMaxHP(adventure.battle.stats:MaximumHP(actor));actor:Restore()
    end end
end
function Factions:ProjectSite(state)
    local site=assert(self.sites[state.SiteId],'Faction site has no world location')
    site.factionSite=true
    if not state.IsTown then
        local definition=self.adventure.config:GetTable('FactionTable'):Get(state.FactionId)
        site.name=definition.name..'据点';site.factionOutpost=true
    end
end
function Factions:AddSite(site,faction,isTown)
    local policy=self.rules.policies:Get(faction)
    local party=self.adventure.parties.data:Add(policy.partyDefinitionId,site.q,site.r,site.id,(self.adventure.data.Seed ~ site.id*65537)&0xffffffff)
    party:ConfigureFaction(faction,site.q,site.r,'garrison')
    self:PrepareRoster(party,policy.encounterId,isTown and 2 or nil)
    local state=self.data:AddSite(site.id,faction,party.Id,isTown,policy.reserve)
    state:SetRecoveryAt(self.adventure.narrative.data.Minutes)
    self:ProjectSite(state);return state
end
function Factions:Initialize()
    self:InvalidatePower()
    self.data=CS.ProjectY.Data.WorldFactionsData.For(self.adventure.data)
    self.conflicts=require('Game.Adventure.WorldConflicts').New(self)
    if self.data.Initialized then
        for i=0,self.data.SiteCount-1 do self:ProjectSite(self.data:GetSiteAt(i)) end
        return
    end
    for _,site in ipairs(self.adventure.parties.towns) do self:AddSite(site,1,true) end
    local candidates={}
    for _,cell in ipairs(self.map:GetCells()) do
        if not cell.waterLevel and not cell.buildingId and not cell.townId then candidates[#candidates+1]=cell end
    end
    -- Seeded spatial ranking is stable across load, frame rate and candidate traversal order.
    local seed=self.adventure.data.Seed
    table.sort(candidates,function(a,b)
        local ha=((a.q*73856093) ~ (a.r*19349663) ~ seed)&0x7fffffff
        local hb=((b.q*73856093) ~ (b.r*19349663) ~ seed)&0x7fffffff
        return ha<hb or ha==hb and (a.q<b.q or a.q==b.q and a.r<b.r)
    end)
    for _,policy in ipairs(self.rules.policies:All()) do
        for n=1,policy.siteCount do
            local selected
            for _,cell in ipairs(candidates) do
                local allowed=self.rules:Suitable(policy.id,self.map:GetRegion(cell.regionId).regionType)
                for _,site in ipairs(self.sites) do
                    if Hex.Distance(cell.q,cell.r,site.q,site.r)<self.rules.settings.siteSafeRadius then allowed=false;break end
                end
                if allowed then
                    for direction=1,6 do local q,r=Hex.Neighbor(cell.q,cell.r,direction);local nextCell=self.map:FindCell(q,r)
                        if nextCell and self.adventure.travel:Cost(cell,nextCell) then selected=cell;break end
                    end
                end
                if selected then break end
            end
            if selected then
                local site=self.adventure.travel:CreateWorldStop(selected.q,selected.r,policy.encounterId)
                self:AddSite(site,policy.id,false)
            end
        end
    end
    self.data:Complete()
end
function Factions:Home(faction,q,r)
    local best,distance
    for i=0,self.data.SiteCount-1 do local site=self.data:GetSiteAt(i)
        if site.FactionId==faction and site.OccupierId==0 then
            local point=self.sites[site.SiteId];local d=Hex.Distance(q,r,point.q,point.r)
            if not distance or d<distance then best,distance=site,d end
        end
    end
    return best
end
function Factions:Threat(faction,q,r)
    local threat=0
    for i=0,self.data.SiteCount-1 do local site=self.data:GetSiteAt(i)
        local owner=site.OccupierId>0 and site.OccupierId or site.FactionId
        if self:Relation(faction,owner)=='hostile' then
            local point=self.sites[site.SiteId];local d=Hex.Distance(q,r,point.q,point.r)
            if d<self.rules.settings.siteSafeRadius then
                local guard=self.adventure.parties.data:Find(site.OccupierId>0 and site.OccupierPartyId or site.GuardPartyId)
                threat=threat+self:Power(assert(guard))*(1-d/self.rules.settings.siteSafeRadius)
            end
        end
    end
    return threat
end
function Factions:CanRoam(party,cell)
    if Hex.Distance(party.HomeQ,party.HomeR,cell.q,cell.r)>self.rules.settings.roamRadius then return false end
    return self:Threat(party.FactionId,cell.q,cell.r)<self:Power(party)*.35
end
function Factions:Think(party,minute)
    if party.Role=='garrison' or party.Defeated or party.BattleSiteId>0 or party.Mission=='occupy' or party.Mission=='escort' or party.Mission=='escort_wait' then return end
    local parties=self.adventure.parties;local travel=party.Travel;local definition=parties.definitions:Get(party.DefinitionId)
    local previousMission=party.Mission
    local target=party.TargetPartyId>0 and parties.data:Find(party.TargetPartyId)
    local targetSite=party.TargetSiteId>0 and self.data:FindSite(party.TargetSiteId)
    local invalid=previousMission=='intercept' and (not target or target.Defeated or target.BattleSiteId>0 or self:Relation(party.FactionId,target.FactionId)~='hostile') or
        previousMission=='raid' and (not targetSite or targetSite.OccupierId>0 or self:Relation(party.FactionId,targetSite.FactionId)~='hostile')
    if invalid then travel:Plan({},{},{},0);party:SetMission('patrol',0,0,minute) end
    if minute<party.DecisionAt then return end
    local policy=self.rules.policies:Get(party.FactionId);local power=self:Power(party)
    local home=party.HomeSiteId>0 and self.data:FindSite(party.HomeSiteId)
    local reserve=home and self:Power(assert(parties.data:Find(home.GuardPartyId))) or 0
    local best,bestScore,bestKind,bestReason,bestPath
    local function consider(target,kind,value,preference)
        local siege=kind=='raid'
        local point=siege and self.sites[target.SiteId] or {q=target.Travel.Q,r=target.Travel.R}
        local distance=Hex.Distance(travel.Q,travel.R,point.q,point.r)
        if distance>(siege and self.rules.settings.siteSearchRadius or definition.detectRadius) then return end
        if self:Relation(party.FactionId,target.FactionId)~='hostile' or power<=0 then return end
        -- These hard gates already make Score zero; reject them before Dijkstra and route threat queries.
        local reserveFraction=self.rules.settings.reserveFraction
        local minimumReserve=siege and power*reserveFraction/(1-reserveFraction) or 0
        local cooldown=siege and (not home or home.OccupierId>0 or home.Reserve<policy.recruitCost)
        if cooldown or reserve<minimumReserve then return end
        local defender=siege and assert(parties.data:Find(target.GuardPartyId)) or target
        if siege and (defender.Defeated or defender.BattleSiteId>0) then return end
        local defense=self:Power(defender)*(siege and self.rules.policies:Get(target.FactionId).defenseMultiplier or 1)
        local required=siege and self.rules.settings.siegeAdvantage or self.rules.settings.raidAdvantage
        if power/math.max(1,defense)<required then return end
        -- LOD catch-up can stop mid-edge; Plan preserves that edge and continues from its destination.
        local path=parties:Path(self.map:GetCell(travel.AnchorQ,travel.AnchorR),self.map:GetCell(point.q,point.r))
        if not path then return end
        local minutes,threat=0,0;for i=2,#path do
            minutes=minutes+self.adventure.travel:Cost(path[i-1],path[i])/definition.speed
            threat=math.max(threat,self:Threat(party.FactionId,path[i].q,path[i].r))
        end
        if threat>power*self.rules.settings.maximumRouteThreat then return end
        local score,reason=self.rules:Score{hostile=true,reachable=true,attack=power,defense=defense,minutes=minutes,
            threat=threat,reserve=reserve,minimumReserve=minimumReserve,
            cooldown=cooldown,value=value,preference=preference,siege=siege}
        if kind==party.Mission and (kind=='raid' and party.TargetSiteId==target.SiteId or kind=='intercept' and party.TargetPartyId==target.Id) then score=score*self.rules.settings.switchMultiplier end
        if not bestScore or score>bestScore or score==bestScore and target.Id and best.Id and target.Id<best.Id then
            best,bestScore,bestKind,bestReason,bestPath=target,score,kind,reason,path
        end
    end
    if minute>=party.SafeUntil and party.Role~='caravan' and party.CargoCount==0 then
        for i=0,parties.data.Count-1 do local target=parties.data:GetAt(i)
            if target.Id~=party.Id and target.Role~='garrison' and not target.Defeated and target.BattleSiteId==0 and minute>=target.SafeUntil then
                consider(target,'intercept',target.Role=='caravan' and 100 or 45,policy.raidPreference>0 and policy.raidPreference or 1)
            end
        end
        if policy.role=='raider' then
            for i=0,self.data.SiteCount-1 do local site=self.data:GetSiteAt(i)
                if site.OccupierId==0 and minute>=site.ProtectedUntil then
                    consider(site,'raid',150,policy.raidPreference)
                end
            end
        end
    end
    if best and bestScore>=self.rules.settings.minimumActionScore then
        local point=bestKind=='raid' and self.sites[best.SiteId] or {q=best.Travel.Q,r=best.Travel.R}
        if parties:ApplyRoute(party,bestPath) then
            party:SetMission(bestKind,bestKind=='intercept' and best.Id or 0,bestKind=='raid' and best.SiteId or 0,minute+self.rules.settings.thinkMinutes)
            return
        end
    end
    if party.Role=='caravan' then party:SetMission('trade',0,0,minute+self.rules.settings.thinkMinutes);return end
    local distance=Hex.Distance(party.HomeQ,party.HomeR,travel.Q,travel.R)
    local injured=false;for i=0,party.MemberCount-1 do local actor=party:GetMemberAt(i);if actor.HP<actor.MaxHP then injured=true;break end end
    if distance>self.rules.settings.roamRadius or injured or party.CargoCount>0 then
        party:SetMission('return',0,0,minute+self.rules.settings.thinkMinutes)
        parties:Plan(party,self.map:GetCell(party.HomeQ,party.HomeR));return
    end
    party:SetMission('patrol',0,0,minute+self.rules.settings.thinkMinutes)
    if previousMission=='raid' or previousMission=='intercept' then
        travel:Plan({},{},{},0);parties:Roam(party)
    end
end
function Factions:Recover(minute,selectedSites)
    for i=0,self.data.SiteCount-1 do local site=self.data:GetSiteAt(i)
        if (not selectedSites or selectedSites[site.SiteId]) and site.OccupierId==0 and minute>=site.LastRecoveryAt+self.rules.settings.thinkMinutes then
            local policy=self.rules.policies:Get(site.FactionId)
            local periods=math.floor((minute-site.LastRecoveryAt)/self.rules.settings.thinkMinutes)
            local previousRecovery=site.LastRecoveryAt
            local remaining=periods
            if site.LiberatedAt<0 or minute-site.LiberatedAt>=self.rules.settings.retreatMinutes then
                local candidates={assert(self.adventure.parties.data:Find(site.GuardPartyId))}
                local point=self.sites[site.SiteId]
                local homeParties=self.adventure.parties.lod and self.adventure.parties.lod.homeParties[site.SiteId]
                local count=homeParties and #homeParties or self.adventure.parties.data.Count
                for j=1,count do local party=homeParties and homeParties[j] or self.adventure.parties.data:GetAt(j-1)
                    if party.Id~=site.GuardPartyId and not party.Defeated and party.HomeSiteId==site.SiteId and party.Travel.Progress==0 and
                        Hex.Distance(party.Travel.Q,party.Travel.R,point.q,point.r)<=1 then candidates[#candidates+1]=party end
                end
                local recovered=false
                for _,guard in ipairs(candidates) do
                    local restored=false
                    if guard.Role~='caravan' and guard.CargoCount>0 and guard.BattleSiteId==0 then
                        local value=0
                        for j=0,guard.CargoCount-1 do local item=guard:GetCargoAt(j);value=value+assert(self.adventure.parties.prices[item.ItemId])*item.Count end
                        -- Delivered goods are consumed into finite supplies; physical items are never copied.
                        site:AddReserve(math.max(0,math.min(value,self.rules.settings.reserveCapacity-site.Reserve)))
                        guard:SetCargo('已交付据点的补给',{},{},{},{},{})
                    end
                    if remaining>0 and guard.BattleSiteId==0 and minute>=guard.SafeUntil then
                        for j=0,guard.MemberCount-1 do local actor=guard:GetMemberAt(j)
                            if remaining>0 and actor.AnimalOwnerId==0 and actor.HP<actor.MaxHP then
                                local needed=site.Reserve>=policy.recruitCost and 1 or policy.income>0 and math.max(1,math.ceil((policy.recruitCost-site.Reserve)/policy.income)) or math.huge
                                if needed>remaining then break end
                                site:AddReserve(math.max(0,math.min(policy.income*needed,self.rules.settings.reserveCapacity-site.Reserve)))
                                remaining=remaining-needed
                                assert(site:SpendReserve(policy.recruitCost))
                                if actor.HP==0 then
                                    CS.ProjectY.Data.EquipmentCombatState.RemoveActor(self.adventure.equipment.data,actor.Id)
                                    CS.ProjectY.Data.FactionPersistence.Replenish(actor)
                                    self.adventure.equipment:InitializeEnemy(actor)
                                else actor:Restore() end
                                guard:SetDefeated(false);recovered=true;restored=true
                            end
                        end
                        if restored and self.adventure.parties.lod then self.adventure.parties.lod:Calibrate(guard) end
                    end
                end
                if recovered then self:InvalidatePower() end
            end
            site:AddReserve(math.max(0,math.min(policy.income*remaining,self.rules.settings.reserveCapacity-site.Reserve)))
            site:SetRecoveryAt(previousRecovery+periods*self.rules.settings.thinkMinutes)
        end
    end
end
function Factions:Tick(minute)
    self:Recover(minute);self.conflicts:Tick(minute)
end
function Factions:Recovery(siteId)
    local site=self.data:FindSite(siteId)
    return site and self.rules:Recovery(site,self.adventure.narrative.data.Minutes) or 1
end
function Factions:ServiceAllowed(siteId)
    local site=self.data:FindSite(siteId)
    if site and site.OccupierId>0 then return false,'据点已被占据，击败占据者后才能恢复交易与居民活动' end
    return true
end
function Factions:NpcAvailable(siteId,id)
    local ok=self:ServiceAllowed(siteId);if not ok then return false end
    local recovery=self:Recovery(siteId)
    if recovery>=1 then return true end
    local npcs=self.adventure.narrative.rules.npcs;local rank,total=0,0
    for _,npc in ipairs(npcs:All()) do
        if npc.recruitable and self.adventure.narrative.npcs.locations[npc.id]==siteId then
            total=total+1;if npc.id<=id then rank=rank+1 end
        end
    end
    return rank<=math.floor(total*recovery)
end
function Factions:Describe(siteId)
    local site=self.data:FindSite(siteId);if not site then return nil end
    local faction=self.adventure.config:GetTable('FactionTable'):Get(site.FactionId)
    if site.OccupierId>0 then return faction.name..' · 被 '..self.adventure.config:GetTable('FactionTable'):Get(site.OccupierId).name..' 占据 · 进入解放' end
    local recovery=self:Recovery(siteId)
    return faction.name..' · 实力 '..math.floor(self:Strength(site.FactionId))..(recovery<1 and (' · 恢复 '..math.floor(recovery*100)..'%') or '')
end
return Factions
