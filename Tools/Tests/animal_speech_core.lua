-- Real exported configuration, animal rules, combat attributes and dialogue commands.
-- Only mutable C# actor/session data and deterministic random draws are isolated here.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local bridge={}
function bridge.Pending(animal)return animal.speechPending==true end
function bridge.Modifier(animal)return animal.speechModifier or 0 end
function bridge.Resolve(animal,modifier)
    assert(animal.AnimalSpeciesId>0 and animal.AnimalOwnerId==0 and animal.HP>0 and not bridge.Pending(animal))
    animal.speechPending=true;animal.speechModifier=modifier
end
function bridge.Consume(animal)
    local value=bridge.Modifier(animal);animal.speechPending=false;animal.speechModifier=0
    animal.consumed=(animal.consumed or 0)+1;return value
end
function bridge.Target(data)return data.target end
function bridge.Context(data)return data.context end
function bridge.PartyId(data)return data.partyId or 0 end
function bridge.Understood(data)return data.understood==true end
function bridge.Touch(data)data.DialogueVersion=data.DialogueVersion+1 end
CS={ProjectY={Data={AnimalSpeechState=bridge,AnimalCompanionState={Bound=function(actor)return actor.MountedAnimal end},BodyHealth={
    Revision=function()return 0 end,MaximumHP=function()return 10 end,HP=function()return 10 end,
    Damage=function()return 0 end,Permanent=function()return false end}}}}
local stats=require('Game.Battle.CombatStats')(config)
local animals=stats.animals
local rules=require('Game.Animals.AnimalSpeechRules').New(config)
local EmptyGrowth=assert(loadfile('Tools/Tests/growth_empty.lua'))()
local function actor(id,template,affinity,charisma)
    local data={Id=id,TemplateId=template or 1,HP=40,MaxHP=40,Team=1,TraitCount=0,Effects={Count=0,Find=function()return nil end},Growth=EmptyGrowth(),
        HasInitialAttributes=true,initial={animalAffinity=affinity or 0,charisma=charisma or 0},AnimalOwnerId=0,TameRetryTurns=0}
    function data:GetInitialAttribute(name)return self.initial[name] or 0 end
    function data:RollAnimalPercent()self.rolls=(self.rolls or 0)+1;return assert(self.nextRoll)end
    function data:DelayTaming(turns)self.TameRetryTurns=turns end
    function data:AdvanceTamingRound()self.TameRetryTurns=math.max(0,self.TameRetryTurns-1)end
    function data:TameAndRide(target,bond)
        assert(not self.MountedAnimal and target.AnimalOwnerId==0)
        self.MountedAnimal=target;target.AnimalOwnerId=self.Id;target.AnimalBond=bond;target.Team=1;target.TameRetryTurns=0
    end
    return data
end
local function animal(id,template,team)
    local data=actor(id,template);data.AnimalSpeciesId=assert(animals.byUnit[template]).id;data.Team=team or 0;return data
end
local hero,other=actor(1,1,5,3),actor(2,1,5,3)
local expected={{76,56,56,36},{76,46,56,26},{56,46,36,26}}
for index,row in ipairs(rules.approaches:All())do
    assert(rules:Chance(hero,stats,row,false,false)==expected[index][1])
    assert(rules:Chance(hero,stats,row,true,false)==expected[index][2])
    assert(rules:Chance(hero,stats,row,false,true)==expected[index][3])
    assert(rules:Chance(hero,stats,row,true,true)==expected[index][4])
end
assert(rules:Chance(actor(3,1,1000,1000),stats,rules.approaches:Get(1),false,false)==95)
assert(rules:Chance(actor(4),stats,rules.approaches:Get(3),true,true)==5)
print('PASS three conversation approaches, friendly/hostile attitudes, legendary penalty and clamps')

