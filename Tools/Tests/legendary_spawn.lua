package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)local f=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local b=f:read('*a');f:close();return b end}})
local Hex=require('Game.Map.HexGrid');local EmptyGrowth=assert(loadfile('Tools/Tests/growth_empty.lua'))()
local stats=require('Game.Battle.CombatStats')(config)
-- Birth/body persistence has its own C# boundary tests; this fixture covers roster, species and traits.
stats.birth={Initialize=function()end}
stats.injuries={ApplyAttribute=function(_,actor,name,value)return value end}
local function fixture()
    local map={cells={},byKey={}}
    for q=10,36 do for r=-8,8 do local cell={q=q,r=r,regionId=({1,2,5})[q%3+1]};map.cells[#map.cells+1]=cell;map.byKey[Hex.Key(q,r)]=cell end end
    function map:GetCells()return self.cells end
    function map:GetRegion(id)return {regionType=id}end
    function map:FindCell(q,r)return self.byKey[Hex.Key(q,r)]end
    function map:GetCell(q,r)return assert(self:FindCell(q,r))end
    local data={Count=0,rows={}}
    function data:GetAt(i)return self.rows[i+1]end
    function data:Add(definition,q,r,home,seed)
        local p={Id=#self.rows+1,DefinitionId=definition,Travel={Q=q,R=r},members={},MemberCount=0,HomeSiteId=home}
        function p:ConfigureFaction(faction,hq,hr,role)self.FactionId=faction;self.HomeQ=hq;self.HomeR=hr;self.Role=role end
        function p:GetMemberAt(i)return self.members[i+1]end
        function p:AddMember(template)
            local actor={Id=self.Id*100+1,TemplateId=template,TraitCount=0,traits={},Growth=EmptyGrowth(),Effects={Count=0},AnimalSpeciesId=0,AnimalOwnerId=0,TameRetryTurns=0,Team=2}
            function actor:InitializeAnimal(species,seed)
                assert(self.AnimalSpeciesId==0,'Animal RNG must only initialize once')
                self.AnimalSpeciesId=species;self.animalSeed=seed
            end
            function actor:AddTrait(id)for _,old in ipairs(self.traits)do if old==id then return end end;self.traits[#self.traits+1]=id;self.TraitCount=#self.traits end
            function actor:GetTraitAt(i)return self.traits[i+1]end
            function actor:SetMaxHP(hp)self.MaxHP=hp end
            function actor:Restore()self.HP=self.MaxHP end
            function actor:Damage(amount)self.HP=math.max(0,self.HP-amount)end
            function actor:AdvanceTamingRound()assert(self.TameRetryTurns>0);self.TameRetryTurns=self.TameRetryTurns-1;return true end
            self.members[#self.members+1]=actor;self.MemberCount=#self.members;return actor
        end
        self.rows[#self.rows+1]=p;self.Count=#self.rows;return p
    end
    local adventure={config=config,data={Seed=721},battle={stats=stats,encounters=config:GetTable('CombatEncounterTable')},
        characterAppearances={Group=function()return 1 end,Assign=function(_,actor)actor.appearance=true end},travel={Cost=function()return 1 end}}
    local equipment=require('Game.Equipment.EquipmentSystem')();equipment.rules=stats.equipment;equipment.initialLoadouts={ApplyEnemy=function()end};adventure.equipment=equipment
    adventure.factions=setmetatable({adventure=adventure,data={SiteCount=0},rules=require('Game.Adventure.FactionRules').New(config)},require('Game.Adventure.WorldFactions'))
    local parties=setmetatable({adventure=adventure,map=map,sites={{q=0,r=0}},data=data,definitions=config:GetTable('WorldPartyTable'),rule=config:GetTable('WorldPartyRuleTable'):Get(1),Roam=function()end},require('Game.Adventure.WorldParties'))
    parties.legends=require('Game.Adventure.LegendaryEncounters').New(parties);adventure.parties=parties
    return parties
end
local p=fixture();p:Spawn(true);assert(p.data.Count==6,'An existing world must receive all six missing legendary identities when habitats exist')
local positions={}
for _,party in ipairs(p.data.rows)do
    assert(p.adventure.factions.rules:Suitable(party.FactionId,p.map:GetCell(party.Travel.Q,party.Travel.R).regionId))
    assert(Hex.Distance(0,0,party.Travel.Q,party.Travel.R)>=p.rule.spawnSafeRadius and party.MemberCount==1)
    local actor=party:GetMemberAt(0);assert(actor.TraitCount==1 and actor.HP==actor.MaxHP and actor.HP>0,'Real roster initialization must grant innate traits before maximum HP')
    assert((actor.TemplateId>=705)==(actor.appearance==true),'Only human legends use randomized humanoid appearance')
    local species=stats.animals.byUnit[actor.TemplateId]
    assert((actor.TemplateId<=704)==(species~=nil),'Only four configured animal legends receive species')
    assert(actor.AnimalSpeciesId==(species and species.id or 0) and actor.Team==2,'Species initialization must retain faction-controlled team')
    positions[party.DefinitionId]=Hex.Key(party.Travel.Q,party.Travel.R)
end
local dead=p.data.rows[1];dead.Defeated=true;dead:GetMemberAt(0).HP=0
p.data.rows[2]:GetMemberAt(0).HP=7
p:Spawn(true);assert(p.data.Count==6 and dead:GetMemberAt(0).HP==0 and p.data.rows[2]:GetMemberAt(0).HP==7,'Reload cannot duplicate, revive or heal existing legends')
local missing=table.remove(p.data.rows);p.data.Count=#p.data.rows;p:Spawn(true)
assert(p.data.Count==6 and p.data.rows[6].DefinitionId==missing.DefinitionId and p.data.rows[2]:GetMemberAt(0).HP==7)
local same=fixture();same:Spawn(true)
for _,party in ipairs(same.data.rows)do assert(positions[party.DefinitionId]==Hex.Key(party.Travel.Q,party.Travel.R),'Same seed must reproduce legendary placement')end
print('PASS real missing-legend spawn and roster paths: habitats, camp distance, innate traits, humanoid/static bodies, deterministic placement and no duplicate/heal/revive on reload')

-- A world saved after the previous faction migration already has faction IDs and existing actors.
local migrated=fixture();migrated:Spawn(true);migrated.data.Initialized=true
local original={}
for i,party in ipairs(migrated.data.rows) do
    party.BattleSiteId=0;local actor=party:GetMemberAt(0);original[i]=actor
    if i<=4 then actor.AnimalSpeciesId=0;actor.animalSeed=nil end
end
original[1].HP=0;migrated.data.rows[1].Defeated=true;original[2].HP=7
function migrated.data:CompleteFactionMigration()self.migrationCompleted=true end
migrated.adventure.factions.Initialize=function()end
migrated.lod={Initialize=function()end}
migrated:Initialize();migrated:Initialize()
assert(migrated.data.Count==6 and migrated.data.migrationCompleted)
for i,party in ipairs(migrated.data.rows) do
    local actor=party:GetMemberAt(0);assert(actor==original[i] and actor.TraitCount==1 and actor.Team==2)
    assert(actor.AnimalSpeciesId==(stats.animals.byUnit[actor.TemplateId] and stats.animals.byUnit[actor.TemplateId].id or 0))
end
assert(original[1].HP==0 and original[2].HP==7,'Legacy species migration must not heal or resurrect existing actors')
print('PASS initialized-world species migration retains object identity, HP, traits, faction team and death across repeated loads')

-- Retry clocks use whole world-minute boundaries only while the player is travelling.
local actors={}
for _,party in ipairs(migrated.data.rows) do local actor=party:GetMemberAt(0);actor.HP=actor.MaxHP;party.Defeated=false;actor.TameRetryTurns=3;actors[#actors+1]=actor end
actors[1].HP=0;actors[2].AnimalOwnerId=99;migrated.data.rows[3].BattleSiteId=45
migrated:AdvanceAnimalRetries(1000000,true)
assert(actors[1].TameRetryTurns==3 and actors[2].TameRetryTurns==3 and actors[3].TameRetryTurns==3)
assert(actors[4].TameRetryTurns==0 and actors[5].TameRetryTurns==3,'Only living unowned animals outside battle advance, bounded by remaining retries')
actors[4].TameRetryTurns=3;migrated.data.Clock=0;migrated.data.Remainder=0
function migrated.data:ElapsedTicks(now)
    local elapsed=self.Remainder+now-self.Clock;local ticks=math.floor(elapsed+1e-8)
    self.Remainder=elapsed-ticks;self.Clock=now;return ticks
end
local advances={};migrated.lod.Advance=function(_,minute)advances[#advances+1]=minute end
local narrative={data={Minutes=.4}};migrated.adventure.narrative=narrative
migrated:SyncClock(true);assert(actors[4].TameRetryTurns==3)
narrative.data.Minutes=1;migrated:SyncClock(true);assert(actors[4].TameRetryTurns==2 and advances[1]==1)
narrative.data.Minutes=2;migrated:SyncClock(false);assert(actors[4].TameRetryTurns==2 and advances[2]==2)
migrated:SyncClock(true);assert(actors[4].TameRetryTurns==2,'Unchanged time must not advance retries')
narrative.townMissions={escort={HasActive=function()return true end,Refresh=function()end}}
narrative.data.Minutes=4;migrated:SyncClock(true)
assert(actors[4].TameRetryTurns==0 and advances[3]==3 and advances[4]==4,'Escort boundaries keep the same per-minute LOD order')
print('PASS world taming retries: partial-minute carry, movement only, unchanged time, bounded catch-up and escort boundary order')

local Factions=require('Game.Adventure.WorldFactions')
local owned={HP=0,MaxHP=10,AnimalOwnerId=9}
local guard={Id=1,MemberCount=1,Role='wildlife',CargoCount=0,BattleSiteId=0,SafeUntil=0,GetMemberAt=function()return owned end,
    SetDefeated=function()error('Faction recovery must never revive an owned animal')end}
local site={SiteId=1,GuardPartyId=1,FactionId=1,OccupierId=0,LastRecoveryAt=0,LiberatedAt=-1,Reserve=10,
    AddReserve=function(self,value)self.Reserve=self.Reserve+value end,SetRecoveryAt=function(self,value)self.LastRecoveryAt=value end}
local faction=setmetatable({adventure={battle={stats={}},parties={data={Count=0,Find=function()return guard end}}},
    sites={{q=0,r=0}},data={SiteCount=1,GetSiteAt=function()return site end},rules={
        settings={thinkMinutes=1,retreatMinutes=1,reserveCapacity=100},policies={Get=function()return {income=1,recruitCost=1}end},
        Power=function()error('Owned animal must not contribute to the old faction')end}},Factions)
faction:Recover(1);assert(owned.HP==0 and site.LastRecoveryAt==1)
owned.HP=10;assert(faction:Power(guard)==0)
print('PASS former faction cannot count, heal or revive an owned animal')
config:OnShutdown()
