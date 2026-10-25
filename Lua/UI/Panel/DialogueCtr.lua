local LuaLanguage = require('Language')
local Class=require('Core.Class')
local Base=require('UI.UIPanelCtrl')
local Dialogue=Class('DialogueCtr',Base)
local Rich=require('UI.RichText')
function Dialogue:Bind()
    self.story=self.context.systems:Get('Narrative');self.pool={};self.choices={}
    self:Listen(self.view.Close,function() self.demo:SendCommand('dialogue_close',0,0) end)
end
function Dialogue:OnShow(args)
    self.demo=assert(args.demo);self.demo:SetStoryOpen(true)
    self.lineCount=0;self.nodeId=nil;self.dialogueVersion=nil
    self.camera=self.story.rules.cameras:Get(self.story.rules.dialogues:Get(self.story.data.DialogueId).cameraId)
    self.view.Style:Prepare(self.demo.MainHudFont,self.camera.panelWidth);self:Refresh()
end
function Dialogue:Refresh()
    local story,data=self.story,self.story.data
    if not data.DialogueOpen then return end
    local npc=story.rules.npcs:Get(data.DialogueNpcId)
    local animal=story.adventure.animalSpeech and story.adventure.animalSpeech:Active() and CS.ProjectY.Data.AnimalSpeechState.Target(data)
    self.view.Title.text=animal and story.adventure.battle.stats:Template(animal).name or npc.name
    self.view.Caption.text=string.format(LuaLanguage.UIDialogueCaptionText, (story.rules.factions:Get(npc.factionId).name))
    local linesChanged=self.lineCount~=data.LineCount or self.dialogueVersion~=data.DialogueVersion
    if linesChanged then
        local rows={}
        for i=0,data.LineCount-1 do
            local line=data:GetLineAt(i);local body=Rich.Escape(line.Text)
            local kind=line.ActorId>0 and 'companion' or line.IsChoice and 'player' or line.Speaker=='旁白' and 'narrator' or 'npc'
            local title='<b>'..Rich.Escape(line.Speaker)..'</b>'
            if kind=='companion' then title=title..'  <size=70%>〔'..Rich.Escape(line.Cue)..'〕</size>' end
            if kind=='narrator' then body='<i>'..body..'</i>' end
            rows[#rows+1]={title=title,body=body,kind=kind,actorId=line.ActorId}
        end
        for i,row in ipairs(rows) do
            if not self.pool[i] then self.pool[i]=self:CreateWidget('DialogueEntry',self.view.Content) end
            self.pool[i]:SetData(row,self.demo.MainHudFont,row.action)
        end
        for i=#rows+1,#self.pool do self.pool[i]:SetData(nil) end
    end
    local version=data.DialogueVersion
    local choices=story.dialogue:Choices()
    local interjections=story.dialogue:Interjections()
    local choiceCount=0
    for _,entry in ipairs(interjections) do
        choiceCount=choiceCount+1
        if not self.choices[choiceCount] then self.choices[choiceCount]=self:CreateWidget('DialogueEntry',self.view.Choices) end
        local id,actorId=entry.id,entry.actorId
        self.choices[choiceCount]:SetData({title=string.format(LuaLanguage.UIDialogueTitle2, (Rich.Escape(entry.name)), (Rich.Escape(entry.cue))),
            body='',kind='invite',actorId=actorId,available=true},
            self.demo.MainHudFont,function() self.demo:SendCommand('dialogue_interject',id,actorId,version) end)
    end
    for i,choice in ipairs(choices) do
        choiceCount=choiceCount+1
        if not self.choices[choiceCount] then self.choices[choiceCount]=self:CreateWidget('DialogueEntry',self.view.Choices) end
        local id=choice.id
        self.choices[choiceCount]:SetData({title=i..'. '..Rich.Escape(choice.text),body=Rich.Escape(choice.reason),kind='choice',available=choice.available},
            self.demo.MainHudFont,function() self.demo:SendCommand('dialogue_choose',id,version) end)
    end
    local adventure=story.adventure;local localId=data.DialogueLocalNpcId
    if npc.locationKind=='town' then
        local area=adventure.areas:ActiveLayout()
        if adventure.shop.rules:Resolve(area,area.npcs[localId]) then
            choiceCount=choiceCount+1
            if not self.choices[choiceCount] then self.choices[choiceCount]=self:CreateWidget('DialogueEntry',self.view.Choices) end
            self.choices[choiceCount]:SetData({title=LuaLanguage.UIDialogueTitle,body='',kind='choice',available=true},self.demo.MainHudFont,
                function() self.demo:SendCommand('shop_open',localId,version) end)
        end
    end
    for i=choiceCount+1,#self.choices do self.choices[i]:SetData(nil) end
    if self.nodeId~=data.DialogueNodeId then self.view.ChoiceScroll.verticalNormalizedPosition=1 end
    self.view.Hint.text=self.demo.LastError~='' and self.demo.LastError or LuaLanguage.UIDialogueHintText
    -- OnShow runs before the host activates the panel; settle wrapped rows on the first visible tick.
    if linesChanged then self.scrollPending=true end
    self.lineCount=data.LineCount;self.nodeId=data.DialogueNodeId
    self.dialogueVersion=data.DialogueVersion
    self.revision=data.Revision;self.demoRevision=self.demo.BattleHUDRevision
    self:Camera()
end
function Dialogue:Camera()
    local data=self.story.data;local camera=self.camera
    if self.story.adventure.animalSpeech and self.story.adventure.animalSpeech:Active()then return end
    if self.story.rules.npcs:Get(data.DialogueNpcId).locationKind=='world_party' then return end
    self.demo:SetDialogueCamera(data.DialogueActorId,data.DialogueLocalNpcId,self.story.rules.nodes:Get(data.DialogueNodeId).shot,
        camera.distance,camera.height,camera.pitch,camera.fieldOfView,camera.blendSeconds,camera.closeupScale,self.view.Style.PanelFraction)
end
function Dialogue:Tick()
    if not self.story.data.DialogueOpen then return end
    if self.revision~=self.story.data.Revision or self.demoRevision~=self.demo.BattleHUDRevision then self:Refresh()
    else self:Camera() end
    if self.scrollPending then
        CS.UnityEngine.Canvas.ForceUpdateCanvases()
        CS.UnityEngine.UI.LayoutRebuilder.ForceRebuildLayoutImmediate(self.view.Content)
        self.view.Style:ScrollToEnd();self.scrollPending=false
    end
end
function Dialogue:OnHide()
    self.scrollPending=false
    if self.story.data.DialogueOpen then self.story.dialogue:Close() end
    if self.demo then self.demo:EndDialogueCamera();self.demo:SetStoryOpen(false);self.demo=nil end
end
return Dialogue
