local Class = require('Core.Class')
local Panel = require('UI.UIWidgetCtrl')
local Model = require('Game.Battle.BattleHUDModel')
local L = require('Language')
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
    self.actions, self.items, self.party, self.turns = {}, {}, {}, {}
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
    for i = 1, 4 do
        local widget = self:CreateWidget('BattleTurn', self.view.TurnSlots)
        widget:Initialize(self.view.HUD, true, function(id) self.demo:FocusBattleActor(id) end)
        self.turns[i] = widget
    end
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
    self:Listen(self.view.LogToggle, function() self.logVisible = not self.logVisible; self.dirty = true end)
    self:Listen(self.view.Previous, function() self.page = self.page - 1; self.dirty = true end)
    self:Listen(self.view.Next, function() self.page = self.page + 1; self.dirty = true end)
end
function HUD:OnShow(args)
    self.demo = assert(args.demo, 'Battle HUD requires its input adapter')
    self.page, self.logVisible, self.lastActor, self.lastTooltip = 1, true, nil, nil
    -- Battle events may arrive midway through a command/settlement. Read after the command, in Tick.
    self.visibleScope:Add(self.battle.Changed:Subscribe(function() self.dirty = true end))
    self:Refresh()
end
function HUD:Refresh()
    local model = Model.Build(self.battle, self.context.services.Adventure)
    local selection=CS.ProjectY.Samples.BattleTargetSelection
    local selecting=selection.Active(self.demo)
    if self.lastActor ~= model.actorId or self.lastPhase~=model.phase then self.page = 1; self.lastActor = model.actorId;self.lastPhase=model.phase end
    self.model = model
    local pages = math.max(1, math.ceil(#model.skills / 4)); self.page = math.min(pages, math.max(1, self.page))
    self.view.Encounter.text = model.encounter
    self.view.Round.text = model.phase=='deployment' and '战前部署' or string.format(L.BattleRound, model.round, model.maxRounds)
    self.view.SkillTitle.text = (model.phase=='deployment' and '职业准备技能' or L.BattleSkills) .. (pages > 1 and ('  ' .. self.page .. '/' .. pages) or '')
    self.view.ItemTitle.text = L.BattleItems
    self.view.EndTurnText.text = selecting and ('确认释放 '..selection.Count(self.demo)..'/'..selection.Limit(self.demo))
        or model.phase=='deployment' and '结束部署' or model.player and L.BattleEndTurn or L.BattleAdvanceAI
    self.view.EndTurn.interactable = selecting and selection.Count(self.demo)>0 or not selecting and (model.player or not self.demo.BattleAutoAI)
    self.view.MoveText.text = selecting and '取消选择 [Esc]' or model.moved and '移动已结束'
        or (self.demo.IsBattleMoveSelected and '• ' or '') .. L.BattleMove..' · 余 '..model.moveRemaining
    self.view.Move.interactable = selecting or model.moveAvailable
    self.view.FocusText.text = L.BattleFocus
    self.view.AutoText.text = self.demo.BattleAutoAI and L.BattleAutoOn or L.BattleAutoOff
    self.view.Auto.interactable=model.phase~='deployment'
    self.view.LogToggleText.text = self.logVisible and L.BattleHideLog or L.BattleShowLog
    self.view.Log.gameObject:SetActive(self.logVisible and not self.view.HUD.Compact)
    self.view.Logs.text = table.concat(model.logs, '\n')
    self.view.Previous.gameObject:SetActive(pages > 1); self.view.Next.gameObject:SetActive(pages > 1)
    self.view.Previous.interactable = self.page > 1; self.view.Next.interactable = self.page < pages
    local errorText = self.demo.LastError
    local targetHint=selection.Hint(self.demo)
    self.view.Hint.text = errorText and errorText ~= '' and errorText or targetHint~='' and targetHint or (not model.player and L.BattleEnemyTurn
        or (model.moved and self.demo.SelectedBattleSkill==0 and '移动阶段已结束；选择可用技能、道具或结束回合。'
            or model.phase=='deployment' and '部署：可先移动，也可直接准备；使用技能或道具后跳过剩余移动。'
            or self.demo.IsBattleMoveSelected and ('可分段移动，剩余 '..model.moveRemaining..' 距离；技能释放后结束移动。')
            or L.BattleTargetHint))
    for i, widget in ipairs(self.actions) do
        local row = model.skills[(self.page - 1) * 4 + i]
        widget:SetData(row, i, row ~= nil and row.id == self.demo.SelectedBattleSkill, row and self.icons:Get(row.iconId))
    end
    for i, widget in ipairs(self.items) do
        local row=model.items[i]
        widget:SetData(row,nil,false,self.icons:Get(row and row.iconId or self.settings.itemIconIds[i]))
    end
    for i, widget in ipairs(self.party) do widget:SetData(model.party[i]) end
    for i, widget in ipairs(self.turns) do widget:SetData(model.turns[i]) end
    self.revision = self.demo.BattleHUDRevision; self.dirty = false
    self.lastTooltip,self.lastTargetTooltip = nil,nil; self.view.Tooltip.gameObject:SetActive(false)
end
function HUD:Tick()
    if self.context.services.Adventure.Phase ~= 'battle' then return end
    if self.dirty or self.revision ~= self.demo.BattleHUDRevision then self:Refresh() end
    if not self.view.Group.interactable then return end
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
    local hovered,itemHovered
    for _, widget in ipairs(self.actions) do if widget:IsHovered() and widget.row then hovered = widget; break end end
    if not hovered then for _, widget in ipairs(self.items) do if widget:IsHovered() then hovered = widget;itemHovered=true;break end end end
    if hovered and hovered ~= self.lastTooltip then
        self.lastTooltip = hovered; self.view.Tooltip.gameObject:SetActive(hovered ~= nil)
        if hovered then
            local row = hovered.row
            self.view.TipTitle.text = row and row.name or L.BattleItems
            self.view.TipBody.text = row and (row.description .. '\n' .. string.format(L.BattleSkillCost, row.cost,
                row.action == 'main' and L.BattleMain or L.BattleSecondary, row.range) .. '\n' ..
                (row.available and (itemHovered and '点击此道具立即对自己使用。' or row.target == 'self' and L.BattleSelfHint or L.BattleTargetHint) or row.reason)) or L.BattleItemHint
        end
    end
    if hovered then self.lastTargetTooltip=nil
    else
        self.lastTooltip=nil
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
    self.demo, self.model, self.lastTooltip = nil, nil, nil
end
function HUD:Show(args)
    if self.context.services.Adventure.Phase~='battle' then self:Hide();return end
    -- Parent Show can revisit an already visible child. Base Show hides it before reopening.
    Panel.Show(self,args);self.view.Root.gameObject:SetActive(true)
end
function HUD:Hide() Panel.Hide(self);self.view.Root.gameObject:SetActive(false) end
return HUD
