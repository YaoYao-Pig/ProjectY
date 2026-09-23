-- 配表分段线性曲线：边界采用端点值，节点和输出范围在生成前验证。
local Curve = {}
function Curve.Validate(xs, ys, minimum, maximum)
    assert(#xs >= 2 and #xs == #ys, 'Curve requires matching X/Y arrays with at least two points')
    for i, x in ipairs(xs) do
        assert(type(x) == 'number' and math.abs(x) < math.huge and (i == 1 or x > xs[i-1]), 'Curve X must be finite and strictly increasing')
        assert(type(ys[i]) == 'number' and ys[i] >= minimum and ys[i] <= maximum, 'Curve Y is outside its allowed range')
    end
end
function Curve.Sample(xs, ys, value)
    if value <= xs[1] then return ys[1] end
    for i = 2, #xs do
        if value <= xs[i] then return ys[i-1] + (ys[i]-ys[i-1]) * (value-xs[i-1]) / (xs[i]-xs[i-1]) end
    end
    return ys[#ys]
end
return Curve
