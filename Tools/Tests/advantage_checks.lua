package.path='Lua/?.lua;'..package.path
local Check=require('Game.CheckRoll')
for _,precision in ipairs({1,100})do
    for raw=0,100*precision do
        assert(Check.BelowThreshold(raw/precision,precision)==raw,'Canonical percentile equality must fail')
    end
end
assert(Check.BelowThreshold(.070000000001,100)==8 and Check.BelowThreshold(.07,100)==7)
local function resolve(threshold,precision,values,sources)
    local calls=0
    local result=Check.Resolve(threshold,precision,function()calls=calls+1;return assert(values[calls])end,sources)
    assert(calls==(#(sources or {})>0 and 2 or 1),'Only the declared number of rolls may be consumed')
    return result
end
local sources={'high_ground','high_ground','animal_speech'}
local result=resolve(30,1,{90,20},sources)
assert(result.passed and result.roll==80 and result.rolls[1]==10 and result.rolls[2]==80 and result.selectedIndex==2)
assert(result.threshold==70 and result.chance==30 and result.effectiveChance==51)
assert(#result.advantageSources==2 and #sources==3,'Source collection must not mutate the input')
local wins=0
for a=0,99 do for b=0,99 do
    result=resolve(30,1,{a,b},{'high_ground'})
    assert(result.passed==(a<30 or b<30),'Taking the high converted value must retain the better outcome')
    if result.passed then wins=wins+1 end
end end
assert(wins==5100,'Independent 30% rolls must produce exactly 51% success')
for _,threshold in ipairs({0,1,25,99,100})do for raw=0,99 do
    result=resolve(threshold,1,{raw})
    assert(result.passed==(raw<threshold) and result.roll==100-raw and result.effectiveChance==threshold)
end end
for _,threshold in ipairs({0,1,2500,9999,10000})do
    for _,raw in ipairs({0,1,2499,2500,2501,9998,9999})do
        result=resolve(threshold,100,{raw,raw},{'animal_speech'})
        assert(result.passed==(raw<threshold) and result.selectedIndex==1 and #result.rolls==2)
        assert(math.abs(result.roll-(10000-raw)/100)<1e-10)
    end
end
assert(not pcall(Check.Resolve,30,1,function()return 100 end,{}))
assert(not pcall(Check.Resolve,30,1,function()return 2.5 end,{}))
assert(not pcall(Check.Resolve,30.5,1,function()return 0 end,{}))
assert(not pcall(Check.Resolve,30,1,function()return 0 end,{''}))
print('PASS exact advantage distribution, source deduplication, high-value selection, ties, RNG counts, integer/hundredth boundaries')
