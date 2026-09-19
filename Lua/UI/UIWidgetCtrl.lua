local Class = require('Core.Class')
local Scope = require('Core.Scope')
local View = require('UI.UIView')
---@class UIWidgetCtrl
local Widget = Class('UIWidgetCtrl')
function Widget:ctor(context, view)
    self.context = context; self.reference = view; self.view = View.Create(view)
    self.widgets = {}; self.visible = false; self.disposed = false
    self.lifetime = Scope(context.log)
end
function Widget:Bind() end
function Widget:OnShow(args) end
function Widget:OnHide() end
function Widget:OnDestroy() end
function Widget:Tick(dt, unscaledDt) end
function Widget:AddWidget(widgetType, reference)
    if type(widgetType) == 'string' then widgetType = require('UI.Widget.' .. widgetType) end
    local widget = widgetType(self.context, reference)
    local ok, err = xpcall(function()
        widget:Bind()
        if self.visible then widget:Show(self.args) end
    end, debug.traceback)
    if not ok then widget:Dispose(); error(err, 0) end
    self.widgets[#self.widgets + 1] = widget
    return widget
end
function Widget:CreateWidget(name, parent)
    local host = self.context.services.UI
    local reference = host:CreateWidget(name, parent or self.reference.transform)
    local widget
    local ok, err = xpcall(function()
        widget = require('UI.Widget.' .. name)(self.context, reference)
        widget.ownedView = true
        widget:Bind()
        if self.visible then widget:Show(self.args) end
    end, debug.traceback)
    if not ok then
        if widget then widget:Dispose() else host:DestroyWidget(reference) end
        error(err, 0)
    end
    self.widgets[#self.widgets + 1] = widget
    return widget
end
function Widget:Listen(button, callback)
    local function guarded()
        local ok, err = xpcall(callback, debug.traceback)
        if not ok then self.context.log(err) end
    end
    button.onClick:AddListener(guarded)
    self.lifetime:Add(function() button.onClick:RemoveListener(guarded) end)
end
function Widget:Show(args)
    assert(not self.disposed, 'Cannot show disposed widget')
    if self.visible then self:Hide() end
    self.visible = true; self.args = args; self.visibleScope = Scope(self.context.log)
    self:OnShow(args)
    for _, widget in ipairs(self.widgets) do widget:Show(args) end
    if self.ownedView then self.context.services.UI:SetWidgetVisible(self.reference, true) end
end
function Widget:Hide()
    if not self.visible then return end
    self.visible = false
    if self.ownedView then self.context.services.UI:SetWidgetVisible(self.reference, false) end
    for i = #self.widgets, 1, -1 do self.widgets[i]:Hide() end
    if self.visibleScope then self.visibleScope:Dispose(); self.visibleScope = nil end
    local ok, err = xpcall(self.OnHide, debug.traceback, self)
    if not ok then self.context.log(err) end
    self.args = nil
end
function Widget:Update(dt, unscaledDt)
    if not self.visible or self.disposed then return end
    self:Tick(dt, unscaledDt)
    for _, widget in ipairs(self.widgets) do widget:Update(dt, unscaledDt) end
end
function Widget:Dispose()
    if self.disposed then return end
    self:Hide(); self.disposed = true
    for i = #self.widgets, 1, -1 do self.widgets[i]:Dispose() end
    self.widgets = {}; self.lifetime:Dispose()
    local ok, err = xpcall(self.OnDestroy, debug.traceback, self)
    if not ok then self.context.log(err) end
    if self.ownedView then self.context.services.UI:DestroyWidget(self.reference) end
    self.view = nil; self.reference = nil; self.context = nil; self.panel = nil
end
return Widget
