local Class=require('Core.Class')
local Panel=require('UI.UIPanelCtrl')
local Model=require('Game.Adventure.MainHudModel')
local Widgets=require('UI.GrowthWidgets')
local HUD=Class('MainHudCtr',Panel)
function HUD:Bind()
    self.adventure=self.context.systems:Get('Adventure');self.view.HUD:Prepare()
    self.party,self.health={},{}
    self.skills={};self.view.HUD:SetCharacterSkillBar(self.view.CharacterSkills)
    self.view.CancelSkillText.font=self.view.HUD.Font
    self:Listen(self.view.CancelSkill,function() self.demo:CancelCharacterSkill() end)
    self:Listen(self.view.GM,function() self.demo:OpenGM() end)
    self.view.GMText.font=self.view.HUD.Font
    self.battleContent=self:AddWidget(require('UI.Widget.BattleHUDContent'),self.view.BattleContent)
    self:Listen(self.view.Inventory,function() self.demo:OpenEquipment() end)
    self:Listen(self.view.Growth,function() self.demo:OpenGrowth() end)
    self:Listen(self.view.NavigationToggle,function() self.navigation=not self.navigation;self:Refresh() end)
    self:Listen(self.view.Focus,function() self.demo:FitMap() end)
    self:Listen(self.view.Leave,function() self.demo:SendCommand('area_leave') end)
    self:Listen(self.view.Stop,function() self.demo:SendCommand('area_stop') end)
    self:Listen(self.view.CameraMode,function() self.demo:ToggleTownCamera() end)
    self:Listen(self.view.Restart,function() self.demo:StartExpedition() end)
    self:Listen(self.view.Environment,function() self.demo:ToggleEnvironment() end)
    self:Listen(self.view.Interact,function() local row=self.model.interaction;self.demo:SendCommand(row.command,row.a or 0,row.b or 0) end)
end
function HUD:OnShow(args)
    self.demo=assert(args.demo);self.demo:SetMainHud(self.view.HUD);self.navigation=true;self.lastPhase=nil;self:Refresh()
end
function HUD:Refresh()
    local model=Model.Build(self.adventure);self.model=model
    -- 探索视野先于 Demo 的显示快照推进；头顶 UI 只绑定本次已创建棋子的身份。
    local rendered={};local ids=self.demo:RenderedHealthActorIds()
    for i=0,ids.Length-1 do rendered[ids[i]]=true end
    local health={};for _,row in ipairs(model.health) do if rendered[row.id] then health[#health+1]=row end end
    model.health=health
    if model.phase~=self.lastPhase then self.navigation=model.phase=='map' or not model.town;self.lastPhase=model.phase end
    local battle=model.phase=='battle'
    self.view.Exploration.gameObject:SetActive(not battle)
    self.view.HealthLayer.gameObject:SetActive(#model.health>0)
    if battle and not self.battleContent.visible then self.battleContent:Show(self.args)
    elseif not battle and self.battleContent.visible then self.battleContent:Hide() end
    self.view.HUD:SetMode(not battle,self.navigation)
    self.view.Location.text=model.title;self.view.Subtitle.text=model.subtitle;self.view.Coins.text=model.coins..'  金币'
    self.view.NavigationTitle.text=model.phase=='map' and '这 一 程，去 哪 里' or '附 近 与 目 的 地'
    self.view.Leave.gameObject:SetActive(model.phase=='area');self.view.Stop.gameObject:SetActive(model.phase=='area')
    self.view.CameraMode.gameObject:SetActive(model.phase=='area' and model.town);self.view.Restart.gameObject:SetActive(model.phase=='map')
    self.view.Logs.text=table.concat(model.logs,'\n\n')
    self.view.Interaction.gameObject:SetActive(model.interaction~=nil and not battle)
    if model.interaction then
        self.view.InteractionTitle.text=model.interaction.title;self.view.InteractionBody.text=model.interaction.body;self.view.InteractText.text=model.interaction.caption
    end
    local errorText=self.demo.LastError or '';self.view.Hint.text=errorText;self.view.Hint.gameObject:SetActive(errorText~='')
    Widgets.Rows(self,'NavigationRows','HudRow',model.rows,function(row) self.demo:SendCommand(row.command,row.a or 0,row.b or 0) end)
    for i,row in ipairs(model.party) do
        if not self.party[i] then self.party[i]=self:CreateWidget('HudParty',self.view.PartyRows) end
        self.party[i]:SetData(row,self.view.HUD,row.id==self.demo.SelectedCharacterId,function(id) self.demo:SelectCharacter(id) end)
    end
    for i=#model.party+1,#self.party do self.party[i]:SetData(nil) end
    for i,row in ipairs(model.health) do
        if not self.health[i] then self.health[i]=self:CreateWidget('HudHealth',self.view.HealthLayer) end
        self.health[i]:SetData(row,self.view.HUD,self.demo)
    end
    for i=#model.health+1,#self.health do self.health[i]:SetData(nil,self.view.HUD) end
    local actor=self.adventure.characterSkills:Actor(self.demo.SelectedCharacterId)
    local rows=self.adventure.characterSkills:Rows(self.demo.SelectedCharacterId,'life')
    self.skillRows=rows
    self.view.CharacterSkills.gameObject:SetActive(not battle)
    self.view.SkillActor.font=self.view.HUD.Font;self.view.SkillHint.font=self.view.HUD.Font;self.view.SkillEmpty.font=self.view.HUD.Font
    self.view.SkillActor.text=actor and (self.adventure.battle.stats:Template(actor).name..' · 技能') or '选择一位队员，查看拥有的技能'
    self.view.SkillEmpty.text=actor and '尚未掌握生活技能，可在升级研习时学习。' or '点击下方队员卡片进行选择'
    self.view.SkillEmpty.gameObject:SetActive(#rows==0)
    self.view.CancelSkill.gameObject:SetActive(self.demo.SelectedCharacterSkill~=0)
    self.view.SkillHint.text=self.demo.SelectedCharacterSkill~=0 and '点击场景中的目标释放技能 · Esc 取消' or '生活技能 · 悬停查看说明'
    for i,row in ipairs(rows) do
        if not self.skills[i] then self.skills[i]=self:CreateWidget('CharacterSkill',self.view.CharacterSkillSlots) end
        self.skills[i]:SetData(row,self.view.HUD,row.id==self.demo.SelectedCharacterSkill,function(skill)
            self.demo:SelectCharacterSkill(self.demo.SelectedCharacterId,skill.id,skill.target)
        end)
    end
    for i=#rows+1,#self.skills do self.skills[i]:SetData(nil) end
    self.revision=self.demo.BattleHUDRevision;self.journalCount=self.adventure.data.JournalCount
end
function HUD:Tick()
    self.battleContent.view.Group.interactable=self.view.Group.interactable
    if self.revision~=self.demo.BattleHUDRevision or self.journalCount~=self.adventure.data.JournalCount then self:Refresh() end
    local hint=self.demo.SelectedCharacterSkill~=0 and '点击场景中的目标释放技能 · Esc 取消' or '生活技能 · 悬停查看说明'
    for _,widget in ipairs(self.skills) do if widget.row and widget:IsHovered() then
        hint=(widget.row.available and '' or (widget.row.reason..' · '))..widget.row.description;break
    end end
    self.view.SkillHint.text=hint
end
function HUD:OnHide() if self.demo then self.demo:SetMainHud(nil);self.demo=nil end end
return HUD
