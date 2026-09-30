-- Pure layout calculations; indices are one-based, intervals are [start, finish).
local Layout = {}

local function finite(value)
    return type(value) == 'number' and value == value and value > -math.huge and value < math.huge
end

function Layout.NonNegative(value, name)
    assert(finite(value) and value >= 0, name .. ' must be a finite non-negative number')
    return value
end

function Layout.Build(count, options, templates, vertical, viewportWidth, viewportHeight)
    assert(finite(count) and count >= 0 and count % 1 == 0, 'Item count must be a non-negative integer')
    local padding = options.padding
    local cursor = vertical and padding.top or padding.left
    local cross = 0
    local items = {}
    for index = 1, count do
        local key = options.defaultTemplate
        if options.getTemplate then key = options.getTemplate(index) end
        local template = assert(templates[key], 'Unknown CellTemplate at index ' .. index .. ': ' .. tostring(key))
        local width, height = template.width, template.height
        if options.getSize then width, height = options.getSize(index, key, viewportWidth, viewportHeight) end
        assert(finite(width) and width > 0 and finite(height) and height > 0,
            'Cell size must be finite and positive at index ' .. index)
        local finish = cursor + (vertical and height or width)
        assert(finite(finish), 'UIScrollList content size overflow')
        items[index] = { templateKey = key, width = width, height = height, start = cursor, finish = finish }
        cursor = finish + options.spacing
        cross = math.max(cross, vertical and width or height)
    end
    if count > 0 then cursor = cursor - options.spacing end
    local extent = cursor + (vertical and padding.bottom or padding.right)
    assert(finite(extent), 'UIScrollList content size overflow')
    return {
        items = items, count = count, extent = extent,
        width = vertical and math.max(viewportWidth, cross + padding.left + padding.right) or math.max(viewportWidth, extent),
        height = vertical and math.max(viewportHeight, extent) or math.max(viewportHeight, cross + padding.top + padding.bottom),
    }
end

-- Two binary searches keep fast jumps independent of total item count.
function Layout.Visible(layout, offset, viewportSize, overscan)
    if layout.count == 0 or viewportSize <= 0 then return 1, 0 end
    local firstEdge, lastEdge = offset - overscan, offset + viewportSize + overscan
    local items, count = layout.items, layout.count
    local low, high = 1, count + 1
    while low < high do
        local middle = math.floor((low + high) / 2)
        if items[middle].finish <= firstEdge then low = middle + 1 else high = middle end
    end
    local first = low
    low, high = 1, count + 1
    while low < high do
        local middle = math.floor((low + high) / 2)
        if items[middle].start < lastEdge then low = middle + 1 else high = middle end
    end
    return first, low - 1
end

function Layout.ClampOffset(layout, offset, viewportSize)
    return math.max(0, math.min(offset, math.max(0, layout.extent - viewportSize)))
end

return Layout
