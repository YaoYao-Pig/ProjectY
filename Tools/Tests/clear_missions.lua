-- Real configuration, acceptance, placement, travel costs and paths; only C# Data/actor creation are fixtures.
package.path='Lua/?.lua;'..package.path
CS={ProjectY={Data={PartyRoster={Count=function(data)return data.PartyCount end}}}}
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local Hex=require('Game.Map.HexGrid')
local Random=require('Game.Map.SeededRandom')
local Clear=require('Game.Adventure.ClearMissions')
local Missions=require('Game.Narrative.TownMissions')
local Parties=require('Game.Adventure.WorldParties')
local Travel=require('Game.Adventure.WorldTravel')
local Language=require('Language')
local passed=0
local function test(name,fn)fn();passed=passed+1;print('PASS '..name)end
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function fixture(required)
    local map=require('Game.Map.Map')(71,1);map.regions[1]={regionType=1}
    for q=7,33 do for r=-13,13 do if Hex.Distance(20,0,q,r)<=13 then
        local cell={q=q,r=r,height=0,regionId=1,roadIds={}}
        map.cells[#map.cells+1]=cell;map.cellsByKey[Hex.Key(q,r)]=cell
    end end end
    local town={id=2,q=20,r=0};local sites={{id=1,q=-20,r=0},town}
    map:GetCell(20,0).townId=1
    local npc={id=1,stableId=99};local layout={areaType=2,npcs={npc},FindPath=function()return {2}end}
    local area={InteractionKind=2,InteractionId=1,CellIndex=1,GetNpcAt=function()return {Present=true,CellIndex=2}end}
    local adventure={config=config,map=map,sites=sites,data={Seed=71,Phase='area',Areas={ActiveSiteId=2,Active=area}},
        areas={townType=2,ActiveLayout=function()return layout end},battle={encounters=config:GetTable('CombatEncounterTable')}}
    local travel=setmetatable({adventure=adventure,map=map,data={Q=20,R=0,AnchorQ=20,AnchorR=0},
        rule=config:GetTable('WorldTravelTable'):Get(1),terrains={}},Travel)
    travel.maxStep=travel.rule.maxHeightStep
    for _,row in ipairs(config:GetTable('WorldTravelTerrainTable'):All()) do travel.terrains[row.regionType]=row end
    travel.paths=require('Game.Map.MapPathfinder')(map);adventure.travel=travel
    local states={Count=0,rows={}}
    function states:GetAt(i)return assert(self.rows[i+1])end
    function states:Add(definition,q,r,home,seed)
        assert(self.Count<4096);self.Count=self.Count+1
        local random=Random(seed)
        local t={Q=q,R=r,AnchorQ=q,AnchorR=r,Progress=0}
        function t:Roll(maximum)return random:Integer(1,maximum)end
        function t:Plan(qs,rs,costs)self.steps=qs;self.Active=#qs>0 end
        local party={Id=self.Count,DefinitionId=definition,HomeSiteId=home,Travel=t,MemberCount=0,LivingCount=0,Defeated=false,BattleSiteId=0}
        function party:ConfigureFaction(f,hq,hr,role)self.FactionId=f;self.HomeQ=hq;self.HomeR=hr;self.Role=role end
        self.rows[#self.rows+1]=party;return party
    end
    local policies=require('Game.Adventure.FactionRules').New(config)
    local factions={rules=policies,ServiceAllowed=function()return true end}
    function factions:Relation(a,b)return self.rules:Relation(a,b,nil,0)end
    function factions:PrepareRoster(party,encounter,count)
        party.MemberCount=math.min(count,#adventure.battle.encounters:Get(encounter).enemyIds);party.LivingCount=party.MemberCount
    end
    function factions:CanRoam(party,cell)return Hex.Distance(party.HomeQ,party.HomeR,cell.q,cell.r)<=self.rules.settings.roamRadius end
    function factions:InvalidatePower()self.invalidated=true end
    adventure.factions=factions
    local parties=setmetatable({adventure=adventure,map=map,sites=sites,paths=travel.paths,data=states,
        definitions=config:GetTable('WorldPartyTable'),rule=config:GetTable('WorldPartyRuleTable'):Get(1),
        lod={Calibrate=function(_,party)party.StrengthReady=true end}},Parties)
    parties.legends=require('Game.Adventure.LegendaryEncounters').New(parties)
    adventure.parties=parties
    local record={Id=17,DefinitionId=required and required<=5 and 5 or 6,SiteId=2,NpcId=99,PartyId=0,
        TargetId=0,State='offered',RequiredCount=required or 9,Progress=0}
    local data={Count=1,Revision=0}
    function data:GetAt(i)eq(i,0);return record end
    function data:Find(id)if id==record.Id then return record end end
    function data:GetDay()return 0 end
    function data:Accept(id)eq(id,record.Id);eq(record.State,'offered');record.State='active';self.Revision=self.Revision+1 end
    function data:AddProgress(id,count)record.Progress=record.Progress+count;self.Revision=self.Revision+1 end
    function data:Ready()record.State='ready';self.Revision=self.Revision+1 end
    CS={ProjectY={Data={TownMissionData={For=function()return data end}}}}
    local story={adventure=adventure,data={Minutes=0},rules={config=config,actions=config:GetTable('NarrativeActionTable')},ItemCount=function()return 0 end}
    adventure.narrative=story;local missions=Missions.New(story);story.townMissions=missions
    return missions,record,adventure,states
end

test('accept immediately adds exactly the configured kill count in reachable objective cells',function()
    for _,count in ipairs({3,5,6,9}) do
        local missions,record,a,states=fixture(count);local radius=missions.definitions:Get(record.DefinitionId).radius
        assert(missions:Accept(record.Id));eq(record.State,'active');eq(record.Progress,0)
        local total=0
        for _,party in ipairs(states.rows) do
            total=total+party.LivingCount;assert(party.StrengthReady)
            assert(not a.parties.legends:Find(party.DefinitionId));eq(a.factions:Relation(0,party.FactionId),'hostile')
            local t=party.Travel;assert(Hex.Distance(20,0,t.Q,t.R)<=radius);assert(Hex.Distance(20,0,t.Q,t.R)>1)
            assert(a.parties:Path(a.map:GetCell(20,0),a.map:GetCell(t.Q,t.R)))
            for _,other in ipairs(states.rows) do if other~=party then assert(Hex.Distance(t.Q,t.R,other.Travel.Q,other.Travel.R)>=2)end end
        end
        eq(total,count);assert(a.factions.invalidated)
    end
end)

test('refresh, repeat accept and reconstructed mission runtime do not spawn again',function()
    local missions,record,a,states=fixture();assert(missions:Accept(record.Id));local count=states.Count
    missions:Refresh();assert(not missions:Accept(record.Id));eq(states.Count,count)
    local restored=Missions.New(missions.story);restored:Refresh();assert(not restored:Accept(record.Id));eq(states.Count,count)
    for _=1,record.RequiredCount do restored:RecordKill()end
    eq(record.State,'ready');restored:Refresh();eq(states.Count,count)
end)

test('placement excludes water, buildings, towns, blocked terrain, occupied cells and isolated land',function()
    local missions,record,a,states=fixture();local map=a.map
    map:GetCell(21,0).waterLevel=0;map:GetCell(19,0).height=100;map:GetCell(20,1).worldTravelBlocked=true
    map:GetCell(20,-3).buildingId=77;map:GetCell(23,-3).townId=2
    for direction=1,6 do local q,r=Hex.Neighbor(25,0,direction);map:GetCell(q,r).waterLevel=0 end
    local existing=states:Add(3,17,0,0,1);existing.Travel.AnchorQ=18
    -- A map-wide scan during acceptance would regress large-world performance.
    function map:GetCells()error('Placement must be bounded to the mission radius')end
    local plan=assert(Clear.Prepare(missions.story,record,12));eq(states.Count,1)
    for _,entry in ipairs(plan) do local c=entry.cell
        assert(not c.waterLevel and not c.buildingId and not c.townId and not c.worldTravelBlocked and c.height==0)
        assert(c.q~=25 or c.r~=0);assert(Hex.Distance(17,0,c.q,c.r)>=2);assert(Hex.Distance(18,0,c.q,c.r)>=2)
    end
end)

test('seeded placement is reproducible and filters current diplomacy and legendary identities',function()
    local function signature()
        local missions,record,a=fixture();local inherited=a.factions.Relation
        function a.factions:Relation(first,second)if second==4 then return 'allied' end;return inherited(self,first,second)end
        local plan=assert(Clear.Prepare(missions.story,record,12));local rows={}
        for _,entry in ipairs(plan) do eq(entry.definition.id,3);rows[#rows+1]=entry.cell.q..':'..entry.cell.r..':'..entry.count..':'..entry.seed end
        return table.concat(rows,';')
    end
    eq(signature(),signature())
end)

test('failed preflight leaves the offer and world unchanged, including partial batch capacity',function()
    local missions,record,a,states=fixture()
    for direction=1,6 do local q,r=Hex.Neighbor(20,0,direction);a.map:GetCell(q,r).waterLevel=0 end
    local ok,reason=missions:Accept(record.Id);assert(not ok);eq(reason,Language.TownClearNoSpawnSpace);eq(record.State,'offered');eq(states.Count,0)
    missions,record,a,states=fixture();states.Count=4095
    local dummy={Defeated=true};function states:GetAt()return dummy end
    ok,reason=missions:Accept(record.Id);assert(not ok);eq(reason,Language.TownClearPartyLimit);eq(record.State,'offered');eq(#states.rows,0)
end)

test('no new enemies before valid acceptance or for delivery objectives',function()
    local missions,record,a,states=fixture();missions:Refresh();eq(states.Count,0)
    a.data.Areas.Active.InteractionKind=0;assert(not missions:Accept(record.Id));eq(states.Count,0);eq(record.State,'offered')
    a.data.Areas.Active.InteractionKind=2;record.DefinitionId=1;record.TargetId=81
    assert(missions:Accept(record.Id));eq(states.Count,0)
end)

local localization=config:GetTable('LuaTxt')
for _,key in ipairs({'TownClearPartyLimit','TownClearNoSpawnSpace'}) do assert(localization:Get(key).txt==Language[key])end
config:OnShutdown()
print('PASS '..passed..' clear mission checks')
