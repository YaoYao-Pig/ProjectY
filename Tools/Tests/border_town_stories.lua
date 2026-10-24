-- 真实导出配置、条件、对话和任务流转；只替代 C# 容器与世界表现，不启动 Editor。
package.path = 'Lua/?.lua;' .. package.path
local config = require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local function copy(values)local result={};for k,v in pairs(values)do result[k]=v end;return result end
local cases={
    [801]={name='名册上多出来的人',npc=3,witness=2,topic='艾达的更正申请还在吗',plain='先把应退的钱',skilled='[智力 8]',endings={'按实情更正','暂时保留登记','把孩子的救济另外申请，艾达领过的那份申请免退。两张一起交。'},cue='孤僻',trait=6},
    [802]={name='半枚铜扣',npc=6,witness=4,topic='失守那晚，你见过',plain='你愿意把这些话',skilled='[侦察 4]',endings={'保留逃兵登记','提交复核','先把遗物还给岑姨。她听过证词以后，再决定要不要申请重查。'},cue='老练',trait=1,history='battle'},
    [803]={name='少一个人的工钱',npc=4,witness=3,topic='炉边第七个人',plain='用这页饭账',skilled='[巧匠 4]',endings={'用艾达的真名','让工人一起核对工日。你拿自己的那份钱作担保。','先按莎娜'},cue='傲慢',trait=3},
    [804]={name='一封写得太好的情书',npc=2,witness=5,topic='两封信都写了“湖”，怎么还错得一模一样？',plain='他们花钱请你代写，可信里的话也都是你编的。',skilled='[魅力 5]',endings={'分别说明代写','约他们和阿苇','告诉他们，这些信都是阿苇写的。以后署她的名字，问他们还愿不愿意收。'},cue='孤僻',trait=6},
    [805]={name='谁家的好狗',npc=5,witness=6,topic='卫队要把巴豆',plain='它已经在孩子家住下了。你想领走，总得先跟孩子说清楚。',skilled='[动物亲和 4]',endings={'留在孩子家','让卫队接走','白天借给城内巡查，天黑前送回酒馆。'},cue='坚韧',trait=2,animal=3},
    [806]={name='关卡下的路费',npc=6,witness=2,topic='修桥费交给谁',plain='把六次的日期',skilled='[智力 8]',endings={'我出三十枚','两名废墟掠夺者已经','把六次没派人护送的事一起上报，交班时也得留人巡查。'},cue='老练',trait=1,history='battle'},
    [807]={name='门后的床',npc=3,witness=4,topic='那间房，到底',plain='把房租和开门',skilled='[巧匠 4]',endings={'先加折屏','大家签个约定：下工以后房间归住户，有火情时让人通行，房租减半。','互助会先腾'},cue='傲慢',trait=3},
    [808]={name='多摆一只碗',npc=5,witness=2,topic='岑姨想请谁',plain='我把原话带回去',skilled='[厨艺 3]',endings={'留一小碗纪念','问问岑姨愿不愿意请大家一起吃，每个人带一道自己爱吃的菜。','把碗送还她'},cue='曾接受同伴援手',history='relationship'},
    [809]={name='一首不准唱完的歌',npc=2,witness=5,topic='歌里偷靴子',plain='把各家唱的都留下',skilled='[智力 8]',endings={'附上赫铎的证词','印各家的版本','先印前三段'},cue='傲慢',trait=3},
    [810]={name='明天开门的人',npc=4,witness=6,topic='赫铎走后',plain='开门、记账、夜间报信，分别写清楚由谁负责。',skilled='[魅力 5]',endings={'请工人推举','请艾达和一名老工人','先交给老工头暂管，留够押金，欠哪些钱也写清楚。你回来后再商量。'},cue='同袍之谊',trait=5,history='relationship'},
}
local function fixture(high,startingCoins)
    local data={Revision=0,Minutes=600,DialogueOpen=false,DialogueVersion=0,values={},progress={},kills={},lines={}}
    function data:GetValue(key)return self.values[key] or 0 end
    function data:SetValue(key,value)if self:GetValue(key)~=value then self.values[key]=value;self.Revision=self.Revision+1 end end
    function data:Status(kind,id)local p=self.progress[kind..':'..id];return p and p.state or 'inactive' end
    function data:Begin(kind,id)assert(self:Status(kind,id)=='inactive');self.progress[kind..':'..id]={state='active',baseline=copy(self.kills)};self.Revision=self.Revision+1 end
    function data:Ready(kind,id)assert(self:Status(kind,id)=='active');self.progress[kind..':'..id].state='ready';self.Revision=self.Revision+1 end
    function data:Complete(kind,id)assert(self:Status(kind,id)=='ready');self.progress[kind..':'..id].state='completed';self.Revision=self.Revision+1 end
    function data:RecordKill(id)self.kills[id]=(self.kills[id] or 0)+1;self.Revision=self.Revision+1 end
    function data:KillCount(kind,id,target)local p=assert(self.progress[kind..':'..id]);return (self.kills[target] or 0)-(p.baseline[target] or 0) end
    function data:BeginDialogue(id,npc)assert(not self.DialogueOpen);self.interjections={};self.DialogueOpen=true;self.DialogueId=id;self.DialogueNpcId=npc;self.DialogueVersion=self.DialogueVersion+1 end
    function data:EnterDialogueNode(id)self.DialogueNodeId=id;self.DialogueVersion=self.DialogueVersion+1 end
    function data:AddDialogueLine()end
    function data:HasDialogueInterjection(id)return self.interjections[id]==true end
    function data:AddCompanionLine(id,actor,name,cue,text)self.lines[#self.lines+1]={id=id,actor=actor,text=text} end
    function data:CompleteDialogueInterjection(id)self.interjections[id]=true;self.DialogueVersion=self.DialogueVersion+1 end
    function data:CloseDialogue()self.DialogueOpen=false;self.DialogueVersion=self.DialogueVersion+1 end
    local actors={}
    for id=1,3 do
        local growth={Initialized=true,Experience=0,Level=1,AttributePoints=0,TalentPoints=0,total=0}
        function growth:AddExperience(amount)self.Experience=self.Experience+amount;self.total=self.total+amount end
        function growth:AdvanceLevel(cost,attributes,talents)self.Experience=self.Experience-cost;self.Level=self.Level+1;self.AttributePoints=self.AttributePoints+attributes;self.TalentPoints=self.TalentPoints+talents end
        actors[id]={Id=id,TemplateId=id,HP=10,Growth=growth,attributes={},traits={}}
        actors[id].HasTrait=function(self,traitId)return self.traits[traitId]==true end
        if high then for _,a in ipairs(config:GetTable('GrowthAttributeTable'):All())do actors[id].attributes[a.code]=10 end end
    end
    local inventory={Revision=0,Grid={Count=0}}
    function inventory:CountItem()return 0 end
    local world={PartyCount=3,JournalCount=0,journal={},Phase='area',Equipment=inventory,Areas={Active={InteractionKind=2,InteractionId=1,GetMemberIdAt=function()return 1 end,Stop=function()end}}}
    function world:GetPartyAt(i)return actors[i+1] end
    function world:GetJournalAt(i)return self.journal[i+1] end
    local growth=require('Game.Progression.GrowthSystem')()
    growth.rules={maxLevel=10,levels=config:GetTable('GrowthLevelTable')};growth.chronicle={Record=function()end}
    local player={Coins=startingCoins==nil and 1000 or startingCoins}
    function player:TrySpendCoins(value)if self.Coins<value then return false end;self.Coins=self.Coins-value;return true end
    function player:AddCoins(value)self.Coins=self.Coins+value end
    local story=require('Game.Narrative.NarrativeSystem')()
    story.townMissions={Refresh=function()end};story.data=data
    story.rules=require('Game.Narrative.NarrativeRules').New(config)
    story.adventure={data=world,player=player,growth=growth,recipe={maxPartySize=4},areas={CloseInteraction=function()end},battle={stats={Get=function(_,actor,code)return actor.attributes[code] or 0 end}}}
    story.conditions=require('Game.Condition.ConditionSystem')()
    story.conditions:OnInit({systems={Get=function(_,name)assert(name=='Config');return config end}})
    require('Game.Narrative.NarrativeConditions')(story);story.conditions:OnStart()
    story.npcs={SyncPresence=function()end,ActorName=function(_,actor)return '队员'..actor.Id end}
    story.dialogue=require('Game.Narrative.Dialogue').New(story)
    for _,npc in ipairs(story.rules.npcs:All())do data:SetValue('relation:'..npc.id,npc.initialRelation)end
    for _,faction in ipairs(story.rules.factions:All())do data:SetValue('reputation:'..faction.id,faction.initialValue)end
    local f={story=story,data=data,actors=actors,world=world,player=player,high=high}
    function f:find(text)
        local found
        for _,visible in ipairs(story.dialogue:Choices())do
            local r=story.rules.choices:Get(visible.id)
            if r.text:find(text,1,true)then assert(not found,'Ambiguous: '..text);found=r end
        end
        return assert(found,'Missing choice: '..text)
    end
    function f:pick(text)
        local r=self:find(text);local version=data.DialogueVersion
        local ok,reason=story.dialogue:Choose(r.id,version);assert(ok,text..': '..tostring(reason))
        assert(not story.dialogue:Choose(r.id,version),'Old click must not replay actions');return r
    end
    function f:open(npc)
        if data.DialogueOpen then story.dialogue:Close() end
        assert(story.dialogue:Open(npc,1));if npc<201 then self:pick('镇上还有几件事。')end
    end
    function f:start(id)
        local c=cases[id];self:open(c.npc);self:pick('问问「'..c.name..'」');self:pick('我去问问。')
        assert(data:Status('mission',id)=='active');assert(data:Status('quest',id*10+1)=='completed')
    end
    function f:evidence(id)
        local c=cases[id];self:open(c.witness);self:pick(c.topic);self:pick(self.high and c.skilled or c.plain)
        assert(data:Status('quest',id*10+2)=='completed')
    end
    function f:menu(id)local c=cases[id];self:open(c.npc);self:pick('「'..c.name..'」，我想好了。')end
    function f:finish(id,ending)
        self:menu(id);local menu=data.DialogueNodeId;self:pick(cases[id].endings[ending])
        assert(data:Status('mission',id)=='completed','Unfinished mission '..id)
        assert(data:GetValue('flag:bt_'..id..'_end')==ending)
        for stage=1,3 do assert(data:Status('quest',id*10+stage)=='completed')end
        for _,cid in ipairs(story.rules.nodes:Get(menu).choiceIds)do
            local r=story.rules.choices:Get(cid)
            if #r.actionIds>0 then assert(not story.conditions:Check(r.conditionId,{}),'Resolved sibling remained selectable')end
        end
        local money,total=player.Coins,actors[1].Growth.total
        story:Refresh();assert(not story:Claim('mission',id))
        self:open(cases[id].npc);self:pick('「'..cases[id].name..'」后来怎么样了？');story:Refresh()
        assert(player.Coins==money and actors[1].Growth.total==total,'Revisit paid again')
    end
    function f:kill(count)for _=1,count do data:RecordKill(4)end;story:Refresh()end
    function f:complete(id,ending)
        self:start(id);self:evidence(id)
        if id==806 and ending==2 then self:menu(id);self:pick('我们出城');self:kill(2)end
        self:finish(id,ending)
    end
    function f:addHistory(kind,actorId)
        local e={Kind=kind,SubjectId=actorId,ObjectId=actorId,EventId=0}
        function e:Involves(id)return id==actorId end
        world.journal[#world.journal+1]=e;world.JournalCount=#world.journal
    end
    story:Refresh()
    for id=801,810 do assert(data:Status('mission',id)=='inactive','Must discover before accepting')end
    return f
end

-- 每个结局都从 NPC 入口走到奖励，前置任务也通过实际对话完成。
for id=801,810 do for ending=1,3 do
    local f=fixture(true)
    if id==803 and ending==1 then f:complete(801,1)end
    if id==809 and ending==1 then f:complete(802,3)end
    if id==810 then
        if ending==2 then f:complete(801,1);f:complete(803,1)
        else f:complete(803,2);f:complete(807,2)end
    end
    f:complete(id,ending)
end end

-- 零属性路线仍可完成十项，且两种顺序互不锁死。
for _,order in ipairs({{804,808,802,805,806,809,801,803,807,810},{807,803,801,809,806,805,802,808,804,810}})do
    local f=fixture(false)
    local endings={[801]=2,[802]=3,[803]=3,[804]=1,[805]=1,[806]=1,[807]=3,[808]=3,[809]=3,[810]=3}
    for _,id in ipairs(order)do f:complete(id,endings[id])end
    for _,a in ipairs(f.actors)do assert(a.Growth.total==450)end
end

-- 无金币时付费会原子拒绝；激活前的击败不计入出城阶段。
local combat=fixture(false,0)
combat:kill(20);combat:start(806);combat:evidence(806);combat:menu(806)
local paid=combat:find('我出三十枚');local ok=combat.story.dialogue:Choose(paid.id,combat.data.DialogueVersion)
assert(not ok and combat.player.Coins==0 and combat.data:GetValue('flag:bt_806_end')==0)
combat:pick('我们出城');assert(combat.data:KillCount('quest',8064,4)==0)
combat:kill(1);assert(combat.data:Status('quest',8064)=='active')
combat:kill(1);combat:finish(806,2)
-- 已接下出城阶段，也能回来改谈付费，不遗留活动阶段。
local changed=fixture(false);changed:start(806);changed:evidence(806);changed:menu(806);changed:pick('我们出城');changed:finish(806,1)
assert(changed.data:Status('quest',8064)=='completed')

-- 实际跨任务解锁：先议房门再改名，先共同核薪再分钥匙。
local linked=fixture(false)
linked:complete(803,2);linked:complete(807,2);linked:start(801);linked:evidence(801);linked:finish(801,3);linked:complete(810,1)
local dog=fixture(false);dog:complete(806,2);dog:complete(805,3)
local song=fixture(true);song:complete(809,2);song.high=false
for _,actor in ipairs(song.actors)do actor.attributes={}end
song:complete(807,2)
local supper=fixture(true);supper:complete(808,2);supper.high=false
for _,actor in ipairs(supper.actors)do actor.attributes={}end
supper:complete(804,2)

-- 十个主动插话均走真正候选选择和 NPC 接续，消耗一次；其中傲慢会损失好感。
for id=801,810 do
    local c=cases[id];local f=fixture(false)
    if id==810 then f:complete(803,3);f:complete(807,3)end
    f:start(id)
    if c.trait then f.actors[1].traits[c.trait]=true end
    if c.history then f:addHistory(c.history,1)end
    if c.animal then f.actors[1].attributes.animalAffinity=c.animal end
    f:open(c.witness);f:pick(c.topic)
    local picked
    for _,r in ipairs(f.story.dialogue:Interjections())do if r.cue:find(c.cue,1,true) and r.actorId==1 then picked=r;break end end
    assert(picked,'Missing interjection for '..id)
    local version=f.data.DialogueVersion
    assert(f.story.dialogue:Interject(picked.id,1,version))
    assert(not f.story.dialogue:Interject(picked.id,1,version))
    f:pick(id==807 and '这句话说得难听' or '我知道了。')
    assert(f.data:GetValue('flag:bt_'..id..'_evidence')==1)
    if id==807 then assert(f.data:GetValue('relation:4')==-3 and f.data:GetValue('flag:bt_807_offended')==1)end
end

-- 同人条件不能拼接两位队员的特质与经历，倒地者不能发言。
local split=fixture(false);split:start(802)
split.actors[1].traits[1]=true;split:addHistory('battle',2)
split:open(4);split:pick(cases[802].topic);assert(#split.story.dialogue:Interjections()==0)
split:addHistory('battle',1);assert(#split.story.dialogue:Interjections()==1)
split.actors[1].HP=0;assert(#split.story.dialogue:Interjections()==0)

-- 自动发言覆盖所有满足者；循环节点不重播，重开会话重新允许。
local auto=fixture(false);auto.actors[1].traits[3]=true;auto.actors[2].traits[3]=true
auto:open(3);auto:pick('问问「名册上多出来的人」');assert(#auto.data.lines==2)
auto:pick('先让我想想。');auto:pick('问问「名册上多出来的人」');assert(#auto.data.lines==2)
auto:open(3);auto:pick('问问「名册上多出来的人」');assert(#auto.data.lines==4)

-- 本批所有属性阈值的边界与实时存活检查。
local bounds=fixture(false)
for _,r in ipairs(config:GetTable('ConditionTable'):All())do if r.id>=8000 and r.kind=='party_attribute' then
    for _,a in ipairs(bounds.actors)do a.attributes={} end
    local code=config:GetTable('GrowthAttributeTable'):Get(r.targetId).code
    bounds.actors[1].attributes[code]=r.value-1;assert(not bounds.story.conditions:Check(r.id,{}))
    bounds.actors[1].attributes[code]=r.value;assert(bounds.story.conditions:Check(r.id,{}))
    bounds.actors[1].HP=0;assert(not bounds.story.conditions:Check(r.id,{}));bounds.actors[1].HP=10
end end

-- 新实例恢复已完成事实与进度以后，Refresh 不补发奖励。
local restored=fixture(false)
restored.data.values=copy(linked.data.values)
for key,p in pairs(linked.data.progress)do restored.data.progress[key]={state=p.state,baseline=copy(p.baseline)}end
restored.story:Refresh()
assert(restored.actors[1].Growth.total==0 and not restored.story:Claim('mission',810))
local recruits={
    [901]={npc=201,witness=6,topic='陶恩想补',plain='把空表交给我',skilled='[魅力 5]',offers={'退伍证明可以领','塞维恩答应单独听','洛岑的复核'},trait=1,profession=1,weapon=40,voiceTrait=1,voiceHistory='battle'},
    [902]={npc=202,witness=2,topic='莎芙交给驿站',plain='借给过谁',skilled='[侦察 4]',offers={'书记承认把地图借给了别人','原图和改过的图一起存档，你带一份副本跟我们走。','那几次漏防已经查清，把地图也交上去。以后的交班时间别再公开了。'},trait=6,profession=2,weapon=46,voiceTrait=6},
    [903]={npc=203,witness=4,topic='维珂的那批断件',plain='先把两批分开',skilled='[巧匠 4]',offers={'工坊退还铁料的钱，你把少做工序的那批重新做好。两边签字结清。','带上两块断件','工坊已经共同核过'},trait=3,profession=4,weapon=40,voiceTrait=3},
    [904]={npc=204,witness=3,topic='米蕾署着老师名字',plain='留下的三瓶换标签，发出去的两瓶，照记录找到领药的人。',skilled='[智力 8]',offers={'把用过老师名字的事告诉他们。我们遇到伤病，你治不了就直接说。','药方、剂量','岑姨能选自己爱吃的菜，用药的人也该知道药是谁配的。把实情告诉他们吧。'},trait=2,profession=3,weapon=1,voiceTrait=2},
    [905]={npc=205,witness=5,topic='奥林究竟走过',plain='说说他送老人回家的事，书上的就不用讲了。',skilled='[魅力 5]',offers={'先去酒馆说清楚','先走一天','旧歌上写了是谁抄的，你讲游记也该说清是哪本书里的。'},trait=5,profession=2,weapon=46,voiceTrait=5},
}
local equipmentRules=require('Game.Equipment.EquipmentRules').New(config)
local growthRules=require('Game.Progression.GrowthRules').New(config)
local function recruitingFixture(high)
    local f=fixture(high);local story,world,stats=f.story,f.world,f.story.adventure.battle.stats
    world.Seed=20261024
    function world:PrepareRecruitActor(id,template)
        local unit=config:GetTable('CombatUnitTable'):Get(template)
        local g={Initialized=false,CurrentProfessionId=0,Level=1,Experience=0,total=0,trees={},skills={}}
        function g:Initialize()assert(not self.Initialized);self.Initialized=true end
        function g:UnlockTree(tree)self.trees[tree]=true end
        function g:JoinProfession(profession)self.CurrentProfessionId=profession end
        function g:GrantSkill(skill)self.skills[skill]=true end
        function g:AddLearningOpportunity()end
        function g:AddExperience(amount)self.Experience=self.Experience+amount;self.total=self.total+amount end
        function g:AdvanceLevel(cost)self.Experience=self.Experience-cost;self.Level=self.Level+1 end
        local actor={Id=id,TemplateId=template,HP=1,Growth=g,attributes={},traits={}}
        for _,a in ipairs(config:GetTable('GrowthAttributeTable'):All())do actor.attributes[a.code]=unit[a.code] or 0 end
        for i,code in ipairs(unit.attributeNames)do actor.attributes[code]=unit.attributeValues[i]end
        function actor:HasTrait(t)return self.traits[t]==true end
        function actor:AddTrait(t)
            assert(not self.traits[t]);self.traits[t]=true
            local def=config:GetTable('CombatTraitTable'):Get(t);self.attributes[def.attribute]=self.attributes[def.attribute]+def.amount
        end
        function actor:SetMaxHP(value)self.MaxHP=value end
        function actor:Restore()self.HP=self.MaxHP end
        return actor
    end
    function world:AddPreparedRecruit(actor)f.actors[#f.actors+1]=actor;self.PartyCount=#f.actors end
    function stats:MaximumHP(actor)return 18+config:GetTable('CombatUnitTable'):Get(actor.TemplateId).vitality*4 end
    function stats:Template(actor)return config:GetTable('CombatUnitTable'):Get(actor.TemplateId)end
    story.adventure.growth.rules=growthRules;story.adventure.growth.stats={units=config:GetTable('CombatUnitTable')};story.adventure.growth.data=world
    story.adventure.characterAppearances={Party=function()end}
    story.adventure.factions={ServiceAllowed=function()return not f.blockedTown,'据点封锁' end,NpcAvailable=function()return not f.recoveringTown end}
    local gear={next=0,weapons={},equipped={}}
    function gear:AddWeapon(item)self.next=self.next+1;local weapon={Id=self.next,ItemId=item};self.weapons[self.next]=weapon;return weapon end
    function gear:Equip(actor,weapon)self.equipped[actor]=assert(self.weapons[weapon]).ItemId;return true end
    local loadout=require('Game.Equipment.InitialLoadout').New(config,equipmentRules,function()return stats end)
    story.adventure.equipment={data=gear,initialLoadouts=loadout,CanGrant=function()return not f.fullBag end}
    local npcs=require('Game.Narrative.NpcSystem').New(story)
    for id=201,205 do npcs.locations[id]=11 end
    npcs.SyncPresence=function()end
    npcs.PrepareDeployment=function()if f.blockedDeployment then return nil,'附近没有站位' end;return {}end
    story.npcs=npcs;f.gear=gear
    function f:recruitStart(id)
        local c=recruits[id];self:open(c.npc);self:pick('谈谈跟我们同行');self:pick('我去问清楚')
        self:open(c.witness);self:pick(c.topic)
    end
    function f:recruitEvidence(id)self:recruitStart(id);self:pick(self.high and recruits[id].skilled or recruits[id].plain)end
    function f:offer(id,route)
        self:open(recruits[id].npc);self:pick('我们来谈同行');self:pick(recruits[id].offers[route])
        assert(self.data:Status('mission',id)=='ready')
        for stage=1,3 do assert(self.data:Status('quest',id*10+stage)=='completed')end
        assert(world.PartyCount==3,'An agreement must not auto-recruit')
    end
    function f:join(id)
        local c=recruits[id];self:open(c.npc);self:pick('行李收好了');self:pick('出发吧')
        assert(world.PartyCount==4 and self.data:Status('mission',id)=='completed')
        local actor=world:GetPartyAt(3)
        assert(actor.Id==10000+c.npc and actor.TemplateId==id and actor:HasTrait(c.trait))
        assert(actor.Growth.CurrentProfessionId==c.profession and actor.Growth.skills[400+c.profession])
        assert(self.gear.equipped[actor.Id]==c.weapon and self.gear.next==1)
        assert(self.data:GetValue('recruited:'..c.npc)==actor.Id)
        local xp=self.actors[1].Growth.total;story:Refresh()
        assert(not story:Claim('mission',id) and world.PartyCount==4 and self.gear.next==1 and self.actors[1].Growth.total==xp)
    end
    return f
end
-- 五名角色各三条路线，使用真实 NPC 招募、成长初始化和装备应用。
for id=901,905 do for route=1,3 do
    local f=recruitingFixture(route~=1)
    if route==3 then
        if id==901 then f:complete(802,2)
        elseif id==902 then f:complete(806,3)
        elseif id==903 then f:complete(803,2)
        elseif id==904 then f:complete(808,1)
        else f:complete(809,2)end
    end
    f:recruitEvidence(id);f:offer(id,route)
    local xp=f.actors[1].Growth.total
    -- 满员、满包、封锁、尚未回归及站位不足都不得发奖或吞任务。
    for _,failure in ipairs({'fullParty','fullBag','blockedTown','recoveringTown','blockedDeployment'})do
        if failure=='fullParty' then f.story.adventure.recipe.maxPartySize=3 else f[failure]=true end
        local ok,reason=f.story:Claim('mission',id)
        assert(not ok and reason and f.data:Status('mission',id)=='ready' and f.world.PartyCount==3 and f.gear.next==0 and f.actors[1].Growth.total==xp)
        if failure=='fullParty' then f.story.adventure.recipe.maxPartySize=4 else f[failure]=false end
    end
    f:join(id)
end end
-- 每条招募任务都有能够接续 NPC 回答的特质路线。
for id=901,905 do
    local c=recruits[id];local f=recruitingFixture(false)
    f.actors[1].traits[c.voiceTrait]=true;if c.voiceHistory then f:addHistory(c.voiceHistory,1)end
    f:recruitStart(id)
    local candidates=f.story.dialogue:Interjections();assert(#candidates==1)
    assert(f.story.dialogue:Interject(candidates[1].id,1,f.data.DialogueVersion));f:pick('把这些话带回去')
    f:offer(id,2);f:join(id)
end

-- 实际城镇生成：十一位剧情 NPC 的出生格和全天停留格都可达。
local town=fixture(false)
local generator=require('Game.MapArea.MapAreaGenerator')(config)
generator:Register(2,require('Game.MapArea.TownGenerator'),'MapAreaTownTable','MapAreaTownThemeTable')
local npcs=require('Game.Narrative.NpcSystem').New(town.story);local site={id=11,areaConfigId=2};npcs:BindWorld({site})
for _,seed in ipairs({20260924,20261016})do
    local area=generator:Generate(2,seed,site.id,{regionId=7,regionType=5,regionConfigId=5,q=0,r=0,height=1,biomeWeights={{regionType=5,weight=1}}},function(layout)npcs:Populate(layout,site)end)
    local occupied,count={},0
    for _,npc in ipairs(area.npcs)do
        assert(not occupied[npc.spawnIndex]);occupied[npc.spawnIndex]=true
        if npc.narrativeId then
            count=count+1;assert(area:FindPath(area.entryIndex,npc.spawnIndex))
            for _,target in pairs(npc.scheduleTargets)do assert(area:FindPath(npc.spawnIndex,target))end
        end
    end
    assert(count==11,'All original and recruit NPCs must be reachable')
end
print('PASS border town: 30 side endings; 2 full zero-attribute routes; cross-quest unlocks; no-coin combat and kill baseline; 15 recruit routes plus 5 trait routes; real recruitment/growth/loadout; full party/bag/blocked town/deployment retention; 11 NPC placements; no duplicate rewards')
