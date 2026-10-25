package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local f=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local bytes=f:read('*a');f:close();return bytes
end}})
local Factions=require('Game.Adventure.WorldFactions')
local facts,writes={},0
local visible={[0]=true}
local rows={
    {FactionId=1,Role='caravan',Mission='trade',Travel={Q=0,R=0}},
    {FactionId=4,Role='raider',Mission='patrol',Travel={Q=1,R=0}},
    {FactionId=5,Role='raider',Mission='patrol',Travel={Q=0,R=0},Defeated=true},
    {FactionId=6,Role='garrison',Mission='guard',Travel={Q=0,R=0}},
    {FactionId=7,Role='raider',Mission='occupy',Travel={Q=0,R=0}},
}
local parties={Count=#rows,Revision=1,Clock=0,GetAt=function(_,i)return rows[i+1]end,Find=function(_,id)return rows[id]end}
local site={SiteId=1,FactionId=6,OccupierId=7}
local adventure={data={Phase='map'},config=config,parties={data=parties},
    fog={data={Revision=1},Visible=function(_,q)return visible[q]==true end,Known=function()return true end},
    narrative={data={GetValue=function(_,key)return facts[key] or 0 end,SetValue=function(_,key,value)facts[key]=value;writes=writes+1 end}}}
local factions=setmetatable({adventure=adventure,rules=require('Game.Adventure.FactionRules').New(config),
    sites={{q=3,r=0}},data={SiteCount=1,GetSiteAt=function()return site end}},Factions)
adventure.factions=factions
factions:ObserveWorld()
assert(factions:IsDiscovered(1) and not factions:IsDiscovered(4) and not factions:IsDiscovered(5) and not factions:IsDiscovered(6) and not factions:IsDiscovered(7))
assert(factions:IsDiscovered(0) and writes==1)
factions:ObserveWorld();assert(writes==1,'Unchanged/paused world must not keep writing facts')
visible={[1]=true};adventure.fog.data.Revision=2;factions:ObserveWorld()
assert(factions:IsDiscovered(4) and factions:IsDiscovered(1),'Leaving sight must retain discoveries')
rows[#rows+1]={FactionId=3,Role='caravan',Mission='trade',Travel={Q=9,R=0}};parties.Count=#rows;parties.Revision=2;factions:ObserveWorld()
assert(not factions:IsDiscovered(3));rows[#rows].Travel.Q=1;parties.Clock=1;factions:ObserveWorld();assert(factions:IsDiscovered(3),'Moving factions must be observed while player stands still')
visible[3]=true;adventure.fog.data.Revision=3;factions:ObserveWorld();assert(factions:IsDiscovered(6) and factions:IsDiscovered(7),'Visible sites reveal owner and occupier')
rows[#rows+1]={FactionId=9,Role='wildlife',Mission='patrol',Travel={Q=1,R=0}};parties.Count=#rows;parties.Revision=3
adventure.data.Phase='area';factions:ObserveWorld();assert(not factions:IsDiscovered(9),'Do not see the world while in a local area')
print('PASS first visible contact, remembered fog exclusion, hidden/dead/garrison/occupation exclusion, retained discoveries, moving parties and site owners')

local previousCS=CS
CS={ProjectY={Data={FactionPersistence={PartyId=function(group)return group.partyId end}}}}
local layout={cells={},npcs={{narrativeId=101},{narrativeId=102}},Find=function(_,q)return {index=q}end}
for i=1,12 do layout.cells[i]={index=i} end
adventure.narrative.rules={npcs={Get=function(_,id)return {factionId=id==101 and 2 or 8}end}}
local npcs={{Id=1,Present=true,CellIndex=10},{Id=2,Present=false,CellIndex=10}}
local group={partyId=#rows,EnemyCount=1,GetEnemyAt=function()return {HP=10,Q=11,R=0}end}
local state={Revision=1,NpcCount=2,VisibleCount=1,EncounterCount=1,GetNpcAt=function(_,i)return npcs[i+1]end,
    GetVisibleAt=function()return 10 end,GetEncounterAt=function()return group end}
factions:ObserveArea(layout,state)
assert(factions:IsDiscovered(2) and not factions:IsDiscovered(8) and not factions:IsDiscovered(9))
state.Revision=2;state.VisibleCount=12;factions:ObserveArea(layout,state)
assert(factions:IsDiscovered(9) and not factions:IsDiscovered(8),'Only present NPCs and visible attached armies reveal identities')
local before=writes;factions:ObserveArea(layout,state);assert(writes==before)
CS=previousCS
print('PASS local NPC presence, local vision, attached army identity, fully visible areas and idempotent observations')

-- Exercise the actual multi-minute travel loop: a faction is visible only at the intermediate step.
facts={};visible={};adventure.data.Phase='map';parties.Count=1;rows[1].FactionId=4;rows[1].Travel.Q=1
local travelState={Paused=false,Active=true,Progress=0,Q=0,R=0,Speed=1,
    Step=function(self)self.Q=self.Q+1;return 1 end,CheckDue=function()return false end}
adventure.travel={data=travelState};adventure.context={services={UI={IsWorldPaused=false}}};adventure.camp={data={IsOpen=false}}
adventure.fog.Update=function(self)self.data.Revision=self.data.Revision+1;visible={[travelState.Q]=true}end
adventure.narrative.AdvanceMinutes=function(_,spent)parties.Clock=parties.Clock+spent end
adventure.parties.SyncClock=function()end;adventure.parties.CheckContact=function()return false end;adventure.parties.ReplanPursuit=function()end
local travel=setmetatable({adventure=adventure,data=travelState,rule={minutesPerSecond=1,checkMinutes=1}},require('Game.Adventure.WorldTravel'))
travel:Tick(2)
assert(travelState.Q==2 and not adventure.fog:Visible(1,0) and factions:IsDiscovered(4))
print('PASS travel records first sight at intermediate steps, without needing to open the relation UI')
for _,path in ipairs({'Lua/Game/Adventure/AdventureSystem.lua','Lua/Game/MapArea/MapAreaSystem.lua'}) do assert(loadfile(path)) end
