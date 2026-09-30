local Class = require('Core.Class')
local Base = require('UI.UIWidgetCtrl')
local View = require('UI.UIView')
local Layout = require('UI.UIScrollListLayout')

---@class UIScrollList : UIWidgetCtrl
local List = Class('UIScrollList', Base)

function List:ctor(context, reference)
    Base.ctor(self, context, reference)
    self.activeCells = {}
    self.cells = {}
    self.itemCount = 0
end

local function optionalCallback(value, name)
    assert(value == nil or type(value) == 'function', name .. ' must be a function')
    return value
end

-- Call once in the owning Panel/Widget's Bind, before Show.
-- templates maps a string key to a LuaReference whose Root binds its root RectTransform.
function List:Configure(options)
    assert(not self.configured and not self.visible and not self.disposed, 'Configure UIScrollList once before Show')
    assert(type(options) == 'table' and type(options.templates) == 'table', 'CellTemplates are required')
    assert(type(options.onBind) == 'function', 'onBind(cell, index) is required')
    local padding = options.padding or {}
    self.options = {
        onBind = options.onBind,
        onCreate = optionalCallback(options.onCreate, 'onCreate'),
        onRecycle = optionalCallback(options.onRecycle, 'onRecycle'),
        onDestroy = optionalCallback(options.onDestroy, 'onDestroy'),
        getTemplate = optionalCallback(options.getTemplate, 'getTemplate'),
        getSize = optionalCallback(options.getSize, 'getSize'),
        spacing = Layout.NonNegative(options.spacing or 0, 'spacing'),
        overscan = Layout.NonNegative(options.overscan or 100, 'overscan'),
        padding = {
            left = Layout.NonNegative(padding.left or 0, 'padding.left'),
            right = Layout.NonNegative(padding.right or 0, 'padding.right'),
            top = Layout.NonNegative(padding.top or 0, 'padding.top'),
            bottom = Layout.NonNegative(padding.bottom or 0, 'padding.bottom'),
        },
    }
    self.scroll = self.view.ScrollRect
    self.content = assert(self.scroll.content, 'ScrollRect.content is required')
    self.viewport = assert(self.scroll.viewport, 'ScrollRect.viewport is required')
    assert(self.content.parent == self.viewport, 'Content must be a direct child of Viewport')
    assert(self.scroll.vertical ~= self.scroll.horizontal, 'UIScrollList requires exactly one scrolling axis')
    self.vertical = self.scroll.vertical
    self.templates = {}
    local templateCount = 0
    for key, reference in pairs(options.templates) do
        assert(type(key) == 'string' and key ~= '', 'CellTemplate keys must be non-empty strings')
        local root = reference:Get('Root')
        assert(root == reference.transform, 'CellTemplate.Root must bind the template root RectTransform')
        assert(not root.gameObject.activeSelf, 'CellTemplates must be inactive before Configure: ' .. key)
        assert(root.rect.width > 0 and root.rect.height > 0, 'CellTemplate must have positive dimensions: ' .. key)
        self.templates[key] = { reference = reference, width = root.rect.width, height = root.rect.height, pool = {} }
        self.options.defaultTemplate = key
        templateCount = templateCount + 1
    end
    assert(templateCount > 0, 'At least one CellTemplate is required')
    assert(templateCount == 1 or self.options.getTemplate, 'Multiple CellTemplates require getTemplate(index)')
    local unity = CS.UnityEngine
    self.content.anchorMin = unity.Vector2(0, 1)
    self.content.anchorMax = unity.Vector2(0, 1)
    self.content.pivot = unity.Vector2(0, 1)
    self.content.localScale = unity.Vector3.one
    self.content.localEulerAngles = unity.Vector3.zero
    self.configured = true
    self:SetItemCount(0)
end

-- Public mutations may not be called recursively from layout/cell callbacks.
-- Always release the guard on failure; errors still propagate to the owning UI.
function List:_Mutate(operation, ...)
    assert(self.configured and not self.disposed, 'UIScrollList is not configured or is disposed')
    assert(not self.busy, 'Do not mutate UIScrollList from its callbacks')
    self.busy = true
    local ok, err = xpcall(operation, debug.traceback, self, ...)
    self.busy = false
    if not ok then error(err, 0) end
end

function List:_ViewportSize()
    local rect = self.viewport.rect
    return rect.width, rect.height
end

function List:_Offset()
    local position = self.content.anchoredPosition
    return self.vertical and position.y or -position.x
end

function List:_SetOffset(offset)
    local size = self.vertical and self.viewportHeight or self.viewportWidth
    offset = Layout.ClampOffset(self.layout, offset, size)
    self.content.anchoredPosition = self.vertical and CS.UnityEngine.Vector2(0, offset) or CS.UnityEngine.Vector2(-offset, 0)
end

