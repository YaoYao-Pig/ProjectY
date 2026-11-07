-- Production spirit flow, generic dialogue routing and panel controller; C# state/Unity views are isolated.
package.path='Lua/?.lua;'..package.path
local L=require('Language')
for _,key in ipairs({'EquipmentSpiritBusy','EquipmentSpiritMapOnly','EquipmentSpiritUnavailable','EquipmentSpiritDormant',
    'EquipmentSpiritLivingActor','EquipmentSpiritStale','EquipmentSpiritKnow','EquipmentSpiritMemories','EquipmentSpiritWish',
    'EquipmentSpiritAcceptWish','EquipmentSpiritLeave','EquipmentSpiritNoMemory','EquipmentSpiritCaption','EquipmentSpiritHint',
    'EquipmentSpiritNoInterjection'})do assert(type(L[key])=='string' and L[key]~='','Missing spirit language key: '..key)end
local session={DialogueOpen=false,DialogueVersion=0,Revision=0,LineCount=0,lines={},weaponId=0}
function session:AddDialogueLine(speaker,text,choice)
    assert(self.DialogueOpen and type(speaker)=='string' and speaker~='' and type(text)=='string' and text~='')
    self.lines[#self.lines+1]={Speaker=speaker,Text=text,IsChoice=choice,ActorId=0,Cue=''}
    self.LineCount=#self.lines;self.Revision=self.Revision+1
end
function session:GetLineAt(index)return assert(self.lines[index+1])end
function session:CloseDialogue()
    self.DialogueOpen=false;self.weaponId=0;self.DialogueId=0;self.DialogueNodeId=0
    self.DialogueNpcId=0;self.DialogueLocalNpcId=0;self.DialogueActorId=0
    self.lines={};self.LineCount=0;self.DialogueVersion=self.DialogueVersion+1;self.Revision=self.Revision+1
end
local bridge={}
function bridge.WeaponId(data)return data.weaponId end
function bridge.Begin(data,id,actorId)
    assert(not data.DialogueOpen and id>0 and actorId>0)
    data.DialogueOpen=true;data.weaponId=id;data.DialogueId=-1;data.DialogueNodeId=0
    data.DialogueNpcId=0;data.DialogueLocalNpcId=0;data.DialogueActorId=actorId
    data.DialogueVersion=data.DialogueVersion+1;data.Revision=data.Revision+1
end
function bridge.Touch(data)data.DialogueVersion=data.DialogueVersion+1;data.Revision=data.Revision+1 end
CS={ProjectY={Data={EquipmentSpiritSession=bridge,EquipmentLegacyData={Of=function(weapon)return weapon.legacy end}}},
    UnityEngine={VerticalWrapMode={Truncate=0},Canvas={ForceUpdateCanvases=function()end},UI={LayoutRebuilder={ForceRebuildLayoutImmediate=function()end}}}}
local actors={{Id=11,HP=10},{Id=12,HP=10}}
local function history(path)
    local value={Awakened=true,PathId=path,WishState=0,Revision=3,DeedCount=1,accepts=0}
    function value:GetDeedAt(index)assert(index==0);return {RuleId=path,ActorId=11,TargetId=7,SiteId=2,Minutes=100}end
    function value:AcceptWish()
        assert(self.Awakened and self.WishState==0);self.WishState=1;self.Revision=self.Revision+1;self.accepts=self.accepts+1;return true
    end
    return value
end
local weapons={{Id=21,ItemId=40,OwnerActorId=12,legacy=history(1)},
    {Id=22,ItemId=40,OwnerActorId=0,legacy=history(2)},
    {Id=23,ItemId=40,OwnerActorId=99,legacy=history(1)}}
local inventory={WeaponCount=#weapons}
function inventory:GetWeaponAt(index)return weapons[index+1]end
local equipment={data=inventory}
function equipment:Actor(id)for _,actor in ipairs(actors)do if actor.Id==id then return actor end end end
function equipment:IsCarriedWeapon(weapon)return weapon.OwnerActorId==0 or self:Actor(weapon.OwnerActorId)~=nil end
local adventure={data={Narrative=session,Phase='map'},equipment=equipment}
adventure.events={LivingParty=function()
    local rows={};for _,actor in ipairs(actors)do if actor.HP>0 then rows[#rows+1]=actor end end;return rows
end}
adventure.travel={data={SetPaused=function(_,value)assert(value==true);adventure.paused=true end}}
local paths={
    {name='Slayer',spiritOpening='Awake',personality='Bold',wish='Survive together',wishAccepted='Promise',wishProgress='Awaiting victory',wishCompleted='We survived'},
    {name='Guardian',spiritOpening='Listening',personality='Patient',wish='Stand together',wishAccepted='Together',wishProgress='Still waiting',wishCompleted='Home safely'}}
adventure.forge={rules={settings={spiritCameraId=17},paths={Get=function(_,id)return assert(paths[id])end}},
    Name=function(_,weapon)return 'Weapon '..weapon.Id end,
    DeedText=function(_,deed)return 'Deed '..deed.RuleId..':'..deed.ActorId..':'..deed.TargetId end}
local forbidden={Get=function()error('Equipment spirit queried an NPC, town, faction or narrative node table')end}
local story={adventure=adventure,data=session,rules={settings={playerSpeaker='Player'},npcs=forbidden,factions=forbidden,
    dialogues=forbidden,nodes=forbidden,choices=forbidden,interjections=forbidden,
    cameras={Get=function(_,id)assert(id==17);return {panelWidth=512}end}}}
adventure.narrative=story
adventure.spiritDialogue=require('Game.Equipment.EquipmentSpiritDialogue').New(adventure)
story.dialogue=require('Game.Narrative.Dialogue').New(story)
local spirit=adventure.spiritDialogue
local function choose(id)return story.dialogue:Choose(id,session.DialogueVersion)end
local function last()return session.lines[#session.lines].Text end

assert(not spirit:Open(999) and not spirit:Open(23),'Missing and foreign weapons are rejected')
weapons[1].legacy.Awakened=false;assert(not spirit:Open(21));weapons[1].legacy.Awakened=true
adventure.data.Phase='battle';assert(not spirit:Open(21));adventure.data.Phase='map'
actors[1].HP=0;actors[2].HP=0;assert(not spirit:Open(21));actors[1].HP=10;actors[2].HP=10
assert(spirit:Open(21) and spirit:Active() and session.weaponId==21 and session.DialogueNpcId==0 and session.DialogueActorId==12)
assert(adventure.paused and last()==paths[1].spiritOpening and not spirit:Open(22),'Open is exclusive and retains the instance owner')
assert(story.dialogue:CanContinue() and #story.dialogue:Interjections()==0 and not story.dialogue:Interject(1,11,session.DialogueVersion))
local oldVersion=session.DialogueVersion
assert(choose(-1) and last()==paths[1].personality)
assert(not story.dialogue:Choose(-4,oldVersion),'An earlier choice cannot accept a wish after dialogue advances')
assert(not choose(1) and weapons[1].legacy.accepts==0,'Config NPC choice ids are not allowed in a spirit session')
assert(choose(-2) and last()=='Deed 1:11:7','The selected instance recalls its own participant and target')
assert(choose(-3) and last()==paths[1].wish)
assert(choose(-4) and weapons[1].legacy.WishState==1 and weapons[1].legacy.accepts==1 and last()==paths[1].wishAccepted)
assert(not choose(-4) and weapons[1].legacy.accepts==1,'The wish can only be accepted once')
assert(choose(-3) and last()==paths[1].wishProgress)
weapons[1].legacy.WishState=2
assert(choose(-3) and last()==paths[1].wishCompleted,'Completed wishes answer without granting another reward')
local beforeClose=session.DialogueVersion
assert(choose(-5) and not spirit:Active() and session.weaponId==0 and session.LineCount==0)
assert(spirit:Open(22) and session.DialogueActorId==11 and last()==paths[2].spiritOpening)
assert(not story.dialogue:Choose(-4,beforeClose) and weapons[2].legacy.accepts==0,'Old callbacks cannot address a new weapon session')
assert(spirit:Title()=='Weapon 22' and spirit:Caption()==string.format(L.EquipmentSpiritCaption,paths[2].name))
assert(choose(-2) and last()=='Deed 2:11:7','Same item template does not share history or personality')
weapons[2].OwnerActorId=99
assert(not choose(-4) and weapons[2].legacy.accepts==0 and choose(-5),'A transferred weapon cannot accept a wish, but can always close')
weapons[2].OwnerActorId=0
assert(spirit:Open(22));actors[1].HP=0
assert(not choose(-4) and choose(-5),'The speaking actor must still be alive')
actors[1].HP=10
assert(spirit:Open(22));adventure.data.Phase='area'
assert(not choose(-1) and choose(-5),'Changed phase invalidates actions while preserving close')
adventure.data.Phase='map'
assert(spirit:Open(22));session:CloseDialogue();assert(not spirit:Active(),'Narrative reset/close clears spirit identity')
assert(spirit:Open(22));weapons[2].legacy.DeedCount=0
assert(choose(-2) and last()==L.EquipmentSpiritNoMemory)
weapons[2].legacy.DeedCount=1

local panel=setmetatable({story=story,pool={},choices={},view={Title={fontSize=25},Caption={},Hint={},Content={},Choices={},ChoiceScroll={},Style={}}},
    require('UI.Panel.DialogueCtr'))
local demo={LastError='',MainHudFont={},BattleHUDRevision=1}
function demo:SetStoryOpen(value)self.storyOpen=value end
function demo:SetDialogueCamera()error('An equipment spirit tried to focus a town NPC camera')end
function demo:EndDialogueCamera()self.ended=true end
function demo:SendCommand(command,id,version)
    assert(command=='dialogue_choose');self.lastResult=story.dialogue:Choose(id,version);return self.lastResult
end
function panel.view.Style:Prepare(font,width)assert(font==demo.MainHudFont and width==512)end
function panel.view.Style:ScrollToEnd()self.scrolled=true end
function panel:CreateWidget(name,parent)
    assert(name=='DialogueEntry' and (parent==self.view.Content or parent==self.view.Choices))
    return {SetData=function(widget,row,font,action)widget.row=row;widget.action=action end}
end
panel:OnShow({demo=demo})
assert(demo.storyOpen and panel.view.Title.text=='Weapon 22' and panel.view.Hint.text==L.EquipmentSpiritHint)
assert(#panel.choices==5 and panel.choices[1].row.kind=='choice')
local callback=panel.choices[1].action
callback();assert(demo.lastResult);panel:Tick();assert(panel.view.Style.scrolled and panel.lineCount==session.LineCount)
callback();assert(not demo.lastResult,'Panel callbacks preserve their original dialogue version')
panel:OnHide();assert(not demo.storyOpen and demo.ended and session.weaponId==0 and not session.DialogueOpen)
assert(spirit:Open(21));panel:OnShow({demo=demo})
assert(panel.view.Title.text=='Weapon 21' and #story.dialogue:Choices()==4 and panel.choices[5].row==nil,
    'Cached panel reopening replaces identity and hides a completed wish accept choice')
panel:OnHide();assert(not session.DialogueOpen and session.weaponId==0)
print('PASS equipment spirit: instance identity, history, wish lifecycle, ownership/life/phase gates, stale callbacks, NPC-free UI routing and close/reopen')
