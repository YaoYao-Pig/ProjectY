package.path='Lua/?.lua;'..package.path
local Save=require('Game.Narrative.NarrativeSave')
local key,value='faction_seen:1',1
local prepared={ActorCount=0,Narrative={ProgressCount=0,ValueCount=1,
    GetValueKeyAt=function()return key end,GetValue=function()return value end}}
local story={rules={factions={Get=function(_,id)assert(id==1,'Unknown faction');return {id=id}end}}}
Save.Validate(story,prepared)
for _,case in ipairs({{'faction_seen:0',1},{'faction_seen:1.5',1},{'faction_seen:999',1},{'faction_seen:1',2},{'unknown_fact:1',1}})do
    key,value=case[1],case[2];assert(not pcall(Save.Validate,story,prepared),'Malformed fact accepted: '..key)
end
print('PASS discovered faction facts roundtrip while invalid IDs, states and unknown fact types remain rejected')
local facts={['escort_route:1']=8,['escort_checks:1']=2}
local mission={PartyId=9,State='active',DefinitionId=1}
CS={ProjectY={Data={TownMissionData={Prepared=function()return {Find=function(_,id)if id==1 then return mission end end}end}}}}
prepared.Narrative.GetValue=function(_,requested)return facts[requested] or 0 end
story.rules.config={GetTable=function(_,name)assert(name=='TownMissionTable');return {Get=function(_,id)assert(id==1);return {kind='escort'}end}end}
for _,valid in ipairs({'escort_route:1','escort_checks:1'}) do key=valid;Save.Validate(story,prepared) end
for _,case in ipairs({{'escort_route:0',8},{'escort_route:1.5',8},{'escort_route:2',8},{'escort_checks:1',4},{'escort_route:1',-1}}) do
    key=case[1];local prior=facts[key];facts[key]=case[2]
    assert(not pcall(Save.Validate,story,prepared),'Malformed escort fact accepted: '..key)
    facts[key]=prior
end
key='escort_checks:1';facts['escort_route:1']=nil
assert(not pcall(Save.Validate,story,prepared),'Orphan escort check count accepted')
facts['escort_route:1']=8;mission.State='offered'
assert(not pcall(Save.Validate,story,prepared),'Unaccepted escort check count accepted')
print('PASS escort checkpoint facts preserve progress and reject malformed or orphaned records')
