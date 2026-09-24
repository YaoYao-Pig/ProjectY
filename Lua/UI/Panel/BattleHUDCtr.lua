local Class = require('Core.Class')
local Panel = require('UI.UIPanelCtrl')
local Model = require('Game.Battle.BattleHUDModel')
local L = require('Language')
---@class BattleHUDCtr : UIPanelCtrl
---@field view BattleHUDPanelView
local HUD = Class('BattleHUDCtr', Panel)
function HUD:Bind()
    self.battle = self.context.systems:Get('Battle')
    local config = self.context.systems:Get('Config')
    self.icons = config:GetTable('BattleIconTable')
    self.settings = config:GetTable('BattleHUDTable'):Get(1)
    assert(#self.settings.itemIconIds == 4, 'Battle HUD has four item presentation slots')
    self.view.HUD:Prepare()
    self.actions, self.items, self.party, self.turns = {}, {}, {}, {}
    for i = 1, 8 do
        local widget = self:CreateWidget('BattleAction', self.view.SkillSlots)
        widget:Initialize(self.view.HUD, function(row) self.demo:SelectBattleSkill(row.id) end)
        self.actions[i] = widget
    end
    for i = 1, 4 do
        local widget = self:CreateWidget('BattleAction', self.view.ItemSlots)
        widget:Initialize(self.view.HUD, function() error('Item slots do not implement inventory gameplay') end)
        self.items[i] = widget
    end
    for i = 1, 4 do
        local widget = self:CreateWidget('BattleParty', self.view.PartySlots)
        widget:Initialize(self.view.HUD, false, function(id) self.demo:FocusBattleActor(id) end)
        self.party[i] = widget
    end
    for i = 1, 8 do
        local widget = self:CreateWidget('BattleTurn', self.view.TurnSlots)
        widget:Initialize(self.view.HUD, true, function(id) self.demo:FocusBattleActor(id) end)
        self.turns[i] = widget
    end
    self:Listen(self.view.EndTurn, function()
        self.demo:SendCommand(self.model.player and 'end_turn' or 'ai', 0, 0)
    end)
    self:Listen(self.view.Move, function() self.demo:SelectBattleMove() end)
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
    if self.lastActor ~= model.actorId then self.page = 1; self.lastActor = model.actorId end
    self.model = model
    local pages = math.max(1, math.ceil(#model.skills / 8)); self.page = math.min(pages, math.max(1, self.page))
    self.view.Encounter.text = model.encounter
    self.view.Round.text = string.format(L.BattleRound, model.round, model.maxRounds)
    self.view.ActorName.text = model.name
    self.view.HealthText.text = string.format(L.BattleHP, model.hp, model.maxHP)
    self.view.HUD:SetHealth(self.view.Health, model.hp / model.maxHP)
    self.view.AP.text = string.format(L.BattleAP, model.ap, model.maxAP)
    self.view.Resources.text = string.format(L.BattleResources, model.defense, model.guard,
        model.moved and L.BattleSpent or L.BattleReady, model.mainUsed and L.BattleSpent or L.BattleReady)
        .. (model.ammo~='' and ('\n'..model.ammo) or '')
    self.view.SkillTitle.text = L.BattleSkills .. (pages > 1 and ('  ' .. self.page .. '/' .. pages) or '')
    self.view.ItemTitle.text = L.BattleItems
    self.view.EndTurnText.text = model.player and L.BattleEndTurn or L.BattleAdvanceAI
    self.view.EndTurn.interactable = model.player or not self.demo.BattleAutoAI
    self.view.MoveText.text = (self.demo.IsBattleMoveSelected and '• ' or '') .. L.BattleMove
    self.view.Move.interactable = model.moveAvailable
    self.view.FocusText.text = L.BattleFocus
    self.view.AutoText.text = self.demo.BattleAutoAI and L.BattleAutoOn or L.BattleAutoOff
    self.view.LogToggleText.text = self.logVisible and L.BattleHideLog or L.BattleShowLog
    self.view.Log.gameObject:SetActive(self.logVisible)
    self.view.Logs.text = table.concat(model.logs, '\n')
    self.view.Previous.gameObject:SetActive(pages > 1); self.view.Next.gameObject:SetActive(pages > 1)
    self.view.Previous.interactable = self.page > 1; self.view.Next.interactable = self.page < pages
    local errorText = self.demo.LastError
    self.view.Hint.text = errorText and errorText ~= '' and errorText or (not model.player and L.BattleEnemyTurn
        or (self.demo.IsBattleMoveSelected and L.BattleMoveHint or L.BattleTargetHint))
    for i, widget in ipairs(self.actions) do
        local row = model.skills[(self.page - 1) * 8 + i]
        widget:SetData(row, i, row ~= nil and row.id == self.demo.SelectedBattleSkill, row and self.icons:Get(row.iconId))
    end
    for i, widget in ipairs(self.items) do widget:SetData(nil, nil, false, self.icons:Get(self.settings.itemIconIds[i])) end
    for i, widget in ipairs(self.party) do widget:SetData(model.party[i]) end
    for i, widget in ipairs(self.turns) do widget:SetData(model.turns[i]) end
    self.revision = self.demo.BattleHUDRevision; self.dirty = false
    self.lastTooltip = nil; self.view.Tooltip.gameObject:SetActive(false)
end
function HUD:Tick()
    if self.context.services.Adventure.Phase ~= 'battle' then return end
    if self.dirty or self.revision ~= self.demo.BattleHUDRevision then self:Refresh() end
    if not self.view.Group.interactable then return end
    local shortcut = self.view.HUD:ReadShortcut()
    if shortcut >= 1 and shortcut <= 8 then
        local row = self.actions[shortcut].row
        if row and row.available then self.demo:SelectBattleSkill(row.id) end
    elseif shortcut == 9 and self.model.player then self.demo:SendCommand('end_turn', 0, 0)
    elseif shortcut == 10 and self.model.moveAvailable then self.demo:SelectBattleMove() end
    -- Commands can settle combat and hide this panel synchronously.
    if not self.visible then return end
    local hovered
    for _, widget in ipairs(self.actions) do if widget:IsHovered() and widget.row then hovered = widget; break end end
    if not hovered then for _, widget in ipairs(self.items) do if widget:IsHovered() then hovered = widget; break end end end
    if hovered ~= self.lastTooltip then
        self.lastTooltip = hovered; self.view.Tooltip.gameObject:SetActive(hovered ~= nil)
        if hovered then
            local row = hovered.row
            self.view.TipTitle.text = row and row.name or L.BattleItems
            self.view.TipBody.text = row and (row.description .. '\n' .. string.format(L.BattleSkillCost, row.cost,
                row.action == 'main' and L.BattleMain or L.BattleSecondary, row.range) .. '\n' ..
                (row.available and (row.target == 'self' and L.BattleSelfHint or L.BattleTargetHint) or row.reason)) or L.BattleItemHint
        end
    end
end
function HUD:OnHide()
    self.view.Tooltip.gameObject:SetActive(false)
    self.demo, self.model, self.lastTooltip = nil, nil, nil
end
return HUD
