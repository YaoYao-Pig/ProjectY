-- 离线运行真实叙事流转、条件、对话、奖励与导出配置；仅替代 C# 状态容器和世界表现。
package.path = 'Lua/?.lua;' .. package.path
local config = require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local Rules=require('Game.Narrative.NarrativeRules')
local Actions=require('Game.Narrative.NarrativeActions')
local speechState={}
function speechState.Target(data)return data.speechAnimal end
function speechState.Context(data)return data.speechContext end
function speechState.PartyId(data)return data.speechParty or 0 end
function speechState.Understood(data)return data.speechUnderstood==true end
function speechState.Bind(data,animal,party,context,understood)
    assert(data.DialogueOpen and not data.speechAnimal)
    data.speechAnimal=animal;data.speechParty=party;data.speechContext=context;data.speechUnderstood=understood
    data.DialogueVersion=data.DialogueVersion+1
end
function speechState.Understand(data,actorId)
    assert(data.DialogueOpen and data.speechAnimal and not data.speechUnderstood)
    data.speechUnderstood=true;data.DialogueActorId=actorId;data.DialogueVersion=data.DialogueVersion+1
end
function speechState.Pending(animal)return animal.speechPending==true end
function speechState.Modifier(animal)return animal.speechModifier or 0 end
CS={ProjectY={Data={AnimalSpeechState=speechState,AnimalCompanionState={Bound=function(actor)return actor.MountedAnimal end},BodyHealth={
    Revision=function()return 0 end,MaximumHP=function()return 10 end,HP=function()return 10 end,
    Damage=function()return 0 end,Permanent=function()return false end}}}}
