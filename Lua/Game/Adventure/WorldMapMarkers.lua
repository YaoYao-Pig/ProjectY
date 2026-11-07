local NpcMarkers=require('Game.Narrative.NpcMissionMarkers')
local Markers={}
local order={available=1,active=2,ready=3}

-- knownSites is Adventure:Snapshot().sites, after its exploration and site-lifetime filters.
-- Counts represent town contacts/contracts at a site, not individual Quest objectives.
function Markers.Build(adventure,knownSites)
    local result={};local story=adventure.narrative
    if not story then return result end
    local known,groups={},{}
    for _,site in ipairs(knownSites) do known[site.id]=true end
    local function add(siteId,kind)
        if not known[siteId] then return end
        local group=groups[siteId]
        if not group then group={};groups[siteId]=group end
        local row=group[kind]
        if row then row.count=row.count+1
        else
            row={siteId=siteId,kind=kind,count=1};group[kind]=row;result[#result+1]=row
        end
    end

    -- Use the existing dialogue marker rule, without mutating NpcSystem's marker cache
    -- or treating missionIds as a current objective's position.
    for _,npc in ipairs(story.rules.npcs:All()) do
        local siteId=story.npcs.locations[npc.id]
        if npc.locationKind=='town' and siteId and known[siteId]
            and story.data:GetValue('recruited:'..npc.id)==0
            and adventure.factions:ServiceAllowed(siteId)
            and (not npc.recruitable or adventure.factions:NpcAvailable(siteId,npc.id)) then
            local marker=NpcMarkers.Story(story,npc.id)
            if marker==1 then add(siteId,'available')
            elseif marker==2 then add(siteId,'ready') end
        end
    end

    local missions=story.townMissions;local day=math.floor(story.data.Minutes/1440)
    for i=0,missions.data.Count-1 do
        local mission=missions.data:GetAt(i);local state=mission.State
        if state=='offered' then
            -- Daily offers are generated on town entry; never refresh them for a map view.
            if known[mission.SiteId] and mission.Day==day and adventure.factions:ServiceAllowed(mission.SiteId) then
                add(mission.SiteId,'available')
            end
        elseif state=='active' or state=='ready' then
            if known[mission.SiteId] then
                local kind='active'
                if state=='ready' and adventure.factions:ServiceAllowed(mission.SiteId) and missions:CanClaim(mission) then kind='ready' end
                add(mission.SiteId,kind)
            end
            -- A finished escort returns to its publisher; its moving caravan is never projected.
            if state=='active' and missions.definitions:Get(mission.DefinitionId).kind=='escort'
                and mission.DestinationSiteId>0 and mission.DestinationSiteId~=mission.SiteId then
                add(mission.DestinationSiteId,'active')
            end
        end
    end
    table.sort(result,function(a,b)
        if a.siteId~=b.siteId then return a.siteId<b.siteId end
        return order[a.kind]<order[b.kind]
    end)
    return result
end
return Markers
