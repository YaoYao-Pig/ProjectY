-- Focused native fixture: a real generated world with one isolated caravan, then one hostile.
-- Requires the existing Edit Mode LuaEnv/FrameworkServices in world_parties_presentation.cs.
-- This integration fixture is not runnable in the standalone pure-Lua run_lua.py host.
local adventure=require('Main'):Get('Adventure');adventure:Start(20261016,3,10000)
local parties=adventure.parties;local source
local factions=adventure.factions
local function clearParties()
    -- Roster actor IDs are allocated by WorldPartiesData and reused after Clear.
    -- Remove only these isolated world actors' equipment before recreating them.
    for i=0,parties.data.Count-1 do local party=parties.data:GetAt(i)
        for j=0,party.MemberCount-1 do
            CS.ProjectY.Data.EquipmentCombatState.RemoveActor(adventure.equipment.data,party:GetMemberAt(j).Id)
        end
    end
    parties.data:Clear();factions:InvalidatePower();factions.data:Complete()
end
local function initializeParty(party,role)
    local row=parties.definitions:Get(party.DefinitionId)
    party:ConfigureFaction(row.factionId,party.Travel.Q,party.Travel.R,role)
    factions:PrepareRoster(party,row.encounterId)
end
for i=0,parties.data.Count-1 do local row=parties.data:GetAt(i);if row.DefinitionId==1 and row.Travel.StepCount>=5 then source=row;break end end
assert(source,'Need a caravan route at least five cells long')
local q,r,home,destination=source.Travel.Q,source.Travel.R,source.HomeSiteId,source.DestinationSiteId
local ahead=source.Travel:GetStepAt(3);local playerQ,playerR=ahead.Q,ahead.R
clearParties();local caravan=parties.data:Add(1,q,r,home,431);initializeParty(caravan,'caravan')
caravan:SetDestination(destination);parties:Restock(caravan)
local site=adventure.sites[destination];assert(parties:Plan(caravan,adventure.map:GetCell(site.q,site.r)));parties.data:Complete(adventure.narrative.data.Minutes)
adventure.travel.data:Reset(adventure.data.Seed,playerQ,playerR,#adventure.sites+1)
assert(parties:Pursue(caravan.Id) and not parties.data.IsOpen,'Contact must not open at a distance')
adventure.travel.data:SetPaused(true);local remaining=caravan.Travel.RemainingMinutes
adventure:Tick(1);assert(caravan.Travel.RemainingMinutes==remaining,'Paused pursuit moved the caravan')
adventure.travel.data:SetPaused(false)
for _=1,300 do adventure:Tick(.05);if parties.data.IsOpen then break end end
assert(parties.data.ContactId==caravan.Id and adventure.travel.data.Paused,'Following a moving caravan did not reach contact')
parties.data:Close();clearParties()
local enemy=parties.data:Add(2,q,r,0,431);initializeParty(enemy,'raider')
-- The current AI intentionally avoids stronger players. Make the original pursuit
-- scenario explicitly eligible, with real configured actors instead of a power stub.
local definition=parties.definitions:Get(enemy.DefinitionId)
local encounter=adventure.battle.encounters:Get(definition.encounterId)
local appearance=adventure.characterAppearances:Group(encounter.appearancePoolId,(adventure.data.Seed ~ enemy.Id*65537)&0xffffffff)
local required=factions:PlayerPower()*factions.rules.settings.raidAdvantage
while factions:Power(enemy)<required do
    assert(enemy.MemberCount<64,'Configured hostile roster cannot meet pursuit strength requirement')
    local actor=enemy:AddMember(encounter.enemyIds[enemy.MemberCount%#encounter.enemyIds+1])
    if not adventure.battle.stats.animals:IsStaticBody(actor) then adventure.characterAppearances:Assign(actor,appearance) end
    adventure.equipment:InitializeEnemy(actor);actor:SetMaxHP(adventure.battle.stats:MaximumHP(actor));actor:Restore()
    factions:InvalidatePower()
end
parties.data:Complete(adventure.narrative.data.Minutes)
adventure.travel.data:Reset(adventure.data.Seed,playerQ,playerR,#adventure.sites+1)
adventure.narrative:AdvanceMinutes(1);parties:SyncClock()
assert(enemy.Chasing and enemy.Travel.Active,'Hostile did not acquire a nearby player and plan pursuit')
return 'PASS moving-caravan pursuit reaches contact; paused pursuit freezes; nearby hostile acquires and follows player'
