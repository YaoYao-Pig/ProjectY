local Class = require('Core.Class')
local System = require('Core.LuaSystem')
local UI = Class('UISystem', System)
local ranks = { Background = 1, Main = 2, Popup = 3, Overlay = 4 }
function UI:OnInit(context)
    System.OnInit(self, context)
    self.host = context.services.UI; self.sceneVersion = self.host.SceneVersion
    self.panels = {}; self.opened = {}; self.sequence = 0
end
function UI:Open(name, args)
    local definition = self.host:GetConfig(name)
    assert(not definition.IsWidget, 'Cannot open a Widget as a Panel')
    assert(ranks[definition.Layer], 'Unknown panel layer')
    local entry = self.panels[name]
    if not entry then
        local view = self.host:CreateView(name)
        local ok, result = xpcall(function()
            local ctrl = require(definition.ControllerModule)(self.context, view)
            entry = { name = name, ctrl = ctrl, view = view, definition = definition }
            ctrl.panelName = name; ctrl.panel = self.host:GetPanel(view); ctrl:Bind()
            return entry
        end, debug.traceback)
        if not ok then
            if entry then entry.ctrl:Dispose() end
            self.host:DestroyView(view); error(result, 0)
        end
        self.panels[name] = result
    end
    for i = #self.opened, 1, -1 do if self.opened[i] == entry then table.remove(self.opened, i) end end
    self.sequence = self.sequence + 1; entry.sequence = self.sequence
    self.opened[#self.opened + 1] = entry
    local ok, err = xpcall(function()
        entry.ctrl:Show(args)
        self.host:SetVisible(entry.view, true)
    end, debug.traceback)
    if not ok then self:Close(name, true); error(err, 0) end
    self:RefreshInput()
    return entry.ctrl
end
function UI:RefreshInput()
    table.sort(self.opened, function(a, b)
        local ar, br = ranks[a.definition.Layer], ranks[b.definition.Layer]
        if ar ~= br then return ar < br end
        return a.sequence < b.sequence
    end)
    local blocked = false
    for i = #self.opened, 1, -1 do
        local entry = self.opened[i]
        self.host:SetOrder(entry.view, 100 + i)
        self.host:SetInteractable(entry.view, not blocked)
        if entry.definition.Modal then blocked = true end
    end
end
function UI:Close(name, forceDestroy)
    local entry = self.panels[name]
    if not entry then return false end
    for i = #self.opened, 1, -1 do if self.opened[i] == entry then table.remove(self.opened, i) end end
    entry.ctrl:Hide(); self.host:SetVisible(entry.view, false)
    if forceDestroy or not entry.definition.Cache then
        entry.ctrl:Dispose(); self.host:DestroyView(entry.view); self.panels[name] = nil
    end
    self:RefreshInput()
    return true
end
function UI:Back()
    for i = #self.opened, 1, -1 do
        local entry = self.opened[i]
        if entry.definition.CloseOnBack ~= false then return self:Close(entry.name) end
        if entry.definition.Modal then return false end
    end
    return false
end
function UI:Tick(dt, unscaledDt)
    if self.sceneVersion ~= self.host.SceneVersion then
        self.sceneVersion = self.host.SceneVersion
        self:OnSceneChanged()
    end
    local snapshot = {}
    for i, entry in ipairs(self.opened) do snapshot[i] = entry end
    for _, entry in ipairs(snapshot) do
        if entry.ctrl.visible and not entry.ctrl.disposed then
            local ok, err = xpcall(entry.ctrl.Update, debug.traceback, entry.ctrl, dt, unscaledDt)
            if not ok then self.context.log(err); self:Close(entry.name, true) end
        end
    end
end
function UI:OnSceneChanged()
    local names = {}
    for name, entry in pairs(self.panels) do
        if entry.definition.CloseOnSceneChange then names[#names + 1] = name end
    end
    for _, name in ipairs(names) do self:Close(name, true) end
end
function UI:OnShutdown()
    if not self.panels then return end
    local names = {}
    for name in pairs(self.panels) do names[#names + 1] = name end
    for _, name in ipairs(names) do self:Close(name, true) end
end
return UI
