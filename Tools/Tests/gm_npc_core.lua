package.path='Lua/?.lua;'..package.path
local Commands=require('Game.GM.NpcCommands')
local actors={{Id=10,HP=20},{Id=20,HP=20}}
local data={PartyCount=2,Phase='map',Areas={ActiveSiteId=0}}
function data:GetPartyAt(index)return actors[index+1]end
local occupied,enemies={[1]=true},{}
local state={IsNpcOccupied=function(_,index)return occupied[index]==true end}
local area={cells={{index=1},{index=2},{index=3},{index=4}}}
local neighbors={{2,3},{1,4},{1,4},{2,3}}
function area:Neighbors(cell)local rows={};for _,index in ipairs(neighbors[cell.index])do rows[#rows+1]=self.cells[index]end;return rows end
local adventure={data=data,areas={}}
function adventure.areas:EnemyOccupancy()return enemies end
function adventure.areas:SquadFootprint(_,ids)
    assert(ids[1]==10 and ids[2]==20)
    return function(index,member)
        if member==1 then if index==2 then return {2,4} elseif index==3 then return {3} end
        elseif index==4 then return {4} end
    end
end
local story={data={DialogueOpen=false},rules={settings={recruitSearchRadius=2}}}
local gm=Commands.New(adventure,story)
assert(gm:CanTravel())
for _,phase in ipairs({'battle','event','result'})do data.Phase=phase;assert(not gm:CanTravel())end
data.Phase='map';story.data.DialogueOpen=true;assert(not gm:CanTravel());story.data.DialogueOpen=false
actors[1].HP=0;actors[2].HP=0;assert(not gm:CanTravel());actors[1].HP=20;actors[2].HP=20
local deployment=assert(gm:Deployment(area,state,1))
assert(deployment.cells[1]==3 and deployment.cells[2]==4,'Planner must backtrack when a large leader footprint blocks another member')
occupied[4]=true
local result,reason=gm:Deployment(area,state,1);assert(not result and reason:find('合法位置'))
occupied[4]=nil;enemies[4]=true;assert(not gm:Deployment(area,state,1))
assert(data.Phase=='map' and data.Areas.ActiveSiteId==0,'Planning must not mutate world location')
print('PASS GM NPC phase/dialogue/defeated gates, complete footprints, backtracking, occupied cells and enemy rejection')

local Language=require('Language')
local definitions={
    {id=1,name='Town speaker',locationKind='town'},
    {id=101,name='World legend',locationKind='world_party'},
    {id=301,name='Trial knight',locationKind='event'},
    {id=302,name='Deserter',locationKind='event'},
    {id=401,name='Animal dialogue',locationKind='animal'},
}
local byId={};for _,row in ipairs(definitions)do byId[row.id]=row end
story.rules.npcs={All=function()return definitions end,Find=function(_,id)return byId[id]end,Get=function(_,id)return assert(byId[id])end}
local facts={}
function story.data:GetValue(key)return facts[key] or 0 end
story.npcs={locations={[1]=2},Schedule=function(_,id)assert(id==1,'Only town NPCs have schedules');return {activity='fixture schedule'}end}
adventure.sites={[2]={id=2,name='Town',q=3,r=4},[3]={id=3,name='Trial',q=15,r=25},[4]={id=4,name='Roadside',q=21,r=18}}
local outcome,failed=0,false
adventure.specialEvents={byNpc={[301]={npcId=301},[302]={npcId=302}},
    SiteForNpc=function(_,id)return adventure.sites[id==301 and 3 or 4]end,
    Value=function()return outcome end,CanEnter=function()return not failed,failed and 'configured failure result' or nil end}
local calls={}
adventure.travel={data={Progress=0,Active=true}}
local travel=adventure.travel.data
function travel:Plan(qs,rs,minutes,target)
    assert(#qs==0 and #rs==0 and #minutes==0 and target==0 and self.Progress==0)
    self.Active=false;calls[#calls+1]='plan'
end
function travel:Relocate(q,r)assert(not self.Active);self.Q=q;self.R=r;calls[#calls+1]='relocate'end
function travel:SetPaused(value)assert(value);self.Paused=value;calls[#calls+1]='pause'end
adventure.fog={Update=function()assert(travel.Q and travel.Paused);calls[#calls+1]='fog'end}
function adventure.areas:Stop()calls[#calls+1]='stop';return true end
function adventure.areas:Leave()data.Phase='map';data.Areas.ActiveSiteId=0;calls[#calls+1]='leave';return true end
function adventure:EnterSite(id)
    assert(data.Phase=='map' and id==3 and travel.Q==15 and travel.R==25)
    data.Phase='event';data.EventId=301;calls[#calls+1]='enter';return true
end

local rows=gm:Search('')
assert(#rows==5 and rows[1].available and not rows[2].available and rows[3].available and rows[4].available and not rows[5].available)
assert(rows[3].body:find('(15, 25)',1,true) and rows[4].body:find('(21, 18)',1,true))
assert(rows[5].body==Language.GmNpcAnimalIdentity and #calls==0,'Searching must not create scenes, move the party or generate substitute NPCs')
assert(gm:Target(301).kind=='event' and gm:Target(1).kind=='town')
assert(not gm:Target(0) and not gm:Target(999))
outcome=1;assert(gm:Search('301')[1].body:find(Language.GmNpcEventRescued,1,true));outcome=2
assert(gm:Search('301')[1].body:find(Language.GmNpcEventEnded,1,true));outcome=0
local savedSite=adventure.sites[3];adventure.sites[3]=nil;outcome=2
local terminal=gm:Search('301')[1]
assert(not terminal.available and terminal.body==Language.GmNpcEventEnded and #calls==0,'Settled legacy events without a saved site must remain unavailable without respawning')
outcome=0
local missingPending,missingReason=pcall(function()gm:Target(301)end)
assert(not missingPending and tostring(missingReason):find('Pending event NPC has no generated site',1,true))
adventure.sites[3]=savedSite
failed=true;local target,why=gm:Target(301);assert(not target and why=='configured failure result' and not gm:Search('301')[1].available)
failed=false;facts['recruited:301']=20
target,why=gm:Target(301);assert(not target and why==string.format(Language.GmNpcRecruited,'Trial knight',2));facts['recruited:301']=nil
print('PASS GM distinguishes town, event, world-party and generic-animal identities without mutation or town lookups for events')

assert(gm:GoTo(301))
assert(table.concat(calls,',')=='plan,relocate,pause,fog,enter' and data.Phase=='event' and data.EventId==301)
assert(data.PartyCount==2,'Event travel must not choose outcomes, recruit, or grant rewards')
assert(not gm:GoTo(301),'Repeated clicks cannot interrupt the newly opened event')
data.Phase='map';calls={};travel.Progress=.25;travel.Active=true
local allowed,reason=gm:GoTo(301)
assert(not allowed and reason==Language.GmNpcFinishTravelStep and #calls==0 and not gm:Search('301')[1].available)
data.Phase='area';data.Areas.ActiveSiteId=3
assert(gm:GoTo(301) and #calls==0 and data.Areas.ActiveSiteId==3,'Already in the event scene must not leave or re-enter it')
data.Areas.ActiveSiteId=2;travel.Progress=0;calls={}
assert(gm:GoTo(301) and table.concat(calls,',')=='stop,leave,plan,relocate,pause,fog,enter')
print('PASS GM event navigation preserves choices, pauses and relocates safely, rejects mid-step mutation and avoids re-entering the current scene')

local Proxy=require('Config.LanguageProxy')
Proxy.Bind(function(key)return ({GmNpcInvalidId='Invalid NPC ID',GmNpcAnimalIdentity='Generic animal dialogue',
    GmNpcWorldParty='%s is roaming',GmNpcEventLocation='%s at (%d,%d): %s',GmNpcEventPending='Awaiting choice'})[key]end)
target,why=gm:Target(0);assert(not target and why=='Invalid NPC ID')
assert(gm:Search('401')[1].body=='Generic animal dialogue' and gm:Search('101')[1].body=='World legend is roaming')
assert(gm:Search('301')[1].body:find('Trial at (15,25): Awaiting choice',1,true))
Proxy.Bind(nil)

local Controller=require('UI.Panel.GMCtr')
local closed,refreshed=0,0
local controller={gm={npcs=gm,adventure=adventure},view={Result={}},demo={BattleHUDRevision=1,LastError=''},
    Close=function()closed=closed+1 end,RefreshNpcs=function()refreshed=refreshed+1 end}
function controller.demo:SendCommand(command,id)assert(command=='gm_goto_npc');self.BattleHUDRevision=self.BattleHUDRevision+1 end
Controller.GoToNpc(controller,301)
assert(closed==1 and refreshed==0 and controller.view.Result.text==string.format(Language.GmNpcEventEntered,'Trial'))
Controller.GoToNpc(controller,1);assert(closed==1 and refreshed==1,'Town navigation must retain its existing panel behavior')
controller.demo.LastError='fixture rejection';Controller.GoToNpc(controller,301)
assert(closed==1 and refreshed==2 and controller.view.Result.text=='fixture rejection')
print('PASS GM messages resolve language overrides and only successful event navigation closes GM for the story panel')
