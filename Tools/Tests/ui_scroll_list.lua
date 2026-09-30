package.path = 'Lua/?.lua;' .. package.path
local Layout = require('UI.UIScrollListLayout')

local function equal(actual, expected, message)
    assert(actual == expected, (message or 'Mismatch') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end
local function throws(fn, message)
    local ok, err = pcall(fn)
    assert(not ok and tostring(err):find(message, 1, true), 'Expected error containing: ' .. message .. '; got ' .. tostring(err))
end
local padding = { left = 7, right = 11, top = 13, bottom = 17 }
local templates = { Short = { width = 120, height = 24 }, Tall = { width = 160, height = 96 } }
local options = { padding = padding, spacing = 5, getTemplate = function(index) return index % 3 == 0 and 'Tall' or 'Short' end }
local layout = Layout.Build(4, options, templates, true, 200, 100)
equal(layout.extent, 213, 'Mixed-height extent includes padding and only three gaps')
equal(layout.items[3].start, 71)
equal(layout.items[4].finish, 196)
equal(layout.width, 200)
local first, last = Layout.Visible(layout, 37, 5, 0)
assert(first > last, 'Viewport wholly inside spacing should show no cell')
first, last = Layout.Visible(layout, 24, 100, 0)
equal(first, 1); equal(last, 3)
equal(Layout.ClampOffset(layout, 10000, 100), 113)

-- Compare binary search against an independent linear overlap oracle.
math.randomseed(54321)
for _, vertical in ipairs({ true, false }) do
    for count = 0, 70 do
        local sizes = {}
        for i = 1, count do sizes[i] = { math.random(1, 300), math.random(1, 300) } end
        local randomOptions = {
            padding = padding, spacing = math.random(0, 40), defaultTemplate = 'Short',
            getSize = function(i) return sizes[i][1], sizes[i][2] end,
        }
        local current = Layout.Build(count, randomOptions, templates, vertical, 200, 180)
        for _ = 1, 30 do
            local offset, viewport, overscan = math.random(-500, current.extent + 500), math.random(1, 500), math.random(0, 150)
            local expected = {}
            for index, item in ipairs(current.items) do
                if item.finish > offset - overscan and item.start < offset + viewport + overscan then expected[#expected + 1] = index end
            end
            local a, b = Layout.Visible(current, offset, viewport, overscan)
            equal(math.max(0, b - a + 1), #expected, 'Visible count')
            if #expected > 0 then equal(a, expected[1]); equal(b, expected[#expected]) end
        end
    end
end
throws(function() Layout.Build(-1, options, templates, true, 200, 100) end, 'Item count')
throws(function() Layout.Build(1.5, options, templates, true, 200, 100) end, 'Item count')
local invalid = { padding = padding, spacing = 0, defaultTemplate = 'Short', getTemplate = function() return nil end }
throws(function() Layout.Build(1, invalid, templates, true, 200, 100) end, 'Unknown CellTemplate')
invalid.getTemplate = nil; invalid.getSize = function() return 120, 0 end
throws(function() Layout.Build(1, invalid, templates, true, 200, 100) end, 'Cell size')
invalid.getSize = function() return 120, 0 / 0 end
throws(function() Layout.Build(1, invalid, templates, true, 200, 100) end, 'Cell size')
print('PASS mixed-size layout, padding/spacing, invalid inputs, 4260 randomized visibility comparisons')

-- Minimal Unity boundary doubles. Exercise the real controller and framework lifecycle.
local function vector(x, y, z) return { x = x, y = y, z = z } end
local function event()
    local result = { listeners = {} }
    function result:AddListener(fn) self.listeners[#self.listeners + 1] = fn end
    function result:RemoveListener(fn)
        for i = #self.listeners, 1, -1 do if self.listeners[i] == fn then table.remove(self.listeners, i) end end
    end
    function result:Emit() for _, fn in ipairs(self.listeners) do fn() end end
    return result
end
local function rect(width, height, parent)
    local obj = { activeSelf = false }
    function obj:SetActive(active) self.activeSelf = active end
    local result = { rect = { width = width, height = height }, gameObject = obj, parent = parent, anchoredPosition = vector(0, 0) }
    return setmetatable(result, {
        __newindex = function(self, key, value)
            if key == 'sizeDelta' then self.rect.width, self.rect.height = value.x, value.y
            else rawset(self, key, value) end
        end,
        __index = function(self, key) if key == 'sizeDelta' then return vector(self.rect.width, self.rect.height) end end,
    })
end
local function reference(root, key)
    local result = { transform = root, gameObject = root.gameObject, marker = key }
    result.bindings = { Root = root, Caption = { text = '' }, Button = { onClick = event() } }
    function result:Get(name) return assert(self.bindings[name], 'Missing binding: ' .. name) end
    return result
end
local instances, destroyed = {}, 0
CS = { UnityEngine = {
    Vector2 = vector, Vector3 = { one = vector(1, 1, 1), zero = vector(0, 0, 0) },
    Object = {
        Instantiate = function(source, parent, worldPositionStays)
            assert(not source.gameObject.activeSelf and worldPositionStays == false)
            local copy = reference(rect(source.transform.rect.width, source.transform.rect.height, parent), source.marker)
            instances[#instances + 1] = copy
            return copy
        end,
        Destroy = function(obj) assert(not obj.destroyed, 'Double destroy'); obj.destroyed = true; destroyed = destroyed + 1 end,
    },
} }
local Base = require('UI.UIWidgetCtrl')
local List = require('UI.UIScrollList')
local function fixture(vertical)
    local viewport = rect(200, 180)
    local scroll = { viewport = viewport, content = rect(200, 180, viewport), vertical = vertical, horizontal = not vertical, onValueChanged = event() }
    function scroll:StopMovement() self.stops = (self.stops or 0) + 1 end
    local view = { Get = function(_, key) equal(key, 'ScrollRect'); return scroll end }
    local owner = Base({ log = error }, {})
    local list = owner:AddWidget(List, view)
    return owner, list, scroll
end
local owner, list, scroll = fixture(true)
local created, bound, recycled, released, clicked = 0, 0, 0, 0, nil
local tall = reference(rect(160, 96), 'Tall')
local short = reference(rect(120, 24), 'Short')
local templateQueries = 0
local reverse = false
list:Configure({
    templates = { Short = short, Tall = tall }, overscan = 0, spacing = 5, padding = padding,
    getTemplate = function(index)
        templateQueries = templateQueries + 1
        return (index % 3 == 0) ~= reverse and 'Tall' or 'Short'
    end,
    onCreate = function(cell)
        created = created + 1
        assert(not cell.root.gameObject.activeSelf)
        list:Listen(cell.view.Button, function() clicked = cell.index end)
    end,
    onBind = function(cell, index)
        equal(cell.index, index); equal(cell.reference.marker, cell.templateKey)
        cell.view.Caption.text = tostring(index)
        bound = bound + 1
    end,
    onRecycle = function(cell, index)
        assert(not cell.root.gameObject.activeSelf and cell.index == nil and index > 0)
        recycled = recycled + 1
    end,
    onDestroy = function(cell)
        equal(#cell.view.Button.onClick.listeners, 0, 'Lifetime listeners removed before destruction')
        released = released + 1
    end,
})
list:SetItemCount(10000)
equal(created, 0, 'Hidden list must not create cells')
owner:Show()
equal(#scroll.onValueChanged.listeners, 1)
assert(created > 0 and created < 10, 'Only viewport cells should exist')
equal(scroll.content.sizeDelta.y, list.layout.extent)
local initialBound, initialQueries = bound, templateQueries
owner:Update(0, .016); scroll.onValueChanged:Emit()
equal(bound, initialBound, 'Stationary list must not rebind')
equal(templateQueries, initialQueries, 'Scroll hot path must not enumerate metadata')

for index = 100, 10000, 100 do
    list:ScrollTo(index, .5)
    assert(list:GetVisibleCell(index), 'Jump target not visible')
    local target = list:GetVisibleCell(index)
    equal(target.view.Caption.text, tostring(index), 'Reused cell retained stale data')
    target.view.Button.onClick:Emit(); equal(clicked, index, 'Click listener captured an old index')
    for visibleIndex, cell in pairs(list.activeCells) do
        local item = list.layout.items[visibleIndex]
        equal(cell.root.sizeDelta.y, item.height)
        equal(cell.root.sizeDelta.x, item.width)
        equal(cell.root.anchoredPosition.y, -item.start)
    end
end
assert(created < 20, 'Pool grew with data count or scroll distance: ' .. created)
equal(templateQueries, initialQueries, 'Jumping must use cached layout')
list:ScrollTo(10000, 1)
equal(list:_Offset(), list.layout.items[10000].finish - 180, 'End alignment targets the cell edge, before bottom padding')
list:ScrollTo(1)
list:RefreshItem(1); equal(list:GetVisibleCell(1).view.Caption.text, '1')
local beforeInvisibleRefresh = bound
list:RefreshItem(9000); equal(bound, beforeInvisibleRefresh)
throws(function() list:ScrollTo(10001) end, 'out of range')
throws(function() list:ScrollTo(1, 2) end, 'alignment')
assert(not list.busy, 'Failure must release mutation guard')

-- Metadata replacement, viewport resizing, shrink/clamp, and empty list.
reverse = true
local oldOffset = list:_Offset()
list:Reload()
equal(list:_Offset(), oldOffset)
equal(list:GetVisibleCell(1).templateKey, 'Tall')
list:ScrollTo(10000)
scroll.viewport.rect.width, scroll.viewport.rect.height = 320, 300
owner:Update(0, .016)
equal(scroll.content.sizeDelta.x, 320)
equal(list:_Offset(), list.layout.extent - 300, 'Resize clamps the end')
list:SetItemCount(2, true)
equal(list:_Offset(), 0, 'Shrinking below viewport clamps to start')
equal(scroll.content.sizeDelta.y, 300, 'Short content fills viewport')
assert(list:GetVisibleCell(1) and list:GetVisibleCell(2))
list:SetItemCount(0)
equal(next(list.activeCells), nil)
first, last = list:GetVisibleRange(); assert(first > last)
equal(list:_Offset(), 0)
throws(function() list:SetItemCount(-1) end, 'Item count')
equal(list.itemCount, 0, 'Invalid metadata should not replace existing layout')

list:SetItemCount(100)
local cellsBeforeHide = created
owner:Hide()
equal(#scroll.onValueChanged.listeners, 0)
equal(next(list.activeCells), nil)
list:SetItemCount(50, true)
equal(created, cellsBeforeHide)
owner:Show()
equal(#scroll.onValueChanged.listeners, 1)
equal(created, cellsBeforeHide, 'Reopening reuses the pool')
owner:Dispose(); owner:Dispose()
equal(#scroll.onValueChanged.listeners, 0)
equal(destroyed, created); equal(released, created)
assert(recycled > 0)
assert(not short.gameObject.destroyed and not tall.gameObject.destroyed, 'Templates belong to the caller')
print('PASS 10000 items: bounded template pools, jump/reuse, callbacks, reload, resize, shrink, empty, hide/show/dispose')

local horizontalOwner, horizontal, horizontalScroll = fixture(false)
local widthFactor = 1
horizontal:Configure({
    templates = { Short = short }, spacing = 3, padding = padding, overscan = 20,
    getSize = function(index, key, viewportWidth, viewportHeight)
        equal(key, 'Short'); equal(viewportWidth, 200); equal(viewportHeight, 180)
        return index * 15 * widthFactor, 40 + index
    end,
    onBind = function(cell, index) cell.view.Caption.text = tostring(index) end,
})
horizontal:SetItemCount(30)
horizontalOwner:Show()
horizontal:ScrollTo(10, .5)
local cell = horizontal:GetVisibleCell(10)
equal(cell.root.sizeDelta.x, 150); equal(cell.root.sizeDelta.y, 50)
equal(cell.root.anchoredPosition.x, horizontal.layout.items[10].start)
equal(cell.root.anchoredPosition.y, -13)
assert(horizontalScroll.content.anchoredPosition.x < 0 and horizontalScroll.content.anchoredPosition.y == 0)
widthFactor = 2
horizontal:Reload(false); equal(horizontal:_Offset(), 0)
horizontal:ScrollTo(30, 1); assert(horizontal:GetVisibleCell(30))
horizontalScroll.viewport.rect.width = 0
-- Zero viewport produces no visible cells (without invoking the fixture's width assertion).
local a, b = Layout.Visible(horizontal.layout, 0, 0, 20); assert(a > b)
horizontalScroll.viewport.rect.width = 200
horizontalOwner:Dispose()

local errorOwner, errorList = fixture(true)
errorList:Configure({ templates = { Short = short }, onBind = function() errorList:Reload() end })
errorList:SetItemCount(10)
throws(function() errorOwner:Show() end, 'Do not mutate UIScrollList from its callbacks')
assert(not errorList.busy)
errorOwner:Dispose()
equal(destroyed, #instances, 'All owned clones released, including after a callback failure')
print('PASS horizontal/per-item dimensions, alignment, overscan, reentrant callback rejection and failure cleanup')
