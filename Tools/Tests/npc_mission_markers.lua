package.path='Lua/?.lua;'..package.path
local Markers=require('Game.Narrative.NpcMissionMarkers')
local function tableOf(rows)return {Get=function(_,id)return assert(rows[id])end}end
local status,locked='inactive',false
local story={adventure={player={Coins=0},data={PartyCount=0}},data={Status=function()return status end},
    conditions={Check=function(_,id)return id~=2 or not locked end}}
function story:CanAccept()return status=='inactive' end
story.rules={npcs=tableOf({[1]={dialogueIds={1}}}),dialogues=tableOf({[1]={conditionId=1,entryNodeId=1}}),
    nodes=tableOf({[1]={choiceIds={1,2}},[2]={choiceIds={3,4}}}),
    choices=tableOf({[1]={conditionId=2,actionIds={},nextNodeId=2},[2]={conditionId=1,actionIds={1},nextNodeId=0},
        [3]={conditionId=1,actionIds={2},nextNodeId=0},[4]={conditionId=1,actionIds={},nextNodeId=1}}),
    actions=tableOf({[1]={kind='accept_mission',targetId=100},[2]={kind='claim_mission',targetId=100},[3]={kind='add_coins',value=5}}),
    missions=tableOf({[100]={actionIds={3}}})}
assert(Markers.Story(story,1)==1,'Available dialogue mission must be gold')
status='active';assert(Markers.Story(story,1)==0,'Only an active mission must not show a marker')
status='ready';assert(Markers.Story(story,1)==2,'Reachable hand-in must be green, including dialogue loops')
locked=true;assert(Markers.Story(story,1)==0,'Locked branches must not advertise hand-in')
locked=false;story.adventure.player.Coins=2147483647
assert(Markers.Story(story,1)==0,'An unclaimable reward must not advertise green')
status='completed';assert(Markers.Story(story,1)==0,'Completed missions must not advertise a task')
print('PASS NPC markers: available, active, ready, locked, reward preflight, completed and cyclic dialogue')
