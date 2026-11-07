local Hex=require('Game.Map.HexGrid')
local Random=require('Game.Map.SeededRandom')
local Language=require('Language')
local Clear={}

-- Build the whole batch before accepting; a failed placement must not leave a partial contract.
function Clear.Prepare(story,contract,radius)
    local adventure=story.adventure;local parties=adventure.parties;local factions=adventure.factions
    local town=assert(adventure.sites[contract.SiteId]);local map=adventure.map
    local available={}
    for _,row in ipairs(parties.definitions:All()) do
        if row.kind=='hostile' and row.count>0 and not parties.legends:Find(row.id) and factions:Relation(0,row.factionId)=='hostile' then
            available[#available+1]=row
        end
    end
    local blocked={}
    local function reserve(q,r)
        blocked[Hex.Key(q,r)]=true
        for direction=1,6 do local nq,nr=Hex.Neighbor(q,r,direction);blocked[Hex.Key(nq,nr)]=true end
    end
    for i=0,parties.data.Count-1 do local party=parties.data:GetAt(i)
        if not party.Defeated then
            reserve(party.Travel.Q,party.Travel.R);reserve(party.Travel.AnchorQ,party.Travel.AnchorR)
        end
    end
    local player=adventure.travel.data;reserve(player.AnchorQ,player.AnchorR)
    for _,site in ipairs(adventure.sites) do reserve(site.q,site.r) end
    -- Flood only the objective's hex disk, so placement never searches the entire world.
    local origin=map:GetCell(town.q,town.r);local queue={origin};local seen={[origin]=true};local candidates={};local head=1
    local camp=assert(adventure.sites[1])
    while head<=#queue do
        local cell=queue[head];head=head+1
        if not cell.waterLevel and not cell.buildingId and not cell.townId and not blocked[Hex.Key(cell.q,cell.r)] and
            Hex.Distance(camp.q,camp.r,cell.q,cell.r)>=parties.rule.spawnSafeRadius then
            local definitions={};local region=map:GetRegion(cell.regionId).regionType
            for _,row in ipairs(available) do
                if factions.rules:Suitable(row.factionId,region) then definitions[#definitions+1]=row end
            end
            if #definitions>0 then candidates[#candidates+1]={cell=cell,definitions=definitions} end
        end
        for direction=1,6 do local q,r=Hex.Neighbor(cell.q,cell.r,direction);local nextCell=map:FindCell(q,r)
            if nextCell and not seen[nextCell] and not nextCell.waterLevel and Hex.Distance(town.q,town.r,q,r)<=radius and
                adventure.travel:Cost(cell,nextCell) then
                seen[nextCell]=true;queue[#queue+1]=nextCell
            end
        end
    end
    local random=Random((adventure.data.Seed ~ (contract.Id*104729) ~ (contract.SiteId*7919)) & 0xffffffff)
    for i=#candidates,2,-1 do local j=random:Integer(1,i);candidates[i],candidates[j]=candidates[j],candidates[i] end
    local plan={};local remaining=contract.RequiredCount
    for _,candidate in ipairs(candidates) do local cell=candidate.cell
        if not blocked[Hex.Key(cell.q,cell.r)] then
            if parties.data.Count+#plan>=4096 then return nil,Language.TownClearPartyLimit end
            local definition=candidate.definitions[random:Integer(1,#candidate.definitions)]
            local count=math.min(remaining,#adventure.battle.encounters:Get(definition.encounterId).enemyIds)
            assert(count>0,'Clear mission requires a nonempty encounter')
            plan[#plan+1]={definition=definition,cell=cell,count=count,seed=random:Integer(0,0xffffffff)}
            reserve(cell.q,cell.r);remaining=remaining-count
            if remaining==0 then return plan end
        end
    end
    return nil,Language.TownClearNoSpawnSpace
end

function Clear.Start(story,contract,plan)
    assert(contract.State=='active','Clear mission must be accepted before spawning')
    local adventure=story.adventure;local parties=adventure.parties;local factions=adventure.factions
    for _,entry in ipairs(plan) do local row=entry.definition;local cell=entry.cell
        -- These additional roaming bands use their spawn location as home, without creating a faction outpost.
        local party=parties.data:Add(row.id,cell.q,cell.r,0,entry.seed)
        local role=factions.rules.policies:Get(row.factionId).role
        party:ConfigureFaction(row.factionId,cell.q,cell.r,role=='wildlife' and 'wildlife' or role=='raider' and 'raider' or 'patrol')
        factions:PrepareRoster(party,row.encounterId,entry.count)
        parties.lod:Calibrate(party);parties:Roam(party)
    end
    factions:InvalidatePower()
end
return Clear
