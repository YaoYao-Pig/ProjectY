-- Free GM rolls use their own random stream and produce presentation requests only.
local LuaLanguage=require('Language')
local Random=require('Game.Map.SeededRandom')
local Dice={};Dice.__index=Dice
Dice.Kinds={'D4','D6','D8','D10','D12','D20','D100'}
Dice.Limit=6
local faces={D4={1,4},D6={1,6},D8={1,8},D10={0,9},D12={1,12},D20={1,20},D100={0,9,10}}
function Dice.New(seed)return setmetatable({random=Random(seed)},Dice)end
function Dice:Validate(counts)
    if type(counts)~='table' then return nil,LuaLanguage.GMDiceInvalidCombination end
    local total=0
    for kind,count in pairs(counts)do
        if not faces[kind] or type(count)~='number' or count%1~=0 or count<0 or count>self.Limit then
            return nil,LuaLanguage.GMDiceInvalidCombination
        end
        total=total+count
    end
    if total<1 or total>self.Limit then return nil,string.format(LuaLanguage.GMDiceCountRequired,self.Limit) end
    return total
end
function Dice:Roll(counts)
    local count,reason=self:Validate(counts);if not count then return false,reason end
    local dice,combination,results={},{},{};local sum=0
    for _,kind in ipairs(self.Kinds)do
        local quantity=counts[kind] or 0 -- Omitted kinds are explicitly optional.
        if quantity>0 then combination[#combination+1]=string.format('%d×%s',quantity,kind) end
        for _=1,quantity do
            local range=faces[kind];local value=self.random:Integer(range[1],range[2])*(range[3] or 1)
            dice[#dice+1]={kind=kind,value=value,label=kind};sum=sum+value
            results[#results+1]=kind..'='..(kind=='D100' and string.format('%02d',value) or tostring(value))
        end
    end
    return true,{kind='roll',title=LuaLanguage.GMDiceRollTitle,dice=dice,count=count,sum=sum,
        detail=string.format(LuaLanguage.GMDiceCombination,table.concat(combination,' + ')),
        reading=string.format(LuaLanguage.GMDiceRollResult,table.concat(results,' + '),sum)}
end
return Dice
