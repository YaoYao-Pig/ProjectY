-- 条件只读取调用方提供的事实；任务流转、发奖和对话跳转由各自系统执行。
local Evaluator = {}
Evaluator.__index = Evaluator

local composites = { all = true, any = true, ['not'] = true }

function Evaluator.New(definitions)
    return setmetatable({ definitions = assert(definitions), handlers = {}, validated = false }, Evaluator)
end

-- evaluate(row, context) -> boolean, reason；validate(row) 在启动时检查叶子参数和外部引用。
function Evaluator:Register(kind, evaluate, validate)
    assert(type(kind) == 'string' and kind ~= '', 'Condition kind is required')
    assert(not composites[kind] and not self.handlers[kind], 'Duplicate/reserved condition kind: ' .. kind)
    assert(type(evaluate) == 'function' and type(validate) == 'function', 'Condition needs evaluation and validation handlers')
    self.handlers[kind] = { evaluate = evaluate, validate = validate }
    self.validated = false
end

function Evaluator:Validate()
    self.validated = false
    local visited, visiting = {}, {}
    local function visit(id)
        assert(not visiting[id], 'Condition reference cycle at ' .. tostring(id))
        if visited[id] then return visited[id] end
        local row = self.definitions:Get(id)
        assert(type(row.reason) == 'string' and row.reason ~= '', 'Condition failure reason is required: ' .. id)
        visiting[id] = true
        local depth = 1
        if composites[row.kind] then
            assert(#row.conditionIds > 0, 'Composite condition needs children: ' .. id)
            assert(row.kind ~= 'not' or #row.conditionIds == 1, 'NOT condition needs exactly one child: ' .. id)
            local seen = {}
            for _, childId in ipairs(row.conditionIds) do
                assert(not seen[childId], 'Duplicate condition child: ' .. childId)
                seen[childId] = true
                depth = math.max(depth, visit(childId) + 1)
            end
        else
            assert(#row.conditionIds == 0, 'Leaf condition cannot contain children: ' .. id)
            local handler = assert(self.handlers[row.kind], 'Unknown condition kind: ' .. tostring(row.kind))
            handler.validate(row)
        end
        assert(depth <= 64, 'Condition nesting exceeds 64 at ' .. tostring(id))
        visiting[id], visited[id] = nil, depth
        return depth
    end
    for _, row in ipairs(self.definitions:All()) do visit(row.id) end
    self.validated = true
end

function Evaluator:Check(id, context)
    assert(self.validated, 'Validate conditions after registering all handlers')
    assert(context ~= nil, 'Condition context is required')
    -- 缓存仅存在于一次查询内；下一次查询重新读取背包、任务等真实状态。
    local results = {}
    local function evaluate(conditionId)
        local cached = results[conditionId]
        if cached then return cached[1], cached[2] end
        local row = self.definitions:Get(conditionId)
        local passed, reason
        if row.kind == 'all' then
            passed = true
            for _, childId in ipairs(row.conditionIds) do
                passed, reason = evaluate(childId)
                if not passed then break end
            end
        elseif row.kind == 'any' then
            passed = false
            for _, childId in ipairs(row.conditionIds) do
                if evaluate(childId) then passed = true; break end
            end
        elseif row.kind == 'not' then
            passed = not evaluate(row.conditionIds[1])
        else
            passed, reason = self.handlers[row.kind].evaluate(row, context)
            assert(type(passed) == 'boolean', 'Condition handler must return boolean: ' .. row.kind)
            assert(reason == nil or type(reason) == 'string', 'Condition reason must be a string: ' .. row.kind)
        end
        reason = passed and '' or (reason ~= nil and reason ~= '' and reason or row.reason)
        results[conditionId] = { passed, reason }
        return passed, reason
    end
    return evaluate(id)
end

return Evaluator
