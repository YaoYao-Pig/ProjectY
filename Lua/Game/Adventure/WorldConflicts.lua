local Hex=require('Game.Map.HexGrid')
local Conflicts={};Conflicts.__index=Conflicts
function Conflicts.New(factions) return setmetatable({factions=factions,adventure=factions.adventure,data=factions.data},Conflicts) end
function Conflicts:Parties(conflict)
    local data=self.adventure.parties.data
    local result={assert(data:Find(conflict.PartyA))}
    if conflict.PartyB>0 then result[#result+1]=assert(data:Find(conflict.PartyB)) end
    return result
end
function Conflicts:Source(site,encounterId)
    local travel=self.adventure.travel;local cell=travel.map:GetCell(site.q,site.r);local region=travel.map:GetRegion(cell.regionId)
    local terrain=travel:Terrain(cell)
    return {regionId=region.instanceId,regionConfigId=region.configId,regionType=region.regionType,
        q=cell.q,r=cell.r,height=cell.height,biomeWeights=cell.biomeWeights,encounterId=encounterId,
        factionConflict=true,obstacleChance=.06,surfaceId=terrain.battleSurfaceId,propIds=terrain.battlePropIds}
end
function Conflicts:Prepare(conflict)
    local adventure=self.adventure;local areas=adventure.areas;local site=assert(adventure.sites[conflict.SiteId])
    local existing=CS.ProjectY.Data.FactionPersistence.Find(adventure.data.Areas,site.id)
    if existing then return assert(areas.layouts[site.id]),existing end
    local participants=self:Parties(conflict)
    local encounterId=adventure.parties.definitions:Get(participants[1].DefinitionId).encounterId
    local layout=areas.generator:Generate(areas.battlefieldAreaId,adventure.data.Seed,site.id,self:Source(site,encounterId))
    areas.layouts[site.id]=layout
    local state=CS.ProjectY.Data.FactionPersistence.Ensure(adventure.data.Areas,site.id,#layout.cells,layout.entryIndex)
    CS.ProjectY.Data.ExpeditionPersistence.Definition(state,layout.configId)
    local occupied={}
    for index,party in ipairs(participants) do
        local group=state:AddEncounter(index,adventure.parties.definitions:Get(party.DefinitionId).encounterId)
        if conflict.Phase~='active' then
            CS.ProjectY.Data.FactionPersistence.AttachParty(group,party)
        else
        local candidates={}
        for _,cell in ipairs(layout.cells) do if not cell.blocked and cell.q>=0 then candidates[#candidates+1]=cell end end
        local tq,tr=index==1 and 5 or 2,index==1 and -4 or 4
        table.sort(candidates,function(a,b)
            local da,db=Hex.Distance(a.q,a.r,tq,tr),Hex.Distance(b.q,b.r,tq,tr)
            return da<db or da==db and a.index<b.index
        end)
        for i=0,party.MemberCount-1 do local actor=party:GetMemberAt(i)
            if actor.AnimalOwnerId==0 then
            local found
            for _,cell in ipairs(candidates) do
                if adventure.battle.stats.animals:CanPlace(actor,layout,cell.q,cell.r,occupied) then
                    actor:Deploy(index+1,cell.q,cell.r);adventure.battle.stats.animals:Occupy(actor,layout,occupied);found=true;break
                end
            end
            assert(found,'World conflict cannot fit party footprint')
            end
        end
        CS.ProjectY.Data.FactionPersistence.AttachParty(group,party)
        end
    end
    state:CompleteEncounterInitialization()
    if conflict.Phase~='active' then
        -- Initialize the historical links before retiring them, as in a resolved detailed battlefield.
        for i=0,state.EncounterCount-1 do CS.ProjectY.Data.FactionPersistence.DetachParty(state:GetEncounterAt(i)) end
    end
    state:CompleteLootInitialization()
    conflict:MarkMaterialized()
    adventure.parties.data:DropDeferredCargo(conflict,state,layout.entryIndex)
    return layout,state
end
function Conflicts:Begin(a,b,minute,targetSite,abstract)
    assert(a.BattleSiteId==0 and (not b or b.BattleSiteId==0),'Party already in conflict')
    local site=self.adventure.travel:CreateWorldStop(a.Travel.Q,a.Travel.R,self.adventure.parties.definitions:Get(a.DefinitionId).encounterId)
    site.name=targetSite and (self.adventure.sites[targetSite].name..' · 争夺战') or '交战中的队伍'
    local rule=self.factions.rules.settings
    local add=abstract and self.data.AddAbstractConflict or self.data.AddConflict
    local conflict=add(self.data,site.id,a.Id,b and b.Id or 0,minute,minute+rule.conflictMinimumMinutes,minute+rule.conflictMaximumMinutes,(self.adventure.data.Seed ~ site.id*104729)&0xffffffff)
    if targetSite then conflict:SetTargetSite(targetSite) end
    self.adventure.parties.data:EngageParty(a.Id,site.id)
    if b then self.adventure.parties.data:EngageParty(b.Id,site.id) end
    if not abstract then self:Prepare(conflict) end
    return conflict
end
function Conflicts:Near(a,b)
    local first,second=a.Travel,b.Travel
    if first.Progress~=0 or second.Progress~=0 then return false end
    local adventure=self.adventure;local range=adventure.parties.rule.contactRadius
    local aq,ar,bq,br=first.Q,first.R,second.Q,second.R
    local distance=Hex.Distance(aq,ar,bq,br)
    if distance>range then return false end
    local from,to=adventure.map:GetCell(aq,ar),adventure.map:GetCell(bq,br)
    -- With a one-edge contact budget an impassable direct edge cannot qualify by detouring.
    if range==1 and distance==1 and adventure.travel:Cost(from,to)==nil then return false end
    local path=adventure.parties:Path(from,to)
    return path~=nil and #path-1<=range
end
function Conflicts:Contacts(minute,maximumLod,participants)
    local data=self.adventure.parties.data;local range=self.adventure.parties.rule.contactRadius
    local moving,byId,relations={},{},{}
    -- A simulation tick does not move parties. Read each bridge object once, then compare Lua values.
    local function capture(party)
        local row={party=party,Id=party.Id,busy=party.Defeated or party.BattleSiteId~=0}
        byId[row.Id]=row
        if not row.busy then
            local travel=party.Travel
            row.Travel={Q=travel.Q,R=travel.R,Progress=travel.Progress};row.FactionId=party.FactionId
            local role,mission=party.Role,party.Mission
            if role~='garrison' and mission~='occupy' and minute>=party.SafeUntil and row.Travel.Progress==0 and
                (not maximumLod or party.Lod<=maximumLod) then
                row.mission=mission
                if mission=='raid' then row.target=party.TargetSiteId;row.home=party.HomeSiteId end
                moving[#moving+1]=row
            end
        end
        return row
    end
    if participants then for _,party in ipairs(participants) do capture(party) end
    else for i=0,data.Count-1 do capture(data:GetAt(i)) end end
    local function nearby(a,b)
        local first,second=a.Travel,b.Travel
        return not b.busy and second.Progress==0 and Hex.Distance(first.Q,first.R,second.Q,second.R)<=range
    end
    local function hostile(a,b)
        local first,second=math.min(a.FactionId,b.FactionId),math.max(a.FactionId,b.FactionId)
        local relation=relations[first]
        if not relation then relation={};relations[first]=relation end
        if relation[second]==nil then relation[second]=self.factions:Relation(first,second)=='hostile' end
        return relation[second]
    end
    for i,a in ipairs(moving) do
        if not a.busy then
            if a.mission=='raid' and a.target>0 then
                local target=self.data:FindSite(a.target)
                if target and target.OccupierId==0 and minute>=target.ProtectedUntil then
                    local b=byId[target.GuardPartyId] or capture(assert(data:Find(target.GuardPartyId),'Faction site guard has no world party'))
                    if nearby(a,b) and hostile(a,b) and self:Near(a,b) then
                        local home=self.data:FindSite(a.home)
                        local cost=self.factions.rules.policies:Get(a.FactionId).recruitCost
                        if home and home.OccupierId==0 and home:SpendReserve(cost) then
                            self:Begin(a.party,b.party,minute,target.SiteId);a.busy=true;b.busy=true
                        end
                    end
                end
            end
            if not a.busy then for j=i+1,#moving do local b=moving[j]
                if nearby(a,b) and hostile(a,b) and self:Near(a,b) then
                    self:Begin(a.party,b.party,minute);a.busy=true;b.busy=true;break
                end
            end end
        end
    end
end
local function living(party)
    local actors,hp,maximum={},0,0
    for i=0,party.MemberCount-1 do local actor=party:GetMemberAt(i)
        if actor.AnimalOwnerId==0 then
        hp=hp+actor.HP;maximum=maximum+actor.MaxHP
        if actor.HP>0 then actors[#actors+1]=actor end
        end
    end
    return actors,hp,maximum
end
function Conflicts:Damage(party,amount)
    local actors=living(party)
    if #actors==0 then return end
    local share=math.max(1,math.floor(amount/#actors))
    for _,actor in ipairs(actors) do actor:Damage(share) end
end
function Conflicts:Resolve(conflict,winner,minute)
    self.factions:InvalidatePower()
    local layout,state
    if conflict.Materialized then layout,state=self:Prepare(conflict) end
    local data=self.adventure.parties.data
    local facade=state and {data={Active=state},ActiveLayout=function()return layout end}
    if winner>0 then
        local winningParty=assert(data:Find(winner))
        local takesCargo=winningParty.Role=='raider' or winningParty.Role=='patrol' or winningParty.Role=='caravan'
        for _,party in ipairs(self:Parties(conflict)) do
            if party.Id~=winner and party.Cargo then
                if not takesCargo or not data:CaptureCargo(winner,party.Id) then
                    if state then data:DropPartyCargo(party.Id,state,layout.entryIndex) else data:DeferCargo(party.Id,conflict) end
                end
            end
        end
    end
    for _,party in ipairs(self:Parties(conflict)) do
        local actors={};for i=0,party.MemberCount-1 do local actor=party:GetMemberAt(i);if actor.AnimalOwnerId==0 then actors[#actors+1]=actor end end
        if facade then self.adventure.equipment.worldLoot:ActorDrops(facade,actors,self.adventure.battle.stats) end
        local _,hp=living(party)
        if hp==0 then
            if state then data:DropPartyCargo(party.Id,state,layout.entryIndex) else data:DeferCargo(party.Id,conflict) end
        end
        data:ReleaseParty(party.Id,hp==0,minute+self.factions.rules.settings.retreatMinutes)
        if hp>0 and party.Role~='garrison' then
            party.Travel:Plan({},{},{},0)
            if party.Mission~='escort' and party.Mission~='escort_wait' then party:SetMission('return',0,0,minute) end
        end
    end
    if conflict.TargetSiteId>0 and winner>0 then
        local site=assert(self.data:FindSite(conflict.TargetSiteId));local party=assert(data:Find(winner))
        if party.FactionId~=site.FactionId and self.factions:Relation(party.FactionId,site.FactionId)=='hostile' then
            site:SetOccupation(party.FactionId,party.Id,minute)
            party:SetMission('occupy',0,site.SiteId,minute+self.factions.rules.settings.thinkMinutes)
        end
    end
    if state then for i=0,state.EncounterCount-1 do local group=state:GetEncounterAt(i);if CS.ProjectY.Data.FactionPersistence.PartyId(group)>0 then CS.ProjectY.Data.FactionPersistence.DetachParty(group) end end end
    if state and self.adventure.parties.lod then for _,party in ipairs(self:Parties(conflict)) do self.adventure.parties.lod:Calibrate(party) end end
    conflict:Engage(false);conflict:Resolve(winner,minute+self.factions.rules.settings.ruinMinutes)
end
function Conflicts:Tick(minute)
    for i=0,self.data.ConflictCount-1 do local conflict=self.data:GetConflictAt(i)
        self:TickConflict(conflict,minute,1)
    end
    self:Contacts(minute)
end
function Conflicts:TickConflict(conflict,minute,lod)
    local rule=self.factions.rules.settings
    if lod==1 and not conflict.Materialized and conflict.Phase=='active' then self:Prepare(conflict) end
    if conflict.Phase=='active' and not conflict.PlayerEngaged and conflict.PartyB>0 and minute>=conflict.MinimumEndAt and minute>=conflict.NextTickAt then
            local parties=self:Parties(conflict);local a,b=parties[1],parties[2]
            local _,ha,ma=living(a);local _,hb,mb=living(b)
            if lod==3 then
                local settings=self.adventure.parties.lod.rule
                local pa,pb=a.StrategicPower,b.StrategicPower
                local winner=pa*(.9+conflict:Roll(21)/100)>=pb and a or b
                local loser=winner==a and b or a
                local ratio=loser.StrategicPower/math.max(1,winner.StrategicPower)
                self:Damage(winner,(winner==a and ma or mb)*math.min(.65,settings.farWinnerLoss*ratio))
                self:Damage(loser,(loser==a and ma or mb)*settings.farLoserLoss)
                local _,hp=living(winner)
                self:Resolve(conflict,hp>0 and winner.Id or 0,minute);return
            end
            local pa,pb=self.factions:Power(a),self.factions:Power(b)
            local noise=.85+conflict:Roll(31)/100
            local steps=lod==2 and math.max(1,math.floor((minute-math.max(conflict.MinimumEndAt,conflict.NextTickAt))/rule.conflictTickMinutes)+1) or 1
            self:Damage(a,ma*rule.attrition*pb/math.max(1,pa)*noise*steps)
            self:Damage(b,mb*rule.attrition*pa/math.max(1,pb)/noise*steps)
            local _,na=living(a);local _,nb=living(b)
            conflict:TickAt(minute+rule.conflictTickMinutes)
            if na==0 or nb==0 or na/ma<=rule.retreatHealth or nb/mb<=rule.retreatHealth or minute>=conflict.ExpiresAt then
                local winner=na==0 and (nb>0 and b.Id or 0) or nb==0 and a.Id or (na/ma>nb/mb and a.Id or b.Id)
                self:Resolve(conflict,winner,minute)
            end
    elseif conflict.Phase=='resolved' and minute>=conflict.ExpiresAt and self.adventure.data.Areas.ActiveSiteId~=conflict.SiteId then
            conflict:Expire()
    end
end
function Conflicts:CoarseContacts(minute,parties,lod)
    for i,a in ipairs(parties) do
        if not a.Defeated and a.BattleSiteId==0 and not a.AbstractTravel and a.Role~='garrison' and a.Mission~='occupy' and minute>=a.SafeUntil then
            for j=i+1,#parties do local b=parties[j]
                if not b.Defeated and b.BattleSiteId==0 and not b.AbstractTravel and b.Role~='garrison' and b.Mission~='occupy' and minute>=b.SafeUntil and
                    Hex.Distance(a.Travel.Q,a.Travel.R,b.Travel.Q,b.Travel.R)<=self.adventure.parties.rule.contactRadius and
                    self.factions:Relation(a.FactionId,b.FactionId)=='hostile' and lod:Connected(a.Travel.Q,a.Travel.R,b.Travel.Q,b.Travel.R) then
                    self:Begin(a,b,minute,nil,true);break
                end
            end
        end
    end
end
function Conflicts:Relations(conflict,protectedPartyId)
    local teams={[1]=0};local relations={};local primary
    local protectedTeam
    for i,party in ipairs(self:Parties(conflict)) do
        teams[i+1]=party.FactionId
        if not primary and self.factions:Relation(0,party.FactionId)=='hostile' then primary=i+1 end
        if party.Id==protectedPartyId then protectedTeam=i+1 end
    end
    for a,first in pairs(teams) do relations[a]={};for b,second in pairs(teams) do relations[a][b]=self.factions:Relation(first,second) end end
    if protectedPartyId then
        assert(protectedTeam,'Protected escort is not a conflict participant');primary=nil
        for side in pairs(teams) do if side~=1 then
            local relation=side==protectedTeam and 'allied' or relations[protectedTeam][side]
            relations[1][side]=relation;relations[side][1]=relation
            if not primary and relation=='hostile' then primary=side end
        end end
    end
    return relations,primary
end
function Conflicts:Enter(conflict,protectedPartyId)
    if conflict.Phase=='expired' then return false,'这片战场遗迹已经消散' end
    local adventure=self.adventure;local site=adventure.sites[conflict.SiteId]
    local layout,state=self:Prepare(conflict)
    if conflict.Phase=='resolved' then
        local ok,reason=adventure.areas:Enter(site,adventure.data.Seed)
        if ok then adventure.equipment:InitializeLoot(adventure.areas) end
        return ok,reason
    end
    local relations,primary=self:Relations(conflict,protectedPartyId)
    if not primary then return false,'交战双方与你均无敌对关系，队伍保持中立' end
    CS.ProjectY.Data.WorldTravelData.BeginBattle(adventure.data,site.id)
    assert(adventure.areas:Activate(site,adventure.data.Seed,true))
    conflict:Engage(true)
    adventure.equipment:InitializeLoot(adventure.areas)
    adventure.areas:StartBattle(adventure.battle,state:GetEncounterAt(0),{relations=relations,primary=primary,conflict=conflict})
    return true
end
function Conflicts:Attack(party)
    self.factions:Aggress(party.FactionId)
    local conflict=party.BattleSiteId>0 and self.data:FindConflict(party.BattleSiteId)
    if not conflict then conflict=self:Begin(party,nil,self.adventure.narrative.data.Minutes) end
    self.adventure.parties.data:Close()
    return self:Enter(conflict)
end
function Conflicts:EnterSite(siteId)
    local conflict=self.data:FindConflict(siteId)
    if conflict then return true,self:Enter(conflict) end
    local site=self.data:FindSite(siteId)
    if not site then return false end
    if site.OccupierId>0 then
        local party=assert(self.adventure.parties.data:Find(site.OccupierPartyId))
        self.factions:Aggress(party.FactionId)
        local fight=party.BattleSiteId>0 and self.data:FindConflict(party.BattleSiteId)
        if not fight then fight=self:Begin(party,nil,self.adventure.narrative.data.Minutes,siteId) end
        return true,self:Enter(fight)
    end
    if not site.IsTown then
        if self.factions:Relation(0,site.FactionId)~='hostile' then return true,false,'这是友好势力的驻地，巡守队正在维持边境' end
        local party=assert(self.adventure.parties.data:Find(site.GuardPartyId))
        if party.Defeated then return true,false,'据点正在恢复守军' end
        local fight=party.BattleSiteId>0 and self.data:FindConflict(party.BattleSiteId)
        if not fight then fight=self:Begin(party,nil,self.adventure.narrative.data.Minutes,siteId) end
        return true,self:Enter(fight)
    end
    return false
end
function Conflicts:Settle(result)
    local conflict=self.data:FindConflict(self.adventure.data.SiteId)
    if not conflict or conflict.Phase~='active' then return false,0 end
    local minute=self.adventure.narrative.data.Minutes
    if result=='victory' then
        local winner=0
        for _,party in ipairs(self:Parties(conflict)) do
            local _,hp=living(party)
            if hp>0 and not self.adventure.battle:IsHostile(1,party:GetMemberAt(0)) then winner=party.Id;self.factions:RewardAid(party.FactionId) end
        end
        local target=conflict.TargetSiteId>0 and self.data:FindSite(conflict.TargetSiteId)
        local liberating=target and target.OccupierId>0
        self:Resolve(conflict,winner,minute)
        if liberating then
            target:Liberate(minute,minute+self.factions.rules.settings.occupationProtectionMinutes)
            target:SetRecoveryAt(minute)
            self.factions:RewardAid(target.FactionId)
        end
    else
        local story=self.adventure.narrative;local escort=story and story.townMissions and story.townMissions.escort
        if escort and escort.data.AttachedId>0 then escort:Detach() end
        conflict:Engage(false)
        local retired,winner=false,0
        for _,party in ipairs(self:Parties(conflict))do
            local _,hp=living(party)
            if hp==0 then retired=true else winner=party.Id end
        end
        if retired then self:Resolve(conflict,winner,minute)
        elseif conflict.PartyB==0 then self:Resolve(conflict,conflict.PartyA,minute) end
    end
    return true,0
end
return Conflicts
