local LuaLanguage = require('Language')
local Class=require('Core.Class')
local Panel=require('UI.UIPanelCtrl')
local Model=require('Game.Adventure.MainHudModel')
local Widgets=require('UI.GrowthWidgets')
local Feedback=require('Game.Battle.BattleFeedback')
local DiceChecks=require('Game.Presentation.DiceChecks')
local HUD=Class('MainHudCtr',Panel)
function HUD:Bind()
    self.adventure=self.context.systems:Get('Adventure');self.view.HUD:Prepare()
    self.party,self.health={},{}
    self.skills={};self.view.HUD:SetCharacterSkillBar(self.view.CharacterSkills)
    self:Listen(self.view.MenuToggle,function() self.menuOpen=not self.menuOpen;self:Refresh() end)
    self:Listen(self.view.Missions,function() self.demo:SendCommand('hud_missions') end)
    self:Listen(self.view.SkillPrevious,function() self.skillPage=self.skillPage-1;self:Refresh() end)
    self:Listen(self.view.SkillNext,function() self.skillPage=self.skillPage+1;self:Refresh() end)
    self.view.CancelSkillText.font=self.view.HUD.Font
    self:Listen(self.view.CancelSkill,function() self.demo:CancelCharacterSkill() end)
    self:Listen(self.view.GM,function() self.demo:OpenGM() end)
    self.view.GMText.font=self.view.HUD.Font
    self.battleContent=self:AddWidget(require('UI.Widget.BattleHUDContent'),self.view.BattleContent)
    self:Listen(self.view.Inventory,function() self.demo:OpenEquipment() end)
    self.view.GrowthText.text=LuaLanguage.UIMainHudGrowthTextText
    self:Listen(self.view.Growth,function() self.demo:OpenGrowth() end)
    self:Listen(self.view.NavigationToggle,function() self.navigation=not self.navigation;self:Refresh() end)
    self:Listen(self.view.Focus,function() self.demo:FitMap() end)
    self:Listen(self.view.Follow,function() self.demo:SendCommand('hud_follow') end)
    self:Listen(self.view.TimeStart,function() self.demo:SendCommand('travel_resume') end)
    self:Listen(self.view.TimePause,function() self.demo:SendCommand('travel_suspend') end)
    self:Listen(self.view.TimeSpeed,function()
        local speed=self.adventure.travel.data.Speed
        self.demo:SendCommand('travel_speed',speed==1 and 2 or speed==2 and 4 or 1)
    end)
    self:Listen(self.view.Leave,function() self.demo:SendCommand('area_leave') end)
    self:Listen(self.view.Stop,function() self.demo:SendCommand('area_stop') end)
    self:Listen(self.view.CameraMode,function() self.demo:ToggleTownCamera() end)
    -- 复用已保存的独立导航按钮；新远征移入菜单，营地不再藏在菜单中。
    self.view.RestartText.text=LuaLanguage.UIMainHudRestartTextText
    self:Listen(self.view.Restart,function() self.demo:SendCommand('camp_open') end)
    self:Listen(self.view.Environment,function() self.demo:ToggleEnvironment() end)
    self:Listen(self.view.Interact,function() local row=self.model.interaction;self.demo:SendCommand(row.command,row.a or 0,row.b or 0) end)
end
function HUD:OnShow(args)
    self.demo=assert(args.demo);self.demo:SetMainHud(self.view.HUD);self.navigation=false;self.menuOpen=false
    self.visibleScope:Add(self.adventure.battle.Changed:Subscribe(function(event)
        Feedback.Changed(self.view.BattleFeedback,event);self.healthDirty=true
        if self.adventure.data.Phase~='battle' then
            local check=DiceChecks.FromBattleEvent(event)
            if check then self:ShowCheck(check) end
        end
    end))
    self.visibleScope:Add(self.adventure.events.CheckResolved:Subscribe(function(check) self:ShowCheck(check) end))
    self.visibleScope:Add(self.adventure.narrative.RewardSettled:Subscribe(function(receipt)
        if self.missionSettlement and self.missionSettlement.visible then self.missionSettlement:Enqueue(receipt)
        else self.missionSettlement=self.context.systems:Get('UI'):Open('MissionSettlement',{receipt=receipt,font=self.demo.MainHudFont}) end
    end))
    self.view.HealthTooltip.gameObject:SetActive(false)
    self.skillPage=1;self.skillActor=nil;self.lastPhase=nil;self.clockMinute=nil;self:Refresh();self:Clock()
end
function HUD:ShowCheck(check)
    if self.diceRoll and self.diceRoll.visible then self.diceRoll:Enqueue(check)
    else self.diceRoll=self.context.systems:Get('UI'):Open('DiceRoll',{check=check}) end
