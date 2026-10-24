package.path='Lua/?.lua;'..package.path
local Proxy=require('Config.LanguageProxy')
local Language=require('Language')
local Checks=require('Game.Presentation.DiceChecks')
local Inventory=require('Game.Equipment.InventoryModel')
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local texts=config:GetTable('LuaTxt')
Proxy.Bind(function(id)local row=texts:Find(id);return row and row.txt end)
assert(Checks.Percent('清障',43,70,true,'inclusive').detail=='要求：70')
assert(texts:Get('DiceRequirement').txt=='要求：%s')
for _,entry in ipairs({{'CampFacilityTable','description'},{'CampRecipeTable','name'}, {'MapAreaTable','name'},
    {'MapAreaTownFacilityTable','name'},{'MapAreaTownNpcTable','name'},{'MapWeatherTable','name'}})do
    local schema=require('_Gen.'..entry[1]);local found=false
    for _,field in ipairs(schema.fields)do if field.name==entry[2] then assert(field.type=='text');found=true end end
    assert(found)
end
-- Bind overrides after modules have been required: cached label maps must resolve at use time.
local translated={DiceRequirement='Required: %s',DiceTens='Tens',DiceUnits='Units',DiceTenths='Tenths',DiceHundredths='Hundredths',
    DiceSuccess='Success',DiceFailure='Failure',UIInventoryHead='Head',UIInventoryWeapon='Main hand'}
Proxy.Bind(function(id)return translated[id] end)
local check=Checks.Percent('Tame',62.37,50,false,'exclusive',100)
assert(check.detail=='Required: 50' and check.reading=='62.37')
assert(check.dice[1].label=='Tens' and check.dice[4].label=='Hundredths')
assert(Inventory.slotNames.head=='Head' and Inventory.slotNames.weapon=='Main hand')
assert(Language.DiceSuccess=='Success' and Language.DiceFailure=='Failure')
translated.DiceRequirement=''
assert(Checks.Percent('Tame',42,70,true,'exclusive').detail=='','Empty text override is intentional')
Proxy.Bind(nil)
assert(Checks.Percent('清障',43,70,true,'inclusive').detail=='要求：70')
config:OnShutdown()
print('PASS exported UI language table, translated dice formats, lazy label maps, empty overrides and display field text schemas')
