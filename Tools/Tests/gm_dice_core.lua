package.path='Lua/?.lua;'..package.path
local Dice=require('Game.GM.DiceCommands')
local Language=require('Language')
local tests=0
local function test(name,run)run();tests=tests+1;print('PASS '..name)end
test('invalid combinations reject atomically without advancing the GM random stream',function()
    local dice=Dice.New(42);local state=dice.random.state
    for _,counts in ipairs({{}, {D6=-1},{D6=1.5},{D3=1},{D6=7},{D6=4,D20=3},{D6='1'},{D6=0/0},{D6=math.huge},{[1]='D6'}})do
        local ok,reason=dice:Roll(counts);assert(not ok and type(reason)=='string' and reason~='')
        assert(dice.random.state==state)
    end
    assert(not dice:Roll(nil) and not dice:Roll('2D6'))
end)
test('mixed duplicate dice preserve their catalog ranges, request order and sum',function()
    local dice=Dice.New(123);local counts={D4=1,D6=2,D10=1,D20=1,D100=1}
    local ok,roll=dice:Roll(counts);assert(ok and roll.kind=='roll' and roll.count==6 and #roll.dice==6)
    local sum=0;local order={'D4','D6','D6','D10','D20','D100'}
    local ranges={D4={1,4},D6={1,6},D10={0,9},D20={1,20},D100={0,90}}
    for i,die in ipairs(roll.dice)do
        assert(die.kind==order[i]);local range=ranges[die.kind]
        assert(die.value>=range[1] and die.value<=range[2] and die.value%1==0)
        if die.kind=='D100' then assert(die.value%10==0)end
        sum=sum+die.value
    end
    assert(roll.sum==sum and roll.passed==nil and roll.reading:find(tostring(sum),1,true))
    assert(counts.D6==2 and counts.D20==1 and counts.D8==nil,'Caller selection must not be modified')
end)
test('every supported die reaches the same minimum and maximum as its physical model',function()
    local minima={D4=1,D6=1,D8=1,D10=0,D12=1,D20=1,D100=0}
    local maxima={D4=4,D6=6,D8=8,D10=9,D12=12,D20=20,D100=90}
    for _,kind in ipairs(Dice.Kinds)do
        local dice=Dice.New(0)
        dice.random={Integer=function(_,low,high)return low end}
        local ok,roll=dice:Roll({[kind]=1});assert(ok and roll.dice[1].value==minima[kind])
        dice.random={Integer=function(_,low,high)return high end}
        ok,roll=dice:Roll({[kind]=1});assert(ok and roll.dice[1].value==maxima[kind])
    end
end)
test('GM randomness is independent and reproducible without reseeding Lua global randomness',function()
    local first,second=Dice.New(9),Dice.New(9)
    math.randomseed(12345);local expected=math.random()
    math.randomseed(12345)
    local ok,a=first:Roll({D6=6});local yes,b=second:Roll({D6=6});assert(ok and yes and a.reading==b.reading)
    assert(math.random()==expected)
    local state=second.random.state;assert(first:Roll({D20=1}));assert(second.random.state==state)
end)
print('GM dice: '..tests..' checks passed')
