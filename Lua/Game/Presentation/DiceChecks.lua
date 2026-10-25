local LuaLanguage = require('Language')
-- Converts settled facts to visual dice; never consumes a gameplay random stream.
local Checks={}
local sourceNames=require('Config.LanguageProxy').Map(LuaLanguage,{high_ground='AdvantageHighGround',animal_speech='AdvantageAnimalSpeech'})
local function number(value)return string.format('%.4f',value):gsub('%.?0+$','')end
function Checks.SourceText(sources)
    local names={}
    for _,source in ipairs(sources)do names[#names+1]=assert(sourceNames[source],'Unknown advantage source: '..source)end
    return table.concat(names,LuaLanguage.AdvantageSourceSeparator)
end
function Checks.Reading(result,emphasize)
    if #result.rolls==1 then return number(result.roll)end
    local selected=number(result.roll)
    if emphasize then selected='<b>'..selected..'</b>'end
    return string.format(LuaLanguage.DiceAdvantageReading,number(result.rolls[1]),number(result.rolls[2]),selected)
end
function Checks.Percent(title,roll,chance,passed,convention,precision)
    assert(type(title)=='string' and title~='' and type(passed)=='boolean','Invalid check identity')
    assert(type(roll)=='number' and type(chance)=='number' and chance>=0 and chance<=100,'Invalid percentile check')
    assert(convention=='inclusive' or convention=='exclusive','Unknown percentile convention')
    precision=precision or 1
    assert(precision==1 or precision==100,'Unsupported percentile precision')
    local integer=math.floor(roll*precision+.5)
    assert(math.abs(integer-roll*precision)<.00001,'Check precision would discard the settled roll')
    assert(convention=='inclusive' and roll>=1/precision and roll<=100 or convention=='exclusive' and roll>=0 and roll<100,'Roll out of range')
    local faceValue=integer%(100*precision)
    local whole=math.floor(faceValue/precision)
    local dice={{kind='D100',value=math.floor(whole/10)*10,label=LuaLanguage.DiceTens},{kind='D10',value=whole%10,label=LuaLanguage.DiceUnits}}
    if precision==100 then
        local fraction=faceValue%100
        dice[#dice+1]={kind='D10',value=math.floor(fraction/10),label=LuaLanguage.DiceTenths}
        dice[#dice+1]={kind='D10',value=fraction%10,label=LuaLanguage.DiceHundredths}
    end
    local reading=precision==100 and string.format('%.2f',roll) or tostring(roll)
    local detail=string.format(LuaLanguage.DiceRequirement, (string.format('%.2f',chance):gsub('%.?0+$','')))
    return {title=title,dice=dice,detail=detail,reading=reading,passed=passed}
end
function Checks.Resolved(title,result)
    local request=Checks.Percent(title,result.roll,result.chance,result.passed,'inclusive',result.precision)
    request.detail=string.format(LuaLanguage.DiceRequirementGreater,result.threshold,result.chance)
    if #result.advantageSources==0 then return request end
    assert(#result.rolls==2,'Advantage needs exactly two settled rolls')
    request.reading=Checks.Reading(result,true)
    request.detail=string.format(LuaLanguage.DiceAdvantageRequirement,Checks.SourceText(result.advantageSources),
        number(result.threshold),number(result.effectiveChance))
    request.rounds={}
    for i,value in ipairs(result.rolls)do
        local round=Checks.Percent(string.format(LuaLanguage.DiceAdvantageRollTitle,title,i,#result.rolls),
            value,result.chance,result.passed,'inclusive',result.precision)
        round.detail=request.detail
        request.rounds[i]=round
    end
    return request
end
function Checks.FromBattleEvent(event)
    if event.kind~='check' then return end
    local data=assert(event.impact,'Check requires settled metadata')
    if data.check then return Checks.Resolved(data.checkName,data.check)end
    if data.roll==nil then return end -- Guaranteed effects have no die roll.
    local result=Checks.Percent(data.checkName,data.roll,data.chance,data.passed,data.rollConvention or 'exclusive',1)
    if data.rollComparison=='greater' then result.detail=string.format(LuaLanguage.DiceRequirementGreater,data.threshold,data.chance) end
    return result
end
return Checks