function List:_Recycle(index)
    local cell = self.activeCells[index]
    self.activeCells[index] = nil
    cell.root.gameObject:SetActive(false)
    -- Pool ownership is transferred before invoking user code, even if that code fails.
    local pool = self.templates[cell.templateKey].pool
    pool[#pool + 1] = cell
    cell.index = nil
    if self.options.onRecycle then self.options.onRecycle(cell, index) end
end

function List:_RecycleAll()
    for index in pairs(self.activeCells) do self:_Recycle(index) end
    self.firstVisible, self.lastVisible = nil, nil
end

function List:_Acquire(index, item)
    local template = self.templates[item.templateKey]
    local pool = template.pool
    local cell = table.remove(pool)
    if not cell then
        local reference = CS.UnityEngine.Object.Instantiate(template.reference, self.content, false)
        cell = { reference = reference, view = View.Create(reference), templateKey = item.templateKey }
        self.cells[#self.cells + 1] = cell
        cell.root = cell.view.Root
        cell.root.anchorMin = CS.UnityEngine.Vector2(0, 1)
        cell.root.anchorMax = CS.UnityEngine.Vector2(0, 1)
        cell.root.pivot = CS.UnityEngine.Vector2(0, 1)
        cell.root.localScale = CS.UnityEngine.Vector3.one
        cell.root.localEulerAngles = CS.UnityEngine.Vector3.zero
        self.activeCells[index] = cell
        cell.index = index
        if self.options.onCreate then self.options.onCreate(cell) end
    else
        self.activeCells[index] = cell
        cell.index = index
    end
    local padding = self.options.padding
    cell.root.sizeDelta = CS.UnityEngine.Vector2(item.width, item.height)
    cell.root.anchoredPosition = self.vertical and CS.UnityEngine.Vector2(padding.left, -item.start)
        or CS.UnityEngine.Vector2(item.start, -padding.top)
    self.options.onBind(cell, index)
    cell.root.gameObject:SetActive(true)
end

function List:_RefreshVisible()
    if not self.visible then return end
    local size = self.vertical and self.viewportHeight or self.viewportWidth
    -- Use the real offset here so Elastic overscroll does not materialize unrelated cells.
    local first, last = Layout.Visible(self.layout, self:_Offset(), size, self.options.overscan)
    if first == self.firstVisible and last == self.lastVisible then return end
    -- Recycle before acquiring: a jump can immediately reuse the outgoing cells.
    for index in pairs(self.activeCells) do
        if index < first or index > last then self:_Recycle(index) end
    end
    for index = first, last do
        if not self.activeCells[index] then self:_Acquire(index, self.layout.items[index]) end
    end
    self.firstVisible, self.lastVisible = first, last
end

function List:_Rebuild(count, keepPosition)
    local width, height = self:_ViewportSize()
    -- Validate new metadata completely before recycling the previous layout.
    local layout = Layout.Build(count, self.options, self.templates, self.vertical, width, height)
    local offset = keepPosition and self:_Offset() or 0
    self:_RecycleAll()
    self.layout, self.itemCount = layout, count
    self.viewportWidth, self.viewportHeight = width, height
    self.content.sizeDelta = CS.UnityEngine.Vector2(layout.width, layout.height)
    self.scroll:StopMovement()
    self:_SetOffset(offset)
    self:_RefreshVisible()
end

---Rebuild template/size metadata. By default a replacement data set starts at the beginning.
function List:SetItemCount(count, keepPosition)
    self:_Mutate(self._Rebuild, count, keepPosition == true)
end

---Re-read template/size metadata and rebind; preserve pixel offset by default.
function List:Reload(keepPosition)
    self:_Mutate(self._Rebuild, self.itemCount, keepPosition ~= false)
end

function List:_CheckIndex(index)
    assert(type(index) == 'number' and index % 1 == 0 and index >= 1 and index <= self.itemCount, 'Item index is out of range')
end

function List:_RefreshItem(index)
    self:_CheckIndex(index)
    local cell = self.activeCells[index]
    if cell then self.options.onBind(cell, index) end
end

---Content only. Template/size changes require Reload.
function List:RefreshItem(index)
    self:_Mutate(self._RefreshItem, index)
end

function List:_ScrollTo(index, alignment)
    self:_CheckIndex(index)
    Layout.NonNegative(alignment, 'alignment')
    assert(alignment <= 1, 'alignment must be between 0 (start) and 1 (end)')
    local item = self.layout.items[index]
    local size = self.vertical and self.viewportHeight or self.viewportWidth
    self.scroll:StopMovement()
    self:_SetOffset(item.start - (size - (item.finish - item.start)) * alignment)
    self:_RefreshVisible()
end

function List:ScrollTo(index, alignment)
    self:_Mutate(self._ScrollTo, index, alignment or 0)
end

---Returned cells are borrowed: their index/view will be reused when they leave the viewport.
function List:GetVisibleCell(index)
    return self.activeCells[index]
end

function List:GetVisibleRange()
    return self.firstVisible or 1, self.lastVisible or 0
end

function List:OnShow()
    assert(self.configured, 'Configure UIScrollList in the parent Bind before Show')
    self.scrollCallback = function()
        if not self.busy then self:_Mutate(self._SyncViewport) end
    end
    self.scroll.onValueChanged:AddListener(self.scrollCallback)
    local callback = self.scrollCallback
    self.visibleScope:Add(function() self.scroll.onValueChanged:RemoveListener(callback) end)
    self:_Mutate(self._SyncViewport)
end

function List:_SyncViewport()
    local width, height = self:_ViewportSize()
    if width ~= self.viewportWidth or height ~= self.viewportHeight then self:_Rebuild(self.itemCount, true)
    else self:_RefreshVisible() end
end

function List:Tick()
    -- Tick also catches viewport resizes and programmatic changes before ScrollRect emits an event.
    self:_Mutate(self._SyncViewport)
end

function List:OnHide()
    self.scrollCallback = nil
    self.scroll:StopMovement()
    self:_Mutate(self._RecycleAll)
end

function List:OnDestroy()
    local firstError
    for _, cell in ipairs(self.cells) do
        if self.options.onDestroy then
            local ok, err = xpcall(self.options.onDestroy, debug.traceback, cell)
            if not ok and not firstError then firstError = err end
        end
        CS.UnityEngine.Object.Destroy(cell.reference.gameObject)
        cell.view, cell.reference, cell.root = nil, nil, nil
    end
    self.cells, self.activeCells, self.templates = {}, {}, nil
    self.options, self.layout, self.scroll, self.content, self.viewport = nil, nil, nil, nil, nil
    if firstError then error(firstError, 0) end
end

return List
