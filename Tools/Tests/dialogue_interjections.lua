-- Real exported rules and Condition graph; minimal stand-in for the C# session container.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local f=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local bytes=f:read('*a');f:close();return bytes
end}})
local actors={}
for i=1,3 do
    actors[i]={Id=i,TemplateId=i,HP=10,traits={}}
    actors[i].HasTrait=function(self,id)return self.traits[id]==true end
end
actors[1].traits[3]=true;actors[2].traits[3]=true;actors[3].traits[3]=true;actors[3].HP=0
local journal={}
local world={PartyCount=3,JournalCount=0,Phase='area',Areas={Active={InteractionKind=2,InteractionId=1,GetMemberIdAt=function()return 1 end,Stop=function()end}}}
function world:GetPartyAt(i)return actors[i+1] end
function world:GetJournalAt(i)return journal[i+1] end
local function record(kind,subject,object,participants,eventId)
    local row={Kind=kind,SubjectId=subject,ObjectId=object,EventId=eventId or 0}
    function row:Involves(id)for _,p in ipairs(participants)do if p==id then return true end end;return false end
    journal[#journal+1]=row;world.JournalCount=#journal
end
local data={DialogueOpen=false,DialogueVersion=0,lines={},used={},Revision=0}
function data:BeginDialogue(id,npc,localId,actor)
    self.DialogueOpen=true;self.DialogueId=id;self.DialogueNpcId=npc;self.DialogueActorId=actor;self.DialogueLocalNpcId=localId
    self.lines={};self.used={};self.DialogueVersion=self.DialogueVersion+1
end
function data:EnterDialogueNode(id)self.DialogueNodeId=id;self.DialogueVersion=self.DialogueVersion+1 end
function data:AddDialogueLine(speaker,text,choice)self.lines[#self.lines+1]={Speaker=speaker,Text=text,IsChoice=choice} end
function data:HasDialogueInterjection(id)return self.used[id]==true end
function data:AddCompanionLine(id,actor,speaker,cue,text)self.lines[#self.lines+1]={ActorId=actor,InterjectionId=id,Speaker=speaker,Cue=cue,Text=text} end
function data:CompleteDialogueInterjection(id)assert(not self.used[id]);self.used[id]=true;self.DialogueVersion=self.DialogueVersion+1 end
function data:CloseDialogue()self.DialogueOpen=false;self.lines={};self.used={};self.DialogueVersion=self.DialogueVersion+1 end
function data:GetValue()return 0 end
local story={data=data,rules=require('Game.Narrative.NarrativeRules').New(config)}
story.adventure={data=world,areas={CloseInteraction=function()end},battle={stats={Template=function(_,a)return {name='Actor '..a.Id}end,Get=function()return 4 end}}}
story.npcs={SyncPresence=function()end,ActorName=function(_,actor)if actor.Id==2 then return 'Recruited companion' end end}
story.conditions=require('Game.Condition.ConditionSystem')()
story.conditions:OnInit({systems={Get=function()return config end}})
require('Game.Narrative.NarrativeConditions')(story);story.conditions:OnStart()
story.dialogue=require('Game.Narrative.Dialogue').New(story)
assert(story.dialogue:Open(1,1))
assert(#data.lines==3 and data.lines[2].ActorId==1 and data.lines[3].ActorId==2,'All living eligible members speak in party order')
assert(data.lines[3].Speaker=='Recruited companion','Recruitment identity must take priority over combat template name')
story.dialogue:Enter(1);assert(#data.lines==4,'Loop must not repeat automatic speech')
assert(#story.dialogue:Interjections()==0,'Unqualified members must not appear')
record('battle',0,0,{2})
actors[1].traits[2]=true
assert(not story.conditions:Check(4041,{actor=actors[1]}),'Cannot borrow another actor history')
assert(not story.conditions:Check(4041,{actor=actors[2]}),'Cannot borrow another actor trait')
actors[2].traits[2]=true;assert(story.conditions:Check(4041,{actor=actors[2]}))
local list=story.dialogue:Interjections();assert(#list==1 and list[1].actorId==2)
record('battle',0,0,{1});list=story.dialogue:Interjections();assert(#list==2)
local version=data.DialogueVersion
assert(not story.dialogue:Interject(2,3,version),'Reject dead/nonmatching actor')
assert(not story.dialogue:Interject(2,999,version),'Reject nonparty actor')
assert(not story.dialogue:Interject(1,1,version),'Automatic row cannot be clicked')
assert(story.dialogue:Interject(2,2,version))
assert(data.DialogueNodeId==4156 and data.lines[#data.lines-1].ActorId==2,'Selected companion and NPC response remain connected')
assert(not story.dialogue:Interject(2,1,version),'Reject stale button')
story.dialogue:Enter(1);assert(#story.dialogue:Interjections()==0,'Optional speech is once per session across all candidates')
story.dialogue:Close();assert(story.dialogue:Open(1,1) and #story.dialogue:Interjections()==2,'New session clears consumed speech')
local history=config:GetTable('ConditionTable'):Get(4039)
record('relationship',1,2,{1,2})
assert(story.conditions:Check(history.id,{actor=actors[1]}));assert(story.conditions:Check(history.id,{actor=actors[2]}))
assert(not story.conditions:Check(history.id,{actor=actors[3]}),'Uninvolved members cannot borrow a shared experience')
assert(not pcall(function()story.conditions:Check(4036,{})end),'Actor context must be explicit')
print('PASS companion dialogue: all eligible speakers, per-actor ALL, exact history participants, optional candidates, branch, stale/dead/foreign clicks, session dedup and reopen')
