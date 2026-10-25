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
