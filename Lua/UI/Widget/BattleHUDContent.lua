local LuaLanguage = require('Language')
local Class = require('Core.Class')
local Panel = require('UI.UIWidgetCtrl')
local Model = require('Game.Battle.BattleHUDModel')
---@class BattleHUDCtr : UIPanelCtrl
---@field view BattleHUDPanelView
local HUD = Class('BattleHUDContent', Panel)
function HUD:Bind()
    self.battle = self.context.systems:Get('Battle')
    local config = self.context.systems:Get('Config')
    self.icons = config:GetTable('BattleIconTable')
    self.settings = config:GetTable('BattleHUDTable'):Get(1)
    assert(#self.settings.itemIconIds == 4, 'Battle HUD has four item presentation slots')
    self.view.HUD:Prepare()
    self.skillTip=require('UI.SkillTipPresenter').New(self.view.SkillTip,config)
    self.actions, self.items, self.party = {}, {}, {}
    for i = 1, 4 do
        local widget = self:CreateWidget('BattleAction', self.view.SkillSlots)
        widget:Initialize(self.view.HUD, function(row) self.demo:SelectBattleSkill(row.id) end)
        self.actions[i] = widget
    end
    for i = 1, 4 do
        local widget = self:CreateWidget('BattleAction', self.view.ItemSlots)
        widget:Initialize(self.view.HUD, function(row) self.demo:SendCommand('use_item',row.id,0) end)
        self.items[i] = widget
    end
    for i = 1, 4 do
        local widget = self:CreateWidget('BattleParty', self.view.PartySlots)
        widget:Initialize(self.view.HUD, false, function(id) self.demo:FocusBattleActor(id) end)
        self.party[i] = widget
    end
    self.turnList = self:AddWidget(require('UI.UIScrollList'), self.view.TurnList)
    self.turnList:Configure({
        templates = { turn = self.view.TurnTemplate }, spacing = 6,
        getSize = function(_, _, width) return math.max(110, (width - 18) / 4), 62 end,
        onCreate = function(cell)
            -- Cells belong to the list; parent Show must not show a newly bound cell twice.
            cell.widget = require('UI.Widget.BattleTurn')(self.context, cell.reference)
            cell.widget:Bind()
            cell.widget:Initialize(self.view.HUD, true, function(id) self.demo:FocusBattleActor(id) end)
        end,
        onBind = function(cell, index)
            if not cell.widget.visible then cell.widget:Show(self.args) end
            cell.widget:SetData(self.model.turns[index])
        end,
        onRecycle = function(cell) cell.widget:Hide() end,
        onDestroy = function(cell) cell.widget:Dispose() end,
    })
    self:Listen(self.view.EndTurn, function()
        local selection=CS.ProjectY.Samples.BattleTargetSelection
        if selection.Active(self.demo) then selection.Confirm(self.demo)
        else self.demo:SendCommand(self.model.player and 'end_turn' or 'ai', 0, 0) end
    end)
    self:Listen(self.view.Move, function()
        local selection=CS.ProjectY.Samples.BattleTargetSelection
        if selection.Active(self.demo) then selection.Cancel(self.demo) else self.demo:SelectBattleMove() end
    end)
    self:Listen(self.view.Focus, function() self.demo:FitMap() end)
    self:Listen(self.view.Auto, function() self.demo:SetBattleAutoAI(not self.demo.BattleAutoAI) end)
    self:Listen(self.view.LogToggle, function() self.logExpanded = not self.logExpanded; self.dirty = true end)
    self:Listen(self.view.LogOpen, function() self.logExpanded = true; self.dirty = true end)
    self:Listen(self.view.LogClose, function() self.logExpanded = false; self.dirty = true end)
    self:Listen(self.view.Previous, function() self.page = self.page - 1; self.dirty = true end)
    self:Listen(self.view.Next, function() self.page = self.page + 1; self.dirty = true end)
end
function HUD:OnShow(args)
    self.demo = assert(args.demo, 'Battle HUD requires its input adapter')
    self.page, self.logExpanded, self.lastActor, self.lastTooltip = 1, false, nil, nil
    self.model = nil
    -- Battle events may arrive midway through a command/settlement. Read after the command, in Tick.
    self.visibleScope:Add(self.battle.Changed:Subscribe(function() self.dirty = true end))
    self:Refresh()
end
function HUD:Refresh()
    local model = Model.Build(self.battle, self.context.services.Adventure)
    -- Target-hover revisions must not close the card while the pointer crosses into a term link.
    local keepTip=not self.dirty and self.lastActor==model.actorId and self.lastPhase==model.phase
        and self.lastTooltip~=nil and self.skillTip:KeepOpen(self.lastTooltip:IsHovered())
    local selection=CS.ProjectY.Samples.BattleTargetSelection
    local selecting=selection.Active(self.demo)
    local selectingLanding=selection.NeedsLanding(self.demo)
    if self.lastActor ~= model.actorId or self.lastPhase~=model.phase then self.page = 1; self.lastActor = model.actorId;self.lastPhase=model.phase end
    local previous = self.model
    local resetTurns = not previous or previous.actorId ~= model.actorId
        or previous.round ~= model.round or previous.phase ~= model.phase
    local turnsChanged = resetTurns or #previous.turns ~= #model.turns
    if not turnsChanged then
        for i, row in ipairs(model.turns) do
            if previous.turns[i].id ~= row.id then turnsChanged = true; break end
        end
    end
    self.model = model
    local pages = math.max(1, math.ceil(#model.skills / 4)); self.page = math.min(pages, math.max(1, self.page))
    self.view.Encounter.text = model.encounter
    self.view.Round.text = model.phase=='deployment' and LuaLanguage.UIBattleHUDContentRoundText or string.format(LuaLanguage.BattleRound, model.round, model.maxRounds)
    self.view.SkillTitle.text = (model.phase=='deployment' and LuaLanguage.UIBattleHUDContentSkillTitleText or LuaLanguage.BattleSkills) .. (pages > 1 and ('  ' .. self.page .. '/' .. pages) or '')
    self.view.ItemTitle.text = LuaLanguage.BattleItems
    self.view.EndTurnText.text = selectingLanding and LuaLanguage.BattleSelectionChooseLanding
        or selecting and (string.format(LuaLanguage.UIBattleHUDContentEndTurnTextText2, (selection.Count(self.demo)), (selection.Limit(self.demo))))
        or model.phase=='deployment' and LuaLanguage.UIBattleHUDContentEndTurnTextText or model.player and LuaLanguage.BattleEndTurn or LuaLanguage.BattleAdvanceAI
    self.view.EndTurn.interactable = not selectingLanding and (selecting and selection.Count(self.demo)>0 or not selecting and (model.player or not self.demo.BattleAutoAI))
    self.view.MoveText.text = selecting and LuaLanguage.UIBattleHUDContentMoveTextText3 or model.moved and LuaLanguage.UIBattleHUDContentMoveTextText2
        or string.format(LuaLanguage.UIBattleHUDContentMoveTextText, (self.demo.IsBattleMoveSelected and '• ' or ''), (LuaLanguage.BattleMove), (model.moveRemaining))
    self.view.Move.interactable = selecting or model.moveAvailable
    self.view.FocusText.text = LuaLanguage.BattleFocus
    self.view.AutoText.text = self.demo.BattleAutoAI and LuaLanguage.BattleAutoOn or LuaLanguage.BattleAutoOff
    self.view.Auto.interactable=model.phase~='deployment'
    self.view.LogToggleText.text = self.logExpanded and LuaLanguage.BattleHideLog or LuaLanguage.BattleShowLog
    local recent={};for i=math.max(1,#model.logs-2),#model.logs do recent[#recent+1]=model.logs[i] end
    CS.ProjectY.UI.BattleLogPresentation.Set(self.view.HUD,self.logExpanded,table.concat(recent,'\n\n'),table.concat(model.logs,'\n\n'),#model.logs)
    self.view.Previous.gameObject:SetActive(pages > 1); self.view.Next.gameObject:SetActive(pages > 1)
    self.view.Previous.interactable = self.page > 1; self.view.Next.interactable = self.page < pages
    local errorText = self.demo.LastError
    local targetHint=selection.Hint(self.demo)
    self.view.Hint.text = errorText and errorText ~= '' and errorText or targetHint~='' and targetHint or (not model.player and LuaLanguage.BattleEnemyTurn
        or (model.moved and self.demo.SelectedBattleSkill==0 and LuaLanguage.UIBattleHUDContentHintText3
            or model.phase=='deployment' and LuaLanguage.UIBattleHUDContentHintText2
            or self.demo.IsBattleMoveSelected and (string.format(LuaLanguage.UIBattleHUDContentHintText, (model.moveRemaining)))
            or LuaLanguage.BattleTargetHint))
    for i, widget in ipairs(self.actions) do
        local row = model.skills[(self.page - 1) * 4 + i]
        widget:SetData(row, i, row ~= nil and row.id == self.demo.SelectedBattleSkill, row and self.icons:Get(row.iconId))
    end
    for i, widget in ipairs(self.items) do
        local row=model.items[i]
        widget:SetData(row,nil,false,self.icons:Get(row and row.iconId or self.settings.itemIconIds[i]))
    end
    for i, widget in ipairs(self.party) do widget:SetData(model.party[i]) end
    if turnsChanged then self.turnList:SetItemCount(#model.turns, not resetTurns)
    else
        local first, last = self.turnList:GetVisibleRange()
        for i = first, last do self.turnList:RefreshItem(i) end
    end
    self.revision = self.demo.BattleHUDRevision; self.dirty = false
    self.lastTargetTooltip=nil;self.view.Tooltip.gameObject:SetActive(false)
    if not keepTip then self.lastTooltip=nil;self.skillTip:Hide() end
end
function HUD:Tick()
    if self.context.services.Adventure.Phase ~= 'battle' then return end
    if self.dirty or self.revision ~= self.demo.BattleHUDRevision then self:Refresh() end
    if not self.view.Group.interactable then self.skillTip:Hide();self.lastTooltip=nil;return end
    self.skillTip:Tick()
    local shortcut = self.view.HUD:ReadShortcut()
    if shortcut >= 1 and shortcut <= 4 then
        local row = self.actions[shortcut].row
        if row and row.available then self.demo:SelectBattleSkill(row.id) end
    elseif shortcut == 9 and self.model.player then
        local selection=CS.ProjectY.Samples.BattleTargetSelection
        if selection.Active(self.demo) then selection.Confirm(self.demo) else self.demo:SendCommand('end_turn', 0, 0) end
    elseif shortcut == 10 then
        if self.demo.SelectedBattleSkill~=0 then CS.ProjectY.Samples.BattleTargetSelection.Cancel(self.demo)
        elseif self.model.moveAvailable then self.demo:SelectBattleMove() end
    end
    -- Commands can settle combat and hide this panel synchronously.
    if not self.visible then return end
    local hovered
    for _, widget in ipairs(self.actions) do if widget:IsHovered() and widget.row then hovered = widget; break end end
    if not hovered then for _, widget in ipairs(self.items) do if widget:IsHovered() and widget.row then hovered = widget;break end end end
    if hovered and hovered ~= self.lastTooltip then
        self.lastTooltip=hovered
        self.skillTip:Show(hovered.row,self.context.services.Adventure,hovered.view.Root)
    end
    -- Sample both surfaces every frame; leaving them dismisses the card immediately.
    local keepTip=self.skillTip:KeepOpen(hovered~=nil)
    if keepTip then
        self.lastTargetTooltip=nil;self.view.Tooltip.gameObject:SetActive(false)
    else
        self.lastTooltip=nil;self.skillTip:Hide()
        local selection=CS.ProjectY.Samples.BattleTargetSelection
        local title,body=selection.PreviewTitle(self.demo),selection.PreviewBody(self.demo)
        local key=title..'\n'..body
        if key~=self.lastTargetTooltip then
            self.lastTargetTooltip=key;self.view.Tooltip.gameObject:SetActive(title~='')
            if title~='' then self.view.TipTitle.text=title;self.view.TipBody.text=body end
        end
    end
end
function HUD:OnHide()
    self.view.Tooltip.gameObject:SetActive(false)
    self.skillTip:Hide()
    self.demo, self.model, self.lastTooltip = nil, nil, nil
end
function HUD:Show(args)
    if self.context.services.Adventure.Phase~='battle' then self:Hide();return end
    -- Parent Show can revisit an already visible child. Base Show hides it before reopening.
    Panel.Show(self,args);self.view.Root.gameObject:SetActive(true)
end
function HUD:Hide() Panel.Hide(self);self.view.Root.gameObject:SetActive(false) end
return HUD
