-- Focused native fixture: a real generated world with one isolated caravan, then one hostile.
local adventure=require('Main'):Get('Adventure');adventure:Start(20261016,3,10000)
local parties=adventure.parties;local source
for i=0,parties.data.Count-1 do local row=parties.data:GetAt(i);if row.DefinitionId==1 and row.Travel.StepCount>=5 then source=row;break end end
assert(source,'Need a caravan route at least five cells long')
local q,r,home,destination=source.Travel.Q,source.Travel.R,source.HomeSiteId,source.DestinationSiteId
local ahead=source.Travel:GetStepAt(3);local playerQ,playerR=ahead.Q,ahead.R
parties.data:Clear();local caravan=parties.data:Add(1,q,r,home,431);caravan:SetDestination(destination);parties:Restock(caravan)
local site=adventure.sites[destination];assert(parties:Plan(caravan,adventure.map:GetCell(site.q,site.r)));parties.data:Complete(adventure.narrative.data.Minutes)
adventure.travel.data:Reset(adventure.data.Seed,playerQ,playerR,#adventure.sites+1)
assert(parties:Pursue(caravan.Id) and not parties.data.IsOpen,'Contact must not open at a distance')
adventure.travel.data:SetPaused(true);local remaining=caravan.Travel.RemainingMinutes
adventure:Tick(1);assert(caravan.Travel.RemainingMinutes==remaining,'Paused pursuit moved the caravan')
adventure.travel.data:SetPaused(false)
for _=1,300 do adventure:Tick(.05);if parties.data.IsOpen then break end end
assert(parties.data.ContactId==caravan.Id and adventure.travel.data.Paused,'Following a moving caravan did not reach contact')
parties.data:Close();parties.data:Clear()
local enemy=parties.data:Add(2,q,r,0,431);parties.data:Complete(adventure.narrative.data.Minutes)
adventure.travel.data:Reset(adventure.data.Seed,playerQ,playerR,#adventure.sites+1)
adventure.narrative:AdvanceMinutes(1);parties:SyncClock()
assert(enemy.Chasing and enemy.Travel.Active,'Hostile did not acquire a nearby player and plan pursuit')
return 'PASS moving-caravan pursuit reaches contact; paused pursuit freezes; nearby hostile acquires and follows player'
