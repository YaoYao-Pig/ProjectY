package.path = 'Lua/?.lua;' .. package.path
local Story = require('Game.Narrative.NarrativeSystem')
local Actions = require('Game.Narrative.NarrativeActions')
local Rewards = require('Game.Narrative.MissionRewards')
local TownMissions = require('Game.Narrative.TownMissions')
local Dialogue = require('Game.Narrative.Dialogue')

local function tableOf(rows)
    return {Get=function(_,id)return assert(rows[id],'Missing fixture row '..id)end,
        All=function()local result={};for _,row in pairs(rows)do result[#result+1]=row end;return result end}
end
local function find(rows,kind)
    for _,row in ipairs(rows) do if row.kind==kind then return row end end
end
local function fixture()
    local story=Story()
    story.RewardSettled.log=function(err)error(err,0)end
    local data={values={['relation:1']=90,['reputation:1']=18},states={},DialogueVersion=1,DialogueOpen=true,DialogueNodeId=1,DialogueNpcId=1}
    function data:GetValue(key)return self.values[key] or 0 end
    function data:SetValue(key,value)self.values[key]=value end
    function data:Status(kind,id)return self.states[kind..':'..id] or 'inactive' end
    function data:Complete(kind,id)assert(self:Status(kind,id)=='ready');self.states[kind..':'..id]='completed' end
    function data:AddDialogueLine()end
    function data:EnterDialogueNode(id)self.DialogueNodeId=id;self.DialogueVersion=self.DialogueVersion+1 end
    local actors={{Id=1,HP=10,Growth={Initialized=true,Experience=0}},{Id=2,HP=0,Growth={Initialized=true,Experience=0}}}
    local inventory={items={[22]=5},Revision=0}
    function inventory:CountItem(id)return self.items[id] or 0 end
    function inventory:ConsumeStack(id,amount)assert(self:CountItem(id)>=amount);self.items[id]=self.items[id]-amount end
    local world={Phase='area',PartyCount=#actors,Equipment=inventory}
    function world:GetPartyAt(index)return assert(actors[index+1])end
    local equipment={full=false}
    function equipment:CanGrant()return not self.full end
    function equipment:Grant(id,amount)assert(not self.full);inventory.items[id]=inventory:CountItem(id)+amount;return true end
    local player={Coins=100}
    function player:AddCoins(amount)self.Coins=self.Coins+amount end
    function player:TrySpendCoins(amount)if self.Coins<amount then return false end;self.Coins=self.Coins-amount;return true end
    local growth={AddExperience=function(_,actor,amount)actor.Growth.Experience=actor.Growth.Experience+amount end}
    local items=tableOf({[22]={id=22,name='补给',kind='material',iconPath='Icons/supply'}})
    story.data=data
    story.rules={config={GetTable=function(_,name)assert(name=='EquipmentItemTable');return items end},
        actions=tableOf({
            [1]={kind='add_coins',value=50},[2]={kind='grant_experience',value=25},
            [3]={kind='grant_item',targetId=22,value=2},[4]={kind='add_relation',targetId=1,value=50},
            [5]={kind='add_reputation',targetId=1,value=10},[6]={kind='set_flag',key='done',value=1},
            [7]={kind='claim_mission',targetId=100},[8]={kind='add_coins',value=10},
            [9]={kind='recruit_npc',targetId=1,value=0},[10]={kind='add_reputation',targetId=1,value=-5},
            [11]={kind='add_relation',targetId=1,value=5},[12]={kind='add_coins',value=-4}}),
        npcs=tableOf({[1]={name='莱雅',relationMin=0,relationMax=100,locationKind='town'}}),
        factions=tableOf({[1]={name='公会',minValue=0,maxValue=20}}),
        missions=tableOf({[100]={id=100,name='测试任务',description='原始说明',category='side',actionIds={1,2,3,4,5,6}},
            [101]={id=101,name='无物质奖励',description='',category='side',actionIds={6}}}),
        quests=tableOf({[201]={id=201,name='自动事实阶段',actionIds={6},autoComplete=true},
            [202]={id=202,name='手动阶段',actionIds={6},autoComplete=false},
            [203]={id=203,name='经验阶段',actionIds={2},autoComplete=true}}),questsByMission={},settings={playerSpeaker='队伍'},
        nodes=tableOf({[1]={id=1,dialogueId=1,choiceIds={1}},[2]={id=2,dialogueId=1,choiceIds={}}}),
        choices=tableOf({[1]={conditionId=0,actionIds={8,7,12},nextNodeId=2,text='领取'}})}
    story.adventure={data=world,equipment=equipment,player=player,growth=growth,recipe={maxPartySize=4},sites={[1]={name='河湾镇'}},areas={}}
    story.conditions={Check=function()return true end}
    story.Refresh=function()end
    story.CanAccept=function()return false end
    local receipts={}
    story.RewardSettled:Subscribe(function(receipt)receipts[#receipts+1]=receipt end)
    return story,actors,receipts
end

-- Preview does not grant anything; actual receipts reflect clamps and all original recipients, including downed members.
do
    local story,actors,receipts=fixture()
    local preview=Rewards.Preview(story,story.rules.missions:Get(100).actionIds)
    assert(#preview==5 and find(preview,'relation').amount==50 and find(preview,'reputation').amount==10)
    assert(find(preview,'experience').perMember and not find(preview,'experience').recipients)
    assert(find(preview,'item').itemId==22 and find(preview,'item').iconPath=='Icons/supply')
    assert(story.adventure.player.Coins==100 and actors[1].Growth.Experience==0 and #receipts==0)
    story.data.states['mission:100']='ready'
    story.RewardSettled:Subscribe(function(receipt)assert(story.data:Status(receipt.kind,receipt.id)=='completed')end)
    story.adventure.equipment.full=true
    assert(not story:Claim('mission',100) and #receipts==0 and actors[1].Growth.Experience==0 and story.adventure.player.Coins==100)
    assert(story.data:Status('mission',100)=='ready')
    story.adventure.equipment.full=false
    assert(story:Claim('mission',100) and #receipts==1)
    local receipt=receipts[1]
    assert(receipt.title=='测试任务' and receipt.kind=='mission' and receipt.id==100 and #receipt.rows==5)
    assert(find(receipt.rows,'coins').amount==50 and story.adventure.player.Coins==150)
    assert(find(receipt.rows,'relation').amount==10 and find(receipt.rows,'reputation').amount==2)
    local experience=find(receipt.rows,'experience')
    assert(experience.amount==25 and #experience.recipients==2 and experience.recipients[2].id==2)
    assert(actors[1].Growth.Experience==25 and actors[2].Growth.Experience==25)
    assert(not story:Claim('mission',100) and #receipts==1 and story.adventure.player.Coins==150)
    assert(#story:Rows()[1].rewards>0)
end

-- Automatic bookkeeping stays quiet; manual completion and whole missions still acknowledge completion.
do
    local story,_,receipts=fixture()
    for _,id in ipairs({201,202,203})do story.data.states['quest:'..id]='ready' end
    story.data.states['mission:101']='ready'
    assert(story:Claim('quest',201) and #receipts==0)
    assert(story:Claim('quest',202) and #receipts==1 and #receipts[1].rows==0)
    assert(story:Claim('mission',101) and #receipts==2 and #receipts[2].rows==0)
    assert(story:Claim('quest',203) and #receipts==3 and find(receipts[3].rows,'experience').amount==25)
end

-- Dialogue claims publish once after all surrounding actions; their receipt excludes unrelated choice costs/rewards.
do
    local story,actors,receipts=fixture()
    story.data.states['mission:100']='ready'
    story.RewardSettled:Subscribe(function()assert(story.adventure.player.Coins==156,'Emit must follow the final choice action')end)
    local dialogue=Dialogue.New(story)
    dialogue.Enter=function(_,id)story.data:EnterDialogueNode(id)end
    local version=story.data.DialogueVersion
    assert(dialogue:Choose(1,version) and #receipts==1)
    assert(find(receipts[1].rows,'coins').amount==50 and actors[1].Growth.Experience==25)
    assert(not dialogue:Choose(1,version) and #receipts==1)
end

-- Reward aggregation preserves signed actual deltas; capped relations and internal flags do not invent rewards.
do
    local story=fixture()
    story.data.values['relation:1']=100
    local rows=Actions.Apply(story,assert(Actions.Prepare(story,{1,8,12,2,2,4,11,5,10,6})))
    assert(#rows==3 and find(rows,'coins').amount==56 and not find(rows,'relation'))
    assert(find(rows,'experience').amount==50 and find(rows,'reputation').amount==-3)
    assert(Rewards.Preview(story,{9})[1].kind=='recruit','A zero action value still previews recruitment')
end

-- Recruitment is visible, but experience still targets exactly the members captured before the action group.
do
    local story,actors,receipts=fixture()
    local recruit={Id=10001,TemplateId=3,Growth={Initialized=true,Experience=0}}
    local deployed=false
    story.rules.missions:Get(100).actionIds={9,2}
    story.data.states['mission:100']='ready'
    story.adventure.equipment.initialLoadouts={Items=function()return {} end}
    story.npcs={PrepareRecruit=function()return {npcId=1,actorId=recruit.Id,actor=recruit}end,
        PrepareDeployment=function()return {} end,
        Recruit=function()actors[#actors+1]=recruit;story.adventure.data.PartyCount=#actors end,
        ApplyDeployment=function()deployed=true end}
    story.RewardSettled:Subscribe(function()assert(deployed,'Settlement must follow recruit deployment')end)
    assert(story:Claim('mission',100) and #receipts==1)
    local reward=find(receipts[1].rows,'recruit')
    assert(reward.name=='莱雅' and reward.targetId==1 and reward.amount==1)
    assert(#find(receipts[1].rows,'experience').recipients==2 and recruit.Growth.Experience==0)
end

-- Town delivery only consumes materials on successful grant, then reports the completed instance exactly once.
do
    local story,actors,receipts=fixture()
    local mission={Id=7,DefinitionId=1,State='ready',SiteId=1,NpcId=1,TargetId=22,RequiredCount=3}
    local data={Count=1,Find=function(_,id)if id==7 then return mission end end,GetAt=function()return mission end,
        Complete=function(_,id)assert(id==7 and mission.State=='ready');mission.State='completed'end}
    local town=setmetatable({story=story,data=data,definitions=tableOf({[1]={name='居民备料',description='交些补给',kind='delivery',actionIds={1,2}}}),
        Refresh=function()end,NearPublisher=function()return true end,PublisherName=function()return '居民甲'end},TownMissions)
    local view=town:Rows(1,1)[1]
    assert(view.description=='交些补给' and view.publisher=='居民甲' and view.location=='河湾镇' and view.objective:find('补给'))
    assert(#view.rewards==2 and view.turnInHint:find('原委托人'))
    actors[1].Growth.Experience=2147483647
    assert(not town:Claim(7) and story:ItemCount(22)==5 and #receipts==0 and mission.State=='ready')
    actors[1].Growth.Experience=0
    story.RewardSettled:Subscribe(function()assert(mission.State=='completed')end)
    assert(town:Claim(7) and #receipts==1 and story:ItemCount(22)==2)
    assert(receipts[1].kind=='town' and receipts[1].title=='居民备料' and #receipts[1].rows==2)
    assert(not town:Claim(7) and #receipts==1 and story:ItemCount(22)==2)
end

print('PASS mission rewards: previews, actual grants/clamps, downed XP recipients, blocked/repeated claims, automatic/manual stages, dialogue ordering and town delivery')