CS.ProjectY.Data.EquipmentAffixData={Of=function()return 1 end}
CS.ProjectY.Data.EquipmentConditionData={Of=function()return {Broken=false,Efficiency=1}end}
CS.ProjectY.Data.ProfessionCombatState={
    Mark=function(actor,key)return actor.marks and actor.marks[key] or 0 end,
    SetMark=function(actor,key,value)actor.marks=actor.marks or {};actor.marks[key]=value end}
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
    function data:BeginDialogue(id,npc)local old=self.DialogueOpen;assert(not old);self.DialogueOpen=true;self.DialogueId=id;self.DialogueNpcId=npc;self.DialogueVersion=self.DialogueVersion+1 end
    function data:EnterDialogueNode(id)self.DialogueNodeId=id;self.DialogueVersion=self.DialogueVersion+1 end
    function data:AddDialogueLine()end
    function data:CloseDialogue()self.DialogueOpen=false;self.DialogueVersion=self.DialogueVersion+1;self.speechAnimal=nil;self.speechParty=nil;self.speechContext=nil;self.speechUnderstood=false end
    local actors={}
    for id=1,3 do
        local growth={Initialized=true,Experience=0,Level=1,AttributePoints=0,TalentPoints=0,opportunities=0,total=0}
        function growth:AddExperience(amount)self.Experience=self.Experience+amount;self.total=self.total+amount end
        function growth:AdvanceLevel(cost,attributes,talents,learn)self.Experience=self.Experience-cost;self.Level=self.Level+1;self.AttributePoints=self.AttributePoints+attributes;self.TalentPoints=self.TalentPoints+talents;if learn then self.opportunities=self.opportunities+1 end end
        growth.TalentCount=0;growth.SkillCount=id==3 and 1 or 0
        function growth:GetAttribute()return 0 end
        function growth:GetSkillAt(index)assert(index==0);return 206 end
        actors[id]={Id=id,TemplateId=id,Team=1,HP=10,Growth=growth,attributes={},HasInitialAttributes=true,TraitCount=0,Effects={Count=0}}
        actors[id].GetInitialAttribute=function(self,name)return self.attributes[name] or 0 end
    end
    local inventory={Revision=0,Grid={Count=0},items={}}
    function inventory:CountItem(id)return self.items[id] or 0 end
    local world={PartyCount=#actors,Phase='area',Equipment=inventory,Areas={Active={InteractionKind=2,InteractionId=1,GetMemberIdAt=function()return 1 end,Stop=function()end}}}
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
    story:Refresh();assert(data:Status('mission',300)=='active' and data:Status('mission',400)=='active' and data:Status('mission',500)=='inactive')
    return f
end
local function worldFixture()
    local f=fixture();local story,data=f.story,f.data;local adventure=story.adventure
    adventure.config=config;adventure.narrative=story;adventure.data.Phase='map'
    local battle=require('Game.Battle.BattleSystem')()
    battle.stats=require('Game.Battle.CombatStats')(config)
    battle.skills=config:GetTable('CombatSkillTable');battle.effects=config:GetTable('CombatEffectTable')
    local catalyst={Id=1,ItemId=battle.stats.equipment:TemplateLoadout(3),GetRune=function()return 0 end}
    f.inventory.WearableCount=0
    function f.inventory:Equipped(actorId)return actorId==3 and catalyst or nil end
    function f.inventory:Offhand()return nil end
    function f.inventory:Worn()return nil end
    battle.stats.equipment.data=f.inventory
    battle.professions=require('Game.Battle.ProfessionCombat').New(config,battle)
    battle.beasts=require('Game.Battle.ProfessionBeasts').New(config,battle)
    battle.legendary=require('Game.Battle.LegendaryEquipment').New(config,battle)
    adventure.battle=battle
    adventure.characterSkills=require('Game.Adventure.CharacterSkills').New(adventure)
    adventure.events={LivingParty=function()return f.actors end}
    adventure.travel={data={SetPaused=function(_,value)f.paused=value end}}
    local parties=setmetatable({adventure=adventure,definitions=config:GetTable('WorldPartyTable'),rule=config:GetTable('WorldPartyRuleTable'):Get(1)},require('Game.Adventure.WorldParties'))
    local world={Count=0,Clock=data.Minutes,rows={},TargetId=0,IsOpen=false,ContactId=0}
    function world:GetAt(i)return assert(self.rows[i+1])end
    function world:Find(id)for _,party in ipairs(self.rows)do if party.Id==id then return party end end end
    function world:Target(id)self.TargetId=id end
    function world:Open(id)assert(not self.IsOpen);self.ContactId=id;self.TargetId=0;self.IsOpen=true end
    function world:Close()self.IsOpen=false;self.ContactId=0 end
    function world:ReleaseParty(id,defeated,safe)local party=assert(self:Find(id));party.Defeated=defeated;party.SafeUntil=safe end
    for _,legend in ipairs(config:GetTable('LegendaryEncounterTable'):All())do
        local template=config:GetTable('NpcTable'):Get(legend.npcId).actorTemplateId
        local species=battle.stats.animals.byUnit[template]
        local member={Id=2000+legend.id,TemplateId=template,HP=100,MaxHP=100,Team=2,AnimalOwnerId=0,TameRetryTurns=0,AnimalSpeciesId=species and species.id or 0}
        world.rows[#world.rows+1]={Id=1000+legend.id,DefinitionId=legend.id,FactionId=legend.id,Defeated=false,BattleSiteId=0,SafeUntil=0,Role='wildlife',Travel={Q=20,R=0},MemberCount=1,GetMemberAt=function(_,index)assert(index==0);return member end}
    end
    world.Count=#world.rows;parties.data=world;adventure.parties=parties
    parties.Near=function(_,party)return f.nearId==party.Id end
    parties.legends=require('Game.Adventure.LegendaryEncounters').New(parties)
    adventure.animalSpeech=require('Game.Animals.AnimalSpeech').New(story)
    local factionRules=require('Game.Adventure.FactionRules').New(config)
    adventure.factions={Relation=function(_,a,b)return factionRules:Relation(a,b,nil,data:GetValue('reputation:'..b))end,
        data={FindConflict=function()end},conflicts={Attack=function(_,party)
            assert(not data.DialogueOpen,'Dialogue must close before battle');f.attacks=(f.attacks or 0)+1;world:Close();adventure.data.Phase='battle';return true
        end}}
    local begin=data.BeginDialogue
    function data:BeginDialogue(id,npc,localId,actor)begin(self,id,npc);self.DialogueLocalNpcId=localId;self.DialogueActorId=actor end
    function f:translate()
        assert(adventure.animalSpeech:Active() and not adventure.animalSpeech:HasStory())
        local ok,reason=story.dialogue:Choose(-100000000-self.actors[3].Id,data.DialogueVersion)
        assert(ok,tostring(reason));assert(adventure.animalSpeech:HasStory())
    end
    function f:open(definition,untranslated)
        self.nearId=1000+definition;world:Target(self.nearId)
        assert(parties:CheckContact() and data.DialogueOpen and not world.IsOpen and self.paused)
        if adventure.animalSpeech:Active() and not untranslated then self:translate()end
    end
    return f,parties
end
local f,p=worldFixture();f:open(11,true)
assert(not f.attacks,'Hostile legend must talk before fighting')
for _,row in ipairs(f.story.dialogue:Choices())do assert(row.id<0,'Untranslated animal dialogue cannot expose narrative choices')end
local ordinary=f.story.rules.nodes:Get(f.data.DialogueNodeId).choiceIds[1]
local allowed,reason=f.story.dialogue:Choose(ordinary,f.data.DialogueVersion)
assert(not allowed and reason==require('Language').AnimalSpeechNotUnderstood)
f:translate()
local recruits=require('Game.Narrative.NpcSystem').New(f.story)
local recruitOk,recruitError=pcall(recruits.PrepareRecruit,recruits,401)
assert(not recruitOk and tostring(recruitError):find('NPC cannot join the party',1,true),'Generic animal identity cannot use human recruitment')
local choices=f.story.dialogue:Choices();local locked
for _,row in ipairs(choices)do if row.text:find('[动物亲和',1,true)then locked=row end end
assert(locked and not locked.available)
local version=f.data.DialogueVersion;assert(not f.story.dialogue:Choose(locked.id,version));assert(f.story.adventure.player.Coins==1000)
f.story.dialogue:Close();assert(p.data:Find(1011).SafeUntil==f.data.Minutes+60)
assert(not p:CheckContact(),'Closing cannot immediately reopen the hostile encounter')
f:open(11);f:choose('支付 60');assert(f.data:GetValue('flag:legend_bloodmoon_resolved')==1)
assert(f.story.adventure.factions:Relation(0,11)=='allied' and f.story.adventure.player.Coins==940)
assert(f.story.adventure.factions:Relation(0,14)=='hostile','Peace with one legend cannot pacify another')
f.story.dialogue:Close();f:open(11)
for _,row in ipairs(f.story.dialogue:Choices())do assert(not row.text:find('支付',1,true),'Resolved branch must not take payment again')end
f.story.dialogue:Close();f:open(14);f:choose('拔出武器')
assert(f.attacks==1 and f.story.adventure.data.Phase=='battle' and not f.data.DialogueOpen)
print('PASS hostile first contact, locked negotiation, close grace, independent peace, one-time payment and explicit battle')

for _,route in ipairs({'peace','defeat'})do
    for _,spec in ipairs({{friend=12,target=11,mission=701,template=701},{friend=13,target=14,mission=702,template=704},{friend=16,target=15,mission=703,template=705}})do
        local run,parties=worldFixture();local story,data=run.story,run.data
        run:open(spec.friend);run:choose('听听你的委托');run:choose(spec.mission==701 and '我会找到' or spec.mission==702 and '我会去找' or '我会阻止')
        assert(data:Status('mission',spec.mission)=='active');story.dialogue:Close()
        if route=='peace' then
            for _,actor in ipairs(run.actors)do actor.attributes={animalAffinity=8,crafting=8,charisma=8}end
            run:open(spec.target);run:choose(spec.target==11 and '[动物亲和' or spec.target==14 and '[营造' or '[魅力');story.dialogue:Close()
        else
            parties.legends:RecordDefeat({TemplateId=spec.template});story:Refresh()
        end
        assert(data:Status('quest',spec.mission*10+1)=='completed' and data:Status('mission',spec.mission)=='active','Resolution requires returning to the publisher')
        run:open(spec.friend);run:choose('已经解决');assert(data:Status('mission',spec.mission)=='ready')
        local coins=story.adventure.player.Coins;run:choose('收下谢礼');assert(data:Status('mission',spec.mission)=='completed' and story.adventure.player.Coins>coins)
        coins=story.adventure.player.Coins;assert(not story:Claim('mission',spec.mission) and story.adventure.player.Coins==coins)
        story.dialogue:Close();run:open(spec.friend)
        for _,row in ipairs(story.dialogue:Choices())do assert(not row.text:find('领取',1,true) and not row.text:find('已经解决',1,true),'Completed dialogue must not regrant rewards')end
    end
end
print('PASS all three missions through peace and defeat, real return/report gates and one-time rewards')

f,p=worldFixture();p.legends:RecordDefeat({TemplateId=701});f:open(12);f:choose('听听你的委托');f:choose('我会找到')
assert(f.data:Status('quest',7011)=='completed','Defeat before acceptance must still satisfy this fixed legendary identity')
f.story.dialogue:Close()
local before=p.data.Count;p.data:Find(1011).Defeated=true
p:Spawn(true);assert(p.data.Count==before and p.data:Find(1011).Defeated,'Existing or defeated legends must never respawn during load')
package.loaded['UI.UIPanelCtrl']=require('Core.Class')('LegendaryPanelFixture')
local camera=require('UI.Panel.DialogueCtr')();camera.story=f.story;camera.camera={};f:open(12)
camera.demo={SetDialogueCamera=function()error('World dialogue cannot use a town camera target')end};camera:Camera()
print('PASS early resolution, defeated identity retention and map dialogue camera isolation')
for _,path in ipairs({'Lua/Game/Adventure/LegendaryEncounters.lua','Lua/Game/Adventure/WorldParties.lua','Lua/Game/Narrative/Dialogue.lua','Lua/UI/Panel/DialogueCtr.lua','Lua/UI/Panel/MissionJournalCtr.lua'})do assert(loadfile(path))end
config:OnShutdown()
