-- Resolve a check once; presentation consumes these settled facts without drawing again.
local Check={}
function Check.BelowThreshold(chance,precision)
    assert(type(chance)=='number' and chance>=0 and chance<=100,'Invalid check chance')
    assert(precision==1 or precision==100,'Unsupported check precision')
    local threshold=math.ceil(chance*precision)
    -- Compare the canonical percentage values: multiplying e.g. 0.07 by 100 can round above 7.
    if threshold>0 and (threshold-1)/precision>=chance then threshold=threshold-1
    elseif threshold<100*precision and threshold/precision<chance then threshold=threshold+1 end
    return threshold
end
function Check.Chance(chance,sources)
    assert(type(chance)=='number' and chance>=0 and chance<=100,'Invalid check chance')
    if not sources or #sources==0 then return chance end
    return chance*(2-chance/100)
end
function Check.Resolve(threshold,precision,roll,sources)
    assert(precision==1 or precision==100,'Unsupported check precision')
    local scale=100*precision
    assert(math.tointeger(threshold) and threshold>=0 and threshold<=scale,'Invalid check threshold')
    assert(type(roll)=='function','Check needs its owning random stream')
    local unique,seen={},{}
    for _,source in ipairs(sources or {})do
        assert(type(source)=='string' and source~='','Invalid advantage source')
        if not seen[source]then unique[#unique+1]=source;seen[source]=true end
    end
    local count=#unique>0 and 2 or 1
    local rolls,selected={},1
    for i=1,count do
        local raw=roll()
        assert(math.tointeger(raw) and raw>=0 and raw<scale,'Check roll is outside its declared precision')
        rolls[i]=(scale-raw)/precision
        if rolls[i]>rolls[selected]then selected=i end
    end
    local chance=threshold/precision
    local minimum=(scale-threshold)/precision
    return {passed=rolls[selected]>minimum,roll=rolls[selected],rolls=rolls,selectedIndex=selected,
        threshold=minimum,chance=chance,effectiveChance=Check.Chance(chance,unique),advantageSources=unique,
        precision=precision,rollConvention='inclusive',rollComparison='greater'}
end
return Check
