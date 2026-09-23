-- 测试面板通过现有 Config 系统读取尺寸，不在 C# 再维护一份配置默认值。
return function()
    local config = require('Main'):Get('Config')
    local defaultCells = config:GetConstant('Map', 'DefaultTargetCells')
    local maxCells = config:GetConstant('Map', 'MaxCells')
    assert(defaultCells >= 1 and defaultCells <= maxCells and defaultCells == math.floor(defaultCells), 'Invalid DefaultTargetCells')
    return { defaultCells = defaultCells, maxCells = maxCells }
end
