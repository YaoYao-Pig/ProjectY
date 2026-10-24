-- 离线运行真实叙事流转、条件、对话、奖励与导出配置；仅替代 C# 状态容器和世界表现。
package.path = 'Lua/?.lua;' .. package.path
local config = require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local Rules=require('Game.Narrative.NarrativeRules')
local Actions=require('Game.Narrative.NarrativeActions')
local function copy(values)local result={};for k,v in pairs(values)do result[k]=v end;return result end
local function fixture()
    local data={Revision=0,Minutes=600,DialogueOpen=false,DialogueVersion=0,values={},progress={},kills={}}
    function data:GetValue(key)return self.values[key] or 0 end
    function data:SetValue(key,value)if self:GetValue(key)~=value then self.values[key]=value;self.Revision=self.Revision+1 end end
    function data:Status(kind,id)local row=self.progress[kind..':'..id];return row and row.state or 'inactive' end
    function data:Begin(kind,id)assert(self:Status(kind,id)=='inactive');self.progress[kind..':'..id]={state='active',baseline=copy(self.kills)};self.Revision=self.Revision+1 end
    function data:Ready(kind,id)assert(self:Status(kind,id)=='active');self.progress[kind..':'..id].state='ready';self.Revision=self.Revision+1 end
    function data:Complete(kind,id)assert(self:Status(kind,id)=='ready');self.progress[kind..':'..id].state='completed';self.Revision=self.Revision+1 end
    function data:RecordKill(id)self.kills[id]=(self.kills[id] or 0)+1;self.Revision=self.Revision+1 end
    function data:KillCount(kind,id,target)local row=assert(self.progress[kind..':'..id]);return (self.kills[target] or 0)-(row.baseline[target] or 0) end
    function data:BeginDialogue(id,npc)local old=self.DialogueOpen;assert(not old);self.interjections={};self.DialogueOpen=true;self.DialogueId=id;self.DialogueNpcId=npc;self.DialogueVersion=self.DialogueVersion+1 end
    function data:EnterDialogueNode(id)self.DialogueNodeId=id;self.DialogueVersion=self.DialogueVersion+1 end
    function data:AddDialogueLine()end
    function data:HasDialogueInterjection(id)return self.interjections[id]==true end
    function data:AddCompanionLine()end
    function data:CompleteDialogueInterjection(id)self.interjections[id]=true;self.DialogueVersion=self.DialogueVersion+1 end
    function data:CloseDialogue()self.DialogueOpen=false;self.DialogueVersion=self.DialogueVersion+1 end
    local actors={}
    for id=1,3 do
        local growth={Initialized=true,Experience=0,Level=1,AttributePoints=0,TalentPoints=0,opportunities=0,total=0}
        function growth:AddExperience(amount)self.Experience=self.Experience+amount;self.total=self.total+amount end
        function growth:AdvanceLevel(cost,attributes,talents,learn)self.Experience=self.Experience-cost;self.Level=self.Level+1;self.AttributePoints=self.AttributePoints+attributes;self.TalentPoints=self.TalentPoints+talents;if learn then self.opportunities=self.opportunities+1 end end
        actors[id]={Id=id,TemplateId=id,HP=10,Growth=growth,attributes={}}
        actors[id].HasTrait=function()return false end
    end
    local inventory={Revision=0,Grid={Count=0},items={}}
    function inventory:CountItem(id)return self.items[id] or 0 end
    local world={PartyCount=#actors,JournalCount=0,Phase='area',Equipment=inventory,Areas={Active={InteractionKind=2,InteractionId=1,GetMemberIdAt=function()return 1 end,Stop=function()end}}}
    function world:GetPartyAt(i)return assert(actors[i+1]) end
    local growth=require('Game.Progression.GrowthSystem')()
    growth.rules={maxLevel=10,levels=config:GetTable('GrowthLevelTable')};growth.chronicle={Record=function()end}
    local equipment={full=false,grants=0}
    function equipment:CanGrant()return not self.full end
    function equipment:Grant(id,count)assert(not self.full);inventory.items[id]=inventory:CountItem(id)+count;inventory.Revision=inventory.Revision+1;self.grants=self.grants+count;return true end
    local player={Coins=1000}
    function player:TrySpendCoins(value)if self.Coins<value then return false end;self.Coins=self.Coins-value;return true end
    function player:AddCoins(value)self.Coins=self.Coins+value end
    local story=require('Game.Narrative.NarrativeSystem')()
    story.townMissions={Refresh=function()end}
    story.data=data;story.rules=Rules.New(config)
    story.adventure={data=world,player=player,equipment=equipment,growth=growth,recipe={maxPartySize=4},areas={CloseInteraction=function()end},battle={stats={Get=function(_,actor,code)return actor.attributes[code] or 0 end}}}
    story.conditions=require('Game.Condition.ConditionSystem')()
    story.conditions:OnInit({systems={Get=function(_,name)assert(name=='Config');return config end}})
    require('Game.Narrative.NarrativeConditions')(story);story.conditions:OnStart()
    story.npcs={SyncPresence=function()end};story.dialogue=require('Game.Narrative.Dialogue').New(story)
    for _,npc in ipairs(story.rules.npcs:All())do data:SetValue('relation:'..npc.id,npc.initialRelation)end
    for _,faction in ipairs(story.rules.factions:All())do data:SetValue('reputation:'..faction.id,faction.initialValue)end
    local f={story=story,data=data,actors=actors,inventory=inventory,equipment=equipment}
    function f:choose(text)
        local chosen
        for _,id in ipairs(story.rules.nodes:Get(data.DialogueNodeId).choiceIds)do local row=story.rules.choices:Get(id);if row.text:find(text,1,true)then assert(not chosen,'Ambiguous choice '..text);chosen=row end end
        assert(chosen,'Choice missing: '..text)
        local version=data.DialogueVersion
        local ok,reason=story.dialogue:Choose(chosen.id,version);assert(ok,text..': '..tostring(reason))
        assert(not story.dialogue:Choose(chosen.id,version),'Stale click must not repeat rewards')
        return chosen
    end
    function f:talk(npc,topic,selection)
        if data.DialogueOpen then story.dialogue:Close() end
        assert(story.dialogue:Open(npc,1));self:choose(topic)
        local menu=data.DialogueNodeId
        self:choose(selection)
        for _,id in ipairs(story.rules.nodes:Get(menu).choiceIds)do
            local row=story.rules.choices:Get(id)
            if #row.actionIds>0 then assert(not story.conditions:Check(row.conditionId,{}),'A resolved branch must disable every sibling action') end
        end
        story.dialogue:Close()
    end
    function f:kill(id,count)for _=1,count do data:RecordKill(id)end;story:Refresh()end
    function f:claim(id)
        assert(data:Status('mission',id)=='ready','Mission '..id..' not ready')
        local before=actors[1].Growth.total
        local plan=assert(Actions.Prepare(story,story.rules.missions:Get(id).actionIds));assert(plan)
        assert(actors[1].Growth.total==before,'Preparing experience must not mutate growth')
        equipment.full=true
        local ok,reason=story:Claim('mission',id)
        assert(not ok and reason:find('背包') and actors[1].Growth.total==before and data:Status('mission',id)=='ready','Full inventory must defer the whole reward')
        equipment.full=false;assert(story:Claim('mission',id));local after=actors[1].Growth.total
        assert(after>before and not story:Claim('mission',id) and actors[1].Growth.total==after,'Completed mission cannot give XP twice')
        story:Refresh()
    end
    story:Refresh();assert(data:Status('mission',300)=='active' and data:Status('mission',400)=='active' and data:Status('mission',500)=='inactive')
    return f
end
local function campaign(ledger,bell,ending,highStats,reverseOrder)
    local f=fixture();local s,d=f.story,f.data
    if highStats then for _,a in ipairs(f.actors)do a.attributes={intellect=10,scouting=5,crafting=4,charisma=5}end end
    -- 真实激活前击杀不能回填任何新阶段。
    f:kill(4,20);f:kill(5,20)
    f:talk(3,'这封烧焦','我会把账');f:talk(4,'为什么停了','先把裂痕')
    assert(d:KillCount('quest',305,4)==0 and d:KillCount('quest',405,5)==0)
    f:talk(5,'为什么没有离开','先把你记作')
    f:talk(3,'核对两本账',highStats and '[智力' or '支付 20')
    f:talk(4,'看看拆下',highStats and '[侦察' or '支付 15')
    local planChoices={'恢复人人','保留卫队','改用分区'}
    f:talk(4,'钟该为谁',planChoices[bell])
    -- 实际搜刮/购买由物品系统负责；此夹具只在边界补入所需库存。
    f.inventory.items[81]=6;f.inventory.items[83]=4;f.inventory.items[82]=2;f.inventory.items[91]=2;s:Refresh()
    f:kill(4,3);f:kill(5,2)
    local function ash()
        f:talk(5,'退路与救济',highStats and '[魅力' or '匿名封存')
        f:talk(3,'账本不能',({'公开原账','原账交互助会','交给工匠会'})[ledger])
        local verdict=d:GetValue('flag:ash_verdict');assert(verdict==ledger)
        assert(s.conditions:Check(s.rules.quests:Get(307).completeConditionId,{}))
        f:talk(6,'仓库大火','把这段承认');f:talk(3,'最后一页','签字。')
        f:claim(300)
    end
    local function clock()
        f:talk(4,'开始校准',highStats and '[巧匠' or '支付 15')
        f:talk(5,'钟究竟响了',highStats and d:GetValue('flag:ash_named')==1 and '凭公开' or '支付 10')
        f:talk(4,'证词与钟机',({'恢复公共','交卫队','建立街区'})[bell])
        f:talk(6,'警戒规程','请把这句话');f:talk(4,'工图交还','签下验收')
        f:claim(400)
    end
    if reverseOrder then clock();assert(d:Status('mission',500)=='active');ash() else ash();assert(d:Status('mission',500)=='active');clock() end
    f:talk(6,'一份邀请','先落实三方')
    assert(d:KillCount('quest',506,4)==0 and d:KillCount('quest',506,5)==0,'Earlier case kills cannot satisfy council escort')
    f:talk(3,'救济与驿工',highStats and '[魅力' or '保留你的')
    f:talk(4,'坐到桌前',highStats and '[巧匠' or '先保留')
    f:talk(5,'写给你的',highStats and '你已有公开' or '匿名陈述')
    f:kill(4,4);f:kill(5,2)
    f:talk(6,'先写什么',highStats and '[智力' or '临时章程')
    f:talk(6,'最终的议约',({'[驿路声望','[工匠声望','先签临时','[公开原账'})[ending])
    assert(d:GetValue('flag:council_ending')==ending)
    local outcomeCoins=s.adventure.player.Coins;local grants=f.equipment.grants
    s:Refresh();assert(s.adventure.player.Coins==outcomeCoins and f.equipment.grants==grants,'Refresh must not repeat ending reward')
    f:talk(3,'怎么看这份','把这些问题');f:talk(6,'最后一封档案','封存档案');f:claim(500)
    for _,id in ipairs({300,400,500})do assert(d:Status('mission',id)=='completed')end
    assert(f.actors[1].Growth.Level>1 and f.actors[1].Growth.AttributePoints>0 and f.actors[1].Growth.opportunities>0,'Mission XP must use real growth level and learning rules')
    for _,a in ipairs(f.actors)do assert(a.Growth.total==f.actors[1].Growth.total)end
    return f
end
-- 每个账本 × 警钟选择均能走无属性保底结局，两案顺序也不固定。
for ledger=1,3 do for bell=1,3 do campaign(ledger,bell,3,false,(ledger+bell)%2==0)end end
campaign(1,2,1,false,false)
campaign(3,3,2,false,true)
local best=campaign(1,1,4,true,false)
assert(best.data:GetValue('flag:council_named')==1)

-- 属性阈值、倒地排除、即时成长/装备结果读取，以及时段边界。
local f=fixture();local checks={}
for _,row in ipairs(config:GetTable('ConditionTable'):All())do
    if row.kind=='party_attribute' and row.targetId==19 and row.value==5 then checks.attribute=row.id end
    if row.kind=='time_window' and row.targetId==1200 then checks.time=row.id end
end
assert(checks.attribute and checks.time)
f.actors[2].attributes.charisma=4;assert(not f.story.conditions:Check(checks.attribute,{}))
f.actors[2].attributes.charisma=5;assert(f.story.conditions:Check(checks.attribute,{}))
f.actors[2].HP=0;assert(not f.story.conditions:Check(checks.attribute,{}));f.actors[2].HP=1
assert(f.story.conditions:Check(checks.attribute,{}))
for _,case in ipairs({{1199,false},{1200,true},{1379,true},{1380,false},{2640,true}})do f.data.Minutes=case[1];assert(f.story.conditions:Check(checks.time,{})==case[2])end
-- 账本提供的修钟凭据能够替代材料，而不是只改变文案。
local supply=f.story.rules.quests:Get(403).completeConditionId
assert(not f.story.conditions:Check(supply,{}))
f.data:SetValue('flag:ash_verdict',2);assert(f.story.conditions:Check(supply,{}))
f.data:SetValue('flag:ash_verdict',1);assert(not f.story.conditions:Check(supply,{}))
-- 合并动作的经验上限预检也不能部分发奖。
local rewards=best.story.rules.missions:Get(300).actionIds
best.actors[1].Growth.Experience=2147483647
local plan,reason=Actions.Prepare(best.story,rewards);assert(not plan and reason:find('经验超过上限'))
-- 独立实例恢复叙事事实/任务/击杀基线后，完成任务仍不可领取。
local restored=fixture()
restored.data.values=copy(best.data.values);restored.data.kills=copy(best.data.kills)
for key,row in pairs(best.data.progress)do restored.data.progress[key]={state=row.state,baseline=copy(row.baseline)}end
restored.story:Refresh();assert(not restored.story:Claim('mission',500) and restored.actors[1].Growth.total==0)
-- 实际城镇生成与 NPC 日程占位；配置中的叙事 NPC 不得挤在同一出生/停留格。
local generator=require('Game.MapArea.MapAreaGenerator')(config)
generator:Register(2,require('Game.MapArea.TownGenerator'),'MapAreaTownTable','MapAreaTownThemeTable')
local npcs=require('Game.Narrative.NpcSystem').New(f.story)
local site={id=11,areaConfigId=2};npcs:BindWorld({site})
local expectedNpcCount=0
for _,placement in ipairs(f.story.rules.placements:All())do if placement.areaId==site.areaConfigId then expectedNpcCount=expectedNpcCount+1 end end
for _,seed in ipairs({20260924,20261016})do
    local area=generator:Generate(2,seed,site.id,{regionId=7,regionType=5,regionConfigId=5,q=0,r=0,height=1,biomeWeights={{regionType=5,weight=1}}},function(layout)npcs:Populate(layout,site)end)
    local count,occupied=0,{}
    for _,npc in ipairs(area.npcs)do
        assert(not occupied[npc.spawnIndex]);occupied[npc.spawnIndex]=true
        if npc.narrativeId then
            count=count+1;assert(area:FindPath(area.entryIndex,npc.spawnIndex))
            for _,target in pairs(npc.scheduleTargets)do assert(area:FindPath(npc.spawnIndex,target))end
        end
    end
    assert(count==expectedNpcCount,'All configured story NPCs must be present in the town')
end
print('PASS campaign: 12 complete routes, low-attribute alternatives, both mission orders, four endings, activation kill baselines, one-time/full-bag XP, real level growth, restored completion, attribute and time boundaries')
