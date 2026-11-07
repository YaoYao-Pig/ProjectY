-- Settlement uses real town gates, reward preparation/application and journal rows; C# Data is a fixture.
package.path='Lua/?.lua;'..package.path
CS={ProjectY={Data={PartyRoster={Count=function(data)return data.PartyCount end}}}}
local Missions=require('Game.Narrative.TownMissions')
local Language=require('Language')
local passed=0
local function test(name,fn)fn();passed=passed+1;print('PASS '..name)end
local function tableOf(rows)return {Get=function(_,id)return assert(rows[id],'Missing fixture row '..id)end}end
local function fixture(kind,state)
    local mission={Id=7,DefinitionId=1,State=state or 'ready',SiteId=1,NpcId=77,TargetId=22,
        RequiredCount=3,Progress=3,DestinationSiteId=2}
    local data={Count=1}
    function data:Find(id)if id==mission.Id then return mission end end
    function data:GetAt(i)assert(i==0);return mission end
    function data:Complete(id)assert(id==mission.Id and mission.State=='ready');mission.State='completed'end
    local inventory={count=5,consumed=0}
    function inventory:ConsumeStack(id,amount)
        assert(id==22 and self.count>=amount);self.count=self.count-amount;self.consumed=self.consumed+amount
    end
    local actor={Id=1,Growth={Initialized=true,Experience=0}}
    local area={InteractionKind=2,InteractionId=1,CellIndex=1}
    function area:GetNpcAt()return {Present=true,CellIndex=2}end
    local world={Phase='map',PartyCount=1,Equipment=inventory,Areas={ActiveSiteId=0,Active=area}}
    function world:GetPartyAt(i)assert(i==0);return actor end
    local layout={npcs={{id=1,stableId=77,templateId=1},{id=2,stableId=78,templateId=1}},FindPath=function()return {2}end}
    local row={name='test contract',description='test objective',kind=kind,radius=5,actionIds={1,2}}
    local config={GetTable=function(_,name)
        if name=='EquipmentItemTable' then return tableOf({[22]={name='test material'}})end
        assert(name=='MapAreaTownNpcTable');return tableOf({{name='test publisher'}})
    end}
    local adventure={data=world,player={Coins=100},sites={{name='origin town'},{name='destination town'}},
        areas={layouts={[1]=layout},ActiveLayout=function()return layout end},
        factions={allowed=true},growth={AddExperience=function(_,target,amount)target.Growth.Experience=target.Growth.Experience+amount end}}
    function adventure.player:AddCoins(amount)self.Coins=self.Coins+amount end
    function adventure.factions:ServiceAllowed()return self.allowed,'services unavailable'end
    local completions=0
    adventure.titles={CompletionReward=function()return 30 end,Complete=function(_,kind,id)
        assert(kind=='town' and id==mission.Id and mission.State=='completed');completions=completions+1;return 30
    end}
    local receipts={}
    local story={adventure=adventure,rules={config=config,actions=tableOf({
        {kind='add_coins',value=50},{kind='grant_experience',value=25}})},
        ItemCount=function(_,id)assert(id==22);return inventory.count end,
        RewardSettled={Emit=function(_,receipt)assert(mission.State=='completed');receipts[#receipts+1]=receipt end}}
    local missions=setmetatable({story=story,data=data,definitions=tableOf({row}),Refresh=function()end},Missions)
    return {missions=missions,mission=mission,world=world,adventure=adventure,actor=actor,inventory=inventory,
        receipts=receipts,completions=function()return completions end}
end
local function unchanged(f)
    assert(f.adventure.player.Coins==100 and f.actor.Growth.Experience==0 and f.inventory.consumed==0)
    assert(#f.receipts==0 and f.completions()==0)
end
local function publisher(f)
    f.world.Phase='area';f.world.Areas.ActiveSiteId=1;f.world.Areas.Active.InteractionId=1
end

test('ready escort is directly claimable from map and another town exactly once',function()
    for _,phase in ipairs({'map','area'})do
        local f=fixture('escort');f.world.Phase=phase;f.world.Areas.ActiveSiteId=2
        f.adventure.factions.allowed=false
        local view=f.missions:Rows()[1]
        assert(view.claimable and view.reason=='' and view.turnInHint==Language.TownEscortTurnInHint)
        assert(f.missions:Claim(f.mission.Id));assert(f.mission.State=='completed')
        assert(f.adventure.player.Coins==150 and f.actor.Growth.Experience==25 and f.inventory.consumed==0)
        assert(#f.receipts==1 and f.receipts[1].kind=='town' and f.receipts[1].id==f.mission.Id and f.completions()==1)
        assert(not f.missions:Claim(f.mission.Id) and not f.missions:Rows()[1].claimable)
        assert(f.adventure.player.Coins==150 and f.actor.Growth.Experience==25 and #f.receipts==1 and f.completions()==1)
    end
end)

test('remote escort keeps reward preflight and cannot complete early or after failure',function()
    local f=fixture('escort');f.actor.Growth.Experience=2147483647
    local view=f.missions:Rows()[1];local ok,reason=f.missions:Claim(f.mission.Id)
    assert(not view.claimable and not ok and reason==view.reason and reason~='')
    assert(f.mission.State=='ready' and f.adventure.player.Coins==100 and #f.receipts==0 and f.completions()==0)
    f.actor.Growth.Experience=0;assert(f.missions:Rows()[1].claimable and f.missions:Claim(f.mission.Id))
    for _,state in ipairs({'offered','active','failed','completed'})do
        f=fixture('escort',state);assert(not f.missions:Claim(f.mission.Id));unchanged(f)
    end
    for _,phase in ipairs({'battle','idle'})do
        f=fixture('escort');f.world.Phase=phase
        local blocked=f.missions:Rows()[1];local claimed,why=f.missions:Claim(f.mission.Id)
        assert(not blocked.claimable and not claimed and why==Language.TownMissionClaimExplorationOnly and blocked.reason==why)
        unchanged(f)
    end
    f=fixture('escort');assert(not f.missions:Claim(999));unchanged(f)
end)

test('delivery and clear still require the original publisher and operating town',function()
    for _,kind in ipairs({'delivery','clear'})do
        local f=fixture(kind);local view=f.missions:Rows()[1]
        assert(not view.claimable and view.turnInHint==Language.TownMissionTurnInHint)
        local ok,reason=f.missions:Claim(f.mission.Id);assert(not ok and reason==view.reason);unchanged(f)
        publisher(f);f.world.Areas.Active.InteractionId=2
        assert(not f.missions:Rows()[1].claimable and not f.missions:Claim(f.mission.Id));unchanged(f)
        publisher(f);f.adventure.factions.allowed=false
        assert(not f.missions:Rows()[1].claimable and not f.missions:Claim(f.mission.Id));unchanged(f)
        f.adventure.factions.allowed=true
        assert(f.missions:Rows()[1].claimable and f.missions:Claim(f.mission.Id))
        assert(f.inventory.consumed==(kind=='delivery' and 3 or 0) and #f.receipts==1 and f.completions()==1)
    end
end)

test('delivery inventory and reward checks prevent consumption until settlement succeeds',function()
    local f=fixture('delivery');publisher(f);f.inventory.count=2
    assert(not f.missions:Rows()[1].claimable and not f.missions:Claim(f.mission.Id));unchanged(f)
    f.inventory.count=5;f.actor.Growth.Experience=2147483647
    assert(not f.missions:Rows()[1].claimable and not f.missions:Claim(f.mission.Id))
    assert(f.inventory.count==5 and f.inventory.consumed==0 and #f.receipts==0)
    f.actor.Growth.Experience=0;assert(f.missions:Claim(f.mission.Id))
    assert(f.inventory.count==2 and f.inventory.consumed==3)
    assert(not f.missions:Claim(f.mission.Id) and f.inventory.count==2 and #f.receipts==1)
end)

test('journal labels escort completion and routes its click to the same settlement command',function()
    -- Execute the production controller with presentation-only fixtures, without creating Unity objects.
    local function noop()end
    package.loaded['UI.ArtSkin']={ApplyButton=noop,ApplyImage=noop,FitTab=noop,FitEntry=noop}
    package.loaded['UI.UIPanelCtrl']={}
    CS.UnityEngine={Vector2=function(x,y)return {x=x,y=y}end}
    local Journal=require('UI.Panel.MissionJournalCtr')
    local view={RewardsLayout={cellSize={x=100}}}
    for _,key in ipairs({'Title','Caption','CompanionsText','Companions','MissionsScroll','Objective','RewardTitle','Rewards',
        'PrimaryAction','PrimaryHint','DetailTitle','Description','PrimaryText','Hint'})do
        view[key]={gameObject={SetActive=function(self,value)self.active=value end}}
    end
    local function widget()return {SetData=noop,view={Button={},Title={},Body={},Label={},Selected={}}}end
    local row={id=-7,contractId=7,status='ready',kind='escort',claimable=true,reason='',name='escort',
        description='fixture description',quests={},rewards={},turnInHint=Language.TownEscortTurnInHint}
    local story={data={Minutes=0,Revision=0},Rows=function()return {} end,townMissions={Rows=function()return {row}end}}
    local sent={};local demo={LastError='',BattleHUDRevision=0,SendCommand=function(_,command,id)sent={command,id}end}
    local journal=setmetatable({story=story,demo=demo,view=view,category='town',townNpcId=77,
        tabs={},missionRows={widget()},rewardRows={},pool={},skin={colors={ink={}}}},Journal)
    for i=1,6 do journal.tabs[i]=widget()end
    journal:Refresh()
    assert(view.PrimaryAction.interactable and view.PrimaryText.DefaultText==Language.TownEscortComplete)
    journal.primaryAction();assert(sent[1]=='town_mission_claim' and sent[2]==7)
    row.claimable=false;journal:Refresh();assert(not view.PrimaryAction.interactable)
    row.kind='delivery';row.claimable=true;journal:Refresh()
    assert(view.PrimaryText.DefaultText==Language.UIMissionJournalTitle6)
    row.kind='escort';row.status='inactive';journal:Refresh()
    assert(view.PrimaryText.DefaultText==Language.UIMissionJournalTitle7)
    journal.primaryAction();assert(sent[1]=='town_mission_accept' and sent[2]==7)
end)

print('PASS town mission claim: '..passed..' focused cases')
