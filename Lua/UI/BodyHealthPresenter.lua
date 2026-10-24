local LuaLanguage=require('Language')
local Presenter={};Presenter.__index=Presenter
local function color(value)
    local hex=require('Config.Color').Normalize(value)
    return CS.UnityEngine.Color(tonumber(hex:sub(2,3),16)/255,tonumber(hex:sub(4,5),16)/255,tonumber(hex:sub(6,7),16)/255,1)
end
function Presenter.ModifierText(modifiers)
    local lines={}
    for _,row in ipairs(modifiers)do
        local tint=row.value<0 and '#F19A96' or row.value>0 and '#76D6AE' or '#EDF2F7'
        local value=math.floor(math.abs(row.value)*100+.5)/100*(row.value<0 and -1 or 1)
        lines[#lines+1]=string.format(row.percent and LuaLanguage.BodyAttributePercent or LuaLanguage.BodyAttributeAmount,row.name,tint,value)
    end
    return #lines>0 and table.concat(lines,'\n') or LuaLanguage.BodyNoPenalty
end
function Presenter.New(panel)
    local self=setmetatable({panel=panel,open=false,part=0},Presenter)
    panel:Listen(panel.view.Health,function()self:SetOpen(true)end)
    panel:Listen(panel.view.HealthBack,function()self:SetOpen(false)end)
    for i=0,5 do local part=i
        panel:Listen(panel.view['HealthPart'..i],function()self.part=part;self:Refresh()end)
    end
    panel:Listen(panel.view.HealthTreat,function()
        local ok,message=panel.system:TreatInjury(panel.actorId,self.part,1)
        panel.message=message
        if ok then panel.demo:SendCommand('snapshot')end
        panel:Refresh()
    end)
    panel:Listen(panel.view.HealthDiseaseTreat,function()
        local ok,message=panel.system:TreatDisease(panel.actorId,1)
        panel.message=message
        if ok then panel.demo:SendCommand('snapshot')end
        panel:Refresh()
    end)
    return self
end
function Presenter:SetOpen(value)
    self.open=value
    self.panel.view.Inventory:CancelDrag()
    if value then self.panel.view.Character:ReleasePreview()end
    self.panel:Refresh()
end
function Presenter:Refresh()
    local panel=self.panel;local view=panel.view
    view.HealthOverlay.gameObject:SetActive(self.open)
    view.Character.gameObject:SetActive(not self.open)
    view.Health.gameObject:SetActive(not self.open)
    local actor=assert(panel.system:Actor(panel.actorId));local injuries=panel.stats.injuries
    self.revision=CS.ProjectY.Data.BodyHealth.Revision(actor);self.effectRevision=actor.Effects.Revision
    if not self.open then return end
    local selected
    for _,row in ipairs(injuries:Rows(actor))do
        view['HealthPartImage'..row.index].color=color(row.color)
        view['HealthPartOutline'..row.index].effectColor=color(row.index==self.part and '#E5BE70' or '#788B9E')
        if row.index==self.part then selected=row end
    end
    assert(selected,'Unknown selected body part')
    view.HealthPartName.text=selected.name
    local effects=Presenter.ModifierText(selected.modifiers)
    local description=selected.description
    local recoveryAt=CS.ProjectY.Data.BodyHealth.RecoveryAt(actor,self.part)
    if recoveryAt>0 then
        local hours=math.ceil(math.max(0,recoveryAt-panel.system.adventure.Narrative.Minutes)/60)
        description=description..'\n'..string.format(LuaLanguage.BodyScheduledRecovery,hours,CS.ProjectY.Data.BodyHealth.RecoveryAmount(actor,self.part))
    end
    view.HealthDetail.text=string.format(LuaLanguage.BodyDetailV2,selected.health,selected.maximum,actor.HP,actor.MaxHP,selected.permanent and '#D5BBC0' or selected.color,
        selected.stage,selected.injury,description,effects)..'\n\n'..LuaLanguage.BodyTreatmentNoteV2
    if self.scrollActor~=actor.Id or self.scrollPart~=self.part then
        view.HealthDetailsScroll:StopMovement();view.HealthDetail.rectTransform.anchoredPosition=CS.UnityEngine.Vector2.zero
        self.scrollActor=actor.Id;self.scrollPart=self.part
    end
    local allowed=injuries:Treatment(actor,self.part,1,panel.system.data)
    view.HealthTreat.interactable=allowed and (panel.system.adventure.Phase=='map' or panel.system.adventure.Phase=='area')
    local treatment=injuries.treatments:Get(1)
    view.HealthTreatText.text=selected.permanent and LuaLanguage.BodyUntreatable or selected.damage==0 and LuaLanguage.BodyNoTreatment or
        string.format(LuaLanguage.BodyTreatmentButtonV2,injuries.items:Get(treatment.itemId).name,treatment.count,panel.system.data:CountItem(treatment.itemId),math.min(selected.damage,treatment.recovery))
    local diseases=panel.stats.diseases:Rows(actor);local lines={}
    for _,disease in ipairs(diseases)do lines[#lines+1]=string.format(LuaLanguage.BodyDiseaseEntry,disease.name,Presenter.ModifierText(disease.modifiers))end
    view.HealthDiseases.text=#lines>0 and table.concat(lines,'\n\n') or LuaLanguage.BodyNoDisease
    local medical=panel.stats.diseases.definitions:Get(1);local count=panel.system.data:CountItem(medical.itemId)
    view.HealthDiseaseTreat.interactable=#diseases>0 and count>=medical.count and (panel.system.adventure.Phase=='map' or panel.system.adventure.Phase=='area')
    view.HealthDiseaseTreatText.text=string.format(LuaLanguage.BodyDiseaseMedicine,panel.stats.diseases.items:Get(medical.itemId).name,medical.count,count)
end
function Presenter:Hide()
    self.open=false
    self.panel.view.HealthOverlay.gameObject:SetActive(false)
    self.panel.view.Character.gameObject:SetActive(true)
    self.panel.view.Health.gameObject:SetActive(true)
end
return Presenter
