-- First sightings are expedition facts in NarrativeData; Lua retains only observation stamps.
local Discovery={}
local function key(id) return 'faction_seen:'..id end
function Discovery.Known(factions,id)
    return id==0 or factions.adventure.narrative.data:GetValue(key(id))==1
end
function Discovery.Mark(factions,id)
    if id==0 then return end
    factions.rules.policies:Get(id)
    local data=factions.adventure.narrative.data
    if data:GetValue(key(id))~=1 then data:SetValue(key(id),1) end
end
function Discovery.World(factions)
    local adventure=factions.adventure
    if adventure.data.Phase~='map' then return end
    local fog,parties=adventure.fog,adventure.parties.data
    if factions.seenFogRevision==fog.data.Revision and factions.seenPartyRevision==parties.Revision and factions.seenClock==parties.Clock then return end
    factions.seenFogRevision,factions.seenPartyRevision,factions.seenClock=fog.data.Revision,parties.Revision,parties.Clock
    for i=0,parties.Count-1 do
        local party=parties:GetAt(i)
        if not party.Defeated and party.Role~='garrison' and party.Mission~='occupy' and fog:Visible(party.Travel.Q,party.Travel.R) then
            Discovery.Mark(factions,party.FactionId)
        end
    end
    for i=0,factions.data.SiteCount-1 do
        local state=factions.data:GetSiteAt(i);local site=assert(factions.sites[state.SiteId])
        if fog:Visible(site.q,site.r) then
            Discovery.Mark(factions,state.FactionId)
            if state.OccupierId>0 then Discovery.Mark(factions,state.OccupierId) end
        end
    end
end
function Discovery.Area(factions,layout,state)
    if factions.seenArea==state and factions.seenAreaRevision==state.Revision then return end
    factions.seenArea,factions.seenAreaRevision=state,state.Revision
    local all=state.VisibleCount==#layout.cells;local visible={}
    if not all then for i=0,state.VisibleCount-1 do visible[state:GetVisibleAt(i)]=true end end
    local adventure=factions.adventure
    for i=0,state.NpcCount-1 do
        local npc=state:GetNpcAt(i);local definition=assert(layout.npcs[npc.Id])
        if npc.Present and definition.narrativeId and (all or visible[npc.CellIndex]) then
            Discovery.Mark(factions,adventure.narrative.rules.npcs:Get(definition.narrativeId).factionId)
        end
    end
    for i=0,state.EncounterCount-1 do
        local group=state:GetEncounterAt(i);local partyId=CS.ProjectY.Data.FactionPersistence.PartyId(group)
        if partyId>0 then
            for j=0,group.EnemyCount-1 do
                local actor=group:GetEnemyAt(j);local cell=assert(layout:Find(actor.Q,actor.R))
                if actor.HP>0 and (all or visible[cell.index]) then
                    Discovery.Mark(factions,assert(adventure.parties.data:Find(partyId)).FactionId);break
                end
            end
        end
    end
end
return Discovery
