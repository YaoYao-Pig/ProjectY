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
    self.camera=self.story.rules.cameras:Get(self.story.rules.dialogues:Get(self.story.data.DialogueId).cameraId)
    self.view.Style:Prepare(self.demo.MainHudFont,self.camera.panelWidth);self:Refresh()
end
function Dialogue:Refresh()
    local story,data=self.story,self.story.data
    if not data.DialogueOpen then return end
    local npc=story.rules.npcs:Get(data.DialogueNpcId)
    self.view.Title.text=npc.name
    self.view.Caption.text=story.rules.factions:Get(npc.factionId).name..' · 好感 '..data:GetValue('relation:'..npc.id)
    local rows={}
    for i=0,data.LineCount-1 do
        local line=data:GetLineAt(i);local body=Rich.Escape(line.Text)
        if line.Speaker=='旁白' then body='<i><color=#A8B5A3>'..body..'</color></i>'
        else body='<b><color='..(line.IsChoice and '#A9BDCC' or '#DDC28A')..'>'..Rich.Escape(line.Speaker)..'：</color></b> '..body end
        rows[#rows+1]={title='',body=body,plain=true}
    end
    local version=data.DialogueVersion
    for i,row in ipairs(rows) do
        if not self.pool[i] then self.pool[i]=self:CreateWidget('NarrativeEntry',self.view.Content) end
        self.pool[i]:SetData(row,self.demo.MainHudFont,row.action)
    end
    for i=#rows+1,#self.pool do self.pool[i]:SetData(nil) end
    local choices=story.dialogue:Choices()
    for i,choice in ipairs(choices) do
        if not self.choices[i] then self.choices[i]=self:CreateWidget('NarrativeEntry',self.view.Choices) end
        local id=choice.id
        self.choices[i]:SetData({title=i..'. '..Rich.Escape(choice.text),body=Rich.Escape(choice.reason),available=choice.available},
            self.demo.MainHudFont,function() self.demo:SendCommand('dialogue_choose',id,version) end)
    end
    for i=#choices+1,#self.choices do self.choices[i]:SetData(nil) end
    self.view.ChoiceScroll.verticalNormalizedPosition=1
    self.view.Hint.text=self.demo.LastError or ''
    self.view.Style:ScrollToEnd();self.revision=data.Revision;self.demoRevision=self.demo.BattleHUDRevision
    self:Camera()
end
function Dialogue:Camera()
    local data=self.story.data;local camera=self.camera
    self.demo:SetDialogueCamera(data.DialogueActorId,data.DialogueLocalNpcId,self.story.rules.nodes:Get(data.DialogueNodeId).shot,
        camera.distance,camera.height,camera.pitch,camera.fieldOfView,camera.blendSeconds,camera.closeupScale,self.view.Style.PanelFraction)
end
function Dialogue:Tick()
    if not self.story.data.DialogueOpen then return end
    if self.revision~=self.story.data.Revision or self.demoRevision~=self.demo.BattleHUDRevision then self:Refresh()
    else self:Camera() end
end
function Dialogue:OnHide()
    if self.story.data.DialogueOpen then self.story.dialogue:Close() end
    if self.demo then self.demo:EndDialogueCamera();self.demo:SetStoryOpen(false);self.demo=nil end
end
return Dialogue
