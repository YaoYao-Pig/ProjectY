package.path='Lua/?.lua;'..package.path
local Markers=require('Game.Adventure.WorldMapMarkers')
local TownMissions=require('Game.Narrative.TownMissions')
local function tableOf(rows)
    return {Get=function(_,id)return assert(rows[id])end,All=function()return rows end}
end
local function forbidden()error('Map projection called a state-changing or proximity operation')end
local function fixture()
    local records,npcs,status,recruited,closed,absent,items={},{},{},{},{},{},{}
    local story={data={Minutes=2880,Revision=7},npcs={locations={}},conditions={Check=function()return true end}}
    local adventure={narrative=story,player={Coins=0},data={PartyCount=0},factions={}}
    story.adventure=adventure
    story.Refresh=forbidden
    function story.data:GetValue(key)return recruited[key] or 0 end
    function story.data:Status(_,id)return status[id] or 'inactive' end
    function story:CanAccept(id)return self.data:Status('mission',id)=='inactive' end
    function story:ItemCount(id)return items[id] or 0 end
    function adventure.factions:ServiceAllowed(id)return not closed[id] end
    function adventure.factions:NpcAvailable(_,id)return not absent[id] end
    local actions,missions,dialogues,nodes,choices={},{},{},{},{}
    story.rules={npcs=tableOf(npcs),actions=tableOf(actions),missions=tableOf(missions),
        dialogues=tableOf(dialogues),nodes=tableOf(nodes),choices=tableOf(choices)}
    actions[1]={kind='add_coins',value=5}
    local town=setmetatable({story=story,definitions=tableOf({
        [1]={kind='delivery',actionIds={1}},[2]={kind='clear',actionIds={1}},[3]={kind='escort',actionIds={1}}}),
        data={Count=0,Revision=4},EnsureTown=forbidden,Refresh=forbidden,NearPublisher=forbidden,
        Accept=forbidden,Claim=forbidden},{__index=TownMissions})
    story.townMissions=town
    function town.data:GetAt(index)return records[index+1] end
    local f={adventure=adventure,story=story,records=records,npcs=npcs,status=status,recruited=recruited,
        closed=closed,absent=absent,items=items}
    function f:contract(site,state,definition,destination,day)
        local row={Id=#records+1,SiteId=site,NpcId=100001,DefinitionId=definition or 2,
            State=state,TargetId=81,RequiredCount=4,Progress=0,DestinationSiteId=destination or 0,Day=day or 2}
        records[#records+1]=row;town.data.Count=#records;return row
    end
    function f:npc(site,state,kind)
        local id=#npcs+1;local missionId=100+id
        npcs[id]={id=id,locationKind=kind or 'town',recruitable=false,dialogueIds={id}}
        story.npcs.locations[id]=site;status[missionId]=state
        dialogues[id]={conditionId=1,entryNodeId=id};nodes[id]={choiceIds={id*2,id*2+1}}
        choices[id*2]={conditionId=1,actionIds={id*2},nextNodeId=0}
        choices[id*2+1]={conditionId=1,actionIds={id*2+1},nextNodeId=0}
        actions[id*2]={kind='accept_mission',targetId=missionId}
        actions[id*2+1]={kind='claim_mission',targetId=missionId}
        missions[missionId]={actionIds={1}}
        return npcs[id]
    end
    return f
end
local function signature(rows)
    local result={}
    for _,row in ipairs(rows) do
        result[#result+1]=row.siteId..':'..row.kind..':'..row.count
        local fields=0;for _ in pairs(row)do fields=fields+1 end
        assert(fields==3,'Map markers must not expose coordinates, names or moving identities')
    end
    return table.concat(result,',')
end
local passed=0
local function test(name,run)run();passed=passed+1;print('PASS '..name)end

test('known-site intersection and stable aggregation',function()
    local f=fixture()
    f:contract(2,'offered');f:contract(2,'offered');f:contract(2,'active')
    f:contract(2,'ready');f:contract(1,'active');f:contract(9,'ready')
    f:npc(2,'inactive');f:npc(2,'ready');f:npc(9,'ready')
    local expected='1:active:1,2:available:3,2:active:1,2:ready:2'
    assert(signature(Markers.Build(f.adventure,{{id=2},{id=1}}))==expected)
    assert(signature(Markers.Build(f.adventure,{{id=1},{id=2}}))==expected)
    assert(#Markers.Build(f.adventure,{})==0)
end)

test('completion, failure and expired unaccepted offers disappear',function()
    local f=fixture();local row=f:contract(1,'active');f:npc(1,'completed')
    f:contract(1,'failed');f:contract(1,'offered',2,0,1)
    assert(signature(Markers.Build(f.adventure,{{id=1}}))=='1:active:1')
    row.State='completed';assert(#Markers.Build(f.adventure,{{id=1}})==0)
end)

test('ready delivery rechecks materials and rewards without requiring publisher proximity',function()
    local f=fixture();f:contract(1,'ready',1);f.items[81]=4
    assert(signature(Markers.Build(f.adventure,{{id=1}}))=='1:ready:1')
    f.items[81]=3
    assert(signature(Markers.Build(f.adventure,{{id=1}}))=='1:active:1')
    f.items[81]=4;f.adventure.player.Coins=2147483647
    assert(signature(Markers.Build(f.adventure,{{id=1}}))=='1:active:1')
end)

test('known escort destinations only while active, never moving parties',function()
    local f=fixture();local row=f:contract(1,'active',3,2)
    f:contract(1,'active',3,9);f:contract(1,'active',3,1)
    f.adventure.parties=setmetatable({},{__index=forbidden})
    assert(signature(Markers.Build(f.adventure,{{id=2},{id=1}}))=='1:active:3,2:active:1')
    row.State='ready'
    assert(signature(Markers.Build(f.adventure,{{id=2},{id=1}}))=='1:active:2,1:ready:1')
end)

test('unavailable town contacts and non-town NPCs do not advertise tasks',function()
    local f=fixture()
    local recruited=f:npc(1,'ready');f.recruited['recruited:'..recruited.id]=10001
    local recovering=f:npc(1,'inactive');recovering.recruitable=true;f.absent[recovering.id]=true
    f:npc(1,'ready','world_party');f:npc(1,'ready','event');f:npc(1,'inactive','animal')
    f:npc(2,'ready');f.closed[2]=true;f:contract(2,'offered');f:contract(2,'ready')
    f:npc(1,'active')
    assert(signature(Markers.Build(f.adventure,{{id=2},{id=1}}))=='2:active:1')
end)

test('repeated projection leaves authoritative data and input snapshots unchanged',function()
    local f=fixture();local row=f:contract(1,'ready',1);f.items[81]=4;f:npc(1,'ready')
    local known={{id=1,name='Fixture',q=3,r=4}};local before=signature(Markers.Build(f.adventure,known))
    for _=1,3 do assert(signature(Markers.Build(f.adventure,known))==before)end
    assert(row.State=='ready' and row.Progress==0 and f.story.townMissions.data.Count==1)
    assert(f.items[81]==4 and f.adventure.player.Coins==0 and f.status[101]=='ready')
    assert(f.story.data.Revision==7 and f.story.townMissions.data.Revision==4 and f.story.data.Minutes==2880)
    assert(f.story.npcs.markers==nil and #known==1 and known[1].id==1 and known[1].name=='Fixture' and known[1].q==3 and known[1].r==4)
end)

test('an adventure without the optional narrative system has no task markers',function()
    assert(#Markers.Build({},{{id=1}})==0)
end)
print('PASS world map markers: '..passed..' focused checks')