end
function HUD:Refresh()
    self.view.Group.alpha=self.adventure.narrative.data.DialogueOpen and 0 or 1
    local model=Model.Build(self.adventure);self.model=model
    -- 探索视野先于 Demo 的显示快照推进；头顶 UI 只绑定本次已创建棋子的身份。
    local rendered={};local ids=self.demo:RenderedHealthActorIds()
    for i=0,ids.Length-1 do rendered[ids[i]]=true end
    local health={};for _,row in ipairs(model.health) do if rendered[row.id] then health[#health+1]=row end end
    model.health=health
    if model.phase~=self.lastPhase then self.navigation=false;self.menuOpen=false;self.lastPhase=model.phase end
    local battle=model.phase=='battle'
    self.view.Exploration.gameObject:SetActive(not battle)
    self.view.HealthLayer.gameObject:SetActive(true)
    if battle and not self.battleContent.visible then self.battleContent:Show(self.args)
    elseif not battle and self.battleContent.visible then self.battleContent:Hide() end
    self.view.HUD:SetMode(not battle,self.navigation)
    self.view.Menu.gameObject:SetActive(self.menuOpen)
    local exploring=model.phase=='map' or model.phase=='area'
    self.view.TimeControls.gameObject:SetActive(model.phase=='map')
    self.view.Follow.gameObject:SetActive(exploring)
    if model.phase=='map' then
        self.view.TimeStart.interactable=model.timeControl.paused
        self.view.TimePause.interactable=not model.timeControl.paused
        self.view.TimeSpeedText.text=string.format(LuaLanguage.UIMainHudTimeSpeedTextText, (model.timeControl.speed))
    end
    self.view.Inventory.interactable=exploring;self.view.Missions.interactable=exploring;self.view.Growth.interactable=exploring
    self.view.NavigationToggle.gameObject:SetActive(not battle)
    self.view.Location.text=model.title;self.view.Subtitle.text=model.subtitle;self.view.Coins.text=string.format(LuaLanguage.UIMainHudCoinsText, (model.coins))
    self.view.NavigationTitle.text=model.phase=='map' and LuaLanguage.UIMainHudNavigationTitleText2 or LuaLanguage.UIMainHudNavigationTitleText
    self.view.Leave.gameObject:SetActive(model.phase=='area');self.view.Stop.gameObject:SetActive(model.phase=='area')
    self.view.CameraMode.gameObject:SetActive(false);self.view.Restart.gameObject:SetActive(model.phase=='map')
    self.view.Logs.text=table.concat(model.logs,'\n\n')
    if not self.prompt then self.prompt=self:CreateWidget('HudInteraction',self.view.Root) end
    self.prompt:SetData(model.prompt,self.view.HUD,self.demo)
    self.view.Interaction.gameObject:SetActive(model.interaction~=nil and not battle)
    if model.interaction then
        self.view.InteractionTitle.text=model.interaction.title;self.view.InteractionBody.text=model.interaction.body;self.view.InteractText.text=model.interaction.caption
    end
    local errorText=self.demo.LastError or '';self.view.Hint.text=errorText;self.view.Hint.gameObject:SetActive(errorText~='')
    Widgets.Rows(self,'NavigationRows','HudRow',model.rows,function(row) self.demo:SendCommand(row.command,row.a or 0,row.b or 0) end)
    Widgets.Rows(self,'MenuRows','HudRow',model.menu,function(row)
        self.menuOpen=false
        if row.command=='start' then self.demo:StartExpedition()
        else self.demo:SendCommand(row.command,row.a or 0,row.b or 0) end
        self:Refresh()
    end)
    for i,row in ipairs(model.party) do
        if not self.party[i] then self.party[i]=self:CreateWidget('HudParty',self.view.PartyRows) end
        self.party[i]:SetData(row,self.view.HUD,row.id==self.demo.SelectedCharacterId,function(id) self.demo:SelectCharacter(id) end,self.view.BattleFeedback)
    end
    for i=#model.party+1,#self.party do self.party[i]:SetData(nil) end
    local used,visible={},false
    for _,row in ipairs(model.health) do
        local widget
        for _,candidate in ipairs(self.health) do if candidate.row and candidate.row.id==row.id then widget=candidate;break end end
        if not widget then
            for _,candidate in ipairs(self.health) do if not candidate.row and not used[candidate] then widget=candidate;break end end
        end
        if not widget then widget=self:CreateWidget('HudHealth',self.view.HealthLayer);self.health[#self.health+1]=widget end
        used[widget]=true;visible=true
        widget:SetData(row,self.view.HUD,self.demo,self.battleContent.view.HUD,self.view.BattleFeedback)
    end
    for _,widget in ipairs(self.health) do if not used[widget] then
        if widget.row and (not widget.row.screen or battle) and widget.view.HealthAnimation.TargetFraction==0
            and (widget.view.HealthAnimation.IsAnimating or widget.view.DamageNumbers.IsAnimating) then
            widget:Retire();visible=true
        else widget:SetData(nil) end
    end end
    self.view.HealthLayer.gameObject:SetActive(visible)
    local actor=self.adventure.characterSkills:Actor(self.demo.SelectedCharacterId)
    local rows=self.adventure.characterSkills:Rows(self.demo.SelectedCharacterId,'life')
    self.skillRows=rows
    if self.skillActor~=self.demo.SelectedCharacterId then self.skillActor=self.demo.SelectedCharacterId;self.skillPage=1 end
    local pages=math.max(1,math.ceil(#rows/4));self.skillPage=math.max(1,math.min(pages,self.skillPage))
    self.view.SkillPage.text=self.skillPage..' / '..pages
    self.view.SkillPrevious.interactable=self.skillPage>1;self.view.SkillNext.interactable=self.skillPage<pages
    self.view.CharacterSkills.gameObject:SetActive(not battle)
    self.view.SkillActor.font=self.view.HUD.Font;self.view.SkillHint.font=self.view.HUD.Font;self.view.SkillEmpty.font=self.view.HUD.Font
    self.view.SkillActor.text=actor and (string.format(LuaLanguage.UIMainHudSkillActorText2, (self.adventure.battle.stats:Template(actor).name))) or LuaLanguage.UIMainHudSkillActorText
    self.view.SkillEmpty.text=actor and LuaLanguage.UIMainHudSkillEmptyText2 or LuaLanguage.UIMainHudSkillEmptyText
    self.view.SkillEmpty.gameObject:SetActive(#rows==0)
    self.view.CancelSkill.gameObject:SetActive(self.demo.SelectedCharacterSkill~=0)
    self.view.SkillHint.text=self.demo.SelectedCharacterSkill~=0 and LuaLanguage.UIMainHudSkillHintText2 or LuaLanguage.UIMainHudSkillHintText
    for i=1,math.min(4,#rows) do
        local row=rows[(self.skillPage-1)*4+i]
        if not self.skills[i] then self.skills[i]=self:CreateWidget('CharacterSkill',self.view.CharacterSkillSlots) end
        self.skills[i]:SetData(row,self.view.HUD,row~=nil and row.id==self.demo.SelectedCharacterSkill,function(skill)
            self.demo:SelectCharacterSkill(self.demo.SelectedCharacterId,skill.id,skill.target)
        end)
    end
    for i=math.min(4,#rows)+1,#self.skills do self.skills[i]:SetData(nil) end
    self.revision=self.demo.BattleHUDRevision;self.journalCount=self.adventure.data.JournalCount;self.healthDirty=false
end
function HUD:Clock()
    local minutes=math.floor(self.adventure.narrative.data.Minutes)
    if self.clockMinute==minutes then return end
    self.clockMinute=minutes;local day=minutes%1440
    self.view.ClockTime.text=string.format('%02d:%02d',day//60,day%60)
    self.view.ClockDay.text=string.format(LuaLanguage.UIMainHudClockDayText, (minutes//1440+1))
    self.view.ClockNeedle.localEulerAngles=CS.UnityEngine.Vector3(0,0,-day/1440*360)
end
function HUD:Tick()
    self.view.Group.alpha=self.adventure.narrative.data.DialogueOpen and 0 or 1
    self:Clock()
    self.battleContent.view.Group.interactable=self.view.Group.interactable
    if self.healthDirty or self.revision~=self.demo.BattleHUDRevision or self.journalCount~=self.adventure.data.JournalCount then self:Refresh() end
    local hint=self.demo.SelectedCharacterSkill~=0 and LuaLanguage.UIMainHudSkillHintText2 or LuaLanguage.UIMainHudSkillHintText
    for _,widget in ipairs(self.skills) do if widget.row and widget:IsHovered() then
        hint=(widget.row.available and '' or (widget.row.reason..' · '))..widget.row.description;break
    end end
    self.view.SkillHint.text=hint
    local hovered
    if self.view.Group.interactable then
        for _,widget in ipairs(self.health) do hovered=widget:HoveredEffect();if hovered then break end end
    end
    self.view.HealthTooltip.gameObject:SetActive(hovered~=nil)
    if hovered and (self.healthHover~=hovered or self.healthTooltipRow~=hovered.row) then
        self.view.HealthTipTitle.text=hovered.row.name;self.view.HealthTipBody.text=hovered.row.body
    end
    self.healthHover=hovered;self.healthTooltipRow=hovered and hovered.row
end
function HUD:OnHide()
    self.view.HealthTooltip.gameObject:SetActive(false);self.healthHover=nil;self.healthTooltipRow=nil
    if self.demo then self.demo:SetMainHud(nil);self.demo=nil end
end
return HUD
