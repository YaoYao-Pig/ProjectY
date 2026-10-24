-- Isolated real Services, config, world, shared actors and temporary expedition save.
local registry=require('Main');local adventure=registry:Get('Adventure');local results={}
local function test(name,body) body();results[#results+1]='PASS '..name end
adventure:Start(20261016,3,10000)
adventure.travel.data:SetPaused(true)
local factions,parties=adventure.factions,adventure.parties
local function find(definition,exclude)
    for i=0,parties.data.Count-1 do local party=parties.data:GetAt(i)
        if party.DefinitionId==definition and party.Role~='garrison' and not party.Defeated and party.Id~=exclude and party.BattleSiteId==0 then return party end
    end
    error('No living mobile party '..definition)
end
local function leave()
    if adventure.equipment.worldLoot.session.Active then adventure:CloseLoot() end
    if adventure.data.Phase=='area' then assert(adventure.areas:Leave()) end
    assert(adventure.data.Phase=='map')
end
local function win()
    for _,actor in ipairs(adventure.battle:Units()) do if adventure.battle:IsHostile(1,actor) then actor:Damage(actor.HP) end end
    assert(adventure.battle:CheckWinner());adventure:SettleBattle()
end
test('real world creates territorial sites, finite rosters and ecology-bound homes',function()
    assert(factions.data.Initialized and factions.data.SiteCount>2)
    local kinds={}
    for i=0,parties.data.Count-1 do local party=parties.data:GetAt(i)
        assert(party.MemberCount>0 and party.FactionId>0);kinds[party.FactionId]=true
        if party.Role=='garrison' then assert(factions.data:FindSite(party.HomeSiteId)) end
    end
    assert(kinds[1] and kinds[4] and kinds[5] and kinds[6])
    assert(factions:Relation(1,6)=='allied' and factions:Relation(1,4)=='hostile')
    assert(#adventure:Snapshot().worldParties.rows>0)
end)
local caravan,orc,firstConflict
test('NPC contact shares persistent actors and player aid preserves alliance and wounds',function()
    caravan=find(1);orc=find(4)
    local minute=adventure.narrative.data.Minutes
    firstConflict=factions.conflicts:Begin(orc,caravan,minute)
    parties.data:Target(orc.Id) -- The player is following this fight, so it must use full precision.
    local state=CS.ProjectY.Data.FactionPersistence.Find(adventure.data.Areas,firstConflict.SiteId)
    assert(state:GetEncounterAt(0):GetEnemyAt(0)==orc:GetMemberAt(0))
    local before=caravan:GetMemberAt(0).HP
    adventure.narrative:AdvanceMinutes(factions.rules.settings.conflictMinimumMinutes);parties:SyncClock()
    assert(firstConflict.Phase=='active' and caravan:GetMemberAt(0).HP<before,'Background conflict failed to advance actual wounds')
    local aid,bid,battleSite=orc.Id,caravan.Id,firstConflict.SiteId
    local savedHP=caravan:GetMemberAt(0).HP
    local save=require('Game.Adventure.CharacterSave')
    local ok,reason=save.Write(adventure);assert(ok,reason);ok,reason=save.Read(adventure);assert(ok,reason)
    orc,caravan=parties.data:Find(aid),parties.data:Find(bid);firstConflict=factions.data:FindConflict(battleSite)
    state=CS.ProjectY.Data.FactionPersistence.Find(adventure.data.Areas,battleSite)
    assert(state:GetEncounterAt(1):GetEnemyAt(0)==caravan:GetMemberAt(0) and caravan:GetMemberAt(0).HP==savedHP,'Active conflict did not reconnect its original roster')
    local wounded=caravan:GetMemberAt(0);wounded:Damage(2);local hp=wounded.HP
    assert(factions.conflicts:Enter(firstConflict));assert(firstConflict.PlayerEngaged)
    assert(wounded.HP==hp and wounded.Team~=1 and adventure.battle:PresentationTeam(wounded)==4)
    assert(adventure.battle:IsAllied(1,wounded) and not adventure.battle:IsHostile(1,wounded))
    assert(adventure.data.Battle.UnitCount>4)
    win();assert(firstConflict.Phase=='resolved' and orc.Defeated and not caravan.Defeated)
    assert(caravan:GetMemberAt(0).HP==hp,'Joining/settling healed the caravan')
    leave()
end)
test('three hostile sides retain yellow third party and require all player enemies defeated',function()
    local a,b=find(4),find(3)
    local conflict=factions.conflicts:Begin(a,b,adventure.narrative.data.Minutes)
    assert(factions.conflicts:Enter(conflict))
    assert(adventure.battle:IsHostile(a:GetMemberAt(0),b:GetMemberAt(0)))
    assert(adventure.battle:PresentationTeam(a:GetMemberAt(0))==2 and adventure.battle:PresentationTeam(b:GetMemberAt(0))==3)
    for i=0,a.MemberCount-1 do local actor=a:GetMemberAt(i);actor:Damage(actor.HP) end
    assert(not adventure.battle:CheckWinner(),'Third hostile side was ignored')
    win();leave()
end)
local liberatedSite
test('occupied town unlocks only after a player victory and starts gradual recovery',function()
    for i=0,factions.data.SiteCount-1 do local site=factions.data:GetSiteAt(i);if site.IsTown then liberatedSite=site;break end end
    assert(liberatedSite)
    local occupier=find(3);local site=adventure.sites[liberatedSite.SiteId]
    occupier.Travel:Reset(adventure.data.Seed,site.q,site.r,1)
    local guard=assert(parties.data:Find(liberatedSite.GuardPartyId))
    for i=0,guard.MemberCount-1 do local actor=guard:GetMemberAt(i);actor:Damage(actor.HP-1) end
    local siege=factions.conflicts:Begin(occupier,guard,adventure.narrative.data.Minutes,site.id)
    parties.data:Target(occupier.Id)
    adventure.narrative:AdvanceMinutes(factions.rules.settings.conflictMinimumMinutes);parties:SyncClock()
    assert(siege.Phase=='resolved' and liberatedSite.OccupierId==occupier.FactionId,'Winning siege did not occupy the town')
    assert(not factions:ServiceAllowed(site.id) and factions:Recovery(site.id)==0)
    assert(adventure:EnterSite(site.id));assert(adventure.data.Phase=='battle')
    win();assert(liberatedSite.OccupierId==0 and factions:ServiceAllowed(site.id))
    assert(math.abs(factions:Recovery(site.id)-factions.rules.settings.recoveryInitial)<.000001)
    leave()
end)
test('v18 save roundtrip retains liberation, shared rosters, ruins and damaged survivors',function()
    local id,hp=caravan.Id,caravan:GetMemberAt(0).HP
    local siteId,liberated=liberatedSite.SiteId,liberatedSite.LiberatedAt
    local count=parties.data.Count;local conflicts=factions.data.ConflictCount
    local save=require('Game.Adventure.CharacterSave')
    local ok,reason=save.Write(adventure);assert(ok,reason)
    ok,reason=save.Read(adventure);assert(ok,reason)
    assert(parties.data.Count==count and factions.data.ConflictCount==conflicts)
    assert(parties.data:Find(id):GetMemberAt(0).HP==hp)
    assert(factions.data:FindSite(siteId).LiberatedAt==liberated and factions.data:FindSite(siteId).OccupierId==0)
    assert(adventure.travel.data.Paused and adventure:Snapshot())
end)
return table.concat(results,'\n')
