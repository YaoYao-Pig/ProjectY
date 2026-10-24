-- Exported tables and the real caravan restock path; no Editor, save files or C# compilation.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local items=config:GetTable('EquipmentItemTable')
local shop=require('Game.Shop.ShopRules').New(config)
local data={Seed=20261020}
local nativeState={}
CS={ProjectY={Data={WorldPartiesData={For=function(owner)assert(owner==data);return nativeState end}}}}
local Parties=require('Game.Adventure.WorldParties')
local function adventure(settings)
    return {config=settings,data=data,shop={rules=shop},equipment={data={},rules={items=items}},battle={stats={}}}
end
local parties=Parties.New(adventure(config))
local seen={};local attempts=0
local party={Id=1,DefinitionId=1,DestinationSiteId=3,HomeSiteId=2,Travel={Roll=function(_,max)
    assert(max==2147483647);attempts=attempts+1;return attempts
end}}
function party:SetCargo(_,ids,counts,kinds,widths,heights)
    assert(#ids==#counts and #ids==#kinds and #ids==#widths and #ids==#heights)
    for i,id in ipairs(ids) do
        local item=items:Get(id);assert(parties.prices[id] and counts[i]>0)
        assert(kinds[i]==item.kind and widths[i]==item.width and heights[i]==item.height)
        seen[id]=true
    end
end
for _=1,64 do parties:Restock(party) end
for id=730,741 do
    assert(seen[id],'New attachment never reached the real restock path: '..id)
    assert(parties.prices[id]==config:GetTable('ShopEntryTable'):Get(id).price,'Caravan/shop price differs: '..id)
end
print('PASS real randomized caravan restocks cover all 12 new attachments at existing shop prices')

local function priceOverride(rows)
    return {GetTable=function(_,name)
        if name=='WorldTradePriceTable' then return {All=function()return rows end}end
        return config:GetTable(name)
    end}
end
local incomplete={}
for _,row in ipairs(config:GetTable('WorldTradePriceTable'):All()) do if row.itemId~=730 then incomplete[#incomplete+1]=row end end
local ok,reason=pcall(Parties.New,adventure(priceOverride(incomplete)))
assert(not ok and reason:find('WorldTradePriceTable',1,true) and reason:find('730',1,true) and reason:find(items:Get(730).name,1,true))
assert(attempts==64,'Missing-price validation must fail before restocking')
print('PASS missing price fails at initialization with its table, item ID and name')

local duplicated={}
for _,row in ipairs(config:GetTable('WorldTradePriceTable'):All()) do duplicated[#duplicated+1]=row end
duplicated[#duplicated+1]=duplicated[1]
ok,reason=pcall(Parties.New,adventure(priceOverride(duplicated)))
assert(not ok and reason:find('Duplicate world trade price: itemId=',1,true))
local saved=parties.prices[730];parties.prices[730]=nil
local roll=shop.Roll;shop.Roll=function()return {730},{730},{1}end
ok,reason=pcall(parties.Restock,parties,party)
shop.Roll=roll;parties.prices[730]=saved
assert(not ok and reason:find('730',1,true) and reason:find('shopTemplateId=1',1,true))
print('PASS duplicate prices and a changed restock contract report specific item diagnostics')
config:OnShutdown()