local horse=animal(21,201)
assert(animals:TameChance(hero,horse,stats)==43)
bridge.Resolve(horse,15)
local chance,values=animals:TameChance(hero,horse,stats)
assert(math.abs(chance-67.51)<1e-9 and values.communication==0 and values.baseChance==43 and values.advantageSources[1]=='animal_speech')
assert(math.abs(animals:TameChance(other,horse,stats)-67.51)<1e-9,'A different teammate must see the same pending result')
assert(bridge.Pending(horse),'Probability previews must not consume the result')
horse.nextRoll=5800
local success,failedChance,_,_,check=animals:Tame(other,horse,stats)
assert(not success and math.abs(failedChance-67.51)<1e-9 and horse.TameRetryTurns==3 and horse.consumed==1)
assert(check and #check.rolls==2 and horse.rolls==2 and check.selectedIndex==1,'Advantage draws twice and ties keep the first result')
assert(not bridge.Pending(horse) and animals:TameChance(hero,horse,stats)==43,'A failed attempt must consume the modifier exactly once')
assert(not animals:CanTame(hero,horse) and not animals:CanTame(other,horse),'Retry delay belongs to the animal and blocks the whole party')
for _=1,3 do horse:AdvanceTamingRound()end
assert(animals:CanTame(hero,horse))
bridge.Resolve(horse,-25);assert(animals:TameChance(hero,horse,stats)==18)
horse.nextRoll=1799
assert(animals:Tame(hero,horse,stats))
assert(hero.MountedAnimal==horse and not bridge.Pending(horse) and horse.consumed==2,'Success consumes the result and keeps the same animal instance')
local clamped=animal(22,201)
bridge.Resolve(clamped,-100);assert(animals:TameChance(actor(5),clamped,stats)==5)
bridge.Consume(clamped);bridge.Resolve(clamped,100)
assert(animals:TameChance(actor(6,1,1000,1000),clamped,stats)==99.75)
print('PASS shared one-use taming advantage, negative outcomes, exclusive roll boundary, retry delay and ownership')

local skill=config:GetTable('CombatSkillTable'):Get(rules.rule.skillId)
assert(skill.id==206 and skill.skillGroup=='animal_speech' and skill.catalystKind=='arcane' and skill.target=='any')
local contexts={};for _,name in ipairs(skill.contexts)do contexts[name]=true end
assert(contexts.life and contexts.battle and skill.action=='secondary' and skill.cost==1 and skill.range==3)
assert(#skill.effectIds==0 and config:GetTable('SkillDescriptionTable'):Get(skill.id).body~='')
local learned={};for _,row in ipairs(config:GetTable('ProfessionSkillTable'):All())do if row.skillId==skill.id then learned[row.professionId]=true end end
assert(learned[2] and learned[3] and learned[11],'Ranger, mage and beastmaster must all offer the spell')
local atlas=config:GetTable('SkillAtlasTable'):Get(skill.id)
assert(atlas.categoryId==21 and atlas.relatedCategoryIds[1]==51)
local pooled=false;for _,row in ipairs(config:GetTable('ActiveSkillPoolTable'):All())do
    if row.skillId==skill.id then assert(config:GetTable('GrowthAttributeTable'):Get(row.attributeId).code=='animalAffinity');pooled=true end
end
assert(pooled)
for _,unitId in ipairs({701,702,703,704})do
    local species=assert(animals.byUnit[unitId]);local body=assert(animals.bodies[unitId])
    assert(species.rideable and species.moveRange==config:GetTable('CombatUnitTable'):Get(unitId).moveRange)
    assert(#species.footprintQ==#body.footprintQ)
    for i,q in ipairs(body.footprintQ)do assert(species.footprintQ[i]==q and species.footprintR[i]==body.footprintR[i])end
end
print('PASS spell learning, tooltip, atlas, discovery pool and four legendary riding profiles')

local Speech=require('Game.Animals.AnimalSpeech')
local Dialogue=require('Game.Narrative.Dialogue')
local battle=require('Game.Battle.BattleSystem')()
local caster,target=actor(11,1,5,3),animal(31,701,2)
battle.stats=stats
battle.data={Winner='',ActiveId=caster.Id,UnitCount=2,units={caster,target},GetUnitAt=function(self,i)return self.units[i+1]end}
local adventure={config=config,battle=battle,data={Phase='battle',PartyCount=1,GetPartyAt=function()return caster end}}
adventure.parties={adventure=adventure,definitions=config:GetTable('WorldPartyTable')}
adventure.parties.legends=require('Game.Adventure.LegendaryEncounters').New(adventure.parties)
adventure.characterSkills=require('Game.Adventure.CharacterSkills').New(adventure)
local Signal=require('Core.Signal');adventure.events={CheckResolved=Signal()}
local data={DialogueOpen=true,DialogueVersion=1,DialogueActorId=caster.Id,target=target,context='battle',understood=true,lines={}}
function data:AddDialogueLine(speaker,text,player)self.lines[#self.lines+1]={speaker=speaker,text=text,player=player}end
local story={adventure=adventure,data=data,rules={settings={playerSpeaker='player'}}}
story.dialogue=Dialogue.New(story);adventure.animalSpeech=Speech.New(story)
local speech=adventure.animalSpeech;local checks={}
adventure.events.CheckResolved:Subscribe(function(check)checks[#checks+1]=check end)
target.nextRoll=3599
assert(speech:Choose(-1001,data.DialogueVersion))
assert(bridge.Modifier(target)==15 and target.rolls==1 and #checks==1 and checks[1].passed)
assert(data.lines[#data.lines].text==require('Language').AnimalSpeechResultAdvantage)
local canDiscuss,pendingReason=speech:CanDiscuss()
assert(not canDiscuss and pendingReason==require('Language').AnimalSpeechPendingAdvantage)
assert(not speech:Choose(-1002,1),'A stale click must not draw another die')
assert(not speech:Choose(-1002,data.DialogueVersion),'Changing approach after the result must not draw another die')
assert(target.rolls==1 and #checks==1)
data.DialogueActorId=other.Id;battle.data.ActiveId=other.Id;battle.data.units[1]=other
adventure.data.GetPartyAt=function()return other end
assert(not speech:CanDiscuss(),'Changing the speaking teammate must not clear the target result')
data.understood=false
local ok,reason=story.dialogue:Choose(4000,data.DialogueVersion)
assert(not ok and reason==require('Language').AnimalSpeechNotUnderstood,'Untranslated animal dialogue must reject ordinary narrative choices')
assert(target.rolls==1 and #checks==1)
data.understood=true;data.DialogueActorId=caster.Id;battle.data.ActiveId=caster.Id;battle.data.units[1]=caster
adventure.data.GetPartyAt=function()return caster end
bridge.Consume(target);target.TameRetryTurns=3
assert(not speech:Choose(-1001,data.DialogueVersion),'Animal retry delay also prevents communication rerolls')
target.TameRetryTurns=0;target.nextRoll=3600
assert(speech:Choose(-1001,data.DialogueVersion))
assert(bridge.Modifier(target)==-10 and target.rolls==2 and #checks==2 and not checks[2].passed,'The exact percentile threshold must fail')
print('PASS real dialogue communication, stale/duplicate/teammate reroll rejection, untranslated narrative gating and dice metadata')

-- Map entry must use the caster's learned spell and the whole party's real companion identities.
function bridge.Bind(session,pet,partyId,context,understood)
    assert(session.DialogueOpen and not session.target)
    session.target=pet;session.partyId=partyId;session.context=context;session.understood=understood
    session.DialogueVersion=session.DialogueVersion+1
end
CS.ProjectY.Data.EquipmentAffixData={Of=function()return 1 end}
CS.ProjectY.Data.EquipmentConditionData={Of=function()return {Broken=false,Efficiency=1}end}
CS.ProjectY.Data.ProfessionCombatState={
    Mark=function(unit,key)return unit.marks and unit.marks[key] or 0 end,
    SetMark=function(unit,key,value)unit.marks=unit.marks or {};unit.marks[key]=value end}
local mage,ownerA,ownerB=actor(41,3),actor(42),actor(43)
mage.Growth.SkillCount=1
function mage.Growth:GetSkillAt(index)assert(index==0);return 206 end
local wolf,beast=animal(51,702),animal(52,703)
ownerA:TameAndRide(wolf,0)
local mapBattle=require('Game.Battle.BattleSystem')()
mapBattle.stats=require('Game.Battle.CombatStats')(config)
mapBattle.skills=config:GetTable('CombatSkillTable');mapBattle.effects=config:GetTable('CombatEffectTable')
local staff={Id=1,ItemId=mapBattle.stats.equipment:TemplateLoadout(3),GetRune=function()return 0 end}
local inventory={WearableCount=0,catalyst=staff}
function inventory:Equipped(id)return id==mage.Id and self.catalyst or nil end
function inventory:Offhand()return nil end
function inventory:Worn()return nil end
mapBattle.stats.equipment.data=inventory
mapBattle.professions=require('Game.Battle.ProfessionCombat').New(config,mapBattle)
mapBattle.beasts=require('Game.Battle.ProfessionBeasts').New(config,mapBattle)
mapBattle.legendary=require('Game.Battle.LegendaryEquipment').New(config,mapBattle)
local mapData={Phase='map',PartyCount=3,actors={mage,ownerA,ownerB}}
function mapData:GetPartyAt(index)return assert(self.actors[index+1])end
local mapAdventure={config=config,battle=mapBattle,data=mapData,player={Coins=0},events={CheckResolved=Signal()},travel={data={}}}
function mapAdventure.travel.data:SetPaused(value)self.Paused=value end
mapAdventure.parties={adventure=mapAdventure,definitions=config:GetTable('WorldPartyTable')}
mapAdventure.parties.legends=require('Game.Adventure.LegendaryEncounters').New(mapAdventure.parties)
mapAdventure.characterSkills=require('Game.Adventure.CharacterSkills').New(mapAdventure)
local session={DialogueOpen=false,DialogueVersion=0,Minutes=600,lines={},values={},progress={}}
function session:BeginDialogue(id,npcId,localId,actorId)
    assert(not self.DialogueOpen);self.DialogueOpen=true;self.DialogueId=id;self.DialogueNpcId=npcId
    self.DialogueLocalNpcId=localId;self.DialogueActorId=actorId;self.DialogueVersion=self.DialogueVersion+1
end
function session:EnterDialogueNode(id)self.DialogueNodeId=id;self.DialogueVersion=self.DialogueVersion+1 end
function session:AddDialogueLine(speaker,text,player)self.lines[#self.lines+1]={speaker=speaker,text=text,player=player}end
function session:CloseDialogue()
    self.DialogueOpen=false;self.DialogueVersion=self.DialogueVersion+1;self.target=nil;self.context=nil;self.partyId=0;self.understood=false
end
function session:GetValue(key)return self.values[key] or 0 end
function session:Status(kind,id)return self.progress[kind..':'..id] or 'inactive' end
local mapStory={adventure=mapAdventure,data=session,rules=require('Game.Narrative.NarrativeRules').New(config)}
mapStory.conditions=require('Game.Condition.ConditionSystem')()
mapStory.conditions:OnInit({systems={Get=function(_,name)assert(name=='Config');return config end}})
require('Game.Narrative.NarrativeConditions')(mapStory);mapStory.conditions:OnStart()
mapStory.dialogue=Dialogue.New(mapStory);mapAdventure.animalSpeech=Speech.New(mapStory)
local mapSpeech=mapAdventure.animalSpeech;local mapChecks=0
mapAdventure.events.CheckResolved:Subscribe(function()mapChecks=mapChecks+1 end)
local function mapSpellRow()
    for _,row in ipairs(mapAdventure.characterSkills:Rows(mage.Id,'life'))do if row.id==206 then return row end end
    error('Learned animal speech is missing from map skills')
end
assert(not mage.MountedAnimal and ownerA.MountedAnimal==wolf)
assert(mapSpellRow().available and mapSpellRow().target=='self','A mage without a personal mount must be able to speak to a teammate\'s companion from the map')
assert(not mapAdventure.characterSkills:CanUse(ownerA.Id,206,ownerA.Id),'Ownership does not bypass the spell learning gate')
inventory.catalyst=nil
assert(not mapAdventure.characterSkills:CanUse(mage.Id,206,mage.Id),'Map companion speech still requires the caster\'s arcane catalyst')
inventory.catalyst=staff
assert(mapAdventure.characterSkills:Use(mage.Id,206,mage.Id))
assert(session.target==wolf and session.DialogueActorId==mage.Id and session.DialogueNpcId==102 and mapSpeech:HasStory())
local originalAvailable=false
for _,row in ipairs(mapStory.dialogue:Choices())do
    if row.id>0 and row.available then originalAvailable=true end
    assert(row.id~=-1001 and row.id~=-1002 and row.id~=-1003,'Bound companions cannot produce another taming modifier')
end
assert(originalAvailable,'A single companion opens its original narrative choices immediately')
local reportAllowed,reportReason=mapStory.dialogue:Choose(4037,session.DialogueVersion)
assert(not reportAllowed and reportReason~=require('Language').AnimalSpeechNotUnderstood and session:Status('mission',701)=='inactive',
    'Understanding an owned legendary animal must not bypass the original quest report condition')
assert(mapStory.dialogue:Close())

ownerB:TameAndRide(beast,0)
assert(mapAdventure.characterSkills:Use(mage.Id,206,mage.Id))
assert(session.target==wolf and not mapSpeech:HasStory(),'Several companions must first open the target selector')
local companionChoices={}
for _,row in ipairs(mapStory.dialogue:Choices())do
    assert(row.id<0,'No original story branch is available before selecting a companion')
    companionChoices[row.id]=true
end
assert(companionChoices[-300000000-ownerA.Id] and companionChoices[-300000000-ownerB.Id])
local locked,lockedReason=mapStory.dialogue:Choose(4037,session.DialogueVersion)
assert(not locked and lockedReason==require('Language').AnimalSpeechNotUnderstood)
local selectedId,selectorVersion=-300000000-ownerB.Id,session.DialogueVersion
mage.Growth.SkillCount=0
assert(not mapStory.dialogue:Choose(selectedId,selectorVersion),'The selected caster must still know the spell when the companion choice commits')
assert(session.target==wolf and not mapSpeech:HasStory())
mage.Growth.SkillCount=1
assert(mapStory.dialogue:Choose(selectedId,selectorVersion))
assert(session.target==beast and session.DialogueActorId==mage.Id and session.DialogueNpcId==103 and mapSpeech:HasStory())
assert(not mapStory.dialogue:Choose(selectedId,selectorVersion),'A stale companion selection cannot reopen another session')
assert(not mapStory.dialogue:Choose(selectedId,session.DialogueVersion),'A committed companion selection is not a reroll choice')
local secondStory=false
for _,row in ipairs(mapStory.dialogue:Choices())do if row.id>0 and row.available then secondStory=true end end
assert(secondStory,'The selected companion keeps its own original narrative branches')
assert(mapChecks==0 and not wolf.rolls and not beast.rolls and not bridge.Pending(wolf) and not bridge.Pending(beast),
    'Selecting or reopening owned companions must not draw dice or create another taming modifier')
assert(mapStory.dialogue:Close())
assert(mapAdventure.characterSkills:Use(mage.Id,206,mage.Id))
assert(mapStory.dialogue:Choose(-300000000-ownerA.Id,session.DialogueVersion))
assert(session.target==wolf and session.DialogueNpcId==102 and mapChecks==0 and not wolf.rolls and not beast.rolls)
print('PASS map companion speech across different caster/owner, single and multiple targets, original story gates and no reroll')
