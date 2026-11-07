-- Fixed event identities use the existing persisted travel-stop range, never the generated base-site range.
local Random=require('Game.Map.SeededRandom')
local Sites={}
local function rows(events)
    local result,byEvent,byId={},{},{}
    for _,row in ipairs(events.adventure.config:GetTable('SpecialEventTable'):All()) do
        assert(not byEvent[row.eventId] and not byId[row.id],'Duplicate special-event placement identity')
        result[#result+1]=row;byEvent[row.eventId]=row;byId[row.id]=row
    end
    table.sort(result,function(a,b)return a.id<b.id end)
    return result,byEvent,byId
end
local function value(data,key)return data and data:GetValue(key) or 0 end
local function terminal(data,row)
    return value(data,'recruited:'..row.npcId)~=0 or value(data,'flag:'..row.key..'_outcome')~=0
end
local function key(q,r)return q..':'..r end
local function existing(sites,definitions)
    local found,occupied={},{}
    for i,site in ipairs(sites) do
        assert(site.id==i,'Special-event sites require contiguous world identities')
        occupied[key(site.q,site.r)]=true
        if definitions[site.eventId] then
            assert(not found[site.eventId],'A special event has multiple world locations')
            found[site.eventId]=site
        end
    end
    return found,occupied
end
local function recorded(data,row,sites,found)
    local id=value(data,'flag:'..row.key..'_site')
    if id~=0 then
        assert(sites[id] and sites[id].eventId==row.eventId and found[row.eventId]==sites[id],
            'Saved special-event site does not match its event')
    end
    return found[row.eventId],id
end
local function reachable(events,world)
    local anchor=assert(world.sites[1],'Special events require an expedition camp')
    local start=world.map:GetCell(anchor.q,anchor.r)
    assert(not start.waterLevel and not start.worldTravelBlocked,'Special-event camp must be traversable land')
    -- Cost reads the supplied map through this adapter; the live travel map, route and RNG stay untouched.
    local travel=setmetatable({map=world.map},{__index=events.adventure.travel})
    local queue,seen,head={start},{[key(start.q,start.r)]=true},1
    while head<=#queue do
        local cell=queue[head];head=head+1
        for _,other in ipairs(world.map:GetNeighbors(cell.q,cell.r)) do
            local location=key(other.q,other.r)
            if not seen[location] and not other.waterLevel and not other.worldTravelBlocked and travel:Cost(cell,other)~=nil then
                seen[location]=true;queue[#queue+1]=other
            end
        end
    end
    table.sort(queue,function(a,b)if a.q~=b.q then return a.q<b.q end;return a.r<b.r end)
    return queue,seen
end
local function selectCell(candidates,occupied,seed,row)
    local pools={{},{},{},{}}
    for _,cell in ipairs(candidates) do
        local free=not occupied[key(cell.q,cell.r)]
        if free and not cell.buildingId then pools[1][#pools[1]+1]=cell end
        if free then pools[2][#pools[2]+1]=cell end
        if not cell.buildingId then pools[3][#pools[3]+1]=cell end
        pools[4][#pools[4]+1]=cell
    end
    local random=Random((seed ~ (row.id*0x9e3779b9) ~ 0x53504543) & 0xffffffff)
    for _,pool in ipairs(pools) do if #pool>0 then return pool[random:Integer(1,#pool)] end end
    error('Special events have no reachable land cell')
end
function Sites.Plan(events,world,narrativeData)
    local definitions,byEvent=rows(events)
    local found,occupied=existing(world.sites,byEvent)
    local plans,candidates={}
    for _,row in ipairs(definitions) do
        local site=recorded(narrativeData,row,world.sites,found)
        if site then plans[#plans+1]={row=row,site=site}
        elseif not terminal(narrativeData,row) then
            if not candidates then candidates=reachable(events,world) end
            local cell=selectCell(candidates,occupied,world.seed,row)
            plans[#plans+1]={row=row,q=cell.q,r=cell.r};occupied[key(cell.q,cell.r)]=true
        end
    end
    return plans
end
function Sites.Apply(events,plans)
    local adventure=events.adventure
    local _,byEvent,byId=rows(events)
    local found=existing(adventure.sites,byEvent)
    local data=adventure.data.Narrative
    local pending,seen,reachableCells={},{}
    local added=0
    for _,plan in ipairs(plans) do
        local row=plan.row
        assert(byId[row.id]==row and not seen[row.id],'Stale or duplicate special-event placement plan');seen[row.id]=true
        local site,id=recorded(data,row,adventure.sites,found)
        if plan.site then
            assert(site==plan.site,'Existing special-event location changed before placement')
        elseif site then
            assert(site.q==plan.q and site.r==plan.r,'Special event was placed at another location')
        elseif not terminal(data,row) then
            if not reachableCells then
                local _;_,reachableCells=reachable(events,{map=adventure.map,sites=adventure.sites})
            end
            local cell=adventure.map:GetCell(plan.q,plan.r)
            assert(not cell.waterLevel and not cell.worldTravelBlocked and reachableCells[key(plan.q,plan.r)],
                'Planned special event is not reachable land')
            added=added+1
        end
        if site or not terminal(data,row) then pending[#pending+1]={row=row,site=site,id=id,q=plan.q,r=plan.r} end
    end
    local travel=adventure.travel.data
    assert(travel.StopCount+added<=10000,'Special-event placement exceeds the saved travel-stop limit')
    if travel.StopCount>0 then assert(travel:GetStopAt(travel.StopCount-1).Id==#adventure.sites,'Travel stops and world-site slots differ') end
    -- Complete preflight before adding any stop or claiming any existing identity.
    for _,plan in ipairs(pending) do
        local site=plan.site or adventure.travel:CreateEventStop(plan.q,plan.r,plan.row.eventId)
        if plan.id~=site.id then events:Set(plan.row,'site',site.id) end
    end
    return added
end
return Sites
